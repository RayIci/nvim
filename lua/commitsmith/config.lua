---Merged commitsmith options. `setup()` writes here once; everything else reads.
---Kept in its own module so `settings` and the harness adapters can reach the
---options without requiring the entry point (which requires them).
---@class CommitsmithConfig
local M = {}

---@class CommitsmithWindowOpts
---@field layout "right"|"left"|"bottom"|"top"|"float"
---@field width integer columns, for left/right layouts
---@field height integer lines, for top/bottom layouts
---@field border string float border style

---@class CommitsmithOpts
---@field harness string harness used until the user picks one
---@field models table<string, CommitsmithModel[]> per-harness model list overrides
---@field output "stream"|"batch" render replies progressively, or once complete
---@field conversation "auto"|"session"|"replay" how follow-up turns carry context
---@field apply "auto"|"manual" replace the commit message on every revision, or on accept
---@field window CommitsmithWindowOpts
---@field on_fallback fun(prompt: string)? called for `generate` outside a gitcommit buffer
---@field seed fun(): CommitsmithStoredSettings? one-time settings seed, for migrations

---@type CommitsmithOpts
local defaults = {
  harness = "copilot",
  models = {},
  output = "stream",
  conversation = "auto",
  apply = "auto",
  window = {
    layout = "right",
    width = 84,
    height = 20,
    border = "rounded",
  },
  on_fallback = nil,
  seed = nil,
}

---@type CommitsmithOpts
M.options = vim.deepcopy(defaults)

---@param opts CommitsmithOpts?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
