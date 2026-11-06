---Neo-tree explorer state per project: expanded folders and whether the tree
---was open. Neo-tree's windows are closed before :mksession, so this lives in
---a side file (stdpath("state")/neotree/<cwd-key>.json) saved on neo-tree's own
---render/window events and re-applied after a session restore.
---@class WorkspaceExplorer
local M = {}

local state = require("config.state")

---Persisted explorer state for one project.
---@class NeotreeSessionState
---@field nodes string[] ids (paths) of expanded directories
---@field is_open boolean whether a neo-tree window was open

---Snapshot expanded directories and the open/closed state. If the tree was
---never materialized this session, the stored expansion list is kept rather
---than wiped.
---@param cwd string
local function save(cwd)
  local path = state.path("neotree", cwd)
  local prev = state.read(path, {})
  assert(type(prev) == "table", "Invalid explorer snapshot: " .. path)

  ---@type NeotreeSessionState
  local snapshot = { nodes = prev.nodes or {}, is_open = false }

  local fs = require("neo-tree.sources.manager").get_state("filesystem")
  if fs and fs.tree then
    snapshot.nodes = {}
    for id, node in pairs(fs.tree.nodes.by_id) do
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

  state.write(path, snapshot)
end

---Debounced saves plus the guard for deferred restores.
M.saver = state.saver({ label = "Workspace session", save = save })

---:restart writes its own session (vim/_core/server.lua) with the tree still
---open, so the new instance gets a foreign "neo-tree filesystem [1]" buffer:
---named and filetyped like neo-tree's, but empty and unknown to it. Neo-tree
---names its fresh sidebar buffer without checking for one (E95: Buffer with
---this name already exists), so wipe every such buffer neo-tree doesn't own.
---@return boolean shown whether any wiped buffer was displayed in a window
function M.wipe_foreign_buffers()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return false
  end
  local owned = {}
  pcall(manager._for_each_state, nil, function(s)
    if s.bufnr then
      owned[s.bufnr] = true
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

---Reopen neo-tree with its stored expansion state. A managed restore waits
---for the tree to render, so the workspace switch only completes once it has.
---@param managed? boolean
function M.restore(managed)
  local path = state.path("neotree")
  local data, exists = state.read(path, nil)
  if not exists then
    return
  end
  assert(type(data) == "table" and type(data.nodes) == "table", "Invalid explorer snapshot: " .. path)
  local manager = require("neo-tree.sources.manager")
  manager.dispose("filesystem", vim.api.nvim_get_current_tabpage())
  local fs = manager.get_state("filesystem")
  fs.force_open_folders = data.nodes
  if not data.is_open then
    manager.close_all()
    return
  end
  M.wipe_foreign_buffers()
  if not managed then
    require("neo-tree.command").execute({ action = "show" })
    return
  end
  local events = require("neo-tree.events")
  local rendered = false
  local cwd, token = vim.fn.getcwd(), M.saver.token()
  local handler = {
    id = "config.workspace.restore",
    event = events.AFTER_RENDER,
    handler = function(rendered_state)
      if rendered_state == fs then
        rendered = true
      end
    end,
  }
  events.subscribe(handler)
  local ok, err = pcall(function()
    require("neo-tree.command").execute({ action = "show" })
    local finished = vim.wait(10000, function()
      return rendered or M.saver.token() ~= token or vim.fn.getcwd() ~= cwd
    end, 10)
    assert(
      finished and rendered and M.saver.token() == token and vim.fn.getcwd() == cwd,
      "Explorer restoration did not complete for " .. cwd
    )
  end)
  events.unsubscribe(handler)
  if not ok then
    error(err, 0)
  end
end

---Close neo-tree and drop its per-tab source state (workspace reset).
function M.reset()
  local manager = require("neo-tree.sources.manager")
  manager.close_all()
  manager.dispose_invalid_tabs()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, name in ipairs({ "filesystem", "buffers", "git_status" }) do
      manager.dispose(name, tab)
    end
  end
end

---Register the save triggers. Must run before auto-session.setup(): this
---VimLeavePre has to fire first, while the tree window still exists, and it
---raises the exiting flag so auto-session's window teardown for :mksession
---cannot record the tree as closed.
function M.setup()
  -- Primary persistence path: neo-tree's own events. Every render (expand or
  -- collapse re-renders) and window open/close schedules a debounced save, so
  -- the state survives :restart, crashes, and kills.
  local ok, events = pcall(require, "neo-tree.events")
  if ok then
    for _, ev in ipairs({
      events.AFTER_RENDER or "after_render",
      events.NEO_TREE_WINDOW_AFTER_OPEN or "neo_tree_window_after_open",
      events.NEO_TREE_WINDOW_AFTER_CLOSE or "neo_tree_window_after_close",
    }) do
      events.subscribe({ event = ev, handler = M.saver.touch })
    end
  end

  local group = vim.api.nvim_create_augroup("config.workspace.explorer", { clear = true })

  -- Any session load, not just auto-session's: when no auto-session file
  -- exists (auto_delete_empty_sessions drops it once only the tree is left),
  -- the :restart session is the only one sourced and post-restore hooks never
  -- run. Swap its empty neo-tree stand-in for the real tree.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      if M.saver.active() and M.wipe_foreign_buffers() then
        M.saver.defer(function()
          require("neo-tree.command").execute({ action = "show" })
        end, 200)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.saver.exit,
  })
end

return M
