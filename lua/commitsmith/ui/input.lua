---The refinement input: a prompt buffer below the transcript. Free-form text
---goes to the harness as the next turn; the canned refinements in the transcript
---window are the same path with the text already written.
---@class CommitsmithInput
local M = {}

local runner = require("commitsmith.runner")

---@param view CommitsmithView
---@param on_closed fun()
---@return integer? buf, integer? win
function M.open(view, on_closed)
  vim.api.nvim_set_current_win(view.win)
  vim.cmd("belowright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(win, 3)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.fn.prompt_setprompt(buf, "refine ❯ ")

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    on_closed()
  end

  vim.fn.prompt_setcallback(buf, function(text)
    close()
    if vim.trim(text or "") ~= "" then
      runner.refine(view.commit, text)
    end
  end)
  vim.keymap.set({ "n", "i" }, "<Esc>", close, { buffer = buf, desc = "Cancel refinement" })

  vim.cmd.startinsert()
  return buf, win
end

return M
