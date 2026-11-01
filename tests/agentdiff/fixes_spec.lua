local H = require("helpers")

describe("git metadata and ignored files", function()
  it("never reviews a commit message written in Neovim (Writing a commit message)", function()
    H.write("a.txt", "a\n")
    H.git_repo()
    H.start()
    -- git writes the template, opens Neovim on it, the user writes the message
    H.write(".git/COMMIT_EDITMSG", "\n# Please enter the commit message\n")
    local buf = H.edit(".git/COMMIT_EDITMSG")
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "feat: something" })
    H.save()
    H.poll()
    eq({}, H.pending())
    -- git removes / rewrites it afterwards
    H.write(".git/COMMIT_EDITMSG", "feat: something\n")
    H.poll()
    eq({}, H.pending())
    H.remove(".git/COMMIT_EDITMSG")
    H.poll()
    eq({}, H.pending())
  end)

  it("never reviews ignored files, whoever writes them (Saving an ignored file)", function()
    H.write(".gitignore", "build/\n")
    H.write("build/out.txt", "x\n")
    H.start()
    local buf = H.edit("build/out.txt")
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "mine" })
    H.save()
    H.poll()
    H.write("build/out.txt", "agent\n")
    H.poll()
    eq({}, H.pending())
  end)

  it("drops entries an earlier version stored for such paths", function()
    H.write("a.txt", "a\n")
    H.git_repo()
    local agentdiff = H.start()
    local s = agentdiff._test.session()
    s.store:write("baseline", { { path = ".git/COMMIT_EDITMSG", text = "old\n" } })
    s.store:write("observed", { { path = ".git/COMMIT_EDITMSG", text = "old\n" } })
    agentdiff._test.reset()
    H.start()
    eq(
      { [".git/COMMIT_EDITMSG"] = false },
      agentdiff._test.session().store:read("baseline", { ".git/COMMIT_EDITMSG" })
    )
    eq({}, H.pending())
  end)
end)

describe("discards through git", function()
  before_each(function()
    H.write("t.lua", H.numbered(30))
    H.git_repo()
  end)

  ---The user edits lines in Neovim and saves (their work, in the baseline).
  local function user_saves(changes)
    H.edit("t.lua")
    for line, text in pairs(changes) do
      H.change(line, line, { text })
    end
    H.save()
    H.poll()
    eq({}, H.pending())
  end

  it("treats discarding saved work in a git client as the user's (Discard in a git client)", function()
    H.start()
    user_saves({ [5] = "mine5" })
    H.git({ "checkout", "--", "t.lua" }) -- what lazygit's discard runs
    H.poll()
    eq({}, H.pending())
    eq(H.numbered(30), H.read("t.lua"))
    user_saves({ [9] = "mine9" })
    H.git({ "restore", "t.lua" })
    H.poll()
    eq({}, H.pending())
  end)

  it("discarding one hunk leaves nothing pending, and the agent's region stays (Discard one hunk)", function()
    H.start()
    user_saves({ [5] = "mine5", [25] = "mine25" })
    local saved = H.read("t.lua")
    -- discard only the first hunk, as lazygit's hunk discard (`git apply -R`) does
    H.write("t.lua", (saved:gsub("mine5\n", "l5\n")))
    H.poll()
    eq({}, H.pending())
    -- an agent change elsewhere, then a discard of the user's other hunk
    H.write("t.lua", (H.read("t.lua"):gsub("l15\n", "agent15\n")))
    H.poll()
    eq({ "modified t.lua +1 -1 #1" }, H.pending())
    H.write("t.lua", (H.read("t.lua"):gsub("mine25\n", "l25\n")))
    H.poll()
    eq({ "modified t.lua +1 -1 #1" }, H.pending(), "the agent's change is still pending")
    eq(14, require("agentdiff").files()[1].hunks[1].b_lo)
  end)

  it("still shows an agent edit the agent staged (Staged agent edit still shown)", function()
    H.start()
    H.write("t.lua", (H.numbered(30):gsub("l5\n", "agent5\n")))
    H.git({ "add", "t.lua" })
    H.poll()
    eq({ "modified t.lua +1 -1 #1" }, H.pending())
  end)

  it("still shows an agent edit that reverts the user's saved work", function()
    H.start()
    user_saves({ [5] = "mine5" })
    -- the agent rewrites the line to something that isn't HEAD's content
    H.write("t.lua", (H.read("t.lua"):gsub("mine5\n", "agent5\n")))
    H.poll()
    eq({ "modified t.lua +1 -1 #1" }, H.pending())
  end)
end)

describe("windows are never closed", function()
  local function side_window()
    -- a neo-tree-like side window: closing every other window must not happen
    vim.cmd("topleft 30vnew")
    vim.bo.buftype = "nofile"
    vim.bo.filetype = "neo-tree"
    local w = vim.api.nvim_get_current_win()
    vim.cmd.wincmd("l")
    return w
  end

  it("keeps every window when undoing the only buffer (Undo the only buffer)", function()
    H.write("keep.lua", "k\n")
    local agentdiff = H.start()
    H.write("new.lua", "fresh\n")
    H.poll()
    local buf = H.edit("new.lua")
    local tree = side_window()
    local file_win = vim.api.nvim_get_current_win()
    eq(2, #vim.api.nvim_list_wins())
    agentdiff.undo_file()
    eq(nil, H.read("new.lua"), "file deleted")
    eq(2, #vim.api.nvim_list_wins(), "no window closed")
    ok(vim.api.nvim_win_is_valid(tree) and vim.api.nvim_win_is_valid(file_win))
    ok(vim.api.nvim_win_get_buf(file_win) ~= buf, "the file window shows another buffer")
    ok(not vim.api.nvim_buf_is_valid(buf), "the deleted file's buffer is gone")
  end)

  it("shows the alternate buffer in windows of a deleted file that is kept", function()
    H.write("a.lua", "a\n")
    H.write("gone.lua", "g\n")
    local agentdiff = H.start()
    local a = H.edit("a.lua")
    H.edit("gone.lua")
    vim.cmd("vsplit")
    H.remove("gone.lua")
    vim.cmd("silent! checktime")
    H.poll()
    agentdiff.keep({ scope = "file", path = "gone.lua" })
    eq(2, #vim.api.nvim_list_wins())
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      eq(a, vim.api.nvim_win_get_buf(w))
    end
  end)
end)

describe("on/off toggle", function()
  ---Simulate a restart: tear everything down and set up again.
  local function restart()
    local agentdiff = require("agentdiff")
    agentdiff._test.reset()
    vim.cmd("silent! %bwipeout!")
    agentdiff.setup({
      root = H.project,
      state_dir = H.state .. "/agentdiff",
      poll_interval = 0,
      auto_start = false,
    })
    agentdiff.start()
    return agentdiff
  end

  it("stays off across a restart, and on again after enabling (Off survives restart)", function()
    H.write("a.lua", "a\n")
    local agentdiff = H.start()
    agentdiff.disable()
    eq(false, agentdiff.enabled())
    eq(nil, agentdiff._test.session(), "stopped")
    agentdiff = restart()
    eq(nil, agentdiff._test.session(), "still off after the restart")
    vim.cmd("Agentdiff toggle")
    eq(true, agentdiff.enabled())
    ok(agentdiff._test.wait_ready(5000), "on again")
    agentdiff = restart()
    ok(agentdiff._test.wait_ready(5000), "still on after another restart")
  end)

  it("starts clean when turned back on (Enabling starts clean)", function()
    H.write("mine.lua", "mine\n")
    H.write("theirs.lua", "theirs\n")
    local agentdiff = H.start()
    agentdiff.disable()
    -- while off: the user edits and saves, an agent edits another file
    H.edit("mine.lua")
    H.change(1, 1, { "edited while off" })
    H.save()
    H.write("theirs.lua", "agent while off\n")
    agentdiff.enable()
    ok(agentdiff._test.wait_ready(5000))
    H.poll()
    eq({}, H.pending(), "nothing from the disabled period is pending")
    H.write("theirs.lua", "agent after\n")
    H.poll()
    eq({ "modified theirs.lua +1 -1 #1" }, H.pending(), "later agent changes show as usual")
    -- and a restart doesn't reset again
    agentdiff = restart()
    ok(agentdiff._test.wait_ready(5000))
    eq({ "modified theirs.lua +1 -1 #1" }, H.pending())
  end)
end)
