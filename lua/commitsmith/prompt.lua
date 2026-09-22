---Prompt construction. One Conventional Commits rule block, rendered two ways:
---with the staged diff inlined (headless generation) or with an instruction to
---fetch the diff (the fallback prompt handed to another agent). The rules are
---the part that must never diverge between the two.
---@class CommitsmithPrompt
local M = {}

---@type string
local rules = table.concat({
  "Use a single title line in the format `type(scope): summary`, at most 72",
  "characters.",
  "",
  "Then write a body wrapped at 72 characters. The body MUST start with a short",
  "introductory sentence that summarizes the overall change, followed by a",
  "bullet list of the concrete changes. Each bullet MUST start with `- `. Add a",
  "final short paragraph only if it helps explain rationale, impact, or context.",
  "",
  "Focus on what changed and why. Do not describe obvious implementation details",
  "unless they are useful for understanding the commit. Do not mention generated",
  "files, formatting-only noise, or unrelated changes unless they are central to",
  "the commit.",
  "",
  "Answer with ONLY the raw commit message. Do not add code fences, quotes,",
  "markdown headings, explanations, commentary, or alternative options.",
}, "\n")

---@param draft string?
---@return string[]
local function draft_block(draft)
  if not draft or vim.trim(draft) == "" then
    return {}
  end
  return {
    "",
    "The current draft of the message is below. Revise it rather than starting",
    "from scratch, keeping whatever is already accurate.",
    "",
    vim.trim(draft),
  }
end

---The prompt for an agent that must obtain the staged diff itself. Used for the
---fallback path, where we are handing work to a session with its own tools.
---@return string
function M.fallback()
  return table.concat({
    "Inspect the staged changes in this repository with `git diff --staged` and",
    "write a commit message following the Conventional Commits convention.",
    "",
    rules,
  }, "\n")
end

---The first turn of a headless conversation: rules, the staged diff, and the
---existing message when there is one to revise (an amend, or a re-run).
---@param diff string
---@param draft string?
---@return string
function M.initial(diff, draft)
  local parts = {
    "Write a commit message for the staged changes following the Conventional",
    "Commits convention.",
    "",
    rules,
  }
  vim.list_extend(parts, draft_block(draft))
  vim.list_extend(parts, { "", "Staged diff:", "", diff })
  return table.concat(parts, "\n")
end

---A follow-up turn sent into a live harness session, which already holds the
---diff and the message it produced. Only the instruction travels.
---@param instruction string
---@return string
function M.refine(instruction)
  return table.concat({
    vim.trim(instruction),
    "",
    "Answer with ONLY the full revised raw commit message, following the same",
    "rules as before. Do not add code fences, quotes, markdown headings,",
    "explanations, commentary, or alternative options.",
  }, "\n")
end

---A follow-up turn for a harness whose session could not be resumed: the whole
---conversation, rebuilt as a single prompt.
---@param diff string
---@param message string current commit message
---@param instruction string
---@return string
function M.replay(diff, message, instruction)
  return table.concat({
    "Revise a commit message for the staged changes, following the Conventional",
    "Commits convention.",
    "",
    rules,
    "",
    "Staged diff:",
    "",
    diff,
    "",
    "The current commit message is:",
    "",
    vim.trim(message),
    "",
    "Revise it as follows:",
    "",
    vim.trim(instruction),
  }, "\n")
end

---@return string the shared rule block, for tests and window rendering
function M.rules()
  return rules
end

return M
