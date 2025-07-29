-- mod-version:3
local core = require "core"
local View = require "core.view"
local style = require "core.style"

-- Override the TitleView class entirely
local TitleView = require "core.titleview"

-- Save original methods
local original_new = TitleView.new
local original_update = TitleView.update
local original_draw = TitleView.draw

-- Override the constructor
function TitleView:new()
  original_new(self)
  self.size.y = 35  -- Set our desired height
end

-- Override the update method
function TitleView:update()
  original_update(self)
  self.size.y = 35  -- Keep our height
end

-- Override the draw method with our MiniHeader functionality
function TitleView:draw()
  original_draw(self)
  local x, y, w, h = self:get_content_bounds()
  
  -- Determine if current view is active and if document is modified
  local is_modified = false
  local doc_name = "No Document"
  
  if core.active_view and core.active_view.doc then
    is_modified = core.active_view.doc:is_dirty()
    doc_name = core.active_view.doc:get_name()
  end
  
  -- Choose colors based on modified state
  local bg_color, fg_color
  if is_modified then
    bg_color = style.line_highlight or style.background2
    fg_color = style.accent or style.text
  else
    bg_color = style.background2
    fg_color = style.text
  end
  
  -- Draw background
  renderer.draw_rect(x, y, w, h, bg_color)
  
  -- Get current time
  local time_str = os.date("%H:%M:%S")
  
  -- Cleanly truncate middle of long paths, preserving head/tail
  local function shorten_path(path, max_len)
  if not path or #path <= max_len then return path end

  -- Normalize path separators
  path = path:gsub("\\", "/")

  local parts = {}
  for part in path:gmatch("[^/]+") do
      table.insert(parts, part)
  end

  if #parts <= 2 then
      return "..." .. path:sub(-max_len + 3)
  end

  local first = parts[1]
  local last = parts[#parts]
  local shortened = string.format("%s/.../%s", first, last)

  if #shortened <= max_len then
      return shortened
  else
      -- fallback to tail-only truncation
      return "..." .. path:sub(-max_len + 3)
  end
  end
  
  local buffer_path = "[No File]"
  if core.active_view and core.active_view.doc and core.active_view.doc.abs_filename then
  buffer_path = shorten_path(core.active_view.doc.abs_filename, 40)
  end
  
  -- Add modified indicator
  if is_modified then
    buffer_path = " ● "
  end
  
  -- Get current line and column
  local location = ""
  if core.active_view and core.active_view.doc then
    local line, col = core.active_view.doc:get_selection()
    location = string.format("L%d C%d", line, col)
  end
  
  -- Get position percentage
  local position = ""
  if core.active_view and core.active_view.doc then
    local line, _ = core.active_view.doc:get_selection()
    local total_lines = #core.active_view.doc.lines
    local percent = math.floor((line / total_lines) * 100)
    position = string.format("%d%%", percent)
  end
  
  -- Get file type/syntax
  local syntax_name = ""
  if core.active_view and core.active_view.doc and core.active_view.doc.syntax then
    syntax_name = core.active_view.doc.syntax.name or ""
  end
  
  -- Build left section
  local left_parts = {}
  table.insert(left_parts, time_str)
  table.insert(left_parts, buffer_path)
  local left_section = table.concat(left_parts, " ")
  
  -- Build right section
  local right_parts = {}
  if syntax_name ~= "" then table.insert(right_parts, syntax_name) end
  if location ~= "" then table.insert(right_parts, location) end
  if position ~= "" then table.insert(right_parts, position) end
  local right_section = table.concat(right_parts, " ")
  
  -- Draw left section
  local font = style.font
  renderer.draw_text(font, left_section, x + 10, y + (h - font:get_height()) / 2, fg_color)
  
  -- Draw right section (right-aligned)
  if right_section ~= "" then
    local text_w = font:get_width(right_section)
    renderer.draw_text(font, right_section, x + w - text_w - 10, y + (h - font:get_height()) / 2, fg_color)
  end
end

-- Make sure the title view is always visible
core.show_title_bar(true)
