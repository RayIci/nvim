---neo-tree.nvim: file explorer sidebar, opening files through nvim-window-picker.
---@class PluginNeotree
local M = {}

---Open the node under the cursor: directories toggle; files open directly when
---at most one eligible window exists, otherwise through the window picker.
---@param state table neo-tree state
local function open_with_smart_picker(state)
  local node = state.tree:get_node()
  if node.type == "directory" then
    state.commands["toggle_node"](state)
    return
  end

  local eligible = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "neo-tree" and vim.bo[buf].buftype ~= "nofile" and vim.bo[buf].buftype ~= "terminal" then
      eligible = eligible + 1
    end
  end

  if eligible <= 1 then
    state.commands["open"](state)
  else
    state.commands["open_with_window_picker"](state)
  end
end

function M.setup()
  require("window-picker").setup({
    filter_rules = {
      include_current_win = false,
      autoselect_one = true,
      bo = {
        filetype = { "neo-tree", "neo-tree-popup", "notify" },
        buftype = { "terminal", "quickfix" },
      },
    },
  })

  require("neo-tree").setup({
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      filtered_items = {
        hide_dotfiles = false,
        hide_by_name = { ".git" },
      },
      use_libuv_file_watcher = true,
    },
    window = {
      width = 45,
      mappings = {
        ["w"] = open_with_smart_picker,
        ["<cr>"] = open_with_smart_picker,
      },
    },
  })

  vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "File explorer" })
  vim.keymap.set("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Reveal file in explorer" })
end

return M
