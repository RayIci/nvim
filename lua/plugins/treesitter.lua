---nvim-treesitter (main branch): parser install + per-filetype highlight/indent.
---Main-branch API: require('nvim-treesitter').install(), vim.treesitter.start(),
---and an experimental indentexpr. No configs.setup() — that is the old API.
---@class PluginTreesitter
local M = {}

function M.setup()
  require("nvim-treesitter").setup({})
end

---Install parsers from language packs and enable highlight+indent for them.
---@param parsers string[] parser names from the merged language packs
function M.apply(parsers)
  -- Always useful parsers on top of what packs declare
  local wanted = vim.list_extend({
    "vim", "vimdoc", "query", "markdown", "markdown_inline",
    "regex", "bash", "diff", "gitcommit", "json", "yaml", "toml",
  }, parsers)

  require("nvim-treesitter").install(wanted)

  -- Map parser -> filetypes it serves and start treesitter there.
  ---@type string[]
  local fts = {}
  for _, parser in ipairs(wanted) do
    vim.list_extend(fts, vim.treesitter.language.get_filetypes(parser))
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.treesitter", { clear = true }),
    pattern = fts,
    callback = function(ev)
      -- Parser may still be installing on very first launch; don't error.
      if not pcall(vim.treesitter.start, ev.buf) then
        return
      end
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  })
end

return M
