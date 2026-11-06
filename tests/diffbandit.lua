-- Run with: nvim --headless -u NONE -l tests/diffbandit.lua
--
-- The configuration's diffbandit wiring against the installed plugins: lazy
-- configuration, the <leader>gx keys and the in-view `-` key, closing every
-- view, and keeping views out of worktree switches and the exit-time session
-- (including a commit panel whose message buffer commits when written).
-- With NVIM_DIFFBANDIT_TEST_CHILD=quit it instead opens a view and quits, so
-- the parent can check what the exit-time session save wrote.
---@diagnostic disable: duplicate-set-field
local child = vim.env.NVIM_DIFFBANDIT_TEST_CHILD
local config = vim.env.NVIM_DIFFBANDIT_TEST_CONFIG or vim.fn.getcwd()
local root = vim.env.NVIM_DIFFBANDIT_TEST_ROOT or vim.fn.tempname()
local original = {
  XDG_STATE_HOME = vim.env.XDG_STATE_HOME,
  XDG_CACHE_HOME = vim.env.XDG_CACHE_HOME,
  XDG_DATA_HOME = vim.env.XDG_DATA_HOME,
  GIT_CONFIG_GLOBAL = vim.env.GIT_CONFIG_GLOBAL,
  GIT_CONFIG_NOSYSTEM = vim.env.GIT_CONFIG_NOSYSTEM,
  GIT_TERMINAL_PROMPT = vim.env.GIT_TERMINAL_PROMPT,
}
local packpath = vim.env.NVIM_DIFFBANDIT_TEST_PACKPATH or vim.o.packpath
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.XDG_CACHE_HOME = root .. "/cache"
vim.env.XDG_DATA_HOME = root .. "/data"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_TERMINAL_PROMPT = "0"
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
vim.opt.rtp:prepend(config)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

for _, name in ipairs({
  "plenary.nvim",
  "neogit",
  "scope.nvim",
  "auto-session",
  "bufferline.nvim",
  "nvim-dap",
  "neo-tree.nvim",
  "nui.nvim",
  "nvim-web-devicons",
  "nvim-window-picker",
  "telescope.nvim",
  "telescope-ui-select.nvim",
  "telescope-fzf-native.nvim",
  "diffview.nvim",
  "git-worktree.nvim",
  "diffbandit.nvim",
}) do
  local path = vim.fn.globpath(packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing installed test dependency: " .. name)
  vim.opt.rtp:append(path)
  -- -u NONE skips plugin/ files; diffbandit's defines its commands.
  for _, file in ipairs(vim.fn.globpath(path, "plugin/*.lua", false, true)) do
    if name == "diffbandit.nvim" then
      vim.cmd.source(vim.fn.fnameescape(file))
    end
  end
end

local function git(cwd, ...)
  local result = vim.system({ "git", "-C", cwd, ... }, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end

local function equal(expected, actual)
  assert(vim.deep_equal(expected, actual), vim.inspect({ expected = expected, actual = actual }))
end

local function settle(ms)
  vim.wait(ms or 300, function()
    return false
  end, 10)
end

local function press(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "mx", false)
end

local repo = root .. "/repo"
local linked = repo .. ".worktrees/review"

---The configuration modules a worktree switch and session save go through.
local function boot()
  vim.api.nvim_set_current_dir(repo)
  require("config.options")
  vim.o.undofile = false
  vim.o.timeoutlen = 50
  require("plugins.diffview").setup()
  require("plugins.diffbandit").setup()
  require("plugins.neogit").setup()
  require("plugins.scope").setup()
  require("plugins.bufferline").setup()
  require("plugins.neotree").setup()
  require("plugins.telescope").setup()
  require("plugins.auto-session").setup()
  require("config.workspace").setup()
  require("plugins.git-worktree").setup()
end

local function wait_view(pred)
  assert(vim.wait(5000, pred, 10), "diffbandit view did not open")
end

local function open_git_view()
  vim.cmd("DiffBanditGit")
  wait_view(function()
    return require("diffbandit").has_session()
  end)
end

local function window_of(buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
end

local function buffer_map(buf, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == lhs then
      return map
    end
  end
end

local function owned_names()
  local names = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and require("diffbandit").owns_buffer(buf) and vim.bo[buf].buftype ~= "" then
      names[#names + 1] = vim.fn.fnamemodify(name, ":t")
    end
  end
  return names
end

local function session_file(cwd)
  local session = require("auto-session")
  return session.get_root_dir() .. require("auto-session.lib").escape_session_name(cwd) .. ".vim"
end

---What a saved session would bring back that diffbandit owned: extra tabs
---(the tests keep a single normal tab) and its buffers' names.
local function session_leaks(path, names)
  local text = table.concat(vim.fn.readfile(path), "\n")
  local leaks = {}
  if text:find("\ntabnew", 1, true) then
    leaks[#leaks + 1] = "tabnew"
  end
  for _, name in ipairs(names) do
    if text:find(name, 1, true) then
      leaks[#leaks + 1] = name
    end
  end
  return leaks
end

local function commit_buffer()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "acwrite" and require("diffbandit").owns_buffer(buf) then
      return buf
    end
  end
end

local function open_commit_panel()
  require("diffbandit").commit_panel({})
  wait_view(function()
    return commit_buffer() ~= nil
  end)
  return commit_buffer()
end

-- Child: open a view and quit; the parent checks the session it left.
if child == "quit" then
  boot()
  vim.cmd.edit("file.txt")
  open_git_view()
  vim.fn.writefile(owned_names(), root .. "/child-names")
  vim.cmd("qa!")
  return
end

vim.fn.mkdir(repo, "p")
git(repo, "init", "-b", "main")
git(repo, "config", "user.email", "test@example.invalid")
git(repo, "config", "user.name", "diffbandit tests")
vim.fn.writefile({ "first", "second", "third" }, repo .. "/file.txt")
git(repo, "add", ".")
git(repo, "commit", "-m", "initial")
git(repo, "worktree", "add", "-b", "review", linked)
vim.fn.writefile({ "first", "SECOND", "third" }, repo .. "/file.txt")

local original_notify, original_confirm = vim.notify, vim.fn.confirm
vim.notify = function() end

local count = 0
local function test(name, fn)
  fn()
  count = count + 1
  print("ok " .. count .. " - " .. name)
end

local ok, failure = xpcall(function()
  boot()
  local host = require("plugins.diffbandit")
  local worktrees = require("git-worktree")
  local function switch(path)
    return worktrees.switch_to(worktrees.discover(), path)
  end
  local function reset_to_repo()
    host.close_all()
    vim.cmd("silent! tabonly")
    vim.fn.confirm = function()
      return 1
    end
    if vim.fn.getcwd() ~= repo then
      assert(switch(repo))
    end
    vim.cmd.edit(repo .. "/file.txt")
  end

  test("startup configures diffbandit lazily and maps <leader>gx", function()
    assert(not package.loaded.diffbandit, "diffbandit was loaded at startup")
    for lhs, desc in pairs({
      ["<leader>gxx"] = "All changes",
      ["<leader>gxs"] = "Staged changes",
      ["<leader>gxf"] = "Current file",
      ["<leader>gxc"] = "Commit panel",
      ["<leader>gxb"] = "Compare branches",
      ["<leader>gxl"] = "Commit log",
      ["<leader>gxm"] = "Menu",
      ["<leader>gxq"] = "Close view",
    }) do
      equal(desc, vim.fn.maparg(lhs, "n", false, true).desc)
    end
    equal("<cmd>DiffviewOpen<cr>", vim.fn.maparg("<leader>gdd", "n", false, true).rhs)
    host.close_all()
    assert(not package.loaded.diffbandit, "close_all loaded diffbandit")
  end)

  test("views stage with - and never map <Space>", function()
    vim.cmd.edit(repo .. "/file.txt")
    local file = vim.api.nvim_get_current_buf()
    press("<leader>gxx")
    wait_view(function()
      return package.loaded.diffbandit and require("diffbandit").has_session()
    end)
    local stage = buffer_map(file, "-")
    assert(stage and stage.nowait == 1 and stage.desc:match("^DiffBandit: Stage"), vim.inspect(stage))
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      assert(not buffer_map(vim.api.nvim_win_get_buf(win), " "), "a diff pane maps <Space>")
    end
    vim.api.nvim_set_current_win(window_of(file))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    press("-")
    assert(
      vim.wait(3000, function()
        return git(repo, "diff", "--cached") ~= ""
      end, 10),
      "- did not stage the hunk"
    )
    press("-")
    assert(
      vim.wait(3000, function()
        return git(repo, "diff", "--cached") == ""
      end, 10),
      "- did not unstage the hunk"
    )
    local before = vim.api.nvim_buf_get_lines(file, 0, -1, false)
    press("ggOadded<Esc>")
    equal(#before + 1, #vim.api.nvim_buf_get_lines(file, 0, -1, false))
    press("u")
    settle()
    equal(before, vim.api.nvim_buf_get_lines(file, 0, -1, false))
    press("<leader>gxq")
    assert(
      vim.wait(3000, function()
        return not require("diffbandit").has_any_session()
      end, 10),
      "<leader>gxq did not close the view"
    )
    equal(1, #vim.api.nvim_list_tabpages())
  end)

  test("the commit panel stages and toggles amend with -", function()
    local commit = open_commit_panel()
    assert(buffer_map(commit, "-"), "commit message window has no -")
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      assert(not buffer_map(vim.api.nvim_win_get_buf(win), " "), "a panel window maps <Space>")
    end
    host.close_all()
  end)

  test("close_all closes views in every tab and returns to the start", function()
    vim.cmd.edit(repo .. "/file.txt")
    local home = vim.api.nvim_get_current_tabpage()
    open_git_view()
    vim.api.nvim_set_current_tabpage(home)
    vim.cmd("tabnew")
    local panel_tab = vim.api.nvim_get_current_tabpage()
    open_commit_panel()
    vim.api.nvim_set_current_tabpage(home)
    host.close_all()
    settle()
    local diffbandit = require("diffbandit")
    assert(not diffbandit.is_running({ any = true, panel = true }), "a view is still open")
    assert(not commit_buffer(), "the commit buffer was left behind")
    equal(home, vim.api.nvim_get_current_tabpage())
    assert(vim.api.nvim_tabpage_is_valid(panel_tab), "close_all closed a tab it did not open")
    vim.cmd("silent tabonly")
  end)

  test("a worktree switch closes views before saving the session", function()
    reset_to_repo()
    vim.cmd("silent write")
    local probe = root .. "/open.vim"
    open_git_view()
    local names = owned_names()
    assert(#names > 0, "diffbandit owns no named buffers to look for")
    vim.cmd.mksession({ probe, bang = true })
    assert(#session_leaks(probe, names) > 0, "the leak check finds nothing even with a view open")
    assert(switch(linked))
    equal(linked, vim.fn.getcwd())
    assert(not require("diffbandit").is_running({ any = true, panel = true }))
    equal({}, session_leaks(session_file(repo), names))
  end)

  test("save-all on switch never writes the commit buffer", function()
    reset_to_repo()
    vim.fn.writefile({ "staged" }, repo .. "/staged.txt")
    git(repo, "add", "staged.txt")
    local head = git(repo, "rev-parse", "HEAD")
    local commit = open_commit_panel()
    vim.api.nvim_set_current_win((assert(vim.fn.win_findbuf(commit)[1], "commit window is not shown")))
    settle()
    -- The message starts on line 3, below diffbandit's two header lines.
    press("Gccdraft message<Esc>")
    equal({ "draft message" }, vim.api.nvim_buf_get_lines(commit, 2, -1, false))
    assert(vim.bo[commit].modified, "typed commit message is not modified")
    local file = vim.fn.bufnr(repo .. "/file.txt")
    vim.api.nvim_buf_set_lines(file, 0, 1, false, { "unsaved" })
    local asked = false
    vim.fn.confirm = function()
      asked = true
      return 1 -- Save all and switch
    end
    assert(switch(linked))
    assert(asked, "the switch did not ask about the unsaved file")
    equal(head, git(repo, "rev-parse", "HEAD"))
    equal("unsaved", vim.fn.readfile(repo .. "/file.txt")[1])
    assert(not commit_buffer(), "the commit buffer survived the switch")
    assert(switch(repo))
    commit = open_commit_panel()
    assert(
      vim.wait(2000, function()
        return vim.deep_equal({ "draft message" }, vim.api.nvim_buf_get_lines(commit, 2, -1, false))
      end, 10),
      "the draft was not restored: " .. vim.inspect(vim.api.nvim_buf_get_lines(commit, 0, -1, false))
    )
    host.close_all()
    git(repo, "reset", "-q", "staged.txt")
  end)

  test("a cancelled switch stays and leaves the view closed", function()
    reset_to_repo()
    open_git_view()
    local file = vim.fn.bufnr(repo .. "/file.txt")
    vim.api.nvim_buf_set_lines(file, 0, 1, false, { "cancel me" })
    vim.fn.confirm = function()
      return 2 -- Cancel
    end
    equal(false, switch(linked))
    equal(repo, vim.fn.getcwd())
    assert(vim.bo[file].modified)
    assert(not require("diffbandit").has_any_session())
    vim.api.nvim_buf_call(file, function()
      vim.cmd("silent edit!")
    end)
  end)

  test("a manual session save leaves the view open", function()
    reset_to_repo()
    open_git_view()
    vim.cmd("AutoSession save")
    assert(require("diffbandit").has_session(), ":AutoSession save closed the view")
    host.close_all()
    vim.cmd("silent tabonly")
  end)

  test("quitting with a view open saves a session without it", function()
    reset_to_repo()
    vim.cmd("silent write")
    host.close_all()
    vim.cmd("silent %bwipeout!")
    local session = session_file(repo)
    vim.fn.delete(session)
    -- A clean environment: vim.system() would set $NVIM, and auto-session
    -- never autosaves under it (it takes it for a nested :terminal).
    local env = vim.fn.environ()
    env.NVIM = nil
    env.NVIM_DIFFBANDIT_TEST_CHILD = "quit"
    env.NVIM_DIFFBANDIT_TEST_CONFIG = config
    env.NVIM_DIFFBANDIT_TEST_ROOT = root
    env.NVIM_DIFFBANDIT_TEST_PACKPATH = packpath
    env.AUTOSESSION_UNIT_TESTING = "1" -- auto-session never autosaves headless otherwise
    local result = vim
      .system({ vim.v.progpath, "--headless", "-u", "NONE", "-l", config .. "/tests/diffbandit.lua" }, {
        cwd = repo,
        env = env,
        clear_env = true,
        text = true,
      })
      :wait(60000)
    assert(result.code == 0, "child failed: " .. tostring(result.stderr) .. tostring(result.stdout))
    assert(
      vim.fn.filereadable(session) == 1,
      ("the exit-time save wrote no %s\n%s%s"):format(session, result.stdout, result.stderr)
    )
    local names = vim.fn.readfile(root .. "/child-names")
    assert(#names > 0, "the child's view owned no named buffers")
    equal({}, session_leaks(session, names))
    require("auto-session").restore_session(repo, { show_message = false })
    settle(500)
    equal(1, #vim.api.nvim_list_tabpages())
    assert(not require("diffbandit").is_running({ any = true, panel = true }))
    equal(repo .. "/file.txt", vim.api.nvim_buf_get_name(0))
  end)
end, debug.traceback)

vim.fn.confirm = original_confirm
vim.notify = original_notify
if package.loaded["config.workspace"] then
  package.loaded["config.workspace"].pause()
end
vim.api.nvim_set_current_dir(config)
for key, value in pairs(original) do
  vim.env[key] = value
end
-- After VimLeavePre: plugins still write logs under the temporary state dir.
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.fn.delete(root, "rf")
  end,
})
if not ok then
  error(failure)
end
print(("Passed %d diffbandit tests"):format(count))
