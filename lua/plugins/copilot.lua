---GitHub Copilot ghost text via copilot.lua (old-config engine) backed by the
---mason-installed copilot-language-server binary. copilot.lua provides real
---partial accepts (word/line) and its keymaps fall back to the key's default
---behavior whenever no suggestion is visible — the semantics the old config had.
---Auth: :Copilot auth (device flow). The server stores tokens in
---~/.config/github-copilot/auth.db (SQLite WAL); hard WSL shutdowns can lose
---the uncheckpointed WAL — if sign-ins keep evaporating, the old config's
---documented device-flow workaround (manual hosts.json) still works.
---@class PluginCopilot
local M = {}

---Nudge once if no credentials exist yet (new SQLite scheme or legacy JSON).
local function warn_if_signed_out()
  local config_home = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME or "", ".config")
  for _, name in ipairs({ "auth.db", "apps.json", "hosts.json" }) do
    if vim.fn.filereadable(vim.fs.joinpath(config_home, "github-copilot", name)) == 1 then
      return
    end
  end
  vim.notify("Copilot is not signed in — run :Copilot auth to enable inline suggestions", vim.log.levels.WARN)
end

function M.setup()
  local server_bin = vim.fn.expand("$MASON/bin/copilot-language-server")

  require("copilot").setup({
    server = {
      type = "binary",
      custom_server_filepath = vim.fn.executable(server_bin) == 1 and server_bin or nil,
    },
    suggestion = {
      enabled = true,
      auto_trigger = true,
      debounce = 75,
      hide_during_completion = false, -- ghost text stays visible with blink's menu
      -- false: accept keys act ONLY on a visible suggestion and pass through to
      -- their built-in behavior otherwise (<C-w> delete word, <C-t> indent).
      -- true would consume the key to trigger a request, eating the keypress.
      trigger_on_accept = false,
      -- Old-config keys; copilot.lua falls back to the key's built-in behavior
      -- when no suggestion is visible. accept_word is mapped directly below
      -- instead (user never uses insert delete-word; no fallback wanted).
      keymap = {
        accept = "<M-l>",
        accept_word = false,
        accept_line = "<C-t>",
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
      },
    },
    panel = { enabled = true, keymap = { open = false } },
    filetypes = { markdown = true, yaml = true },
  })

  -- Direct accept-word map, no passthrough: harmless no-op without a
  -- suggestion (replaces Nvim's default i_CTRL-W delete-word, unused here).
  vim.keymap.set("i", "<C-w>", function()
    require("copilot.suggestion").accept_word()
  end, { desc = "Accept Copilot word" })

  vim.defer_fn(warn_if_signed_out, 2000)

  -- Clear lingering ghost text when leaving insert mode or the buffer
  -- (ported from the old config's CopilotCleanup autocmd).
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = vim.api.nvim_create_augroup("config.copilot.cleanup", { clear = true }),
    callback = function()
      local ok, suggestion = pcall(require, "copilot.suggestion")
      if ok then
        pcall(suggestion.dismiss)
      end
    end,
  })

  vim.keymap.set("n", "<leader>ua", function()
    require("copilot.suggestion").toggle_auto_trigger()
    vim.notify("Copilot auto-trigger: " .. (vim.b.copilot_suggestion_auto_trigger == false and "off" or "on"))
  end, { desc = "Toggle Copilot auto-trigger" })
end

return M
