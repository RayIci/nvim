---Workspace state persistence — deliberately plugin-free.
---
---Per-project (cwd-keyed) state survives restarts:
---  * DAP breakpoints  — restored per file on BufReadPost and after session restore
---  * session          — native :mksession, auto-saved on exit, restored on demand
---  * bufferline pins  — vim.g.BufferlinePinnedBuffers round-trip (bufferline
---                       re-pins on SessionLoadPost, which :source fires)
---
---Layout under stdpath('state'):
---  workspaces/<key>.json  and  sessions/<key>.vim

---One persisted breakpoint.
---@class WorkspaceBreakpoint
---@field lnum integer
---@field condition? string
---@field log_message? string
---@field hit_condition? string

---Persisted per-project state.
---@class WorkspaceState
---@field breakpoints table<string, WorkspaceBreakpoint[]> absolute file path -> breakpoints
---@field pinned string comma-separated pinned buffer paths (bufferline format)

---@class Workspace
local M = {}

local state_dir = vim.fn.stdpath("state") --[[@as string]]

---Filesystem-safe key for the current project.
---@return string
local function project_key()
  return (vim.fn.getcwd():gsub("[/\\:]", "%%"))
end

---@return string
local function json_path()
  return vim.fs.joinpath(state_dir, "workspaces", project_key() .. ".json")
end

---@return string
local function session_path()
  return vim.fs.joinpath(state_dir, "sessions", project_key() .. ".vim")
end

---@param path string
local function ensure_parent(path)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

---@return WorkspaceState
local function load_state()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(json_path()), "\n"))
  end)
  if ok and type(data) == "table" then
    data.breakpoints = data.breakpoints or {}
    data.pinned = data.pinned or ""
    return data
  end
  return { breakpoints = {}, pinned = "" }
end

---@param state WorkspaceState
local function save_state(state)
  local path = json_path()
  ensure_parent(path)
  vim.fn.writefile({ vim.json.encode(state) }, path)
end

---Snapshot current DAP breakpoints into WorkspaceState form.
---@return table<string, WorkspaceBreakpoint[]>
local function collect_breakpoints()
  ---@type table<string, WorkspaceBreakpoint[]>
  local by_file = {}
  local ok, bps = pcall(function()
    return require("dap.breakpoints").get()
  end)
  if not ok then
    return by_file
  end
  for bufnr, list in pairs(bps) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file ~= "" then
      by_file[file] = {}
      for _, bp in ipairs(list) do
        table.insert(by_file[file], {
          lnum = bp.line,
          condition = bp.condition,
          log_message = bp.logMessage,
          hit_condition = bp.hitCondition,
        })
      end
    end
  end
  return by_file
end

---Re-apply persisted breakpoints for one loaded buffer.
---@param bufnr integer
---@param file string absolute path
---@param state WorkspaceState
local function restore_breakpoints_for(bufnr, file, state)
  local list = state.breakpoints[file]
  if not list or #list == 0 then
    return
  end
  local breakpoints = require("dap.breakpoints")
  local lcount = vim.api.nvim_buf_line_count(bufnr)
  for _, bp in ipairs(list) do
    if bp.lnum <= lcount then
      breakpoints.set({
        condition = bp.condition,
        log_message = bp.log_message,
        hit_condition = bp.hit_condition,
      }, bufnr, bp.lnum)
    end
  end
end

---Merge the current session's breakpoints into persisted state.
---Files with buffers loaded now are authoritative (including deletions);
---files not currently open keep their stored breakpoints.
local function persist()
  local state = load_state()
  local current = collect_breakpoints()
  -- Deletions: a loaded buffer with no breakpoints must clear its entry.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local file = vim.api.nvim_buf_get_name(bufnr)
      if file ~= "" and state.breakpoints[file] and not current[file] then
        state.breakpoints[file] = nil
      end
    end
  end
  for file, list in pairs(current) do
    state.breakpoints[file] = list
  end
  state.pinned = vim.g.BufferlinePinnedBuffers or state.pinned or ""
  save_state(state)
end

---Save the session file for this project.
local function save_session()
  local path = session_path()
  ensure_parent(path)
  -- Close plugin-owned windows so they don't leak into the session file.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft:match("^neo%-tree") or ft:match("^dap") or ft == "trouble" or ft == "OverseerList" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  vim.cmd("silent! mksession! " .. vim.fn.fnameescape(path))
end

---Restore the project session: buffers/layout, then pins, then breakpoints.
function M.restore()
  local spath = session_path()
  if vim.fn.filereadable(spath) == 0 then
    vim.notify("No saved session for this directory", vim.log.levels.WARN)
    return
  end
  local state = load_state()

  -- Seed bufferline's global before :source — its once-only SessionLoadPost
  -- handler re-pins buffers from this variable.
  if state.pinned ~= "" then
    vim.g.BufferlinePinnedBuffers = state.pinned
  end

  vim.cmd("silent! source " .. vim.fn.fnameescape(spath))

  -- Breakpoints for every buffer the session brought back.
  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local file = vim.api.nvim_buf_get_name(bufnr)
        if file ~= "" then
          restore_breakpoints_for(bufnr, file, state)
        end
      end
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config.workspace", { clear = true })

  -- Reopening a single file brings its breakpoints back, session or not.
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      local file = vim.api.nvim_buf_get_name(ev.buf)
      if file ~= "" then
        restore_breakpoints_for(ev.buf, file, load_state())
      end
    end,
  })

  -- Persist everything on exit.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      persist()
      save_session()
    end,
  })

  vim.api.nvim_create_user_command("WorkspaceRestore", M.restore, {
    desc = "Restore session, pins, and breakpoints for this directory",
  })
  vim.keymap.set("n", "<leader>qs", M.restore, { desc = "Restore workspace session" })
end

return M
