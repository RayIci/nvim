---Smart folding via nvim-ufo.
---@class PluginFolding
local M = {}

local ft_provider = {
  git = "",
}

local function close_child_folds()
  local base_level = vim.fn.foldlevel(".")
  if base_level == 0 then
    vim.notify("No fold under cursor", vim.log.levels.WARN)
    return
  end

  local start = vim.fn.line(".")
  while start > 1 and vim.fn.foldlevel(start - 1) >= base_level do
    start = start - 1
  end

  local finish = vim.fn.line(".")
  local last = vim.fn.line("$")
  while finish < last and vim.fn.foldlevel(finish + 1) >= base_level do
    finish = finish + 1
  end

  local closed = 0
  local lnum = start
  while lnum <= finish do
    if vim.fn.foldlevel(lnum) == base_level + 1 then
      if vim.fn.foldclosed(lnum) == -1 then
        vim.cmd(("silent! %dfoldclose"):format(lnum))
        if vim.fn.foldclosed(lnum) ~= -1 then
          closed = closed + 1
        end
      end

      local closed_end = vim.fn.foldclosedend(lnum)
      if closed_end ~= -1 then
        lnum = closed_end + 1
      else
        lnum = lnum + 1
      end
    else
      lnum = lnum + 1
    end
  end

  if closed == 0 then
    vim.notify("No child folds to close", vim.log.levels.INFO)
  end
end

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
  vim.keymap.set("n", "zU", close_child_folds, { desc = "Close child folds" })
end

return M
