---The baseline store: a private git directory per project.
---
---Layout of `<state_dir>/<hash of root>/`:
---  git/            git directory (objects only; no refs, never committed to)
---  baseline.idx    index holding the baseline B: the last agreed content
---  observed.idx    index holding O: the last disk content agentdiff processed
---  claims/         claim journal shared by every Neovim instance (see claims.lua)
---  lock/           cross-instance mutex for read-modify-write of B and O
---  root            the project root, for humans
---
---Every git process runs with a sanitized environment: inherited GIT_* variables,
---system and global git config are dropped, and the project's own repository is
---never touched. `info/attributes` turns off every content filter so blobs are
---raw file bytes.
---@class AgentdiffStoreModule
local M = {}

local util = require("agentdiff.util")

local uv = vim.uv

---@alias AgentdiffIndex "baseline"|"observed"

---@class AgentdiffChange
---@field path string   project-relative path
---@field status "M"|"D"|"A"  modified, deleted, or not in the index (added)

---@class AgentdiffStore
---@field root string
---@field dir string
---@field gitdir string
---@field opts AgentdiffOptions
local Store = {}
Store.__index = Store

---Project root: the forced root, else the nearest git toplevel, else the cwd.
---@param opts AgentdiffOptions
---@return string
function M.resolve_root(opts)
  local cwd = uv.cwd() or "."
  local root = opts.root or vim.fs.root(cwd, ".git") or cwd
  return uv.fs_realpath(root) or root
end

---@param extra table<string,string>?
---@return table<string,string>
local function base_env(extra)
  local env = {
    PATH = vim.env.PATH,
    HOME = vim.env.HOME,
    LANG = "C",
    LC_ALL = "C",
    GIT_CONFIG_NOSYSTEM = "1",
    GIT_TERMINAL_PROMPT = "0",
    GIT_OPTIONAL_LOCKS = "0",
  }
  if vim.env.TMPDIR then
    env.TMPDIR = vim.env.TMPDIR
  end
  return vim.tbl_extend("force", env, extra or {})
end

local git_flags = {
  "-c",
  "core.autocrlf=false",
  "-c",
  "core.safecrlf=false",
  "-c",
  "core.quotepath=off",
  "-c",
  "core.fsmonitor=false",
  "-c",
  "core.untrackedCache=false",
  "-c",
  "gc.auto=0",
}

---@param root string
---@param opts AgentdiffOptions
---@return AgentdiffStore
function M.open(root, opts)
  local self = setmetatable({}, Store)
  self.root = root
  self.opts = opts
  self.dir = require("agentdiff.config").state_dir() .. "/" .. vim.fn.sha256(root):sub(1, 16)
  self.gitdir = self.dir .. "/git"
  self:_init()
  return self
end

function Store:_init()
  vim.fn.mkdir(self.dir .. "/claims", "p")
  if not uv.fs_stat(self.gitdir .. "/HEAD") then
    local r = vim
      .system(
        { "git", "--git-dir=" .. self.gitdir, "init", "-q" },
        { env = base_env({ GIT_CONFIG_GLOBAL = "/dev/null" }), clear_env = true }
      )
      :wait()
    if r.code ~= 0 then
      error("agentdiff: cannot create store: " .. (r.stderr or ""))
    end
  end
  util.write_file(self.dir .. "/root", self.root .. "\n")
  vim.fn.mkdir(self.gitdir .. "/info", "p")
  util.write_file(self.gitdir .. "/info/attributes", "* -text -filter -ident -diff -merge -crlf\n")
  self:_write_excludes()
end

---Plugin defaults plus the project's own `.git/info/exclude`, if any.
function Store:_write_excludes()
  local lines = vim.deepcopy(self.opts.excludes)
  local project_exclude = util.read_file(self.root .. "/.git/info/exclude")
  if project_exclude then
    vim.list_extend(lines, vim.split(project_exclude, "\n", { plain = true }))
  end
  util.write_file(self.gitdir .. "/info/exclude", table.concat(lines, "\n") .. "\n")
end

---@param index AgentdiffIndex|string
---@return string
function Store:index_path(index)
  return self.dir .. "/" .. index .. ".idx"
end

---True once the initial snapshot exists.
---@return boolean
function Store:ready()
  return uv.fs_stat(self:index_path("baseline")) ~= nil and uv.fs_stat(self:index_path("observed")) ~= nil
end

---@param index AgentdiffIndex|string
---@param args string[]
---@return string[] cmd
---@return vim.SystemOpts opts
function Store:_cmd(index, args)
  local cmd = { "git", "--git-dir=" .. self.gitdir, "--work-tree=" .. self.root }
  vim.list_extend(cmd, git_flags)
  vim.list_extend(cmd, args)
  return cmd,
    {
      clear_env = true,
      env = base_env({ GIT_CONFIG_GLOBAL = "/dev/null", GIT_INDEX_FILE = self:index_path(index) }),
    }
end

---@param r vim.SystemCompleted
---@return boolean
local function lock_busy(r)
  return r.code ~= 0 and (r.stderr or ""):find("%.lock") ~= nil
end

---Run git synchronously against one of the store's indexes. Retries while
---another instance holds the index lock.
---@param index AgentdiffIndex|string
---@param args string[]
---@param stdin string?
---@return vim.SystemCompleted
function Store:run(index, args, stdin)
  local cmd, o = self:_cmd(index, args)
  o.stdin = stdin
  local r
  for _ = 1, 100 do
    r = vim.system(cmd, o):wait()
    if not lock_busy(r) then
      return r
    end
    uv.sleep(20)
  end
  return r
end

---Run git asynchronously; `cb` is called on the main loop.
---@param index AgentdiffIndex|string
---@param args string[]
---@param cb fun(r: vim.SystemCompleted)
function Store:run_async(index, args, cb)
  local cmd, o = self:_cmd(index, args)
  vim.system(cmd, o, vim.schedule_wrap(cb))
end

---@param out string?
---@return string[]
local function split0(out)
  local res = {}
  for item in (out or ""):gmatch("([^%z]+)") do
    res[#res + 1] = item
  end
  return res
end

---@param diff_out string?
---@param others_out string?
---@return AgentdiffChange[]
local function parse_changes(diff_out, others_out)
  local res = {}
  local parts = split0(diff_out)
  for i = 1, #parts - 1, 2 do
    local st = parts[i]:sub(1, 1)
    res[#res + 1] = { path = parts[i + 1], status = st == "D" and "D" or "M" }
  end
  for _, p in ipairs(split0(others_out)) do
    if p:sub(-1) ~= "/" then -- nested repositories show up as "dir/"
      res[#res + 1] = { path = p, status = "A" }
    end
  end
  table.sort(res, function(a, b)
    return a.path < b.path
  end)
  return res
end

local diff_args = { "diff", "--name-status", "-z", "--no-renames", "--no-ext-diff", "--ignore-submodules" }
local others_args = { "ls-files", "-o", "--exclude-standard", "-z" }

---Files whose disk content differs from the given index, including files on
---disk that the index doesn't have. Synchronous without `cb`.
---@param index AgentdiffIndex
---@param cb? fun(changes: AgentdiffChange[])
---@return AgentdiffChange[]?
function Store:changes(index, cb)
  if not cb then
    local d = self:run(index, diff_args)
    local o = self:run(index, others_args)
    return parse_changes(d.stdout, o.stdout)
  end
  local pending, d_out, o_out = 2, nil, nil
  local function done()
    pending = pending - 1
    if pending == 0 then
      cb(parse_changes(d_out, o_out))
    end
  end
  self:run_async(index, diff_args, function(r)
    d_out = r.stdout
    done()
  end)
  self:run_async(index, others_args, function(r)
    o_out = r.stdout
    done()
  end)
end

---Content of paths in an index: path → text, or false when the index lacks it.
---@param index AgentdiffIndex
---@param paths string[]
---@return table<string, string|false>
function Store:read(index, paths)
  local res = {}
  if #paths == 0 then
    return res
  end
  local input = {}
  for _, p in ipairs(paths) do
    input[#input + 1] = ":" .. p
  end
  local r = self:run(index, { "cat-file", "--batch" }, table.concat(input, "\n") .. "\n")
  local out, pos = r.stdout or "", 1
  for _, p in ipairs(paths) do
    local nl = out:find("\n", pos, true)
    if not nl then
      res[p] = false
    else
      local header = out:sub(pos, nl - 1)
      local size = header:match("^%x+ blob (%d+)$")
      if size then
        size = tonumber(size)
        res[p] = out:sub(nl + 1, nl + size)
        pos = nl + size + 2
      else
        res[p] = false
        pos = nl + 1
      end
    end
  end
  return res
end

---True when the path is ignored (.gitignore files, the store's excludes),
---whether or not an index has it.
---@param path string
---@return boolean
function Store:ignored(path)
  return self:run("baseline", { "check-ignore", "-q", "--no-index", "--", path }).code == 0
end

---Drop index entries for paths that are ignored or inside a .git directory
---(earlier versions could record files Neovim wrote there).
function Store:drop_unreviewable()
  for _, index in ipairs({ "baseline", "observed" }) do
    local r = self:run(index, { "ls-files", "-z", "-c", "-i", "--exclude-standard" })
    local bad = split0(r.stdout)
    local all = self:run(index, { "ls-files", "-z", "-c" })
    for _, p in ipairs(split0(all.stdout)) do
      if ("/" .. p):find("/%.git/") then
        bad[#bad + 1] = p
      end
    end
    if #bad > 0 then
      self:run(index, { "update-index", "--force-remove", "-z", "--stdin" }, table.concat(bad, "\0") .. "\0")
    end
  end
end

---Mode of an index entry, or nil.
---@param index AgentdiffIndex
---@param path string
---@return string?
function Store:mode(index, path)
  local r = self:run(index, { "ls-files", "-s", "--", path })
  return (r.stdout or ""):match("^(%d+) ")
end

---Set entries to given content (text) or remove them (text = nil).
---@param index AgentdiffIndex
---@param entries { path: string, text: string? }[]
function Store:write(index, entries)
  local info = {}
  for _, e in ipairs(entries) do
    if e.text == nil then
      info[#info + 1] = ("0 %s\t%s"):format(("0"):rep(40), e.path)
    else
      local h = self:run(index, { "hash-object", "-w", "--no-filters", "--stdin" }, e.text)
      local sha = vim.trim(h.stdout or "")
      local mode = self:mode(index, e.path) or self:disk_mode(e.path)
      info[#info + 1] = ("%s %s\t%s"):format(mode, sha, e.path)
    end
  end
  if #info > 0 then
    self:run(index, { "update-index", "--add", "--remove", "--index-info" }, table.concat(info, "\n") .. "\n")
  end
end

---Index mode for a file on disk.
---@param path string
---@return string
function Store:disk_mode(path)
  local st = uv.fs_stat(self.root .. "/" .. path)
  if st and bit.band(st.mode, 73) ~= 0 then -- 0o111
    return "100755"
  end
  return "100644"
end

---Take the current disk content of paths into an index (with stat data, so
---later comparisons are cheap). Paths missing on disk are removed.
---@param index AgentdiffIndex
---@param paths string[]
function Store:adopt(index, paths)
  if #paths == 0 then
    return
  end
  self:run(index, { "update-index", "--add", "--remove", "-z", "--stdin" }, table.concat(paths, "\0") .. "\0")
end

---Refresh cached stat data for entries whose content is unchanged.
---@param index AgentdiffIndex
function Store:refresh(index)
  self:run(index, { "update-index", "-q", "--refresh" })
end

---Take the initial snapshot of the whole project into both indexes, in the
---background. `cb(ok, reason)` runs on the main loop; reason is "too_many"
---(with the file count) when the project exceeds `max_files`.
---@param cb fun(ok: boolean, reason: string?, count: integer?)
function Store:snapshot(cb)
  local tmp = "snapshot-" .. vim.fn.getpid()
  local tmp_path = self:index_path(tmp)
  os.remove(tmp_path)
  self:run_async(tmp, others_args, function(r)
    if r.code ~= 0 then
      return cb(false)
    end
    local files = {}
    for _, p in ipairs(split0(r.stdout)) do
      if p:sub(-1) ~= "/" then
        files[#files + 1] = p
      end
    end
    if #files > self.opts.max_files then
      return cb(false, "too_many", #files)
    end
    local cmd, o = self:_cmd(tmp, { "update-index", "--add", "-z", "--stdin" })
    o.stdin = #files > 0 and (table.concat(files, "\0") .. "\0") or ""
    vim.system(
      cmd,
      o,
      vim.schedule_wrap(function(r2)
        if r2.code ~= 0 and #files > 0 then
          os.remove(tmp_path)
          return cb(false)
        end
        if #files == 0 then
          -- An empty project: create an empty index.
          self:run(tmp, { "read-tree", "--empty" })
        end
        -- Another instance may have finished first; keep its snapshot.
        if self:ready() then
          os.remove(tmp_path)
          return cb(true)
        end
        uv.fs_copyfile(tmp_path, self:index_path("observed") .. ".tmp")
        uv.fs_rename(self:index_path("observed") .. ".tmp", self:index_path("observed"))
        uv.fs_rename(tmp_path, self:index_path("baseline"))
        cb(true)
      end)
    )
  end)
end

---Run fn while holding the store's cross-instance lock.
---@param fn fun(): any
---@return any
function Store:locked(fn)
  local lock = self.dir .. "/lock"
  for _ = 1, 250 do
    if uv.fs_mkdir(lock, 448) then
      break
    end
    local st = uv.fs_stat(lock)
    if st and (os.time() - st.mtime.sec) > 10 then
      uv.fs_rmdir(lock) -- stale: its owner died
    else
      uv.sleep(20)
    end
  end
  local ok, res = pcall(fn)
  uv.fs_rmdir(lock)
  if not ok then
    error(res, 0)
  end
  return res
end

---Run git read-only against the project's own repository (git-guard).
---@param root string
---@param args string[]
---@return vim.SystemCompleted
---@param stdin string?
function M.project_git(root, args, stdin)
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  return vim.system(cmd, { clear_env = true, env = base_env(), stdin = stdin }):wait()
end

---Committed (HEAD) content of project paths, read-only: path → text, or false
---when HEAD doesn't have it (or the project isn't a git repository).
---@param root string
---@param paths string[]
---@return table<string, string|false>
function M.head_contents(root, paths)
  local res = {}
  if #paths == 0 then
    return res
  end
  local input = {}
  for _, p in ipairs(paths) do
    input[#input + 1] = "HEAD:" .. p
  end
  local out = M.project_git(root, { "cat-file", "--batch" }, table.concat(input, "\n") .. "\n").stdout or ""
  local pos = 1
  for _, p in ipairs(paths) do
    local nl = out:find("\n", pos, true)
    local size = nl and out:sub(pos, nl - 1):match("^%x+ blob (%d+)$")
    if nl and size then
      local n = tonumber(size)
      res[p] = out:sub(nl + 1, nl + n)
      pos = nl + n + 2
    else
      res[p] = false
      pos = nl and (nl + 1) or (#out + 1)
    end
  end
  return res
end

---Delete the store directory (it's rebuilt from disk on the next start).
---@param store AgentdiffStore
function M.destroy(store)
  vim.fn.delete(store.dir, "rf")
end

return M
