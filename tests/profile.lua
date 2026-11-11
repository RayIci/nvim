-- Run with: nvim --headless -u NONE -l tests/profile.lua
--
-- config.profile: autocmd timing that keeps callback semantics, LSP request
-- accounting from LspRequest, process counting across the three spawn paths,
-- Lua sampling attributed to plugin modules, snapshots, reset and comparison.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.NVIM_PROFILE = "1"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"

local profile = require("config.profile")
profile.setup()
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

test("commands exist only when enabled", function()
  equal(2, vim.fn.exists(":ProfileReport"))
  equal(2, vim.fn.exists(":ProfileReset"))
  equal(2, vim.fn.exists(":ProfileCompare"))
end)

test("a callback returning true still deletes its autocmd and is counted", function()
  local group = vim.api.nvim_create_augroup("test.profile", { clear = true })
  local runs = 0
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "ProfileTest",
    callback = function()
      runs = runs + 1
      return true
    end,
  })
  vim.api.nvim_exec_autocmds("User", { pattern = "ProfileTest" })
  vim.api.nvim_exec_autocmds("User", { pattern = "ProfileTest" })
  equal(1, runs)
  local t = profile.data().autocmds["User\0test.profile"]
  assert(t, "no timing recorded")
  equal(1, t.count)
end)

test("LSP requests are counted per client and method", function()
  local function fake(dispatchers)
    local closing, id = false, 0
    return {
      -- notify_reply is what real RPC calls when a reply arrives; the client
      -- fires LspRequest "complete" from it.
      request = function(method, _, callback, notify_reply)
        id = id + 1
        local rid = id
        if method == "initialize" then
          callback(nil, { capabilities = { hoverProvider = true } })
        elseif method == "shutdown" then
          callback(nil, nil)
        else
          vim.defer_fn(function()
            if notify_reply then
              notify_reply(rid)
            end
            callback(nil, {}, rid)
          end, 5)
        end
        return true, rid
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
  local buf = vim.api.nvim_get_current_buf()
  local id = assert(vim.lsp.start({ name = "fake", cmd = fake, root_dir = root }, { bufnr = buf }))
  local client = assert(vim.lsp.get_client_by_id(id))
  assert(vim.wait(2000, function()
    return client.initialized
  end, 10), "fake server did not initialize")
  local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 0 } }
  client:request("textDocument/hover", params, function() end, buf)
  client:request("textDocument/hover", params, function() end, buf)
  assert(vim.wait(2000, function()
    local stat = profile.data().lsp["fake\0textDocument/hover"]
    return stat ~= nil and stat.count == 2
  end, 10), "hover requests not counted: " .. vim.inspect(profile.data().lsp))
  client:stop(true)
end)

test("processes are counted across uv.spawn, vim.system and jobstart", function()
  local done = 0
  vim.uv.spawn("true", {}, function()
    done = done + 1
  end)
  vim.system({ "true" }):wait()
  vim.fn.jobwait({ vim.fn.jobstart({ "true" }) })
  assert(vim.wait(2000, function()
    local t = profile.data().procs["true"]
    return t ~= nil and t.count == 3
  end, 10), "spawns not counted: " .. vim.inspect(profile.data().procs))
  assert(vim.wait(1000, function()
    return done == 1
  end, 10), "original uv.spawn exit callback did not run")
end)

test("sampled Lua time is attributed to the plugin that ran", function()
  local dir = root .. "/site/pack/core/opt/fakeplug/lua"
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({
    "local M = {}",
    "function M.spin(ms)",
    "  local stop, x = vim.uv.hrtime() + ms * 1e6, 0",
    "  while vim.uv.hrtime() < stop do x = x + math.sin(x) end",
    "  return x",
    "end",
    "return M",
  }, dir .. "/fakeplug.lua")
  package.path = dir .. "/?.lua;" .. package.path
  require("fakeplug").spin(300)
  local samples = profile.data().modules.fakeplug or 0
  assert(samples > 0, "no samples for fakeplug: " .. vim.inspect(profile.data().modules))
  equal("fakeplug", profile.module_of(dir .. "/fakeplug.lua"))
end)

test(":ProfileReport opens the report and writes a decodable snapshot", function()
  vim.cmd.ProfileReport()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(lines[1]:match("^Profile "), lines[1])
  assert(vim.bo.readonly and not vim.bo.modifiable, "report buffer is editable")
  local files = vim.fn.globpath(vim.fn.stdpath("state") .. "/profile", "*.json", false, true)
  equal(1, #files)
  local snap = vim.json.decode(table.concat(vim.fn.readfile(files[1]), "\n"))
  for _, key in ipairs({ "autocmds", "lsp", "procs", "modules", "facts", "uptime_s" }) do
    assert(snap[key] ~= nil, "snapshot lacks " .. key)
  end
  assert(snap.facts.runtimepath_entries > 0)
  vim.cmd.tabclose()
end)

test(":ProfileReset zeroes every counter and restarts uptime", function()
  vim.cmd.ProfileReset()
  local snap = profile.snapshot()
  equal({}, snap.autocmds)
  equal({}, snap.lsp)
  equal({}, snap.procs)
  assert(snap.uptime_s < 1, "uptime not restarted: " .. snap.uptime_s)
end)

test("comparison shows both per-hour values and their difference", function()
  local a = {
    appname = "nvim",
    created = "A",
    uptime_s = 3600,
    autocmds = { { event = "CursorMoved", group = "illuminate", count = 10, total = 120, max = 1 } },
    lsp = {},
    procs = { { name = "mypy", count = 40, total = 8000, max = 300 } },
    modules = {},
  }
  local b = {
    appname = "nvim-new",
    created = "B",
    uptime_s = 7200,
    autocmds = {},
    lsp = {},
    procs = { { name = "mypy", count = 20, total = 4000, max = 300 } },
    modules = {},
  }
  local lines = profile.compare_lines(a, b)
  local text = table.concat(lines, "\n")
  local row = text:match("proc mypy count[^\n]*")
  assert(row, text)
  local va, vb, diff = row:match("([%-%d.]+)%s+([%-%d.]+)%s+([%+%-][%d.]+)$")
  equal({ "40.0", "10.0", "-30.0" }, { va, vb, diff })
  assert(text:match("autocmd CursorMoved illuminate ms%s+120.0%s+0.0%s+%-120.0"), text)
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
