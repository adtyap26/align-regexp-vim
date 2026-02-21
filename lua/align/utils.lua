--- Pure string utility functions. No Neovim API used here.
local M = {}

--- Strip trailing whitespace from s.
---@param s string
---@return string
function M.rtrim(s)
  return (s:gsub("%s+$", ""))
end

--- Pad s to at least `width` characters.
--- Never truncates. justify = "left" adds trailing spaces; "right" adds leading spaces.
---@param s string
---@param width integer
---@param justify string  "left" | "right"
---@return string
function M.pad(s, width, justify)
  local len = #s
  if len >= width then
    return s
  end
  local spaces = string.rep(" ", width - len)
  if justify == "right" then
    return spaces .. s
  else
    return s .. spaces
  end
end

--- Measure the visual display width of s, expanding tabs to the next tabstop.
--- Used for tab-aware width measurement only; never modifies content.
---@param s string
---@param tabstop integer  default 8
---@return integer
function M.display_width(s, tabstop)
  tabstop = tabstop or 8
  local width = 0
  for i = 1, #s do
    local c = s:sub(i, i)
    if c == "\t" then
      width = width + (tabstop - (width % tabstop))
    else
      width = width + 1
    end
  end
  return width
end

return M
