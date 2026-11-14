-- Entry point. Order matters:
-- options -> plugins on rtp -> plugin setup -> language packs -> maps/autocmds -> workspace state.
-- Opt-in session profiler (NVIM_PROFILE=1); must precede every plugin.
require("config.profile").setup()
require("config.options")

-- Embedded in VS Code (vscode-neovim): VS Code owns the UI, LSP and plugins, so
-- only the keymap bridge is loaded. See lua/config/vscode.lua.
if vim.g.vscode then
  require("config.vscode")
  return
end

require("config.pack")
require("plugins").setup()
require("config.clipboard") -- after plugins so its startup notify renders via noice
require("langs").setup()
require("config.keymaps")
require("config.folds").setup()
require("config.statuscolumn").setup()
require("config.leader_doctor").setup()
require("config.autocmds")
require("config.workspace").setup()
