---Per-project workspace state — deliberately plugin-free.
---Everything persists at mutation time (exit hooks alone lose state on
---:restart, crashes, and kills; VimLeavePre remains only as a backstop):
---  * DAP breakpoints  — every mutating dap.breakpoints function is wrapped
---  * buffer list      — BufAdd/BufDelete/BufFilePost, debounced
---  * bufferline pins  — vim.g.BufferlinePinnedBuffers snapshot (bufferline
---                       keeps that global current on every pin toggle)
---Restore: breakpoints per file on BufReadPost; buffers+pins are reconciled
---against the possibly-stale auto-session file after session restore.
---
---Layout under stdpath('state'): workspaces/<cwd-key>.json

---One persisted breakpoint.
---@class WorkspaceBreakpoint
---@field lnum integer
---@field condition? string
---@field log_message? string
---@field hit_condition? string

---Persisted per-project state.
---@class WorkspaceState
---@field breakpoints table<string, WorkspaceBreakpoint[]> absolute file path -> breakpoints
---@field buffers string[] listed real-file buffers (the bufferline set)
---@field pinned string comma-separated pinned buffer paths (bufferline format)

---@class Workspace
local M = {}

local state_dir = vim.fn.stdpath("state") --[[@as string]]

---True once exit has started; blocks late debounced writes racing teardown.
local exiting = false

---Filesystem-safe key for the current project.
---@return string
local function project_key()
  return (vim.fn.getcwd():gsub("[/\\:]", "%%"))
end

---@return string
local function json_path()
  return vim.fs.joinpath(state_dir, "workspaces", project_key() .. ".json")
end

---@return WorkspaceState
local function load_state()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(json_path()), "\n"))
  end)
  if ok and type(data) == "table" then
    data.breakpoints = data.breakpoints or {}
    data.buffers = data.buffers or {}
    data.pinned = data.pinned or ""
    return data
  end
  return { breakpoints = {}, buffers = {}, pinned = "" }
end

---@param state WorkspaceState
local function save_state(state)
  local path = json_path()
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
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

---Listed buffers backed by readable files — the set bufferline shows.
---@return string[]
local function collect_buffers()
  local files = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        table.insert(files, name)
      end
    end
  end
  return files
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

---Write the full workspace snapshot. Breakpoints merge (files with loaded
---buffers are authoritative, including deletions; unopened files keep their
---stored breakpoints); buffers and pins are plain snapshots.
local function persist()
  local state = load_state()
  local current = collect_breakpoints()
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
  state.buffers = collect_buffers()
  state.pinned = vim.g.BufferlinePinnedBuffers or ""
  save_state(state)
end

local persist_timer = assert(vim.uv.new_timer())

---Debounced persist; the single entry point for all change-time triggers.
function M.touch()
  if exiting then
    return
  end
  persist_timer:stop()
  persist_timer:start(500, 0, vim.schedule_wrap(function()
    if not exiting then
      pcall(persist)
    end
  end))
end

---Wrap every mutating function of dap.breakpoints so any change — from our
---keymaps, dap-ui, or the API — schedules a save.
local function persist_on_breakpoint_change()
  local breakpoints = require("dap.breakpoints")
  for _, fname in ipairs({ "set", "remove", "remove_by_id", "toggle", "clear" }) do
    local orig = breakpoints[fname]
    if orig then
      breakpoints[fname] = function(...)
        local result = orig(...)
        M.touch()
        return result
      end
    end
  end
end

---Bring the buffer list and pins in line with the change-time snapshot after
---a session restore: the session file goes stale on :restart/crash, so files
---opened since then are added back and files closed since then are dropped
---(never touching modified or window-displayed buffers). Pins seed
---vim.g.BufferlinePinnedBuffers so the bufferline re-sync uses fresh data.
function M.reconcile_buffers()
  local state = load_state()

  if state.pinned ~= "" then
    vim.g.BufferlinePinnedBuffers = state.pinned
  end

  if #state.buffers == 0 then
    return
  end

  local want = {}
  for _, file in ipairs(state.buffers) do
    want[file] = true
  end

  local have = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        have[name] = true
      end
    end
  end

  for file in pairs(want) do
    if not have[file] and vim.fn.filereadable(file) == 1 then
      vim.cmd.badd(vim.fn.fnameescape(file))
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and not vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and not want[name] and vim.fn.filereadable(name) == 1 then
        local displayed = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then
            displayed = true
            break
          end
        end
        if not displayed then
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config.workspace", { clear = true })

  persist_on_breakpoint_change()

  -- Buffer-list changes persist as they happen (debounced past the event,
  -- since BufDelete fires while the buffer is still listed).
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufFilePost" }, {
    group = group,
    callback = M.touch,
  })

  -- Reopening a file brings its breakpoints back — session-restored or not.
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      local file = vim.api.nvim_buf_get_name(ev.buf)
      if file ~= "" then
        restore_breakpoints_for(ev.buf, file, load_state())
      end
    end,
  })

  -- Backstop; the change-time saves above have already written everything.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      exiting = true
      persist_timer:stop()
      pcall(persist)
    end,
  })
end

return M
