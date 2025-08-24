-- Author: S.Ghamri
-- mod-version:3
local core = require "core"
local common = require "core.common"
local system = require "system"
local process = require "process"

local M = {}

-- m: queue
local git_queue = {} -- single thread queue
local git_busy = false
local function process_next_git_task()
  if #git_queue == 0 then
    git_busy = false
    return
  end

  git_busy = true
  local task = table.remove(git_queue, 1)

  core.add_thread(function()
    task() 
    process_next_git_task() -- call next task in queue
  end)
end

local function enqueue_git_task(task)
  table.insert(git_queue, task)
  if not git_busy then
    process_next_git_task()
  end
end

-- m: git process
local function execute_git(repo_root, args_table)
  local command = { "git", "-C", repo_root }
  for _, arg in ipairs(args_table) do table.insert(command, arg) end

  local git_process = process.start(command)
  if not git_process then
    core.error("git: failed to start process for %s, cmd: %s", repo_root, table.concat(command, " "))
    return "", -1, ""
  end

  local stdout_output, stderr_output = "", ""
  while git_process:running() do
    coroutine.yield() 
    stdout_output = stdout_output .. (git_process:read_stdout() or "")
    stderr_output = stderr_output .. (git_process:read_stderr() or "")
  end

  local exit_code = git_process:returncode() or -1
  if exit_code ~= 0 then
    core.warn("git: command failed (%d) for %s, cmd: %s", exit_code, repo_root, table.concat(command, " "))
    if #stderr_output > 0 then
      core.warn("git: stderr: %s", stderr_output:match("^[^\n]+"))
    end
  end

  return stdout_output, exit_code, stderr_output
end

local function get_repo_root(filepath)
  if not filepath then return nil end
  local current_dir = common.dirname(filepath)
  -- check all parent folders
  while current_dir and current_dir ~= "" and current_dir ~= "/" do
    local info = system.get_file_info(current_dir .. "/.git")
    if info and info.type == "dir" then
      return current_dir
    end
    current_dir = common.dirname(current_dir)
  end
  return nil
end

-- getters ------------------------------------------------------------------------------
-- m: current branch
function M.get_branch(filepath, callback)
  enqueue_git_task(function()
    local branch_name = ""
    local repo_root = filepath and get_repo_root(filepath)
    if repo_root then
      branch_name = execute_git(repo_root, { "rev-parse", "--abbrev-ref", "HEAD" }):match("[^\n]+") or ""
    end
    if type(callback) == "function" then
      callback(branch_name)
    end
  end)
end

-- m: stats
function M.get_diff_stats(filepath, callback)
  enqueue_git_task(function()
    local repo_root = filepath and get_repo_root(filepath)
    local added, deleted = 0, 0
    if repo_root and filepath then
      local relpath = filepath:sub(#repo_root + 2) -- remove root + "/"
      local output = execute_git(repo_root, { "diff", "--numstat", relpath })
      for plus, minus in output:gmatch("(%d+)%s+(%d+)") do
        added = added + tonumber(plus)
        deleted = deleted + tonumber(minus)
      end
    end
    if type(callback) == "function" then
      callback(added, deleted)
    end
  end)
end
----------------------------------------------------------------------------------------

return M
