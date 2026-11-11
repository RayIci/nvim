-- Run with: nvim --headless -u NONE -l tests/state.lua
--
-- config.state: per-project paths in the existing on-disk format, missing vs
-- empty files, and the saver's guards against late or misdirected writes.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"

local state = require("config.state")
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

---Let timers and scheduled callbacks run for `ms`.
local function wait(ms)
  vim.wait(ms, function()
    return false
  end, 10)
end

local project = root .. "/my project"
vim.fn.mkdir(project, "p")
vim.fn.mkdir(root .. "/other", "p")
vim.api.nvim_set_current_dir(project)

test("paths keep the historical cwd key", function()
  -- The key every existing workspaces/ and neotree/ file was written with.
  local legacy = (project:gsub("[/\\:]", "%%"))
  equal(vim.fs.joinpath(vim.fn.stdpath("state"), "workspaces", legacy .. ".json"), state.path("workspaces"))
  equal(state.path("neotree", project), state.path("neotree"))
end)

test("reads files written in the current format", function()
  local path = state.path("workspaces")
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ '{"breakpoints":{},"buffers":["/a.lua"],"pinned":"/a.lua"}' }, path)
  local value, exists = state.read(path, {})
  assert(exists)
  equal({ "/a.lua" }, value.buffers)
  equal("/a.lua", value.pinned)
end)

test("missing is distinct from empty, and damaged files raise", function()
  local missing = root .. "/nope/missing.json"
  local value, exists = state.read(missing, { default = true })
  equal({ default = true }, value)
  equal(false, exists)

  local empty = root .. "/empty/state.json"
  state.write(empty, { buffers = {} })
  value, exists = state.read(empty, { default = true })
  equal(true, exists)
  equal({ buffers = {} }, value)

  vim.fn.writefile({ "{not json" }, empty)
  assert(not pcall(state.read, empty, {}), "damaged file must raise")
end)

---A saver recording each write's cwd.
local function recording(delay)
  local writes = {}
  local saver = state.saver({
    label = "test",
    delay = delay or 50,
    save = function(cwd)
      writes[#writes + 1] = cwd
    end,
  })
  return saver, writes
end

test("touch writes once after the debounce", function()
  local saver, writes = recording()
  saver.touch()
  saver.touch()
  equal({}, writes)
  wait(150)
  equal({ project }, writes)
end)

test("pause drops a pending write and ignores later touches until resume", function()
  local saver, writes = recording()
  saver.touch()
  saver.pause()
  saver.touch()
  wait(150)
  equal({}, writes)
  saver.resume()
  saver.touch()
  wait(150)
  equal({ project }, writes)
end)

test("a pending write never lands after the cwd changed", function()
  local saver, writes = recording()
  saver.touch()
  vim.api.nvim_set_current_dir(root .. "/other")
  wait(150)
  vim.api.nvim_set_current_dir(project)
  equal({}, writes)
end)

test("invalidate drops pending writes and deferred callbacks", function()
  local saver, writes = recording()
  local deferred = false
  saver.touch()
  saver.defer(function()
    deferred = true
  end, 50)
  saver.invalidate()
  wait(150)
  equal({}, writes)
  equal(false, deferred)
  assert(saver.active(), "invalidate must not pause")
end)

test("deferred callbacks run when nothing changed", function()
  local saver = recording()
  local deferred = false
  saver.defer(function()
    deferred = true
  end, 20)
  wait(100)
  equal(true, deferred)
end)

test("flush writes immediately, cancels the pending write and propagates errors", function()
  local saver, writes = recording()
  saver.touch()
  saver.flush()
  equal({ project }, writes)
  wait(150)
  equal({ project }, writes)

  local failing = state.saver({
    label = "test",
    save = function()
      error("disk full", 0)
    end,
  })
  local ok, err = pcall(failing.flush)
  equal(false, ok)
  equal("disk full", err)
end)

test("exit writes once unless paused, and later touches are ignored", function()
  local saver, writes = recording()
  saver.exit()
  equal({ project }, writes)
  saver.touch()
  wait(150)
  equal({ project }, writes)
  assert(not saver.active())

  local paused, none = recording()
  paused.pause()
  paused.exit()
  equal({}, none)
end)

test("errors from debounced writes are reported, not raised", function()
  local messages = {}
  local notify = vim.notify
  vim.notify = function(message) ---@diagnostic disable-line: duplicate-set-field
    messages[#messages + 1] = message
  end
  local saver = state.saver({
    label = "Workspace save",
    delay = 10,
    save = function()
      error("boom", 0)
    end,
  })
  saver.touch()
  wait(100)
  vim.notify = notify
  equal({ "Workspace save: boom" }, messages)
end)

vim.fn.delete(root, "rf")
io.stdout:write(("%s %d state tests\n"):format(failed == 0 and "Passed" or "Failed", passed + failed))
if failed > 0 then
  vim.cmd.cquit(1)
end
vim.cmd.qall({ bang = true })
