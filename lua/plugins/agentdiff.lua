---agentdiff: VS Code agent-mode review of changes AI agents make from another
---tmux pane. The plugin lives in its own repository (~/Github/agentdiff.nvim,
---or $AGENTDIFF_DIR) and is loaded from there; this module is the only place
---that knows about both the plugin and the rest of this configuration (keymaps,
---which-key, statusline, neo-tree, and the tools whose writes must count as the
---user's).
---@class PluginAgentdiff
local M = {}

---Where the plugin's repository lives.
M.dir = vim.env.AGENTDIFF_DIR or vim.fn.expand("~/Github/agentdiff.nvim")

---Put the plugin on the runtimepath (and build its help tags once).
---@return boolean ok
local function load()
  if not vim.uv.fs_stat(M.dir .. "/lua/agentdiff/init.lua") then
    vim.notify("agentdiff: plugin not found at " .. M.dir, vim.log.levels.WARN)
    return false
  end
  vim.opt.rtp:prepend(M.dir)
  if not vim.uv.fs_stat(M.dir .. "/doc/tags") and vim.uv.fs_stat(M.dir .. "/doc") then
    pcall(vim.cmd.helptags, vim.fn.fnameescape(M.dir .. "/doc"))
  end
  return true
end

---Paths touched by a list of oil actions (oil:// URLs of the files adapter).
---@param actions table[]?
---@return string[]
local function oil_paths(actions)
  local paths = {}
  for _, a in ipairs(actions or {}) do
    -- (not ipairs over the three fields: a move has no `url`, and ipairs
    -- would stop at that nil)
    for _, key in ipairs({ "url", "src_url", "dest_url" }) do
      local url = a[key]
      local p = type(url) == "string" and url:match("^oil://(.*)$")
      if p then
        paths[#paths + 1] = p
      end
    end
  end
  return paths
end

---grug-far hook: claim each file right before grug-far rewrites it, so
---project-wide replaces never show as agent changes.
---@param on_finish fun(status?: string, err?: string)
---@param file { path: string }
function M.grug_far_before_edit(on_finish, file)
  pcall(function()
    require("agentdiff").claim({ vim.fn.fnamemodify(file.path, ":p") })
  end)
  on_finish("success")
end

---neo-tree component: the review icon on files with pending agent changes
---and on collapsed directories that contain one.
---@param node table neo-tree node
---@return table
function M.neotree_component(_, node, _)
  local ok, st = pcall(require("agentdiff").path_status, node.path)
  if not ok or not st then
    return {}
  end
  if st == "dir" and node.is_expanded and node:is_expanded() then
    return {}
  end
  return { text = "󰚩 ", highlight = st == "file" and "AgentdiffTreeFile" or "AgentdiffTreeDir" }
end

---neo-tree's default renderers with the `agentdiff` component placed just
---before `git_status` (copied at setup, so the rest follows neo-tree updates).
---@return table
function M.neotree_renderers()
  local renderers = vim.deepcopy(require("neo-tree.defaults").renderers)
  for _, kind in ipairs({ "file", "directory" }) do
    for _, part in ipairs(renderers[kind] or {}) do
      if part[1] == "container" then
        local at = #part.content + 1
        for i, c in ipairs(part.content) do
          if c[1] == "git_status" then
            at = i
            break
          end
        end
        table.insert(part.content, at, { "agentdiff", zindex = 20, align = "right" })
      end
    end
  end
  return renderers
end

function M.setup()
  if not load() then
    return
  end
  local agentdiff = require("agentdiff")
  agentdiff.setup({
    keymaps = {
      next = "]a",
      prev = "[a",
      next_file = "]A",
      prev_file = "[A",
      keep = "<leader>rk",
      undo = "<leader>ru",
      keep_file = "<leader>rK",
      undo_file = "<leader>rU",
      keep_all = "<leader>ra",
      undo_all = "<leader>rA",
      panel = "<leader>rr",
      view = "<leader>rv",
      overlay = "<leader>rh",
      resolve = "<leader>rc",
    },
  })

  -- On/off, persisted across restarts (ui/toggles group).
  vim.keymap.set("n", "<leader>uR", agentdiff.toggle, { desc = "Toggle agent review" })

  -- Statusline (and neo-tree marks): refreshed whenever pending changes change.
  require("plugins.lualine").register({
    icon = "󰚩",
    render = agentdiff.status,
  })
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("agentdiff_statusline", { clear = true }),
    pattern = "AgentdiffChanged",
    callback = function()
      pcall(function()
        require("lualine").refresh()
      end)
      if package.loaded["neo-tree"] then
        pcall(function()
          require("neo-tree.sources.manager").refresh("filesystem")
        end)
      end
    end,
  })

  -- oil renames/moves/deletes write to disk directly: claim them before and
  -- after (directories claim every file under them).
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("agentdiff_oil", { clear = true }),
    pattern = { "OilActionsPre", "OilActionsPost" },
    callback = function(ev)
      agentdiff.claim(oil_paths(ev.data and ev.data.actions))
    end,
  })
end

return M
