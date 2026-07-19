---auto-session: per-cwd sessions, saved automatically on exit and restored
---automatically when Neovim starts with no file arguments. Bufferline pins ride
---along via vim.g.BufferlinePinnedBuffers ('globals' in sessionoptions) plus the
---deferred re-sync below, ported from the old dotfiles config. Breakpoint
---persistence is separate (config/workspace.lua) and fires on BufReadPost.
---Neo-tree can't live inside the session file (its windows are closed before
---:mksession), so its expanded folders + open flag persist in a side JSON.
---@class PluginAutoSession
local M = {}

---Persisted neo-tree explorer state for one project.
---@class NeotreeSessionState
---@field nodes string[] ids (paths) of expanded directories
---@field is_open boolean whether a neo-tree window was open at exit

---@return string
local function neotree_state_path()
  local key = (vim.fn.getcwd():gsub("[/\\:]", "%%"))
  return vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "neotree", key .. ".json")
end

---Snapshot expanded directories and open/closed state. Runs on VimLeavePre
---BEFORE auto-session's own handler, while the tree window still exists.
---Always writes, so a closed tree is remembered as closed.
local function save_neotree_state()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return
  end

  ---@type NeotreeSessionState
  local snapshot = { nodes = {}, is_open = false }

  local state = manager.get_state("filesystem")
  if state and state.tree then
    for id, node in pairs(state.tree.nodes.by_id) do
      if node.type == "directory" and node:is_expanded() then
        table.insert(snapshot.nodes, id)
      end
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
      snapshot.is_open = true
      break
    end
  end

  local path = neotree_state_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(snapshot) }, path)
end

---Reopen neo-tree with its previous expansion state after a session restore.
---Deferred so the restored window layout settles first (old-config timing).
local function restore_neotree_state()
  vim.defer_fn(function()
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(neotree_state_path()), "\n"))
    end)
    if not ok or type(data) ~= "table" then
      return
    end

    local mok, manager = pcall(require, "neo-tree.sources.manager")
    if not mok then
      return
    end

    if type(data.nodes) == "table" and #data.nodes > 0 then
      manager.get_state("filesystem").force_open_folders = data.nodes
    end
    if data.is_open then
      -- "show" opens the sidebar without stealing focus from the restored buffer
      require("neo-tree.command").execute({ action = "show" })
    end
  end, 200)
end

---Re-sync bufferline's pinned group from vim.g.BufferlinePinnedBuffers.
---bufferline's own SessionLoadPost handler runs once; this deferred pass covers
---buffers it missed because they were not materialized yet when it fired.
local function load_pinned_buffers()
  vim.defer_fn(function()
    local pinned_str = vim.g.BufferlinePinnedBuffers
    if not pinned_str or pinned_str == "" then
      return
    end

    local ok_groups, groups = pcall(require, "bufferline.groups")
    local ok_state, state = pcall(require, "bufferline.state")
    if not (ok_groups and ok_state and state.components) then
      return
    end

    for _, path in ipairs(vim.split(pinned_str, ",")) do
      local buf_id = path ~= "" and vim.fn.bufnr(path) or -1
      if buf_id ~= -1 then
        for _, component in ipairs(state.components) do
          if component.id == buf_id then
            if not groups._is_pinned(component) then
              groups.add_element("pinned", component)
            end
            break
          end
        end
      end
    end

    local ok_ui, ui = pcall(require, "bufferline.ui")
    if ok_ui then
      ui.refresh()
    end
  end, 500)
end

function M.setup()
  -- Registered before auto-session.setup() so this VimLeavePre fires first —
  -- auto-session's handler closes unsupported windows (neo-tree included)
  -- before saving, which would make is_open always false.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("config.auto-session.neotree", { clear = true }),
    callback = save_neotree_state,
  })

  require("auto-session").setup({
    auto_save = true,
    auto_restore = true, -- only fires on argument-less startup with a saved session
    show_auto_restore_notif = false,
    -- Keep plugin windows out of saved sessions
    bypass_save_filetypes = { "neo-tree", "trouble", "OverseerList" },
    post_restore_cmds = { load_pinned_buffers, restore_neotree_state },
    session_lens = { load_on_setup = true, previewer = false },
  })

  local map = vim.keymap.set
  map("n", "<leader>qs", "<cmd>AutoSession save<cr>", { desc = "Save session" })
  map("n", "<leader>qr", "<cmd>AutoSession restore<cr>", { desc = "Restore session" })
  map("n", "<leader>ql", "<cmd>AutoSession search<cr>", { desc = "Search sessions" })
  map("n", "<leader>qd", "<cmd>AutoSession delete<cr>", { desc = "Delete session" })
  map("n", "<leader>qt", "<cmd>AutoSession toggle<cr>", { desc = "Toggle session auto-save" })
end

return M
