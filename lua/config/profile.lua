---Opt-in session profiler: where editor time goes over a working session.
---
---Active only when Neovim starts with NVIM_PROFILE=1 (required first thing in
---init.lua, before any plugin loads); otherwise setup() returns without
---installing anything. While active it records:
---  autocmds   Lua-callback autocmds by event x augroup: runs, total, slowest
---  lsp        requests by client x method: count, cancelled, response time
---  procs      spawned processes by executable (vim.uv.spawn, which vim.system
---             uses, and vim.fn.jobstart): count, total runtime
---  modules    sampled Lua time (jit.profile) attributed to the plugin or
---             configuration module running, covering decoration providers,
---             timers and scheduled callbacks no autocmd timing sees
---
---:ProfileReport opens the report and saves a JSON snapshot under
---stdpath("state")/profile/, :ProfileReset clears the counters, and
---:ProfileCompare shows two snapshots side by side per hour of uptime.
---@class ConfigProfile
local M = {}

---Sampling interval of the Lua profiler, in milliseconds.
local SAMPLE_MS = 10

---@class ProfileTiming
---@field count integer
---@field total number milliseconds
---@field max number milliseconds

---@class ProfileLspStat: ProfileTiming
---@field cancelled integer

---@class ProfileData
---@field started integer hrtime of setup or the last reset
---@field autocmds table<string, ProfileTiming> "event\0group" -> timing
---@field lsp table<string, ProfileLspStat> "client\0method" -> timing
---@field procs table<string, ProfileTiming> executable -> runtime
---@field modules table<string, integer> module -> samples

---@type ProfileData
local data

---@type table<string, integer> "client:request" -> hrtime at pending
local pending = {}

local hrtime = vim.uv.hrtime

---The original nvim_create_autocmd, so the profiler's own autocmds are not timed.
local create_autocmd = vim.api.nvim_create_autocmd

function M.enabled()
  return vim.env.NVIM_PROFILE == "1"
end

local function reset()
  data = { started = hrtime(), autocmds = {}, lsp = {}, procs = {}, modules = {} }
  pending = {}
end

---@param tbl table<string, ProfileTiming>
---@param key string
---@param ms number
local function add(tbl, key, ms)
  local t = tbl[key]
  if not t then
    t = { count = 0, total = 0, max = 0 }
    tbl[key] = t
  end
  t.count = t.count + 1
  t.total = t.total + ms
  if ms > t.max then
    t.max = ms
  end
end

-- =============================================================================
-- Autocmds
-- =============================================================================

---Group name for a group given to nvim_create_autocmd (id or name).
---@param group integer|string|nil
---@return string
local function group_label(group)
  if group == nil then
    return "(no group)"
  end
  if type(group) == "string" then
    return group
  end
  -- Resolved lazily: an id only maps to a name through existing autocmds.
  local ok, acs = pcall(vim.api.nvim_get_autocmds, { group = group })
  return ok and acs[1] and acs[1].group_name or ("#" .. group)
end

local function wrap_autocmds()
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim_create_autocmd = function(event, opts)
    local cb = type(opts) == "table" and opts.callback or nil
    if type(cb) == "function" then
      local group = opts.group
      local label ---@type string?
      opts = vim.tbl_extend("force", {}, opts)
      opts.callback = function(args)
        local t0 = hrtime()
        local result = cb(args)
        label = label or group_label(group)
        add(data.autocmds, args.event .. "\0" .. label, (hrtime() - t0) / 1e6)
        return result
      end
    end
    return create_autocmd(event, opts)
  end
end

-- =============================================================================
-- LSP
-- =============================================================================

local function watch_lsp()
  create_autocmd("LspRequest", {
    group = vim.api.nvim_create_augroup("config.profile.lsp", { clear = true }),
    callback = function(args)
      local d = args.data or {}
      local request = d.request or {}
      local id = ("%s:%s"):format(d.client_id, d.request_id)
      if request.type == "pending" then
        pending[id] = hrtime()
        return
      end
      local t0 = pending[id]
      if not t0 then
        return
      end
      pending[id] = nil
      local client = vim.lsp.get_client_by_id(d.client_id)
      local key = (client and client.name or ("#" .. tostring(d.client_id))) .. "\0" .. tostring(request.method)
      add(data.lsp, key, (hrtime() - t0) / 1e6)
      local stat = data.lsp[key] --[[@as ProfileLspStat]]
      stat.cancelled = (stat.cancelled or 0) + (request.type == "cancel" and 1 or 0)
    end,
  })
end

-- =============================================================================
-- Processes
-- =============================================================================

---@param cmd string|string[]
---@return string
local function executable(cmd)
  local first = type(cmd) == "table" and cmd[1] or tostring(cmd):match("^%s*(%S+)") or "?"
  return vim.fs.basename(tostring(first))
end

local function wrap_processes()
  local spawn = vim.uv.spawn
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.uv.spawn = function(path, options, on_exit)
    local t0 = hrtime()
    local name = executable(path)
    local handle, pid = spawn(path, options, function(...)
      add(data.procs, name, (hrtime() - t0) / 1e6)
      if on_exit then
        return on_exit(...)
      end
    end)
    return handle, pid
  end

  local jobstart = vim.fn.jobstart
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.jobstart = function(cmd, opts)
    local t0 = hrtime()
    local name = executable(cmd)
    opts = vim.tbl_extend("force", {}, opts or {})
    local on_exit = opts.on_exit
    opts.on_exit = function(...)
      add(data.procs, name, (hrtime() - t0) / 1e6)
      if on_exit then
        return on_exit(...)
      end
    end
    return jobstart(cmd, opts)
  end
end

-- =============================================================================
-- Lua sampling
-- =============================================================================

local config_lua = vim.fs.joinpath(vim.fn.stdpath("config") --[[@as string]], "lua") .. "/"
local runtime = (vim.env.VIMRUNTIME or "") .. "/"

---Module a source path belongs to: a plugin directory, a configuration module,
---or nil for Neovim's runtime and unknown code (the caller then keeps looking).
---@param path string
---@return string?
function M.module_of(path)
  local plugin = path:match("/pack/[^/]+/opt/([^/]+)/") or path:match("/pack/[^/]+/start/([^/]+)/")
  if plugin then
    return plugin
  end
  if path:sub(1, #config_lua) == config_lua then
    return "config:" .. path:sub(#config_lua + 1):gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", ".")
  end
  return nil
end

---@param stack string "path:line;path:line;..." innermost first
---@return string
local function attribute(stack)
  local fallback
  for frame in stack:gmatch("[^;]+") do
    local path = frame:match("^(.*):%d+$") or frame
    local mod = M.module_of(path)
    if mod then
      return mod
    end
    if not fallback and runtime ~= "/" and path:sub(1, #runtime) == runtime then
      fallback = "nvim-runtime"
    end
  end
  return fallback or "other"
end

local function start_sampling()
  local ok, profile = pcall(require, "jit.profile")
  if not ok then
    return
  end
  profile.start("i" .. SAMPLE_MS, function(thread, samples)
    local mod = attribute(profile.dumpstack(thread, "pl;", 12))
    data.modules[mod] = (data.modules[mod] or 0) + samples
  end)
  create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("config.profile.sampling", { clear = true }),
    callback = function()
      profile.stop()
    end,
  })
end

-- =============================================================================
-- Report and snapshots
-- =============================================================================

---@class ProfileSnapshot
---@field version integer
---@field created string ISO time
---@field appname string
---@field uptime_s number
---@field facts table<string, number>
---@field autocmds { event: string, group: string, count: integer, total: number, max: number }[]
---@field lsp { client: string, method: string, count: integer, cancelled: integer, total: number, max: number }[]
---@field procs { name: string, count: integer, total: number, max: number }[]
---@field modules { name: string, ms: number }[]

---@return ProfileSnapshot
function M.snapshot()
  local loaded, listed = 0, 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      loaded = loaded + 1
    end
    if vim.bo[buf].buflisted then
      listed = listed + 1
    end
  end
  local snap = {
    version = 1,
    created = os.date("!%Y-%m-%dT%H:%M:%SZ") --[[@as string]],
    appname = vim.env.NVIM_APPNAME or "nvim",
    uptime_s = (hrtime() - data.started) / 1e9,
    facts = {
      loaded_buffers = loaded,
      listed_buffers = listed,
      runtimepath_entries = #vim.api.nvim_list_runtime_paths(),
      lua_memory_kb = math.floor(collectgarbage("count")),
      lsp_clients = #vim.lsp.get_clients(),
    },
    autocmds = {},
    lsp = {},
    procs = {},
    modules = {},
  }
  for key, t in pairs(data.autocmds) do
    local event, group = key:match("^(.-)%z(.*)$")
    table.insert(snap.autocmds, { event = event, group = group, count = t.count, total = t.total, max = t.max })
  end
  for key, t in pairs(data.lsp) do
    local client, method = key:match("^(.-)%z(.*)$")
    table.insert(snap.lsp, {
      client = client,
      method = method,
      count = t.count,
      cancelled = t.cancelled or 0,
      total = t.total,
      max = t.max,
    })
  end
  for name, t in pairs(data.procs) do
    table.insert(snap.procs, { name = name, count = t.count, total = t.total, max = t.max })
  end
  for name, samples in pairs(data.modules) do
    table.insert(snap.modules, { name = name, ms = samples * SAMPLE_MS })
  end
  local function by_total(a, b)
    return a.total > b.total
  end
  table.sort(snap.autocmds, by_total)
  table.sort(snap.lsp, by_total)
  table.sort(snap.procs, by_total)
  table.sort(snap.modules, function(a, b)
    return a.ms > b.ms
  end)
  return snap
end

---@param ms number
---@return string
local function fmt_ms(ms)
  return ms >= 1000 and ("%.2fs"):format(ms / 1000) or ("%.1fms"):format(ms)
end

---@param snap ProfileSnapshot
---@return string[]
function M.render(snap)
  local lines = {
    ("Profile %s · %s · uptime %.1f min"):format(snap.appname, snap.created, snap.uptime_s / 60),
    "",
    "Session",
  }
  local facts = vim.tbl_keys(snap.facts)
  table.sort(facts)
  for _, k in ipairs(facts) do
    table.insert(lines, ("  %-22s %s"):format(k, snap.facts[k]))
  end

  table.insert(lines, "")
  table.insert(lines, "Autocmds (Lua callbacks)       runs      total    slowest")
  for _, a in ipairs(snap.autocmds) do
    table.insert(
      lines,
      ("  %-14s %-28s %6d %10s %10s"):format(a.event, a.group, a.count, fmt_ms(a.total), fmt_ms(a.max))
    )
  end

  table.insert(lines, "")
  table.insert(lines, "LSP requests                  count  cancel    avg      total")
  for _, l in ipairs(snap.lsp) do
    table.insert(
      lines,
      ("  %-14s %-34s %6d %6d %8s %10s"):format(
        l.client,
        l.method,
        l.count,
        l.cancelled,
        fmt_ms(l.total / math.max(l.count, 1)),
        fmt_ms(l.total)
      )
    )
  end

  table.insert(lines, "")
  table.insert(lines, "Processes                     count    runtime    longest")
  for _, p in ipairs(snap.procs) do
    table.insert(lines, ("  %-28s %6d %10s %10s"):format(p.name, p.count, fmt_ms(p.total), fmt_ms(p.max)))
  end

  table.insert(lines, "")
  table.insert(lines, ("Lua time by module (sampled every %dms)"):format(SAMPLE_MS))
  for _, m in ipairs(snap.modules) do
    table.insert(lines, ("  %-40s %10s"):format(m.name, fmt_ms(m.ms)))
  end
  return lines
end

---@return string
local function snapshot_dir()
  return vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "profile")
end

---Write a snapshot file and return its path.
---@param snap ProfileSnapshot
---@return string
function M.save(snap)
  local name = snap.created:gsub("[:]", "-") .. "-" .. snap.appname .. ".json"
  local path = vim.fs.joinpath(snapshot_dir(), name)
  require("config.state").write(path, snap)
  return path
end

---@param lines string[]
---@param name string
local function show(lines, name)
  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = buf, desc = "Close report" })
end

function M.report()
  local snap = M.snapshot()
  local path = M.save(snap)
  local lines = M.render(snap)
  table.insert(lines, "")
  table.insert(lines, "Saved: " .. path)
  show(lines, "profile://report")
end

-- =============================================================================
-- Comparison
-- =============================================================================

---Rows keyed by a stable identity, valued per hour of uptime.
---@param snap ProfileSnapshot
---@return table<string, number>
local function per_hour(snap)
  local hours = math.max(snap.uptime_s / 3600, 1 / 3600)
  local rows = {}
  for _, a in ipairs(snap.autocmds or {}) do
    rows[("autocmd %s %s ms"):format(a.event, a.group)] = a.total / hours
  end
  for _, l in ipairs(snap.lsp or {}) do
    rows[("lsp %s %s count"):format(l.client, l.method)] = l.count / hours
  end
  for _, p in ipairs(snap.procs or {}) do
    rows[("proc %s count"):format(p.name)] = p.count / hours
    rows[("proc %s ms"):format(p.name)] = p.total / hours
  end
  for _, m in ipairs(snap.modules or {}) do
    rows[("lua %s ms"):format(m.name)] = m.ms / hours
  end
  return rows
end

---Side-by-side lines for two snapshots, normalised per hour, largest change first.
---@param a ProfileSnapshot
---@param b ProfileSnapshot
---@return string[]
function M.compare_lines(a, b)
  local ra, rb = per_hour(a), per_hour(b)
  local keys = {}
  for k in pairs(ra) do
    keys[k] = true
  end
  for k in pairs(rb) do
    keys[k] = true
  end
  local list = vim.tbl_keys(keys)
  table.sort(list, function(x, y)
    local dx = math.abs((rb[x] or 0) - (ra[x] or 0))
    local dy = math.abs((rb[y] or 0) - (ra[y] or 0))
    if dx == dy then
      return x < y
    end
    return dx > dy
  end)
  local lines = {
    ("A: %s %s (%.1f min)"):format(a.appname, a.created, a.uptime_s / 60),
    ("B: %s %s (%.1f min)"):format(b.appname, b.created, b.uptime_s / 60),
    "",
    ("%-60s %12s %12s %12s"):format("per hour", "A", "B", "B - A"),
  }
  for _, k in ipairs(list) do
    local va, vb = ra[k] or 0, rb[k] or 0
    table.insert(lines, ("%-60s %12.1f %12.1f %+12.1f"):format(k, va, vb, vb - va))
  end
  return lines
end

---Snapshot files: this instance's state dir, then the configuration's committed ones.
---@return string[]
local function snapshot_files()
  local files = vim.fn.globpath(snapshot_dir(), "*.json", false, true)
  local committed = vim.fs.joinpath(vim.fn.stdpath("config") --[[@as string]], "docs", "profiles")
  vim.list_extend(files, vim.fn.globpath(committed, "*.json", false, true))
  table.sort(files)
  return files
end

function M.compare()
  local files = snapshot_files()
  if #files < 2 then
    vim.notify("ProfileCompare: need at least two snapshots", vim.log.levels.WARN)
    return
  end
  local function pick(prompt, cb)
    vim.ui.select(files, {
      prompt = prompt,
      format_item = function(f)
        return vim.fn.fnamemodify(f, ":~")
      end,
    }, cb)
  end
  pick("Snapshot A (before)", function(fa)
    if not fa then
      return
    end
    pick("Snapshot B (after)", function(fb)
      if not fb then
        return
      end
      local state = require("config.state")
      local a, b = state.read(fa, {}), state.read(fb, {})
      show(M.compare_lines(a, b), "profile://compare")
    end)
  end)
end

-- =============================================================================
-- Setup
-- =============================================================================

---Install the profiler when NVIM_PROFILE=1; a no-op otherwise.
function M.setup()
  if not M.enabled() or data then
    return
  end
  reset()
  wrap_autocmds()
  wrap_processes()
  watch_lsp()
  start_sampling()

  vim.api.nvim_create_user_command("ProfileReport", M.report, { desc = "Show and save the session profile" })
  vim.api.nvim_create_user_command("ProfileReset", reset, { desc = "Clear the session profile counters" })
  vim.api.nvim_create_user_command("ProfileCompare", M.compare, { desc = "Compare two profile snapshots" })
end

---Counters, for tests.
---@return ProfileData
function M.data()
  return data
end

M.reset = reset

return M
