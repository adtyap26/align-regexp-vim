# align-regexp-vim

A robust, production-quality Neovim alignment plugin written in Lua, inspired by Emacs' `align-regexp`.

Align any block of text on a delimiter pattern — `=`, `:=`, `|`, `->`, `,`, and more — with a single command.

---

## Features

- Align on any **Lua pattern** delimiter
- Works on visual selections, explicit line ranges, or the entire buffer
- Supports **multi-column alignment** (multiple delimiters per line)
- Preserves indentation and original whitespace
- Configurable padding, justification, and max-width guard
- No external dependencies — pure Lua, Neovim 0.9+
- Single atomic buffer write per invocation (no flicker, undo-friendly)
- O(n × m) algorithm — fast on large files (10k+ lines)

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "adtyap26/align-regexp-vim",
  config = function()
    -- No setup() required. The :Align command is registered automatically.
    -- Add keymaps here if desired (see Keymap Examples below).
  end,
}
```

---

## Quick Start

Open any file, select lines in visual mode, then:

```
:'<,'>Align =
```

Or align the entire buffer:

```
:Align =
```

Align Go `:=` assignments:

```
:Align :=
```

Align a pipe-separated table:

```
:'<,'>Align %|
```

---

## Lua Pattern Reference

The plugin uses Lua's built-in `string.find` as the pattern engine. Lua special characters must be escaped with `%`.

| Goal                    | Pattern   | Notes                        |
|-------------------------|-----------|------------------------------|
| Align on `=`            | `=`       |                              |
| Align on `:=`           | `:=`      |                              |
| Align on `:`            | `:`       |                              |
| Align on `->`           | `%->`     | `-` is a special char        |
| Align on `\|` (pipe)    | `%|`      | `|` is a special char        |
| Align on `,`            | `,`       |                              |
| Align on `.`            | `%.`      | `.` matches any char raw     |
| Align on whitespace     | `%s+`     | one or more spaces/tabs      |
| Align on `=>`           | `=>`      |                              |
| Align on `::`           | `::`      |                              |

**Lua special characters that need `%` escaping:** `. + - * ? [ ] ^ $ ( ) %`

---

## Options

All options are passed as a table to `require("align").align(opts)`:

| Option       | Type            | Default  | Description                                                         |
|--------------|-----------------|----------|---------------------------------------------------------------------|
| `pattern`    | `string`        | required | A Lua pattern string used as the alignment delimiter                |
| `padding`    | `integer`       | `1`      | Number of spaces to insert between pre-match text and the delimiter |
| `justify`    | `"left"/"right"`| `"left"` | `"left"`: trailing spaces; `"right"`: leading spaces               |
| `max_width`  | `integer\|nil`  | `nil`    | Skip lines where pre-match width exceeds this value                 |
| `ignore_case`| `boolean`       | `false`  | **Not supported** — emits a warning; has no effect                  |
| `range`      | `{int, int}\|nil`| `nil`  | `{start, end}` 0-indexed, exclusive end; `nil` = entire buffer     |

### `padding`

```lua
require("align").align({ pattern = "=", padding = 0 })  -- no space before delimiter
require("align").align({ pattern = "=", padding = 2 })  -- two spaces before delimiter
```

### `justify`

```lua
-- "left" (default): text flush-left, trailing spaces fill the column
-- a    = 1
-- long = 2

-- "right": text flush-right, leading spaces fill the column
--    a = 1
-- long = 2
```

### `max_width`

Lines where the pre-match text exceeds `max_width` characters are left unchanged and excluded from the column-width calculation:

```lua
require("align").align({ pattern = "=", max_width = 20 })
```

---

## Command Usage

### `:Align {pattern}`

Range-aware user command. Works with visual selections automatically.

```vim
" Align entire buffer on =
:Align =

" Align lines 5–12
:5,12Align :=

" Align visual selection
:'<,'>Align %|
```

---

## Lua API

```lua
require("align").align(opts)
```

### Full example

```lua
require("align").align({
  pattern   = "=",
  padding   = 1,
  justify   = "left",
  max_width = 40,
  range     = { 0, 10 },  -- align first 10 lines (0-indexed)
})
```

---

## Keymap Examples

These keymaps are **not set automatically** — add them to your config as desired.

### Fixed pattern (`=`)

```lua
vim.keymap.set("v", "<leader>a", function()
  local s = vim.fn.line("v")
  local e = vim.fn.line(".")
  if s > e then s, e = e, s end
  require("align").align({
    pattern = "=",
    range   = { s - 1, e },
  })
end, { desc = "Align selection on =" })
```

### Prompt-based (asks for pattern)

```lua
vim.keymap.set("v", "<leader>A", function()
  local pattern = vim.fn.input("Align pattern: ")
  if pattern == "" then return end
  local s = vim.fn.line("v")
  local e = vim.fn.line(".")
  if s > e then s, e = e, s end
  require("align").align({
    pattern = pattern,
    range   = { s - 1, e },
  })
end, { desc = "Align selection on pattern" })
```

---

## Known Limitations

### No alternation

`foo|bar` in a Lua pattern matches the **literal string** `foo|bar`, not `foo` or `bar`. Use two separate `:Align` calls:

```vim
:'<,'>Align foo
:'<,'>Align bar
```

### No `ignore_case`

`ignore_case = true` is accepted but has no effect and emits a warning. Case-insensitive matching is not available with Lua patterns. A future `vim.regex` backend may add this.

### No lazy quantifiers

Lua patterns do not support `+?` or `*?`. Use specific patterns instead of overly broad ones.

### No lookahead/lookbehind

Lua patterns have no `(?=...)` or `(?<!...)` syntax.

### Tabs preserved in content

Tabs in line content are never converted to spaces. The `display_width` utility exists for tab-aware width measurement but the core alignment engine operates on byte positions. Tab content is written back unchanged.

### String literal protection

The plugin does not skip alignment inside string literals or comments without Treesitter. This is intentional — reliable string boundary detection without a language parser is not feasible.

---

## Performance Notes

- A single `nvim_buf_set_lines` call is issued per `:Align` invocation — no line-by-line writes.
- The algorithm is **O(n × m)** where `n` = number of lines in range and `m` = maximum matches per line. For a single delimiter, this is effectively O(n).
- All width computation is done in one forward pass before any rebuilding.
- `table.concat` is used per line; no repeated string concatenation in the hot path.
- `local` references cache `string.find`, `string.rep`, `string.sub` in tight loops.

---

## Running Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (`plenary.busted`).

### Inside Neovim

```vim
:PlenaryBustedFile tests/align_spec.lua
```

### Headless CLI

```sh
nvim --headless -c "PlenaryBustedFile tests/align_spec.lua"
```

### With lazy.nvim dev setup

Ensure `align-regexp-vim` is on your `runtimepath`:

```lua
vim.opt.rtp:prepend("/path/to/align-regexp-vim")
```

---

## Architecture

```
align-regexp-vim/
├── lua/
│   └── align/
│       ├── init.lua    -- public API, option validation, buffer I/O
│       ├── core.lua    -- alignment algorithm (pure Lua, no Neovim API)
│       ├── parser.lua  -- line parsing and match extraction
│       └── utils.lua   -- string helpers (rtrim, pad, display_width)
├── plugin/
│   └── align.lua       -- :Align user command registration
├── tests/
│   └── align_spec.lua  -- plenary.busted test suite
└── README.md
```

Each module has a single clear responsibility. `core.lua` and `parser.lua` have no Neovim API dependency and can be unit-tested outside of a buffer context.

---

## License

MIT
