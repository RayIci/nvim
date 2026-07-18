---vim-visual-multi: multi-cursor editing.
---Stock bindings already match the requested UX:
---  <C-n>  select word under cursor / add next occurrence
---  q      skip current occurrence and grab the next
---  Q      remove current region
---  n/N    get next/previous occurrence   [ / ] navigate cursors
---Regions highlight live and edits appear on every cursor in real time.
---@class PluginVisualMulti
local M = {}

function M.setup()
  -- Silence the default "exit" delay hint and use a nicer theme
  vim.g.VM_set_statusline = 0 -- lualine already shows VM's mode via vim.b.VM_Selection
  vim.g.VM_silent_exit = 1
  vim.g.VM_show_warnings = 0
end

return M
