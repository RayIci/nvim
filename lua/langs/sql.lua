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
---a file. Generic config containers only count when they have a sqlfluff section.
---@param fname string
---@return string|nil dir containing the config
local function sqlfluff_config_dir(fname)
  if not fname or fname == "" then
    return nil
  end
  local names = { ".sqlfluff", ".sqlfluff.cfg", "pyproject.toml", "setup.cfg", "tox.ini", "pep8.ini" }
  local dir = vim.fs.dirname(fname)

  while dir do
    for _, name in ipairs(names) do
      local path = vim.fs.joinpath(dir, name)
      if vim.fn.filereadable(path) == 1 then
        if name == ".sqlfluff" or name == ".sqlfluff.cfg" then
          return dir
        end

        local ok, lines = pcall(vim.fn.readfile, path)
        if ok then
          for _, line in ipairs(lines) do
            if
              (name == "pyproject.toml" and line:match("^%s*%[tool%.sqlfluff[%].]"))
              or (name ~= "pyproject.toml" and line:match("^%s*%[sqlfluff[%].]"))
            then
              return dir
            end
          end
        end
      end
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

local sqlfluff_dialect_pref = "sqlfluff_dialect"
local sqlfluff_default_dialect = "ansi"
local sqlfluff_dialects = {
  "ansi",
  "athena",
  "bigquery",
  "clickhouse",
  "databricks",
  "db2",
  "doris",
  "duckdb",
  "exasol",
  "flink",
  "greenplum",
  "hive",
  "impala",
  "mariadb",
  "materialize",
  "mysql",
  "oracle",
  "postgres",
  "redshift",
  "snowflake",
  "soql",
  "sparksql",
  "sqlite",
  "starrocks",
  "teradata",
  "trino",
  "tsql",
  "vertica",
}

local sqlfluff_dialect_set = {}
for _, dialect in ipairs(sqlfluff_dialects) do
  sqlfluff_dialect_set[dialect] = true
end

local function selected_sqlfluff_dialect()
  local dialect = require("config.prefs").get(sqlfluff_dialect_pref, sqlfluff_default_dialect)
  if type(dialect) == "string" then
    dialect = dialect:lower()
  end
  return sqlfluff_dialect_set[dialect] and dialect or sqlfluff_default_dialect
end

---@param dialect string
local function set_sqlfluff_dialect(dialect)
  dialect = dialect:lower()
  if not sqlfluff_dialect_set[dialect] then
    vim.notify("SQLFluff: unknown dialect '" .. dialect .. "'", vim.log.levels.ERROR)
    return
  end

  require("config.prefs").set(sqlfluff_dialect_pref, dialect)
  vim.notify("SQLFluff fallback dialect: " .. dialect .. " (project config still takes precedence)")
end

local function select_sqlfluff_dialect()
  local current = selected_sqlfluff_dialect()
  vim.ui.select(sqlfluff_dialects, {
    prompt = "SQLFluff fallback dialect",
    format_item = function(item)
      return item == current and (item .. " (current)") or item
    end,
  }, function(choice)
    if choice then
      set_sqlfluff_dialect(choice)
    end
  end)
end

---@param subcommand string
---@param fname string
---@return string[]
local function sqlfluff_args(subcommand, fname)
  local args = { subcommand }
  if subcommand == "lint" then
    vim.list_extend(args, { "--format=json" })
  end
  if fname ~= "" then
    vim.list_extend(args, { "--stdin-filename", fname })
  end
  if not sqlfluff_config_dir(fname) then
    vim.list_extend(args, { "--dialect", selected_sqlfluff_dialect() })
  end
  args[#args + 1] = "-"
  return args
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

    vim.api.nvim_create_user_command("SqlDialect", function(opts)
      if opts.args == "" then
        select_sqlfluff_dialect()
      else
        set_sqlfluff_dialect(opts.args)
      end
    end, {
      nargs = "?",
      complete = function()
        return sqlfluff_dialects
      end,
      desc = "Select persisted SQLFluff fallback dialect",
    })

    vim.keymap.set("n", "<leader>Ds", select_sqlfluff_dialect, { desc = "Select SQL dialect" })

    -- sqlfluff needs a dialect. Project sqlfluff config always wins; otherwise
    -- use the persisted fallback dialect selected by :SqlDialect.
    require("conform").formatters.sqlfluff = {
      command = "sqlfluff",
      stdin = true,
      exit_codes = { 0, 1 },
      cwd = function(_, ctx)
        return sqlfluff_config_dir(ctx.filename) or vim.fn.getcwd()
      end,
      args = function(_, ctx)
        return sqlfluff_args("fix", ctx.filename)
      end,
    }

    local default_sqlfluff = require("lint.linters.sqlfluff")
    require("lint").linters.sqlfluff = function()
      local linter = vim.deepcopy(default_sqlfluff)
      local fname = vim.api.nvim_buf_get_name(0)
      linter.args = sqlfluff_args("lint", fname)
      return linter
    end
  end,
}
