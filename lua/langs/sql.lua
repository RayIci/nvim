---SQL language pack: sql-formatter + vim-dadbod (DB client), dadbod-ui
---(drawer), and dadbod completion in sql/mysql/plsql buffers.
---@type LangPack

---Buffer-local mappings replicated from the old config (db_ui_disable_mappings
---is set, so every mapping is explicit).
local function dbui_buffer_maps()
  local group = vim.api.nvim_create_augroup("langs.sql.maps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "dbui",
    callback = function()
      local function bmap(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = true, desc = desc })
      end
      bmap("n", "o", "<Plug>(DBUI_SelectLine)", "Open/Toggle selected item")
      bmap("n", "<cr>", "<Plug>(DBUI_SelectLine)", "Open/Toggle selected item")
      bmap("n", "S", "<Plug>(DBUI_SelectLineVsplit)", "Open in vertical split")
      bmap("n", "d", "<Plug>(DBUI_DeleteLine)", "Delete selected item")
      bmap("n", "R", "<Plug>(DBUI_Redraw)", "Redraw")
      bmap("n", "A", "<Plug>(DBUI_AddConnection)", "Add connection")
      bmap("n", "H", "<Plug>(DBUI_ToggleDetails)", "Toggle database details")
      bmap("n", "r", "<Cmd>DBUIRenameBuffer<Cr>", "Rename/Edit buffer/connection/saved query")
      bmap("n", "q", "<Cmd>DBUIToggle<Cr>", "Close drawer")
      bmap("n", "<C-j>", "<Plug>(DBUI_GoToLastSibling)", "Go to last sibling")
      bmap("n", "<C-k>", "<Plug>(DBUI_GoToFirstSibling)", "Go to first sibling")
      bmap("n", "K", "<Plug>(DBUI_GoToPrevSibling)", "Go to prev sibling")
      bmap("n", "J", "<Plug>(DBUI_GoToNextSibling)", "Go to next sibling")
      bmap("n", "<C-p>", "<Plug>(DBUI_GoToParentNode)", "Go to parent node")
      bmap("n", "<C-n>", "<Plug>(DBUI_GoToChildNode)", "Go to child node")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "sql",
    callback = function()
      vim.keymap.set(
        "n",
        "<leader>Dqw",
        "<Plug>(DBUI_SaveQuery)",
        { buffer = true, desc = "Save currently opened query" }
      )
      vim.keymap.set(
        "n",
        "<leader>Dqe",
        "<Plug>(DBUI_EditBindParameters)",
        { buffer = true, desc = "Edit bind parameters" }
      )
      vim.keymap.set(
        { "n", "v" },
        "<leader>Dqs",
        "<Plug>(DBUI_ExecuteQuery)",
        { buffer = true, desc = "Execute query" }
      )
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "dbout",
    callback = function()
      vim.keymap.set(
        "n",
        "<C-]>",
        "<Plug>(DBUI_JumpToForeignKey)",
        { buffer = true, desc = "Go to entry from foreign key cell" }
      )
      vim.keymap.set(
        "o",
        "ic",
        "<Plug>(DBUI_SelectLineInner)",
        { buffer = true, desc = "Operator pending for cell value" }
      )
      vim.keymap.set(
        "n",
        "<leader>DR",
        "<Plug>(DBUI_ToggleResultLayout)",
        { buffer = true, desc = "Toggle expanded view" }
      )
    end,
  })
end

---Dedicated sqlfluff config that pins a dialect, found by searching upward from
---a file. Only `.sqlfluff`/`.sqlfluff.cfg` count as definitive — pyproject.toml
---and setup.cfg may exist with no `[sqlfluff]` section, and mis-detecting one
---would make us force `--dialect ansi` over a real config.
---@param fname string
---@return string|nil dir containing the config
local function sqlfluff_config_dir(fname)
  if not fname or fname == "" then
    return nil
  end
  local found = vim.fs.find({ ".sqlfluff", ".sqlfluff.cfg" }, {
    path = vim.fs.dirname(fname),
    upward = true,
  })[1]
  return found and vim.fs.dirname(found) or nil
end

---@type LangPack
return {
  treesitter = { "sql" },
  formatters = { sql = { "sqlfluff" } },
  linters = { sql = { "sqlfluff" } },
  mason = { "sqlfluff" },
  packs = {
    { src = "tpope/vim-dadbod" },
    { src = "kristijanhusak/vim-dadbod-ui" },
    { src = "kristijanhusak/vim-dadbod-completion" },
  },
  completion = {
    providers = {
      dadbod = {
        name = "Dadbod",
        module = "vim_dadbod_completion.blink",
      },
    },
    per_filetype = {
      sql = { "dadbod", "snippets", "buffer" },
      mysql = { "dadbod", "snippets", "buffer" },
      plsql = { "dadbod", "snippets", "buffer" },
    },
  },
  setup = function()
    vim.g.db_ui_disable_mappings = 1
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_execute_on_save = false

    require("which-key").add({
      { "<leader>D", group = "Database" },
      { "<leader>Dq", group = "Query" },
    })
    vim.keymap.set("n", "<leader>DD", "<Cmd>DBUIToggle<Cr>", { desc = "Toggle UI" })
    vim.keymap.set("n", "<leader>DA", "<Cmd>DBUIAddConnection<Cr>", { desc = "Add Connection" })
    vim.keymap.set("n", "<leader>DF", "<Cmd>DBUIFindBuffer<Cr>", { desc = "Find Buffer" })

    dbui_buffer_maps()

    -- sqlfluff needs a dialect, and this config spans many (postgres, mysql,
    -- sqlite, tsql, snowflake, bigquery, databricks). Never hardcode one:
    --
    --   Formatting: run only where a dedicated .sqlfluff exists (require_cwd),
    --   so the dialect is always known — `sqlfluff fix` under a generic dialect
    --   could rewrite dialect-specific SQL incorrectly.
    --
    --   Linting: defer to the project config when present (via --stdin-filename
    --   so discovery follows the file, not Neovim's cwd), and fall back to the
    --   permissive `ansi` dialect only when none exists — lint is non-destructive
    --   and a fallback beats sqlfluff erroring with "no dialect specified".
    require("conform").formatters.sqlfluff = {
      cwd = require("conform.util").root_file({ ".sqlfluff", ".sqlfluff.cfg" }),
      require_cwd = true,
    }

    local default_sqlfluff = require("lint.linters.sqlfluff")
    require("lint").linters.sqlfluff = function()
      local linter = vim.deepcopy(default_sqlfluff)
      local fname = vim.api.nvim_buf_get_name(0)
      local args = { "lint", "--format=json" }
      if fname ~= "" then
        vim.list_extend(args, { "--stdin-filename", fname })
      end
      if not sqlfluff_config_dir(fname) then
        vim.list_extend(args, { "--dialect", "ansi" })
      end
      args[#args + 1] = "-"
      linter.args = args
      return linter
    end
  end,
}
