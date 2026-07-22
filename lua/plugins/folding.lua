---Smart folding via nvim-ufo.
---@class PluginFolding
local M = {}

local ft_provider = {
  git = "",
}

---@param bufnr integer
local function fold_provider_chain(bufnr)
  local function fallback(err, provider)
    if type(err) == "string" and err:match("UfoFallbackException") then
      return require("ufo").getFolds(bufnr, provider)
    end
    return require("promise").reject(err)
  end

  return require("ufo").getFolds(bufnr, "lsp"):catch(function(err)
    return fallback(err, "treesitter")
  end):catch(function(err)
    return fallback(err, "indent")
  end)
end

function M.setup()
  require("ufo").setup({
    provider_selector = function(bufnr, filetype, buftype)
      if buftype ~= "" then
        return ""
      end
      return ft_provider[filetype] or fold_provider_chain
    end,
    preview = {
      win_config = {
        border = "rounded",
        winblend = 0,
      },
    },
  })

  local ufo = require("ufo")
  vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
  vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
  vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, { desc = "Open folds except kinds" })
  vim.keymap.set("n", "zm", ufo.closeFoldsWith, { desc = "Close folds with level" })
end

return M
