---Global autocommands.

local function augroup(name)
  return vim.api.nvim_create_augroup("config." .. name, { clear = true })
end

-- Flash the yanked region
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.hl.range(0, vim.api.nvim_create_namespace("yank_flash"), "IncSearch", "'[", "']", { timeout = 150 })
  end,
})

-- Return to last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_position"),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close transient windows with q
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "help", "qf", "checkhealth", "man", "grug-far-help" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, desc = "Close window" })
  end,
})

-- Wrap and spell in prose filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("prose"),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Handle stale swap files automatically. Only prompt when the dead
-- session had unsaved changes worth recovering.
vim.api.nvim_create_autocmd("SwapExists", {
  group = augroup("smart_swap"),
  callback = function()
    local info = vim.fn.swapinfo(vim.v.swapname)
    local alive = info.pid and vim.fn.getpid() ~= info.pid and vim.uv.kill(info.pid, 0) == 0
    if alive then
      vim.v.swapchoice = "o" -- file open in another instance: read-only
      vim.schedule(function()
        vim.notify("File open in another nvim (pid " .. info.pid .. "), opened read-only", vim.log.levels.WARN)
      end)
    elseif info.dirty == 0 then
      vim.v.swapchoice = "d" -- dead session, nothing unsaved: delete swap
    end
  end,
})
