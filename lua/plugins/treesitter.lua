---nvim-treesitter (main branch): parser install + per-filetype highlight/indent.
---Main-branch API: require('nvim-treesitter').install(), vim.treesitter.start(),
---and an experimental indentexpr. No configs.setup() — that is the old API.
---@class PluginTreesitter
local M = {}

function M.setup()
  -- Registers the dap_repl parser source; must run before nvim-treesitter
  -- installs parsers and before dap.repl loads (old-config order).
  require("nvim-dap-repl-highlights").setup()
  require("nvim-treesitter").setup({})
end

---Install parsers from language packs and enable highlight+indent for them.
---@param ts LangTreesitterMerged parsers + explicit filetype lists from the packs
function M.apply(ts)
  -- Always useful parsers on top of what packs declare
  local wanted = {
    "vim",
    "vimdoc",
    "query",
    "markdown",
    "markdown_inline",
    "regex",
    "bash",
    "diff",
    "json",
    "yaml",
    "toml",
    "c",
    "lua",
    "luadoc",
    "make",
    "dockerfile",
    "editorconfig",
    "xml",
    "http",
    "gitcommit",
    "gitignore",
    "git_rebase",
    "git_config",
    "gitattributes",
    "dap_repl", -- REPL syntax highlighting (nvim-dap-repl-highlights)
  }
  for _, parser in ipairs(ts.parsers) do
    if not vim.list_contains(wanted, parser) then
      wanted[#wanted + 1] = parser
    end
  end

  require("nvim-treesitter").install(wanted)

  ---@type table<string, true>
  local wanted_set = {}
  for _, parser in ipairs(wanted) do
    wanted_set[parser] = true
  end

  -- Explicit `parser = { filetypes }` entries: teach the registry those
  -- filetypes, and remember them as the only ones the parser starts on.
  ---@type table<string, table<string, true>>
  local only = {}
  for parser, fts in pairs(ts.filetypes) do
    if #fts > 0 then
      vim.treesitter.language.register(parser, fts)
    end
    only[parser] = {}
    for _, ft in ipairs(fts) do
      only[parser][ft] = true
    end
  end

  -- Decide per buffer when its filetype is set, not from a filetype list
  -- computed here: nvim-treesitter registers most parser<->filetype mappings
  -- (c_sharp<->cs, bash<->sh, …) in its plugin/ file, which runs after
  -- init.lua, so a list built now would miss them.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.treesitter", { clear = true }),
    callback = function(ev)
      local lang = vim.treesitter.language.get_lang(ev.match)
      if not (lang and wanted_set[lang]) then
        return
      end
      if only[lang] and not only[lang][ev.match] then
        return
      end
      -- Parser may still be installing on very first launch; don't error.
      if not pcall(vim.treesitter.start, ev.buf, lang) then
        return
      end
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  })
end

return M
