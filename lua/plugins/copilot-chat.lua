---CopilotChat.nvim: chat + commit message generation.
---In gitcommit buffers, <leader>gm asks Copilot for a conventional commit
---title + description from the staged diff and inserts it at the top.
---@class PluginCopilotChat
local M = {}

local commit_prompt = table.concat({
  "Write a commit message for the staged change following the Conventional Commits",
  "convention: a single title line `type(scope): summary` at most 72 characters,",
  "one blank line, then a body describing what changed and why, wrapped at 72",
  "characters. Answer with ONLY the raw commit message — no code fences, no",
  "surrounding quotes, no commentary.",
  "",
  "#gitdiff:staged",
}, "\n")

function M.setup()
  require("CopilotChat").setup({
    window = { layout = "vertical", width = 0.4 },
  })

  local map = vim.keymap.set
  map({ "n", "v" }, "<leader>aa", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot chat" })
  map({ "n", "v" }, "<leader>ae", "<cmd>CopilotChatExplain<cr>", { desc = "Explain code" })
  map({ "n", "v" }, "<leader>ar", "<cmd>CopilotChatReview<cr>", { desc = "Review code" })

  -- Commit-message generation inside gitcommit buffers
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.copilotchat.commit", { clear = true }),
    pattern = "gitcommit",
    callback = function(ev)
      vim.keymap.set("n", "<leader>gm", function()
        vim.notify("Generating commit message…")
        require("CopilotChat").ask(commit_prompt, {
          headless = true, -- don't open the chat window
          callback = function(response)
            local text = vim.trim(response.content or "")
            -- Strip a stray markdown fence if the model added one anyway
            text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")
            if text == "" then
              vim.notify("Copilot returned an empty message", vim.log.levels.WARN)
              return
            end
            vim.api.nvim_buf_set_lines(ev.buf, 0, 0, false, vim.split(text, "\n"))
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
          end,
        })
      end, { buffer = ev.buf, desc = "Generate commit message (Copilot)" })
    end,
  })
end

return M
