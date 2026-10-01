---Buffer helpers shared by keymaps and bufferline.
---@class ConfigBuffers
local M = {}

---Delete a buffer without disturbing the window layout: every window showing
---it switches to another listed buffer (or a fresh empty one) first. Unlike
---:bdelete, no window closes — with neo-tree's close_if_last_window, closing
---the last editor window would take the tree and then Neovim down with it.
---@param buf? integer defaults to the current buffer
function M.close(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if vim.bo[buf].modified then
    vim.notify("Buffer has unsaved changes", vim.log.levels.WARN)
    return
  end
  local fallback ---@type integer?
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= buf and vim.bo[b].buflisted then
      fallback = b
      break
    end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      if fallback then
        vim.api.nvim_win_set_buf(win, fallback)
      else
        vim.api.nvim_win_call(win, function()
          vim.cmd.enew()
        end)
      end
    end
  end
  pcall(vim.api.nvim_buf_delete, buf, {})
end

return M
