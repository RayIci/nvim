---Line diffs and three-way merges over line arrays.
---
---Text model: a file's content is a string, or nil when the file is absent.
---`lines(text)` splits on "\n" keeping a trailing "" element when the text
---ends with a newline, so `join(lines(t)) == t` for every string, and a change
---to the final newline is a change to that last element. An absent file is
---the empty array.
---@class AgentdiffMerge
local M = {}

---A hunk maps the half-open, 0-based line range [a_lo, a_hi) of the old side
---to [b_lo, b_hi) of the new side. An empty range is an insertion point.
---@class AgentdiffHunk
---@field a_lo integer
---@field a_hi integer
---@field b_lo integer
---@field b_hi integer

---@param text string?
---@return string[]
function M.lines(text)
  if text == nil then
    return {}
  end
  return vim.split(text, "\n", { plain = true })
end

---@param lines string[]
---@return string
function M.join(lines)
  return table.concat(lines, "\n")
end

---@param lines string[]
---@return string
local function diff_input(lines)
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

---Line hunks turning `a` into `b`, in order.
---@param a string[]
---@param b string[]
---@return AgentdiffHunk[]
function M.diff(a, b)
  if #a == #b then
    local same = true
    for i = 1, #a do
      if a[i] ~= b[i] then
        same = false
        break
      end
    end
    if same then
      return {}
    end
  end
  local res =
    vim.text.diff(diff_input(a), diff_input(b), { result_type = "indices", algorithm = "histogram" })
  ---@cast res integer[][]
  local out = {}
  for _, h in ipairs(res) do
    local as, ac, bs, bc = h[1], h[2], h[3], h[4]
    local a_lo = ac == 0 and as or as - 1
    local b_lo = bc == 0 and bs or bs - 1
    out[#out + 1] = { a_lo = a_lo, a_hi = a_lo + ac, b_lo = b_lo, b_hi = b_lo + bc }
  end
  return out
end

---@param h AgentdiffHunk
---@return "added"|"removed"|"changed"
function M.kind(h)
  if h.a_lo == h.a_hi then
    return "added"
  elseif h.b_lo == h.b_hi then
    return "removed"
  end
  return "changed"
end

---@param t string[]
---@param lo integer 0-based inclusive
---@param hi integer 0-based exclusive
---@return string[]
function M.slice(t, lo, hi)
  local out = {}
  for i = lo + 1, hi do
    out[#out + 1] = t[i]
  end
  return out
end

---@param dst string[]
---@param src string[]
local function append(dst, src)
  for _, v in ipairs(src) do
    dst[#dst + 1] = v
  end
end

---Three-way merge. Changes base→ours and base→theirs that neither overlap nor
---touch are both applied; where they overlap or touch, ours wins.
---@param base string[]
---@param ours string[]
---@param theirs string[]
---@return string[] merged
---@return boolean conflicted  true when some region had changes on both sides
function M.merge3(base, ours, theirs)
  local items = {}
  for _, h in ipairs(M.diff(base, ours)) do
    items[#items + 1] = { h = h, side = "o" }
  end
  for _, h in ipairs(M.diff(base, theirs)) do
    items[#items + 1] = { h = h, side = "t" }
  end
  if #items == 0 then
    return vim.list_extend({}, ours), false
  end
  table.sort(items, function(x, y)
    if x.h.a_lo ~= y.h.a_lo then
      return x.h.a_lo < y.h.a_lo
    end
    return x.h.a_hi < y.h.a_hi
  end)

  -- Group items whose base ranges overlap or touch.
  local clusters = {}
  local cur
  for _, it in ipairs(items) do
    if cur and it.h.a_lo <= cur.hi then
      cur.hi = math.max(cur.hi, it.h.a_hi)
      table.insert(cur.items, it)
    else
      cur = { lo = it.h.a_lo, hi = it.h.a_hi, items = { it } }
      table.insert(clusters, cur)
    end
  end

  local merged, conflicted = {}, false
  local pos = 0
  local delta = { o = 0, t = 0 } -- line-count offset of each side before the cluster
  for _, c in ipairs(clusters) do
    local inner = { o = 0, t = 0 }
    local has = { o = false, t = false }
    for _, it in ipairs(c.items) do
      has[it.side] = true
      inner[it.side] = inner[it.side] + (it.h.b_hi - it.h.b_lo) - (it.h.a_hi - it.h.a_lo)
    end
    append(merged, M.slice(base, pos, c.lo))
    local side
    if has.o and has.t then
      side, conflicted = "o", true
    else
      side = has.o and "o" or "t"
    end
    local src = side == "o" and ours or theirs
    append(merged, M.slice(src, c.lo + delta[side], c.hi + delta[side] + inner[side]))
    delta.o = delta.o + inner.o
    delta.t = delta.t + inner.t
    pos = c.hi
  end
  append(merged, M.slice(base, pos, #base))
  return merged, conflicted
end

---Replace the region [lo, hi) of `t` with `repl`.
---@param t string[]
---@param lo integer
---@param hi integer
---@param repl string[]
---@return string[]
function M.splice(t, lo, hi, repl)
  local out = M.slice(t, 0, lo)
  append(out, repl)
  append(out, M.slice(t, hi, #t))
  return out
end

---True when the text looks binary (a NUL byte in its first 8000 bytes).
---@param text string?
---@return boolean
function M.is_binary(text)
  return text ~= nil and text:sub(1, 8000):find("\0", 1, true) ~= nil
end

---Strip a trailing "\r" from every element except the last (lines of a
---"dos" file as Neovim shows them in a buffer).
---@param lines string[]
---@return string[]
function M.strip_cr(lines)
  local out = {}
  for i, l in ipairs(lines) do
    out[i] = (i < #lines) and l:gsub("\r$", "") or l
  end
  return out
end

---Inverse of strip_cr: every element followed by a newline gets "\r".
---@param lines string[]
---@return string[]
function M.add_cr(lines)
  local out = {}
  for i, l in ipairs(lines) do
    out[i] = (i < #lines) and (l .. "\r") or l
  end
  return out
end

return M
