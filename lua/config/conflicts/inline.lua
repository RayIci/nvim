---Inline conflicts: in each conflicted file (from the current operation's
---unmerged list) both sides are highlighted, marker lines carry role labels
---("▼ YOURS · feature …"), and buffer-local keys resolve the conflict under
---the cursor by role. Marks follow edits; when a buffer has no markers left it
---is detached and the user is told to stage it.
---@class ConflictsInline
local M = {}

local markers = require("config.conflicts.markers")
local state = require("config.conflicts.state")

local ns = vim.api.nvim_create_namespace("config.conflicts")

---@type table<integer, true> attached buffers
M.attached = {}

---Highlight groups by role. Themes that style git-conflict.nvim's groups
---(vale does) keep their colours: yours uses GitConflictCurrent, incoming
---GitConflictIncoming, the ancestor GitConflictAncestor.
function M.set_highlights()
  local function pick(name, fallback)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return (hl.bg or hl.fg) and { link = name } or { link = fallback }
  end
  vim.api.nvim_set_hl(0, "ConflictYours", pick("GitConflictCurrent", "DiffAdd"))
  vim.api.nvim_set_hl(0, "ConflictIncoming", pick("GitConflictIncoming", "DiffChange"))
  vim.api.nvim_set_hl(0, "ConflictBase", pick("GitConflictAncestor", "DiffText"))
  vim.api.nvim_set_hl(0, "ConflictYoursLabel", pick("GitConflictCurrentLabel", "DiffAdd"))
  vim.api.nvim_set_hl(0, "ConflictIncomingLabel", pick("GitConflictIncomingLabel", "DiffChange"))
  vim.api.nvim_set_hl(0, "ConflictBaseLabel", pick("GitConflictAncestorLabel", "DiffText"))
end

---@param section "ours"|"theirs"
---@return ConflictRole
local function role_of(section)
  return state.section("yours") == section and "yours" or "incoming"
end

---@param role ConflictRole
---@return string
local function group(role)
  return role == "yours" and "ConflictYours" or "ConflictIncoming"
end

---Draw highlights and labels for every conflict in `buf`.
---@param buf integer
---@return Conflict[]
function M.render(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local conflicts = markers.in_buffer(buf)
  local top, bottom = role_of("ours"), role_of("theirs")
  for _, c in ipairs(conflicts) do
    local function line_hl(from, to, hl)
      for row = from, to do
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { line_hl_group = hl, priority = 50 })
      end
    end
    local ours_end = (c.base_marker or c.sep) - 1
    line_hl(c.start + 1, ours_end, group(top))
    if c.base_marker then
      line_hl(c.base_marker + 1, c.sep - 1, "ConflictBase")
    end
    line_hl(c.sep + 1, c.finish - 1, group(bottom))
    local function label(row, text, hl)
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { " " .. text .. " ", hl } },
        virt_text_pos = "eol",
        line_hl_group = hl,
        priority = 60,
      })
    end
    label(c.start, "▼ " .. state.label(top), group(top) .. "Label")
    if c.base_marker then
      label(c.base_marker, "▼ BEFORE (common ancestor)", "ConflictBaseLabel")
    end
    label(c.sep, "▼ " .. state.label(bottom), group(bottom) .. "Label")
    label(c.finish, "▲ end of conflict", group(bottom) .. "Label")
  end
  return conflicts
end

---Resolve the conflict under the cursor with a whole-side choice.
---@param choice "yours"|"incoming"|"both"|"both_incoming_first"|"none"
function M.choose(choice)
  local buf = vim.api.nvim_get_current_buf()
  local c = markers.at(markers.in_buffer(buf), vim.api.nvim_win_get_cursor(0)[1] - 1)
  if not c then
    vim.notify("No conflict under the cursor", vim.log.levels.WARN)
    return
  end
  markers.apply(buf, c, markers.choose(c, choice))
  M.update(buf)
end

---Jump to the next/previous conflict (wrapping).
---@param dir 1|-1
function M.jump(dir)
  local conflicts = markers.in_buffer(0)
  if #conflicts == 0 then
    vim.notify("No conflicts in this buffer", vim.log.levels.INFO)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local target
  if dir > 0 then
    for _, c in ipairs(conflicts) do
      if c.start > row then
        target = c
        break
      end
    end
    target = target or conflicts[1]
  else
    for i = #conflicts, 1, -1 do
      if conflicts[i].start < row then
        target = conflicts[i]
        break
      end
    end
    target = target or conflicts[#conflicts]
  end
  vim.api.nvim_win_set_cursor(0, { target.start + 1, 0 })
end

---Conflicts of the current buffer as quickfix items.
---@return table[]
function M.qf_items()
  local buf = vim.api.nvim_get_current_buf()
  local items = {}
  for i, c in ipairs(markers.in_buffer(buf)) do
    items[#items + 1] = {
      bufnr = buf,
      lnum = c.start + 1,
      text = ("conflict %d: %s ↔ %s"):format(i, state.name("yours"), state.name("incoming")),
    }
  end
  return items
end

---Buffer-local keys, described with the branch each one keeps.
---@param buf integer
local function set_keys(buf)
  local yours, incoming = state.name("yours"), state.name("incoming")
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  map("<leader>gCo", function()
    M.choose("yours")
  end, ("Keep yours (%s)"):format(yours))
  map("<leader>gCt", function()
    M.choose("incoming")
  end, ("Take incoming (%s)"):format(incoming))
  map("<leader>gCb", function()
    M.choose("both")
  end, ("Keep both: %s, then %s"):format(yours, incoming))
  map("<leader>gCB", function()
    M.choose("both_incoming_first")
  end, ("Keep both: %s, then %s"):format(incoming, yours))
  map("<leader>gC0", function()
    M.choose("none")
  end, "Keep neither")
  for _, lhs in ipairs({ "<leader>gCn", "]x" }) do
    map(lhs, function()
      M.jump(1)
    end, "Next conflict")
  end
  for _, lhs in ipairs({ "<leader>gCp", "[x" }) do
    map(lhs, function()
      M.jump(-1)
    end, "Previous conflict")
  end
  map("<leader>gCQ", function()
    vim.fn.setqflist(M.qf_items(), "r")
    vim.cmd.copen()
  end, "List conflicts in quickfix")
  map("<leader>gCq", function()
    vim.fn.setqflist(M.qf_items(), "r")
    vim.cmd("Trouble qflist open")
  end, "List conflicts in Trouble")
end

local key_lhs = {
  "<leader>gCo",
  "<leader>gCt",
  "<leader>gCb",
  "<leader>gCB",
  "<leader>gC0",
  "<leader>gCn",
  "<leader>gCp",
  "<leader>gCQ",
  "<leader>gCq",
  "]x",
  "[x",
}

---@param buf integer
function M.detach(buf)
  if not M.attached[buf] then
    return
  end
  M.attached[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    if vim.b[buf].conflicts_hid_diagnostics then
      vim.b[buf].conflicts_hid_diagnostics = nil
      vim.diagnostic.enable(true, { bufnr = buf })
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    pcall(vim.api.nvim_del_augroup_by_name, "config.conflicts.buf." .. buf)
    for _, lhs in ipairs(key_lhs) do
      pcall(vim.keymap.del, "n", lhs, { buffer = buf })
    end
  end
end

---Re-render after an edit; detach and suggest staging once no marker is left.
---@param buf integer
function M.update(buf)
  if not M.attached[buf] or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if #M.render(buf) == 0 then
    M.detach(buf)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
    vim.notify(("%s has no conflicts left — save it and press <leader>gCa to stage it"):format(name))
  end
end

---Attach to `buf` when it is one of the current operation's conflicted files
---and still has markers.
---@param buf integer
function M.attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  if not state.is_conflicted(vim.api.nvim_buf_get_name(buf)) then
    M.detach(buf)
    return
  end
  if #M.render(buf) == 0 then
    M.detach(buf)
    return
  end
  set_keys(buf) -- also refreshes descriptions when the operation moved on
  if M.attached[buf] then
    return
  end
  M.attached[buf] = true
  -- Markers are syntax errors to every language server; hide that noise
  -- while the buffer has conflicts (restored on detach).
  if vim.diagnostic.is_enabled({ bufnr = buf }) then
    vim.b[buf].conflicts_hid_diagnostics = true
    vim.diagnostic.enable(false, { bufnr = buf })
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("config.conflicts.buf." .. buf, { clear = true }),
    buffer = buf,
    callback = function()
      M.update(buf)
    end,
  })
end

---Re-sync every loaded buffer with the current operation.
function M.sync()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if state.current then
      M.attach(buf)
    else
      M.detach(buf)
    end
  end
end

return M
