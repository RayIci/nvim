---Resolve view: a tab for the conflicts of one file. Top left YOURS, top right
---INCOMING (each line with a [x]/[ ] mark), bottom RESULT: the file around
---the conflict as it will read once the current choice is applied, each line
---coloured by the side it came from. Single keys choose whole sides, keep or
---drop single lines, reorder them, or edit the result by hand; <CR> writes the
---choice into the file and moves to the next conflict.
---@class ConflictsResolve
local M = {}

local markers = require("config.conflicts.markers")
local state = require("config.conflicts.state")

local ns = vim.api.nvim_create_namespace("config.conflicts.resolve")
local CONTEXT = 5

local HINT = "o yours · t incoming · b both · B both (incoming first) · x neither · <Space> keep/drop line"
  .. " · J/K move · e edit · <CR> apply · n/p next/prev · u undo · ? explain · q close"

---@class ResolveEntry
---@field role ConflictRole
---@field i integer line index in that side

---@class ResolveView
---@field target integer the conflicted file's buffer
---@field tab integer
---@field wins { yours: integer, incoming: integer, result: integer }
---@field bufs { yours: integer, incoming: integer, result: integer }
---@field index integer current conflict (1-based)
---@field conflict Conflict?
---@field kept ResolveEntry[]
---@field chosen boolean whether anything was chosen for this conflict
---@field manual string[]? hand-edited result
---@field result_rows table<integer, integer> result buffer row -> kept index
---@field last { tick: integer, index: integer }? last apply, for u

---@type ResolveView?
M.view = nil

---@param role ConflictRole
---@return string[]
local function lines_of(role)
  local v = assert(M.view)
  return v.conflict and markers.side(v.conflict, role) or {}
end

---The composed result lines and, per line, the role it came from.
---@return string[] lines
---@return (ConflictRole|"manual")[] origins
function M.composed()
  local v = assert(M.view)
  if v.manual then
    local origins = {}
    for i = 1, #v.manual do
      origins[i] = "manual"
    end
    return vim.deepcopy(v.manual), origins
  end
  local lines, origins = {}, {}
  for _, e in ipairs(v.kept) do
    lines[#lines + 1] = lines_of(e.role)[e.i]
    origins[#origins + 1] = e.role
  end
  return lines, origins
end

---@param role ConflictRole
---@param i integer
---@return integer?
local function kept_index(role, i)
  for k, e in ipairs(assert(M.view).kept) do
    if e.role == role and e.i == i then
      return k
    end
  end
end

---@param choice "yours"|"incoming"|"both"|"both_incoming_first"|"none"
function M.choose(choice)
  local v = assert(M.view)
  local kept = {}
  local function add(role)
    for i = 1, #lines_of(role) do
      kept[#kept + 1] = { role = role, i = i }
    end
  end
  if choice == "yours" then
    add("yours")
  elseif choice == "incoming" then
    add("incoming")
  elseif choice == "both" then
    add("yours")
    add("incoming")
  elseif choice == "both_incoming_first" then
    add("incoming")
    add("yours")
  end
  v.kept, v.manual, v.chosen = kept, nil, true
  M.render()
end

---Keep or drop one line of a side. A newly kept line goes in source order
---among the kept lines of its side, or at the end.
---@param role ConflictRole
---@param i integer
function M.toggle(role, i)
  local v = assert(M.view)
  if i < 1 or i > #lines_of(role) then
    return
  end
  v.manual, v.chosen = nil, true
  local k = kept_index(role, i)
  if k then
    table.remove(v.kept, k)
    return M.render()
  end
  local pos = #v.kept + 1
  local after
  for idx, e in ipairs(v.kept) do
    if e.role == role and e.i < i then
      after = idx
    end
  end
  if after then
    pos = after + 1
  else
    for idx, e in ipairs(v.kept) do
      if e.role == role and e.i > i then
        pos = idx
        break
      end
    end
  end
  table.insert(v.kept, pos, { role = role, i = i })
  M.render()
end

---Move kept entry `k` by `delta` places.
---@param k integer
---@param delta 1|-1
function M.move(k, delta)
  local v = assert(M.view)
  local to = k + delta
  if not v.kept[k] or to < 1 or to > #v.kept then
    return
  end
  v.kept[k], v.kept[to] = v.kept[to], v.kept[k]
  M.render()
  if vim.api.nvim_get_current_win() == v.wins.result then
    for row, idx in pairs(v.result_rows) do
      if idx == to then
        vim.api.nvim_win_set_cursor(v.wins.result, { row + 1, 0 })
      end
    end
  end
end

---The kept index under the cursor: in RESULT the line's entry, in a side
---pane that line's entry if kept.
---@return integer?
local function kept_under_cursor()
  local v = assert(M.view)
  local win = vim.api.nvim_get_current_win()
  local row = vim.api.nvim_win_get_cursor(win)[1]
  if win == v.wins.result then
    return v.result_rows[row - 1]
  end
  local role = win == v.wins.yours and "yours" or "incoming"
  return kept_index(role, row)
end

---Edit the composed result by hand in a float; q or <CR> keeps the text.
function M.edit()
  local v = assert(M.view)
  local lines = M.composed()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.max(5, math.min(#lines + 2, math.floor(vim.o.lines * 0.6)))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " Edit the result — q or <CR> (normal mode) when done ",
    title_pos = "center",
  })
  local ft = vim.bo[v.target].filetype
  local lang = vim.treesitter.language.get_lang(ft)
  if lang then
    pcall(vim.treesitter.start, buf, lang)
  end
  local function done()
    if not M.view then
      return
    end
    M.view.manual = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    M.view.chosen = true
    pcall(vim.api.nvim_win_close, win, true)
    M.render()
  end
  vim.keymap.set("n", "q", done, { buffer = buf, desc = "Keep this text" })
  vim.keymap.set("n", "<CR>", done, { buffer = buf, desc = "Keep this text" })
end

---Write the current choice into the file and move to the next conflict.
function M.apply()
  local v = assert(M.view)
  if not v.conflict then
    return
  end
  if not v.chosen then
    vim.notify("Nothing chosen yet: o, t, b, B, x, or pick lines with <Space>", vim.log.levels.WARN)
    return
  end
  local c = markers.in_buffer(v.target)[v.index]
  if not c then
    return M.load(1)
  end
  markers.apply(v.target, c, (M.composed()))
  v.last = { tick = vim.api.nvim_buf_get_changedtick(v.target), index = v.index }
  require("config.conflicts.inline").update(v.target)
  M.load(v.index)
end

---Undo the last apply, if the file did not change since.
function M.undo()
  local v = assert(M.view)
  if not v.last or vim.api.nvim_buf_get_changedtick(v.target) ~= v.last.tick then
    vim.notify("Nothing to undo here (the file changed since); undo in the file with u", vim.log.levels.WARN)
    return
  end
  local index = v.last.index
  vim.api.nvim_buf_call(v.target, function()
    vim.cmd("silent undo")
  end)
  v.last = nil
  require("config.conflicts.inline").attach(v.target)
  M.load(index)
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

---Redraw the three panes from the view state.
function M.render()
  local v = M.view
  if not v or not vim.api.nvim_tabpage_is_valid(v.tab) then
    return
  end
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(v.target), ":.")
  if not v.conflict then
    set_lines(v.bufs.yours, {})
    set_lines(v.bufs.incoming, {})
    set_lines(v.bufs.result, {
      ("✓ All conflicts in %s are resolved."):format(file),
      "",
      "Save the file, then press <leader>gCa to stage it (or s in the conflict center, <leader>gCC).",
      "q closes this view.",
    })
    vim.wo[v.wins.result].winbar = " RESULT · " .. file .. " · resolved"
    return
  end

  -- Side panes: the lines with a [x]/[ ] mark.
  for _, role in ipairs({ "yours", "incoming" }) do
    local buf = v.bufs[role]
    local lines = lines_of(role)
    set_lines(buf, #lines > 0 and lines or { "" })
    if #lines == 0 then
      vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
        virt_text = { { "(no lines on this side)", "Comment" } },
        virt_text_pos = "overlay",
      })
    end
    for i = 1, #lines do
      local on = kept_index(role, i) ~= nil
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        virt_text = { { on and "[x] " or "[ ] ", on and "DiagnosticOk" or "Comment" } },
        virt_text_pos = "inline",
        line_hl_group = on and (role == "yours" and "ConflictYours" or "ConflictIncoming") or nil,
      })
    end
    vim.wo[v.wins[role]].winbar = " " .. state.label(role)
  end

  -- RESULT: context above, the composed lines, context below.
  local all = vim.api.nvim_buf_get_lines(v.target, 0, -1, false)
  local c = v.conflict
  local above = {}
  for row = math.max(0, c.start - CONTEXT), c.start - 1 do
    above[#above + 1] = all[row + 1]
  end
  local below = {}
  for row = c.finish + 1, math.min(#all - 1, c.finish + CONTEXT) do
    below[#below + 1] = all[row + 1]
  end
  local composed, origins = M.composed()
  local lines = vim.list_extend(vim.list_extend(vim.deepcopy(above), composed), below)
  set_lines(v.bufs.result, #lines > 0 and lines or { "" })
  v.result_rows = {}
  local hl = { yours = "ConflictYours", incoming = "ConflictIncoming", manual = "ConflictBase" }
  for i = 1, #above do
    vim.api.nvim_buf_set_extmark(v.bufs.result, ns, i - 1, 0, { line_hl_group = "Comment", priority = 1 })
  end
  for i, origin in ipairs(origins) do
    local row = #above + i - 1
    vim.api.nvim_buf_set_extmark(v.bufs.result, ns, row, 0, { line_hl_group = hl[origin] })
    if origin ~= "manual" then
      v.result_rows[row] = i
    end
  end
  for i = 1, #below do
    vim.api.nvim_buf_set_extmark(v.bufs.result, ns, #above + #composed + i - 1, 0, { line_hl_group = "Comment" })
  end
  if #composed == 0 then
    local row = math.max(0, #above - 1)
    vim.api.nvim_buf_set_extmark(v.bufs.result, ns, row, 0, {
      virt_lines = {
        {
          {
            v.chosen and "  (the conflict is removed: neither side is kept)"
              or "  (nothing chosen yet — the conflict stays until you choose)",
            "Comment",
          },
        },
      },
      virt_lines_above = #above == 0,
    })
  end
  -- Keys below the preview (virtual lines above line 1 stay hidden until
  -- the window is scrolled).
  local last = vim.api.nvim_buf_line_count(v.bufs.result) - 1
  vim.api.nvim_buf_set_extmark(v.bufs.result, ns, last, 0, {
    virt_lines = { { { "" } }, { { HINT, "Comment" } } },
  })
  local count = #markers.in_buffer(v.target)
  vim.wo[v.wins.result].winbar = (" RESULT · conflict %d/%d · %s · %s"):format(
    v.index,
    count,
    file,
    state.summary()
  )
end

---Show conflict `index` of the target (clamped), resetting the choice.
---@param index integer
function M.load(index)
  local v = assert(M.view)
  local conflicts = markers.in_buffer(v.target)
  if #conflicts == 0 then
    v.conflict, v.index = nil, 0
  else
    v.index = math.max(1, math.min(index, #conflicts))
    v.conflict = conflicts[v.index]
  end
  v.kept, v.manual, v.chosen = {}, nil, false
  M.render()
end

---@param delta 1|-1
function M.step(delta)
  local v = assert(M.view)
  local n = #markers.in_buffer(v.target)
  if n == 0 then
    return
  end
  M.load((v.index - 1 + delta) % n + 1)
end

function M.close()
  local v = M.view
  M.view = nil
  if v and vim.api.nvim_tabpage_is_valid(v.tab) then
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.api.nvim_set_current_tabpage(v.tab)
      vim.cmd.tabclose()
    end
  end
end

---@param buf integer
---@param role ConflictRole|"result"
local function set_keys(buf, role)
  local function map(mode, lhs, fn, desc)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, desc = desc, nowait = true })
  end
  map("n", "o", function()
    M.choose("yours")
  end, "Keep yours")
  map("n", "t", function()
    M.choose("incoming")
  end, "Take incoming")
  map("n", "b", function()
    M.choose("both")
  end, "Keep both (yours first)")
  map("n", "B", function()
    M.choose("both_incoming_first")
  end, "Keep both (incoming first)")
  map("n", "x", function()
    M.choose("none")
  end, "Keep neither")
  map("n", "<Space>", function()
    if role == "result" then
      local k = kept_under_cursor()
      local e = k and M.view.kept[k]
      if e then
        M.toggle(e.role, e.i)
      end
    else
      M.toggle(role, vim.api.nvim_win_get_cursor(0)[1])
    end
  end, "Keep/drop this line")
  if role ~= "result" then
    map("x", "<Space>", function()
      local a, b = vim.fn.line("v"), vim.fn.line(".")
      vim.cmd("normal! \27")
      for i = math.min(a, b), math.max(a, b) do
        M.toggle(role, i)
      end
    end, "Keep/drop these lines")
  end
  map("n", "J", function()
    local k = kept_under_cursor()
    if k then
      M.move(k, 1)
    end
  end, "Move this kept line down")
  map("n", "K", function()
    local k = kept_under_cursor()
    if k then
      M.move(k, -1)
    end
  end, "Move this kept line up")
  map("n", "e", M.edit, "Edit the result by hand")
  map("n", "<CR>", M.apply, "Apply and go to the next conflict")
  map("n", "n", function()
    M.step(1)
  end, "Next conflict (without applying)")
  map("n", "p", function()
    M.step(-1)
  end, "Previous conflict (without applying)")
  map("n", "u", M.undo, "Undo the last apply")
  map("n", "?", function()
    require("config.conflicts.center").explain()
  end, "Explain the sides")
  map("n", "q", M.close, "Close")
end

---@param name string
---@param ft string
---@return integer
local function scratch(name, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, ("conflict://%s/%d"):format(name, buf))
  local lang = vim.treesitter.language.get_lang(ft)
  if lang then
    pcall(vim.treesitter.start, buf, lang) -- highlight without filetype (no LSP)
  end
  return buf
end

---Open the resolve view on `buf` (default current), at the conflict under
---the cursor or the file's first.
---@param buf? integer
function M.open(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local conflicts = markers.in_buffer(buf)
  if #conflicts == 0 then
    vim.notify("No conflicts in this buffer", vim.log.levels.INFO)
    return
  end
  local index = 1
  if vim.api.nvim_get_current_buf() == buf then
    local _, i = markers.at(conflicts, vim.api.nvim_win_get_cursor(0)[1] - 1)
    index = i or 1
  end
  if M.view then
    M.close()
  end
  local ft = vim.bo[buf].filetype
  vim.cmd.tabnew()
  local tab = vim.api.nvim_get_current_tabpage()
  local placeholder = vim.api.nvim_get_current_buf()
  local bufs = { yours = scratch("yours", ft), incoming = scratch("incoming", ft), result = scratch("result", ft) }
  local wins = {}
  wins.yours = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(wins.yours, bufs.yours)
  vim.cmd("rightbelow vsplit")
  wins.incoming = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(wins.incoming, bufs.incoming)
  vim.cmd("botright split")
  wins.result = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(wins.result, bufs.result)
  vim.api.nvim_win_set_height(wins.result, math.floor(vim.o.lines * 0.45))
  if vim.api.nvim_buf_is_valid(placeholder) and placeholder ~= bufs.yours then
    pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
  end
  for role, w in pairs(wins) do
    vim.wo[w].number = role ~= "result"
    vim.wo[w].relativenumber = false
    vim.wo[w].wrap = false
    vim.wo[w].foldenable = false
    set_keys(bufs[role], role)
  end
  M.view = {
    target = buf,
    tab = tab,
    wins = wins,
    bufs = bufs,
    index = index,
    kept = {},
    chosen = false,
    result_rows = {},
  }
  -- Closing any pane (or the tab) ends the view.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup("config.conflicts.resolve", { clear = true }),
    callback = function(ev)
      local v = M.view
      if v and vim.list_contains({ v.wins.yours, v.wins.incoming, v.wins.result }, tonumber(ev.match)) then
        vim.schedule(M.close)
      end
    end,
  })
  M.load(index)
  vim.api.nvim_set_current_win(wins.yours)
end

return M
