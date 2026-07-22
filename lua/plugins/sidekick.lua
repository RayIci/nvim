---@class PluginSidekick
local M = {}

local has_tmux = vim.fn.executable("tmux") == 1
local commit_generation = {}
local prefs = require("config.prefs")
local commit_prefs_key = "sidekick_commit_generation"

local commit_tools = {
  copilot = {
    name = "copilot",
    label = "GitHub Copilot CLI",
    default_model = "auto",
    models = {
      { id = "auto", label = "Auto (Copilot chooses)" },
      { id = "gpt-5-mini", label = "GPT-5 Mini (cheap/fast)" },
      { id = "gpt-5.4-mini", label = "GPT-5.4 Mini" },
      { id = "gpt-5.3-codex", label = "GPT-5.3 Codex" },
    },
  },
  claude = {
    name = "claude",
    label = "Claude Code CLI",
    default_model = "default",
    models = {
      { id = "default", label = "Default (Claude chooses)" },
      { id = "haiku", label = "Haiku" },
      { id = "sonnet", label = "Sonnet" },
      { id = "opus", label = "Opus" },
    },
  },
}

local sidekick_commit_prompt = table.concat({
  "Inspect the staged changes in this repository with `git diff --staged` and",
  "write a commit message following the Conventional Commits convention:",
  "a single title line `type(scope): summary` at most 72 characters, one blank",
  "line, then a body describing what changed and why, wrapped at 72 characters.",
  "Answer with ONLY the raw commit message. Do not add code fences, quotes, or",
  "commentary.",
}, "\n")

local headless_commit_prompt = table.concat({
  "Write a commit message for the staged change below following the Conventional Commits convention.",
  "Use a single title line `type(scope): summary` at most 72 characters, one blank line,",
  "then a body describing what changed and why, wrapped at 72 characters.",
  "Answer with ONLY the raw commit message. Do not add code fences, quotes, or commentary.",
  "",
  "Staged diff:",
  "",
}, "\n")

---@param msg string
---@param level? integer
---@param opts? table
local function notify(msg, level, opts)
  opts = vim.tbl_extend("force", { title = "Sidekick" }, opts or {})
  vim.notify(msg, level or vim.log.levels.INFO, opts)
end

---@param tool string?
---@return table?
local function commit_tool_config(tool)
  if type(tool) ~= "string" then
    return nil
  end
  return commit_tools[tool]
end

---@param tool string
---@param model string?
---@return table?
local function commit_model_config(tool, model)
  local tool_config = commit_tool_config(tool)
  if not tool_config or type(model) ~= "string" then
    return nil
  end

  for _, item in ipairs(tool_config.models) do
    if item.id == model then
      return item
    end
  end
end

---@return { tool: string, models: table<string, string> }
local function commit_preferences()
  local defaults = {
    tool = "copilot",
    models = {
      copilot = commit_tools.copilot.default_model,
      claude = commit_tools.claude.default_model,
    },
  }

  local stored = prefs.get(commit_prefs_key, defaults)
  if type(stored) ~= "table" then
    stored = {}
  end
  if not commit_tool_config(stored.tool) then
    stored.tool = defaults.tool
  end
  if type(stored.models) ~= "table" then
    stored.models = {}
  end

  for tool, config in pairs(commit_tools) do
    if not commit_model_config(tool, stored.models[tool]) then
      stored.models[tool] = config.default_model
    end
  end

  return stored
end

---@param tool string
---@param model? string
local function save_commit_preferences(tool, model)
  local stored = commit_preferences()
  local config = assert(commit_tool_config(tool))
  stored.tool = tool
  stored.models[tool] = commit_model_config(tool, model) and model or config.default_model
  prefs.set(commit_prefs_key, stored)
end

---@param tool string
---@return string?
local function commit_model(tool)
  local stored = commit_preferences()
  local config = commit_tool_config(tool)
  if not config then
    return nil
  end
  return stored.models[tool] or config.default_model
end

---@param tool string
---@param model string?
---@return string
local function commit_model_label(tool, model)
  if model then
    return ("%s / model: %s"):format(tool, model)
  end
  return ("%s / model: CLI default"):format(tool)
end

---@class CommitSpinner
---@field id string
---@field msg string
---@field frames string[]
---@field idx integer
---@field timer uv_timer_t?

---@param buf integer
---@param label string
---@return CommitSpinner
local function start_commit_spinner(buf, label)
  ---@type CommitSpinner
  local spinner = {
    id = "sidekick_commit_" .. buf,
    msg = "Generating commit message with " .. label .. "...",
    frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    idx = 1,
    timer = vim.uv.new_timer(),
  }

  notify(spinner.frames[spinner.idx] .. " " .. spinner.msg, vim.log.levels.INFO, { id = spinner.id, timeout = false })
  spinner.timer:start(
    80,
    80,
    vim.schedule_wrap(function()
      spinner.idx = (spinner.idx % #spinner.frames) + 1
      notify(spinner.frames[spinner.idx] .. " " .. spinner.msg, vim.log.levels.INFO, {
        id = spinner.id,
        timeout = false,
      })
    end)
  )

  return spinner
end

---@param spinner CommitSpinner?
---@param msg string
---@param level? integer
local function finish_commit_spinner(spinner, msg, level)
  if spinner and spinner.timer then
    spinner.timer:stop()
    spinner.timer:close()
    spinner.timer = nil
  end
  notify(msg, level, { id = spinner and spinner.id or nil, timeout = 3000 })
end

---@param response string
---@return string
local function clean_commit_message(response)
  local text = vim.trim(response)
  text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")
  text = vim.trim(text)
  if text:sub(1, 1) == '"' and text:sub(-1) == '"' then
    text = text:sub(2, -2)
  end
  return vim.trim(text)
end

---@param buf integer
---@param text string
---@return boolean
local function apply_commit_message(buf, text)
  local lines = vim.split(text, "\n", { plain = true })
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  if #lines == 0 then
    return false
  end

  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local comment_start ---@type integer?
  for i, line in ipairs(current) do
    if line:match("^#") then
      comment_start = i
      break
    end
  end

  local replace_end = comment_start and (comment_start - 1) or #current
  if comment_start and lines[#lines] ~= "" then
    lines[#lines + 1] = ""
  end

  vim.api.nvim_buf_set_lines(buf, 0, replace_end, false, lines)
  if vim.api.nvim_get_current_buf() == buf then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end
  return true
end

---@param tool string
---@param prompt string
---@param model string?
---@return string[]?
local function headless_command(tool, prompt, model)
  if tool == "copilot" then
    local cmd = { "copilot", "--no-color", "--output-format", "text" }
    if model and model ~= "auto" then
      vim.list_extend(cmd, { "--model", model })
    end
    vim.list_extend(cmd, { "--prompt", prompt })
    return cmd
  elseif tool == "claude" then
    local cmd = { "claude" }
    if model and model ~= "default" then
      vim.list_extend(cmd, { "--model", model })
    end
    vim.list_extend(cmd, { "--print", prompt })
    return cmd
  end
end

---@param buf integer
---@param tool string
---@param model? string
local function generate_commit_message(buf, tool, model)
  if commit_generation[buf] then
    notify("A commit message is already being generated", vim.log.levels.WARN)
    return
  end

  model = model or commit_model(tool)
  local label = commit_model_label(tool, model)
  local command = headless_command(tool, "", model)
  if not command or vim.fn.executable(command[1]) ~= 1 then
    notify(("Headless commit generation is not configured for `%s`; sending the Sidekick prompt instead"):format(tool), vim.log.levels.WARN)
    require("sidekick.cli").send({ prompt = "commit" })
    return
  end

  commit_generation[buf] = {
    spinner = start_commit_spinner(buf, label),
  }

  vim.system({ "git", "diff", "--staged", "--no-ext-diff" }, { text = true }, function(diff_result)
    vim.schedule(function()
      local state = commit_generation[buf]
      if not vim.api.nvim_buf_is_valid(buf) then
        finish_commit_spinner(state and state.spinner, "Commit buffer closed before generation finished", vim.log.levels.WARN)
        commit_generation[buf] = nil
        return
      end

      if diff_result.code ~= 0 then
        commit_generation[buf] = nil
        finish_commit_spinner(state and state.spinner, "Failed to read staged diff: " .. vim.trim(diff_result.stderr or ""), vim.log.levels.WARN)
        return
      end

      local diff = vim.trim(diff_result.stdout or "")
      if diff == "" then
        commit_generation[buf] = nil
        finish_commit_spinner(state and state.spinner, "No staged changes found for commit message generation", vim.log.levels.WARN)
        return
      end

      local prompt = headless_commit_prompt .. diff
      local ai_command = assert(headless_command(tool, prompt, model))
      vim.system(ai_command, { text = true }, function(ai_result)
        vim.schedule(function()
          local current = commit_generation[buf]
          commit_generation[buf] = nil
          if not vim.api.nvim_buf_is_valid(buf) then
            finish_commit_spinner(current and current.spinner, "Commit buffer closed before message was inserted", vim.log.levels.WARN)
            return
          end

          if ai_result.code ~= 0 then
            finish_commit_spinner(
              current and current.spinner,
              ("Commit generation failed: %s"):format(vim.trim(ai_result.stderr or ai_result.stdout or "")),
              vim.log.levels.WARN
            )
            return
          end

          if apply_commit_message(buf, clean_commit_message(ai_result.stdout or "")) then
            finish_commit_spinner(current and current.spinner, "Commit message inserted")
          else
            finish_commit_spinner(current and current.spinner, "Commit generator returned an empty message", vim.log.levels.WARN)
          end
        end)
      end)
    end)
  end)
end

---@param tool string
local function select_commit_model(tool)
  local config = assert(commit_tool_config(tool))
  local stored = commit_preferences()
  local current_model = stored.models[tool] or config.default_model

  vim.ui.select(config.models, {
    prompt = ("Select commit model for %s:"):format(config.label),
    format_item = function(item)
      local current = item.id == current_model and " (current)" or ""
      return ("%s%s"):format(item.label, current)
    end,
  }, function(choice)
    if not choice then
      return
    end
    save_commit_preferences(tool, choice.id)
    notify(("Commit generation set to %s / model: %s"):format(tool, choice.id))
  end)
end

local function select_commit_settings()
  local stored = commit_preferences()
  local tools = vim.tbl_values(commit_tools)
  table.sort(tools, function(a, b)
    return a.name < b.name
  end)

  vim.ui.select(tools, {
    prompt = "Select commit generator CLI:",
    format_item = function(item)
      local installed = vim.fn.executable(item.name) == 1 and "installed" or "missing"
      local current = item.name == stored.tool and " (current)" or ""
      return ("%s [%s]%s"):format(item.label, installed, current)
    end,
  }, function(choice)
    if not choice then
      return
    end
    select_commit_model(choice.name)
  end)
end

local function commit_message()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "gitcommit" then
    require("sidekick.cli").send({ prompt = "commit" })
    return
  end

  local stored = commit_preferences()
  generate_commit_message(buf, stored.tool, stored.models[stored.tool])
end

function M.setup()
  require("sidekick").setup({
    nes = {
      enabled = false,
    },
    cli = {
      watch = true,
      picker = "snacks",
      mux = {
        enabled = has_tmux,
        backend = "tmux",
        create = "terminal",
      },
      win = {
        layout = "right",
        split = {
          width = 84,
          height = 20,
        },
      },
      prompts = {
        commit = sidekick_commit_prompt,
        review_selection = "Can you review this selected code for issues or improvements?\n{selection}",
      },
    },
  })

  local map = vim.keymap.set
  local cli = require("sidekick.cli")
  map({ "n", "x" }, "<leader>aa", function()
    cli.toggle()
  end, { desc = "Toggle Sidekick CLI" })
  map({ "n", "x", "i", "t" }, "<C-.>", function()
    cli.focus()
  end, { desc = "Focus Sidekick CLI" })
  map("n", "<leader>af", function()
    cli.focus()
  end, { desc = "Focus Sidekick CLI" })
  map("n", "<leader>as", function()
    cli.select()
  end, { desc = "Select Sidekick CLI" })
  map({ "n", "x" }, "<leader>ap", function()
    cli.prompt()
  end, { desc = "AI prompt picker" })
  map({ "n", "x" }, "<leader>ae", function()
    cli.send({ prompt = "explain" })
  end, { desc = "Explain code" })
  map("n", "<leader>ar", function()
    cli.send({ prompt = "review" })
  end, { desc = "Review file" })
  map("x", "<leader>ar", function()
    cli.send({ prompt = "review_selection" })
  end, { desc = "Review selection" })
  map("n", "<leader>ad", function()
    cli.send({ prompt = "diagnostics" })
  end, { desc = "Fix diagnostics" })
  map("n", "<leader>aD", function()
    cli.send({ prompt = "diagnostics_all" })
  end, { desc = "Fix workspace diagnostics" })
  map("n", "<leader>am", commit_message, { desc = "Draft commit message" })
  map("n", "<leader>aM", select_commit_settings, { desc = "Configure commit AI" })

  vim.api.nvim_create_user_command("SidekickCommitSettings", select_commit_settings, {
    desc = "Configure Sidekick commit-message CLI and model",
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.sidekick.gitcommit", { clear = true }),
    pattern = "gitcommit",
    callback = function(ev)
      vim.keymap.set("n", "<leader>gm", commit_message, {
        buffer = ev.buf,
        desc = "Draft commit message (Sidekick)",
      })
      vim.keymap.set("n", "<leader>gM", select_commit_settings, {
        buffer = ev.buf,
        desc = "Configure commit AI",
      })
    end,
  })
end

return M
