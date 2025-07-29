-- mod-version:3
local core = require "core"
local View = require "core.view"
local style = require "core.style"

-- TODO: find a way to make sections optional in config
-- TODO: add git section
-- TODO: correct short path format 

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
  
  -- show path in short format
  -- TODO: adapt for windows
  local function shorten_path(path, max_len)
    if not path or #path <= max_len then return path end -- shorten only long paths

    -- Normalize path separators
    path = path:gsub("\\", "/")

    -- Normalize Home
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
  
  local buffer_path = "[No File]"
  if core.active_view and core.active_view.doc and core.active_view.doc.abs_filename then
  buffer_path = shorten_path(core.active_view.doc.abs_filename, 40)
  end
  
  -- Add modified indicator
  if is_modified then
    buffer_path = " ● " .. buffer_path 
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
