---Claude Code CLI adapter.
---
---Streaming shape (`--output-format stream-json --include-partial-messages`),
---one JSON object per line:
---  {"type":"system","subtype":"init","session_id":"…"}          the session id
---  {"type":"stream_event","event":{"type":"content_block_delta",
---     "delta":{"type":"text_delta","text":"ch"}}}               a text delta
---  {"type":"result","subtype":"success","is_error":false,
---     "result":"<full message>","session_id":"…"}               terminal
---@type table
local M = {
  name = "claude",
  label = "Claude Code CLI",
  default_model = "default",
  -- Accepts a session id we choose, so a batch turn is resumable too.
  pins_session = true,
  -- Stable aliases rather than pinned ids, so these do not rot.
  models = {
    { id = "default", label = "Default (Claude chooses)" },
    { id = "haiku", label = "Haiku" },
    { id = "sonnet", label = "Sonnet" },
    { id = "opus", label = "Opus" },
  },
}

function M.available()
  return vim.fn.executable("claude") == 1
end

---@param opts CommitsmithBuildOpts
---@return CommitsmithInvocation
function M.build(opts)
  local cmd = { "claude", "--print" }

  if opts.lean then
    -- --strict-mcp-config with no --mcp-config leaves zero MCP servers;
    -- --restricted drops the command- and code-running tools. The diff is
    -- supplied inline, so the model needs neither.
    vim.list_extend(cmd, { "--strict-mcp-config", "--restricted" })
  end
  if opts.model and opts.model ~= "default" then
    vim.list_extend(cmd, { "--model", opts.model })
  end

  if opts.resume then
    vim.list_extend(cmd, { "--resume", opts.resume })
  elseif opts.session then
    vim.list_extend(cmd, { "--session-id", opts.session })
  end

  if opts.stream then
    -- --verbose is required alongside stream-json on the --print path.
    vim.list_extend(cmd, {
      "--output-format",
      "stream-json",
      "--include-partial-messages",
      "--verbose",
    })
  else
    vim.list_extend(cmd, { "--output-format", "text" })
  end

  -- The prompt carries the whole staged diff, which routinely exceeds Linux's
  -- 128 KB cap on a single argv entry (MAX_ARG_STRLEN), so it goes on stdin.
  -- `--print` with no prompt argument reads it from there.
  return { cmd = cmd, stdin = opts.prompt }
end

---@param line string one JSONL record
---@param state table carries session id and the final message across lines
---@return CommitsmithEvent[]
function M.parse(line, state)
  local ok, event = pcall(vim.json.decode, line)
  if not ok or type(event) ~= "table" then
    return {}
  end

  local events = {}
  if event.session_id and not state.session then
    state.session = event.session_id
    events[#events + 1] = { session = event.session_id }
  end

  if event.type == "stream_event" then
    local inner = event.event
    if
      type(inner) == "table"
      and inner.type == "content_block_delta"
      and type(inner.delta) == "table"
      and inner.delta.type == "text_delta"
      and type(inner.delta.text) == "string"
    then
      events[#events + 1] = { delta = inner.delta.text }
    end
  elseif event.type == "result" then
    if event.is_error then
      events[#events + 1] = { error = tostring(event.result or event.subtype or "claude reported an error") }
    else
      -- `result` holds the whole message; prefer it over the accumulated deltas.
      state.message = type(event.result) == "string" and event.result or state.message
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
