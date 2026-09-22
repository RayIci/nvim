---commitsmith: AI-assisted commit messages, refined in conversation.
---
---Entry point. Owns `setup()`, the `:Commitsmith` command and the pickers for
---the global harness/model/lean settings. Everything buffer-scoped lives in
---`runner` (generation) and `ui.window` (the conversation).
---@class Commitsmith
local M = {}

local buffer = require("commitsmith.buffer")
local config = require("commitsmith.config")
local harness = require("commitsmith.harness")
local prompt = require("commitsmith.prompt")
local runner = require("commitsmith.runner")
local session = require("commitsmith.session")
local settings = require("commitsmith.settings")
local window = require("commitsmith.ui.window")

---@param msg string
---@param level integer?
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Commitsmith" })
end

---@return integer? buf a gitcommit buffer, or nil after reporting why not
local function commit_buffer()
  local buf = vim.api.nvim_get_current_buf()
  if not buffer.is_commit(buf) then
    notify("This requires a commit buffer", vim.log.levels.WARN)
    return nil
  end
  return buf
end

---Pick a model for `name`, then persist the pair.
---@param name string
local function select_model(name)
  local models = harness.models(name)
  local adapter = assert(harness.get(name))
  local current = settings.model(name)

  vim.ui.select(models, {
    prompt = ("Model for %s:"):format(adapter.label),
    format_item = function(item)
      return ("%s%s"):format(item.label, item.id == current and " (current)" or "")
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.id == "__custom__" then
      vim.ui.input({ prompt = ("Model id for %s: "):format(name), default = current }, function(value)
        if value and vim.trim(value) ~= "" then
          settings.set_model(name, vim.trim(value))
          notify(("Commit generation set to %s / %s"):format(name, vim.trim(value)))
        end
      end)
      return
    end
    settings.set_model(name, choice.id)
    notify(("Commit generation set to %s / %s"):format(name, choice.id))
  end)
end

---Discover what is installed, pick a harness, then pick its model.
local function select_harness()
  local adapters = harness.all()
  local current = settings.harness()

  vim.ui.select(adapters, {
    prompt = "Commit generator:",
    format_item = function(item)
      return ("%s [%s]%s"):format(
        item.label,
        item.available() and "installed" or "missing",
        item.name == current and " (current)" or ""
      )
    end,
  }, function(choice)
    if not choice then
      return
    end
    settings.set_harness(choice.name)
    select_model(choice.name)
  end)
end

---`generate` is the one action that means something outside a commit buffer: it
---hands the prompt to whatever the host configured instead.
local function generate()
  local buf = vim.api.nvim_get_current_buf()
  if buffer.is_commit(buf) then
    runner.generate(buf)
    return
  end

  local fallback = config.options.on_fallback
  if type(fallback) ~= "function" then
    notify("This requires a commit buffer", vim.log.levels.WARN)
    return
  end
  fallback(prompt.fallback())
end

---@type table<string, fun()>
local subcommands = {
  harness = select_harness,
  model = function()
    select_model(settings.harness())
  end,
  lean = function()
    local value = settings.toggle_lean()
    notify(("Lean invocation %s"):format(value and "enabled (no tools, no MCP servers)" or "disabled"))
  end,
  generate = generate,
  chat = function()
    local buf = commit_buffer()
    if buf then
      window.toggle(buf)
    end
  end,
  stop = function()
    local buf = commit_buffer()
    if buf then
      runner.stop(buf)
    end
  end,
  clear = function()
    local buf = commit_buffer()
    if buf then
      session.clear(buf)
      notify("Conversation cleared")
    end
  end,
  accept = function()
    local buf = commit_buffer()
    if buf then
      runner.accept(buf)
    end
  end,
}

---@type string[] completion order, most used first
local names = { "generate", "chat", "harness", "model", "lean", "stop", "clear", "accept" }

---@param opts CommitsmithOpts?
function M.setup(opts)
  config.setup(opts)
  settings.seed()

  vim.api.nvim_create_user_command("Commitsmith", function(args)
    local name = args.fargs[1] or "generate"
    local action = subcommands[name]
    if not action then
      notify(("Unknown subcommand `%s` (try: %s)"):format(name, table.concat(names, ", ")), vim.log.levels.ERROR)
      return
    end
    action()
  end, {
    nargs = "?",
    desc = "Generate and refine commit messages",
    complete = function(lead)
      return vim.tbl_filter(function(name)
        return name:find(lead, 1, true) == 1
      end, names)
    end,
  })
end

-- Public surface, for host keymaps.
M.generate = generate
M.harness = select_harness

---@param name string?
function M.model(name)
  select_model(name or settings.harness())
end

function M.chat()
  local buf = commit_buffer()
  if buf then
    window.toggle(buf)
  end
end

function M.lean()
  subcommands.lean()
end

function M.stop()
  subcommands.stop()
end

function M.clear()
  subcommands.clear()
end

function M.accept()
  subcommands.accept()
end

return M
