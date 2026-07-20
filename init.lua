-- Entry point. Order matters:
-- options -> plugins on rtp -> plugin setup -> language packs -> maps/autocmds -> workspace state.
require("config.options")
require("config.pack")
require("plugins")
require("config.clipboard") -- after plugins so its startup notify renders via noice
require("langs").setup()
require("config.keymaps")
require("config.autocmds")
require("config.workspace").setup()
