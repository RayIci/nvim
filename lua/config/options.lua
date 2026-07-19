---Core editor options. Loaded before everything else.

-- Leader must be set before any plugin creates <leader> mappings.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local o = vim.o

-- UI
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.showmode = false -- lualine shows the mode
o.laststatus = 3 -- single global statusline
o.pumheight = 12
o.winborder = "rounded"
o.scrolloff = 6
o.sidescrolloff = 8
o.splitbelow = true
o.splitright = true
o.mouse = "a"
o.confirm = true

-- Editing
o.expandtab = true -- guess-indent overrides per buffer
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = false -- treesitter indentexpr handles structure
o.wrap = false
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.completeopt = "menu,menuone,noselect"

-- Search
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

-- Sessions (auto-session): old-config set. 'globals' is required — bufferline
-- persists pins in vim.g.BufferlinePinnedBuffers and re-pins on SessionLoadPost.
o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions,globals"

-- System clipboard
vim.schedule(function()
  o.clipboard = "unnamedplus"
end)
