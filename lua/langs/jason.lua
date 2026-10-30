---Jason (AgentSpeak / BDI) language pack: jason.nvim, which bundles the
---plugin (filetypes, syntax, indent, snippets, :Jason, jasonlint/jasonfmt),
---the tree-sitter grammar (tree-sitter-jason/) and the language server
---(server/, jason_ls).

-- Where vim.pack installs jason.nvim.
local plugin_path = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "site", "pack", "core", "opt", "jason.nvim")
local has_server = vim.uv.fs_stat(vim.fs.joinpath(plugin_path, "server", "dist", "server.js")) ~= nil

-- plugins.treesitter installs parsers before plugin/ files (where jason.nvim
-- registers its grammar) are sourced, so register the bundled grammar here.
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("langs.jason.treesitter", { clear = true }),
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").jason = {
      install_info = { path = plugin_path, location = "tree-sitter-jason", queries = "tree-sitter-jason/queries" },
    }
  end,
})

---@type LangPack
return {
  packs = {
    {
      src = "RayIci/jason.nvim",
      -- Build the bundled language server on install and update.
      build = function(path)
        local server = vim.fs.joinpath(path, "server")
        if vim.fn.executable("npm") == 1 and vim.uv.fs_stat(server) then
          vim.system({ "npm", "ci", "--no-audit", "--no-fund" }, { cwd = server }):wait()
          vim.system({ "npm", "run", "build" }, { cwd = server }):wait()
        end
      end,
    },
  },
  -- lsp/jason_ls.lua (in jason.nvim) runs the bundled server.
  lsp = { jason_ls = {} },
  -- Install only: jason.nvim starts highlighting itself and keeps its own
  -- indentexpr (plugins.treesitter would switch to tree-sitter indent).
  treesitter = { jason = {} },
  -- jason.nvim ships the nvim-lint and conform definitions
  -- (lua/lint/linters/jasonlint.lua, lua/conform/formatters/jasonfmt.lua).
  linters = { jason = { "jasonlint" }, mas2j = { "jasonlint" } },
  -- .asl: the language server's layout formatter (conform falls back to LSP
  -- when a filetype has no formatter); jasonfmt when the server is missing.
  formatters = {
    jason = not has_server and { "jasonfmt" } or nil,
    mas2j = { "jasonfmt" },
  },
  completion = {
    providers = {
      snippets = {
        opts = {
          -- Keep blink's default path; add the plugin's package.json snippets.
          search_paths = { vim.fn.stdpath("config") .. "/snippets", plugin_path },
        },
      },
    },
  },
  setup = function()
    require("jason").setup({
      -- Run through Overseer like the other language packs.
      runner = function(spec)
        local overseer = require("overseer")
        local task = overseer.new_task({ name = spec.name, cmd = spec.cmd, cwd = spec.cwd })
        task:start()
        overseer.open({ enter = false })
      end,
    })

    require("which-key").add({
      { "<leader>-", group = "Language" },
      { "<leader>-a", group = "Jason (agents)" },
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("langs.jason.maps", { clear = true }),
      pattern = { "jason", "mas2j" },
      callback = function(ev)
        local function bmap(lhs, cmd, desc)
          vim.keymap.set("n", lhs, "<cmd>Jason " .. cmd .. "<cr>", { buffer = ev.buf, desc = desc })
        end
        bmap("<leader>-ar", "run", "Run MAS")
        bmap("<leader>-ac", "compile", "Compile app")
        bmap("<leader>-am", "mind", "Mind Inspector")
      end,
    })
  end,
}
