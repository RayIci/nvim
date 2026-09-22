---The conversation window: a transcript of the exchange for one commit buffer,
---plus an input for refining the message. Opened and closed independently of
---generation — it attaches to whatever state already exists.
---@class CommitsmithWindow
local M = {}

local buffer = require("commitsmith.buffer")
local config = require("commitsmith.config")
local runner = require("commitsmith.runner")
local session = require("commitsmith.session")
local settings = require("commitsmith.settings")

---@class CommitsmithView
---@field commit integer the gitcommit buffer this view belongs to
---@field buf integer transcript buffer
---@field win integer transcript window
---@field input integer? input buffer
---@field input_win integer? input window
---@field expanded boolean whether the staged diff is shown in full

---@type table<integer, CommitsmithView>
local views = {}

---@type table<string, string> canned refinements, keyed by the key that sends them
local canned = {
  s = "Make the message shorter and tighter without losing any concrete change.",
  d = "Add more detail to the body: be specific about what each change does.",
  t = "The Conventional Commits type or scope is wrong. Fix it to match the diff.",
  r = "__regenerate__",
}

---@param view CommitsmithView
---@return string[]
local function render(view)
  local conversation = session.peek(view.commit)
  local name = settings.harness()
  local lines = {
    ("# Commitsmith — %s%s"):format(name, settings.lean() and " (lean)" or ""),
    "",
  }

  if not conversation or #conversation.turns == 0 then
    lines[#lines + 1] = "*No conversation yet.*"
    lines[#lines + 1] = ""
  end

  for _, turn in ipairs(conversation and conversation.turns or {}) do
    if turn.role == "request" then
      lines[#lines + 1] = "## → request"
      lines[#lines + 1] = turn.text
      if turn.diff then
        lines[#lines + 1] = ""
        if view.expanded then
          lines[#lines + 1] = "```diff"
          vim.list_extend(lines, vim.split(turn.diff, "\n", { plain = true }))
          lines[#lines + 1] = "```"
          lines[#lines + 1] = "*<Tab> to collapse*"
        else
          lines[#lines + 1] = ("▸ %s  *<Tab> to expand*"):format(buffer.diff_summary(turn.diff))
        end
      end
    elseif turn.role == "refinement" then
      lines[#lines + 1] = "## → refine"
      vim.list_extend(lines, vim.split(turn.text, "\n", { plain = true }))
    elseif turn.role == "reply" then
      lines[#lines + 1] = "## ← message"
      vim.list_extend(lines, vim.split(turn.text, "\n", { plain = true }))
    elseif turn.role == "note" then
      lines[#lines + 1] = ("· %s"):format(turn.text)
    end
    lines[#lines + 1] = ""
  end

  if conversation and conversation.status == "running" then
    lines[#lines + 1] = "## ← message"
    local pending = conversation.pending or ""
    if pending == "" then
      lines[#lines + 1] = "*waiting for the harness…*"
    else
      vim.list_extend(lines, vim.split(pending, "\n", { plain = true }))
    end
    lines[#lines + 1] = ""
  elseif conversation and conversation.status == "error" and conversation.error then
    lines[#lines + 1] = ("! %s"):format(conversation.error)
    lines[#lines + 1] = ""
  end

  lines[#lines + 1] = "---"
  local accept = config.options.apply == "manual" and "  a accept" or ""
  lines[#lines + 1] = ("i refine  s shorter  d detail  t type/scope  r regenerate%s"):format(accept)
  lines[#lines + 1] = "x stop  c clear  q close"
  return lines
end

---@param view CommitsmithView
local function redraw(view)
  if not vim.api.nvim_buf_is_valid(view.buf) then
    return
  end
  local lines = render(view)
  vim.bo[view.buf].modifiable = true
  vim.api.nvim_buf_set_lines(view.buf, 0, -1, false, lines)
  vim.bo[view.buf].modifiable = false
  if vim.api.nvim_win_is_valid(view.win) then
    -- Follow the tail while a reply streams in, but not if the user scrolled up
    -- to read something.
    local cursor = vim.api.nvim_win_get_cursor(view.win)
    if cursor[1] >= #lines - 4 then
      pcall(vim.api.nvim_win_set_cursor, view.win, { #lines, 0 })
    end
  end
end

---@param view CommitsmithView
local function open_input(view)
  if view.input_win and vim.api.nvim_win_is_valid(view.input_win) then
    vim.api.nvim_set_current_win(view.input_win)
    vim.cmd.startinsert()
    return
  end

  view.input, view.input_win = require("commitsmith.ui.input").open(view, function()
    view.input, view.input_win = nil, nil
  end)
end

---@param view CommitsmithView
local function set_keymaps(view)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = view.buf, desc = desc, nowait = true })
  end

  map("q", function()
    M.close(view.commit)
  end, "Close conversation")
  map("<Tab>", function()
    view.expanded = not view.expanded
    redraw(view)
  end, "Toggle staged diff")
  map("i", function()
    open_input(view)
  end, "Refine the message")
  map("x", function()
    runner.stop(view.commit)
  end, "Stop generation")
  map("c", function()
    session.clear(view.commit)
  end, "Clear conversation")
  map("a", function()
    runner.accept(view.commit)
  end, "Accept revision")

  for key, instruction in pairs(canned) do
    map(key, function()
      if instruction == "__regenerate__" then
        runner.generate(view.commit)
      else
        runner.refine(view.commit, instruction)
      end
    end, "Refine: " .. key)
  end
end

---@param commit integer
---@return CommitsmithView
local function create(commit)
  local opts = config.options.window
  local layout = opts.layout

  if layout == "float" then
    local width = math.min(opts.width, math.floor(vim.o.columns * 0.9))
    local height = math.floor(vim.o.lines * 0.8)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = "minimal",
      border = opts.border,
      title = " Commitsmith ",
    })
    return { commit = commit, buf = buf, win = win, expanded = false }
  end

  local command = ({
    right = "botright vsplit",
    left = "topleft vsplit",
    bottom = "botright split",
    top = "topleft split",
  })[layout] or "botright vsplit"
  vim.cmd(command)
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  if layout == "right" or layout == "left" then
    vim.api.nvim_win_set_width(win, opts.width)
  else
    vim.api.nvim_win_set_height(win, opts.height)
  end
  return { commit = commit, buf = buf, win = win, expanded = false }
end

---@param commit integer
function M.open(commit)
  local view = views[commit]
  if view and vim.api.nvim_win_is_valid(view.win) then
    vim.api.nvim_set_current_win(view.win)
    return
  end

  view = create(commit)
  views[commit] = view
  vim.bo[view.buf].filetype = "markdown"
  vim.bo[view.buf].bufhidden = "wipe"
  vim.bo[view.buf].modifiable = false
  vim.wo[view.win].wrap = true
  vim.wo[view.win].number = false
  vim.wo[view.win].relativenumber = false
  vim.wo[view.win].signcolumn = "no"
  pcall(vim.api.nvim_buf_set_name, view.buf, ("commitsmith://%d"):format(commit))
  set_keymaps(view)

  local conversation = session.get(commit)
  conversation.on_change = function()
    local current = views[commit]
    if current then
      redraw(current)
    end
  end
  redraw(view)

  -- Opening the window with nothing to show starts the work the user came for.
  if #conversation.turns == 0 and conversation.status ~= "running" then
    runner.generate(commit)
  end
end

---@param commit integer
function M.close(commit)
  local view = views[commit]
  if not view then
    return
  end
  if view.input_win and vim.api.nvim_win_is_valid(view.input_win) then
    vim.api.nvim_win_close(view.input_win, true)
  end
  if vim.api.nvim_win_is_valid(view.win) then
    vim.api.nvim_win_close(view.win, true)
  end
  views[commit] = nil
  -- The conversation itself outlives the window on purpose.
  local conversation = session.peek(commit)
  if conversation then
    conversation.on_change = nil
  end
end

---@param commit integer
function M.toggle(commit)
  local view = views[commit]
  if view and vim.api.nvim_win_is_valid(view.win) then
    M.close(commit)
  else
    M.open(commit)
  end
end

return M
