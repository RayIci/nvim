---agentdiff: VS Code agent-mode review of changes AI agents make from another
---tmux pane. The plugin is installed by vim.pack; this module is the only place
---that knows about both the plugin and the rest of this configuration (keymaps,
---which-key, statusline, and the plugin's neo-tree, oil and grug-far
---integration modules).
---@class PluginAgentdiff
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "RayIci/agentdiff.nvim",
}

---One of agentdiff's integration modules, or nil when the installed version
---doesn't have it yet (that integration is then simply skipped).
---@param name "neotree"|"oil"|"grug_far"
---@return table?
function M.integration(name)
  local ok, mod = pcall(require, "agentdiff.integrations." .. name)
  return ok and mod or nil
end

---grug-far hook: claim each file right before grug-far rewrites it.
---@param on_finish fun(status?: string, err?: string)
---@param file { path: string }
function M.grug_far_before_edit(on_finish, file)
  local gf = M.integration("grug_far")
  if gf then
    return gf.on_before_edit_file(on_finish, file)
  end
  on_finish("success")
end

---Keymap actions the installed agentdiff knows (older versions reject unknown
---ones, so newer actions are added only once the plugin has them).
---@param name string
---@return boolean
local function has_action(name)
  local ok, cfg = pcall(require, "agentdiff.config")
  return ok and vim.tbl_contains(cfg.keymap_fields or {}, name)
end

function M.setup()
  local agentdiff = require("agentdiff")
  local keymaps = {
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
  }
  -- the changed-files panel as a tree / as a list (each toggles its own view
  -- and switches from the other one)
  if has_action("panel_tree") then
    keymaps.panel_tree = "<leader>rp"
    keymaps.panel_list = "<leader>rP"
  end
  -- Panel width: 30% of the editor, but never narrower than 45 columns
  -- (a function size needs a recent agentdiff; older ones get plain 30%).
  local cfg_ok, cfg = pcall(require, "agentdiff.config")
  local panel_size = (cfg_ok and cfg.valid_size)
      and function(ctx)
        return math.max(45, math.floor(ctx.total * 0.3))
      end
    or "30%"

  agentdiff.setup({
    panel = { size = panel_size },
    -- Review only what agent CLIs report through their hooks (installed once
    -- with `:Agentdiff hooks install`); generators, file explorers and other
    -- programs writing into the project are never shown as agent changes.
    attribution = "hooks",
    keymaps = keymaps,
  })

  -- On/off, persisted across restarts (ui/toggles group).
  vim.keymap.set("n", "<leader>uR", agentdiff.toggle, { desc = "Toggle agent review" })

  -- Statusline: refreshed whenever pending changes change.
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
    end,
  })

  -- neo-tree marks refresh, and oil's file operations count as mine.
  local nt = M.integration("neotree")
  if nt then
    nt.setup()
  end
  local oil = M.integration("oil")
  if oil then
    oil.setup()
  end
end

return M
