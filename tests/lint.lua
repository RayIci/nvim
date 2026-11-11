-- Run with: nvim --headless -u NONE -l tests/lint.lua
--
-- Lint triggers (plugins/lint.lua): open and save always lint; entering a
-- buffer or leaving insert mode lints only after a change; typing never does.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"
local lint_path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/nvim-lint")
assert(lint_path ~= "", "Missing installed test dependency: nvim-lint")
vim.opt.rtp:append(lint_path)
vim.cmd("filetype on")

local lint = require("lint")
local runs = 0
local try_lint = lint.try_lint
-- Count calls that start the stub linter (the lua buffer's), not calls for
-- buffers without linters, which start nothing.
lint.try_lint = function(...)
  if vim.bo.filetype == "lua" then
    runs = runs + 1
  end
  return try_lint(...)
end
lint.linters.stub = { cmd = "true", stdin = false, ignore_exitcode = true, parser = function() return {} end }
require("plugins.lint").apply({ lua = { "stub" } })

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
  assert(expected == actual, ("%s: expected %s, got %s"):format(what or "runs", expected, actual))
end

local a, b = root .. "/a.lua", root .. "/b.txt"
vim.fn.writefile({ "local x = 1" }, a)
vim.fn.writefile({ "plain" }, b)

test("opening a buffer lints it once", function()
  vim.cmd.edit(a)
  equal(1, runs)
end)

test("leaving insert mode without an edit does not lint", function()
  vim.api.nvim_feedkeys(vim.keycode("i<Esc>"), "nx", false)
  equal(1, runs)
end)

test("re-entering an unchanged buffer does not lint", function()
  vim.cmd.edit(b)
  vim.cmd.edit(a)
  equal(1, runs)
end)

test("typing never lints", function()
  vim.api.nvim_buf_set_lines(0, 1, 1, false, { "local y = 2" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
  vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 })
  equal(1, runs)
end)

test("leaving insert mode after an edit lints once", function()
  vim.api.nvim_feedkeys(vim.keycode("ozz<Esc>"), "nx", false)
  equal(2, runs)
end)

test("re-entering a buffer changed since its last lint lints it", function()
  vim.cmd.edit(b)
  -- changed while hidden (e.g. a plugin or a replace across files)
  vim.api.nvim_buf_set_lines(vim.fn.bufnr(a), 0, 0, false, { "-- changed elsewhere" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = vim.fn.bufnr(a) })
  vim.cmd.edit(a)
  equal(3, runs)
end)

test("saving always lints", function()
  vim.cmd.write()
  equal(4, runs)
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
