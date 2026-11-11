---Sidebar file explorer: the snacks.nvim explorer as a 45-column left sidebar
---on <leader>e, following the current file with git and diagnostic marks, the
---agentdiff review marks, neo-tree's hide lists, smart opening with a window
---picker, the Y copy-path chooser and n for a new .NET item. Its snacks options
---are merged into the snacks setup (plugins/snacks.lua) so directory buffers
---(`nvim .`) open with the same configuration. Persistence of its open state
---and expanded folders lives in config/workspace/explorer.lua.
---@class PluginExplorer
local M = {}

---@type (string|PackSpec)[]
M.spec = {} -- snacks.nvim is installed by plugins/snacks.lua

-- Hidden by default and revealed with H (neo-tree's hide_by_name/_by_pattern).
M.hide_list = {
  ".git",
  ".github",
  ".mypy_cache",
  ".pytest_cache",
  ".ruff_cache",
  "bin",
  "obj",
  "node_modules",
  ".next",
  ".*venv*",
  "*.egg-info",
}

-- Never shown (neo-tree's never_show): bytecode caches, and conform's
-- temporary copies (formatters without stdin) that flash in on every save.
M.never_show = { "__pycache__", ".conform.*" }

-- IDE-style yellow for folder icons; a colorscheme can supply its own by
-- defining a `FolderIcon` group (vale does), which then wins.
local FOLDER_ICON_COLOR = "#E5C07B"
local FOLDER_HL = "SnacksExplorerFolderIcon"

local function set_folder_icon_hl()
  local themed = vim.api.nvim_get_hl(0, { name = "FolderIcon", link = false }).fg ~= nil
  vim.api.nvim_set_hl(0, FOLDER_HL, themed and { link = "FolderIcon" } or { fg = FOLDER_ICON_COLOR })
end

---Excludes for the current H state.
---@param reveal boolean show the hide list
---@return string[]
function M.excludes(reveal)
  local list = vim.deepcopy(M.never_show)
  if not reveal then
    vim.list_extend(list, M.hide_list)
  end
  return list
end

---The agentdiff integration when the installed agentdiff has it.
---@return table?
local function agentdiff()
  local ok, mod = pcall(require, "agentdiff.integrations.snacks_explorer")
  return ok and mod or nil
end

---snacks' file format (with agentdiff's marks when available), folder icons
---recoloured with the theme's folder colour.
---@param item table
---@param picker table
---@return table[]
function M.format(item, picker)
  local ad = agentdiff()
  local ret = ad and ad.format(item, picker) or require("snacks.picker.format").file(item, picker)
  if item.dir then
    for _, chunk in ipairs(ret) do
      if chunk.virtual and type(chunk[1]) == "string" then
        chunk[2] = FOLDER_HL -- the first virtual chunk is the icon
        break
      end
    end
  end
  return ret
end

---Editing windows in the current tab: normal windows showing file buffers
---(not the explorer, notifications, terminals, quickfix or other panels).
---@return integer
function M.editing_windows()
  local n = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if
      vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[buf].buftype == ""
      and not vim.bo[buf].filetype:match("^snacks_")
    then
      n = n + 1
    end
  end
  return n
end

---Yank the node's path in a chosen form (old-config "advanced yank" on Y).
---@param path string absolute path of the node
function M.copy_path(path)
  local filename = vim.fs.basename(path)
  local modify = vim.fn.fnamemodify
  local results = {
    filename,
    modify(filename, ":r"),
    path,
    modify(path, ":."),
    modify(path, ":~"),
    modify(filename, ":e"),
  }
  vim.ui.select({
    "1. Filename: " .. results[1],
    "2. Filename without extension: " .. results[2],
    "3. Absolute path: " .. results[3],
    "4. Path relative to CWD: " .. results[4],
    "5. Path relative to HOME: " .. results[5],
    "6. Extension of the filename: " .. results[6],
  }, { prompt = "Choose to copy to clipboard:" }, function(choice)
    if choice then
      local result = results[tonumber(choice:sub(1, 1))]
      vim.fn.setreg("+", result)
      vim.fn.setreg("*", result)
      vim.fn.setreg('"', result)
      vim.notify("Copied: " .. result)
    end
  end)
end

---Explorer actions (snacks picker action functions).
M.actions = {
  ---Directories expand/collapse; files open directly with at most one
  ---editing window, otherwise through the window picker.
  explorer_smart_open = function(picker, item)
    if not item then
      return
    end
    if item.dir or M.editing_windows() <= 1 then
      return picker:action("confirm")
    end
    picker:action({ "pick_win", "jump" })
  end,
  explorer_copy_path = function(_, item)
    if item and item.file then
      M.copy_path(item.file)
    end
  end,
  ---Create a C# item via easy-dotnet in the directory under the cursor.
  explorer_dotnet_item = function(_, item)
    if not item then
      return
    end
    local ok, dotnet = pcall(require, "easy-dotnet")
    if not ok then
      vim.notify("easy-dotnet is not available", vim.log.levels.WARN)
      return
    end
    dotnet.create_item(item.dir and item.file or vim.fs.dirname(item.file))
  end,
  ---Show or hide the hide-list entries.
  explorer_toggle_hide_list = function(picker)
    M.revealed = not M.revealed
    picker.opts.exclude = M.excludes(M.revealed)
    require("snacks.explorer.actions").update(picker, { refresh = true })
  end,
}

---@type boolean whether H currently shows the hide list
M.revealed = false

---Options merged into snacks' picker.sources.explorer.
---@return table
function M.snacks_source()
  return {
    hidden = true, -- dotfiles stay visible (neo-tree hide_dotfiles = false)
    ignored = true, -- so do git-ignored files (hide_gitignored = false)
    exclude = M.excludes(false),
    follow_file = true,
    git_status = true,
    diagnostics = true,
    watch = true,
    layout = { preset = "sidebar", preview = false, layout = { width = 45, min_width = 45 } },
    format = M.format,
    actions = M.actions,
    -- Persist the open state (config/workspace/explorer.lua).
    on_show = function()
      require("config.workspace.explorer").on_visibility(true)
    end,
    on_close = function()
      require("config.workspace.explorer").on_visibility(false)
    end,
    win = {
      list = {
        keys = {
          ["<CR>"] = "explorer_smart_open",
          ["w"] = "explorer_smart_open",
          ["l"] = "explorer_smart_open",
          ["Y"] = "explorer_copy_path",
          ["n"] = "explorer_dotnet_item",
          ["H"] = "explorer_toggle_hide_list",
          -- The global maps win: tmux-aware navigation, save, terminal.
          ["<c-j>"] = false,
          ["<c-k>"] = false,
          ["<c-s>"] = false,
          ["<c-t>"] = false,
        },
      },
    },
  }
end

---@return table[] open explorer pickers in every tab
function M.open_explorers()
  return Snacks.picker.get({ source = "explorer", tab = false })
end

---Re-run git status for the open explorers and redraw them (files changed
---outside Neovim, including inside collapsed folders). A no-op when no
---explorer is open, so nothing runs git while the user just edits.
function M.refresh_git()
  if not (rawget(_G, "Snacks") and package.loaded["snacks.picker"]) then
    return
  end
  for _, picker in ipairs(M.open_explorers()) do
    pcall(function()
      require("snacks.explorer.git").refresh(picker:cwd())
      require("snacks.explorer.actions").update(picker, { refresh = true, target = false })
    end)
  end
end

---Toggle the explorer in the current tab.
function M.toggle()
  local open = Snacks.picker.get({ source = "explorer" })
  if #open > 0 then
    for _, picker in ipairs(open) do
      picker:close()
    end
  else
    Snacks.explorer()
  end
end

---Whether a window belongs to a snacks picker layout (explorer included).
---@param win integer
---@return boolean
local function is_snacks_win(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^snacks_") ~= nil
end

function M.setup()
  vim.keymap.set("n", "<leader>e", M.toggle, { desc = "File explorer" })

  -- Closing the last editing window quits even with the explorer open
  -- (neo-tree's close_if_last_window): once a window has closed and the tab
  -- holds nothing but the explorer, close the tab, or quit when it is the
  -- last one. Acting after the close (not on QuitPre) leaves :qa and :restart
  -- alone, so the explorer is still open when its state is saved on exit.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup("plugins.explorer.quit", { clear = true }),
    callback = function(ev)
      local closed = tonumber(ev.match)
      if not closed or not vim.api.nvim_win_is_valid(closed) or is_snacks_win(closed) then
        return
      end
      if vim.api.nvim_win_get_config(closed).relative ~= "" then
        return
      end
      local tab = vim.api.nvim_win_get_tabpage(closed)
      vim.schedule(function()
        if not vim.api.nvim_tabpage_is_valid(tab) or vim.v.exiting ~= vim.NIL then
          return
        end
        local explorer = false
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          if vim.api.nvim_win_get_config(win).relative == "" then
            if not is_snacks_win(win) then
              return -- an editing window is left
            end
            explorer = true
          end
        end
        if not explorer then
          return
        end
        if #vim.api.nvim_list_tabpages() > 1 then
          vim.api.nvim_set_current_tabpage(tab)
          pcall(vim.cmd.tabclose)
        else
          pcall(vim.cmd, "confirm qall")
        end
      end)
    end,
  })

  set_folder_icon_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("plugins.explorer.folder_icon", { clear = true }),
    callback = set_folder_icon_hl,
  })

  -- Outside edits: on focus/terminal return, and when agentdiff reports new
  -- agent changes. Never on BufEnter or idle.
  local refresh = vim.api.nvim_create_augroup("plugins.explorer.refresh", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave" }, { group = refresh, callback = M.refresh_git })
  vim.api.nvim_create_autocmd("User", { group = refresh, pattern = "AgentdiffChanged", callback = M.refresh_git })

  local ad = agentdiff()
  if ad then
    ad.setup()
  end
end

return M
