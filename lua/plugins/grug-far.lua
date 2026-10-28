---grug-far.nvim: project-wide find & replace with live ripgrep preview.
---@class PluginGrugFar
local M = {}

function M.setup()
  require("grug-far").setup({
    hooks = {
      -- Replaces write files directly: claim each one so agentdiff counts it
      -- as the user's edit, not the agent's.
      on_before_edit_file = function(on_finish, file)
        require("plugins.agentdiff").grug_far_before_edit(on_finish, file)
      end,
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>sr", "<cmd>GrugFar<cr>", { desc = "Find & replace (project)" })
  map("v", "<leader>sr", function()
    require("grug-far").with_visual_selection()
  end, { desc = "Find & replace selection" })
  map("n", "<leader>sw", function()
    require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
  end, { desc = "Replace word under cursor" })
end

return M
