---Managed worktree actions; Git operations reuse Neogit, editor state uses auto-session.
---@class PluginWorktrees
local M = {}

---@class ManagedWorktree
---@field path string
---@field branch? string full local ref
---@field head? string
---@field locked? string
---@field prunable? string
---@field bare? boolean

---@class WorktreeContext
---@field cwd string
---@field current string
---@field main string
---@field head string
---@field trees ManagedWorktree[]

---@class WorktreeBranch
---@field name string
---@field ref string
---@field kind "local"|"remote"|"new"

local busy = false

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify("Worktrees: " .. message, level or vim.log.levels.INFO)
end

---@param cwd string
---@param args string[]
---@return string
local function git(cwd, args)
  local command = { "git", "-C", cwd }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = false }):wait()
  if result.code ~= 0 then
    error(vim.trim(result.stderr or result.stdout or "Git operation failed"), 0)
  end
  return result.stdout or ""
end

---@param path string
---@return string
local function identity(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

---@param cwd? string
---@return WorktreeContext
function M.discover(cwd)
  cwd = cwd or vim.fn.getcwd()
  local current = git(cwd, { "rev-parse", "--show-toplevel" }):gsub("\n$", "")
  local trees = {} ---@type ManagedWorktree[]
  local tree ---@type ManagedWorktree?
  for _, field in ipairs(vim.split(git(cwd, { "worktree", "list", "--porcelain", "-z" }), "\0")) do
    if field:sub(1, 9) == "worktree " then
      tree = { path = field:sub(10) }
      trees[#trees + 1] = tree
    elseif tree then
      local key, value = field:match("^(%S+)%s(.*)$")
      if key == "branch" then
        tree.branch = value
      elseif key == "HEAD" then
        tree.head = value
      elseif field == "bare" then
        tree.bare = true
      elseif key == "locked" or field == "locked" then
        tree.locked = value or ""
      elseif key == "prunable" or field == "prunable" then
        tree.prunable = value or ""
      end
    end
  end
  local main = trees[1]
  if not main or main.bare or vim.fn.isdirectory(main.path) ~= 1 then
    error("A registered, non-bare main checkout is required", 0)
  end
  return {
    cwd = cwd,
    current = current,
    main = main.path,
    head = vim.trim(git(cwd, { "rev-parse", "--verify", "HEAD" })),
    trees = trees,
  }
end

---@param ctx WorktreeContext
local function check_context(ctx)
  if identity(vim.fn.getcwd()) ~= identity(ctx.cwd) then
    error("Working directory changed during the action; select the worktree again", 0)
  end
end

---@param ctx WorktreeContext
---@param path string
---@return ManagedWorktree
local function registered(ctx, path)
  for _, tree in ipairs(ctx.trees) do
    if identity(tree.path) == identity(path) then
      if tree.bare or tree.prunable or vim.fn.isdirectory(tree.path) ~= 1 then
        error("Checkout is unavailable: " .. tree.path, 0)
      end
      return tree
    end
  end
  error("Not a registered checkout of this repository: " .. path, 0)
end

---@param ctx WorktreeContext
---@return WorktreeBranch[]
function M.branches(ctx)
  local choices = {} ---@type WorktreeBranch[]
  local remotes = vim.split(vim.trim(git(ctx.cwd, { "remote" })), "\n", { trimempty = true })
  table.sort(remotes, function(a, b)
    return #a > #b
  end)
  for line in
    git(ctx.cwd, { "for-each-ref", "--format=%(refname)%09%(symref)", "refs/heads", "refs/remotes" }):gmatch(
      "[^\n]+"
    )
  do
    local ref, symbolic = line:match("^(.-)\t(.*)$")
    if ref and symbolic == "" then
      local name = ref:match("^refs/heads/(.+)$")
      if name then
        choices[#choices + 1] = { name = name, ref = ref, kind = "local" }
      else
        for _, remote in ipairs(remotes) do
          local prefix = "refs/remotes/" .. remote .. "/"
          if vim.startswith(ref, prefix) then
            choices[#choices + 1] = { name = ref:sub(#prefix + 1), ref = ref, kind = "remote" }
            break
          end
        end
      end
    end
  end
  return choices
end

---@param ctx WorktreeContext
---@param branch string
---@return string
local function default_destination(ctx, branch)
  git(ctx.cwd, { "check-ref-format", "--branch", branch })
  return ctx.main .. ".worktrees/" .. branch
end

---@param ctx WorktreeContext
---@param branch string
---@param override? string
---@return string
function M.destination(ctx, branch, override)
  local default = default_destination(ctx, branch)
  local path = override or default
  if path == "" then
    error("The worktree destination cannot be empty", 0)
  end
  if path == "~" or path:sub(1, 2) == "~/" then
    path = vim.fn.expand("~") .. path:sub(2)
  end
  if not vim.startswith(path, "/") then
    path = vim.fs.joinpath(ctx.main, path)
  end
  path = vim.fs.normalize(path)
  if vim.uv.fs_lstat(path) then
    error("Destination already exists: " .. path, 0)
  end
  return path
end

---@param path string
---@return NeogitRepo
local function bind_neogit(path)
  local repository = require("neogit.lib.git.repository")
  local function finish(repo)
    if repo._refresh_task and not repo._refresh_task:wait(10000) then
      error("Neogit's repository refresh did not finish; retry the worktree action", 0)
    end
  end
  -- Neogit's command builders share the selected repository across async refreshes.
  finish(repository.instance())
  local repo = repository.instance(path)
  finish(repo)
  return repo
end

---@param ctx WorktreeContext
---@param args string[]
---@param validate? fun()
local function mutate(ctx, args, validate)
  check_context(ctx)
  local repo = bind_neogit(ctx.current)
  check_context(ctx)
  if validate then
    validate()
  end
  local result = require("neogit.lib.git").cli.worktree.arg_list(args).call({
    await = true,
    hidden = true,
    ignore_error = true,
  })
  if not result:success() then
    error(table.concat(result.stderr, "\n"), 0)
  end
  local refresh = repo:dispatch_refresh()
  if refresh and not refresh:wait(10000) then
    error(
      "Git completed worktree "
        .. table.concat(args, " ")
        .. ", but Neogit's refresh did not finish; inspect the registered worktrees",
      0
    )
  end
end

---@param ctx WorktreeContext
---@param choice WorktreeBranch
---@param path string
---@return ManagedWorktree
function M.create_checkout(ctx, choice, path)
  check_context(ctx)
  local fresh = M.discover(ctx.cwd)
  path = M.destination(fresh, choice.name, path)
  local local_ref = "refs/heads/" .. choice.name
  for _, tree in ipairs(fresh.trees) do
    if tree.branch == local_ref then
      error("Branch is already checked out at " .. tree.path, 0)
    end
  end
  local args = { "add" }
  local start = choice.name
  local exists = false
  for _, branch in ipairs(M.branches(fresh)) do
    if branch.ref == local_ref then
      exists = true
    end
  end
  if choice.kind == "new" then
    if exists then
      error("Local branch already exists: " .. choice.name, 0)
    end
    vim.list_extend(args, { "-b", choice.name })
    start = ctx.head
  elseif choice.kind == "remote" and not exists then
    vim.list_extend(args, { "--track", "-b", choice.name })
    start = choice.ref
  elseif not exists then
    error("Local branch no longer exists: " .. choice.name, 0)
  end
  vim.list_extend(args, { path, start })
  mutate(fresh, args)
  return registered(M.discover(ctx.cwd), path)
end

---@param ctx WorktreeContext
---@param path string
function M.remove_checkout(ctx, path)
  check_context(ctx)
  local tree = registered(M.discover(ctx.cwd), path)
  mutate(ctx, { "remove", tree.path }, function()
    local fresh = M.discover(ctx.cwd)
    tree = registered(fresh, path)
    if identity(tree.path) == identity(fresh.main) or identity(tree.path) == identity(fresh.current) then
      error("Cannot remove the main or active checkout", 0)
    end
    if tree.locked then
      error("Worktree is locked: " .. tree.path, 0)
    end
    if git(tree.path, { "status", "--porcelain", "--untracked-files=all", "--ignored" }) ~= "" then
      error("Worktree contains modified, untracked, or ignored files: " .. tree.path, 0)
    end
  end)
end

---@return boolean
function M.preflight()
  local dap = package.loaded.dap
  if dap and next(dap.sessions()) then
    error("Stop active debugging sessions before switching workspaces", 0)
  end
  local modified = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" then
      local job = vim.b[buf].terminal_job_id
      if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
        error("Close the live terminal before switching: " .. vim.api.nvim_buf_get_name(buf), 0)
      end
    elseif vim.bo[buf].modified then
      modified[#modified + 1] = buf
    end
  end
  if #modified == 0 then
    return true
  end
  if vim.fn.confirm("Workspace has unsaved edits", "&Save all and switch\n&Cancel", 2) ~= 1 then
    return false
  end
  for _, buf in ipairs(modified) do
    if vim.api.nvim_buf_get_name(buf) == "" then
      error("Save the unnamed modified buffer before switching workspaces", 0)
    end
    vim.api.nvim_buf_call(buf, function()
      vim.cmd.write()
    end)
    if vim.bo[buf].modified then
      error("Buffer still has unsaved edits: " .. vim.api.nvim_buf_get_name(buf), 0)
    end
  end
  return true
end

local function reset_editor()
  local buffers = vim.api.nvim_list_bufs()
  local blank = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(blank)
  require("plugins.auto-session").reset_workspace()
  vim.cmd("silent tabonly")
  vim.cmd("silent only")
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
  local scope = require("scope.core")
  scope.cache = {}
  scope.last_tab = vim.api.nvim_get_current_tabpage()
  vim.g.ScopeState = nil
  vim.g.BufferlinePinnedBuffers = ""
  require("dap.breakpoints").clear()
  vim.v.this_session = ""
end

---@param ctx WorktreeContext
---@param path string
---@return boolean switched
function M.switch_to(ctx, path)
  check_context(ctx)
  local fresh = M.discover(ctx.cwd)
  local target = registered(fresh, path)
  if identity(target.path) == identity(fresh.current) then
    return true
  end
  if not M.preflight() then
    return false
  end
  check_context(ctx)

  local workspace = require("config.workspace")
  local persistence = require("plugins.auto-session")
  local session = require("auto-session")
  local session_config = require("auto-session.config")
  local auto_save = session_config.auto_save
  local function restore(file)
    local handler, continue_on_error =
      session_config.restore_error_handler, session_config.continue_restore_on_error
    session_config.continue_restore_on_error = false
    session_config.restore_error_handler = function(message)
      error("Session restore failed: " .. message, 0)
    end
    local restored, result = pcall(function()
      if file then
        return session.restore_session_file(file, { show_message = false })
      end
      return session.restore_session(nil, { show_message = false })
    end)
    session_config.restore_error_handler = handler
    session_config.continue_restore_on_error = continue_on_error
    if not restored then
      error(tostring(result), 0)
    end
    return result
  end
  local source = vim.fn.getcwd()
  local source_session = ""
  local changed = false
  workspace.pause()
  persistence.pause()
  session_config.auto_save = false
  local ok, err = pcall(function()
    workspace.flush()
    persistence.flush()
    if not session.save_session(source, { show_message = false }) then
      error("Could not save the outgoing session", 0)
    end
    source_session = vim.v.this_session
    changed = true
    reset_editor()
    vim.api.nvim_set_current_dir(target.path)
    session.manually_named_session = false
    if session.session_exists_for_cwd() then
      local restored, result = pcall(restore)
      if not restored or not result then
        error("Could not restore the destination session: " .. target.path .. "\n" .. tostring(result), 0)
      end
    end
    persistence.restore_workspace(true)
    bind_neogit(target.path)
    vim.cmd.clearjumps()
  end)
  if not ok and changed then
    local recovered, recovery_error = pcall(function()
      workspace.pause()
      persistence.pause()
      reset_editor()
      vim.api.nvim_set_current_dir(source)
      if source_session == "" or not restore(source_session) then
        error("Could not restore source session: " .. source_session, 0)
      end
      persistence.restore_workspace(true)
      bind_neogit(fresh.current)
    end)
    if not recovered then
      session_config.auto_save = false
      error(
        ("%s\nRecovery failed: %s\nAutomatic writes stopped. Current cwd: %s\nSource session: %s"):format(
          tostring(err),
          tostring(recovery_error),
          vim.fn.getcwd(),
          source_session
        ),
        0
      )
    end
  end
  session_config.auto_save = auto_save
  workspace.resume()
  persistence.resume()
  if not ok then
    error(tostring(err), 0)
  end
  workspace.touch()
  notify("Opened workspace: " .. target.path)
  return true
end

---@param tree ManagedWorktree
---@return string
local function tree_label(tree)
  return ("%s  %s"):format(tree.branch and tree.branch:gsub("^refs/heads/", "") or "(detached)", tree.path)
end

---@param ctx WorktreeContext
local function choose_switch(ctx)
  local select = require("plenary.async").wrap(vim.ui.select, 3)
  local tree = select(ctx.trees, { prompt = "Switch worktree workspace:", format_item = tree_label })
  if tree then
    M.switch_to(ctx, tree.path)
  end
end

---@param ctx WorktreeContext
local function choose_create(ctx)
  local async = require("plenary.async")
  local select = async.wrap(vim.ui.select, 3)
  local input = async.wrap(vim.ui.input, 2)
  local choices = M.branches(ctx)
  table.insert(choices, 1, { name = "Create new branch...", ref = "", kind = "new" })
  local choice = select(choices, {
    prompt = "Branch for new worktree:",
    format_item = function(branch)
      return branch.kind == "remote" and branch.ref:gsub("^refs/remotes/", "") .. " (remote)" or branch.name
    end,
  })
  if not choice then
    return
  end
  if choice.kind == "new" then
    local name = input({ prompt = "New branch name: " })
    if name == nil then
      return
    end
    choice.name = name
  end
  local default = default_destination(ctx, choice.name)
  local destination = input({ prompt = "Worktree destination: ", default = default, completion = "dir" })
  if destination == nil then
    return
  end
  local path = M.destination(ctx, choice.name, destination)
  check_context(ctx)
  if not M.preflight() then
    return
  end
  local tree = M.create_checkout(ctx, choice, path)
  local ok, switched = pcall(M.switch_to, ctx, tree.path)
  if not ok or not switched then
    notify("Created worktree, but did not open it: " .. tree.path, vim.log.levels.WARN)
    if not ok then
      error(switched, 0)
    end
  end
end

---@param ctx WorktreeContext
local function choose_delete(ctx)
  local select = require("plenary.async").wrap(vim.ui.select, 3)
  local tree = select(ctx.trees, { prompt = "Delete inactive worktree:", format_item = tree_label })
  if not tree then
    return
  end
  local answer = select({ "Cancel", "Delete" }, { prompt = "Remove " .. tree_label(tree) .. "?" })
  if answer == "Delete" then
    M.remove_checkout(ctx, tree.path)
    notify("Removed worktree: " .. tree.path)
  end
end

---@param fn fun(ctx: WorktreeContext)
local function action(fn)
  if busy then
    notify("A worktree action is already in progress", vim.log.levels.WARN)
    return
  end
  busy = true
  require("plenary.async").void(function()
    local ok, err = xpcall(function()
      local status = require("neogit.buffers.status")
      if status.is_open() then
        status.instance():close()
        require("plenary.async").util.scheduler()
      end
      fn(M.discover())
    end, debug.traceback)
    busy = false
    if not ok then
      notify(tostring(err), vim.log.levels.ERROR)
    end
  end)()
end

function M.create()
  action(choose_create)
end

function M.switch()
  action(choose_switch)
end

function M.delete()
  action(choose_delete)
end

function M.menu()
  action(function(ctx)
    local select = require("plenary.async").wrap(vim.ui.select, 3)
    local choice = select({ "Switch workspace", "Create worktree", "Delete worktree" }, {
      prompt = "Worktrees:",
    })
    if choice == "Switch workspace" then
      choose_switch(ctx)
    elseif choice == "Create worktree" then
      choose_create(ctx)
    elseif choice == "Delete worktree" then
      choose_delete(ctx)
    end
  end)
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>gww", M.switch, { desc = "Switch worktree workspace" })
  map("n", "<leader>gwc", M.create, { desc = "Create worktree workspace" })
  map("n", "<leader>gwd", M.delete, { desc = "Delete inactive worktree" })
end

return M
