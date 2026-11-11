---Conflict center (<leader>gCC): what is happening in plain words, which side
---is which, and every conflicted file with its remaining conflicts; from there
---resolve, open the 3-way view, stage, continue, skip or abort. Also the
---explain panel and the next-step commands behind <leader>gCa/gCc/gCA.
---@class ConflictsCenter
local M = {}

local markers = require("config.conflicts.markers")
local state = require("config.conflicts.state")

---@type { buf: integer, win: integer, rows: table<integer, string> }?
M.panel = nil

---@param msg string
---@param level? integer
local function say(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Conflicts" })
end

---@param path string
---@return string
local function rel(path)
  local root = state.current and state.current.root
  if root and path:sub(1, #root + 1) == root .. "/" then
    return path:sub(#root + 2)
  end
  return vim.fn.fnamemodify(path, ":.")
end

---Refresh state, inline marks, statusline and the open panel.
local function refresh()
  state.refresh()
  pcall(vim.cmd.checktime)
  if M.panel then
    M.render()
  end
end

---Stage a resolved file. Refused while it (on disk or unsaved) still has markers.
---@param path? string defaults to the current buffer's file
function M.stage(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if not state.current then
    state.refresh()
  end
  if not state.current then
    return say("Nothing to stage: no conflict in progress", vim.log.levels.WARN)
  end
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.bo[buf].modified then
    return say(rel(path) .. " has unsaved changes: save it first", vim.log.levels.WARN)
  end
  local left = markers.count_file(path)
  if left > 0 then
    return say(
      ("%s still has %d conflict%s: resolve %s first"):format(rel(path), left, left == 1 and "" or "s", left == 1 and "it" or "them"),
      vim.log.levels.WARN
    )
  end
  local result = state.run("add", "--", path)
  if result.code ~= 0 then
    return say("git add failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
  end
  refresh()
  local info = state.current
  if info and #info.files == 0 then
    if info.op == "stash" then
      say(rel(path) .. " staged. No conflicts left.")
    else
      say(rel(path) .. " staged. No conflicts left — press <leader>gCc to continue the " .. info.op .. ".")
    end
  else
    say(("%s staged. %d conflicted file%s left."):format(rel(path), info and #info.files or 0, info and #info.files == 1 and "" or "s"))
  end
end

---Continue the operation with git's default message.
function M.continue()
  state.refresh()
  local info = state.current
  if not info then
    return say("Nothing to continue: no conflict in progress", vim.log.levels.WARN)
  end
  if #info.files > 0 then
    local names = vim.tbl_map(rel, info.files)
    return say(
      ("Not yet: %d file%s still conflicted (%s). Resolve and stage %s first."):format(
        #names,
        #names == 1 and " is" or "s are",
        table.concat(names, ", "),
        #names == 1 and "it" or "them"
      ),
      vim.log.levels.WARN
    )
  end
  if info.op == "stash" then
    return say(
      "A stash apply has no continue: the resolved changes are in your working tree, and git kept the stash entry (drop it with `git stash drop` when you no longer need it)."
    )
  end
  local result = state.run("-c", "core.editor=true", info.op, "--continue")
  refresh()
  if result.code ~= 0 then
    local next_info = state.current
    if next_info and #next_info.files > 0 then
      return say(state.summary() .. ": new conflicts in " .. #next_info.files .. " file(s). <leader>gCC shows them.")
    end
    return say(info.op .. " --continue failed: " .. vim.trim(result.stderr ~= "" and result.stderr or result.stdout), vim.log.levels.ERROR)
  end
  say(state.current and ("Continued: " .. state.summary()) or ("The " .. info.op .. " is finished."))
end

---Skip the current commit of a rebase.
function M.skip()
  local info = state.current
  if not info or info.op ~= "rebase" then
    return say("Skip only applies to a rebase", vim.log.levels.WARN)
  end
  local result = state.run("rebase", "--skip")
  refresh()
  if result.code ~= 0 and not state.current then
    return say("rebase --skip failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
  end
  say(state.current and ("Skipped. " .. state.summary()) or "Skipped. The rebase is finished.")
end

---Abort the operation after a confirmation.
function M.abort()
  state.refresh()
  local info = state.current
  if not info then
    return say("Nothing to abort: no conflict in progress", vim.log.levels.WARN)
  end
  if info.op == "stash" then
    return say(
      "A stash apply has no abort. To drop the conflicted changes: `git checkout -- <file>` per file (the stash entry is still saved).",
      vim.log.levels.WARN
    )
  end
  local choice = vim.fn.confirm(
    ("Abort: %s?\nEverything goes back to how it was before the %s."):format(state.summary(), info.op),
    "&Abort\n&Cancel",
    2
  )
  if choice ~= 1 then
    return
  end
  local result = state.run(info.op, "--abort")
  refresh()
  if result.code ~= 0 then
    return say(info.op .. " --abort failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
  end
  say("The " .. info.op .. " was aborted.")
end

---Open the whole-file 3-way view (diffview's merge tool).
function M.three_way()
  if not state.current then
    return say("No conflict in progress", vim.log.levels.WARN)
  end
  vim.cmd("DiffviewOpen")
end

---Lines of the explain panel for the current operation.
---@return string[]
function M.explain_lines()
  local info = state.current
  local lines = { state.summary(), "" }
  if not info then
    return lines
  end
  -- Git's markers: <<<<<<< opens "ours", >>>>>>> closes "theirs".
  local function role(section)
    return state.section("yours") == section and "YOURS" or "INCOMING"
  end
  vim.list_extend(lines, {
    "  " .. state.label("yours"),
    "  " .. state.label("incoming"),
    "",
    ("In git's own words, during this %s:"):format(info.op),
    '  "ours"   = the <<<<<<< (top) side    = ' .. role("ours"),
    '  "theirs" = the >>>>>>> (bottom) side = ' .. role("theirs"),
  })
  if info.op == "rebase" then
    vim.list_extend(lines, {
      "  A rebase replays your commits on top of the other branch, so git calls",
      "  the other branch \"ours\" and your commit \"theirs\". Here it's the opposite",
      "  of a merge; the keys below always mean YOURS and INCOMING.",
    })
  end
  vim.list_extend(lines, {
    "",
    "In a conflicted file:",
    "  <leader>gCo keep yours    <leader>gCt take incoming    <leader>gCb both    <leader>gCB both, incoming first",
    "  <leader>gC0 keep neither  ]x / [x next/previous conflict  <leader>gCr resolve view (pick single lines)",
    "Next steps:",
    "  <leader>gCa stage the file   <leader>gCc continue   <leader>gCA abort   <leader>gCC conflict center",
  })
  return lines
end

---@param lines string[]
---@param title string
---@return integer buf
---@return integer win
local function float(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local width = 20
  for _, l in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(l) + 2)
  end
  width = math.min(width, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].signcolumn = "no"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true, desc = "Close" })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true, desc = "Close" })
  return buf, win
end

function M.explain()
  if not state.current then
    state.refresh()
  end
  float(M.explain_lines(), "Which side is which")
end

---Lines of the center for the current state, and which row is which file.
---@return string[] lines
---@return table<integer, string> rows 1-based row -> file
function M.lines()
  local info = state.current
  if not info then
    return { state.summary() }, {}
  end
  local lines = {
    state.summary(),
    "",
    "  " .. state.label("yours"),
    "  " .. state.label("incoming"),
    "",
  }
  local rows = {}
  if #info.files == 0 then
    lines[#lines + 1] = info.op == "stash" and "All conflicts resolved." or "All conflicts resolved — c continues."
  else
    lines[#lines + 1] = "Conflicted files:"
    for _, file in ipairs(info.files) do
      lines[#lines + 1] = ("  %s (%d)"):format(rel(file), markers.count_file(file))
      rows[#lines] = file
    end
  end
  vim.list_extend(lines, {
    "",
    "<CR> resolve file · m 3-way view · s stage file · c continue"
      .. (info.op == "rebase" and " · S skip commit" or "")
      .. " · A abort · r refresh · ? explain · q close",
  })
  return lines, rows
end

function M.render()
  local p = M.panel
  if not p or not vim.api.nvim_win_is_valid(p.win) then
    M.panel = nil
    return
  end
  local lines, rows = M.lines()
  vim.bo[p.buf].modifiable = true
  vim.api.nvim_buf_set_lines(p.buf, 0, -1, false, lines)
  vim.bo[p.buf].modifiable = false
  p.rows = rows
end

---@return string?
local function file_under_cursor()
  local p = M.panel
  return p and p.rows[vim.api.nvim_win_get_cursor(p.win)[1]] or nil
end

function M.open()
  state.refresh()
  if not state.current then
    return say("Nothing to resolve: no merge, rebase, cherry-pick, revert or stash conflict in progress")
  end
  local lines, rows = M.lines()
  local buf, win = float(lines, "Conflicts")
  M.panel = { buf = buf, win = win, rows = rows }
  for row in pairs(rows) do
    pcall(vim.api.nvim_win_set_cursor, win, { row, 2 })
    break
  end
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
  end
  map("<CR>", function()
    local file = file_under_cursor()
    if not file then
      return
    end
    vim.api.nvim_win_close(win, true)
    M.panel = nil
    vim.cmd.edit(vim.fn.fnameescape(file))
    require("config.conflicts.inline").attach(vim.api.nvim_get_current_buf())
    local first = markers.in_buffer(0)[1]
    if first then
      vim.api.nvim_win_set_cursor(0, { first.start + 1, 0 })
      require("config.conflicts.resolve").open()
    end
  end, "Resolve this file")
  map("m", function()
    vim.api.nvim_win_close(win, true)
    M.panel = nil
    M.three_way()
  end, "3-way view")
  map("s", function()
    local file = file_under_cursor()
    if file then
      M.stage(file)
    end
  end, "Stage this file")
  map("c", M.continue, "Continue")
  map("S", M.skip, "Skip this commit (rebase)")
  map("A", M.abort, "Abort")
  map("r", refresh, "Refresh")
  map("?", M.explain, "Explain the sides")
end

return M
