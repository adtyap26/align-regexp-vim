--- Line parsing and match extraction using Lua patterns.
local M = {}

--- Parse a single line into segments using the given Lua pattern.
---
--- Returns two values:
---   segments  table of {pre, match} pairs, or nil if no matches
---   trailing  the remainder of the line after the last match, or nil
---
--- Each segment:
---   pre   (string) text before the match start
---   match (string) the matched text
---
---@param line string
---@param pattern string  a Lua pattern (string.find compatible)
---@return table|nil segments
---@return string|nil trailing
function M.parse_line(line, pattern)
  local segments = {}
  local pos = 1
  local find = string.find
  local sub = string.sub

  while true do
    local s, e = find(line, pattern, pos)
    if not s then
      break
    end
    -- Guard against zero-length matches to prevent infinite loops.
    if e < s then
      e = s
    end
    segments[#segments + 1] = {
      pre   = sub(line, pos, s - 1),
      match = sub(line, s, e),
    }
    pos = e + 1
  end

  if #segments == 0 then
    return nil, nil
  end

  return segments, line:sub(pos)
end

return M
