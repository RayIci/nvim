-- Run with: nvim --headless -u NONE -l tests/lsp-diagnostic-fix.lua
--
-- plugins/lsp-diagnostic-fix.lua: vim.lsp.diagnostic.from() must always return
-- complete lsp.Diagnostics, even when a producer (nvim-lint) left only a
-- partial `user_data.lsp` such as `{ code = "arg-type" }`.
vim.opt.rtp:prepend(vim.fn.getcwd())
require("plugins.lsp-diagnostic-fix").setup()

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
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(what, vim.inspect(expected), vim.inspect(actual)))
end

---@return vim.Diagnostic
local function diag(user_data)
  return {
    lnum = 150, col = 26, end_lnum = 150, end_col = 29,
    severity = vim.diagnostic.severity.ERROR,
    message = '"Task" has no attribute "i"', source = "mypy", code = "attr-defined",
    user_data = user_data,
  }
end

test("a partial user_data.lsp (nvim-lint) is completed from the diagnostic", function()
  local lsp = vim.lsp.diagnostic.from({ diag({ lsp = { code = "attr-defined" } }) })[1]
  equal({ start = { line = 150, character = 26 }, ["end"] = { line = 150, character = 29 } }, lsp.range, "range")
  equal('"Task" has no attribute "i"', lsp.message, "message")
  equal("attr-defined", lsp.code, "code")
  equal("mypy", lsp.source, "source")
  equal(1, lsp.severity, "severity")
end)

test("fields the producer set win over the rebuilt ones", function()
  local href = { href = "https://example.invalid/attr-defined" }
  local lsp = vim.lsp.diagnostic.from({ diag({ lsp = { code = "custom", codeDescription = href } }) })[1]
  equal("custom", lsp.code, "code")
  equal(href, lsp.codeDescription, "codeDescription")
  assert(lsp.range, "range missing")
end)

test("a complete user_data.lsp (an LSP server's own) is returned unchanged", function()
  local original = {
    range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 5 } },
    message = "from the server", severity = 2, data = { fix = true },
  }
  local lsp = vim.lsp.diagnostic.from({ diag({ lsp = original }) })[1]
  assert(lsp == original, "server diagnostic was replaced")
end)

test("diagnostics without user_data keep the built-in conversion", function()
  local lsp = vim.lsp.diagnostic.from({ diag(nil), diag({ lsp = { code = "x" } }) })
  equal(2, #lsp, "count")
  equal(lsp[1].range, lsp[2].range, "range")
  equal("attr-defined", lsp[1].code, "code")
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
