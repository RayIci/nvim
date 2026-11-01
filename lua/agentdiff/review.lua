---Attribution and review state.
---
---The invariant: a file's pending changes are diff(B, current), where B is the
---baseline. Every disk change has an author:
---  agent  O := disk               (B unchanged, so the change is now pending)
---  user   B := merge3(O, B, disk) (your delta lands in B too), then O := disk
---merge3 resolves overlaps to B, so a user edit touching a pending change only
---lands in the current content and becomes part of that change.
---
---Buffers with unsaved edits are shown against a display baseline built the
---same way in memory: merge3(O, B, buffer).
---@class AgentdiffReview
local M = {}

local merge = require("agentdiff.merge")
local session = require("agentdiff.session")
local util = require("agentdiff.util")

---@param s AgentdiffSession
---@param ... string?
---@return boolean
function M.is_whole(s, ...)
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if t ~= nil and (#t > s.opts.max_file_size or merge.is_binary(t)) then
      return true
    end
  end
  return false
end

---@param buf integer
---@return boolean
local function is_dos(buf)
  return vim.bo[buf].fileformat == "dos"
end

---Buffer content as display-space lines (a trailing "" when the buffer will
---be written with a final newline).
---@param buf integer
---@return string[]
function M.buf_lines(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local empty = #lines == 1
    and lines[1] == ""
    and vim.api.nvim_buf_call(buf, function()
        return vim.fn.line2byte(vim.fn.line("$") + 1)
      end)
      == -1
  if empty then
    return { "" }
  end
  if vim.bo[buf].eol or (vim.bo[buf].fixeol and not vim.bo[buf].binary) then
    lines[#lines + 1] = ""
  end
  return lines
end

---Disk text → display-space lines for a buffer.
---@param buf integer?
---@param text string?
---@return string[]
function M.disp(buf, text)
  local l = merge.lines(text)
  if buf and is_dos(buf) then
    return merge.strip_cr(l)
  end
  return l
end

---Display-space lines → disk text for a buffer.
---@param buf integer?
---@param lines string[]
---@return string
function M.undisp(buf, lines)
  if buf and is_dos(buf) then
    return merge.join(merge.add_cr(lines))
  end
  return merge.join(lines)
end

---@param v string|false|nil
---@return string?
local function opt(v)
  if v == false then
    return nil
  end
  return v
end

---Recompute the review state of one path; nil when nothing is pending.
---@param s AgentdiffSession
---@param path string
---@return AgentdiffFile?
function M.compute(s, path)
  local B = opt(s.store:read("baseline", { path })[path])
  local D = util.read_file(session.abs(s, path))
  local buf = session.buf_of_rel(s, path)
  local modified = buf ~= nil and vim.bo[buf].modified
  if D == nil and not modified then
    buf = nil -- deleted on disk: the buffer is a leftover, review the deletion
  end
  local conflicted = s.conflicts[path] == true

  if M.is_whole(s, B, D) then
    if B == D and not conflicted then
      return nil
    end
    ---@type AgentdiffFile
    return {
      path = path,
      status = conflicted and "conflicted"
        or (B == nil and "created")
        or (D == nil and "deleted")
        or "binary",
      whole = true,
      hunks = {},
      base = {},
      cur = {},
      added = 0,
      removed = 0,
      buf = buf,
    }
  end

  local cur, base
  if buf then
    cur = M.buf_lines(buf)
    local bl = M.disp(buf, B)
    local override = s.base_override[buf]
    if modified or override then
      local o = override or M.disp(buf, opt(s.store:read("observed", { path })[path]))
      base = (merge.merge3(o, bl, cur))
    else
      base = bl
    end
  else
    cur = merge.lines(D)
    base = merge.lines(B)
  end

  local hunks = merge.diff(base, cur)
  if #hunks == 0 and not conflicted then
    return nil
  end
  -- Count real lines: a trailing "" only stands for the final newline.
  local function real(lines, lo, hi)
    local n = hi - lo
    if hi == #lines and hi > lo and lines[hi] == "" then
      n = n - 1
    end
    return n
  end
  local added, removed = 0, 0
  for _, h in ipairs(hunks) do
    added = added + real(cur, h.b_lo, h.b_hi)
    removed = removed + real(base, h.a_lo, h.a_hi)
  end
  ---@type AgentdiffFile
  return {
    path = path,
    status = conflicted and "conflicted"
      or (B == nil and "created")
      or (D == nil and "deleted")
      or "modified",
    whole = false,
    hunks = hunks,
    base = base,
    cur = cur,
    added = added,
    removed = removed,
    buf = buf,
  }
end

---@param s AgentdiffSession
local function rebuild_order(s)
  local order = vim.tbl_keys(s.files)
  table.sort(order)
  s.order = order
end

---@param s AgentdiffSession
local function fire_if_changed(s)
  local parts = {}
  for _, p in ipairs(s.order) do
    local f = s.files[p]
    parts[#parts + 1] = ("%s:%s:%d:%d:%d"):format(p, f.status, #f.hunks, f.added, f.removed)
  end
  local sig = table.concat(parts, "|")
  if sig ~= s.signature then
    s.signature = sig
    vim.api.nvim_exec_autocmds("User", { pattern = "AgentdiffChanged", modeline = false })
  end
end

---Recompute review state: every pending path (paths = nil) or only some.
---@param s AgentdiffSession
---@param paths string[]?
function M.refresh(s, paths)
  if not s.ready then
    return
  end
  if paths == nil then
    local set = {}
    for _, c in ipairs(s.store:changes("baseline") or {}) do
      set[c.path] = true
    end
    for p in pairs(s.conflicts) do
      set[p] = true
    end
    for b in pairs(s.base_override) do
      local r = session.rel_of_buf(s, b)
      if r then
        set[r] = true
      end
    end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified then
        local r = session.rel_of_buf(s, b)
        if r then
          set[r] = true
        end
      end
    end
    s.files = {}
    for p in pairs(set) do
      s.files[p] = M.compute(s, p)
    end
  else
    for _, p in ipairs(paths) do
      s.files[p] = M.compute(s, p)
    end
  end
  rebuild_order(s)
  if paths == nil then
    s.refreshed = true
  end
  require("agentdiff.render").all(s)
  fire_if_changed(s)
end

---Apply the author rule to disk changes of `paths`.
---@param s AgentdiffSession
---@param paths string[]
---@param author "agent"|"user"
function M.process(s, paths, author)
  if #paths == 0 then
    return
  end
  s.store:locked(function()
    if author == "agent" then
      s.store:adopt("observed", paths)
      return
    end
    local O = s.store:read("observed", paths)
    local B = s.store:read("baseline", paths)
    local bwrites, owrites = {}, {}
    for _, p in ipairs(paths) do
      local D = util.read_file(session.abs(s, p))
      local o, b = opt(O[p]), opt(B[p])
      local nb
      if D == nil then
        nb = nil -- the user deleted it
      elseif o == nil then
        nb = D -- the user created (or re-created) it
      elseif M.is_whole(s, o, b, D) then
        nb = D
      else
        local buf = session.buf_of_rel(s, p)
        local base_lines = merge.lines(o)
        if buf and s.base_override[buf] then
          base_lines = merge.lines(M.undisp(buf, s.base_override[buf]))
        end
        local merged = merge.merge3(base_lines, merge.lines(b), merge.lines(D))
        if b == nil and #merged == 0 then
          nb = nil -- still an agent-created file pending review
        else
          nb = merge.join(merged)
        end
      end
      if nb ~= b then
        bwrites[#bwrites + 1] = { path = p, text = nb }
      end
      owrites[#owrites + 1] = { path = p, text = D }
    end
    s.store:write("baseline", bwrites)
    s.store:write("observed", owrites)
    s.store:refresh("observed")
  end)
  -- A claim covers one change: consume it, so a later agent edit of the same
  -- path is the agent's again.
  local claims = require("agentdiff.claims")
  for _, p in ipairs(paths) do
    claims.release(s.store, p)
  end
end

---Set B for one path (keep), from display-space lines of the given buffer.
---@param s AgentdiffSession
---@param path string
---@param text string?
function M.set_baseline(s, path, text)
  s.store:locked(function()
    s.store:write("baseline", { { path = path, text = text } })
    s.store:refresh("baseline")
  end)
end

return M
