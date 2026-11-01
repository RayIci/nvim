---User actions: navigation, keep, undo, conflict resolution.
---
---Keep and undo take a scope ("hunk", "file", "all") and, for "hunk", an
---optional 1-based line range {l1, l2}: then only the lines of pending changes
---inside the range are kept or undone. A change's removed lines count as
---selected when the range starts at or above the change's first line.
---@class AgentdiffActions
local M = {}

local buffers = require("agentdiff.buffers")
local claims = require("agentdiff.claims")
local merge = require("agentdiff.merge")
local render = require("agentdiff.render")
local review = require("agentdiff.review")
local session = require("agentdiff.session")
local util = require("agentdiff.util")

---@class AgentdiffActionOpts
---@field scope? "hunk"|"file"|"all"
---@field range? integer[]   1-based {first, last} line, for scope "hunk"
---@field path? string       project-relative path (default: current buffer)
---@field force? boolean     skip the keep-all / undo-all confirmation

---@return AgentdiffSession?
local function active()
  local s = session.get()
  if not s or not s.ready then
    util.notify("agentdiff: not active yet", vim.log.levels.WARN)
    return nil
  end
  buffers.flush(s)
  return s
end

---@param s AgentdiffSession
---@param path string?
---@return string? rel
---@return AgentdiffFile? file
local function target(s, path)
  -- From a side-by-side baseline window, act on the file it shows.
  local rel = path or vim.b.agentdiff_baseline_of or session.rel_of_buf(s, vim.api.nvim_get_current_buf())
  if not rel then
    return nil, nil
  end
  local f = review.compute(s, rel)
  s.files[rel] = f
  return rel, f
end

---The current buffer's 0-based cursor row (or the paired file's, from a baseline view).
---@return integer
local function cursor_row()
  return vim.api.nvim_win_get_cursor(0)[1] - 1
end

---@class AgentdiffSelection
---@field h AgentdiffHunk
---@field del boolean        removed lines selected
---@field lo integer         selected current-side rows [lo, hi)
---@field hi integer

---@param f AgentdiffFile
---@param range integer[]?
---@return AgentdiffSelection[]
local function select_hunks(f, range)
  local sel = {}
  if not range and vim.b.agentdiff_baseline_of then
    -- In the side-by-side baseline window the cursor is on the baseline side.
    local row = cursor_row()
    for _, h in ipairs(f.hunks) do
      if row >= h.a_lo and row < math.max(h.a_hi, h.a_lo + 1) then
        return { { h = h, del = true, lo = h.b_lo, hi = h.b_hi } }
      end
    end
    return sel
  end
  if not range then
    local i = render.hunk_at(f, cursor_row(), true)
    if i then
      local h = f.hunks[i]
      sel[1] = { h = h, del = true, lo = h.b_lo, hi = h.b_hi }
    end
    return sel
  end
  local r1, r2 = range[1] - 1, range[2] -- rows [r1, r2)
  local nlines = #f.cur
  if nlines > 0 and f.cur[nlines] == "" then
    nlines = nlines - 1
  end
  for _, h in ipairs(f.hunks) do
    local lo, hi = math.max(h.b_lo, r1), math.min(h.b_hi, r2)
    -- Removed lines are drawn above the anchor row: selected when the range
    -- covers that row and starts at or above it.
    local anchor = render.anchor_row(h, nlines)
    local del = h.a_hi > h.a_lo and r1 <= anchor and anchor < r2
    if hi > lo or del then
      sel[#sel + 1] = { h = h, del = del, lo = math.max(lo, h.b_lo), hi = math.max(hi, math.max(lo, h.b_lo)) }
    end
  end
  return sel
end

---Baseline lines after keeping the selections.
---@param f AgentdiffFile
---@param sels AgentdiffSelection[]
---@return string[]
local function kept_base(f, sels)
  local base = f.base
  for i = #sels, 1, -1 do
    local x = sels[i]
    local repl = x.del and {} or merge.slice(f.base, x.h.a_lo, x.h.a_hi)
    vim.list_extend(repl, merge.slice(f.cur, x.lo, x.hi))
    base = merge.splice(base, x.h.a_lo, x.h.a_hi, repl)
  end
  return base
end

---Current lines after undoing the selections.
---@param f AgentdiffFile
---@param sels AgentdiffSelection[]
---@return string[]
local function undone_cur(f, sels)
  local cur = f.cur
  for i = #sels, 1, -1 do
    local x = sels[i]
    local repl = x.del and merge.slice(f.base, x.h.a_lo, x.h.a_hi) or {}
    vim.list_extend(repl, merge.slice(f.cur, x.h.b_lo, x.lo))
    vim.list_extend(repl, merge.slice(f.cur, x.hi, x.h.b_hi))
    cur = merge.splice(cur, x.h.b_lo, x.h.b_hi, repl)
  end
  return cur
end

---@param s AgentdiffSession
---@param rel string
local function disk_text(s, rel)
  return util.read_file(session.abs(s, rel))
end

---Write the baseline from new display-space baseline lines of a file.
---@param s AgentdiffSession
---@param f AgentdiffFile
---@param new_base string[]
local function write_base(s, f, new_base)
  local B = s.store:read("baseline", { f.path })[f.path] or nil
  local text
  if f.buf then
    local bl = review.disp(f.buf, B)
    text = review.undisp(f.buf, (merge.merge3(f.base, bl, new_base)))
  else
    text = merge.join(new_base)
  end
  if B == nil and f.status == "created" and #new_base == 0 then
    text = nil
  end
  review.set_baseline(s, f.path, text)
end

---@param s AgentdiffSession
---@param rel string
---@return integer
local function load_hidden(s, rel)
  local b = vim.fn.bufadd(session.abs(s, rel))
  if not vim.api.nvim_buf_is_loaded(b) then
    vim.bo[b].buflisted = false
    vim.fn.bufload(b)
  end
  return b
end

---Restore the baseline of a whole file on disk (created/deleted/binary files).
---@param s AgentdiffSession
---@param rel string
local function restore_whole(s, rel)
  local B = s.store:read("baseline", { rel })[rel] or nil
  claims.add(s.store, { rel })
  local buf = session.buf_of_rel(s, rel)
  if B == nil then
    os.remove(session.abs(s, rel))
    if buf then
      buffers.wipe(buf)
    end
  else
    util.write_file(session.abs(s, rel), B)
  end
  review.process(s, { rel }, "user")
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.cmd.checktime, buf)
  end
end

---@param s AgentdiffSession
---@param rel string
---@param f AgentdiffFile
---@param opts AgentdiffActionOpts
---@return boolean changed
local function keep_one(s, rel, f, opts)
  if f.whole or f.status == "deleted" or (f.status == "created" and opts.scope ~= "hunk") then
    local D = disk_text(s, rel)
    review.set_baseline(s, rel, D)
    if D == nil then
      local buf = session.buf_of_rel(s, rel)
      if buf and not vim.bo[buf].modified then
        buffers.wipe(buf)
      end
    end
    s.conflicts[rel] = nil
    return true
  end
  local sels
  if opts.scope == "hunk" then
    sels = select_hunks(f, opts.range)
    if #sels == 0 then
      return false
    end
  else
    sels = {}
    for _, h in ipairs(f.hunks) do
      sels[#sels + 1] = { h = h, del = true, lo = h.b_lo, hi = h.b_hi }
    end
  end
  write_base(s, f, kept_base(f, sels))
  return true
end

---@param s AgentdiffSession
---@param rel string
---@param f AgentdiffFile
---@param opts AgentdiffActionOpts
---@return boolean changed
local function undo_one(s, rel, f, opts)
  local whole_scope = opts.scope ~= "hunk" or (not opts.range and #f.hunks == 1)
  if f.whole or f.status == "deleted" or (f.status == "created" and whole_scope) then
    restore_whole(s, rel)
    s.conflicts[rel] = nil
    return true
  end
  if not f.buf then
    load_hidden(s, rel)
    local loaded = review.compute(s, rel)
    if not loaded then
      return false
    end
    f = loaded
  end
  local buf = assert(f.buf)
  local sels
  if opts.scope == "hunk" then
    sels = select_hunks(f, opts.range)
    if #sels == 0 then
      return false
    end
  else
    sels = {}
    for _, h in ipairs(f.hunks) do
      sels[#sels + 1] = { h = h, del = true, lo = h.b_lo, hi = h.b_hi }
    end
  end
  local was_modified = vim.bo[buf].modified
  local before = review.buf_lines(buf)
  local seq_before = buffers.undo_seq(buf)
  buffers.set_lines(buf, undone_cur(f, sels))
  buffers.record_undo(s, buf, { seq_before = seq_before, seq_after = buffers.undo_seq(buf), before = before })
  if not was_modified then
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent keepalt keepjumps update")
    end)
  end
  return true
end

---@param what string
---@return boolean
local function confirm_all(s, what, opts)
  if opts.force or not s.opts.confirm then
    return true
  end
  local n = render.count(s)
  return vim.fn.confirm(("%s all %d pending changes in %d files?"):format(what, n, #s.order), "&Yes\n&No", 2)
    == 1
end

---@param kind "keep"|"undo"
---@param opts AgentdiffActionOpts?
local function act(kind, opts)
  opts = opts or {}
  opts.scope = opts.scope or "hunk"
  local s = active()
  if not s then
    return
  end
  local fn = kind == "keep" and keep_one or undo_one
  if opts.scope == "all" then
    review.refresh(s)
    if #s.order == 0 then
      return util.notify("agentdiff: nothing pending")
    end
    if not confirm_all(s, kind == "keep" and "Keep" or "Undo", opts) then
      return
    end
    for _, p in ipairs(vim.list_extend({}, s.order)) do
      local f = review.compute(s, p)
      if f then
        fn(s, p, f, { scope = "file" })
      end
    end
    review.refresh(s)
    return
  end
  local rel, f = target(s, opts.path)
  if not rel or not f then
    return util.notify("agentdiff: no pending change here")
  end
  if not fn(s, rel, f, opts) then
    return util.notify("agentdiff: no pending change under the cursor")
  end
  review.refresh(s, { rel })
end

---@param opts AgentdiffActionOpts?
function M.keep(opts)
  act("keep", opts)
end

---@param opts AgentdiffActionOpts?
function M.undo(opts)
  act("undo", opts)
end

---@param s AgentdiffSession
---@param rel string
---@param row integer 0-based
local function jump(s, rel, row)
  local cur = session.rel_of_buf(s, vim.api.nvim_get_current_buf())
  if cur ~= rel then
    vim.cmd.edit(vim.fn.fnameescape(session.abs(s, rel)))
  end
  local count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(row + 1, count)), 0 })
  render.hint(s)
end

---@param dir 1|-1
---@param by_file boolean
local function move(dir, by_file)
  local s = active()
  if not s then
    return
  end
  review.refresh(s)
  local entries = render.flatten(s)
  if #entries == 0 then
    return util.notify("agentdiff: nothing pending")
  end
  if by_file then
    local seen, files = {}, {}
    for _, e in ipairs(entries) do
      if not seen[e.path] then
        seen[e.path] = true
        files[#files + 1] = e
      end
    end
    entries = files
  end
  local cur = session.rel_of_buf(s, vim.api.nvim_get_current_buf()) or ""
  local row = cursor_row()
  local function after(e)
    if by_file then
      return e.path > cur
    end
    return e.path > cur or (e.path == cur and e.row > row)
  end
  local function before(e)
    if by_file then
      return e.path < cur
    end
    return e.path < cur or (e.path == cur and e.row < row)
  end
  local pick
  if dir == 1 then
    for _, e in ipairs(entries) do
      if after(e) then
        pick = e
        break
      end
    end
    if not pick then
      pick = entries[1]
      util.notify("agentdiff: wrapped to the first change")
    end
  else
    for i = #entries, 1, -1 do
      if before(entries[i]) then
        pick = entries[i]
        break
      end
    end
    if not pick then
      pick = entries[#entries]
      util.notify("agentdiff: wrapped to the last change")
    end
  end
  jump(s, pick.path, pick.row)
end

function M.next()
  move(1, false)
end

function M.prev()
  move(-1, false)
end

function M.next_file()
  move(1, true)
end

function M.prev_file()
  move(-1, true)
end

---Open a pending file at its first change.
---@param rel string
function M.open(rel)
  local s = active()
  if not s then
    return
  end
  local f = s.files[rel] or review.compute(s, rel)
  jump(s, rel, f and f.hunks[1] and f.hunks[1].b_lo or 0)
end

---Resolve a conflicted file.
---@param choice? "agent"|"mine"|"compare"
---@param path? string
function M.resolve(choice, path)
  local s = active()
  if not s then
    return
  end
  local rel = path or session.rel_of_buf(s, vim.api.nvim_get_current_buf())
  if not rel or not s.conflicts[rel] then
    return util.notify("agentdiff: no conflict here")
  end
  local function apply(c)
    local buf = session.buf_of_rel(s, rel)
    if c == "agent" then
      s.conflicts[rel] = nil
      if buf then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent edit!")
        end)
      end
    elseif c == "mine" then
      s.conflicts[rel] = nil
      local B = s.store:read("baseline", { rel })[rel] or nil
      claims.add(s.store, { rel })
      if B == nil then
        os.remove(session.abs(s, rel))
      else
        util.write_file(session.abs(s, rel), B)
      end
      review.process(s, { rel }, "user")
      if buf and vim.api.nvim_buf_is_loaded(buf) then
        -- keep the unsaved edits, but on top of the file now on disk
        buffers.resync(buf, review.buf_lines(buf))
      end
    elseif c == "compare" then
      require("agentdiff.sidebyside").compare_disk(s, rel)
      return
    end
    review.refresh(s, { rel })
  end
  if choice then
    return apply(choice)
  end
  vim.ui.select({ "agent", "mine", "compare" }, {
    prompt = "agentdiff: " .. rel .. " conflicts with your unsaved edits",
    format_item = function(c)
      return ({
        agent = "Take the agent's version (your unsaved edits can be restored with u)",
        mine = "Keep mine (undo the agent's changes to this file)",
        compare = "Compare side by side",
      })[c]
    end,
  }, function(c)
    if c then
      apply(c)
    end
  end)
end

return M
