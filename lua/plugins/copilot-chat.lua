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
}, "\n")

local commit_status = {}
local commit_timeout_ms = 30000

---@param level "info"|"warn"|"error"
---@param msg string
---@param opts table
local function notify(level, msg, opts)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.notify and snacks.notify[level] then
    snacks.notify[level](msg, opts)
    return
  end

  local vim_level = level == "warn" and vim.log.levels.WARN
    or level == "error" and vim.log.levels.ERROR
    or vim.log.levels.INFO
  vim.notify(msg, vim_level, opts)
end

---@class CommitSpinner
---@field frames string[]
---@field interval integer
---@field timer uv_timer_t?
---@field timeout_timer uv_timer_t?
---@field idx integer
---@field id string
---@field msg string
local CommitSpinner = {}
CommitSpinner.__index = CommitSpinner

---@param id string
---@return CommitSpinner
function CommitSpinner.new(id)
  return setmetatable({
    frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    interval = 80,
    timer = nil,
    timeout_timer = nil,
    idx = 1,
    id = id,
    msg = "",
  }, CommitSpinner)
end

---@param msg string
---@param timeout integer
function CommitSpinner:start(msg, timeout)
  self:stop()
  self.msg = msg
  self.idx = 1
  notify("info", self.frames[1] .. " " .. msg, { id = self.id, timeout = false })
  self.timer = vim.uv.new_timer()
  self.timer:start(
    self.interval,
    self.interval,
    vim.schedule_wrap(function()
      self.idx = (self.idx % #self.frames) + 1
      notify("info", self.frames[self.idx] .. " " .. self.msg, { id = self.id, timeout = false })
    end)
  )
  self.timeout_timer = vim.uv.new_timer()
  self.timeout_timer:start(
    timeout,
    0,
    vim.schedule_wrap(function()
      self:on_timeout()
    end)
  )
end

function CommitSpinner:on_timeout() end

---@param msg string
---@param level? "info"|"warn"|"error"
function CommitSpinner:finish(msg, level)
  self:stop()
  notify(level or "info", msg, { id = self.id, timeout = 3000 })
end

function CommitSpinner:stop()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
  if self.timeout_timer then
    self.timeout_timer:stop()
    self.timeout_timer:close()
    self.timeout_timer = nil
  end
end

---@param buf integer
---@param state table
---@param msg string
---@param level? "info"|"warn"|"error"
---@return boolean
local function finish_commit_status(buf, state, msg, level)
  if commit_status[buf] ~= state or state.done then
    return false
  end
  state.done = true
  commit_status[buf] = nil
  state.spinner:finish(msg, level)
  return true
end

---@param buf integer
---@return table
local function start_commit_status(buf)
  local state = {
    done = false,
    spinner = CommitSpinner.new("copilot_commit_" .. buf),
  }
  commit_status[buf] = state
  state.spinner.on_timeout = function()
    finish_commit_status(buf, state, "Timed out: Generating commit message...", "warn")
  end
  state.spinner:start("Generating commit message...", commit_timeout_ms)
  return state
end

---@param buf integer
---@return boolean
local function commit_generation_running(buf)
  local state = commit_status[buf]
  return state ~= nil and not state.done
end

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
    if commit_generation_running(buf) then
      notify("warn", "A Copilot commit message is already being generated", {
        id = "copilot_commit_duplicate_" .. buf,
        timeout = 3000,
      })
      return
    end

    local status = start_commit_status(buf)
    local ok, err = pcall(require("CopilotChat").ask, commit_prompt, {
      headless = true, -- don't open the chat window
      resources = { "gitdiff:staged" },
      callback = function(response)
        if commit_status[buf] ~= status or status.done then
          return
        end

        local text = vim.trim(response.content or "")
        -- Strip a stray markdown fence if the model added one anyway
        text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")
        if text == "" then
          finish_commit_status(buf, status, "Copilot returned an empty commit message", "warn")
          return
        end
        if not vim.api.nvim_buf_is_valid(buf) then
          finish_commit_status(buf, status, "Commit buffer closed before message was inserted", "warn")
          return
        end
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, vim.split(text, "\n"))
        if vim.api.nvim_get_current_buf() == buf then
          vim.api.nvim_win_set_cursor(0, { 1, 0 })
        end
        finish_commit_status(buf, status, "Commit message inserted")
      end,
    })
    if not ok then
      finish_commit_status(buf, status, "Copilot commit generation failed: " .. tostring(err), "warn")
    end
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
