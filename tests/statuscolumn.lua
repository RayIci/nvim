-- Run with: nvim --headless -u NONE -l tests/statuscolumn.lua
--
-- lua/config/statuscolumn.lua: each kind of sign keeps its own column, so
-- error signs from several sources never hide the lightbulb or a breakpoint.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.o.columns, vim.o.lines = 80, 20
vim.o.number, vim.o.relativenumber, vim.o.cursorline = true, true, true
vim.o.signcolumn, vim.o.foldcolumn = "yes", "0"
require("config.statuscolumn").setup()

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.stdout:write("ok " .. passed + failed .. " - " .. name .. "\n")
  else
    failed = failed + 1
    io.stdout:write("not ok " .. passed + failed .. " - " .. name .. "\n" .. err .. "\n")
  end
end

local function equal(expected, actual, what)
  assert(expected == actual, ("%s: expected %q, got %q"):format(what, expected, actual))
end

local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three", "four" })

local function sign(ns_name, row, text, priority, hl)
  local ns = vim.api.nvim_create_namespace(ns_name)
  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { sign_text = text, priority = priority, sign_hl_group = hl })
end

-- Line 2: breakpoint, two sources' errors, a warning, the lightbulb, a git hunk.
sign("dap_breakpoints", 1, "●", 21, "DiagnosticError")
sign("nvim.basedpyright.diagnostic.signs", 1, "E", 13, "DiagnosticSignError")
sign("nvim.mypy.diagnostic.signs", 1, "E", 13, "DiagnosticSignError")
sign("nvim.mypy.diagnostic.signs", 1, "W", 12, "DiagnosticSignWarn")
sign("nvim-lightbulb", 1, "💡", 10, "LightBulbSign")
sign("gitsigns_signs_", 1, "┃", 6, "GitSignsChange")
-- Line 3: only a git sign. Line 4: a sign from an unknown plugin.
sign("gitsigns_signs_", 2, "┃", 6, "GitSignsAdd")
sign("some-plugin", 3, "T", 10)

---The rendered status column of buffer line `lnum`, as on screen.
local function screen_column(lnum)
  vim.cmd.redraw({ bang = true })
  local pos = vim.fn.screenpos(0, lnum, 1)
  local cells = {}
  for c = 1, pos.col - 1 do
    cells[#cells + 1] = vim.fn.screenstring(pos.row, c)
  end
  return table.concat(cells)
end

test("namespaces map to their slots", function()
  local slot = require("config.statuscolumn").slot
  equal("diagnostic", slot("nvim.nvim.lsp.basedpyright.1.basedpyright.diagnostic.signs"), "lsp diagnostic")
  equal("diagnostic", slot("nvim.mypy.diagnostic.signs"), "linter diagnostic")
  equal("action", slot("nvim-lightbulb"), "lightbulb")
  equal("git", slot("gitsigns_signs_staged"), "git")
  equal("debug", slot("dap_breakpoints"), "dap")
  equal("debug", slot(""), "anonymous")
end)

test("every kind of sign shows at once, one error sign for both sources", function()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  -- [debug 2][diagnostic 2][action 2][number 3 + space][git 1]
  equal("● E 💡  1 ┃", screen_column(2), "line 2")
end)

test("empty slots keep their width so columns line up", function()
  equal("        2 ┃", screen_column(3), "line 3 (relative number)")
  for lnum = 1, 4 do
    equal(11, vim.fn.strdisplaywidth(screen_column(lnum)), "width of line " .. lnum)
  end
end)

test("signs from unknown plugins land in the debug slot", function()
  equal("T       3  ", screen_column(4), "line 4")
end)

test("the cursor line shows its absolute number", function()
  equal("        1  ", screen_column(1), "line 1")
end)

test("signcolumn=no drops the sign slots", function()
  vim.wo.signcolumn = "no"
  vim.wo.statuscolumn = vim.wo.statuscolumn -- the column only shrinks when re-set
  equal("  1 ", screen_column(2), "line 2")
  vim.wo.signcolumn = "yes"
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
