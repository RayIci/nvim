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

---@type LangPack
return {
  formatters = { sql = { "sql_formatter" } },
  mason = { "sql-formatter" },
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
  end,
}
