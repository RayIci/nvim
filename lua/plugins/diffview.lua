---diffview.nvim: side-by-side diffs and git history browsing.
---@class PluginDiffview
local M = {}

---@type (string|PackSpec)[]
M.spec = {
  "sindrets/diffview.nvim",
}

---In the 3-way merge view, the same <leader>gC keys keep YOURS / INCOMING by
---role (diffview's conflict_choose takes git's names, which swap in a rebase).
---@param role "yours"|"incoming"|"none"
---@return function
local function choose(role)
  return function()
    local side = role == "none" and "none" or require("config.conflicts.state").git_side(role)
    require("diffview.actions").conflict_choose(side)()
  end
end

function M.setup()
  require("diffview").setup({
    view = {
      -- yours and incoming side by side on top, the file (result) below
      merge_tool = { layout = "diff3_mixed", disable_diagnostics = true, winbar_info = false },
    },
    hooks = {
      ---Role labels instead of OURS/THEIRS on the merge view's windows.
      diff_buf_win_enter = function(_, winid, ctx)
        if not (ctx.layout_name or ""):match("^diff3") then
          return
        end
        local st = require("config.conflicts.state")
        local label = {
          a = st.label(st.section("yours") == "ours" and "yours" or "incoming"),
          b = "RESULT (the file — <leader>gCo / gCt / gC0 here or above)",
          c = st.label(st.section("yours") == "theirs" and "yours" or "incoming"),
        }
        if label[ctx.symbol] then
          vim.wo[winid].winbar = " " .. label[ctx.symbol]
        end
      end,
    },
    keymaps = {
      view = {
        { "n", "<leader>gCo", choose("yours"), { desc = "Keep yours" } },
        { "n", "<leader>gCt", choose("incoming"), { desc = "Take incoming" } },
        { "n", "<leader>gC0", choose("none"), { desc = "Keep neither" } },
      },
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>gdd", "<cmd>DiffviewOpen<cr>", { desc = "Open" })
  map("n", "<leader>gdo", "<cmd>DiffviewOpen<cr>", { desc = "Open" })
  map("n", "<leader>gdc", "<cmd>DiffviewClose<cr>", { desc = "Close" })
  map("n", "<leader>gdr", "<cmd>DiffviewRefresh<cr>", { desc = "Refresh" })
  map("n", "<leader>gdt", "<cmd>DiffviewToggleFiles<cr>", { desc = "Toggle file panel" })
  map("n", "<leader>gdf", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
  map("n", "<leader>gdp", "<cmd>DiffviewFileHistory<cr>", { desc = "File history (project)" })
end

return M
