---Buffer integration: Neovim's own writes, external changes to loaded buffers,
---conflicts, and the undo journal.
---@class AgentdiffBuffers
local M = {}

local claims = require("agentdiff.claims")
local merge = require("agentdiff.merge")
local review = require("agentdiff.review")
local session = require("agentdiff.session")
local util = require("agentdiff.util")

---@param ev table
---@return string? rel
local function write_target(s, ev)
  local name = ev.match ~= "" and ev.match or vim.api.nvim_buf_get_name(ev.buf)
  if name == "" then
    return nil
  end
  local abs = vim.fn.fnamemodify(name, ":p")
  local dir = vim.uv.fs_realpath(vim.fs.dirname(abs))
  if dir then
    abs = dir .. "/" .. vim.fs.basename(abs)
  end
  local rel = util.relative(s.root, abs)
  if rel and vim.fs.basename(rel) == ".gitignore" then
    s.ignored = {} -- ignore rules may change with this write
  end
  if rel and not session.reviewable(s, rel) then
    return nil
  end
  return rel
end

---Replace a buffer's content with display-space lines, touching only the
---lines that change (one undo block, cursor and marks kept elsewhere).
---@param buf integer
---@param lines string[]
function M.set_lines(buf, lines)
  local new = vim.list_extend({}, lines)
  local eol = false
  if #new > 1 and new[#new] == "" then
    new[#new] = nil
    eol = true
  elseif #new == 0 then
    new = { "" }
  end
  local old = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = merge.diff(old, new)
  for i = #hunks, 1, -1 do
    local h = hunks[i]
    vim.api.nvim_buf_set_lines(buf, h.a_lo, h.a_hi, false, merge.slice(new, h.b_lo, h.b_hi))
  end
  if vim.bo[buf].eol ~= eol and not (#lines == 1 and lines[1] == "") then
    vim.bo[buf].eol = eol
    if not eol then
      vim.bo[buf].fixeol = false
    end
  end
end

---Make a buffer hold `lines` while Neovim believes it last read the current
---disk file: reload it (undoable, keeps the undo history) and put the lines
---back on top. Without this, writing a buffer whose external change was merged
---in would hit Neovim's "file has been changed since reading it" prompt.
---@param buf integer
---@param lines string[]
function M.resync(buf, lines)
  local view = vim.fn.bufwinid(buf) ~= -1 and vim.api.nvim_win_call(vim.fn.bufwinid(buf), vim.fn.winsaveview)
    or nil
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent keepalt keepjumps edit!")
  end)
  M.set_lines(buf, lines)
  if view then
    vim.api.nvim_win_call(vim.fn.bufwinid(buf), function()
      vim.fn.winrestview(view)
    end)
  end
end

---Remove a buffer without closing any window: every window that shows it
---switches to the alternate buffer (or a fresh empty one) first. Closing a
---window could leave only side windows (neo-tree, the panel), and plugins
---that quit Neovim when only they remain would then exit.
---@param buf integer
function M.wipe(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(win, function()
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= buf and vim.fn.buflisted(alt) == 1 and vim.api.nvim_buf_is_loaded(alt) then
        vim.api.nvim_win_set_buf(win, alt)
      else
        vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
      end
    end)
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

---@param buf integer
---@return integer
local function undo_seq(buf)
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.undotree().seq_cur
  end)
end
M.undo_seq = undo_seq

---Record an agentdiff undo so that undoing it (with `u`) makes the agent's
---change pending again.
---@param s AgentdiffSession
---@param buf integer
---@param rec AgentdiffUndoRecord
function M.record_undo(s, buf, rec)
  s.journal[buf] = s.journal[buf] or {}
  table.insert(s.journal[buf], rec)
end

---@param s AgentdiffSession
---@param buf integer
local function check_journal(s, buf)
  local recs = s.journal[buf]
  if not recs or #recs == 0 then
    return
  end
  local seq = undo_seq(buf)
  for i = #recs, 1, -1 do
    local rec = recs[i]
    if seq <= rec.seq_before then
      -- The user undid agentdiff's undo: the agent's text is back, and it is
      -- not the user's edit.
      s.base_override[buf] = rec.before
      table.remove(recs, i)
    end
  end
end

---@param s AgentdiffSession
---@param buf integer
local function on_change(s, buf)
  check_journal(s, buf)
  local rel = session.rel_of_buf(s, buf)
  if rel then
    review.refresh(s, { rel })
  end
end

---Debounced per buffer.
---@type table<integer, uv.uv_timer_t>
local debounce = {}

---@param s AgentdiffSession
---@param buf integer
local function schedule_change(s, buf)
  local t = debounce[buf]
  if not t then
    t = assert(vim.uv.new_timer())
    debounce[buf] = t
  end
  t:stop()
  t:start(100, 0, function()
    vim.schedule(function()
      if session.get() == s and vim.api.nvim_buf_is_loaded(buf) then
        on_change(s, buf)
      end
    end)
  end)
end

---Run pending debounced updates now (tests, and before actions).
---@param s AgentdiffSession
function M.flush(s)
  for buf, t in pairs(debounce) do
    if t:is_active() then
      t:stop()
      if vim.api.nvim_buf_is_loaded(buf) then
        on_change(s, buf)
      end
    end
  end
end

---@param s AgentdiffSession
---@param buf integer
local function forget(s, buf)
  s.synced[buf] = nil
  s.base_override[buf] = nil
  s.journal[buf] = nil
  s.views[buf] = nil
  local t = debounce[buf]
  if t then
    t:stop()
    if not t:is_closing() then
      t:close()
    end
    debounce[buf] = nil
  end
end

---External change to a loaded buffer (FileChangedShell).
---@param s AgentdiffSession
---@param buf integer
local function on_file_changed(s, buf)
  local rel = session.rel_of_buf(s, buf)
  if not rel or not s.ready then
    vim.v.fcs_choice = "ask"
    return
  end
  local reason = vim.v.fcs_reason
  if reason == "deleted" or reason == "mode" or reason == "time" then
    vim.v.fcs_choice = ""
    vim.schedule(function()
      if session.get() == s then
        review.refresh(s, { rel })
      end
    end)
    return
  end
  if not vim.bo[buf].modified then
    vim.v.fcs_choice = "reload"
    return
  end
  -- Unsaved edits: merge the disk change into the buffer instead of prompting.
  vim.v.fcs_choice = ""
  local D = util.read_file(session.abs(s, rel))
  local synced = s.synced[buf]
  if synced == nil then
    synced = s.store:read("observed", { rel })[rel]
  end
  local base = review.disp(buf, synced or nil)
  local cur = review.buf_lines(buf)
  local theirs = review.disp(buf, D)
  local merged, conflict = merge.merge3(base, cur, theirs)
  if conflict then
    s.conflicts[rel] = true
    vim.schedule(function()
      if session.get() ~= s then
        return
      end
      local key = type(s.opts.keymaps) == "table" and s.opts.keymaps.resolve
      util.notify(
        ("agentdiff: %s changed on disk and overlaps your unsaved edits%s"):format(
          rel,
          key and (" — " .. key .. " to resolve") or " — :Agentdiff resolve"
        ),
        vim.log.levels.WARN
      )
      review.refresh(s, { rel })
    end)
    return
  end
  s.synced[buf] = D or false
  vim.schedule(function()
    if session.get() == s and vim.api.nvim_buf_is_loaded(buf) then
      M.resync(buf, merged)
      review.refresh(s, { rel })
    end
  end)
end

---@param s AgentdiffSession
function M.attach(s)
  local g = s.group
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = g,
    callback = function(ev)
      local rel = session.rel_of_buf(s, ev.buf)
      if not rel then
        return
      end
      s.synced[ev.buf] = util.read_file(session.abs(s, rel)) or false
      s.base_override[ev.buf] = nil
      vim.schedule(function()
        if session.get() == s then
          review.refresh(s, { rel })
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = g,
    callback = function(ev)
      if not s.ready then
        return
      end
      local rel = write_target(s, ev)
      if not rel then
        return
      end
      -- An agent change Neovim is about to overwrite still counts as the
      -- agent's: process it before the write.
      local D0 = util.read_file(session.abs(s, rel))
      local O = s.store:read("observed", { rel })[rel]
      if (D0 or false) ~= (O or false) and not claims.claimed(s.store, rel, s.opts.claim_ttl) then
        review.process(s, { rel }, "agent")
      end
      s.writing[rel] = true
      claims.add(s.store, { rel })
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = g,
    callback = function(ev)
      if not s.ready then
        return
      end
      local rel = write_target(s, ev)
      if not rel then
        return
      end
      review.process(s, { rel }, "user")
      s.writing[rel] = nil
      s.conflicts[rel] = nil
      s.synced[ev.buf] = util.read_file(session.abs(s, rel)) or false
      s.base_override[ev.buf] = nil
      review.refresh(s, { rel })
    end,
  })

  vim.api.nvim_create_autocmd("FileChangedShell", {
    group = g,
    callback = function(ev)
      on_file_changed(s, ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = g,
    callback = function(ev)
      if s.files[session.rel_of_buf(s, ev.buf) or ""] or s.journal[ev.buf] or vim.bo[ev.buf].modified then
        schedule_change(s, ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = g,
    callback = function(ev)
      forget(s, ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "BufWinEnter", "WinEnter" }, {
    group = g,
    callback = function()
      require("agentdiff.render").hint(s)
    end,
  })

  -- Buffers loaded before the session started.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      local rel = session.rel_of_buf(s, b)
      if rel and s.synced[b] == nil then
        s.synced[b] = util.read_file(session.abs(s, rel)) or false
      end
    end
  end
end

function M.detach()
  for buf, t in pairs(debounce) do
    t:stop()
    if not t:is_closing() then
      t:close()
    end
    debounce[buf] = nil
  end
end

return M
