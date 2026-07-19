---GitHub Copilot ghost text via NATIVE vim.lsp.inline_completion (Neovim 0.12)
---backed by copilot-language-server (installed through mason). No copilot.lua
---plugin. Server definition ("copilot") ships with nvim-lspconfig, including
---:LspCopilotSignIn / :LspCopilotSignOut buffer commands for first-time auth.
---@class PluginCopilot
local M = {}

---Ghost text only appears once GitHub auth exists. The language server writes
---credentials to ~/.config/github-copilot/ on :LspCopilotSignIn; if neither
---token file is there yet, nudge once instead of failing silently.
local function warn_if_signed_out()
  local config_home = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME or "", ".config")
  for _, name in ipairs({ "apps.json", "hosts.json" }) do
    if vim.fn.filereadable(vim.fs.joinpath(config_home, "github-copilot", name)) == 1 then
      return
    end
  end
  vim.notify("Copilot is not signed in — run :LspCopilotSignIn to enable inline suggestions", vim.log.levels.WARN)
end

function M.setup()
  vim.lsp.enable("copilot")

  local warned = false

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config.copilot", { clear = true }),
    callback = function(ev)
      local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
      if not client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, ev.buf) then
        return
      end

      if not warned then
        warned = true
        warn_if_signed_out()
      end

      vim.lsp.inline_completion.enable(true, { bufnr = ev.buf })

      -- Old-config keys. Partial accepts ride the native on_accept hook, which
      -- exists precisely to trim a suggestion before insertion; snippets
      -- (non-string insert_text) fall back to a full accept.
      ---@param trim? fun(text: string): string
      local function accept(trim)
        return function()
          local ok = vim.lsp.inline_completion.get({
            on_accept = trim and function(item)
              if type(item.insert_text) == "string" then
                item.insert_text = trim(item.insert_text)
              end
              return item
            end or nil,
          })
          if not ok then
            vim.notify("No inline suggestion", vim.log.levels.INFO)
          end
        end
      end
      local function dismiss()
        -- No public dismiss API: a buffer-scoped disable/enable cycle clears
        -- the visible ghost text without touching the global toggle.
        vim.lsp.inline_completion.enable(false, { bufnr = ev.buf })
        vim.lsp.inline_completion.enable(true, { bufnr = ev.buf })
      end

      vim.keymap.set("i", "<C-t>", accept(function(text)
        return text:match("^[^\n]*\n?") or text
      end), { buffer = ev.buf, desc = "Accept suggestion line" })
      vim.keymap.set("i", "<C-w>", accept(function(text)
        return text:match("^%s*%S+") or text
      end), { buffer = ev.buf, desc = "Accept suggestion word" })
      vim.keymap.set("i", "<M-l>", accept(), { buffer = ev.buf, desc = "Accept inline suggestion" })
      vim.keymap.set("i", "<C-]>", dismiss, { buffer = ev.buf, desc = "Dismiss inline suggestion" })
      vim.keymap.set("i", "<M-]>", function()
        vim.lsp.inline_completion.select({ count = 1 })
      end, { buffer = ev.buf, desc = "Next inline suggestion" })
      vim.keymap.set("i", "<M-[>", function()
        vim.lsp.inline_completion.select({ count = -1 })
      end, { buffer = ev.buf, desc = "Previous inline suggestion" })
    end,
  })

  -- Belt-and-braces ghost-text cleanup when leaving insert or the buffer
  -- (ported from the old config's CopilotCleanup autocmd).
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = vim.api.nvim_create_augroup("config.copilot.cleanup", { clear = true }),
    callback = function(ev)
      if vim.lsp.inline_completion.is_enabled({ bufnr = ev.buf }) then
        vim.lsp.inline_completion.enable(false, { bufnr = ev.buf })
        vim.lsp.inline_completion.enable(true, { bufnr = ev.buf })
      end
    end,
  })

  vim.keymap.set("n", "<leader>ua", function()
    local enabled = not vim.lsp.inline_completion.is_enabled()
    vim.lsp.inline_completion.enable(enabled)
    vim.notify("Inline AI completion: " .. (enabled and "on" or "off"))
  end, { desc = "Toggle inline AI completion" })
end

return M
