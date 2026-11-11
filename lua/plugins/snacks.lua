---snacks.nvim: pickers (and vim.ui.select), vim.ui.input, notifications, LSP
---reference highlighting and indent guides. Owns the <leader>f find keys,
---]] / [[ reference jumps and the notification keys.
---@class PluginSnacks
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "folke/snacks.nvim",
}

-- Ignore lists ported from the old dotfiles config (as globs).
local find_exclude = { "node_modules", "dist", "build", ".git", "vendor" }
local grep_exclude = vim.list_extend(vim.deepcopy(find_exclude), {
  "*.lock",
  "*.jpg",
  "*.jpeg",
  "*.png",
  "*.svg",
  "*.otf",
  "*.ttf",
  "*.webp",
  "*.gif",
  "*.zip",
  "*.tar.gz",
  "*.tar.bz2",
  "*.exe",
  "*.dll",
  "*.class",
  "*.jar",
})

-- Panels that never get indent guides (the old indent-blankline exclude list).
local no_indent = {
  help = true,
  dashboard = true,
  Trouble = true,
  trouble = true,
  lazy = true,
  mason = true,
  snacks_picker_list = true,
}

---@type table
M.options = {
  notifier = {
    enabled = true,
    top_down = false,
    style = "compact",
    timeout = 1000,
    width = { min = 40, max = 0.4 },
    height = { min = 1, max = 0.6 },
    padding = false,
  },
  input = { enabled = true },
  -- Directory buffers (`nvim .`, `:e dir`) open in the sidebar explorer.
  explorer = { enabled = true, replace_netrw = true },
  picker = {
    enabled = true,
    ui_select = true, -- vim.ui.select (DAP configs, code actions with [server], sessions)
    sources = {
      -- The sidebar explorer's options live with it (plugins/explorer.lua).
      explorer = require("plugins.explorer").snacks_source(),
      files = { hidden = true, exclude = find_exclude },
      grep = { hidden = true, exclude = grep_exclude },
      grep_word = { hidden = true, exclude = grep_exclude },
    },
  },
  -- Other uses of the symbol under the cursor, from the server's document
  -- highlights. Normal mode only: no request per keystroke while typing.
  words = { enabled = true, debounce = 120, modes = { "n" } },
  indent = {
    enabled = true,
    indent = { char = "│" },
    scope = { enabled = true, char = "│" },
    animate = { enabled = false },
    filter = function(buf)
      return vim.bo[buf].buftype == "" and not no_indent[vim.bo[buf].filetype] and vim.b[buf].snacks_indent ~= false
    end,
  },
}

function M.setup()
  require("snacks").setup(M.options)

  local map = vim.keymap.set
  local function pick(source, opts)
    return function()
      Snacks.picker[source](opts)
    end
  end

  map("n", "<leader><leader>", pick("files"), { desc = "Find files" })
  map("n", "<leader>ff", pick("resume"), { desc = "Resume last picker" })
  map("n", "<leader>fg", pick("grep"), { desc = "Live grep" })
  map("n", "<leader>fb", pick("buffers"), { desc = "Buffers" })
  map("n", "<leader>fh", pick("help"), { desc = "Help tags" })
  map("n", "<leader>fr", pick("recent"), { desc = "Recent files" })
  map({ "n", "x" }, "<leader>fw", pick("grep_word"), { desc = "Grep word under cursor" })
  map("n", "<leader>fd", pick("diagnostics"), { desc = "Diagnostics" })
  map("n", "<leader>fk", pick("keymaps"), { desc = "Keymaps" })
  map("n", "<leader>fs", pick("lsp_workspace_symbols"), { desc = "Workspace symbols" })
  map("n", "<leader>fn", pick("notifications"), { desc = "Notification history" })

  map("n", "<leader>un", function()
    Snacks.notifier.hide()
  end, { desc = "Dismiss notifications" })

  map("n", "]]", function()
    Snacks.words.jump(vim.v.count1, true)
  end, { desc = "Next reference" })
  map("n", "[[", function()
    Snacks.words.jump(-vim.v.count1, true)
  end, { desc = "Previous reference" })
end

return M
