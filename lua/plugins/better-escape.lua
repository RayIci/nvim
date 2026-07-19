---better-escape.nvim: jk/jj leave insert mode without the pending-map lag a
---plain `inoremap jk <Esc>` causes (it watches keys instead of mapping them,
---so a typed j renders instantly). Old-config settings: INSERT MODE ONLY —
---default_mappings stays off so no terminal/cmdline sequences are grabbed,
---which would re-break interactive TUIs like lazygit (sent keys can't be
---retracted from a terminal; see the toggleterm jk exclusion for the same
---issue on the terminal side).
---@class PluginBetterEscape
local M = {}

function M.setup()
  require("better_escape").setup({
    timeout = vim.o.timeoutlen,
    default_mappings = false,
    mappings = {
      i = {
        j = {
          k = "<Esc>",
          j = "<Esc>",
        },
      },
    },
  })
end

return M
