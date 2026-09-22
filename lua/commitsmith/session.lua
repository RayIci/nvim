---Conversation state, one per gitcommit buffer.
---
---A commit buffer is exactly the scope of one commit message, so the transcript
---lives and dies with it: closing the window leaves it alone, wiping the buffer
---discards it. Nothing here is persisted.
---@class CommitsmithSession
local M = {}

---@class CommitsmithTurn
---@field role "request"|"reply"|"refinement"|"note"
---@field text string
---@field diff string? full staged diff, shown collapsed
---@field replayed boolean? this turn resent the whole conversation
---@field cancelled boolean?

---@class CommitsmithConversation
---@field buf integer
---@field turns CommitsmithTurn[]
---@field message string? the latest complete message
---@field pending string? text accumulating from the harness right now
---@field status "idle"|"running"|"error"
---@field error string?
---@field harness string? harness that owns `session_id`
---@field session_id string? resume handle, when the harness gave us one
---@field diff string? staged diff captured for this conversation
---@field handle table? running process, for cancellation
---@field on_change fun()? window redraw hook

---@type table<integer, CommitsmithConversation>
local conversations = {}

---@param buf integer
---@return CommitsmithConversation
function M.get(buf)
  if not conversations[buf] then
    conversations[buf] = {
      buf = buf,
      turns = {},
      status = "idle",
    }
    -- The conversation is meaningless once the buffer is gone; a buffer number
    -- can be reused, so stale state would otherwise leak into a later commit.
    vim.api.nvim_create_autocmd({ "BufWipeout" }, {
      buffer = buf,
      once = true,
      callback = function()
        M.discard(buf)
      end,
    })
  end
  return conversations[buf]
end

---@param buf integer
---@return CommitsmithConversation?
function M.peek(buf)
  return conversations[buf]
end

---@param buf integer
function M.discard(buf)
  local conversation = conversations[buf]
  if conversation and conversation.handle then
    pcall(function()
      conversation.handle:kill("sigterm")
    end)
  end
  conversations[buf] = nil
end

---Reset in place: same buffer, empty conversation, no resume handle.
---@param buf integer
function M.clear(buf)
  local conversation = conversations[buf]
  if not conversation then
    return
  end
  if conversation.handle then
    pcall(function()
      conversation.handle:kill("sigterm")
    end)
  end
  conversation.turns = {}
  conversation.message = nil
  conversation.pending = nil
  conversation.status = "idle"
  conversation.error = nil
  conversation.session_id = nil
  conversation.harness = nil
  conversation.diff = nil
  conversation.handle = nil
  M.changed(conversation)
end

---@param conversation CommitsmithConversation
---@param turn CommitsmithTurn
function M.add(conversation, turn)
  conversation.turns[#conversation.turns + 1] = turn
  M.changed(conversation)
end

---@param conversation CommitsmithConversation
function M.changed(conversation)
  if conversation.on_change then
    vim.schedule(conversation.on_change)
  end
end

---@param buf integer
---@return boolean
function M.is_running(buf)
  local conversation = conversations[buf]
  return conversation ~= nil and conversation.status == "running"
end

return M
