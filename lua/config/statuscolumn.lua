---Fixed-slot status column. The built-in sign column fills its cells with the
---highest-priority signs whatever their kind, so error signs (one per source:
---basedpyright and mypy both sign the same line) push the lightbulb or a
---breakpoint out of view. Here every kind of sign owns a column:
---
---  [debug] [diagnostic] [action] [number] [git] [fold] text
---
---  debug       DAP breakpoints / stopped line, plus any other plugin's signs
---  diagnostic  the most severe diagnostic on the line, across all sources
---  action      the code-action lightbulb
---  git         gitsigns hunk marker
---
---Each slot shows its highest-priority sign. Windows with 'signcolumn' "no"
---get no sign slots; the number follows 'number'/'relativenumber'.
---@class ConfigStatuscolumn
local M = {}

---@alias StatuscolumnSlot "debug"|"diagnostic"|"action"|"git"

---Cell width of each sign slot.
---@type table<StatuscolumnSlot, integer>
M.width = { debug = 2, diagnostic = 2, action = 2, git = 1 }

---@type table<integer, string>
local ns_names = {}

---@param id integer
---@return string
local function ns_name(id)
  local name = ns_names[id]
  if name == nil then
    for n, i in pairs(vim.api.nvim_get_namespaces()) do
      ns_names[i] = n
    end
    name = ns_names[id] or "" -- anonymous namespace
    ns_names[id] = name
  end
  return name
end

---Which slot a sign from namespace `name` belongs to.
---@param name string
---@return StatuscolumnSlot
function M.slot(name)
  if name:find("diagnostic%.signs$") then
    return "diagnostic"
  elseif name == "nvim-lightbulb" then
    return "action"
  elseif name:find("^gitsigns") then
    return "git"
  end
  return "debug"
end

---@param sign vim.api.keyset.extmark_details?
---@param width integer
---@return string
local function cell(sign, width)
  if not sign then
    return string.rep(" ", width)
  end
  local text = vim.fn.strcharpart(sign.sign_text, 0, width)
  if vim.fn.strdisplaywidth(text) > width then
    text = vim.fn.strcharpart(text, 0, 1)
  end
  text = text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
  text = text:gsub("%%", "%%%%")
  if sign.sign_hl_group then
    return "%#" .. sign.sign_hl_group .. "#" .. text .. "%*"
  end
  return text
end

---The column for one screen line, as a 'statuscolumn' format string.
---@param win integer
---@param lnum integer 1-based buffer line
---@param relnum integer
---@param virtnum integer 0 for the line itself, ~= 0 for wrapped/virtual lines
---@return string
function M.build(win, lnum, relnum, virtnum)
  local buf = vim.api.nvim_win_get_buf(win)
  local wo = vim.wo[win]
  local parts = {}

  local signs = wo.signcolumn ~= "no"
  ---@type table<StatuscolumnSlot, vim.api.keyset.extmark_details>
  local best = {}
  if signs and virtnum == 0 then
    local row = lnum - 1
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, { row, 0 }, { row, -1 }, { details = true, type = "sign" })) do
      local d = mark[4]
      if d and d.sign_text then
        local slot = M.slot(ns_name(d.ns_id))
        local cur = best[slot]
        if not cur or (d.priority or 0) > (cur.priority or 0) then
          best[slot] = d
        end
      end
    end
  end

  if signs then
    parts[#parts + 1] = cell(best.debug, M.width.debug)
    parts[#parts + 1] = cell(best.diagnostic, M.width.diagnostic)
    parts[#parts + 1] = cell(best.action, M.width.action)
  end

  if wo.number or wo.relativenumber then
    local text = ""
    if virtnum == 0 then
      text = tostring((wo.relativenumber and (relnum ~= 0 or not wo.number)) and relnum or lnum)
    end
    local width = math.max(wo.numberwidth - 1, #tostring(vim.api.nvim_buf_line_count(buf)))
    local hl = (relnum == 0 and wo.cursorline) and "CursorLineNr" or "LineNr"
    parts[#parts + 1] = "%#" .. hl .. "#" .. string.rep(" ", width - #text) .. text .. " %*"
  end

  if signs then
    parts[#parts + 1] = cell(best.git, M.width.git)
  end
  parts[#parts + 1] = "%C"
  return table.concat(parts)
end

---'statuscolumn' entry point (evaluated per screen line).
---@return string
function M.render()
  return M.build(vim.g.statusline_winid, vim.v.lnum, vim.v.relnum, vim.v.virtnum)
end

function M.setup()
  vim.o.statuscolumn = "%!v:lua.require'config.statuscolumn'.render()"
end

return M
