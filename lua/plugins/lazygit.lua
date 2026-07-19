---Lazygit in a floating terminal. Plugin-free: a float + termopen, closed
---automatically when lazygit exits.
---@class PluginLazygit
local M = {}

local function open_lazygit()
  if vim.fn.executable("lazygit") == 0 then
    vim.notify("lazygit is not installed", vim.log.levels.ERROR)
    return
  end

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local buf = vim.api.nvim_create_buf(false, true)
  -- Interactive TUI: keep j/k instant — the terminal jk/C-hjkl maps must not
  -- attach here (a pending jk map lags every j press and can kick lazygit
  -- into normal mode). Set before jobstart so TermOpen handlers see it.
  vim.b[buf].term_no_escape_maps = true
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.fn.jobstart({ "lazygit" }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
  vim.cmd.startinsert()
end

function M.setup()
  vim.keymap.set("n", "<leader>gg", open_lazygit, { desc = "Lazygit" })
end

return M
