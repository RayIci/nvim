---GitHub Copilot ghost text via NATIVE vim.lsp.inline_completion (Neovim 0.12)
---backed by copilot-language-server (installed through mason). No copilot.lua
---plugin. Server definition ("copilot") ships with nvim-lspconfig, including
---:LspCopilotSignIn / :LspCopilotSignOut buffer commands for first-time auth.
---@class PluginCopilot
local M = {}

function M.setup()
  vim.lsp.enable("copilot")

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config.copilot", { clear = true }),
    callback = function(ev)
      local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
      if not client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, ev.buf) then
        return
      end

      vim.lsp.inline_completion.enable(true, { bufnr = ev.buf })

      -- Classic copilot.vim-style keys; Tab stays free for blink/snippets.
      vim.keymap.set("i", "<M-l>", function()
        if not vim.lsp.inline_completion.get() then
          vim.notify("No inline suggestion", vim.log.levels.INFO)
        end
      end, { buffer = ev.buf, desc = "Accept inline suggestion" })
      vim.keymap.set("i", "<M-]>", function()
        vim.lsp.inline_completion.select({ count = 1 })
      end, { buffer = ev.buf, desc = "Next inline suggestion" })
      vim.keymap.set("i", "<M-[>", function()
        vim.lsp.inline_completion.select({ count = -1 })
      end, { buffer = ev.buf, desc = "Previous inline suggestion" })
    end,
  })

  vim.keymap.set("n", "<leader>ua", function()
    local enabled = not vim.lsp.inline_completion.is_enabled()
    vim.lsp.inline_completion.enable(enabled)
    vim.notify("Inline AI completion: " .. (enabled and "on" or "off"))
  end, { desc = "Toggle inline AI completion" })
end

return M
