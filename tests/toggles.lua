-- Run with: nvim --headless -u NONE -l tests/toggles.lua
--
-- Persisted display toggles: <leader>ul (lightbulb), <leader>li (inlay
-- hints) and <leader>lct (code lenses) write their pref, apply to the open
-- buffer at once, and are restored by a fresh instance.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local config = vim.fn.getcwd()
local state = root .. "/state"
vim.env.XDG_STATE_HOME = state
vim.opt.rtp:prepend(config)
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.g.mapleader = " "

local deps = { "nvim-lightbulb", "blink.cmp" }
local paths = {}
for _, name in ipairs(deps) do
  local path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing installed test dependency: " .. name)
  vim.opt.rtp:append(path)
  paths[#paths + 1] = path
end

require("plugins.lightbulb").setup()
require("plugins.lsp").setup()

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
  assert(
    vim.deep_equal(expected, actual),
    ("%s: expected %s, got %s"):format(what or "value", vim.inspect(expected), vim.inspect(actual))
  )
end

---Run `lua` in a fresh instance with the same state dir and return its output.
local function fresh(lua)
  local cmd = { vim.v.progpath, "--headless", "-u", "NONE", "--cmd", "set rtp^=" .. config }
  for _, p in ipairs(paths) do
    vim.list_extend(cmd, { "--cmd", "set rtp+=" .. p })
  end
  vim.list_extend(cmd, { "-c", "lua " .. lua, "-c", "qa!" })
  local result = vim.system(cmd, { text = true, env = { XDG_STATE_HOME = state } }):wait(10000)
  return result.stdout .. result.stderr
end

local function lightbulb_hooks()
  return #vim.api.nvim_get_autocmds({ group = "LightBulb", event = "CursorHold" })
end

local file = root .. "/a.lua"
vim.fn.writefile({ "local x = 1" }, file)
vim.cmd.edit(file)
local function fake(dispatchers)
  local closing = false
  return {
    request = function(method, _, callback, notify_reply)
      local result = method == "initialize"
          and { capabilities = { codeLensProvider = {}, inlayHintProvider = true, codeActionProvider = true } }
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
assert(vim.wait(2000, function()
  return vim.fn.maparg(" lct", "n", false, true).buffer == 1
end, 10), "LSP keymaps not attached")

test("<leader>ul turns the lightbulb off now and after a restart", function()
  assert(lightbulb_hooks() > 0, "lightbulb not on by default")
  vim.api.nvim_feedkeys(vim.keycode("<leader>ul"), "mx", false)
  equal(0, lightbulb_hooks(), "CursorHold hooks after toggle")
  equal(false, require("config.prefs").get("lightbulb", true), "pref")
  local out = fresh(
    "require('plugins.lightbulb').setup() io.stdout:write(#vim.api.nvim_get_autocmds({ group = 'LightBulb', event = 'CursorHold' }))"
  )
  equal("0", out, "hooks in a fresh instance")
end)

test("<leader>li turns inlay hints on now and after a restart", function()
  equal(false, vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), "default")
  vim.api.nvim_feedkeys(vim.keycode("<leader>li"), "mx", false)
  equal(true, vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), "after toggle")
  local out = fresh("require('plugins.lsp').setup() io.stdout:write(tostring(vim.lsp.inlay_hint.is_enabled()))")
  equal("true", out, "fresh instance")
end)

test("<leader>lct turns code lenses off now and in a fresh instance", function()
  equal(true, vim.lsp.codelens.is_enabled({ bufnr = 0 }), "default")
  vim.api.nvim_feedkeys(vim.keycode("<leader>lct"), "mx", false)
  equal(false, vim.lsp.codelens.is_enabled({ bufnr = 0 }), "after toggle")
  local out = fresh("io.stdout:write(tostring(require('plugins.lsp').codelens_enabled()))")
  equal("false", out, "fresh instance")
end)

vim.lsp.get_client_by_id(id):stop(true)
io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
