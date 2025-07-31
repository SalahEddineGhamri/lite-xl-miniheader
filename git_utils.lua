local core = require "core"
local common = require "core.common"
local system = require "system"
local process = require "process"

local function execute_git(repo_root, args_table)
  local command = { "git", "-C", repo_root }
  for _, arg in ipairs(args_table) do table.insert(command, arg) end

  local git_process = process.start(command)
  if not git_process then
    core.error("git: failed to start process for %s, cmd: %s", repo_root, table.concat(command, " "))
    return ""
  end

  while git_process:running() do coroutine.yield(0.1) end

  local stdout_output = git_process:read_stdout() or ""
  local stderr_output = git_process:read_stderr() or ""
  local exit_code = git_process:wait()

  if exit_code ~= 0 then
    core.warn("git: command failed (%d) for %s, cmd: %s", exit_code, repo_root, table.concat(command, " "))
    if #stderr_output > 0 then core.warn("git: stderr: %s", stderr_output:match("^[^\n]+")) end
    return ""
  end
  return stdout_output
end

local function get_repo_root(filepath)
  if not filepath then return nil end
  local current_dir = common.dirname(filepath)
  while current_dir and current_dir ~= "" and current_dir ~= "/" do
    if system.get_file_info(current_dir .. "/.git") then return current_dir end
    current_dir = common.dirname(current_dir)
  end
  return nil
end

local M = {}

-- TODO: we can get more then branch name
function M.get_branch(filepath, callback)
  core.add_thread(function()
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

return M
