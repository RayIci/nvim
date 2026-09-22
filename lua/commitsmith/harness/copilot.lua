---GitHub Copilot CLI adapter.
---
---Streaming shape (`--output-format json --stream on`), one JSON object per line:
---  {"type":"assistant.message_delta","data":{"deltaContent":"ch"}}   a text delta
---  {"type":"assistant.message","data":{"content":"<full message>"}}  the reply
---  {"type":"result","sessionId":"…","exitCode":0}                    terminal
---  {"type":"session.mcp_servers_loaded","data":{"servers":[…]}}      lean proof
---@type table
local M = {
  name = "copilot",
  label = "GitHub Copilot CLI",
  default_model = "auto",
  -- Accepts a session id we choose, so a batch turn is resumable too.
  pins_session = true,
  -- Deliberately just the automatic option: this CLI exposes no way to list
  -- the models an account may use, and every concrete id tried against 1.0.87
  -- was rejected with "Model ... is not available" -- including the one the CLI
  -- itself picked. Reach a specific model through the picker's custom entry, or
  -- pin a list via setup({ models = { copilot = { ... } } }).
  models = {
    { id = "auto", label = "Auto (Copilot chooses)" },
  },
}

function M.available()
  return vim.fn.executable("copilot") == 1
end

---@param opts CommitsmithBuildOpts
---@return CommitsmithInvocation
function M.build(opts)
  -- --allow-all-tools is required for any non-interactive run, even one that
  -- ends up with no tools at all.
  local cmd = { "copilot", "--allow-all-tools" }

  if opts.lean then
    -- An empty --available-tools allowlist leaves the model no tools, which
    -- also makes the configured MCP servers irrelevant; --disable-builtin-mcps
    -- stops the bundled github server from being loaded at all.
    vim.list_extend(cmd, { "--disable-builtin-mcps", "--available-tools" })
  end
  if opts.model and opts.model ~= "auto" then
    vim.list_extend(cmd, { "--model", opts.model })
  end

  if opts.resume then
    vim.list_extend(cmd, { "--resume", opts.resume })
  elseif opts.session then
    vim.list_extend(cmd, { "--session-id", opts.session })
  end

  if opts.stream then
    vim.list_extend(cmd, { "--output-format", "json", "--stream", "on" })
  else
    -- --silent prints the agent response only, with no stats banner.
    cmd[#cmd + 1] = "--silent"
  end

  -- The prompt carries the whole staged diff, which routinely exceeds Linux's
  -- 128 KB cap on a single argv entry (MAX_ARG_STRLEN), so it goes on stdin
  -- instead of `--prompt`; piped stdin still runs non-interactively.
  return { cmd = cmd, stdin = opts.prompt }
end

---@param line string one JSONL record
---@param state table
---@return CommitsmithEvent[]
function M.parse(line, state)
  local ok, event = pcall(vim.json.decode, line)
  if not ok or type(event) ~= "table" then
    return {}
  end

  local data = type(event.data) == "table" and event.data or {}
  local events = {}

  if event.type == "assistant.message_delta" then
    if type(data.deltaContent) == "string" then
      events[#events + 1] = { delta = data.deltaContent }
    end
  elseif event.type == "assistant.message" then
    if type(data.content) == "string" then
      state.message = data.content
    end
  elseif event.type == "result" then
    if type(event.sessionId) == "string" and not state.session then
      state.session = event.sessionId
      events[#events + 1] = { session = event.sessionId }
    end
    if event.exitCode and event.exitCode ~= 0 then
      events[#events + 1] = { error = ("copilot exited with code %s"):format(event.exitCode) }
    else
      events[#events + 1] = { done = true }
    end
  end

  return events
end

---@param result vim.SystemCompleted
---@return string? message, string? err
function M.finalize(result)
  if result.code ~= 0 then
    local reason = vim.trim(result.stderr or "")
    if reason == "" then
      reason = vim.trim(result.stdout or "")
    end
    return nil, reason ~= "" and reason or ("exited with code " .. tostring(result.code))
  end
  return result.stdout or ""
end

return M
