---Conflict state: which git operation is in progress, its progress, which
---side of a conflict is YOURS (the work of the branch you are on) and which is
---INCOMING (what the operation brings in), and the conflicted files.
---
---Detection reads only the repository's operation-state files (fs_stat, no
---process): MERGE_HEAD, rebase-merge/ or rebase-apply/, CHERRY_PICK_HEAD,
---REVERT_HEAD, and AUTO_MERGE alone for a conflicting `git stash pop/apply`.
---Only when one exists does refresh() run git, once, for names and files.
---
---Git's markers call the sections "ours" (<<<<<<<) and "theirs" (>>>>>>>).
---Which one is yours depends on the operation: in a rebase git swaps them
---(ours = the branch being rebased onto, theirs = your commit being replayed).
---Every other module asks section(role) / git_side(role) and never uses git's
---words.
---@class ConflictsState
local M = {}

---@alias ConflictRole "yours"|"incoming"
---@alias ConflictOp "merge"|"rebase"|"cherry-pick"|"revert"|"stash"

---@class ConflictSide
---@field name string branch name, "stash", or short commit hash
---@field detail string? e.g. 'your commit a1b2c3 "fix login"' or "rebasing onto"

---@class ConflictInfo
---@field op ConflictOp
---@field root string repository top level
---@field git_dir string
---@field step integer? current step (rebase)
---@field total integer? number of steps (rebase)
---@field yours ConflictSide
---@field incoming ConflictSide
---@field files string[] absolute paths of unmerged files

---@type ConflictInfo?
M.current = nil

---Listeners notified after every refresh (inline marks, statusline, center).
---@type fun(info: ConflictInfo?)[]
local listeners = {}

---@param fn fun(info: ConflictInfo?)
function M.on_change(fn)
  listeners[#listeners + 1] = fn
end

---@param path string
---@return boolean
local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

---@param path string
---@return string?
local function read_line(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local line = fd:read("*l")
  fd:close()
  return line and vim.trim(line) or nil
end

---The repository's top level and git dir for `dir`, from the filesystem only
---(a linked worktree's `.git` is a file pointing at its git dir).
---@param dir? string
---@return string? root
---@return string? git_dir
function M.git_dir(dir)
  local root = vim.fs.root(dir or vim.fn.getcwd(), ".git")
  if not root then
    return nil, nil
  end
  local dotgit = root .. "/.git"
  local stat = vim.uv.fs_stat(dotgit)
  if stat and stat.type == "file" then
    local pointer = read_line(dotgit) or ""
    local target = pointer:match("^gitdir:%s*(.+)$")
    if not target then
      return root, nil
    end
    if not target:match("^/") then
      target = vim.fs.normalize(root .. "/" .. target)
    end
    return root, target
  end
  return root, dotgit
end

---The operation in progress in `git_dir`, from its state files only.
---@param git_dir string
---@return ConflictOp?
function M.detect(git_dir)
  if exists(git_dir .. "/rebase-merge") or exists(git_dir .. "/rebase-apply") then
    return "rebase"
  elseif exists(git_dir .. "/MERGE_HEAD") then
    return "merge"
  elseif exists(git_dir .. "/CHERRY_PICK_HEAD") then
    return "cherry-pick"
  elseif exists(git_dir .. "/REVERT_HEAD") then
    return "revert"
  elseif exists(git_dir .. "/AUTO_MERGE") then
    return "stash" -- confirmed by unmerged files in refresh()
  end
  return nil
end

---Run git in `root`; trimmed stdout, or nil on failure.
---@param root string
---@param ... string
---@return string?
local function git(root, ...)
  local result = vim.system({ "git", "-C", root, ... }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout)
end

---Short hash and subject of a commit.
---@param root string
---@param rev string
---@return string hash
---@return string subject
local function commit(root, rev)
  local out = git(root, "log", "-1", "--format=%h%x00%s", rev) or ""
  local hash, subject = out:match("^(.-)%z(.*)$")
  return hash or rev:sub(1, 7), subject or ""
end

---A branch name for a commit, or nil.
---@param root string
---@param rev string
---@return string?
local function branch_of(root, rev)
  local name = git(root, "name-rev", "--name-only", "--no-undefined", "--refs=refs/heads/*", rev)
  if not name or name == "" then
    return nil
  end
  return (name:gsub("[~^].*$", ""))
end

---@param root string
---@return string
local function current_branch(root)
  return git(root, "symbolic-ref", "--short", "-q", "HEAD") or "detached HEAD"
end

---Names, subjects and progress for the operation.
---@param op ConflictOp
---@param root string
---@param git_dir string
---@return table
local function describe(op, root, git_dir)
  if op == "merge" then
    local merged = read_line(git_dir .. "/MERGE_HEAD") or "MERGE_HEAD"
    local hash = commit(root, merged)
    return {
      yours = { name = current_branch(root), detail = "your branch" },
      incoming = { name = branch_of(root, merged) or hash, detail = "being merged in" },
    }
  elseif op == "rebase" then
    local dir = exists(git_dir .. "/rebase-merge") and git_dir .. "/rebase-merge" or git_dir .. "/rebase-apply"
    local head = (read_line(dir .. "/head-name") or ""):gsub("^refs/heads/", "")
    local onto = read_line(dir .. "/onto") or "HEAD"
    local stopped = read_line(dir .. "/stopped-sha") or read_line(git_dir .. "/REBASE_HEAD")
    local step = tonumber(read_line(dir .. "/msgnum") or read_line(dir .. "/next") or "")
    local total = tonumber(read_line(dir .. "/end") or read_line(dir .. "/last") or "")
    local detail = "your commit"
    if stopped then
      local hash, subject = commit(root, stopped)
      detail = ('your commit %s "%s"'):format(hash, subject)
    end
    return {
      yours = { name = head ~= "" and head or "detached HEAD", detail = detail },
      incoming = { name = branch_of(root, onto) or select(1, commit(root, onto)), detail = "rebasing onto" },
      step = step,
      total = total,
    }
  elseif op == "cherry-pick" or op == "revert" then
    local file = op == "cherry-pick" and "/CHERRY_PICK_HEAD" or "/REVERT_HEAD"
    local hash, subject = commit(root, read_line(git_dir .. file) or "HEAD")
    return {
      yours = { name = current_branch(root), detail = "your branch" },
      incoming = {
        name = hash,
        detail = (op == "revert" and 'reverting "%s"' or 'picked commit "%s"'):format(subject),
      },
    }
  end
  return {
    yours = { name = current_branch(root), detail = "your working tree" },
    incoming = { name = "stash", detail = "your stashed changes" },
  }
end

---Re-read the operation state for `dir` (default cwd) and notify listeners.
---Runs git only when an operation-state file exists.
---@param dir? string
---@return ConflictInfo?
function M.refresh(dir)
  local root, git_dir = M.git_dir(dir)
  local op = git_dir and M.detect(git_dir) or nil
  local info = nil ---@type ConflictInfo?
  if op and root and git_dir then
    local files = {}
    for _, rel in ipairs(vim.split(git(root, "diff", "--name-only", "--diff-filter=U") or "", "\n", { trimempty = true })) do
      files[#files + 1] = root .. "/" .. rel
    end
    -- AUTO_MERGE outlives a resolved stash conflict: no unmerged file, no op.
    if op ~= "stash" or #files > 0 then
      info = vim.tbl_extend("force", describe(op, root, git_dir), {
        op = op,
        root = root,
        git_dir = git_dir,
        files = files,
      })
    end
  end
  M.current = info
  for _, fn in ipairs(listeners) do
    pcall(fn, info)
  end
  return info
end

---Marker section ("ours"|"theirs") holding `role`'s lines in the current op.
---@param role ConflictRole
---@param op? ConflictOp defaults to the current operation
---@return "ours"|"theirs"
function M.section(role, op)
  op = op or (M.current and M.current.op) or "merge"
  local swapped = op == "rebase"
  if role == "yours" then
    return swapped and "theirs" or "ours"
  end
  return swapped and "ours" or "theirs"
end

---Git's name for `role`'s side in the current operation (diffview's
---conflict_choose takes git's names).
M.git_side = M.section

---@param role ConflictRole
---@return string e.g. "YOURS · feature (your commit a1b2c3 "fix login")"
function M.label(role)
  local info = M.current
  local side = info and info[role]
  local title = role == "yours" and "YOURS" or "INCOMING"
  if not side then
    return title
  end
  return ("%s · %s%s"):format(title, side.name, side.detail and (" (" .. side.detail .. ")") or "")
end

---@param role ConflictRole
---@return string branch or commit name only
function M.name(role)
  local side = M.current and M.current[role]
  return side and side.name or role
end

---One line saying what is happening, e.g. "REBASING feature onto main, commit 2 of 5".
---@return string
function M.summary()
  local info = M.current
  if not info then
    return "No merge, rebase, cherry-pick, revert or stash conflict in progress"
  end
  if info.op == "merge" then
    return ("MERGING %s into %s"):format(info.incoming.name, info.yours.name)
  elseif info.op == "rebase" then
    local progress = info.step and info.total and (", commit %d of %d"):format(info.step, info.total) or ""
    return ("REBASING %s onto %s%s"):format(info.yours.name, info.incoming.name, progress)
  elseif info.op == "cherry-pick" then
    return ("CHERRY-PICKING %s onto %s"):format(info.incoming.name, info.yours.name)
  elseif info.op == "revert" then
    return ("REVERTING %s on %s"):format(info.incoming.name, info.yours.name)
  end
  return ("APPLYING the stash on %s"):format(info.yours.name)
end

---Statusline text: "⚔ REBASE 2/5 · 3 files", or "" without an operation.
---@return string
function M.status()
  local info = M.current
  if not info then
    return ""
  end
  local progress = (info.step and info.total) and (" %d/%d"):format(info.step, info.total) or ""
  local n = #info.files
  return ("⚔ %s%s · %d file%s"):format(info.op:upper(), progress, n, n == 1 and "" or "s")
end

---Whether `path` is one of the conflicted files.
---@param path string
---@return boolean
function M.is_conflicted(path)
  local info = M.current
  return info ~= nil and path ~= "" and vim.list_contains(info.files, vim.fs.normalize(path))
end

---Run git for the current repository (used by the next-step commands).
---@param ... string
---@return vim.SystemCompleted
function M.run(...)
  local root = M.current and M.current.root or select(1, M.git_dir()) or vim.fn.getcwd()
  return vim.system({ "git", "-C", root, ... }, { text = true }):wait()
end

return M
