-- Child init for worktrees.lua: exercise real startup without loading/installing unrelated plugins.
vim.opt.rtp:prepend(assert(vim.env.NVIM_WORKTREE_TEST_CONFIG))
vim.o.packpath = assert(vim.env.NVIM_WORKTREE_TEST_PACKPATH)
for _, name in ipairs({
  "plenary.nvim",
  "scope.nvim",
  "auto-session",
  "bufferline.nvim",
  "nvim-dap",
  "neo-tree.nvim",
  "nui.nvim",
  "nvim-web-devicons",
  "nvim-window-picker",
  "telescope.nvim",
  "telescope-ui-select.nvim",
  "telescope-fzf-native.nvim",
}) do
  local path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing startup dependency: " .. name)
  vim.opt.rtp:append(path)
end
require("config.options")
vim.o.swapfile = false
vim.o.undofile = false
vim.o.shadafile = "NONE"
require("plugins.scope").setup()
require("plugins.bufferline").setup()
require("plugins.neotree").setup()
require("plugins.telescope").setup()
require("plugins.auto-session").setup()
require("dap")
require("config.workspace").setup()
if vim.env.NVIM_WORKTREE_TEST_DISABLED ~= "1" then
  require("plugins.worktrees").setup()
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local buffers_before_open = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
          buffers_before_open[#buffers_before_open + 1] = vim.api.nvim_buf_get_name(buf)
        end
      end
      if vim.env.NVIM_WORKTREE_TEST_OPEN_FILE and vim.env.NVIM_WORKTREE_TEST_OPEN_FILE ~= "" then
        vim.cmd.edit(vim.fn.fnameescape(vim.env.NVIM_WORKTREE_TEST_OPEN_FILE))
      end
      local tabs = {}
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local files = {}
        for _, buf in ipairs(require("scope.core").cache[tab] or {}) do
          if vim.api.nvim_buf_is_valid(buf) then
            files[#files + 1] = vim.api.nvim_buf_get_name(buf)
          end
        end
        tabs[#tabs + 1] = files
      end
      local breakpoints = {}
      for buf, points in pairs(require("dap.breakpoints").get()) do
        breakpoints[vim.api.nvim_buf_get_name(buf)] = points
      end
      local buffers = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
          buffers[#buffers + 1] = vim.api.nvim_buf_get_name(buf)
        end
      end
      local result = {
        cwd = vim.fn.getcwd(),
        file = vim.api.nvim_buf_get_name(0),
        tabs = tabs,
        buffers = buffers,
        buffers_before_open = buffers_before_open,
        pinned = vim.g.BufferlinePinnedBuffers or "",
        breakpoints = breakpoints,
        session = vim.v.this_session,
        managed_mapping = vim.fn.maparg("<leader>gww", "n") ~= "",
      }
      vim.fn.writefile({ vim.json.encode(result) }, assert(vim.env.NVIM_WORKTREE_TEST_RESULT))
      require("config.workspace").pause()
      require("plugins.auto-session").pause()
      require("auto-session.config").auto_save = false
      vim.cmd("qa!")
    end, 800)
  end,
})
