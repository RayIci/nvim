---noice.nvim: cmdline popup and message routing only. LSP hover uses Neovim's
---native treesitter markdown rendering and signature help is owned by blink.cmp,
---so all noice LSP handlers/overrides stay disabled (see plugins/render-markdown).
---@class PluginNoice
local M = {}

function M.setup()
  require("noice").setup({
    lsp = {
      hover = { enabled = false },
      signature = { enabled = false },
    },
    -- Classic bottom-row cmdline (noice-rendered), not the centered popup
    cmdline = { view = "cmdline" },
    routes = {
      -- Surface mode messages (macro "recording @x") that noice would swallow
      { view = "notify", filter = { event = "msg_showmode" } },
    },
    presets = {
      bottom_search = true,
      long_message_to_split = true,
    },
  })

  -- noice stops handling every UI event once v:exiting is set. With
  -- cmdheight=0, any message printed during exit (e.g. a plugin's VimLeavePre)
  -- then raises Nvim 0.12's "Press any key to continue" prompt (a cmdline_show
  -- event, not the msg_show return_prompt noice knows) that nothing draws or
  -- answers: :restart / :qa hang until a key is pressed. Answer exactly that
  -- prompt, for the exit phase only — real questions (confirm) stay untouched.
  -- Attached up front: the prompt fires synchronously inside whichever exit
  -- handler prints, possibly before a VimLeavePre of ours would run.
  vim.ui_attach(
    vim.api.nvim_create_namespace("plugins.noice.exit_prompt"),
    { ext_messages = true },
    function(event, _, _, _, prompt)
      if event == "cmdline_show" and prompt == "Press any key to continue" and vim.v.exiting ~= vim.NIL then
        vim.api.nvim_input("<cr>")
      end
    end
  )

  vim.keymap.set("n", "<leader>un", "<cmd>NoiceDismiss<cr>", { desc = "Dismiss notifications" })
  vim.keymap.set("n", "<leader>fn", "<cmd>Noice telescope<cr>", { desc = "Notification history" })
end

return M
