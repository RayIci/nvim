---Writes theme files. Palette values are edited in place: each `key = "…"`
---line inside its block has only its quoted value swapped, so comments,
---order and every other byte stay untouched (the table is never
---re-serialised). semantics.lua is small generated data and is rewritten.
local vale = require("vale")

local M = {}

---Swap the values of several slots in palette text.
---@param lines string[] palette (or template) lines
---@param edits table<string, string> "block.key" → value (hex or palette name)
---@return string[]|nil lines, string? err
function M.apply(lines, edits)
  local out = vim.deepcopy(lines)
  -- index "block.key" → line number, refusing duplicates
  local index, dup = {}, {}
  local block
  for i, line in ipairs(out) do
    local open = line:match("^%s*([%w_]+)%s*=%s*{%s*$")
    if open then
      block = open
    elseif line:match("^%s*},?%s*$") then
      block = nil
    elseif block then
      local key = line:match('^%s*([%w_]+)%s*=%s*"[^"]*"')
      if key then
        local slot = block .. "." .. key
        dup[slot] = index[slot] ~= nil
        index[slot] = i
      end
    end
  end
  for slot, value in pairs(edits) do
    local i = index[slot]
    if not i or dup[slot] then
      return nil, ("expected one %q line, found %s"):format(slot, i and "several" or "none")
    end
    local key = slot:match("%.([%w_]+)$")
    out[i] = out[i]:gsub("^(%s*" .. key .. '%s*=%s*")[^"]*(")', "%1" .. value .. "%2", 1)
  end
  return out
end

---@param path string
---@return string|nil err when an open buffer has unsaved changes
local function check_buffer(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 and vim.bo[bufnr].modified then
    return vim.fs.basename(path) .. " is open with unsaved changes; save or discard it first"
  end
end

---@param path string
local function refresh_buffer(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("checktime")
    end)
  end
end

---Serialise a theme's semantics overrides, dropping entries equal to what
---they would resolve to anyway. Returns nil when nothing differs.
---@param sem table file-shaped: role = name, night = {…}, day = {…}
---@param name string theme name (for the header)
---@return string[]|nil
function M.semantics_lines(sem, name)
  local default = require("vale.semantics")
  local top, variants = {}, {}
  for role, value in pairs(sem) do
    if type(value) == "string" and default[role] ~= value then
      top[role] = value
    end
  end
  for _, v in ipairs(vale.variants) do
    for role, value in pairs(sem[v] or {}) do
      if (top[role] or default[role]) ~= value then
        variants[v] = variants[v] or {}
        variants[v][role] = value
      end
    end
  end
  if vim.tbl_isempty(top) and vim.tbl_isempty(variants) then
    return nil
  end
  local out = {
    ("-- %s theme: roles that differ from vale's shared default mapping."):format(name),
    "-- Written by the vale studio on save; pure data.",
    "return {",
  }
  local function entries(t, indent)
    local keys = vim.tbl_keys(t)
    table.sort(keys)
    for _, k in ipairs(keys) do
      out[#out + 1] = ("%s%s = %q,"):format(indent, k, t[k])
    end
  end
  entries(top, "  ")
  for _, v in ipairs(vale.variants) do
    if variants[v] then
      out[#out + 1] = ("  %s = {"):format(v)
      entries(variants[v], "    ")
      out[#out + 1] = "  },"
    end
  end
  out[#out + 1] = "}"
  return out
end

---Save a theme: palette edits per variant and its semantics. Every edit is
---computed first, so a failure writes nothing.
---@param name string
---@param palette table<string, table<string, string>> variant → "block.key" → hex
---@param semantics? table file-shaped semantics (nil: leave semantics.lua alone)
---@return boolean ok, string? err
function M.save(name, palette, semantics)
  local writes = {} ---@type { path: string, lines: string[]|nil }[]
  for variant, edits in pairs(palette or {}) do
    if not vim.tbl_isempty(edits) then
      local path = vale.palette_path(name, variant)
      local err = check_buffer(path)
      if err then
        return false, err
      end
      local lines, aerr = M.apply(vim.fn.readfile(path), edits)
      if not lines then
        return false, vim.fs.basename(path) .. ": " .. aerr
      end
      writes[#writes + 1] = { path = path, lines = lines }
    end
  end
  if semantics then
    local path = vale.theme_path(name, "semantics.lua")
    local err = check_buffer(path)
    if err then
      return false, err
    end
    writes[#writes + 1] = { path = path, lines = M.semantics_lines(semantics, name) }
  end
  for _, w in ipairs(writes) do
    if w.lines then
      if vim.fn.writefile(w.lines, w.path) ~= 0 then
        return false, "could not write " .. w.path
      end
    elseif vim.uv.fs_stat(w.path) then
      os.remove(w.path)
    end
    refresh_buffer(w.path)
  end
  return true
end

return M
