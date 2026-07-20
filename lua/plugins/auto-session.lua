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
local function neotree_state_path()
  local key = (vim.fn.getcwd():gsub("[/\\:]", "%%"))
  return vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "neotree", key .. ".json")
end

---True once exit has started: our VimLeavePre (registered before auto-session's)
---sets it, so the window-close events auto-session fires while tearing windows
---down for :mksession don't overwrite is_open with false.
local exiting = false

---Snapshot expanded directories and open/closed state. Runs on every neo-tree
---render/window event (debounced) — exit hooks alone lose state on :restart,
---crashes, and kills. If the tree was never materialized this session, the
---previously saved expansion list is preserved instead of being wiped.
local function save_neotree_state()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return
  end

  local prev_ok, prev = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(neotree_state_path()), "\n"))
  end)

  ---@type NeotreeSessionState
  local snapshot = {
    nodes = (prev_ok and type(prev) == "table" and prev.nodes) or {},
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

  local path = neotree_state_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(snapshot) }, path)
end

local save_timer = assert(vim.uv.new_timer())

---Debounced event-driven save; ignored once exit has started.
local function schedule_neotree_save()
  if exiting then
    return
  end
  save_timer:stop()
  save_timer:start(500, 0, vim.schedule_wrap(function()
    if not exiting then
      pcall(save_neotree_state)
    end
  end))
end

---Reopen neo-tree with its previous expansion state after a session restore.
---Deferred so the restored window layout settles first (old-config timing).
local function restore_neotree_state()
  vim.defer_fn(function()
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(neotree_state_path()), "\n"))
    end)
    if not ok or type(data) ~= "table" then
      return
    end

    local mok, manager = pcall(require, "neo-tree.sources.manager")
    if not mok then
      return
    end

    if type(data.nodes) == "table" and #data.nodes > 0 then
      manager.get_state("filesystem").force_open_folders = data.nodes
    end
    if data.is_open then
      -- "show" opens the sidebar without stealing focus from the restored buffer
      require("neo-tree.command").execute({ action = "show" })
    end
  end, 200)
end

---Sync bufferline's pinned group to vim.g.BufferlinePinnedBuffers (seeded from
---the change-time workspace snapshot by reconcile_buffers, so it's fresher than
---the session file). Pins missing from bufferline are added; pins bufferline
---restored from a stale session file but that are no longer pinned are removed.
local function load_pinned_buffers()
  vim.defer_fn(function()
    local ok_groups, groups = pcall(require, "bufferline.groups")
    local ok_state, state = pcall(require, "bufferline.state")
    if not (ok_groups and ok_state and state.components) then
      return
    end

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

    for _, component in ipairs(state.components) do
      local pinned = groups._is_pinned(component)
      if want[component.id] and not pinned then
        groups.add_element("pinned", component)
      elseif not want[component.id] and pinned then
        pcall(groups.remove_element, "pinned", component)
      end
    end

    local ok_ui, ui = pcall(require, "bufferline.ui")
    if ok_ui then
      ui.refresh()
    end
  end, 500)
end

function M.setup()
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

  -- Backstop snapshot. Registered before auto-session.setup() so this fires
  -- first: it captures is_open while the window still exists and raises the
  -- exiting flag, so the close events from auto-session's window teardown
  -- can't record the tree as closed.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("config.auto-session.neotree", { clear = true }),
    callback = function()
      exiting = true
      save_timer:stop()
      pcall(save_neotree_state)
    end,
  })

  require("auto-session").setup({
    auto_save = true,
    auto_restore = true, -- only fires on argument-less startup with a saved session
    show_auto_restore_notif = false,
    -- Keep plugin windows out of saved sessions
    bypass_save_filetypes = { "neo-tree", "trouble", "OverseerList" },
    -- scope.nvim per-tab buffer state rides the session as a global variable
    -- ('globals' is in sessionoptions), old-config integration.
    pre_save_cmds = { "ScopeSaveState" },
    pre_restore_cmds = { "ScopeLoadState" },
    post_restore_cmds = {
      -- Reconcile first: it re-adds/drops buffers changed since the (possibly
      -- stale) session save and seeds fresh pin data for the sync below.
      function()
        require("config.workspace").reconcile_buffers()
      end,
      load_pinned_buffers,
      restore_neotree_state,
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
