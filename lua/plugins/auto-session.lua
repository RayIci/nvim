---auto-session: per-cwd sessions, saved automatically on exit and restored
---automatically when Neovim starts with no file arguments. Bufferline pins ride
---along via vim.g.BufferlinePinnedBuffers ('globals' in sessionoptions) plus the
---deferred re-sync below, ported from the old dotfiles config. Breakpoint
---persistence is separate (config/workspace.lua) and fires on BufReadPost.
---Neo-tree can't live inside the session file (its windows are closed before
---:mksession), so its expanded folders + open flag persist in a side JSON.
---@class PluginAutoSession
local M = {}

---Persisted neo-tree explorer state for one project.
---@class NeotreeSessionState
---@field nodes string[] ids (paths) of expanded directories
---@field is_open boolean whether a neo-tree window was open at exit

---@return string
local function neotree_state_path(cwd)
  local key = ((cwd or vim.fn.getcwd()):gsub("[/\\:]", "%%"))
  return vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "neotree", key .. ".json")
end

---True once exit has started: our VimLeavePre (registered before auto-session's)
---sets it, so the window-close events auto-session fires while tearing windows
---down for :mksession don't overwrite is_open with false.
local exiting = false
local paused = false
local generation = 0

---Snapshot expanded directories and open/closed state. Runs on every neo-tree
---render/window event (debounced) — exit hooks alone lose state on :restart,
---crashes, and kills. If the tree was never materialized this session, the
---previously saved expansion list is preserved instead of being wiped.
local function save_neotree_state(cwd)
  local manager = require("neo-tree.sources.manager")
  local path = neotree_state_path(cwd)
  local prev = {}
  if vim.uv.fs_lstat(path) then
    prev = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    assert(type(prev) == "table", "Invalid explorer snapshot: " .. path)
  end

  ---@type NeotreeSessionState
  local snapshot = {
    nodes = prev.nodes or {},
    is_open = false,
  }

  local state = manager.get_state("filesystem")
  if state and state.tree then
    snapshot.nodes = {}
    for id, node in pairs(state.tree.nodes.by_id) do
      if node.type == "directory" and node:is_expanded() then
        table.insert(snapshot.nodes, id)
      end
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
      snapshot.is_open = true
      break
    end
  end

  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(snapshot) }, path)
end

local save_timer = assert(vim.uv.new_timer())

local function report(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify("Workspace session: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function defer_restore(fn, delay)
  local cwd, token = vim.fn.getcwd(), generation
  vim.defer_fn(function()
    if not paused and not exiting and generation == token and cwd == vim.fn.getcwd() then
      report(fn)
    end
  end, delay)
end

function M.pause()
  paused = true
  generation = generation + 1
  save_timer:stop()
end

function M.resume()
  paused = false
end

function M.flush()
  generation = generation + 1
  save_timer:stop()
  save_neotree_state(vim.fn.getcwd())
end

---Debounced event-driven save; ignored once exit has started.
local function schedule_neotree_save()
  if exiting or paused then
    return
  end
  local cwd, token = vim.fn.getcwd(), generation
  save_timer:stop()
  save_timer:start(
    500,
    0,
    vim.schedule_wrap(function()
      if not exiting and not paused and generation == token and cwd == vim.fn.getcwd() then
        report(function()
          save_neotree_state(cwd)
        end)
      end
    end)
  )
end

---:restart writes its own session (vim/_core/server.lua) with the tree still
---open, so the new instance gets a foreign "neo-tree filesystem [1]" buffer:
---named and filetyped like neo-tree's, but empty and unknown to it. Neo-tree
---names its fresh sidebar buffer without checking for one (E95: Buffer with
---this name already exists), so wipe every such buffer neo-tree doesn't own.
---@return boolean shown whether any wiped buffer was displayed in a window
local function wipe_foreign_neotree_buffers()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return false
  end
  local owned = {}
  pcall(manager._for_each_state, nil, function(state)
    if state.bufnr then
      owned[state.bufnr] = true
    end
  end)
  local shown = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
    if not owned[buf] and name:match("^neo%-tree [^ ]+ %[%d+%]$") then
      -- Vacate its windows first: closing a tab's last window fails (E444),
      -- so that one gets an empty buffer like :enew instead. Floats (noice
      -- popups) don't count — they can't stand in as the last window.
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        shown = true
        local splits = vim.tbl_filter(function(w)
          return vim.api.nvim_win_get_config(w).relative == ""
        end, vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)))
        if #splits > 1 then
          pcall(vim.api.nvim_win_close, win, true)
        else
          vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        end
      end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  return shown
end

---Reopen neo-tree with its previous expansion state after a session restore.
---Deferred so the restored window layout settles first (old-config timing).
---@param managed? boolean
local function restore_neotree_state(managed)
  local path = neotree_state_path()
  if not vim.uv.fs_lstat(path) then
    return
  end
  local data = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  assert(type(data) == "table" and type(data.nodes) == "table", "Invalid explorer snapshot: " .. path)
  local manager = require("neo-tree.sources.manager")
  manager.dispose("filesystem", vim.api.nvim_get_current_tabpage())
  local state = manager.get_state("filesystem")
  state.force_open_folders = data.nodes
  if data.is_open then
    wipe_foreign_neotree_buffers()
    if not managed then
      require("neo-tree.command").execute({ action = "show" })
      return
    end
    local events = require("neo-tree.events")
    local rendered = false
    local cwd, token = vim.fn.getcwd(), generation
    local handler = {
      id = "config.workspace.restore",
      event = events.AFTER_RENDER,
      handler = function(rendered_state)
        if rendered_state == state then
          rendered = true
        end
      end,
    }
    events.subscribe(handler)
    local ok, err = pcall(function()
      require("neo-tree.command").execute({ action = "show" })
      local finished = vim.wait(10000, function()
        return rendered or generation ~= token or vim.fn.getcwd() ~= cwd
      end, 10)
      assert(
        finished and rendered and generation == token and vim.fn.getcwd() == cwd,
        "Explorer restoration did not complete for " .. cwd
      )
    end)
    events.unsubscribe(handler)
    if not ok then
      error(err, 0)
    end
  else
    manager.close_all()
  end
end

---Sync bufferline's pinned group to vim.g.BufferlinePinnedBuffers (seeded from
---the change-time workspace snapshot by reconcile_buffers, so it's fresher than
---the session file). Pins missing from bufferline are added; pins bufferline
---restored from a stale session file but that are no longer pinned are removed.
local function load_pinned_buffers()
  local groups = require("bufferline.groups")
  local Buffer = require("bufferline.models").Buffer

  local pinned_str = vim.g.BufferlinePinnedBuffers or ""
  local want = {}
  for _, path in ipairs(vim.split(pinned_str, ",")) do
    if path ~= "" then
      local buf_id = vim.fn.bufnr(path)
      if buf_id ~= -1 then
        want[buf_id] = true
      end
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- Bufferline's constructor populates its component fields.
    ---@diagnostic disable-next-line: missing-fields
    local component = Buffer:new({ id = buf, path = vim.api.nvim_buf_get_name(buf) })
    local pinned = groups._is_pinned(component)
    if want[component.id] and not pinned then
      groups.add_element("pinned", component)
    elseif not want[component.id] and pinned then
      groups.remove_element("pinned", component)
    end
  end

  require("bufferline.ui").refresh()
end

local function save_scope_state()
  vim.cmd.ScopeSaveState()
  local cache = {}
  local core = require("scope.core")
  local utils = require("scope.utils")
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    cache[#cache + 1] = utils.get_buffer_names(core.cache[tab] or {})
  end
  vim.g.ScopeState = vim.json.encode({ cache = cache, last_tab = core.last_tab })
end

local function restore_scope_state()
  if not vim.g.ScopeState then
    return
  end
  local saved = vim.json.decode(vim.g.ScopeState)
  local core = require("scope.core")
  local utils = require("scope.utils")
  local cache = {}
  -- Session files create new tab handles; scope's serialized cache uses tab positions.
  for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
    cache[tab] = utils.get_buffer_ids(saved.cache[index] or {})
  end
  for _, buffers in pairs(cache) do
    for _, buf in ipairs(buffers) do
      vim.bo[buf].buflisted = false
    end
  end
  core.cache = cache
  core.last_tab = vim.api.nvim_get_current_tabpage()
  core.on_tab_enter()
end

---Managed restores run synchronously; no delayed source-workspace callback can finish them.
---@param managed? boolean
function M.restore_workspace(managed)
  restore_scope_state()
  require("config.workspace").reconcile_buffers(managed)
  require("config.workspace").restore_breakpoints()
  load_pinned_buffers()
  restore_neotree_state(managed)
end

function M.reset_workspace()
  local manager = require("neo-tree.sources.manager")
  manager.close_all()
  manager.dispose_invalid_tabs()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, name in ipairs({ "filesystem", "buffers", "git_status" }) do
      manager.dispose(name, tab)
    end
  end
  local groups = require("bufferline.groups")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    groups.remove_id_from_manual_groupings(buf)
  end
  vim.g.BufferlinePinnedBuffers = ""
end

function M.setup()
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("config.auto-session.pins", { clear = true }),
    callback = function(ev)
      require("bufferline.groups").remove_id_from_manual_groupings(ev.buf)
    end,
  })

  -- Primary persistence path: neo-tree's own events. Every render (expand or
  -- collapse re-renders) and window open/close schedules a debounced save, so
  -- the state survives :restart, crashes, and kills.
  local eok, nt_events = pcall(require, "neo-tree.events")
  if eok then
    for _, ev in ipairs({
      nt_events.AFTER_RENDER or "after_render",
      nt_events.NEO_TREE_WINDOW_AFTER_OPEN or "neo_tree_window_after_open",
      nt_events.NEO_TREE_WINDOW_AFTER_CLOSE or "neo_tree_window_after_close",
    }) do
      nt_events.subscribe({ event = ev, handler = schedule_neotree_save })
    end
  end

  -- Any session load, not just auto-session's: when no auto-session file
  -- exists (auto_delete_empty_sessions drops it once only the tree is left),
  -- the :restart session is the only one sourced and post_restore_cmds never
  -- run. Swap its empty neo-tree stand-in for the real tree.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = vim.api.nvim_create_augroup("config.auto-session.neotree-ghost", { clear = true }),
    callback = function()
      if paused then
        return
      end
      if wipe_foreign_neotree_buffers() then
        defer_restore(function()
          require("neo-tree.command").execute({ action = "show" })
        end, 200)
      end
    end,
  })

  -- Backstop snapshot. Registered before auto-session.setup() so this fires
  -- first: it captures is_open while the window still exists and raises the
  -- exiting flag, so the close events from auto-session's window teardown
  -- can't record the tree as closed.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("config.auto-session.neotree", { clear = true }),
    callback = function()
      exiting = true
      generation = generation + 1
      save_timer:stop()
      if not paused then
        report(function()
          save_neotree_state(vim.fn.getcwd())
        end)
      end
    end,
  })

  require("auto-session").setup({
    auto_save = true,
    auto_restore = true, -- only fires on argument-less startup with a saved session
    show_auto_restore_notif = false,
    -- Keep plugin windows out of saved sessions
    bypass_save_filetypes = { "neo-tree", "trouble", "OverseerList", "oil" },
    -- scope.nvim per-tab buffer state rides the session as a global variable
    -- ('globals' is in sessionoptions), old-config integration.
    pre_save_cmds = { save_scope_state },
    pre_restore_cmds = {
      function()
        generation = generation + 1
        save_timer:stop()
      end,
      "ScopeLoadState",
    },
    post_restore_cmds = {
      -- Reconcile first: it re-adds/drops buffers changed since the (possibly
      -- stale) session save and seeds fresh pin data for the sync below.
      function()
        if not paused then
          restore_scope_state()
          require("config.workspace").reconcile_buffers()
          defer_restore(load_pinned_buffers, 500)
          defer_restore(restore_neotree_state, 200)
        end
      end,
    },
    session_lens = { load_on_setup = true, previewer = false },
  })

  local map = vim.keymap.set
  map("n", "<leader>qs", "<cmd>AutoSession save<cr>", { desc = "Save session" })
  map("n", "<leader>qr", "<cmd>AutoSession restore<cr>", { desc = "Restore session" })
  map("n", "<leader>ql", "<cmd>AutoSession search<cr>", { desc = "Search sessions" })
  map("n", "<leader>qd", "<cmd>AutoSession delete<cr>", { desc = "Delete session" })
  map("n", "<leader>qt", "<cmd>AutoSession toggle<cr>", { desc = "Toggle session auto-save" })
end

return M
