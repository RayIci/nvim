---Per-project workspace state, persisted at mutation time (exit hooks alone
---lose state on :restart, crashes and kills; VimLeavePre remains a backstop).
---
---  snapshot   stdpath("state")/workspaces/<cwd-key>.json: DAP breakpoints,
---             the buffer list and bufferline pins (buffers.lua,
---             breakpoints.lua, pins.lua), saved on change, debounced
---  explorer   stdpath("state")/neotree/<cwd-key>.json: neo-tree expansion and
---             open state (explorer.lua), saved on neo-tree's own events
---  scope      per-tab buffer lists, carried in the session file (scope.lua)
---
---Restore: breakpoints per file on BufReadPost; buffers, pins, scope and the
---explorer are reconciled against the possibly stale auto-session file by the
---session hooks below. Workspace transitions (git worktree switches) drive
---pause/flush/restore_workspace/reset_workspace/resume.
---@class Workspace
local M = {}

local state = require("config.state")
local breakpoints = require("config.workspace.breakpoints")
local buffers = require("config.workspace.buffers")
local explorer = require("config.workspace.explorer")
local pins = require("config.workspace.pins")
local scope = require("config.workspace.scope")

---Persisted per-project snapshot.
---@class WorkspaceState
---@field breakpoints table<string, WorkspaceBreakpoint[]> absolute file path -> breakpoints
---@field buffers string[] open real-file buffers (the bufferline set)
---@field pinned string comma-separated pinned buffer paths (bufferline format)

---@param cwd? string
---@return WorkspaceState
---@return boolean exists
local function load(cwd)
  local path = state.path("workspaces", cwd)
  local data, exists = state.read(path, nil)
  if not exists then
    return { breakpoints = {}, buffers = {}, pinned = "" }, false
  end
  assert(type(data) == "table", "Invalid workspace snapshot: " .. path)
  data.breakpoints = data.breakpoints or {}
  data.buffers = data.buffers or {}
  data.pinned = data.pinned or ""
  assert(
    type(data.breakpoints) == "table" and type(data.buffers) == "table" and type(data.pinned) == "string",
    "Invalid workspace snapshot: " .. path
  )
  return data, true
end

---Write the full snapshot for `cwd`.
---@param cwd string
local function persist(cwd)
  local snapshot = load(cwd)
  snapshot.breakpoints = breakpoints.merge(snapshot.breakpoints)
  snapshot.buffers = buffers.collect()
  snapshot.pinned = pins.collect()
  state.write(state.path("workspaces", cwd), snapshot)
end

local saver = state.saver({ label = "Workspace save", save = persist })

---Debounced snapshot save; the single entry point for change-time triggers.
M.touch = saver.touch

---Stop all workspace writes and drop pending ones (start of a transition).
function M.pause()
  saver.pause()
  explorer.saver.pause()
end

function M.resume()
  saver.resume()
  explorer.saver.resume()
end

---Write the snapshot and explorer state for the current cwd now. Errors
---propagate, so a transition aborts before anything is torn down.
function M.flush()
  saver.flush()
  explorer.saver.flush()
end

---Bring buffers and pins in line with the snapshot after a session restore.
---@param managed? boolean allow replacing stale displayed buffers during a managed restore
function M.reconcile_buffers(managed)
  local snapshot, exists = load()
  if not exists then
    return
  end
  pins.seed(snapshot.pinned)
  buffers.reconcile(snapshot.buffers, managed)
end

---Replace registered breakpoints with the snapshot's, for loaded buffers.
function M.restore_breakpoints()
  local snapshot, exists = load()
  if exists then
    breakpoints.restore(snapshot.breakpoints)
  end
end

---Re-apply every part of the workspace for the current cwd. Managed restores
---run synchronously; no deferred callback from the previous workspace can
---finish them.
---@param managed? boolean
function M.restore_workspace(managed)
  scope.restore()
  M.reconcile_buffers(managed)
  M.restore_breakpoints()
  pins.sync()
  explorer.restore(managed)
end

---Clear explorer and pin state before the editor is torn down for another
---workspace.
function M.reset_workspace()
  explorer.reset()
  pins.reset()
end

---auto-session hooks (pre_save_cmds, pre_restore_cmds, post_restore_cmds).
M.session = {
  pre_save = scope.save,
  pre_restore = function()
    explorer.saver.invalidate()
    vim.cmd("ScopeLoadState")
  end,
  ---Reconcile first: it re-adds/drops buffers changed since the (possibly
  ---stale) session save and seeds fresh pin data for the deferred sync.
  post_restore = function()
    if explorer.saver.active() then
      scope.restore()
      M.reconcile_buffers()
      explorer.saver.defer(pins.sync, 500)
      explorer.saver.defer(explorer.restore, 200)
    end
  end,
}

---Register the session-side triggers. Call right before auto-session.setup()
---(see explorer.setup for why the order matters).
function M.setup_session()
  pins.setup()
  explorer.setup()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config.workspace", { clear = true })

  breakpoints.watch(M.touch)

  -- Buffer-list changes persist as they happen (debounced past the event,
  -- since BufDelete fires while the buffer is still listed).
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufFilePost" }, {
    group = group,
    callback = M.touch,
  })

  -- Reopening a file brings its breakpoints back, session-restored or not.
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      local file = vim.api.nvim_buf_get_name(ev.buf)
      if file ~= "" then
        breakpoints.restore_buffer(ev.buf, load().breakpoints[file])
      end
    end,
  })

  -- Backstop; the change-time saves above have already written everything.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = saver.exit,
  })
end

return M
