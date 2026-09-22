---Codex CLI adapter.
---
---Streaming shape (`--json`), one JSON object per line:
---  {"type":"thread.started","thread_id":"…"}                      the session id
---  {"type":"turn.started"}
---  {"type":"item.completed","item":{"type":"agent_message",
---     "text":"<full message>"}}                                   the reply
---  {"type":"turn.completed","usage":{…}}                          terminal
---
---Three things this CLI does differently, all verified against 0.154.0:
---  * It emits no incremental text deltas. `item.completed` carries the whole
---    message at once, so "streaming" here means one large delta on arrival
---    rather than a message typing itself out.
---  * `codex exec resume` accepts a strict subset of `codex exec`'s flags: no
---    `-s/--sandbox`, no `--color`. Passing either aborts with exit 2.
---  * It blocks on stdin ("Reading additional input from stdin...") unless stdin
---    is closed, so the invocation always hands it an empty one.
---@type table
local M = {
  name = "codex",
  label = "Codex CLI",
  default_model = "default",
  -- Reports its own thread id instead of taking one, and only on the --json
  -- stream, so a batch codex turn is never resumable and always replays.
  pins_session = false,
  -- `default` defers to ~/.codex/config.toml. Only the model codex reported as
  -- its own default is listed; anything else goes through the picker's custom
  -- entry rather than being guessed here.
  models = {
    { id = "default", label = "Default (config.toml)" },
    { id = "gpt-5.6-terra", label = "GPT-5.6 Terra" },
  },
}

function M.available()
  return vim.fn.executable("codex") == 1
end

---@param opts CommitsmithBuildOpts
---@return CommitsmithInvocation
function M.build(opts)
  local cmd = { "codex", "exec" }
  if opts.resume then
    vim.list_extend(cmd, { "resume", opts.resume })
  end

  cmd[#cmd + 1] = "--skip-git-repo-check"
  if opts.lean then
    -- An empty mcp_servers table leaves no servers to start. `-s read-only`
    -- would also drop write access, but `resume` rejects the flag, so it is
    -- only passed when starting a session.
    vim.list_extend(cmd, { "-c", "mcp_servers={}" })
    if not opts.resume then
      vim.list_extend(cmd, { "-s", "read-only" })
    end
  end
  if not opts.resume then
    -- `resume` does not accept --color.
    vim.list_extend(cmd, { "--color", "never" })
  end
  if opts.model and opts.model ~= "default" then
    vim.list_extend(cmd, { "-m", opts.model })
  end

  local output_file, cleanup
  if opts.stream then
    cmd[#cmd + 1] = "--json"
  else
    -- -o writes just the final message, sidestepping the banner on stderr and
    -- any progress codex prints to stdout.
    output_file = vim.fn.tempname()
    vim.list_extend(cmd, { "-o", output_file })
    cleanup = function()
      vim.fn.delete(output_file)
    end
  end

  -- The prompt carries the whole staged diff, which routinely exceeds Linux's
  -- 128 KB cap on a single argv entry (MAX_ARG_STRLEN), so `-` tells codex to
  -- read it from stdin. This also settles the stdin wait it does otherwise.
  cmd[#cmd + 1] = "-"
  return { cmd = cmd, stdin = opts.prompt, cleanup = cleanup, output_file = output_file }
end

---@param line string one JSONL record
---@param state table
---@return CommitsmithEvent[]
function M.parse(line, state)
  local ok, event = pcall(vim.json.decode, line)
  if not ok or type(event) ~= "table" then
    return {}
  end

  local events = {}
  if event.type == "thread.started" then
    if type(event.thread_id) == "string" and not state.session then
      state.session = event.thread_id
      events[#events + 1] = { session = event.thread_id }
    end
  elseif event.type == "item.completed" then
    local item = event.item
    if type(item) == "table" and item.type == "agent_message" and type(item.text) == "string" then
      -- No token-level deltas from this CLI: the whole message lands here.
      state.message = item.text
      events[#events + 1] = { delta = item.text }
    end
  elseif event.type == "turn.failed" or event.type == "error" then
    local message = type(event.error) == "table" and event.error.message or event.message
    events[#events + 1] = { error = tostring(message or "codex reported an error") }
  elseif event.type == "turn.completed" then
    events[#events + 1] = { done = true }
  end

  return events
end

---@param result vim.SystemCompleted
---@param state table? carries the -o path chosen in build()
---@return string? message, string? err
function M.finalize(result, state)
  if result.code ~= 0 then
    local reason = vim.trim(result.stderr or "")
    if reason == "" then
      reason = vim.trim(result.stdout or "")
    end
    return nil, reason ~= "" and reason or ("exited with code " .. tostring(result.code))
  end

  local file = state and state.output_file
  if file and vim.fn.filereadable(file) == 1 then
    local text = table.concat(vim.fn.readfile(file), "\n")
    vim.fn.delete(file)
    return text
  end
  return result.stdout or ""
end

return M
