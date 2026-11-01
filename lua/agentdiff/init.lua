---agentdiff: review file changes made by AI agents running outside Neovim.
---
---Entry point. Owns `setup()`, the `:Agentdiff` command, the optional keymaps
---and the public API. The plugin depends only on Neovim and the `git`
---executable and registers no keymaps unless the host passes `opts.keymaps`.
---@class Agentdiff
local M = {}

local actions = require("agentdiff.actions")
local buffers = require("agentdiff.buffers")
local claims = require("agentdiff.claims")
local config = require("agentdiff.config")
local detect = require("agentdiff.detect")
local render = require("agentdiff.render")
local review = require("agentdiff.review")
local session = require("agentdiff.session")
local store_mod = require("agentdiff.store")
local util = require("agentdiff.util")

local global_group = vim.api.nvim_create_augroup("agentdiff_global", { clear = true })

-- On/off state ------------------------------------------------------------------
--
-- One global file, `<state_dir>/enabled`: "on <epoch>" or "off <epoch>". The
-- epoch changes every time review is turned on; each store remembers the epoch
-- it was built in, and a store from before a disabled period is rebuilt from
-- the disk, so nothing that changed while review was off shows as pending.

---@return string
local function state_file()
  return config.state_dir() .. "/enabled"
end

---@return boolean enabled
---@return string? epoch
local function read_state()
  local t = util.read_file(state_file())
  if not t then
    return true, nil
  end
  local word, epoch = t:match("^(%a+)%s*(%d*)")
  return word ~= "off", (epoch ~= "" and epoch or nil)
end

---@param on boolean
local function write_state(on)
  local _, epoch = read_state()
  if on then
    epoch = tostring(util.now_ms())
  end
  util.write_file(state_file(), ("%s %s\n"):format(on and "on" or "off", epoch or ""))
end

---True when review is on (persisted across restarts).
---@return boolean
function M.enabled()
  return (read_state())
end

---Start reviewing the project of the current directory (or `opts.root`).
function M.start()
  M.stop()
  local enabled, epoch = read_state()
  if not enabled then
    return
  end
  local opts = config.options
  local root = store_mod.resolve_root(opts)
  -- Never treat the home directory or / as a project unless asked to: that
  -- would snapshot everything under it.
  local home = vim.uv.fs_realpath(vim.env.HOME or "") or vim.env.HOME
  if not opts.root and (root == home or root == "/") then
    return
  end
  local ok, store = pcall(store_mod.open, root, opts)
  if not ok then
    util.notify(tostring(store), vim.log.levels.ERROR)
    return
  end
  if epoch then
    local stored = vim.trim(util.read_file(store.dir .. "/epoch") or "")
    if stored ~= epoch then
      -- Built before review was last turned off: start over from the disk.
      store_mod.destroy(store)
      store = store_mod.open(root, opts)
      util.write_file(store.dir .. "/epoch", epoch .. "\n")
    end
  end
  local s = session.new(root, store, opts)
  buffers.attach(s)
  detect.start(s)
  if s.ready then
    store:drop_unreviewable()
    vim.schedule(function()
      if session.get() == s then
        review.refresh(s)
        detect.poll()
      end
    end)
  else
    store:snapshot(function(done, reason, count)
      if session.get() ~= s then
        return
      end
      if not done then
        if reason == "too_many" then
          util.notify(
            ("agentdiff: %s has %d files (max_files = %d); not reviewing it"):format(
              root,
              count,
              opts.max_files
            ),
            vim.log.levels.WARN
          )
          M.stop()
          store_mod.destroy(store)
        else
          util.notify("agentdiff: initial snapshot failed", vim.log.levels.ERROR)
        end
        return
      end
      s.ready = true
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local rel = vim.api.nvim_buf_is_loaded(b) and session.rel_of_buf(s, b)
        if rel then
          s.synced[b] = util.read_file(session.abs(s, rel)) or false
        end
      end
      review.refresh(s)
    end)
  end
end

---Stop reviewing (pending changes stay in the store).
function M.stop()
  local s = session.get()
  detect.stop()
  buffers.detach()
  if s then
    pcall(vim.api.nvim_del_augroup_by_id, s.group)
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        vim.api.nvim_buf_clear_namespace(b, render.ns, 0, -1)
        vim.api.nvim_buf_clear_namespace(b, render.ns_hint, 0, -1)
      end
    end
    require("agentdiff.panel").close()
  end
  session.current = nil
end

---Turn review on (persisted).
function M.enable()
  write_state(true)
  M.start()
  util.notify("agentdiff: on")
end

---Turn review off (persisted): nothing is detected or shown until enabled.
function M.disable()
  write_state(false)
  M.stop()
  util.notify("agentdiff: off")
end

---Toggle review on/off (persisted).
function M.toggle()
  if M.enabled() then
    M.disable()
  else
    M.enable()
  end
end

-- Navigation ------------------------------------------------------------------

M.next = actions.next
M.prev = actions.prev
M.next_file = actions.next_file
M.prev_file = actions.prev_file
M.open = actions.open

-- Keep / undo -----------------------------------------------------------------

---Keep pending changes. `opts.scope`: "hunk" (default, the change under the
---cursor, or the lines of `opts.range`), "file" or "all".
M.keep = actions.keep

---Undo pending changes; same options as keep().
M.undo = actions.undo

function M.keep_file()
  actions.keep({ scope = "file" })
end

function M.undo_file()
  actions.undo({ scope = "file" })
end

---@param opts { force: boolean? }?
function M.keep_all(opts)
  actions.keep({ scope = "all", force = opts and opts.force })
end

---@param opts { force: boolean? }?
function M.undo_all(opts)
  actions.undo({ scope = "all", force = opts and opts.force })
end

---Resolve a conflicted file: "agent", "mine" or "compare" (asks when nil).
M.resolve = actions.resolve

-- Views -----------------------------------------------------------------------

function M.panel()
  require("agentdiff.panel").toggle()
end

function M.toggle_view()
  require("agentdiff.sidebyside").toggle()
end

function M.toggle_overlay()
  local s = session.get()
  if not s then
    return
  end
  s.overlay_hidden = not s.overlay_hidden
  render.all(s)
end

-- Claims, status, events ------------------------------------------------------

---Mark the next disk changes of these paths (absolute or project-relative) as
---the user's, e.g. right before or after a file explorer renames them. A path
---that is an existing directory claims every file under it.
---@param paths string[]
function M.claim(paths)
  local s = session.get()
  if not s then
    return
  end
  local rels = {}
  local function add(abs)
    local rel = util.relative(s.root, vim.fs.normalize(abs))
    if rel then
      rels[#rels + 1] = rel
    end
  end
  for _, p in ipairs(paths) do
    local abs = vim.fs.normalize(p:sub(1, 1) == "/" and p or session.abs(s, p)):gsub("/$", "")
    add(abs)
    local st = vim.uv.fs_stat(abs)
    if st and st.type == "directory" then
      for name, kind in vim.fs.dir(abs, { depth = math.huge }) do
        if kind == "file" then
          add(abs .. "/" .. name)
        end
      end
    end
  end
  claims.add(s.store, rels)
end

---Statusline summary: "3 files · 7 changes", or "" when nothing is pending.
---@return string
function M.status()
  local s = session.get()
  if not s or #s.order == 0 then
    return ""
  end
  local nf, nc = #s.order, render.count(s)
  return ("%d %s · %d %s"):format(nf, nf == 1 and "file" or "files", nc, nc == 1 and "change" or "changes")
end

---@type { sig: string?, root: string?, files: table<string, true>, dirs: table<string, true> }
local status_cache = { files = {}, dirs = {} }

---Review status of a path, for file trees: "file" when the file has pending
---changes (created and deleted files included), "dir" when a directory
---contains such a file at any depth, nil otherwise. Cheap: answered from sets
---rebuilt only when pending changes change.
---@param path string absolute, or relative to the project root
---@return "file"|"dir"|nil
function M.path_status(path)
  local s = session.get()
  if not s or #s.order == 0 then
    return nil
  end
  if status_cache.sig ~= s.signature or status_cache.root ~= s.root then
    local files, dirs = {}, {}
    for _, p in ipairs(s.order) do
      files[p] = true
      local d = vim.fs.dirname(p)
      while d and d ~= "." and d ~= "" and not dirs[d] do
        dirs[d] = true
        d = vim.fs.dirname(d)
      end
    end
    dirs[""] = true -- the project root contains them all
    status_cache = { sig = s.signature, root = s.root, files = files, dirs = dirs }
  end
  local abs = path:sub(1, 1) == "/" and vim.fs.normalize(path) or session.abs(s, path)
  abs = abs:gsub("/$", "")
  local rel = abs == s.root and "" or util.relative(s.root, abs)
  if not rel then
    return nil
  end
  if status_cache.files[rel] then
    return "file"
  elseif status_cache.dirs[rel] then
    return "dir"
  end
  return nil
end

---Pending files in navigation order (read-only copies).
---@return AgentdiffFile[]
function M.files()
  local s = session.get()
  if not s then
    return {}
  end
  local out = {}
  for _, p in ipairs(s.order) do
    out[#out + 1] = vim.deepcopy(s.files[p])
  end
  return out
end

-- Command ---------------------------------------------------------------------

---@type table<string, fun(range: integer[]?)>
M.subcommands = {
  next = function()
    M.next()
  end,
  prev = function()
    M.prev()
  end,
  next_file = function()
    M.next_file()
  end,
  prev_file = function()
    M.prev_file()
  end,
  keep = function(range)
    M.keep({ range = range })
  end,
  undo = function(range)
    M.undo({ range = range })
  end,
  keep_file = function()
    M.keep_file()
  end,
  undo_file = function()
    M.undo_file()
  end,
  keep_all = function()
    M.keep_all()
  end,
  undo_all = function()
    M.undo_all()
  end,
  panel = function()
    M.panel()
  end,
  view = function()
    M.toggle_view()
  end,
  overlay = function()
    M.toggle_overlay()
  end,
  resolve = function()
    M.resolve()
  end,
  refresh = function()
    detect.now("poll")
  end,
  enable = function()
    M.enable()
  end,
  disable = function()
    M.disable()
  end,
  toggle = function()
    M.toggle()
  end,
  status = function()
    if not M.enabled() then
      return util.notify("agentdiff: off")
    end
    local st = M.status()
    util.notify(st ~= "" and st or "agentdiff: nothing pending")
  end,
}

local function create_command()
  vim.api.nvim_create_user_command("Agentdiff", function(cmd)
    local name = cmd.fargs[1] or "panel"
    local fn = M.subcommands[name]
    if not fn then
      return util.notify("agentdiff: unknown subcommand '" .. name .. "'", vim.log.levels.ERROR)
    end
    fn(cmd.range > 0 and { cmd.line1, cmd.line2 } or nil)
  end, {
    nargs = "?",
    range = true,
    desc = "agentdiff: review agent changes",
    complete = function(lead)
      local names = vim.tbl_keys(M.subcommands)
      table.sort(names)
      return vim.tbl_filter(function(n)
        return n:find(lead, 1, true) == 1
      end, names)
    end,
  })
end

-- Keymaps ---------------------------------------------------------------------

local normal_actions = {
  next = { M.next, "Next agent change" },
  prev = { M.prev, "Previous agent change" },
  next_file = { M.next_file, "Next changed file" },
  prev_file = { M.prev_file, "Previous changed file" },
  keep = {
    function()
      M.keep()
    end,
    "Keep change",
  },
  undo = {
    function()
      M.undo()
    end,
    "Undo change",
  },
  keep_file = { M.keep_file, "Keep file" },
  undo_file = { M.undo_file, "Undo file" },
  keep_all = {
    function()
      M.keep_all()
    end,
    "Keep all",
  },
  undo_all = {
    function()
      M.undo_all()
    end,
    "Undo all",
  },
  panel = { M.panel, "Changed files panel" },
  view = { M.toggle_view, "Toggle side-by-side" },
  overlay = { M.toggle_overlay, "Hide/show overlay" },
  resolve = {
    function()
      M.resolve()
    end,
    "Resolve conflict",
  },
}

---@return integer[]
local function visual_range()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  return { math.min(a, b), math.max(a, b) }
end

---@param keys AgentdiffKeymaps
local function create_keymaps(keys)
  for name, lhs in pairs(keys) do
    local a = normal_actions[name]
    if a then
      vim.keymap.set("n", lhs, a[1], { desc = a[2] })
    end
  end
  if keys.keep then
    vim.keymap.set("x", keys.keep, function()
      M.keep({ range = visual_range() })
    end, { desc = "Keep selected lines" })
  end
  if keys.undo then
    vim.keymap.set("x", keys.undo, function()
      M.undo({ range = visual_range() })
    end, { desc = "Undo selected lines" })
  end
end

-- Setup -----------------------------------------------------------------------

---@param opts AgentdiffOptions|table|nil
function M.setup(opts)
  local o = config.resolve(opts)
  render.define_highlights()
  vim.api.nvim_clear_autocmds({ group = global_group })
  vim.api.nvim_create_autocmd("ColorScheme", { group = global_group, callback = render.define_highlights })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = global_group,
    pattern = "global",
    callback = function()
      local s = session.get()
      if s and store_mod.resolve_root(config.options) ~= s.root then
        M.start()
      end
    end,
  })
  create_command()
  if type(o.keymaps) == "table" then
    create_keymaps(o.keymaps)
  end
  if o.auto_start then
    if vim.v.vim_did_enter == 1 then
      M.start()
    else
      vim.api.nvim_create_autocmd("VimEnter", { group = global_group, once = true, callback = M.start })
    end
  end
end

-- Test hooks --------------------------------------------------------------------

M._test = {
  ---Stop everything and forget the session (between tests).
  reset = function()
    M.stop()
    vim.api.nvim_clear_autocmds({ group = global_group })
    pcall(vim.api.nvim_del_user_command, "Agentdiff")
  end,
  ---Block until the initial snapshot exists.
  wait_ready = function(ms)
    return vim.wait(ms or 5000, function()
      local s = session.get()
      return s ~= nil and s.ready and s.refreshed
    end, 10)
  end,
  ---Detect synchronously. settle = false confirms unclaimed changes at once.
  poll_now = function(opts)
    detect.now("poll", opts or { settle = false })
  end,
  ---Run debounced buffer updates now.
  flush = function()
    local s = session.get()
    if s then
      buffers.flush(s)
    end
  end,
  session = session.get,
}

return M
