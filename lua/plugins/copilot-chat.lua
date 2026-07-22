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
    model = "gpt-5-mini",
    window = { layout = "vertical", width = 0.4 },
    mappings = {
      -- Default insert-mode close is <C-c>; disable it so leaving insert
      -- mode with <C-c> can't dismiss the chat. q still closes from normal.
      close = { normal = "q", insert = "" },
      show_diffs = { full_diff = true },
    },
  })

  local map = vim.keymap.set
  map({ "n", "v" }, "<leader>aa", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot chat" })
  map({ "n", "v" }, "<leader>ae", "<cmd>CopilotChatExplain<cr>", { desc = "Explain code" })
  map({ "n", "v" }, "<leader>ar", "<cmd>CopilotChatReview<cr>", { desc = "Review code" })

  ---Headless generation: never opens the chat window, inserts into the buffer.
  ---@param buf integer gitcommit buffer
  local function generate_commit_message(buf)
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
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, vim.split(text, "\n"))
        if vim.api.nvim_get_current_buf() == buf then
          vim.api.nvim_win_set_cursor(0, { 1, 0 })
        end
      end,
    })
  end

  -- Commit-message generation inside gitcommit buffers: automatic on open for
  -- a fresh (empty) message, <leader>gm to (re)generate manually.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.copilotchat.commit", { clear = true }),
    pattern = "gitcommit",
    callback = function(ev)
      vim.keymap.set("n", "<leader>gm", function()
        generate_commit_message(ev.buf)
      end, { buffer = ev.buf, desc = "Generate commit message (Copilot)" })

      -- Auto-generate once, and only when there's no message yet (first line
      -- empty — an amend/reword arrives with its message already present).
      local first = (vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1] or ""):gsub("%s+", "")
      if first == "" and not vim.b[ev.buf].copilot_commit_generated then
        vim.b[ev.buf].copilot_commit_generated = true
        generate_commit_message(ev.buf)
      end
    end,
  })
end

return M
