---DAP breakpoints in the workspace snapshot: collected per file and
---re-applied to each buffer when it is read.
---@class WorkspaceBreakpoints
local M = {}

---One persisted breakpoint.
---@class WorkspaceBreakpoint
---@field lnum integer
---@field condition? string
---@field log_message? string
---@field hit_condition? string

---Current DAP breakpoints by absolute file path.
---@return table<string, WorkspaceBreakpoint[]>
function M.collect()
  ---@type table<string, WorkspaceBreakpoint[]>
  local by_file = {}
  for bufnr, list in pairs(require("dap.breakpoints").get()) do
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

---Merge the live breakpoints into stored ones: files with a loaded buffer are
---authoritative (including deletions); unopened files keep what was stored.
---@param stored table<string, WorkspaceBreakpoint[]>
---@return table<string, WorkspaceBreakpoint[]>
function M.merge(stored)
  local current = M.collect()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local file = vim.api.nvim_buf_get_name(bufnr)
      if file ~= "" and stored[file] and not current[file] then
        stored[file] = nil
      end
    end
  end
  for file, list in pairs(current) do
    stored[file] = list
  end
  return stored
end

---Re-apply persisted breakpoints for one loaded buffer.
---@param bufnr integer
---@param list? WorkspaceBreakpoint[]
function M.restore_buffer(bufnr, list)
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

---Replace all registered breakpoints with the stored ones of loaded buffers.
---@param stored table<string, WorkspaceBreakpoint[]>
function M.restore(stored)
  require("dap.breakpoints").clear()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.restore_buffer(buf, stored[vim.api.nvim_buf_get_name(buf)])
    end
  end
end

---Call `on_change` after every mutating dap.breakpoints function, so changes
---from keymaps, dap-ui or the API all schedule a save.
---@param on_change fun()
function M.watch(on_change)
  local breakpoints = require("dap.breakpoints")
  for _, fname in ipairs({ "set", "remove", "remove_by_id", "toggle", "clear" }) do
    local orig = breakpoints[fname]
    if orig then
      breakpoints[fname] = function(...)
        local result = orig(...)
        on_change()
        return result
      end
    end
  end
end

return M
