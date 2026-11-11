---Explorer state per project: expanded folders and whether the sidebar
---explorer (snacks.nvim) was open. Explorer windows are closed before the
---session is saved, so this lives in a side file
---(stdpath("state")/explorer/<cwd-key>.json), written when the state changes:
---a folder is expanded or collapsed, or the explorer is shown or closed.
---Files written by the previous neo-tree-based configuration
---(stdpath("state")/neotree/<cwd-key>.json, same shape) are read once.
---@class WorkspaceExplorer
local M = {}

local state = require("config.state")

---Persisted explorer state for one project.
---@class ExplorerSessionState
---@field nodes string[] absolute paths of expanded directories under the project
---@field is_open boolean whether the explorer was open

---Whether the explorer has been shown or restored in this session. Until then
---the stored expansion list is kept rather than replaced by an empty tree.
M.materialized = false

---@type table<string, string> last written JSON per path, to skip identical writes
local last_written = {}

---@param cwd? string
---@return ExplorerSessionState? data
---@return boolean exists
local function read(cwd)
  local data, exists = state.read(state.path("explorer", cwd), nil)
  if not exists then
    data, exists = state.read(state.path("neotree", cwd), nil)
  end
  if exists then
    assert(
      type(data) == "table" and type(data.nodes or {}) == "table",
      "Invalid explorer snapshot: " .. state.path("explorer", cwd)
    )
  end
  return data, exists
end

---snacks' explorer tree, when snacks is set up.
---@return table?
local function tree()
  if not rawget(_G, "Snacks") then
    return nil
  end
  local ok, t = pcall(require, "snacks.explorer.tree")
  return ok and t or nil
end

---Open explorer pickers in every tab.
---@return table[]
local function explorers()
  local snacks = rawget(_G, "Snacks")
  if not (snacks and package.loaded["snacks.picker"]) then
    return {}
  end
  return snacks.picker.get({ source = "explorer", tab = false })
end

---Close an explorer, after its running finder (if any) is done: closing
---mid-scan makes snacks index the closed picker's matcher. Bounded wait.
---@param picker table
local function close(picker)
  vim.wait(1000, function()
    return not picker.finder:running()
  end, 10)
  picker:close()
end

---@param path string
---@param cwd string
---@return boolean
local function under(path, cwd)
  return path:sub(1, #cwd + 1) == cwd .. "/"
end

---Expanded directories under `cwd` in the explorer tree.
---@param cwd string
---@return string[]
local function expanded(cwd)
  local nodes = {}
  local t = tree()
  for path, node in pairs(t and t.nodes or {}) do
    if node.dir and node.open and under(path, cwd) then
      nodes[#nodes + 1] = path
    end
  end
  table.sort(nodes)
  return nodes
end

---Snapshot expanded directories and the open state for `cwd`.
---@param cwd string
local function save(cwd)
  local prev = read(cwd)
  ---@type ExplorerSessionState
  local snapshot = {
    nodes = M.materialized and expanded(cwd) or (prev and prev.nodes or {}),
    is_open = #explorers() > 0,
  }
  local path = state.path("explorer", cwd)
  local json = vim.json.encode(snapshot)
  if last_written[path] == json and vim.uv.fs_stat(path) then
    return
  end
  state.write(path, snapshot)
  last_written[path] = json
end

---Debounced saves plus the guard for deferred restores.
M.saver = state.saver({ label = "Workspace session", save = save })

---Explorer shown or closed (picker hooks from plugins/explorer.lua).
---@param shown boolean
function M.on_visibility(shown)
  if shown then
    M.materialized = true
  end
  M.saver.touch()
end

-- Filetypes of the explorer's layout windows (snacks sidebar layout).
local layout_filetypes = {
  snacks_layout_box = true,
  snacks_picker_list = true,
  snacks_picker_input = true,
  snacks_picker_preview = true,
}

---Close explorer windows left in a session written by `:restart` (which
---saves with the explorer still open: the session recreates its split as an
---empty window with the layout's filetype). Only split windows whose buffer
---has an explorer layout filetype and belongs to no live picker are touched;
---floats (notifications, live pickers) never are.
---@return boolean found whether any such window existed
function M.scrub()
  local owned = {}
  for _, picker in ipairs(explorers()) do
    for _, win in pairs(picker.layout and picker.layout.wins or {}) do
      if win.buf then
        owned[win.buf] = true
      end
    end
    local root = picker.layout and picker.layout.root
    if root and root.buf then
      owned[root.buf] = true
    end
  end
  local found = false
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local splits = vim.tbl_filter(function(w)
      return vim.api.nvim_win_get_config(w).relative == ""
    end, vim.api.nvim_tabpage_list_wins(tab))
    for _, win in ipairs(splits) do
      local buf = vim.api.nvim_win_get_buf(win)
      if layout_filetypes[vim.bo[buf].filetype] and not owned[buf] then
        found = true
        if #splits > 1 then
          pcall(vim.api.nvim_win_close, win, true)
        else
          vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        end
        if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end
  end
  return found
end

---Reopen the explorer with its stored expansion state. A managed restore waits
---for the explorer to show, so the workspace switch only completes once it has.
---@param managed? boolean
function M.restore(managed)
  local data, exists = read()
  if not exists or not data then
    return
  end
  local cwd = vim.fn.getcwd()
  for _, picker in ipairs(explorers()) do
    close(picker)
  end
  local t = tree()
  if t then
    for path, node in pairs(t.nodes) do
      if under(path, cwd) then
        node.open = false
      end
    end
    for _, dir in ipairs(data.nodes or {}) do
      if under(dir, cwd) and vim.fn.isdirectory(dir) == 1 then
        t:open(dir)
      end
    end
  end
  M.materialized = true
  if not data.is_open then
    return
  end
  M.scrub()
  -- Shown like neo-tree's "show": the cursor stays in the editing window.
  if not managed then
    Snacks.explorer({ enter = false })
    return
  end
  local shown = false
  local token = M.saver.token()
  Snacks.explorer({
    enter = false,
    on_show = function()
      shown = true
      M.on_visibility(true)
    end,
  })
  local finished = vim.wait(10000, function()
    return shown or M.saver.token() ~= token or vim.fn.getcwd() ~= cwd
  end, 10)
  assert(
    finished and shown and M.saver.token() == token and vim.fn.getcwd() == cwd,
    "Explorer restoration did not complete for " .. cwd
  )
end

---Schedule a save after every tree method that expands or collapses folders,
---so expansions from keys, follow-file and the API are all persisted.
local function watch_tree()
  local t = tree()
  if not t or t.__workspace_watched then
    return
  end
  t.__workspace_watched = true
  for _, name in ipairs({ "open", "close", "toggle", "close_all" }) do
    local orig = t[name]
    if type(orig) == "function" then
      t[name] = function(...)
        local result = orig(...)
        M.saver.touch()
        return result
      end
    end
  end
end

---Register the save triggers. Must run before auto-session.setup(): this
---VimLeavePre has to fire first, while the explorer is still open, and it
---raises the exiting flag so auto-session's window teardown for :mksession
---cannot record the explorer as closed.
function M.setup()
  watch_tree()

  local group = vim.api.nvim_create_augroup("config.workspace.explorer", { clear = true })

  -- Any session load, auto-session's or the one :restart sources (after
  -- which no post-restore hook runs): drop leftover explorer windows, then
  -- re-apply the saved open state and folders. Managed restores (worktree
  -- switches) pause the saver and restore synchronously themselves.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      if M.saver.active() then
        M.scrub()
        M.saver.defer(function()
          M.restore()
        end, 200)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.saver.exit,
  })
end

return M
