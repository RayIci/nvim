---Detection: find disk changes agentdiff has not processed yet and give each an
---author.
---
---While Neovim is focused a timer polls every `poll_interval` ms (two stat-only
---git queries against the observed index). An unclaimed change is confirmed as
---the agent's only when a second poll `settle` ms later still finds it
---unclaimed, which gives another Neovim instance time to claim its own write.
---
---Git-guard: when the project's HEAD or stash moves (checkout, pull, reset,
---stash, commit…), changed files whose content equals HEAD were put there by
---git and are folded into the baseline instead of becoming pending.
---@class AgentdiffDetect
local M = {}

local claims = require("agentdiff.claims")
local merge = require("agentdiff.merge")
local review = require("agentdiff.review")
local session = require("agentdiff.session")
local store_mod = require("agentdiff.store")
local util = require("agentdiff.util")

local uv = vim.uv

---@type uv.uv_timer_t?
local timer = nil
local running = false
local focused = true
---@type table<string, integer>  path → first time an unclaimed change was seen
local suspects = {}
local guard_sig = nil
---@type uv.uv_timer_t?
local confirm_timer = nil

---@param s AgentdiffSession
---@return string?
local function project_gitdir(s)
  if s.project_gitdir == nil then
    local r = store_mod.project_git(s.root, { "rev-parse", "--absolute-git-dir" })
    s.project_gitdir = r.code == 0 and vim.trim(r.stdout or "") or false
  end
  return s.project_gitdir or nil
end

---Fingerprint of the project's HEAD and stash movement.
---@param s AgentdiffSession
---@return string
local function guard_signature(s)
  local gd = project_gitdir(s)
  if not gd then
    return ""
  end
  local parts = {}
  for _, f in ipairs({ "HEAD", "ORIG_HEAD", "logs/HEAD", "logs/refs/stash" }) do
    local st = uv.fs_stat(gd .. "/" .. f)
    parts[#parts + 1] = st and (st.mtime.sec .. "." .. st.mtime.nsec .. ":" .. st.size) or "-"
  end
  return table.concat(parts, "|")
end

---@param out string?
---@return table<string, boolean>
local function set0(out)
  local res = {}
  for item in (out or ""):gmatch("([^%z]+)") do
    res[item] = true
  end
  return res
end

---Paths whose disk state git itself just produced (content equals HEAD, or
---deleted and absent from HEAD).
---@param s AgentdiffSession
---@param paths string[]
---@return table<string, boolean>
local function git_produced(s, paths)
  local res = {}
  if #paths == 0 then
    return res
  end
  local args = { "ls-tree", "-r", "-z", "--name-only", "HEAD", "--" }
  vim.list_extend(args, paths)
  local in_head = set0(store_mod.project_git(s.root, args).stdout)
  local dargs = { "diff", "--name-only", "-z", "--no-renames", "HEAD", "--" }
  vim.list_extend(dargs, paths)
  local differs = set0(store_mod.project_git(s.root, dargs).stdout)
  for _, p in ipairs(paths) do
    local exists = uv.fs_stat(session.abs(s, p)) ~= nil
    if exists then
      res[p] = in_head[p] == true and not differs[p]
    else
      res[p] = not in_head[p]
    end
  end
  return res
end

---Paths whose change only moves them back toward their HEAD content: a
---discard through git or a git client (`git restore`, `git checkout -- f`,
---lazygit's discard of a file or a hunk). Such a change satisfies
---merge3(observed, disk, HEAD) == HEAD; a change that moves away from HEAD
---(an agent edit, staged or not) doesn't.
---@param s AgentdiffSession
---@param paths string[]
---@return table<string, boolean>
local function discarded(s, paths)
  local res = {}
  if #paths == 0 or not project_gitdir(s) then
    return res
  end
  local head = store_mod.head_contents(s.root, paths)
  local observed = s.store:read("observed", paths)
  for _, p in ipairs(paths) do
    local H = head[p] or nil
    local D = util.read_file(session.abs(s, p))
    local O = observed[p] or nil
    if H and D and D ~= O and not review.is_whole(s, H, D, O) then
      local m = merge.merge3(merge.lines(O), merge.lines(D), merge.lines(H))
      res[p] = merge.join(m) == H
    end
  end
  return res
end

---Reload loaded, unmodified buffers of changed paths (FileChangedShell does
---the per-buffer work, including merging into modified buffers).
---@param s AgentdiffSession
---@param paths string[]
local function sync_buffers(s, paths)
  for _, p in ipairs(paths) do
    local b = session.buf_of_rel(s, p)
    if b then
      pcall(vim.cmd.checktime, b)
    end
  end
end

---Attribute and process a list of changes against the observed index.
---@param s AgentdiffSession
---@param changes AgentdiffChange[]
---@param mode "poll"|"agent"|"user"  poll = normal attribution; agent/user force the author
---@return boolean need_confirm
local function handle(s, changes, mode)
  local ttl = s.opts.claim_ttl
  local now = util.now_ms()
  local sig = guard_signature(s)
  local guard_moved = guard_sig ~= nil and sig ~= guard_sig
  guard_sig = sig

  local users, agents, candidates = {}, {}, {}
  local seen = {}
  for _, c in ipairs(changes) do
    local p = c.path
    seen[p] = true
    if not session.reviewable(s, p) then
      -- never reviewed (e.g. a stale entry under .git/): nothing to attribute
    elseif s.writing[p] then
      -- Neovim is writing it: BufWritePost processes it synchronously.
    elseif mode == "user" or claims.claimed(s.store, p, ttl) then
      users[#users + 1] = p
    elseif mode == "agent" then
      agents[#agents + 1] = p
    else
      candidates[#candidates + 1] = p
    end
  end

  local produced = guard_moved and git_produced(s, candidates) or {}
  local rest = {}
  for _, p in ipairs(candidates) do
    if not produced[p] then
      rest[#rest + 1] = p
    end
  end
  local reverted = discarded(s, rest)
  local need_confirm = false
  for _, p in ipairs(candidates) do
    if produced[p] or reverted[p] then
      users[#users + 1] = p
    elseif s.opts.settle > 0 and (not suspects[p] or now - suspects[p] < s.opts.settle) then
      suspects[p] = suspects[p] or now
      need_confirm = true
    else
      agents[#agents + 1] = p
    end
  end
  for p in pairs(suspects) do
    if not seen[p] then
      suspects[p] = nil
    end
  end
  for _, p in ipairs(users) do
    suspects[p] = nil
  end
  for _, p in ipairs(agents) do
    suspects[p] = nil
  end

  review.process(s, users, "user")
  review.process(s, agents, "agent")
  if #users > 0 or #agents > 0 then
    local all = vim.list_extend(vim.list_extend({}, users), agents)
    sync_buffers(s, all)
    review.refresh(s)
  end
  return need_confirm
end

---@param s AgentdiffSession
local function schedule_confirm(s)
  if confirm_timer then
    return
  end
  local t = assert(uv.new_timer())
  confirm_timer = t
  t:start(s.opts.settle, 0, function()
    t:close()
    confirm_timer = nil
    vim.schedule(M.poll)
  end)
end

---Asynchronous poll (the timer's work).
function M.poll()
  local s = session.get()
  if not s or not s.ready or running then
    return
  end
  running = true
  s.store:changes("observed", function(changes)
    running = false
    if session.get() ~= s then
      return
    end
    local ok, need = pcall(handle, s, changes, "poll")
    if not ok then
      util.notify("agentdiff: " .. tostring(need), vim.log.levels.ERROR)
    elseif need then
      schedule_confirm(s)
    end
  end)
end

---Synchronous detection.
---  mode "poll"  normal attribution (settle respected unless opts.settle == false)
---  mode "agent" every unclaimed change is the agent's (before a shell command)
---  mode "user"  every change is the user's (right after a shell command)
---@param mode? "poll"|"agent"|"user"
---@param opts? { settle: boolean? }
function M.now(mode, opts)
  local s = session.get()
  if not s or not s.ready then
    return
  end
  local saved = s.opts.settle
  if opts and opts.settle == false then
    s.opts.settle = 0
  end
  local ok, err = pcall(function()
    local need = handle(s, s.store:changes("observed") or {}, mode or "poll")
    if need then
      schedule_confirm(s)
    end
  end)
  s.opts.settle = saved
  if not ok then
    error(err, 0)
  end
end

---@param s AgentdiffSession
local function start_timer(s)
  if s.opts.poll_interval <= 0 then
    return
  end
  if not timer then
    timer = assert(uv.new_timer())
  end
  local t = timer
  t:start(0, s.opts.poll_interval, function()
    vim.schedule(M.poll)
  end)
end

local function stop_timer()
  if timer then
    timer:stop()
  end
end

---@param s AgentdiffSession
function M.start(s)
  guard_sig = guard_signature(s)
  local g = s.group
  vim.api.nvim_create_autocmd("FocusLost", {
    group = g,
    callback = function()
      focused = false
      stop_timer()
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = g,
    callback = function()
      focused = true
      start_timer(s)
    end,
  })
  local last_enter = 0
  vim.api.nvim_create_autocmd("BufEnter", {
    group = g,
    callback = function()
      local now = uv.now()
      if now - last_enter > 200 then
        last_enter = now
        M.poll()
      end
    end,
  })
  -- Shell commands from Neovim: settle what's pending first, then claim
  -- whatever the command changed.
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = g,
    callback = function()
      if vim.v.event.abort or vim.fn.getcmdtype() ~= ":" then
        return
      end
      if claims.is_shell_cmdline(vim.fn.getcmdline()) then
        pcall(M.now, "agent")
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "ShellCmdPost", "ShellFilterPost" }, {
    group = g,
    callback = function()
      pcall(M.now, "user")
    end,
  })
  if focused then
    start_timer(s)
  end
end

function M.stop()
  stop_timer()
  if timer and not timer:is_closing() then
    timer:close()
  end
  timer = nil
  if confirm_timer and not confirm_timer:is_closing() then
    confirm_timer:close()
  end
  confirm_timer = nil
  suspects = {}
  running = false
  guard_sig = nil
  focused = true
end

return M
