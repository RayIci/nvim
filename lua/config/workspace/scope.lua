---scope.nvim's per-tab buffer lists in the session: saved into
---vim.g.ScopeState ('globals' is in sessionoptions) and re-applied by tab
---position after a restore.
---@class WorkspaceScope
local M = {}

---Buffers held in any tab's scope. scope.nvim unlists buffers of other tabs,
---so these count as open even though they are not 'buflisted'.
---@return table<integer, true>
function M.buffers()
  local scoped = {}
  local core = package.loaded["scope.core"]
  if core then
    for _, buffers in pairs(core.cache) do
      for _, buf in ipairs(buffers) do
        scoped[buf] = true
      end
    end
  end
  return scoped
end

---Whether a buffer is part of the workspace: listed, or scoped to some tab.
---@param buf integer
---@param scoped table<integer, true> from M.buffers()
---@return boolean
function M.is_open(buf, scoped)
  return vim.bo[buf].buflisted or scoped[buf] == true
end

---auto-session pre-save hook.
function M.save()
  vim.cmd.ScopeSaveState()
  local cache = {}
  local core = require("scope.core")
  local utils = require("scope.utils")
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    cache[#cache + 1] = utils.get_buffer_names(core.cache[tab] or {})
  end
  vim.g.ScopeState = vim.json.encode({ cache = cache, last_tab = core.last_tab })
end

function M.restore()
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

return M
