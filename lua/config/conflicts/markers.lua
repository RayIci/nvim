---Conflict marker parsing and resolution text, in role terms.
---
---A conflict is git's block:
---  <<<<<<< label     (the "ours" section starts)
---  ||||||| label     (optional, diff3/zdiff3: the common ancestor)
---  =======
---  >>>>>>> label     (the "theirs" section ended)
---Markers are exactly seven characters at column 0, followed by a space or the
---end of the line (CRLF tolerated), as git writes them.
---@class ConflictsMarkers
local M = {}

---@class Conflict
---@field start integer 0-based line of <<<<<<<
---@field finish integer 0-based line of >>>>>>>
---@field base_marker integer? 0-based line of |||||||
---@field sep integer 0-based line of =======
---@field ours string[]
---@field base string[]?
---@field theirs string[]
---@field ours_label string
---@field theirs_label string

---@param line string
---@param char string one marker character
---@return boolean matched
---@return string label
local function marker(line, char)
  line = line:gsub("\r$", "")
  local prefix = char:rep(7)
  if line:sub(1, 7) ~= prefix then
    return false, ""
  end
  local rest = line:sub(8)
  if rest == "" then
    return true, ""
  end
  if rest:sub(1, 1) ~= " " then
    return false, ""
  end
  return true, rest:sub(2)
end

---Every conflict in `lines`, in order.
---@param lines string[]
---@return Conflict[]
function M.parse(lines)
  local out = {}
  local i = 1
  while i <= #lines do
    local ok, ours_label = marker(lines[i], "<")
    if ok then
      local c = { start = i - 1, ours = {}, theirs = {}, ours_label = ours_label }
      local section = "ours"
      local j = i + 1
      local closed = false
      while j <= #lines do
        local line = lines[j]
        local is_base = marker(line, "|")
        local is_sep = line:gsub("\r$", "") == "======="
        local is_end, theirs_label = marker(line, ">")
        if marker(line, "<") then
          break -- a new conflict before this one closed: not a conflict
        elseif is_base and section == "ours" then
          c.base_marker, c.base, section = j - 1, {}, "base"
        elseif is_sep and section ~= "theirs" then
          c.sep, section = j - 1, "theirs"
        elseif is_end and section == "theirs" then
          c.finish, c.theirs_label, closed = j - 1, theirs_label, true
          break
        else
          table.insert(c[section], (line:gsub("\r$", "")))
        end
        j = j + 1
      end
      if closed then
        out[#out + 1] = c
        i = j + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  return out
end

---Lines of `role`'s side of conflict `c`.
---@param c Conflict
---@param role ConflictRole
---@param op? ConflictOp
---@return string[]
function M.side(c, role, op)
  local section = require("config.conflicts.state").section(role, op)
  return c[section]
end

---Replacement text for a whole-side choice.
---@param c Conflict
---@param choice "yours"|"incoming"|"both"|"both_incoming_first"|"none"
---@param op? ConflictOp
---@return string[]
function M.choose(c, choice, op)
  local yours, incoming = M.side(c, "yours", op), M.side(c, "incoming", op)
  if choice == "yours" then
    return vim.deepcopy(yours)
  elseif choice == "incoming" then
    return vim.deepcopy(incoming)
  elseif choice == "both" then
    return vim.list_extend(vim.deepcopy(yours), incoming)
  elseif choice == "both_incoming_first" then
    return vim.list_extend(vim.deepcopy(incoming), yours)
  end
  return {}
end

---Replace conflict `c` in `buf` with `lines` (one undo step).
---@param buf integer
---@param c Conflict
---@param lines string[]
function M.apply(buf, c, lines)
  -- Each resolution is its own undo step (otherwise quick successive applies
  -- join into one and a single u undoes them all).
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("let &undolevels = &undolevels")
  end)
  vim.api.nvim_buf_set_lines(buf, c.start, c.finish + 1, false, lines)
end

---Conflicts in a buffer.
---@param buf integer
---@return Conflict[]
function M.in_buffer(buf)
  return M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
end

---Number of conflicts in a file on disk (for files not loaded).
---@param path string
---@return integer
function M.count_file(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return #M.in_buffer(buf)
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and #M.parse(lines) or 0
end

---The conflict containing 0-based line `row`, and its index.
---@param conflicts Conflict[]
---@param row integer
---@return Conflict?
---@return integer?
function M.at(conflicts, row)
  for i, c in ipairs(conflicts) do
    if row >= c.start and row <= c.finish then
      return c, i
    end
  end
  return nil, nil
end

return M
