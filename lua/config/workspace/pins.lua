---Bufferline pins. vim.g.BufferlinePinnedBuffers (kept current by bufferline
---on every toggle) rides in the session file and in the workspace snapshot;
---sync() makes bufferline's pinned group match it after a restore.
---@class WorkspacePins
local M = {}

---Current pins in bufferline's comma-separated path format.
---@return string
function M.collect()
  return vim.g.BufferlinePinnedBuffers or ""
end

---Seed the pin set that the next sync() applies.
---@param pinned string
function M.seed(pinned)
  vim.g.BufferlinePinnedBuffers = pinned
end

---Sync bufferline's pinned group to vim.g.BufferlinePinnedBuffers: pins
---missing from bufferline are added, and pins it restored from a stale
---session file but that are no longer pinned are removed.
function M.sync()
  local groups = require("bufferline.groups")
  local Buffer = require("bufferline.models").Buffer

  local want = {}
  for _, path in ipairs(vim.split(M.collect(), ",")) do
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

---Forget every pin (workspace reset).
function M.reset()
  local groups = require("bufferline.groups")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    groups.remove_id_from_manual_groupings(buf)
  end
  M.seed("")
end

function M.setup()
  -- A wiped buffer must not linger in bufferline's manual groupings.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("config.workspace.pins", { clear = true }),
    callback = function(ev)
      require("bufferline.groups").remove_id_from_manual_groupings(ev.buf)
    end,
  })
end

return M
