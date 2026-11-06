---The buffer list in the workspace snapshot: the real-file buffers bufferline
---shows (listed, or scoped to another tab), and reconciling a restored
---session against it.
---@class WorkspaceBuffers
local M = {}

local scope = require("config.workspace.scope")

---Open buffers backed by readable files.
---@return string[]
function M.collect()
  local files = {}
  local scoped = scope.buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and scope.is_open(buf, scoped) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        table.insert(files, name)
      end
    end
  end
  return files
end

---@param buf integer
---@return boolean
local function displayed(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

---Bring the open buffers in line with the change-time snapshot after a
---session restore: the session file goes stale on :restart/crash, so files
---opened since then are added back and files closed since then are dropped
---(never touching modified or, outside managed restores, displayed buffers).
---@param files string[] the snapshot's buffer list
---@param managed? boolean allow replacing stale displayed buffers during a managed restore
function M.reconcile(files, managed)
  local want = {}
  for _, file in ipairs(files) do
    want[file] = true
  end

  local scoped = scope.buffers()
  local have = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if scope.is_open(buf, scoped) then
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
    if scope.is_open(buf, scoped) and not vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and not want[name] and vim.fn.filereadable(name) == 1 then
        local shown = displayed(buf)
        if (managed or #files == 0) and shown then
          require("config.buffers").close(buf)
        elseif not shown then
          vim.api.nvim_buf_delete(buf, {})
        end
      end
    end
  end
end

return M
