-- Run with: nvim --headless -u NONE -l tests/conflicts.lua
--
-- Guided conflict resolution (lua/config/conflicts/, plugins/conflicts.lua):
-- operation and role detection for merge, rebase, cherry-pick, revert and
-- stash pop; role labels; inline keys by role; the resolve view (whole sides,
-- single lines, reorder, hand edit, undo); the conflict center; next steps;
-- the statusline; and no git process while nothing is in progress.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.g.mapleader = " "

local state = require("config.conflicts.state")
local markers = require("config.conflicts.markers")
local inline = require("config.conflicts.inline")
local resolve = require("config.conflicts.resolve")
local center = require("config.conflicts.center")
-- plugins.conflicts registers a statusline widget; a stub stands in for lualine.
package.loaded["plugins.lualine"] = { register = function() end }
require("plugins.conflicts").setup()

local notes = {}
vim.notify = function(msg)
  notes[#notes + 1] = tostring(msg)
end
local function notified(pattern)
  for _, n in ipairs(notes) do
    if n:find(pattern) then
      return true
    end
  end
  return false
end

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
  resolve.close()
  vim.cmd("silent! %bwipeout!")
end

local function equal(expected, actual, what)
  assert(
    vim.deep_equal(expected, actual),
    ("%s: expected %s, got %s"):format(what or "value", vim.inspect(expected), vim.inspect(actual))
  )
end

local function git(cwd, ...)
  local r = vim.system({ "git", "-C", cwd, ... }, { text = true }):wait()
  return vim.trim(r.stdout), r.code
end

local n = 0
---A repo with `file` = base, branch `feature` changing it to `ours`, `main`
---changing it to `theirs`; returns its path, checked out on `checkout`.
local function repo(base, feature, main_lines, checkout)
  n = n + 1
  local dir = root .. "/repo" .. n
  vim.fn.mkdir(dir, "p")
  git(dir, "init", "-q", "-b", "main")
  git(dir, "config", "user.email", "t@t")
  git(dir, "config", "user.name", "t")
  git(dir, "config", "merge.conflictStyle", "merge")
  vim.fn.writefile(base, dir .. "/f.txt")
  git(dir, "add", ".")
  git(dir, "commit", "-qm", "init")
  git(dir, "checkout", "-qb", "feature")
  vim.fn.writefile(feature, dir .. "/f.txt")
  git(dir, "commit", "-qam", "fix login")
  git(dir, "checkout", "-q", "main")
  vim.fn.writefile(main_lines, dir .. "/f.txt")
  git(dir, "commit", "-qam", "use fetch")
  git(dir, "checkout", "-q", checkout)
  return dir
end

local function cd(dir)
  vim.api.nvim_set_current_dir(dir)
  state.refresh(dir)
end

-- ===========================================================================
-- 1. Operation state and roles
-- ===========================================================================

test("merge: yours is the current branch, incoming the merged one", function()
  local dir = repo({ "a" }, { "feature" }, { "main" }, "feature")
  git(dir, "merge", "main")
  cd(dir)
  local info = assert(state.current)
  equal("merge", info.op)
  equal("feature", info.yours.name)
  equal("main", info.incoming.name)
  equal({ dir .. "/f.txt" }, info.files)
  equal("MERGING main into feature", state.summary())
end)

test("rebase: yours is your commit being replayed, incoming the branch you rebase onto", function()
  local dir = repo({ "a" }, { "feature" }, { "main" }, "feature")
  git(dir, "rebase", "main")
  cd(dir)
  local info = assert(state.current)
  equal("rebase", info.op)
  equal("feature", info.yours.name)
  assert(info.yours.detail:find('your commit %x+ "fix login"'), info.yours.detail)
  equal("main", info.incoming.name)
  equal({ 1, 1 }, { info.step, info.total })
  equal("theirs", state.section("yours"))
  equal("ours", state.section("incoming"))
  local explain = center.explain_lines()
  assert(vim.tbl_contains(explain, '  "ours"   = the <<<<<<< (top) side    = INCOMING'), vim.inspect(explain))
  assert(vim.tbl_contains(explain, '  "theirs" = the >>>>>>> (bottom) side = YOURS'), vim.inspect(explain))
end)

test("cherry-pick, revert and stash pop are detected with their roles", function()
  local dir = repo({ "a" }, { "feature" }, { "main" }, "main")
  git(dir, "cherry-pick", "feature")
  cd(dir)
  equal("cherry-pick", state.current.op)
  equal("main", state.current.yours.name)
  assert(state.current.incoming.detail:find("fix login"), state.current.incoming.detail)
  git(dir, "cherry-pick", "--abort")

  local rdir = repo({ "a" }, { "feature" }, { "main" }, "main")
  vim.fn.writefile({ "after" }, rdir .. "/f.txt")
  git(rdir, "commit", "-qam", "after")
  git(rdir, "revert", "--no-edit", "HEAD~1")
  cd(rdir)
  equal("revert", state.current.op)

  local sdir = repo({ "a" }, { "feature" }, { "main" }, "main")
  vim.fn.writefile({ "stashed" }, sdir .. "/f.txt")
  git(sdir, "stash", "-q")
  vim.fn.writefile({ "committed" }, sdir .. "/f.txt")
  git(sdir, "commit", "-qam", "committed")
  git(sdir, "stash", "pop")
  cd(sdir)
  equal("stash", state.current.op)
  equal("stash", state.current.incoming.name)
end)

test("no git process runs while nothing is in progress", function()
  local dir = root .. "/clean"
  vim.fn.mkdir(dir, "p")
  git(dir, "init", "-q")
  local spawns = 0
  local spawn = vim.uv.spawn
  vim.uv.spawn = function(path, ...)
    if vim.fs.basename(path) == "git" then
      spawns = spawns + 1
    end
    return spawn(path, ...)
  end
  vim.api.nvim_set_current_dir(dir)
  for _, ev in ipairs({ "FocusGained", "TermLeave", "DirChanged" }) do
    vim.api.nvim_exec_autocmds(ev, { modeline = false })
  end
  vim.cmd.edit(dir .. "/x.txt")
  vim.uv.spawn = spawn
  equal(nil, state.current)
  equal(0, spawns, "git spawns")
end)

-- ===========================================================================
-- 2. Inline marking and keys
-- ===========================================================================

---Text of the end-of-line labels on each line of `buf`.
local function labels(buf)
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
    local vt = m[4].virt_text
    if vt then
      out[m[2] + 1] = vt[1][1]
    end
  end
  return out
end

test("rebase labels name your commit YOURS although git calls it theirs", function()
  local dir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(dir, "rebase", "main")
  cd(dir)
  vim.cmd.edit(dir .. "/f.txt")
  local buf = vim.api.nvim_get_current_buf()
  assert(inline.attached[buf], "conflicted buffer not attached")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local l = labels(buf)
  local c = markers.in_buffer(buf)[1]
  equal("upstream", lines[c.start + 2])
  assert(l[c.start + 1]:find("INCOMING · main"), l[c.start + 1])
  assert(l[c.sep + 1]:find("YOURS · feature"), l[c.sep + 1])
end)

test("<leader>gCo keeps your lines in a rebase and in a merge, with branch names in descriptions", function()
  local dir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(dir, "rebase", "main")
  cd(dir)
  vim.cmd.edit(dir .. "/f.txt")
  equal("Keep yours (feature)", vim.fn.maparg(" gCo", "n", false, true).desc)
  equal("Take incoming (main)", vim.fn.maparg(" gCt", "n", false, true).desc)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<leader>gCo"), "mx", false)
  equal({ "mine" }, vim.api.nvim_buf_get_lines(0, 0, -1, false), "rebase")

  local mdir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(mdir, "merge", "main")
  cd(mdir)
  vim.cmd.edit(mdir .. "/f.txt")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<leader>gCo"), "mx", false)
  equal({ "mine" }, vim.api.nvim_buf_get_lines(0, 0, -1, false), "merge")
  assert(notified("no conflicts left"), vim.inspect(notes))
end)

test("files outside an operation get no conflict marks", function()
  local dir = root .. "/docs"
  vim.fn.mkdir(dir, "p")
  git(dir, "init", "-q")
  vim.fn.writefile({ "```", "<<<<<<< HEAD", "a", "=======", "b", ">>>>>>> x", "```" }, dir .. "/README.md")
  cd(dir)
  vim.cmd.edit(dir .. "/README.md")
  equal(nil, inline.attached[vim.api.nvim_get_current_buf()])
  equal({}, labels(0))
end)

-- ===========================================================================
-- 3. Resolve view
-- ===========================================================================

---A merge-shaped fake operation over a hand-written conflicted file.
local function fake(lines)
  local dir = root .. "/fake" .. vim.uv.hrtime()
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/f.lua"
  vim.fn.writefile(lines, file)
  state.current = {
    op = "merge",
    root = dir,
    git_dir = dir .. "/.git",
    yours = { name = "feature", detail = "your branch" },
    incoming = { name = "main", detail = "being merged in" },
    files = { file },
  }
  vim.cmd.edit(file)
  inline.attach(vim.api.nvim_get_current_buf())
  return vim.api.nvim_get_current_buf()
end

local three = {
  "<<<<<<< HEAD",
  "y1",
  "=======",
  "i1",
  ">>>>>>> main",
  "mid",
  "<<<<<<< HEAD",
  "y2",
  "=======",
  "i2",
  ">>>>>>> main",
  "<<<<<<< HEAD",
  "y3",
  "=======",
  "i3",
  ">>>>>>> main",
}

test("o <CR> t <CR> b <CR> resolves three conflicts; u restores the last", function()
  local buf = fake(three)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  resolve.open()
  vim.api.nvim_set_current_win(resolve.view.wins.yours)
  vim.api.nvim_feedkeys(vim.keycode("o<CR>t<CR>b<CR>"), "mx", false)
  equal({ "y1", "mid", "i2", "y3", "i3" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  equal(nil, resolve.view.conflict, "view reports the file resolved")
  vim.api.nvim_feedkeys("u", "mx", false)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  equal({ "y1", "mid", "i2", "<<<<<<< HEAD", "y3", "=======", "i3", ">>>>>>> main" }, lines)
  equal(1, #markers.in_buffer(buf))
end)

test("the preview shows the choice before the file changes", function()
  local buf = fake(three)
  resolve.open()
  vim.api.nvim_set_current_win(resolve.view.wins.yours)
  vim.api.nvim_feedkeys("t", "mx", false)
  local preview = vim.api.nvim_buf_get_lines(resolve.view.bufs.result, 0, -1, false)
  equal({ "i1", "mid" }, { preview[1], preview[2] })
  equal(three, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "file untouched")
end)

test("keeping A1 and B2 and moving B2 up applies B2, A1", function()
  local buf = fake({ "<<<<<<< HEAD", "A1", "A2", "=======", "B1", "B2", ">>>>>>> main" })
  resolve.open()
  local v = resolve.view
  vim.api.nvim_set_current_win(v.wins.yours)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(" ", "mx", false)
  vim.api.nvim_set_current_win(v.wins.incoming)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys(" K", "mx", false)
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "mx", false)
  equal({ "B2", "A1" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
end)

test("a hand-edited result is written as edited", function()
  local buf = fake({ "<<<<<<< HEAD", "A", "=======", "B", ">>>>>>> main" })
  resolve.open()
  vim.api.nvim_set_current_win(resolve.view.wins.yours)
  vim.api.nvim_feedkeys("b", "mx", false)
  resolve.edit()
  vim.api.nvim_buf_set_lines(0, 1, 2, false, { "B edited" })
  vim.api.nvim_feedkeys("q", "mx", false)
  vim.api.nvim_set_current_win(resolve.view.wins.result)
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "mx", false)
  equal({ "A", "B edited" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
end)

test("applying with nothing chosen is refused", function()
  local buf = fake({ "<<<<<<< HEAD", "A", "=======", "B", ">>>>>>> main" })
  resolve.open()
  vim.api.nvim_set_current_win(resolve.view.wins.result)
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "mx", false)
  equal(1, #markers.in_buffer(buf))
  assert(notified("Nothing chosen yet"), vim.inspect(notes))
end)

-- ===========================================================================
-- 4. Conflict center, next steps, statusline
-- ===========================================================================

test("the center states the merge and lists files with their counts", function()
  local dir = repo({ "x", "y" }, { "x1", "y" }, { "x2", "y" }, "feature")
  vim.fn.writefile({ "o" }, dir .. "/g.txt")
  git(dir, "add", ".")
  git(dir, "commit", "-qm", "g")
  git(dir, "merge", "main")
  cd(dir)
  local lines = center.lines()
  equal("MERGING main into feature", lines[1])
  assert(vim.tbl_contains(lines, "  f.txt (1)"), vim.inspect(lines))
end)

test("without an operation the center says there is nothing to resolve", function()
  local dir = root .. "/clean2"
  vim.fn.mkdir(dir, "p")
  git(dir, "init", "-q")
  vim.api.nvim_set_current_dir(dir)
  center.open()
  assert(notified("Nothing to resolve"), vim.inspect(notes))
end)

test("staging with markers and continuing with unresolved files are refused", function()
  local dir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(dir, "rebase", "main")
  cd(dir)
  vim.cmd.edit(dir .. "/f.txt")
  center.stage()
  assert(notified("still has 1 conflict"), vim.inspect(notes))
  center.continue()
  assert(notified("still conflicted"), vim.inspect(notes))
  equal("rebase", state.current.op)
end)

test("a fully resolved rebase continues to completion", function()
  local dir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(dir, "rebase", "main")
  cd(dir)
  vim.cmd.edit(dir .. "/f.txt")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  inline.choose("yours")
  vim.cmd.write()
  center.stage()
  assert(notified("<leader>gCc to continue"), vim.inspect(notes))
  center.continue()
  equal(nil, state.current)
  local log = git(dir, "log", "--format=%s")
  equal("fix login\nuse fetch\ninit", log)
end)

test("declining the abort confirmation leaves the operation in progress", function()
  local dir = repo({ "x" }, { "mine" }, { "upstream" }, "feature")
  git(dir, "merge", "main")
  cd(dir)
  local confirm = vim.fn.confirm
  vim.fn.confirm = function()
    return 2
  end
  center.abort()
  vim.fn.confirm = confirm
  equal("merge", state.current.op)
  local _, code = git(dir, "rev-parse", "-q", "--verify", "MERGE_HEAD")
  equal(0, code, "MERGE_HEAD still there")
end)

test("the statusline shows the operation, its progress and the files", function()
  state.current = {
    op = "rebase",
    root = root,
    git_dir = root,
    step = 2,
    total = 5,
    yours = { name = "feature" },
    incoming = { name = "main" },
    files = { "a", "b", "c" },
  }
  equal("⚔ REBASE 2/5 · 3 files", state.status())
  state.current = nil
  equal("", state.status())
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
