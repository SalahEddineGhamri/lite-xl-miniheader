-- Author: S.Ghamri
-- mod-version:3
local core = require "core"
local View = require "core.view"
local style = require "core.style"
local git = require((...) .. ".git_utils")
local config = require "core.config"

------------------------------------------------------------------------------
-- TODO: define faces for the minibuffer. each section can use different color
-- TODO: make sections optional

-- DONE: remove sporadic movement due formating. reserve space
-- DONE: add config
-- DONE: revise how git process is opened
------------------------------------------------------------------------------

config.plugins.header = {
  git_interval = 1.0,
  height = 35,
  show_time = false
  -- TODO: add show options for all sections
}

local last_git_time = 0
local git_status = {}

local TitleView = require "core.titleview"

local original_new = TitleView.new
local original_update = TitleView.update
local original_draw = TitleView.draw

function TitleView:new()
  original_new(self)
  self.size.y = config.plugins.header.height
end

function TitleView:update()
  original_update(self)
  self.size.y = config.plugins.header.height
end

local function shorten_path(path, max_len)
  if not path or #path <= max_len then return path end 

  path = path:gsub("\\", "/")

  local home = os.getenv("HOME")
  if home and path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end

  local parts = {}
  local prev_part
  for part in path:gmatch("[^/]+") do
    if prev_part then
      local first = prev_part:sub(1, 1)
      if first == "." then
        table.insert(parts, prev_part:sub(1, 2))
      else
        table.insert(parts, first)
      end
    end
    prev_part = part
  end

  table.insert(parts, prev_part)
  local shortened = table.concat(parts, "/")
  return shortened
end
 
local function register_git_branch(branch_name, filename)
  git_status[filename] = git_status[filename] or {}  
  if branch_name ~= "" then
    git_status[filename].branch = string.format(" %s", branch_name)
  else
    git_status[filename].branch = ""
  end
end

local function register_git_stat(plus, minus, filename)
  git_status[filename] = git_status[filename] or {}  
  git_status[filename].plus = plus or 0
  git_status[filename].minus = minus or 0
end

local function padded_num(n, width)
  if n == 0 then
    return string.rep(" ", width)
  else
    local s = tostring(n)
    return string.rep(" ", width - #s) .. s
  end
end

function TitleView:draw()
  original_draw(self)
  local x, y, w, h = self:get_content_bounds()

  local is_modified = false
  local doc_name = "No Document"

  if core.active_view and core.active_view.doc then
    is_modified = core.active_view.doc:is_dirty()
    doc_name = core.active_view.doc:get_name()
  end

  -- m: colors
  -- TODO: define a table of colors for each section
  local bg_color, fg_color
  if is_modified then
    bg_color = style.background
    fg_color = style.accent or style.text
  else
    bg_color = style.background
    fg_color = style.text
  end

  renderer.draw_rect(x, y, w, h, bg_color)

  local time_str = (config.plugins.header.show_time and os.date("%H:%M:%S")) or ""

  local buffer_path = "[No File]"
  if core.active_view and core.active_view.doc and core.active_view.doc.abs_filename then
    buffer_path = shorten_path(core.active_view.doc.abs_filename, 40)
  end

  if is_modified then
    buffer_path = "  ● " .. buffer_path
  else
    buffer_path = "    " .. buffer_path
  end

  local location = ""
  if core.active_view and core.active_view.doc then
    local line, col = core.active_view.doc:get_selection()
    location = string.format("L%s C%s", padded_num(line, 3), padded_num(col, 2))
  end

  local position = ""
  if core.active_view and core.active_view.doc then
    local line, _ = core.active_view.doc:get_selection()
    local total_lines = #core.active_view.doc.lines
    local percent = math.floor(((line - 1) / total_lines) * 100) + 1
    position = string.format("%s%%", padded_num(percent, 3))
  end

  local file_encoding = ""
  if core.active_view and core.active_view.doc then
    file_encoding = core.active_view.doc.encoding or "utf-8"
  end

  local syntax_name = ""
  if core.active_view and core.active_view.doc and core.active_view.doc.syntax then
    syntax_name = core.active_view.doc.syntax.name or ""
  end

  -- m: git related
  if core.active_view and core.active_view.doc and core.active_view.doc.abs_filename then
    local file = core.active_view.doc.abs_filename

    local now = system.get_time()
    if (now - last_git_time < config.plugins.header.git_interval) then
        git.get_branch(file, function(branch) register_git_branch(branch, file) end)
        git.get_diff_stats(file, function(plus, minus)  register_git_stat(plus, minus, file) end)
    end

    last_git_time = now
  end


  local left_parts = {}
  if time_str ~= "" then table.insert(left_parts, time_str) end 
  table.insert(left_parts, buffer_path)
  local left_section = table.concat(left_parts, " ")

  local right_parts = {}

  local file = core.active_view and core.active_view.doc and core.active_view.doc.abs_filename
  local info = git_status[file] or {}
  local added = info.plus or 0
  local deleted = info.minus or 0
  local git_branch = info.branch
  local git_stat = (added ~= 0 and deleted ~=0 and string.format("+%d/-%d", added, deleted)) or "" 

  if git_branch ~= "" then table.insert(right_parts, git_branch) end
  if git_stat ~= "" then table.insert(right_parts, git_stat) end
  if syntax_name ~= "" then table.insert(right_parts, syntax_name) end
  if file_encoding ~= "" then table.insert(right_parts, file_encoding) end
  if location ~= "" then table.insert(right_parts, location) end
  if position ~= "" then table.insert(right_parts, position) end
  local right_section = table.concat(right_parts, " ")

  local font = style.font
  renderer.draw_text(font, left_section, x + 10, y + (h - font:get_height()) / 2, fg_color)

  if right_section ~= "" then
    local text_w = font:get_width(right_section)
    renderer.draw_text(font, right_section, x + w - text_w - 10, y + (h - font:get_height()) / 2, fg_color)
  end
end

core.show_title_bar(true)


