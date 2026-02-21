--- Core alignment algorithm. No Neovim API used here.
--- All state is passed via arguments; no globals.
local M = {}

local utils  = require("align.utils")
local parser = require("align.parser")

local rtrim = utils.rtrim
local pad   = utils.pad

--- Align a table of lines according to opts.
---
--- Returns a new table of lines. The input table is never modified.
---
---@param lines  table   list of strings (0-indexed from nvim_buf_get_lines)
---@param opts   table
---   opts.pattern   string   Lua pattern (required, already validated)
---   opts.padding   integer  spaces between pre and match (default 1)
---   opts.justify   string   "left" | "right" (default "left")
---   opts.max_width integer|nil  skip lines where #rtrim(pre) > max_width
---@return table  new list of aligned strings
function M.align_lines(lines, opts)
  local pattern   = opts.pattern
  local padding   = opts.padding   or 1
  local justify   = opts.justify   or "left"
  local max_width = opts.max_width

  local n = #lines

  -- Phase 1: Parse all lines into segments.
  -- parsed[i] = { segments = {...}, trailing = "...", skip = false } | nil
  local parsed   = {}
  local max_cols = 0

  for i = 1, n do
    local line = lines[i]
    if line ~= "" then
      local segments, trailing = parser.parse_line(line, pattern)
      if segments then
        parsed[i] = { segments = segments, trailing = trailing, skip = false }
        if #segments > max_cols then
          max_cols = #segments
        end
      end
    end
  end

  -- Nothing matched at all — return the original lines unchanged.
  if max_cols == 0 then
    return lines
  end

  -- Phase 2: max_width pre-pass — mark lines to skip.
  if max_width then
    for i = 1, n do
      local p = parsed[i]
      if p and not p.skip then
        for _, seg in ipairs(p.segments) do
          if #rtrim(seg.pre) > max_width then
            p.skip = true
            break
          end
        end
      end
    end
  end

  -- Phase 3: Compute per-column max pre-widths across non-skipped lines.
  -- col_widths[c] = max( #rtrim(seg.pre) ) for column c across all eligible lines.
  local col_widths = {}
  for col = 1, max_cols do
    col_widths[col] = 0
  end

  for i = 1, n do
    local p = parsed[i]
    if p and not p.skip then
      for col, seg in ipairs(p.segments) do
        local w = #rtrim(seg.pre)
        if w > col_widths[col] then
          col_widths[col] = w
        end
      end
    end
  end

  -- Phase 4: Rebuild lines.
  local result = {}
  local concat = table.concat

  for i = 1, n do
    local p = parsed[i]
    if not p or p.skip then
      result[i] = lines[i]
    else
      local parts = {}
      local pi = 0
      for col, seg in ipairs(p.segments) do
        local target = col_widths[col] + padding
        local pre_trimmed = rtrim(seg.pre)
        pi = pi + 1
        parts[pi] = pad(pre_trimmed, target, justify)
        pi = pi + 1
        parts[pi] = seg.match
      end
      pi = pi + 1
      parts[pi] = p.trailing
      result[i] = concat(parts)
    end
  end

  return result
end

return M
