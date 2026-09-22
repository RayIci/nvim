---Reading from and writing to a gitcommit buffer.
---@class CommitsmithBuffer
local M = {}

---Strip the wrappers agents add despite being told not to, and normalize the
---blank line after the title (copilot in particular runs the title straight into
---the body).
---@param response string
---@return string
function M.clean(response)
  local text = vim.trim(response or "")
  text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")
  text = vim.trim(text)
  if text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    text = text:sub(2, -2)
  end
  text = vim.trim(text)

  local lines = vim.split(text, "\n", { plain = true })
  if #lines > 1 and vim.trim(lines[2]) ~= "" then
    table.insert(lines, 2, "")
  end
  return table.concat(lines, "\n")
end

---@param buf integer
---@return boolean
function M.is_commit(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "gitcommit"
end

---@param buf integer
---@return integer? index of the first comment line, 1-based
local function comment_start(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^#") then
      return i
    end
  end
end

---The message the buffer already holds: everything above the comment block. Used
---as the draft to revise on an amend, or after an aborted commit.
---@param buf integer
---@return string
function M.message(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end
  local stop = comment_start(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, stop and (stop - 1) or -1, false)
  return vim.trim(table.concat(lines, "\n"))
end

---Replace the message, leaving git's comment block untouched.
---@param buf integer
---@param text string
---@return boolean applied
function M.apply(buf, text)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local lines = vim.split(text, "\n", { plain = true })
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  if #lines == 0 then
    return false
  end

  local stop = comment_start(buf)
  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local replace_end = stop and (stop - 1) or #current
  if stop and lines[#lines] ~= "" then
    lines[#lines + 1] = ""
  end

  vim.api.nvim_buf_set_lines(buf, 0, replace_end, false, lines)
  if vim.api.nvim_get_current_buf() == buf then
    pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
  end
  return true
end

---@param diff string
---@return string one-line summary for the collapsed diff entry
function M.diff_summary(diff)
  local files, added, removed = 0, 0, 0
  for line in vim.gsplit(diff, "\n", { plain = true }) do
    if line:match("^diff %-%-git ") then
      files = files + 1
    elseif line:match("^%+") and not line:match("^%+%+%+") then
      added = added + 1
    elseif line:match("^%-") and not line:match("^%-%-%-") then
      removed = removed + 1
    end
  end
  return ("staged diff: %d file%s, +%d/-%d"):format(files, files == 1 and "" or "s", added, removed)
end

return M
