---The running review session for one project root.
---
---Holds the store and every piece of in-memory state the other modules share.
---There is at most one session per Neovim instance; `DirChanged` re-roots it.
---@class AgentdiffSessionModule
local M = {}

---Per-file review state, recomputed by review.lua.
---@class AgentdiffFile
---@field path string            project-relative path
---@field status "modified"|"created"|"deleted"|"binary"|"conflicted"
---@field whole boolean           reviewed as a whole file (binary or oversized)
---@field hunks AgentdiffHunk[]   a = baseline (display) side, b = current side
---@field base string[]           baseline lines in display space
---@field cur string[]            current lines (buffer or disk) in display space
---@field added integer
---@field removed integer
---@field buf integer?            loaded buffer the hunks were computed from

---@class AgentdiffUndoRecord
---@field seq_before integer      undo sequence before agentdiff's undo
---@field seq_after integer       undo sequence right after it
---@field before string[]         buffer lines (display space) before the undo

---@class AgentdiffSession
---@field root string
---@field store AgentdiffStore
---@field opts AgentdiffOptions
---@field ready boolean                         initial snapshot available
---@field refreshed boolean                     review state computed at least once
---@field group integer                         autocmd group
---@field files table<string, AgentdiffFile>    pending files by path
---@field order string[]                        pending paths in navigation order
---@field conflicts table<string, boolean>      paths with an unresolved conflict
---@field writing table<string, boolean>        paths Neovim is writing right now
---@field synced table<integer, string|false>   per buffer: disk text the buffer last matched
---@field base_override table<integer, string[]> per buffer: base for the user delta (display space)
---@field journal table<integer, AgentdiffUndoRecord[]>
---@field overlay_hidden boolean
---@field views table<integer, integer>         file buffer → baseline scratch buffer (side-by-side)
---@field signature string                      last fired summary (for AgentdiffChanged)
---@field ignored table<string, boolean>?       reviewable() cache: path → ignored
---@field project_gitdir string|false|nil       the project's own git dir (false: not a repo)

---@type AgentdiffSession?
M.current = nil

---@param root string
---@param store AgentdiffStore
---@param opts AgentdiffOptions
---@return AgentdiffSession
function M.new(root, store, opts)
  ---@type AgentdiffSession
  local s = {
    root = root,
    store = store,
    opts = opts,
    ready = store:ready(),
    refreshed = false,
    group = vim.api.nvim_create_augroup("agentdiff", { clear = true }),
    files = {},
    order = {},
    conflicts = {},
    writing = {},
    synced = {},
    base_override = {},
    journal = {},
    overlay_hidden = false,
    views = {},
    signature = "",
    project_gitdir = nil,
  }
  M.current = s
  return s
end

---@return AgentdiffSession?
function M.get()
  return M.current
end

---Absolute path of a project-relative path.
---@param s AgentdiffSession
---@param rel string
---@return string
function M.abs(s, rel)
  return s.root .. "/" .. rel
end

---True when a project-relative path takes part in review: not inside a .git
---directory and not ignored. Cached per session.
---@param s AgentdiffSession
---@param rel string
---@return boolean
function M.reviewable(s, rel)
  if ("/" .. rel .. "/"):find("/%.git/") then
    return false
  end
  s.ignored = s.ignored or {}
  local v = s.ignored[rel]
  if v == nil then
    v = s.store:ignored(rel)
    s.ignored[rel] = v
  end
  return not v
end

---Project-relative path of a buffer, or nil when the buffer isn't a project
---file that takes part in review.
---@param s AgentdiffSession
---@param buf integer
---@return string?
function M.rel_of_buf(s, buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  local rel = require("agentdiff.util").relative(s.root, vim.uv.fs_realpath(name) or name)
  if rel and not M.reviewable(s, rel) then
    return nil
  end
  return rel
end

---Loaded buffer showing a project-relative path, if any.
---@param s AgentdiffSession
---@param rel string
---@return integer?
function M.buf_of_rel(s, rel)
  local abs = M.abs(s, rel)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and (name == abs or vim.uv.fs_realpath(name) == abs) then
        return b
      end
    end
  end
  return nil
end

return M
