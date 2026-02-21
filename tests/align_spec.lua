--- Test suite for align-regexp-vim using plenary.busted.
---
--- Run with:
---   :PlenaryBustedFile tests/align_spec.lua
--- or via CLI:
---   nvim --headless -c "PlenaryBustedFile tests/align_spec.lua"

local core   = require("align.core")
local parser = require("align.parser")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Build opts merging defaults with overrides.
local function make_opts(overrides)
  return vim.tbl_extend("force", {
    pattern = "=",
    padding = 1,
    justify = "left",
  }, overrides or {})
end

-- ---------------------------------------------------------------------------
-- parser.parse_line
-- ---------------------------------------------------------------------------

describe("parser.parse_line", function()
  it("returns nil, nil when pattern does not match", function()
    local segs, trail = parser.parse_line("no match here", "=")
    assert.is_nil(segs)
    assert.is_nil(trail)
  end)

  it("returns single segment for one match", function()
    local segs, trail = parser.parse_line("foo = bar", "=")
    assert.are.equal(1, #segs)
    assert.are.equal("foo ", segs[1].pre)
    assert.are.equal("=", segs[1].match)
    assert.are.equal(" bar", trail)
  end)

  it("returns multiple segments for multiple matches", function()
    local segs, trail = parser.parse_line("a = b = c", "=")
    assert.are.equal(2, #segs)
    assert.are.equal("a ", segs[1].pre)
    assert.are.equal("=", segs[1].match)
    assert.are.equal(" b ", segs[2].pre)
    assert.are.equal("=", segs[2].match)
    assert.are.equal(" c", trail)
  end)

  it("handles match at start of line (empty pre)", function()
    local segs, trail = parser.parse_line("=foo", "=")
    assert.are.equal(1, #segs)
    assert.are.equal("", segs[1].pre)
    assert.are.equal("=", segs[1].match)
    assert.are.equal("foo", trail)
  end)
end)

-- ---------------------------------------------------------------------------
-- core.align_lines — basic alignment
-- ---------------------------------------------------------------------------

describe("core.align_lines — simple = alignment", function()
  it("aligns a basic block of assignments", function()
    local lines = {
      "foo = 1",
      "longer_name = 2",
      "x = 3",
    }
    local result = core.align_lines(lines, make_opts())
    -- "longer_name" is 11 chars; padding=1 → target=12
    assert.are.equal("foo         = 1", result[1])
    assert.are.equal("longer_name = 2", result[2])
    assert.are.equal("x           = 3", result[3])
  end)

  it("leaves non-matching lines unchanged", function()
    local lines = {
      "foo = 1",
      "this line has no delimiter",
      "bar = 2",
    }
    local result = core.align_lines(lines, make_opts())
    assert.are.equal("this line has no delimiter", result[2])
    -- matching lines still aligned relative to each other
    assert.are.equal("foo = 1", result[1])
    assert.are.equal("bar = 2", result[3])
  end)

  it("skips empty lines without error", function()
    local lines = {
      "a = 1",
      "",
      "bb = 2",
    }
    local result = core.align_lines(lines, make_opts())
    assert.are.equal("", result[2])
    assert.are.equal("a  = 1", result[1])
    assert.are.equal("bb = 2", result[3])
  end)

  it("returns original lines when nothing matches", function()
    local lines = { "alpha", "beta", "gamma" }
    local result = core.align_lines(lines, make_opts())
    assert.are.same(lines, result)
  end)
end)

-- ---------------------------------------------------------------------------
-- core.align_lines — multi-column
-- ---------------------------------------------------------------------------

describe("core.align_lines — multi-column alignment", function()
  it("aligns two = columns independently", function()
    local lines = {
      "a = b = c",
      "longer = short = end",
    }
    local result = core.align_lines(lines, make_opts())
    -- col1: rtrim("a ") = "a" → 1; rtrim("longer ") = "longer" → 6; max=6, target=7
    -- col2: rtrim(" b ") = " b" → 2; rtrim(" short ") = " short" → 6; max=6, target=7
    --   (rtrim removes only trailing spaces; leading space in " b" is preserved)
    -- line1: pad("a",7) .. "=" .. pad(" b",7) .. "=" .. " c"
    --      = "a      " .. "=" .. " b     " .. "=" .. " c"
    assert.are.equal("a      = b     = c",   result[1])
    assert.are.equal("longer = short = end", result[2])
  end)
end)

-- ---------------------------------------------------------------------------
-- core.align_lines — padding option
-- ---------------------------------------------------------------------------

describe("core.align_lines — padding option", function()
  it("padding=0 produces no space between pre and match", function()
    local lines = { "foo = 1", "b = 2" }
    local result = core.align_lines(lines, make_opts({ padding = 0 }))
    -- col1 max pre: max(#"foo", #"b") = 3, target = 3+0 = 3
    assert.are.equal("foo= 1", result[1])
    assert.are.equal("b  = 2", result[2])
  end)

  it("padding=2 inserts two spaces before match", function()
    local lines = { "a = 1", "bb = 2" }
    local result = core.align_lines(lines, make_opts({ padding = 2 }))
    -- col1 max pre: max(#"a", #"bb") = 2; target = 2+2 = 4
    -- pad("a",  4) → "a   " (3 trailing spaces)
    -- pad("bb", 4) → "bb  " (2 trailing spaces)
    assert.are.equal("a   = 1", result[1])
    assert.are.equal("bb  = 2", result[2])
  end)
end)

-- ---------------------------------------------------------------------------
-- core.align_lines — justify option
-- ---------------------------------------------------------------------------

describe("core.align_lines — justify option", function()
  it("justify=right produces leading spaces before pre-match text", function()
    local lines = { "foo = 1", "b = 2" }
    local result = core.align_lines(lines, make_opts({ justify = "right" }))
    -- col1 max pre: max(#"foo", #"b") = 3; target = 3+1 = 4
    -- pad("foo", 4, "right") → spaces = rep(" ", 1) → " foo"
    -- pad("b",   4, "right") → spaces = rep(" ", 3) → "   b"
    assert.are.equal(" foo = 1", result[1])
    assert.are.equal("   b = 2", result[2])
  end)
end)

-- ---------------------------------------------------------------------------
-- core.align_lines — max_width option
-- ---------------------------------------------------------------------------

describe("core.align_lines — max_width option", function()
  it("skips lines where pre-match exceeds max_width", function()
    local lines = {
      "short = 1",
      "a_very_long_pre_match = 2",
      "ok = 3",
    }
    -- max_width=5: "short" (5) is OK, "a_very_long_pre_match" (21) is too long, "ok" (2) is OK
    local result = core.align_lines(lines, make_opts({ max_width = 5 }))
    -- skipped line is unchanged
    assert.are.equal("a_very_long_pre_match = 2", result[2])
    -- remaining lines aligned against each other (max pre among non-skipped: "short"=5, "ok"=2 → 5)
    assert.are.equal("short = 1", result[1])
    assert.are.equal("ok    = 3", result[3])
  end)
end)

-- ---------------------------------------------------------------------------
-- Idempotency
-- ---------------------------------------------------------------------------

describe("idempotency", function()
  it("running align twice produces the same result", function()
    local lines = {
      "alpha = 1",
      "b = 2",
      "gamma = 3",
    }
    local opts   = make_opts()
    local first  = core.align_lines(lines, opts)
    local second = core.align_lines(first, opts)
    assert.are.same(first, second)
  end)
end)

-- ---------------------------------------------------------------------------
-- Large file simulation
-- ---------------------------------------------------------------------------

describe("large file simulation", function()
  it("aligns 10000 lines without error", function()
    local lines = {}
    for i = 1, 10000 do
      lines[i] = "var_" .. i .. " = " .. i
    end
    local result = core.align_lines(lines, make_opts())
    assert.are.equal(10000, #result)
    -- Spot-check: every resulting line contains " = "
    for i = 1, 10000 do
      assert.truthy(result[i]:find(" = "), "line " .. i .. " should contain ' = '")
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- init.align — integration (requires buffer)
-- ---------------------------------------------------------------------------

describe("init.align — buffer integration", function()
  local align = require("align")

  local function set_buf_lines(lines)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf
  end

  local function get_buf_lines(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  it("aligns current buffer with no range (whole buffer)", function()
    local input = { "foo = 1", "longer_name = 2" }
    local buf = set_buf_lines(input)
    align.align({ pattern = "=" })
    local result = get_buf_lines(buf)
    assert.are.equal("foo         = 1", result[1])
    assert.are.equal("longer_name = 2", result[2])
  end)

  it("respects explicit range and leaves other lines unchanged", function()
    local input = { "ignored = 99", "foo = 1", "longer_name = 2", "also_ignored = 0" }
    local buf = set_buf_lines(input)
    align.align({ pattern = "=", range = { 1, 3 } })  -- lines 2-3 (0-indexed)
    local result = get_buf_lines(buf)
    assert.are.equal("ignored = 99",      result[1])  -- unchanged
    assert.are.equal("foo         = 1",   result[2])  -- aligned
    assert.are.equal("longer_name = 2",   result[3])  -- aligned
    assert.are.equal("also_ignored = 0",  result[4])  -- unchanged
  end)

  it("does not modify buffer on invalid pattern", function()
    local input = { "foo = 1", "bar = 2" }
    local buf = set_buf_lines(input)
    align.align({ pattern = "[unclosed" })
    local result = get_buf_lines(buf)
    -- Buffer must be unchanged
    assert.are.same(input, result)
  end)

  it("does not modify buffer on empty pattern", function()
    local input = { "foo = 1" }
    local buf = set_buf_lines(input)
    align.align({ pattern = "" })
    local result = get_buf_lines(buf)
    assert.are.same(input, result)
  end)
end)
