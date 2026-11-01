---Inline overlay: removed lines as virtual lines, added lines highlighted, and
---a hint on the pending change nearest the cursor. The buffer text is never
---changed.
---@class AgentdiffRender
local M = {}

local session = require("agentdiff.session")

M.ns = vim.api.nvim_create_namespace("agentdiff")
M.ns_hint = vim.api.nvim_create_namespace("agentdiff_hint")

function M.define_highlights()
  local set = vim.api.nvim_set_hl
  set(0, "AgentdiffAdd", { link = "DiffAdd", default = true })
  set(0, "AgentdiffDelete", { link = "DiffDelete", default = true })
  set(0, "AgentdiffHint", { link = "Comment", default = true })
  set(0, "AgentdiffConflict", { link = "DiagnosticWarn", default = true })
  set(0, "AgentdiffTreeFile", { link = "DiagnosticWarn", default = true })
  set(0, "AgentdiffTreeDir", { link = "DiagnosticWarn", default = true })
end

---@param text string
---@param ts integer
---@return string
local function expand_tabs(text, ts)
  if not text:find("\t", 1, true) then
    return text
  end
  local out, col = {}, 0
  for ch in text:gmatch(".") do
    if ch == "\t" then
      local n = ts - (col % ts)
      out[#out + 1] = (" "):rep(n)
      col = col + n
    else
      out[#out + 1] = ch
      col = col + 1
    end
  end
  return table.concat(out)
end

---Lines of a hunk's old side worth drawing (the trailing "" that only stands
---for a final newline is not a line).
---@param f AgentdiffFile
---@param h AgentdiffHunk
---@return string[]
local function removed_lines(f, h)
  local out = {}
  for i = h.a_lo + 1, h.a_hi do
    if not (i == #f.base and f.base[i] == "") then
      out[#out + 1] = f.base[i]
    end
  end
  return out
end

---Row a hunk is anchored at in a buffer of `count` lines (0-based).
---@param h AgentdiffHunk
---@param count integer
---@return integer
function M.anchor_row(h, count)
  return math.max(0, math.min(h.b_lo, count - 1))
end

---Draw one buffer's overlay.
---@param s AgentdiffSession
---@param buf integer
function M.buffer(s, buf)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  local rel = session.rel_of_buf(s, buf)
  local f = rel and s.files[rel]
  if not f or s.overlay_hidden or s.views[buf] then
    return
  end
  local count = vim.api.nvim_buf_line_count(buf)
  if f.status == "deleted" and f.buf == nil then
    -- A leftover buffer of a file the agent deleted: show it all as removed.
    for row = 0, count - 1 do
      vim.api.nvim_buf_set_extmark(buf, M.ns, row, 0, { line_hl_group = "AgentdiffDelete", priority = 120 })
    end
    return
  end
  if f.whole or f.buf ~= buf then
    return
  end
  local ts = vim.bo[buf].tabstop
  local width = math.max(vim.o.columns, 80)
  local conflicted = f.status == "conflicted"
  for _, h in ipairs(f.hunks) do
    for row = h.b_lo, math.min(h.b_hi, count) - 1 do
      vim.api.nvim_buf_set_extmark(buf, M.ns, row, 0, {
        line_hl_group = conflicted and "AgentdiffConflict" or "AgentdiffAdd",
        priority = 120,
      })
    end
    local old = removed_lines(f, h)
    if #old > 0 then
      local virt = {}
      for _, l in ipairs(old) do
        local text = expand_tabs(l, ts)
        local pad = width - vim.fn.strdisplaywidth(text)
        virt[#virt + 1] = { { text .. (" "):rep(math.max(pad, 0)), "AgentdiffDelete" } }
      end
      local above = h.b_lo < count
      vim.api.nvim_buf_set_extmark(buf, M.ns, above and h.b_lo or (count - 1), 0, {
        virt_lines = virt,
        virt_lines_above = above,
        priority = 120,
      })
    end
  end
end

---Session-wide list of changes in navigation order.
---@param s AgentdiffSession
---@return { path: string, index: integer, row: integer }[]
function M.flatten(s)
  local out = {}
  for _, p in ipairs(s.order) do
    local f = s.files[p]
    if f.whole or #f.hunks == 0 then
      out[#out + 1] = { path = p, index = 0, row = 0 }
    else
      for i, h in ipairs(f.hunks) do
        out[#out + 1] = { path = p, index = i, row = h.b_lo }
      end
    end
  end
  return out
end

---Total number of pending changes.
---@param s AgentdiffSession
---@return integer
function M.count(s)
  local n = 0
  for _, p in ipairs(s.order) do
    local f = s.files[p]
    n = n + ((f.whole or #f.hunks == 0) and 1 or #f.hunks)
  end
  return n
end

---Index of the hunk under (or nearest to) a 0-based row.
---@param f AgentdiffFile
---@param row integer
---@param exact boolean  only a hunk under the row
---@return integer?
function M.hunk_at(f, row, exact)
  local best, best_d
  local count = #f.cur
  if count > 0 and f.cur[count] == "" then
    count = count - 1 -- the final-newline element is not a buffer line
  end
  for i, h in ipairs(f.hunks) do
    local lo = M.anchor_row(h, count)
    local hi = math.max(lo + 1, math.min(h.b_hi, count))
    if row >= lo and row < hi then
      return i
    end
    if not exact then
      local d = row < lo and (lo - row) or (row - hi + 1)
      if not best_d or d < best_d then
        best, best_d = i, d
      end
    end
  end
  return best
end

---@param keys AgentdiffKeymaps|false
---@return string
local function key_hint(keys)
  if type(keys) ~= "table" then
    return ""
  end
  local parts = {}
  if keys.keep then
    parts[#parts + 1] = keys.keep .. " keep"
  end
  if keys.undo then
    parts[#parts + 1] = keys.undo .. " undo"
  end
  if #parts == 0 then
    return ""
  end
  return " · " .. table.concat(parts, " · ")
end

---Hint text for the change at a session-wide position.
---@param s AgentdiffSession
---@param pos integer
---@param conflicted boolean
---@return string
function M.hint_text(s, pos, conflicted)
  local label = conflicted and "conflict" or "agent"
  return ("%s %d/%d%s"):format(label, pos, M.count(s), key_hint(s.opts.keymaps))
end

---Place the hint on the change nearest the cursor of `win`.
---@param s AgentdiffSession
---@param win integer?
function M.hint(s, win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      vim.api.nvim_buf_clear_namespace(b, M.ns_hint, 0, -1)
    end
  end
  if not s.opts.hint or s.overlay_hidden or s.views[buf] then
    return
  end
  local rel = session.rel_of_buf(s, buf)
  local f = rel and s.files[rel]
  if not f or f.buf ~= buf or f.whole or #f.hunks == 0 then
    return
  end
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  local i = M.hunk_at(f, row, false)
  if not i then
    return
  end
  local pos = 0
  for n, e in ipairs(M.flatten(s)) do
    if e.path == rel and e.index == i then
      pos = n
      break
    end
  end
  local count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_extmark(buf, M.ns_hint, M.anchor_row(f.hunks[i], count), 0, {
    virt_text = { { M.hint_text(s, pos, f.status == "conflicted"), "AgentdiffHint" } },
    virt_text_pos = "right_align",
    priority = 130,
  })
end

---Redraw every loaded project buffer and the hint.
---@param s AgentdiffSession
function M.all(s)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      M.buffer(s, b)
    end
  end
  M.hint(s)
end

return M
