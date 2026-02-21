--- Neovim user command registration for align-regexp-vim.
--- Provides :Align {pattern} with visual-range support.

vim.api.nvim_create_user_command("Align", function(opts)
  require("align").align({
    pattern = opts.args,
    -- opts.line1 and opts.line2 are 1-indexed (Vim convention).
    -- Subtract 1 from line1 to convert to 0-indexed for nvim_buf_get_lines.
    -- line2 is already the correct exclusive end.
    range = { opts.line1 - 1, opts.line2 },
  })
end, {
  range  = true,
  nargs  = 1,
  desc   = "Align lines on a Lua pattern delimiter",
})
