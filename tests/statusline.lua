-- Run with: nvim --headless -u NONE -l tests/statusline.lua
--
-- Statusline breadcrumbs (plugins/breadcrumbs.lua): the symbol path from a
-- fake document-symbol server, nothing for terminals, and the persisted
-- <leader>ub toggle.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local config = vim.fn.getcwd()
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(config)
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.g.mapleader = " "
local navic_path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/nvim-navic")
assert(navic_path ~= "", "Missing installed test dependency: nvim-navic")
vim.opt.rtp:append(navic_path)

local crumbs = require("plugins.breadcrumbs")
crumbs.setup()

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

local function range(l1, c1, l2, c2)
  return { start = { line = l1, character = c1 }, ["end"] = { line = l2, character = c2 } }
end

local file = root .. "/shape.lua"
vim.fn.writefile({ "local Shape = {}", "function Shape.area()", "  return 1", "end", "return Shape" }, file)
vim.cmd.edit(file)

local symbols = {
  {
    name = "Shape",
    kind = 5, -- Class
    range = range(0, 0, 4, 12),
    selectionRange = range(0, 6, 0, 11),
    children = {
      { name = "area", kind = 6, range = range(1, 0, 3, 3), selectionRange = range(1, 15, 1, 19) }, -- Method
    },
  },
}

local function fake(dispatchers)
  local closing = false
  return {
    request = function(method, _, callback, notify_reply)
      local result = method == "initialize" and { capabilities = { documentSymbolProvider = true } }
        or method == "textDocument/documentSymbol" and symbols
        or {}
      vim.schedule(function()
        if notify_reply then
          notify_reply(1)
        end
        callback(nil, result, 1)
      end)
      return true, 1
    end,
    notify = function(method)
      if method == "exit" then
        dispatchers.on_exit(0, 15)
      end
      return true
    end,
    is_closing = function()
      return closing
    end,
    terminate = function()
      closing = true
    end,
  }
end
local id = assert(vim.lsp.start({ name = "fake", cmd = fake, root_dir = root }, { bufnr = 0 }))

test("the breadcrumb shows the class and method around the cursor", function()
  vim.api.nvim_win_set_cursor(0, { 3, 2 })
  local text
  assert(vim.wait(3000, function()
    vim.api.nvim_exec_autocmds("CursorHold", {})
    text = crumbs.component()
    return text:find("Shape" .. crumbs.separator, 1, true) ~= nil and text:find("area", 1, true) ~= nil
  end, 50), "breadcrumb was: " .. tostring(text))
end)

test("terminal buffers show no breadcrumb", function()
  local editing = vim.api.nvim_get_current_buf()
  vim.cmd.terminal()
  assert(vim.bo.buftype == "terminal")
  assert(crumbs.component() == "", "breadcrumb in a terminal")
  vim.api.nvim_set_current_buf(editing)
end)

test("<leader>ub turns breadcrumbs off, and they stay off after a restart", function()
  vim.api.nvim_feedkeys(vim.keycode("<leader>ub"), "mx", false)
  assert(crumbs.component() == "", "still shown after the toggle")
  local result = vim.system({
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "--cmd",
    "set rtp^=" .. config,
    "-c",
    "lua io.stdout:write(tostring(require('plugins.breadcrumbs').enabled()))",
    "-c",
    "qa!",
  }, { text = true, env = { XDG_STATE_HOME = root .. "/state" } }):wait(10000)
  assert(result.stdout == "false", "restarted instance reads: " .. result.stdout .. result.stderr)
end)

vim.lsp.get_client_by_id(id):stop(true)
io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
