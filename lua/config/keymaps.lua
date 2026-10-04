---Global keymaps that don't belong to any plugin.
---Plugin-specific maps live next to their plugin's setup in lua/plugins/.

local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Window navigation: <C-h/j/k/l> come from vim-tmux-navigator, which also
-- crosses into tmux panes and falls back to plain window movement outside tmux.
-- Its default mappings are disabled and the normal-mode ones defined here:
-- inside tmux it also adds terminal-mode maps using Vim's `<C-w>:` escape,
-- which Neovim terminals don't have, so `<C-w>: TmuxNavigateRight<CR>` gets
-- typed into the running program (in lazygit, `T` + the rest created
-- `muxNavigate*` tags). Terminal maps come from toggleterm instead. Runs
-- during init.lua, before the plugin's script is sourced and reads the flag.
vim.g.tmux_navigator_no_mappings = 1
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Window/pane left" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Window/pane down" })
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Window/pane up" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Window/pane right" })
map("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", { desc = "Previous window/pane" })

-- Save
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
map("i", "<C-s>", "<Esc><cmd>w<cr>", { desc = "Save file and leave insert mode" })

-- Clear search highlight (alongside <Esc> below)
map("n", "<C-x>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- <C-c> skips InsertLeave, leaving Copilot ghost text on screen and stalling
-- the deferred diagnostics refresh; route it through <Esc> so hooks fire.
map("i", "<C-c>", "<Esc>", { desc = "Exit insert mode (as Esc)" })

-- Shift+Enter must behave as a plain newline. Depending on the terminal's
-- keyboard protocol it arrives as <S-CR> (CSI-u) or as ESC+CR, which nvim
-- decodes as <M-CR> — unmapped, that acts as Esc + Enter (exits insert and
-- moves down a line, the reported bug under Windows Terminal/WSL).
map("i", "<S-CR>", "<CR>", { desc = "New line (stay in insert)" })
map("i", "<M-CR>", "<CR>", { desc = "New line (stay in insert)" })

-- Resize windows with arrows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Grow window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Shrink window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Shrink window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Grow window width" })

-- Move selected lines
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Move the current line (normal mode), mirroring the visual-mode maps above.
-- NOTE: this shadows the default J (join lines) and K (keyword lookup); LSP
-- hover already lives on H (see plugins/lsp.lua), and join stays on gJ.
map("n", "J", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "K", "<cmd>m .-2<cr>==", { desc = "Move line up" })

-- Keep cursor centered on half-page jumps and search hits
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Indent and stay in visual mode
map("v", "<", "<gv", { desc = "Dedent selection" })
map("v", ">", ">gv", { desc = "Indent selection" })

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })

local function close_buffer()
  require("config.buffers").close()
end

map("n", "<leader>xw", close_buffer, { desc = "Close buffer (keep window)" })
map("n", "<leader>bd", close_buffer, { desc = "Close buffer (keep window)" })

-- Tabs (<leader>j group; built-in gt/gT stay unmapped so {count}gt keeps working)
map("n", "<leader>j<Tab>", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<leader>j<S-Tab>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map("n", "<leader>jf", "<cmd>tabfirst<cr>", { desc = "First tab" })
map("n", "<leader>jl", "<cmd>tablast<cr>", { desc = "Last tab" })
map("n", "<leader>jc", "<cmd>tabnew<cr>", { desc = "Create new tab" })
map("n", "<leader>js", function()
  -- With scope.nvim, tabnew starts an empty scope; carrying the buffer over
  -- explicitly replaces the old `tabnew | BufferLineCyclePrev` trick.
  local buf = vim.api.nvim_get_current_buf()
  vim.cmd.tabnew()
  vim.api.nvim_set_current_buf(buf)
end, { desc = "Open current buffer in new tab" })
map("n", "<leader>jx", "<cmd>tabclose<cr>", { desc = "Close current tab" })
map("n", "<leader>xj", "<cmd>tabclose<cr>", { desc = "Close current tab" })
map("n", "<leader>jX", "<cmd>tabonly<cr>", { desc = "Close all other tabs" })
map("n", "<leader>jm", "<cmd>tabmove +1<cr>", { desc = "Move tab right" })
map("n", "<leader>jM", "<cmd>tabmove -1<cr>", { desc = "Move tab left" })
map("n", "<leader>j0", "<cmd>tabmove 0<cr>", { desc = "Move tab to first position" })
map("n", "<leader>j$", "<cmd>tabmove $<cr>", { desc = "Move tab to last position" })
for i = 1, 9 do
  map("n", "<leader>j" .. i, i .. "gt", { desc = "Go to tab " .. i })
end

-- Built-in undo tree (Neovim 0.12, ships as an optional builtin package)
vim.cmd.packadd("nvim.undotree")
map("n", "<leader>uu", "<cmd>Undotree<cr>", { desc = "Undo tree" })

-- Plugin updates via vim.pack
map("n", "<leader>pu", function()
  vim.pack.update()
end, { desc = "Update plugins (vim.pack)" })
