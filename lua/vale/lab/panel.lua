---:ValeLab side panel (current slot + candidates + samples/LSP) and the
---palette strip (every slot, locked or pending).
local contrast = require("vale.lab.contrast")

local M = {}

local ns = vim.api.nvim_create_namespace("vale.lab.panel")

---Highlight group that paints text in `hex` (recreated after every load,
---since `hi clear` wipes it).
---@param hex string
---@param bg? boolean paint the background instead
---@return string
function M.swatch(hex, bg)
  local name = (bg and "ValeLabBg" or "ValeLabFg") .. hex:sub(2):upper()
  vim.api.nvim_set_hl(0, name, bg and { bg = hex } or { fg = hex })
  return name
end

---@class ValeLabLine
---@field text string
---@field hl? { [1]: integer, [2]: integer, [3]: string }[] col_start, col_end, group

---@param buf integer
---@param lines ValeLabLine[]
local function paint(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    vim.tbl_map(function(l)
      return l.text
    end, lines)
  )
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, l in ipairs(lines) do
    for _, h in ipairs(l.hl or {}) do
      local end_col = h[2] == -1 and #l.text or h[2]
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, h[1], { end_col = end_col, hl_group = h[3] })
    end
  end
  vim.bo[buf].modifiable = false
end

---@param s table lab state (see lab/init.lua)
function M.render_panel(s)
  local slot = s.slots[s.slot_i]
  local lines = {} ---@type ValeLabLine[]
  local function add(text, hl)
    lines[#lines + 1] = { text = text, hl = hl }
  end

  add((" vale-%s  ·  slot %d/%d  ·  %s"):format(s.variant, s.slot_i, #s.slots, slot.phase), {
    { 0, -1, "Title" },
  })
  add("")
  add(" " .. slot.slot, { { 0, -1, "Keyword" } })
  add(" " .. slot.label, { { 0, -1, "Comment" } })
  local on_hex = s.lookup(slot.on)
  add((" measured against %s %s"):format(slot.on, on_hex), { { 0, -1, "NonText" } })
  add("")

  for i, cand in ipairs(s.cands) do
    local marker = i == s.cand_i and "▶" or " "
    local ratio = contrast.ratio(cand.hex, on_hex)
    local low = slot.text and ratio < contrast.TEXT_MIN
    local text = (" %s %d ████ %s  %5.1f:1%s  %s"):format(
      marker,
      i,
      cand.hex,
      ratio,
      low and " ⚠" or "  ",
      cand.tag
    )
    local sw_start = #(" %s %d "):format(marker, i)
    local hl = { { sw_start, sw_start + #"████", M.swatch(cand.hex) } }
    if i == s.cand_i then
      hl[#hl + 1] = { 0, #(" " .. marker), "DiagnosticInfo" }
    end
    if low then
      local at = text:find("⚠", 1, true) - 1
      hl[#hl + 1] = { at, at + #"⚠", "DiagnosticWarn" }
    end
    add(text, hl)
  end
  if s.locked[slot.slot] then
    add("")
    add(" ✓ locked", { { 0, -1, "DiagnosticOk" } })
  end

  add("")
  add(" ]c [c  candidate     ]s [s  slot", { { 0, -1, "NonText" } })
  add(" <CR>   lock          <Tab>  samples", { { 0, -1, "NonText" } })
  add(" v      night/day     q / Q  close / keep", { { 0, -1, "NonText" } })
  add("")
  add((" samples  page %d/%d"):format(s.page, s.page_count), { { 0, -1, "Title" } })
  for _, sample in ipairs(s.page_samples) do
    local clients = sample.buf
        and vim.tbl_map(
          function(cl)
            return cl.name
          end,
          vim.tbl_filter(function(cl)
            return cl.name ~= "copilot"
          end, vim.lsp.get_clients({ bufnr = sample.buf }))
        )
      or {}
    local dot = #clients > 0 and "●" or "○"
    local text = (" %s %-24s %s"):format(dot, sample.name, table.concat(clients, ","))
    add(text, { { 1, 1 + #dot, #clients > 0 and "DiagnosticOk" or "NonText" } })
  end
  paint(s.bufs.panel, lines)
end

---@param s table lab state
function M.render_strip(s)
  local text, hl = " ", {}
  local phase
  for i, slot in ipairs(s.slots) do
    if slot.phase ~= phase then
      phase = slot.phase
      local label = (i > 1 and "  " or "") .. phase .. " "
      hl[#hl + 1] = { #text + (i > 1 and 2 or 0), #text + #label, "NonText" }
      text = text .. label
    end
    local ch = s.locked[slot.slot] and "█" or "▒"
    local start = #text
    text = text .. ch
    hl[#hl + 1] = { start, start + #ch, M.swatch(s.lookup(slot.slot)) }
    if i == s.slot_i then
      hl[#hl + 1] = { start, start + #ch, "ValeLabCurrent" }
    end
  end
  vim.api.nvim_set_hl(0, "ValeLabCurrent", { underline = true, sp = s.lookup("base.fg"), bold = true })
  local locked = vim.tbl_count(s.locked)
  paint(s.bufs.strip, {
    { text = text, hl = hl },
    {
      text = (" █ locked  ▒ pending  ·  %d/%d locked"):format(locked, #s.slots),
      hl = { { 0, -1, "NonText" } },
    },
  })
end

return M
