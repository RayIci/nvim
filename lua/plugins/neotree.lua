---neo-tree.nvim: file explorer sidebar, opening files through nvim-window-picker.
---@class PluginNeotree
local M = {}

-- IDE-style yellow for folder icons (survives theme switches, see below).
local FOLDER_ICON_COLOR = "#E5C07B"

---Re-applied on every ColorScheme event: neo-tree recomputes
---NeoTreeDirectoryIcon itself (linking it to "Directory") each time the
---colorscheme changes, so we have to reassert this after every switch,
---not just once at startup.
local function set_folder_icon_hl()
  vim.api.nvim_set_hl(0, "NeoTreeDirectoryIcon", { fg = FOLDER_ICON_COLOR })
end

---Yank the node's path in a chosen form (old-config "advanced yank" on Y).
---@param state table neo-tree state
local function copy_node_path(state)
  local node = state.tree:get_node()
  local filepath = node:get_id()
  local filename = node.name
  local modify = vim.fn.fnamemodify

  local results = {
    filename,
    modify(filename, ":r"),
    filepath,
    modify(filepath, ":."),
    modify(filepath, ":~"),
    modify(filename, ":e"),
  }

  vim.ui.select({
    "1. Filename: " .. results[1],
    "2. Filename without extension: " .. results[2],
    "3. Absolute path: " .. results[3],
    "4. Path relative to CWD: " .. results[4],
    "5. Path relative to HOME: " .. results[5],
    "6. Extension of the filename: " .. results[6],
  }, { prompt = "Choose to copy to clipboard:" }, function(choice)
    if choice then
      local result = results[tonumber(choice:sub(1, 1))]
      vim.fn.setreg("+", result)
      vim.fn.setreg("*", result)
      vim.fn.setreg('"', result)
      vim.notify("Copied: " .. result)
    end
  end)
end

---Create a new C# item (class/interface/enum/record) via easy-dotnet.nvim's
---Roslyn-backed generator, scoped to the directory under the cursor.
---@param state table neo-tree state
local function create_dotnet_item(state)
  local node = state.tree:get_node()
  local path = node.type == "directory" and node.path or vim.fs.dirname(node.path)
  require("easy-dotnet").create_item(path)
end

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
      -- Hide lists ported from the old dotfiles config
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = {
          ".git", ".mypy_cache", ".pytest_cache", ".ruff_cache", ".github",
          "bin", "obj", "bin\\Debug", "bin\\Release", "node_modules", ".next",
        },
        hide_by_pattern = { ".*venv*", "*.egg-info" },
        never_show = { "__pycache__" },
      },
      use_libuv_file_watcher = true,
      commands = {
        create_dotnet_item = create_dotnet_item,
      },
      window = {
        mappings = {
          ["n"] = "create_dotnet_item",
        },
      },
    },
    window = {
      width = 45,
      mappings = {
        ["w"] = open_with_smart_picker,
        ["<cr>"] = open_with_smart_picker,
        ["Y"] = copy_node_path,
      },
    },
  })

  vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "File explorer" })
  vim.keymap.set("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Reveal file in explorer" })

  set_folder_icon_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("plugins.neotree.folder_icon", { clear = true }),
    callback = set_folder_icon_hl,
  })
end

return M
