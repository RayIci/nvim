---Generation pipeline: staged diff in, commit message out, one conversation turn
---at a time.
---@class CommitsmithRunner
local M = {}

local buffer = require("commitsmith.buffer")
local config = require("commitsmith.config")
local harness = require("commitsmith.harness")
local prompt = require("commitsmith.prompt")
local session = require("commitsmith.session")
local settings = require("commitsmith.settings")

---@param msg string
---@param level integer?
---@param opts table?
local function notify(msg, level, opts)
  vim.notify(msg, level or vim.log.levels.INFO, vim.tbl_extend("force", { title = "Commitsmith" }, opts or {}))
end

---A session id we can hand to a harness up front, so the first turn already
---knows what a later turn must resume. claude and copilot accept one; codex
---ignores it and reports its own, which the adapter picks up instead.
---
---Drawn from libuv rather than math.random: LuaJIT does not seed its generator,
---so every Neovim process would otherwise produce the same id, and a harness
---rejects a session id that is already in use ("Session ID ... is already in
---use.") -- the first commit of a session would work and every later one fail.
---@return string
local function uuid()
  local bytes = { vim.uv.random(16):byte(1, 16) }
  -- RFC 4122 version 4, variant 1.
  bytes[7] = bit.bor(bit.band(bytes[7], 0x0f), 0x40)
  bytes[9] = bit.bor(bit.band(bytes[9], 0x3f), 0x80)
  local hex = {}
  for i, byte in ipairs(bytes) do
    hex[i] = ("%02x"):format(byte)
  end
  return table.concat({
    table.concat(hex, "", 1, 4),
    table.concat(hex, "", 5, 6),
    table.concat(hex, "", 7, 8),
    table.concat(hex, "", 9, 10),
    table.concat(hex, "", 11, 16),
  }, "-")
end

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---@param conversation CommitsmithConversation
---@param label string
local function start_spinner(conversation, label)
  local state = { idx = 1, id = "commitsmith_" .. conversation.buf }
  state.timer = vim.uv.new_timer()
  local function tick()
    notify(("%s Generating commit message with %s…"):format(spinner_frames[state.idx], label), nil, {
      id = state.id,
      timeout = false,
    })
  end
  tick()
  state.timer:start(
    80,
    80,
    vim.schedule_wrap(function()
      state.idx = (state.idx % #spinner_frames) + 1
      tick()
    end)
  )
  conversation.spinner = state
end

---@param conversation CommitsmithConversation
---@param msg string?
---@param level integer?
local function stop_spinner(conversation, msg, level)
  local state = conversation.spinner
  conversation.spinner = nil
  if state and state.timer then
    state.timer:stop()
    state.timer:close()
  end
  if msg then
    notify(msg, level, { id = state and state.id or nil, timeout = 3000 })
  end
end

---@param name string harness name
---@param model string?
---@return string
local function label(name, model)
  if model and model ~= "default" and model ~= "auto" then
    return ("%s / %s"):format(name, model)
  end
  return ("%s / CLI default"):format(name)
end

---Pull something readable out of a harness's output. Handles both plain text
---and the JSONL streams, where the useful message is buried in an event.
---@param output string
---@return string
local function describe_output(output)
  local text = vim.trim(output or "")
  if text == "" then
    return ""
  end

  local messages = {}
  for line in vim.gsplit(text, "\n", { plain = true }) do
    line = vim.trim(line)
    if line ~= "" then
      local ok, event = pcall(vim.json.decode, line)
      if ok and type(event) == "table" then
        local data = type(event.data) == "table" and event.data or {}
        local candidate = event.error or event.message or event.result or data.message or data.error
        if type(candidate) == "table" then
          candidate = candidate.message
        end
        if type(candidate) == "string" and vim.trim(candidate) ~= "" then
          messages[#messages + 1] = vim.trim(candidate)
        end
      elseif not line:match("^[%[{]") then
        messages[#messages + 1] = line
      end
    end
  end

  if #messages == 0 then
    return (text:gsub("%s+", " ")):sub(1, 300)
  end
  return messages[#messages]:sub(1, 300)
end

---Feed a stdout chunk through the adapter one complete line at a time.
---@param adapter table
---@param state table
---@param chunk string
---@param emit fun(event: CommitsmithEvent)
local function consume(adapter, state, chunk, emit)
  state.buffer = (state.buffer or "") .. chunk
  while true do
    local newline = state.buffer:find("\n")
    if not newline then
      break
    end
    local line = state.buffer:sub(1, newline - 1)
    state.buffer = state.buffer:sub(newline + 1)
    if vim.trim(line) ~= "" then
      for _, event in ipairs(adapter.parse(line, state)) do
        emit(event)
      end
    end
  end
end

---@param conversation CommitsmithConversation
---@param text string
local function apply_revision(conversation, text)
  local message = buffer.clean(text)
  if message == "" then
    conversation.status = "error"
    conversation.error = "the harness returned an empty message"
    stop_spinner(conversation, "Commit generator returned an empty message", vim.log.levels.WARN)
    session.changed(conversation)
    return
  end

  conversation.message = message
  session.add(conversation, { role = "reply", text = message })

  if config.options.apply == "auto" then
    if buffer.apply(conversation.buf, message) then
      stop_spinner(conversation, "Commit message inserted")
    else
      stop_spinner(conversation, "Could not write the commit buffer", vim.log.levels.WARN)
    end
  else
    stop_spinner(conversation, "Revision ready — accept it to write the commit buffer")
  end
end

---@param conversation CommitsmithConversation
---@param opts { prompt: string, resume: string?, replayed: boolean?, on_resume_failure: fun()? }
local function dispatch(conversation, opts)
  local name = settings.harness()
  local adapter = harness.get(name)
  if not adapter then
    conversation.status = "error"
    conversation.error = ("unknown harness `%s`"):format(name)
    notify(conversation.error, vim.log.levels.ERROR)
    return
  end
  -- A missing harness is never substituted or silently routed elsewhere: that
  -- would change the model, the cost and the output style without being asked.
  if not adapter.available() then
    conversation.status = "error"
    conversation.error = ("`%s` is not installed"):format(name)
    notify(
      ("`%s` is not installed. Pick another with :Commitsmith harness"):format(name),
      vim.log.levels.ERROR
    )
    session.changed(conversation)
    return
  end

  local model = settings.model(name)
  local stream = config.options.output == "stream"
  -- A harness that accepts a session id of our choosing is resumable even in
  -- batch mode, where nothing parses its output; one that only reports its own
  -- id can be resumed only after a stream turn has seen it.
  local pinned = (not opts.resume and adapter.pins_session) and uuid() or nil
  local invocation = adapter.build({
    prompt = opts.prompt,
    model = model,
    lean = settings.lean(),
    stream = stream,
    resume = opts.resume,
    session = pinned,
  })
  if pinned then
    conversation.session_id = pinned
  end

  local state = { output_file = invocation.output_file }
  conversation.status = "running"
  conversation.pending = ""
  conversation.harness = name
  start_spinner(conversation, label(name, model))
  session.changed(conversation)

  local system_opts = { text = true }
  if invocation.stdin ~= nil then
    system_opts.stdin = invocation.stdin
  end
  if stream then
    system_opts.stdout = function(err, chunk)
      if err or not chunk then
        return
      end
      -- Errors in stream mode arrive on stdout, not stderr. Keep a bounded tail
      -- so a failure can say what went wrong instead of only an exit code.
      state.raw = ((state.raw or "") .. chunk):sub(-8192)
      consume(adapter, state, chunk, function(event)
        vim.schedule(function()
          if event.session then
            conversation.session_id = event.session
          end
          if event.delta then
            conversation.pending = (conversation.pending or "") .. event.delta
            session.changed(conversation)
          end
          if event.error then
            conversation.error = event.error
          end
        end)
      end)
    end
  end

  conversation.handle = vim.system(invocation.cmd, system_opts, function(result)
    vim.schedule(function()
      conversation.handle = nil
      if invocation.cleanup then
        pcall(invocation.cleanup)
      end

      if conversation.cancelled then
        conversation.cancelled = nil
        conversation.status = "idle"
        conversation.pending = nil
        session.add(conversation, { role = "note", text = "generation cancelled", cancelled = true })
        stop_spinner(conversation, "Generation cancelled", vim.log.levels.WARN)
        return
      end

      if not vim.api.nvim_buf_is_valid(conversation.buf) then
        stop_spinner(conversation, nil)
        session.discard(conversation.buf)
        return
      end

      if result.code ~= 0 then
        -- A refinement that could not resume is recoverable: resend everything.
        if opts.on_resume_failure then
          conversation.pending = nil
          conversation.error = nil
          stop_spinner(conversation, nil)
          opts.on_resume_failure()
          return
        end
        conversation.status = "error"
        conversation.pending = nil
        -- Prefer, in order: an error the harness reported mid-stream, stderr,
        -- whatever it said on stdout, and only then the bare exit code.
        local reason = vim.trim(conversation.error or "")
        if reason == "" then
          reason = vim.trim(result.stderr or "")
        end
        if reason == "" then
          reason = describe_output(result.stdout or state.raw or "")
        end
        if reason == "" then
          reason = ("%s exited with code %d"):format(name, result.code)
        end
        conversation.error = reason
        stop_spinner(conversation, ("Commit generation failed: %s"):format(conversation.error), vim.log.levels.WARN)
        session.changed(conversation)
        return
      end

      local text
      if stream then
        text = state.message or conversation.pending or ""
      else
        local message, err = adapter.finalize(result, state)
        if not message then
          conversation.status = "error"
          conversation.error = err or "harness failed"
          stop_spinner(conversation, ("Commit generation failed: %s"):format(conversation.error), vim.log.levels.WARN)
          session.changed(conversation)
          return
        end
        text = message
      end

      conversation.status = "idle"
      conversation.pending = nil
      apply_revision(conversation, text)
    end)
  end)
end

---Where to run git for this commit buffer.
---
---Not the buffer's own directory: a commit buffer lives *inside* the git dir,
---and `git commit` exports GIT_INDEX_FILE (and friends) as paths relative to
---the work tree's top level. Running from `.git/` makes `.git/index` resolve to
---`.git/.git/index`, which does not exist -- git then reads an empty index and
---reports every staged file as a deletion (`+0/-N` across the whole tree).
---
---git runs the editor from the top level, so its cwd is normally right. It is
---only trusted when its git dir is the one holding this buffer, so a commit
---buffer opened by hand while Neovim sits in another repository cannot make us
---diff the wrong tree. GIT_INDEX_FILE is deliberately left alone: a partial
---commit (`git commit -p`) points it at a temporary index, and that is the
---index being committed.
---@param buf integer
---@return string
local function repo_cwd(buf)
  local gitdir = vim.fn.resolve(vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))

  ---@param dir string
  ---@return boolean
  local function owns_buffer(dir)
    if dir == "" or vim.fn.isdirectory(dir) == 0 then
      return false
    end
    local probe = vim.system({ "git", "rev-parse", "--absolute-git-dir" }, { text = true, cwd = dir }):wait()
    if probe.code ~= 0 then
      return false
    end
    return vim.fn.resolve(vim.trim(probe.stdout or "")) == gitdir
  end

  for _, candidate in ipairs({ vim.fn.getcwd(), vim.fs.dirname(gitdir) }) do
    if owns_buffer(candidate) then
      return candidate
    end
  end
  return vim.fs.dirname(gitdir)
end

---@param buf integer
---@return string? diff, string? err
local function staged_diff(buf)
  local cwd = repo_cwd(buf)
  local result = vim
    .system({ "git", "diff", "--staged", "--no-ext-diff" }, { text = true, cwd = cwd })
    :wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or "git diff failed")
  end
  local diff = vim.trim(result.stdout or "")
  if diff == "" then
    return nil, "no staged changes found"
  end
  return diff
end

---First turn: rules plus the staged diff, and the existing message when the
---buffer already holds one to revise.
---@param buf integer
function M.generate(buf)
  if session.is_running(buf) then
    notify("A commit message is already being generated", vim.log.levels.WARN)
    return
  end

  local conversation = session.get(buf)
  local diff, err = staged_diff(buf)
  if not diff then
    notify(err or "could not read the staged diff", vim.log.levels.WARN)
    return
  end

  conversation.diff = diff
  conversation.session_id = nil
  local draft = buffer.message(buf)
  local text = prompt.initial(diff, draft)
  session.add(conversation, {
    role = "request",
    text = draft ~= "" and "Generate a commit message, revising the existing draft." or "Generate a commit message.",
    diff = diff,
  })
  dispatch(conversation, { prompt = text })
end

---A follow-up turn. Resumes the harness session when there is one to resume and
---the configured strategy allows it, and resends everything otherwise.
---@param buf integer
---@param instruction string
function M.refine(buf, instruction)
  if vim.trim(instruction or "") == "" then
    return
  end
  if session.is_running(buf) then
    notify("A commit message is already being generated", vim.log.levels.WARN)
    return
  end

  local conversation = session.peek(buf)
  if not conversation or not conversation.message then
    -- Nothing to refine yet: treat it as the opening turn.
    M.generate(buf)
    return
  end

  session.add(conversation, { role = "refinement", text = vim.trim(instruction) })

  local strategy = config.options.conversation
  local can_resume = strategy ~= "replay"
    and conversation.session_id ~= nil
    and conversation.harness == settings.harness()

  local function replay()
    local diff = conversation.diff
    if not diff then
      local fresh, err = staged_diff(buf)
      if not fresh then
        notify(err or "could not read the staged diff", vim.log.levels.WARN)
        return
      end
      diff = fresh
      conversation.diff = diff
    end
    session.add(conversation, { role = "note", text = "full context replayed", replayed = true })
    dispatch(conversation, { prompt = prompt.replay(diff, conversation.message, instruction) })
  end

  if can_resume then
    dispatch(conversation, {
      prompt = prompt.refine(instruction),
      resume = conversation.session_id,
      on_resume_failure = strategy == "session" and nil or replay,
    })
  else
    replay()
  end
end

---@param buf integer
function M.stop(buf)
  local conversation = session.peek(buf)
  if not conversation or not conversation.handle then
    notify("Nothing is being generated", vim.log.levels.WARN)
    return
  end
  conversation.cancelled = true
  pcall(function()
    conversation.handle:kill("sigterm")
  end)
end

---Write the latest revision to the commit buffer. Used by `apply = "manual"`.
---@param buf integer
function M.accept(buf)
  local conversation = session.peek(buf)
  if not conversation or not conversation.message then
    notify("No revision to accept", vim.log.levels.WARN)
    return
  end
  if buffer.apply(buf, conversation.message) then
    notify("Commit message inserted")
  end
end

return M
