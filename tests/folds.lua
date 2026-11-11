-- Run with: nvim --headless -u NONE -l tests/folds.lua
--
-- config/folds.lua: per-buffer fold providers (LSP > Tree-sitter > indent),
-- native fold commands, and files opening unfolded.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"
require("config.options")
local folds = require("config.folds")
folds.setup()

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

local function equal(expected, actual)
  assert(
    vim.deep_equal(expected, actual),
    ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual))
  )
end

local lua_file = root .. "/code.lua"
vim.fn.writefile({
  "local M = {}",
  "function M.a()",
  "  if true then",
  "    return 1",
  "  end",
  "end",
  "function M.b()",
  "  return 2",
  "end",
  "return M",
}, lua_file)

test("a buffer without parser or server folds by indent", function()
  local txt = root .. "/notes.txt"
  vim.fn.writefile({ "a", "  b", "  c", "d" }, txt)
  vim.cmd.edit(txt)
  equal("indent", vim.wo.foldmethod)
  equal(nil, vim.b.fold_provider)
end)

test("a buffer with an active parser gets the Tree-sitter foldexpr", function()
  vim.cmd.edit(lua_file)
  vim.treesitter.start(0, "lua")
  folds.use(0, "treesitter")
  equal("expr", vim.wo.foldmethod)
  equal("v:lua.vim.treesitter.foldexpr()", vim.wo.foldexpr)
end)

test("the provider follows the buffer into a new window", function()
  vim.cmd.split()
  equal("v:lua.vim.treesitter.foldexpr()", vim.wo.foldexpr)
  vim.cmd.close()
end)

test("a server with folding ranges switches the buffer to the LSP foldexpr", function()
  local function fake(dispatchers)
    local closing = false
    return {
      request = function(method, _, callback, notify_reply)
        local result = method == "initialize" and { capabilities = { foldingRangeProvider = true } } or {}
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
    return vim.b.fold_provider == "lsp"
  end, 10), "LspAttach did not switch the provider")
  equal("v:lua.vim.lsp.foldexpr()", vim.wo.foldexpr)
  -- Tree-sitter (lower rank) never takes it back.
  folds.use(0, "treesitter")
  equal("v:lua.vim.lsp.foldexpr()", vim.wo.foldexpr)
  vim.lsp.get_client_by_id(id):stop(true)
end)

test("zM and zR close and reopen folds; new files open unfolded", function()
  vim.cmd.edit({ args = { lua_file }, bang = true })
  vim.wo.foldmethod = "indent"
  vim.bo.shiftwidth = 2 -- the fixture's indent unit
  vim.cmd("normal! zM")
  assert(vim.fn.foldclosed(3) ~= -1, "zM left the nested fold open")
  vim.cmd("normal! zR")
  equal(-1, vim.fn.foldclosed(3))
  local other = root .. "/other.lua"
  vim.fn.writefile({ "local x = 1", "if x then", "  x = 2", "end" }, other)
  vim.cmd.edit(other)
  equal(99, vim.wo.foldlevel)
  equal(-1, vim.fn.foldclosed(3))
end)

test("zU is mapped", function()
  equal("Close child folds", vim.fn.maparg("zU", "n", false, true).desc)
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
