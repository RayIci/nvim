---commitsmith: AI commit messages with an interactive refinement window
---(RayIci/commitsmith.nvim). This module is the only place that knows about
---both the plugin and the rest of this configuration.
---@class PluginCommitsmith
local M = {}

function M.setup()
  require("commitsmith").setup({
    -- Outside a gitcommit buffer the prompt goes to whatever Sidekick session is
    -- attached, which is the interactive path the plugin deliberately knows
    -- nothing about.
    on_fallback = function(prompt)
      require("sidekick.cli").send({ prompt = prompt })
    end,
  })

  local commitsmith = require("commitsmith")
  local map = vim.keymap.set

  map("n", "<leader>am", commitsmith.generate, { desc = "Draft commit message" })
  map("n", "<leader>aM", commitsmith.harness, { desc = "Configure commit AI" })
  map("n", "<leader>ac", commitsmith.chat, { desc = "Commit message chat" })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.commitsmith", { clear = true }),
    pattern = "gitcommit",
    callback = function(ev)
      local function buf_map(lhs, fn, desc)
        map("n", lhs, fn, { buffer = ev.buf, desc = desc })
      end
      buf_map("<leader>gm", commitsmith.generate, "Draft commit message")
      buf_map("<leader>gM", commitsmith.harness, "Configure commit AI")
      -- Shadows the neogit commit popup, which cannot do anything useful from
      -- inside a commit buffer.
      buf_map("<leader>gc", commitsmith.chat, "Commit message chat")
    end,
  })
end

return M
