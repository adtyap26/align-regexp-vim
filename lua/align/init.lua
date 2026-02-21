--- Public API for the align plugin.
--- Entry point: require("align").align(opts)
local M = {}

local core = require("align.core")

local DEFAULTS = {
  padding     = 1,
  justify     = "left",
  ignore_case = false,
}

--- Align lines in the current buffer.
---
---@param opts table
---   opts.pattern    string         required; a Lua pattern string
---   opts.padding    integer        spaces to insert between pre-match and match (default 1)
---   opts.justify    string         "left" | "right" (default "left")
---   opts.max_width  integer|nil    skip lines where pre-match width exceeds this
---   opts.ignore_case boolean       not supported; emits a warning (default false)
---   opts.range      table|nil      {start, finish} 0-indexed; nil = entire buffer
function M.align(opts)
  opts = vim.tbl_extend("force", DEFAULTS, opts or {})

  -- Validate: pattern is required.
  if not opts.pattern or opts.pattern == "" then
    vim.notify("[align] pattern is required", vim.log.levels.ERROR)
    return
  end

  -- Warn about unsupported ignore_case.
  if opts.ignore_case then
    vim.notify(
      "[align] ignore_case is not supported with Lua patterns and has no effect",
      vim.log.levels.WARN
    )
  end

  -- Validate pattern: catch malformed Lua patterns before touching the buffer.
  local ok, err = pcall(string.find, "", opts.pattern)
  if not ok then
    vim.notify("[align] invalid pattern: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local buf   = vim.api.nvim_get_current_buf()
  local total = vim.api.nvim_buf_line_count(buf)

  -- Resolve range (0-indexed, exclusive end — same convention as nvim_buf_get_lines).
  local start_line, end_line
  if opts.range then
    start_line = math.max(0, opts.range[1])
    end_line   = math.min(total, opts.range[2])
  else
    start_line = 0
    end_line   = total
  end

  -- Guard: nothing to do.
  if start_line >= end_line then
    return
  end

  local lines  = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
  local result = core.align_lines(lines, opts)

  -- Single atomic write — never line-by-line.
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, result)
end

return M
