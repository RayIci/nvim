---Side-by-side view: a read-only baseline window next to the file, in diff
---mode. The inline overlay is hidden for that buffer while the view is open;
---keep and undo work from either window.
---@class AgentdiffSideBySide
local M = {}

local render = require("agentdiff.render")
local review = require("agentdiff.review")
local session = require("agentdiff.session")
local util = require("agentdiff.util")

---@param lines string[]
---@return string[]
local function without_final_newline(lines)
  local out = vim.list_extend({}, lines)
  if #out > 1 and out[#out] == "" then
    out[#out] = nil
  end
  return out
end

---@param name string
---@param lines string[]
---@param ft string
---@param rel string
---@return integer
local function scratch(name, lines, ft, rel)
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "wipe"
  pcall(vim.api.nvim_buf_set_name, b, name)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, without_final_newline(lines))
  vim.bo[b].modifiable = false
  vim.bo[b].filetype = ft
  vim.b[b].agentdiff_baseline_of = rel
  return b
end

---Open or close the view for the current file.
function M.toggle()
  local s = session.get()
  if not s then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local of = vim.b[buf].agentdiff_baseline_of
  if of then
    buf = session.buf_of_rel(s, of) or buf
  end
  if s.views[buf] then
    return M.close(s, buf)
  end
  local rel = session.rel_of_buf(s, buf)
  local f = rel and review.compute(s, rel)
  if not rel or not f or f.whole then
    return util.notify("agentdiff: no inline changes to show side by side")
  end
  local file_win = vim.api.nvim_get_current_win()
  local b = scratch("agentdiff://baseline/" .. rel, f.base, vim.bo[buf].filetype, rel)
  vim.cmd("leftabove vsplit")
  vim.api.nvim_win_set_buf(0, b)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(file_win)
  vim.cmd("diffthis")
  s.views[buf] = b
  vim.api.nvim_create_autocmd("User", {
    pattern = "AgentdiffChanged",
    callback = function()
      if s.views[buf] ~= b or not vim.api.nvim_buf_is_valid(b) then
        return true
      end
      local nf = review.compute(s, rel)
      vim.bo[b].modifiable = true
      vim.api.nvim_buf_set_lines(
        b,
        0,
        -1,
        false,
        without_final_newline(nf and nf.base or review.buf_lines(buf))
      )
      vim.bo[b].modifiable = false
      pcall(vim.cmd.diffupdate)
    end,
  })
  render.all(s)
end

---@param s AgentdiffSession
---@param buf integer
function M.close(s, buf)
  local b = s.views[buf]
  s.views[buf] = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local wb = vim.api.nvim_win_get_buf(w)
    if wb == b then
      pcall(vim.api.nvim_win_close, w, true)
    elseif wb == buf then
      vim.api.nvim_win_call(w, function()
        vim.cmd("diffoff")
      end)
    end
  end
  render.all(s)
end

---Show the file on disk next to a buffer with unsaved edits (conflicts).
---@param s AgentdiffSession
---@param rel string
function M.compare_disk(s, rel)
  local buf = session.buf_of_rel(s, rel)
  if not buf then
    return
  end
  local disk = review.disp(buf, util.read_file(session.abs(s, rel)))
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd.buffer(buf)
  end
  local b = scratch("agentdiff://disk/" .. rel, disk, vim.bo[buf].filetype, rel)
  vim.cmd("rightbelow vsplit")
  vim.api.nvim_win_set_buf(0, b)
  vim.cmd("diffthis")
  vim.cmd.wincmd("p")
  vim.cmd("diffthis")
end

return M
