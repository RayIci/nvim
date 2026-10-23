-- Run with: nvim --headless -u NONE -l tests/worktrees.lua
---@diagnostic disable: duplicate-set-field
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local config = vim.fn.getcwd()
local original_state = vim.env.XDG_STATE_HOME
local original_cache = vim.env.XDG_CACHE_HOME
local original_data = vim.env.XDG_DATA_HOME
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.XDG_CACHE_HOME = root .. "/cache"
vim.env.XDG_DATA_HOME = root .. "/data"
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
local git_environment = {}
for key, value in pairs({
  GIT_CONFIG_GLOBAL = "/dev/null",
  GIT_CONFIG_NOSYSTEM = "1",
  GIT_TERMINAL_PROMPT = "0",
}) do
  git_environment[key] = vim.env[key] or false
  vim.env[key] = value
end
vim.opt.rtp:prepend(config)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

local function pack(name)
  local path = (name == "neogit" and vim.env.NVIM_WORKTREE_TEST_NEOGIT)
    or vim.fn.globpath(vim.o.packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing installed test dependency: " .. name)
  vim.opt.rtp:append(path)
end
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
}) do
  pack(name)
end

local function git(cwd, ...)
  local result = vim.system({ "git", "-C", cwd, ... }, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  assert(not result.stderr:match("Error") and not result.stderr:match("ERROR"), result.stderr)
  return vim.trim(result.stdout)
end

local function equal(expected, actual)
  assert(vim.deep_equal(expected, actual), vim.inspect({ expected = expected, actual = actual }))
end

local function rejects(pattern, fn)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):match(pattern), tostring(err))
end

local count = 0
local function test(name, fn)
  fn()
  count = count + 1
  print("ok " .. count .. " - " .. name)
end

local repo = root .. "/arbitrary parent/backend"
local linked = repo .. ".worktrees/feature/login"
vim.fn.mkdir(repo, "p")
git(repo, "init", "-b", "main")
git(repo, "config", "user.email", "test@example.invalid")
git(repo, "config", "user.name", "Worktree tests")
vim.fn.writefile({ "first", "second", "third" }, repo .. "/file.txt")
git(repo, "add", ".")
git(repo, "commit", "-m", "initial")
local worktrees = require("plugins.worktrees")
vim.api.nvim_set_current_dir(repo)
require("config.options")
vim.o.undofile = false
require("plugins.neogit").setup()
local notifications = {}
local original_notify = vim.notify
local original_select, original_input = vim.ui.select, vim.ui.input
local original_confirm = vim.fn.confirm
vim.notify = function(message, level)
  notifications[#notifications + 1] = { message = tostring(message), level = level }
end

local function notified(pattern)
  for _, item in ipairs(notifications) do
    if item.message:match(pattern) then
      return true
    end
  end
  return false
end

local function settle()
  vim.wait(700, function()
    return false
  end, 10)
end

local function state_path(kind, cwd)
  return vim.fs.joinpath(vim.fn.stdpath("state"), kind, cwd:gsub("[/\\:]", "%%") .. ".json")
end

local function snapshot(kind, cwd, value)
  local path = state_path(kind, cwd)
  if value then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({ vim.json.encode(value) }, path)
    return
  end
  return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end

local function listed_files()
  local files = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= "" and vim.bo[buf].buftype == "" then
      files[#files + 1] = vim.api.nvim_buf_get_name(buf)
    end
  end
  table.sort(files)
  return files
end

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

local function pin()
  vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true })
  vim.cmd("BufferLineTogglePin")
end

local ok, failure = xpcall(function()
  test("main discovery and branch-derived defaults", function()
    local ctx = worktrees.discover()
    equal(repo, ctx.main)
    equal(repo .. ".worktrees/feature/login", worktrees.destination(ctx, "feature/login"))
    equal(root .. "/arbitrary parent/review", worktrees.destination(ctx, "fix", "../review"))
    equal(repo, worktrees.discover(repo .. "/.git/..").main)
  end)

  test("invalid destinations and names have no filesystem effects", function()
    local ctx = worktrees.discover()
    rejects("cannot be empty", function()
      worktrees.destination(ctx, "valid", "")
    end)
    rejects("already exists", function()
      worktrees.destination(ctx, "valid", repo)
    end)
    rejects("not a valid branch name", function()
      worktrees.destination(ctx, "../bad")
    end)
    assert(vim.uv.fs_symlink(root .. "/missing", root .. "/dangling"))
    rejects("already exists", function()
      worktrees.destination(ctx, "valid", root .. "/dangling")
    end)
    assert(not vim.uv.fs_stat(repo .. ".worktrees"))
  end)

  test("Neogit creates a branch without changing editor cwd", function()
    local ctx = worktrees.discover()
    local tree = worktrees.create_checkout(ctx, { kind = "new", name = "feature/login", ref = "" }, linked)
    equal(linked, tree.path)
    equal(repo, vim.fn.getcwd())
    equal(ctx.head, git(linked, "rev-parse", "HEAD"))
  end)

  test("linked, external, subdirectory, and detached checkout discovery", function()
    vim.fn.mkdir(linked .. "/subdir", "p")
    equal(repo, worktrees.discover(linked .. "/subdir").main)
    local external = root .. "/review elsewhere"
    git(repo, "worktree", "add", "--detach", external)
    local ctx = worktrees.discover(external)
    equal(repo, ctx.main)
    equal(3, #ctx.trees)
    assert(not ctx.trees[3].branch)
    equal(repo .. ".worktrees/next", worktrees.destination(ctx, "next"))
    git(repo, "worktree", "remove", external)
    vim.fn.delete(linked .. "/subdir", "d")
  end)

  test("creation uses linked HEAD instead of Neogit's old repository", function()
    vim.api.nvim_set_current_dir(linked)
    vim.fn.writefile({ "linked commit" }, linked .. "/linked.txt")
    git(linked, "add", ".")
    git(linked, "commit", "-m", "linked")
    require("neogit.lib.git.repository").instance(repo)
    local ctx = worktrees.discover()
    local path = worktrees.destination(ctx, "feature/next")
    worktrees.create_checkout(ctx, { kind = "new", name = "feature/next", ref = "" }, path)
    equal(ctx.head, git(path, "rev-parse", "HEAD"))
    assert(ctx.head ~= git(repo, "rev-parse", "HEAD"))
    equal(linked, vim.fn.getcwd())
    worktrees.remove_checkout(ctx, path)
  end)

  test("remote branch creation sets tracking without fetching", function()
    git(repo, "remote", "add", "upstream", root .. "/nonexistent-remote")
    git(repo, "update-ref", "refs/remotes/upstream/remote/feature", git(repo, "rev-parse", "HEAD"))
    local ctx = worktrees.discover()
    local choice
    for _, branch in ipairs(worktrees.branches(ctx)) do
      if branch.kind == "remote" then
        choice = branch
      end
    end
    assert(choice)
    equal("remote/feature", choice.name)
    local path = worktrees.destination(ctx, choice.name)
    worktrees.create_checkout(ctx, choice, path)
    equal("upstream", git(path, "config", "branch.remote/feature.remote"))
    equal("refs/heads/remote/feature", git(path, "config", "branch.remote/feature.merge"))
    worktrees.remove_checkout(ctx, path)
  end)

  test("existing local counterpart is not reset to a remote", function()
    local ctx = worktrees.discover()
    local choice = { kind = "remote", name = "feature/next", ref = "refs/remotes/upstream/feature/next" }
    git(repo, "update-ref", choice.ref, git(repo, "rev-parse", "HEAD"))
    local path = worktrees.destination(ctx, choice.name)
    worktrees.create_checkout(ctx, choice, path)
    equal(ctx.head, git(path, "rev-parse", "HEAD"))
    equal("refs/heads/feature/next", git(path, "symbolic-ref", "HEAD"))
    worktrees.remove_checkout(ctx, path)
  end)

  test("checked out branches and protected deletion fail safely", function()
    local ctx = worktrees.discover()
    rejects("already checked out", function()
      worktrees.create_checkout(
        ctx,
        { kind = "local", name = "main", ref = "refs/heads/main" },
        root .. "/unused"
      )
    end)
    rejects("main or active", function()
      worktrees.remove_checkout(ctx, repo)
    end)
    rejects("main or active", function()
      worktrees.remove_checkout(ctx, linked)
    end)
    assert(not vim.uv.fs_stat(root .. "/unused"))
  end)

  test("deletion protects ignored, modified, and locked worktrees", function()
    vim.api.nvim_set_current_dir(repo)
    local ctx = worktrees.discover()
    vim.fn.writefile({ ".env" }, git(repo, "rev-parse", "--git-path", "info/exclude"))
    vim.fn.writefile({ "local secret placeholder" }, linked .. "/.env")
    equal("", git(linked, "status", "--porcelain", "--untracked-files=all"))
    rejects("contains modified", function()
      worktrees.remove_checkout(ctx, linked)
    end)
    vim.fn.delete(linked .. "/.env")
    vim.fn.writefile({ "changed" }, linked .. "/file.txt")
    rejects("contains modified", function()
      worktrees.remove_checkout(ctx, linked)
    end)
    git(linked, "restore", "file.txt")
    git(repo, "worktree", "lock", linked)
    rejects("locked", function()
      worktrees.remove_checkout(ctx, linked)
    end)
    git(repo, "worktree", "unlock", linked)
  end)

  test("unsupported directories and stale invocation contexts are explicit errors", function()
    rejects("not a git repository", function()
      worktrees.discover(root)
    end)
    local ctx = worktrees.discover()
    vim.api.nvim_set_current_dir(linked)
    rejects("directory changed", function()
      worktrees.remove_checkout(ctx, linked)
    end)
    vim.api.nvim_set_current_dir(repo)
  end)

  test("aliases, home overrides, bare contexts, and known remote prefixes", function()
    local alias = root .. "/alias"
    assert(vim.uv.fs_symlink(repo, alias))
    local ctx = worktrees.discover()
    equal(repo, worktrees.discover(alias).main)
    rejects("main or active", function()
      worktrees.remove_checkout(ctx, alias)
    end)
    equal(
      vim.fn.expand("~") .. "/unused-worktree-fixture",
      worktrees.destination(ctx, "home", "~/unused-worktree-fixture")
    )
    git(root, "init", "--bare", root .. "/bare")
    rejects("fatal:", function()
      worktrees.discover(root .. "/bare")
    end)
    git(repo, "remote", "add", "team/upstream", root .. "/nonexistent-team")
    git(repo, "update-ref", "refs/remotes/team/upstream/nested/branch", ctx.head)
    local found = false
    for _, branch in ipairs(worktrees.branches(ctx)) do
      if branch.ref == "refs/remotes/team/upstream/nested/branch" then
        equal("nested/branch", branch.name)
        found = true
      end
    end
    assert(found)
  end)

  require("plugins.scope").setup()
  require("plugins.bufferline").setup()
  require("plugins.neotree").setup()
  require("plugins.telescope").setup()
  require("plugins.auto-session").setup()
  require("config.workspace").setup()
  require("plugins.worktrees").setup()
  local workspace = require("config.workspace")
  local persistence = require("plugins.auto-session")
  local session = require("auto-session")
  local session_config = require("auto-session.config")
  local breakpoints = require("dap.breakpoints")
  local manager = require("neo-tree.sources.manager")
  local telescope_select = vim.ui.select
  local function switch(path)
    return worktrees.switch_to(worktrees.discover(), path)
  end

  test("entry mappings and cancellation leave Git untouched", function()
    equal("function", type(vim.fn.maparg("<leader>gwc", "n", false, true).callback))
    equal("Save session", vim.fn.maparg("<leader>qs", "n", false, true).desc)
    local before = git(repo, "worktree", "list", "--porcelain")
    vim.ui.select = function(_, _, cb)
      cb(nil)
    end
    worktrees.create()
    equal(before, git(repo, "worktree", "list", "--porcelain"))
    vim.ui.select = function(items, _, cb)
      cb(items[1], 1)
    end
    local inputs = 0
    vim.ui.input = function(opts, cb)
      inputs = inputs + 1
      if inputs == 1 then
        cb("cancelled/branch")
      else
        equal(repo .. ".worktrees/cancelled/branch", opts.default)
        cb(nil)
      end
    end
    worktrees.create()
    equal(2, inputs)
    equal(before, git(repo, "worktree", "list", "--porcelain"))
    assert(not vim.uv.fs_stat(repo .. ".worktrees/cancelled"))
    assert(not git(repo, "for-each-ref", "refs/heads/cancelled"):match("cancelled"))
  end)

  test("managed requests are serialized while selection is open", function()
    local callback
    vim.ui.select = function(_, _, cb)
      callback = cb
    end
    worktrees.switch()
    assert(callback, vim.inspect(notifications))
    worktrees.create()
    assert(notified("already in progress"))
    callback(nil)
    vim.ui.select = function(_, _, cb)
      cb(nil)
    end
    worktrees.switch()
  end)

  test("branch identity, invalid input, and actual Git failures are visible", function()
    git(repo, "branch", "ui/local")
    local prompts = 0
    for _, kind in ipairs({ "local", "remote" }) do
      vim.ui.select = function(items, _, cb)
        for index, choice in ipairs(items) do
          if choice.kind == kind and choice.name == (kind == "local" and "ui/local" or "remote/feature") then
            cb(choice, index)
            return
          end
        end
        error("Branch choice missing")
      end
      vim.ui.input = function(opts, cb)
        prompts = prompts + 1
        equal(repo .. ".worktrees/" .. (kind == "local" and "ui/local" or "remote/feature"), opts.default)
        cb(nil)
      end
      worktrees.create()
    end
    equal(2, prompts)
    vim.ui.select = function(items, _, cb)
      cb(items[1], 1)
    end
    vim.ui.input = function(_, cb)
      prompts = prompts + 1
      cb("../invalid")
    end
    worktrees.create()
    equal(3, prompts)
    assert(notified("not a valid branch name"))
    vim.fn.writefile({ "occupied parent" }, root .. "/blocked-parent")
    local inputs = 0
    vim.ui.input = function(_, cb)
      inputs = inputs + 1
      cb(inputs == 1 and "ui/git-failure" or root .. "/blocked-parent/worktree")
    end
    worktrees.create()
    equal(repo, vim.fn.getcwd())
    assert(notified("fatal:"), vim.inspect(notifications))
    assert(not vim.uv.fs_stat(root .. "/blocked-parent/worktree"))
  end)

  test("an occupied suggestion can still be edited to an available destination", function()
    local default = repo .. ".worktrees/ui/occupied"
    local override = root .. "/occupied override"
    git(repo, "branch", "ui/occupied")
    vim.fn.mkdir(default, "p")
    vim.ui.select = function(items, _, cb)
      for index, choice in ipairs(items) do
        if choice.kind == "local" and choice.name == "ui/occupied" then
          cb(choice, index)
          return
        end
      end
      error("Local branch missing")
    end
    vim.ui.input = function(opts, cb)
      equal(default, opts.default)
      cb(override)
    end
    worktrees.create()
    equal(override, vim.fn.getcwd())
    assert(switch(repo))
    worktrees.remove_checkout(worktrees.discover(), override)
    equal(1, vim.fn.isdirectory(default))
    vim.fn.delete(default, "d")
  end)

  test("all-buffer guards cancel, save, and reject failed or unnamed writes", function()
    local buf = edit(repo .. "/file.txt")
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "unsaved" })
    vim.cmd.enew()
    vim.fn.confirm = function(_, _, default)
      equal(2, default)
      return 2
    end
    equal(false, switch(linked))
    equal(repo, vim.fn.getcwd())
    assert(vim.bo[buf].modified)
    assert(switch(repo)) -- An active-checkout selection is a no-op, even with edits.
    vim.fn.confirm = function()
      return 1
    end
    vim.bo[buf].readonly = true
    rejects("file%.txt", function()
      switch(linked)
    end)
    equal(repo, vim.fn.getcwd())
    vim.bo[buf].readonly = false
    assert(worktrees.preflight())
    assert(not vim.bo[buf].modified)
    local unnamed = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(unnamed, 0, -1, false, { "unnamed changes" })
    rejects("unnamed", worktrees.preflight)
    vim.api.nvim_buf_delete(unnamed, { force = true })
    edit(repo .. "/file.txt")
    local source_tab = vim.api.nvim_get_current_tabpage()
    local other_file = repo .. "/guard-other-tab.txt"
    vim.fn.writefile({ "saved" }, other_file)
    vim.cmd.tabnew()
    local other_tab = vim.api.nvim_get_current_tabpage()
    local other = edit(other_file)
    vim.api.nvim_buf_set_lines(other, 0, -1, false, { "other-tab edit" })
    vim.api.nvim_set_current_tabpage(source_tab)
    vim.fn.confirm = function()
      return 2
    end
    equal(false, switch(linked))
    assert(vim.bo[other].modified)
    vim.fn.confirm = function()
      return 1
    end
    assert(worktrees.preflight())
    equal({ "other-tab edit" }, vim.fn.readfile(other_file))
    vim.api.nvim_set_current_tabpage(other_tab)
    vim.cmd.tabclose()
    vim.api.nvim_buf_delete(other, {})
    vim.fn.delete(other_file)
    vim.fn.confirm = original_confirm
  end)

  test("live terminal jobs and debugging sessions are never terminated", function()
    local dap = require("dap")
    local sessions = dap.sessions
    dap.sessions = function()
      return { [1] = {} }
    end
    rejects("debugging", worktrees.preflight)
    dap.sessions = sessions
    vim.cmd.enew()
    local terminal = vim.api.nvim_get_current_buf()
    local job = vim.fn.jobstart({ "sleep", "30" }, { term = true })
    assert(job > 0)
    rejects("live terminal", worktrees.preflight)
    equal(-1, vim.fn.jobwait({ job }, 0)[1])
    vim.fn.jobstop(job)
    vim.fn.jobwait({ job }, 1000)
    vim.api.nvim_buf_delete(terminal, { force = true })
    edit(repo .. "/file.txt")
  end)

  test("outgoing session and sidecar failures abort before teardown", function()
    local buf = vim.api.nvim_get_current_buf()
    local save = session.save_session
    session.save_session = function()
      return false
    end
    rejects("outgoing session", function()
      switch(linked)
    end)
    session.save_session = save
    local flush = workspace.flush
    workspace.flush = function()
      error("fixture sidecar failure")
    end
    rejects("fixture sidecar failure", function()
      switch(linked)
    end)
    workspace.flush = flush
    equal(repo, vim.fn.getcwd())
    equal(buf, vim.api.nvim_get_current_buf())
  end)

  local first = repo .. "/file.txt"
  local second = repo .. "/other.txt"
  local target = repo .. ".worktrees/ui/default"
  test("create-default switches cleanly and saves the entire outgoing layout", function()
    vim.fn.writefile({ "other tab" }, second)
    local buf = edit(first)
    breakpoints.set({}, buf, 2)
    vim.cmd.vsplit()
    pin()
    vim.cmd.tabnew()
    edit(second)
    vim.cmd.tabfirst()
    vim.fn.mkdir(repo .. "/expanded/subdir", "p")
    vim.fn.writefile({ "child" }, repo .. "/expanded/subdir/child.txt")
    vim.fn.writefile({ "direct child" }, repo .. "/expanded/direct.txt")
    manager.dispose("filesystem", vim.api.nvim_get_current_tabpage())
    require("neo-tree.command").execute({ action = "show" })
    assert(
      vim.wait(5000, function()
        local state = manager.get_state("filesystem")
        return state.tree and state.tree.nodes.by_id[repo .. "/expanded"] ~= nil
      end, 10),
      "source explorer did not render"
    )
    local state = manager.get_state("filesystem")
    assert(state.tree)
    ---@cast state neotree.sources.filesystem.StateWithTree
    require("neo-tree.sources.filesystem").toggle_directory(
      state,
      state.tree.nodes.by_id[repo .. "/expanded"]
    )
    settle()
    assert(state.tree.nodes.by_id[repo .. "/expanded"]:is_expanded(), "source explorer did not expand")
    session_config.auto_save = false
    vim.ui.select = function(items, _, cb)
      cb(items[1], 1)
    end
    local inputs = 0
    vim.ui.input = function(opts, cb)
      inputs = inputs + 1
      if inputs == 1 then
        cb("ui/default")
      else
        equal(target, opts.default)
        cb(opts.default)
      end
    end
    worktrees.create()
    equal(target, vim.fn.getcwd())
    equal(false, session_config.auto_save)
    equal(1, #vim.api.nvim_list_tabpages())
    equal(1, #vim.api.nvim_list_wins())
    equal({}, listed_files())
    equal("", vim.api.nvim_buf_get_name(0))
    equal("", vim.g.BufferlinePinnedBuffers)
    equal({}, breakpoints.get())
    local saved = assert(snapshot("workspaces", repo))
    assert(vim.tbl_contains(saved.buffers, first))
    assert(vim.tbl_contains(saved.buffers, second))
    equal(first, saved.pinned)
    assert(assert(snapshot("neotree", repo)).is_open)
    settle()
    equal({}, snapshot("workspaces", target).buffers)
  end)

  test("A-to-B-to-A restores tabs, pins, breakpoints, expansions, and exact filenames", function()
    local buf = edit(target .. "/file.txt")
    breakpoints.set({}, buf, 3)
    pin()
    assert(switch(repo))
    equal(2, #vim.api.nvim_list_tabpages())
    equal(4, #vim.api.nvim_list_wins())
    equal({ first }, listed_files())
    equal(first, vim.g.BufferlinePinnedBuffers)
    equal(2, breakpoints.get()[vim.fn.bufnr(first)][1].line)
    vim.cmd.tablast()
    equal({ second }, listed_files())
    vim.cmd.tabfirst()
    assert(
      vim.wait(5000, function()
        local state = manager.get_state("filesystem")
        local node = state.tree and state.tree.nodes.by_id[repo .. "/expanded"]
        return node and node:is_expanded()
      end, 10),
      "restored explorer did not expand"
    )
    settle()
    assert(
      manager.get_state("filesystem").tree.nodes.by_id[repo .. "/expanded"]:is_expanded(),
      "following the current file collapsed a restored expansion"
    )
    assert(switch(target))
    equal({ target .. "/file.txt" }, listed_files())
    equal(target .. "/file.txt", vim.g.BufferlinePinnedBuffers)
    equal(3, breakpoints.get()[vim.fn.bufnr(target .. "/file.txt")][1].line)
    equal(1, #vim.api.nvim_list_tabpages())
    equal(1, #vim.api.nvim_list_wins())
    settle()
    equal(target .. "/file.txt", snapshot("workspaces", target).pinned)
  end)

  test("creation after a linked checkout uses an editable override", function()
    local override = root .. "/custom review"
    vim.ui.select = function(items, _, cb)
      cb(items[1], 1)
    end
    local inputs = 0
    vim.ui.input = function(opts, cb)
      inputs = inputs + 1
      if inputs == 1 then
        cb("ui/override")
      else
        equal(repo .. ".worktrees/ui/override", opts.default)
        cb(override)
      end
    end
    worktrees.create()
    equal(override, vim.fn.getcwd())
    equal("refs/heads/ui/override", git(override, "symbolic-ref", "HEAD"))
    assert(switch(target))
    worktrees.remove_checkout(worktrees.discover(), override)
    equal(
      "refs/heads/ui/override",
      git(repo, "for-each-ref", "--format=%(refname)", "refs/heads/ui/override")
    )
  end)

  test("a second guard retains and reports a created but unopened checkout", function()
    local create = worktrees.create_checkout
    local buf = vim.api.nvim_get_current_buf()
    worktrees.create_checkout = function(...)
      local result = create(...)
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "edit during creation" })
      return result
    end
    vim.fn.confirm = function()
      return 2
    end
    local inputs = 0
    vim.ui.input = function(opts, cb)
      inputs = inputs + 1
      cb(inputs == 1 and "ui/not-opened" or opts.default)
    end
    worktrees.create()
    worktrees.create_checkout = create
    vim.fn.confirm = original_confirm
    equal(target, vim.fn.getcwd())
    assert(vim.bo[buf].modified)
    assert(notified("Created worktree, but did not open it: .*ui/not%-opened"))
    local created = repo .. ".worktrees/ui/not-opened"
    equal("refs/heads/ui/not-opened", git(created, "symbolic-ref", "HEAD"))
    vim.bo[buf].modified = false
    vim.cmd.edit({ bang = true })
    worktrees.remove_checkout(worktrees.discover(), created)
  end)

  local sidecar = repo .. ".worktrees/sidecar"
  test("sidecar-only state restores without an auto-session file", function()
    local ctx = worktrees.discover()
    worktrees.create_checkout(ctx, { kind = "new", name = "sidecar", ref = "" }, sidecar)
    snapshot("workspaces", sidecar, {
      buffers = { sidecar .. "/file.txt" },
      pinned = sidecar .. "/file.txt",
      breakpoints = { [sidecar .. "/file.txt"] = { { lnum = 2 } } },
    })
    snapshot("neotree", sidecar, { nodes = {}, is_open = false })
    assert(switch(sidecar))
    equal({ sidecar .. "/file.txt" }, listed_files())
    equal(sidecar .. "/file.txt", vim.g.BufferlinePinnedBuffers)
    local buf = edit(sidecar .. "/file.txt")
    equal(2, breakpoints.get()[buf][1].line)
    assert(switch(target))
  end)

  test("empty snapshots clear stale session buffers, pins, breakpoints, and expansions", function()
    snapshot("workspaces", sidecar, { buffers = {}, pinned = "", breakpoints = {} })
    snapshot("neotree", sidecar, { nodes = {}, is_open = false })
    assert(switch(sidecar))
    equal({}, listed_files())
    equal("", vim.g.BufferlinePinnedBuffers)
    equal({}, breakpoints.get())
    equal({}, manager.get_state("filesystem").force_open_folders)
    equal(1, #vim.api.nvim_list_wins())
    assert(switch(target))
  end)

  test("missing sidecars preserve session buffers and pins", function()
    assert(switch(sidecar))
    vim.fn.delete(state_path("workspaces", target))
    vim.fn.delete(state_path("neotree", target))
    assert(switch(target))
    equal({ target .. "/file.txt" }, listed_files())
    equal(target .. "/file.txt", vim.g.BufferlinePinnedBuffers)
  end)

  test("already-queued saves and deferred restores cannot cross a transition", function()
    local callbacks = {}
    local schedule_wrap, defer_fn = vim.schedule_wrap, vim.defer_fn
    vim.schedule_wrap = function(fn)
      callbacks[#callbacks + 1] = fn
      return function() end
    end
    workspace.touch()
    vim.schedule_wrap = schedule_wrap
    vim.defer_fn = function(fn, _delay)
      callbacks[#callbacks + 1] = fn
    end
    session_config.post_restore_cmds[1]()
    vim.defer_fn = defer_fn
    equal(3, #callbacks)
    assert(switch(sidecar))
    local before = vim.fn.readfile(state_path("workspaces", target))
    local closes = 0
    local close = manager.close_all
    manager.close_all = function(...)
      closes = closes + 1
      return close(...)
    end
    for _, callback in ipairs(callbacks) do
      callback()
    end
    manager.close_all = close
    equal(0, closes)
    equal("", vim.g.BufferlinePinnedBuffers)
    equal(before, vim.fn.readfile(state_path("workspaces", target)))
    settle()
    equal({}, snapshot("workspaces", sidecar).buffers)
    assert(switch(target))
  end)

  test("deletion cancellation, ignored-only, staged and untracked content stay safe", function()
    vim.ui.select = function(items, opts, cb)
      if opts.prompt:match("Delete inactive") then
        for index, tree in ipairs(items) do
          if tree.path == sidecar then
            cb(tree, index)
            return
          end
        end
      end
      cb(items[1], 1)
    end
    worktrees.delete()
    assert(vim.uv.fs_stat(sidecar))
    local ctx = worktrees.discover()
    vim.fn.writefile({ "untracked" }, sidecar .. "/untracked")
    rejects("contains modified", function()
      worktrees.remove_checkout(ctx, sidecar)
    end)
    git(sidecar, "add", "untracked")
    rejects("contains modified", function()
      worktrees.remove_checkout(ctx, sidecar)
    end)
    git(sidecar, "reset", "--", "untracked")
    vim.fn.delete(sidecar .. "/untracked")
    local saved = vim.fn.readfile(state_path("workspaces", sidecar))
    worktrees.remove_checkout(ctx, sidecar)
    assert(not vim.uv.fs_stat(sidecar))
    equal(saved, vim.fn.readfile(state_path("workspaces", sidecar)))
    equal("refs/heads/sidecar", git(repo, "for-each-ref", "--format=%(refname)", "refs/heads/sidecar"))
  end)

  test("Neogit status w uses the shared menu and preserves the editing layout", function()
    local status = require("neogit.buffers.status")
    require("neogit").open()
    assert(vim.wait(10000, status.is_open, 10), "Neogit did not open")
    local map = vim.fn.maparg("w", "n", false, true)
    assert(type(map.callback) == "function", vim.inspect(map))
    vim.ui.select = function(items, opts, cb)
      if opts.prompt == "Worktrees:" then
        cb(items[1], 1)
        return
      end
      for index, tree in ipairs(items) do
        if tree.path == repo then
          cb(tree, index)
          return
        end
      end
      error("Main checkout missing")
    end
    local previous_notifications = #notifications
    map.callback()
    assert(
      vim.wait(10000, function()
        for index = previous_notifications + 1, #notifications do
          if notifications[index].message == "Worktrees: Opened workspace: " .. repo then
            return true
          end
        end
        return false
      end, 10),
      vim.inspect(notifications)
    )
    equal(2, #vim.api.nvim_list_tabpages())
    assert(not status.is_open())
    assert(switch(target))
    assert(
      #vim.api.nvim_list_wins() == 1,
      vim.inspect(vim.tbl_map(function(win)
        return {
          name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)),
          config = vim.api.nvim_win_get_config(win),
        }
      end, vim.api.nvim_list_wins()))
    )
    equal({ target .. "/file.txt" }, listed_files())
  end)

  test("ordinary manual restore and mutation-time saves remain compatible", function()
    vim.ui.select, vim.ui.input = original_select, original_input
    assert(session.save_session(nil, { show_message = false }))
    local buf = edit(target .. "/file.txt")
    breakpoints.set({}, buf, 1)
    settle()
    equal(1, snapshot("workspaces", target).breakpoints[target .. "/file.txt"][1].lnum)
    assert(session.restore_session(nil, { show_message = false }))
    settle()
    equal({ target .. "/file.txt" }, listed_files())
    equal(target .. "/file.txt", vim.g.BufferlinePinnedBuffers)
    equal(1, breakpoints.get()[vim.fn.bufnr(target .. "/file.txt")][1].line)
  end)

  test("the actual Telescope selector cancels without changing workspaces", function()
    vim.ui.select = telescope_select
    worktrees.switch()
    assert(vim.wait(5000, function()
      return vim.bo.filetype == "TelescopePrompt"
    end, 10))
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
    settle()
    equal(target, vim.fn.getcwd())
    local called = false
    vim.ui.select = function(_, _, cb)
      called = true
      cb(nil)
    end
    worktrees.switch()
    assert(called, "Telescope cancellation did not release the managed action")
  end)

  test("restart ghost cleanup callbacks are invalidated by workspace transitions", function()
    vim.cmd.vsplit()
    local ghost = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(ghost, "neo-tree filesystem [999]")
    vim.bo[ghost].filetype = "neo-tree"
    vim.api.nvim_set_current_buf(ghost)
    local callbacks = {}
    local defer = vim.defer_fn
    vim.defer_fn = function(fn, _delay)
      callbacks[#callbacks + 1] = fn
    end
    vim.api.nvim_exec_autocmds("SessionLoadPost", { modeline = false })
    vim.defer_fn = defer
    equal(1, #callbacks)
    assert(not vim.api.nvim_buf_is_valid(ghost))
    assert(switch(repo))
    local execute = require("neo-tree.command").execute
    local opened = false
    require("neo-tree.command").execute = function()
      opened = true
    end
    callbacks[1]()
    require("neo-tree.command").execute = execute
    assert(not opened)
    assert(switch(target))
  end)

  test("plain startup, explicit-file startup, and disabled entry points share existing state", function()
    workspace.pause()
    persistence.pause()
    local before_startup = snapshot("workspaces", repo)
    local function startup(args, disabled, open_file)
      local output = root .. "/startup-result.json"
      vim.fn.delete(output)
      local command = { vim.v.progpath, "--headless", "-u", config .. "/tests/worktree-startup.lua" }
      vim.list_extend(command, args)
      local result = vim
        .system(command, {
          cwd = repo,
          text = true,
          env = {
            AUTOSESSION_UNIT_TESTING = "1",
            NVIM_WORKTREE_TEST_CONFIG = config,
            NVIM_WORKTREE_TEST_PACKPATH = vim.o.packpath,
            NVIM_WORKTREE_TEST_RESULT = output,
            NVIM_WORKTREE_TEST_DISABLED = disabled and "1" or "",
            NVIM_WORKTREE_TEST_OPEN_FILE = open_file or "",
          },
        })
        :wait(15000)
      assert(result.code == 0, result.stderr)
      assert(not result.stderr:match("Error") and not result.stderr:match("ERROR"), result.stderr)
      local data = vim.json.decode(table.concat(vim.fn.readfile(output), "\n"))
      data.stderr = result.stderr
      return data
    end
    local restored = startup({}, false)
    equal(repo, restored.cwd)
    equal(first, restored.file)
    equal(2, #restored.tabs)
    equal({ first }, restored.tabs[1])
    assert(
      vim.deep_equal({ second }, restored.tabs[2]),
      vim.inspect({
        restored = restored,
        before = before_startup,
        snapshot = snapshot("workspaces", repo),
        scope = vim.tbl_filter(
          function(line)
            return line:match("ScopeState")
          end,
          vim.fn.readfile(
            session.get_root_dir() .. require("auto-session.lib").escape_session_name(repo) .. ".vim"
          )
        ),
      })
    )
    equal(first, restored.pinned)
    equal(2, restored.breakpoints[first][1].line)
    assert(restored.managed_mapping)
    local disabled = startup({}, true)
    assert(not disabled.managed_mapping)
    equal(restored.file, disabled.file)
    equal(restored.tabs, disabled.tabs)
    equal(restored.pinned, disabled.pinned)
    local explicit = repo .. "/explicit.txt"
    vim.fn.writefile({ "explicit startup" }, explicit)
    local opened = startup({ explicit }, false)
    equal(explicit, opened.file)
    equal(1, #opened.tabs)
    equal("", opened.pinned)
    equal("", opened.session)
    workspace.resume()
    persistence.resume()
    assert(switch(repo))
    local saved_session = session.get_root_dir()
      .. require("auto-session.lib").escape_session_name(repo)
      .. ".vim"
    local unchanged_session = vim.fn.readfile(saved_session)
    local later = repo .. "/opened-after-session.txt"
    vim.fn.writefile({ "only in mutation-time state" }, later)
    local later_buf = edit(later)
    pin()
    breakpoints.set({}, later_buf, 1)
    settle()
    equal(unchanged_session, vim.fn.readfile(saved_session))
    workspace.pause()
    persistence.pause()
    local restarted = startup({}, false, later)
    equal(later, restarted.file)
    assert(vim.tbl_contains(restarted.buffers_before_open, later))
    assert(vim.tbl_contains(restarted.buffers, later))
    assert(restarted.pinned:find(later, 1, true))
    equal(1, restarted.breakpoints[later][1].line)
    equal(unchanged_session, vim.fn.readfile(saved_session))
    workspace.resume()
    persistence.resume()
    assert(switch(target))
  end)

  local broken = repo .. ".worktrees/broken"
  test("broken target sessions recover the source without overwriting saved target state", function()
    worktrees.create_checkout(worktrees.discover(), { kind = "new", name = "broken", ref = "" }, broken)
    local path = session.get_root_dir() .. require("auto-session.lib").escape_session_name(broken) .. ".vim"
    vim.fn.writefile({ "throw 'fixture broken session'" }, path)
    local before = vim.fn.readfile(path)
    rejects("destination session", function()
      switch(broken)
    end)
    equal(target, vim.fn.getcwd())
    equal({ target .. "/file.txt" }, listed_files())
    equal(false, session_config.auto_save)
    equal(before, vim.fn.readfile(path))
  end)

  test("failed recovery stops automatic writes and identifies recoverable source state", function()
    local restore = session.restore_session_file
    session.restore_session_file = function()
      return false
    end
    rejects("Automatic writes stopped.*Source session:", function()
      switch(broken)
    end)
    session.restore_session_file = restore
    equal(false, session_config.auto_save)
    local before = vim.fn.readfile(state_path("workspaces", target))
    workspace.touch()
    vim.api.nvim_create_buf(true, false)
    settle()
    equal(before, vim.fn.readfile(state_path("workspaces", target)))
  end)
  vim.ui.select, vim.ui.input, vim.fn.confirm = original_select, original_input, original_confirm
end, debug.traceback)

local repos = {
  require("neogit.lib.git.repository").instance(repo),
  require("neogit.lib.git.repository").instance(linked),
}
assert(
  vim.wait(10000, function()
    for _, instance in ipairs(repos) do
      if instance._refresh_task and not instance._refresh_task:done() then
        return false
      end
    end
    return true
  end, 10),
  "Neogit refreshes did not finish"
)
vim.api.nvim_set_current_dir(config)
for _, group in ipairs({ "config.workspace", "config.auto-session.neotree" }) do
  if vim.fn.exists("#" .. group) == 1 then
    vim.api.nvim_del_augroup_by_name(group)
  end
end
if package.loaded["plugins.auto-session"] then
  package.loaded["plugins.auto-session"].pause()
end
if package.loaded["config.workspace"] then
  package.loaded["config.workspace"].pause()
end
if package.loaded["neo-tree.sources.manager"] then
  for _, source in ipairs({ "filesystem", "buffers", "git_status" }) do
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      package.loaded["neo-tree.sources.manager"].dispose(source, tab)
    end
  end
end
vim.notify = original_notify
vim.ui.select, vim.ui.input, vim.fn.confirm = original_select, original_input, original_confirm
vim.env.XDG_STATE_HOME = original_state
vim.env.XDG_CACHE_HOME = original_cache
vim.env.XDG_DATA_HOME = original_data
for key, value in pairs(git_environment) do
  vim.env[key] = value or nil
end
vim.fn.delete(root, "rf")
if not ok then
  error(failure)
end
print(("Passed %d worktree tests"):format(count))
