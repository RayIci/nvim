---Harness registry. Each adapter owns one agent CLI: how to invoke it, how to
---read what it prints, how to carry a session between turns, and how to strip it
---down to no tools. The three CLIs disagree on all four, so the divergence lives
---in three small files behind this interface rather than in branching elsewhere.
---
---An adapter is a table:
---  name, label, default_model, models
---  available()            -> boolean            executable on PATH
---  build(opts)            -> CommitsmithInvocation
---  parse(chunk, state)    -> CommitsmithEvent[]  streaming; normalizes output
---  finalize(result, state)-> string?, string?    batch; message or error
---  session_id(state)      -> string?             what to resume with next turn
---@class CommitsmithHarness
local M = {}

---@class CommitsmithModel
---@field id string passed to the CLI, or a sentinel meaning "let the CLI decide"
---@field label string shown in the picker

---@class CommitsmithBuildOpts
---@field prompt string
---@field model string?
---@field lean boolean invoke with no tools and no MCP servers
---@field stream boolean
---@field resume string? session id to continue instead of starting fresh
---@field session string? session id to pin on a new session, when supported

---@class CommitsmithInvocation
---@field cmd string[] argv
---@field stdin string? written to the process and closed
---@field cleanup fun()? removes anything the invocation created

---@class CommitsmithEvent
---@field delta string? text appended to the reply
---@field session string? session id the harness reported
---@field done boolean? the reply is complete
---@field error string? the harness reported a failure

---@type string[] selection order in the picker
M.order = { "claude", "codex", "copilot" }

---@type table<string, table>
local adapters = {}

---@param name string
---@return table? adapter
function M.get(name)
  if type(name) ~= "string" then
    return nil
  end
  if adapters[name] == nil then
    local ok, adapter = pcall(require, "commitsmith.harness." .. name)
    adapters[name] = ok and adapter or false
  end
  return adapters[name] or nil
end

---@return table[] every adapter, in selection order
function M.all()
  local list = {}
  for _, name in ipairs(M.order) do
    local adapter = M.get(name)
    if adapter then
      list[#list + 1] = adapter
    end
  end
  return list
end

---The model list for a harness, with any `setup({ models = ... })` override
---applied, plus a free-text entry so a model the plugin has never heard of is
---still reachable without editing it.
---@param name string
---@return CommitsmithModel[]
function M.models(name)
  local adapter = M.get(name)
  if not adapter then
    return {}
  end

  local override = require("commitsmith.config").options.models[name]
  local models = vim.deepcopy(override or adapter.models)
  models[#models + 1] = { id = "__custom__", label = "custom… (type a model id)" }
  return models
end

---@param name string
---@param id string
---@return CommitsmithModel?
function M.model(name, id)
  for _, model in ipairs(M.models(name)) do
    if model.id == id then
      return model
    end
  end
end

return M
