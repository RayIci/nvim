---auto-session: per-cwd sessions, saved automatically on exit and restored
---automatically when Neovim starts with no file arguments. Everything a session
---file cannot hold on its own (neo-tree state, fresh pins and buffer lists,
---breakpoints, scope's per-tab buffers) is persisted by config.workspace and
---re-applied through the hooks below.
---@class PluginAutoSession
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "rmagatti/auto-session",
}

function M.setup()
  local workspace = require("config.workspace")
  -- Before auto-session.setup(): the explorer's VimLeavePre must run first.
  workspace.setup_session()

  require("auto-session").setup({
    auto_save = true,
    auto_restore = true, -- only fires on argument-less startup with a saved session
    show_auto_restore_notif = false,
    -- Keep plugin windows out of saved sessions
    bypass_save_filetypes = { "neo-tree", "trouble", "OverseerList", "oil" },
    -- scope.nvim per-tab buffer state rides the session as a global variable
    -- ('globals' is in sessionoptions).
    -- diffbandit's views are closed before the exit-time save (only then).
    pre_save_cmds = { workspace.session.pre_save, require("plugins.diffbandit").close_on_exit },
    pre_restore_cmds = { workspace.session.pre_restore },
    post_restore_cmds = { workspace.session.post_restore },
    session_lens = { load_on_setup = true, previewer = false },
  })

  local map = vim.keymap.set
  map("n", "<leader>qs", "<cmd>AutoSession save<cr>", { desc = "Save session" })
  map("n", "<leader>qr", "<cmd>AutoSession restore<cr>", { desc = "Restore session" })
  map("n", "<leader>ql", "<cmd>AutoSession search<cr>", { desc = "Search sessions" })
  map("n", "<leader>qd", "<cmd>AutoSession delete<cr>", { desc = "Delete session" })
  map("n", "<leader>qt", "<cmd>AutoSession toggle<cr>", { desc = "Toggle session auto-save" })
end

return M
