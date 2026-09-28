---:ValeLab — pick vale's colours one slot at a time against real code.
---A dedicated tab: 2×3 grid of sample buffers, a side panel with the current
---slot's candidates (VS Code reference first) and a palette strip. Cycling a
---candidate repaints everything live without touching disk; <CR> writes the
---hex into the palette file. Edits to any vale file hot-reload the lab.
local vale = require("vale")
local panel = require("vale.lab.panel")
local writer = require("vale.lab.writer")

local M = {}

local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))) -- lua/vale
local samples_dir = vim.fs.joinpath(root, "lab", "samples")
local candidates_path = vim.fs.joinpath(root, "lab", "candidates.lua")
local locked_path = vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "vale-lab.json")

-- Sample files in display order; "terminal" is an ANSI colour table.
local SAMPLES = {
  "sample.py",
  "sample.ts",
  "csharp/Sample.cs",
  "java/src/main/java/sample/Sample.java",
  "rust/src/main.rs",
  "sample.lua",
  "sample.kt",
  "sample.sql",
  "sample.sh",
  "sample.json",
  "sample.yaml",
  "sample.md",
  "Dockerfile",
  "terminal",
}
local PER_PAGE = 6

---@type table|nil lab state while open
local S = nil

-- Persisted "locked" marks: { night = { ["base.bg"] = true }, day = {…} }.
local function read_locked()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(locked_path), "\n"))
  end)
  return (ok and type(data) == "table") and data or {}
end

local function save_locked(all)
  vim.fn.mkdir(vim.fs.dirname(locked_path), "p")
  vim.fn.writefile({ vim.json.encode(all) }, locked_path)
end

---Slots from the candidates file, keeping only ones the palette has.
local function read_slots()
  local ok, data = pcall(dofile, candidates_path)
  if not ok then
    vim.notify("vale lab: candidates.lua: " .. tostring(data), vim.log.levels.ERROR)
    return S and S.slots or {}
  end
  local p = vale.read_palette(S.variant)
  return vim.tbl_filter(function(slot)
    local block, key = slot.slot:match("^(%w+)%.([%w_]+)$")
    return block and p[block] and p[block][key] ~= nil
  end, data)
end

---Hex for "block.key" in the colours currently shown (preview included).
local function lookup(slot)
  local block, key = slot:match("^(%w+)%.([%w_]+)$")
  local c = vale.current.c
  if block == "ui" or block == "ansi" then
    return c[block][key]
  end
  return c[key]
end

---Candidates for the current slot: VS Code reference, current value, extras.
local function build_candidates()
  local slot = S.slots[S.slot_i]
  local block, key = slot.slot:match("^(%w+)%.([%w_]+)$")
  local ref = dofile(vim.fs.joinpath(root, "reference", "vscode_modern.lua"))[S.variant][block][key]
  local resolved = vale.resolve(vale.read_palette(S.variant))
  local current = (block == "ui" or block == "ansi") and resolved[block][key] or resolved[key]

  local list, seen = {}, {}
  local function push(hex, tag)
    hex = hex:upper()
    if seen[hex] then
      seen[hex].tag = seen[hex].tag .. " · " .. tag
      return
    end
    local cand = { hex = hex, tag = tag }
    seen[hex] = cand
    list[#list + 1] = cand
  end
  push(ref, "VS Code")
  push(current, "current")
  for _, hex in ipairs(slot[S.variant] or {}) do
    push(hex, "")
  end
  S.cands = list
  S.current_hex = current:upper()
end

---Page of samples currently in the grid.
local function page_samples()
  local out = {}
  for i = (S.page - 1) * PER_PAGE + 1, math.min(S.page * PER_PAGE, #SAMPLES) do
    out[#out + 1] = { name = SAMPLES[i] }
  end
  return out
end

-- ANSI table for the terminal sample.
local ANSI_SCRIPT = [[
for i in 0 1 2 3 4 5 6 7; do printf "\033[3${i}m  fg %-2d \033[0m" $i; done; echo
for i in 0 1 2 3 4 5 6 7; do printf "\033[9${i}m  fg %-2d \033[0m" $((i+8)); done; echo
for i in 0 1 2 3 4 5 6 7; do printf "\033[4${i}m  bg %-2d \033[0m" $i; done; echo
for i in 0 1 2 3 4 5 6 7; do printf "\033[10${i}m  bg %-2d \033[0m" $((i+8)); done; echo
echo; ls --color=always / | head -8; echo
git -c color.ui=always log --oneline --graph -6 2>/dev/null
exec sleep infinity
]]

local map_keys -- forward declaration

---Show a sample in a window (terminal is recreated so it picks up the
---current terminal_color_* values).
local function show_sample(win, sample)
  vim.api.nvim_win_call(win, function()
    if sample.name == "terminal" then
      vim.cmd("enew")
      vim.fn.jobstart({ "bash", "-c", ANSI_SCRIPT }, { term = true, cwd = vim.fn.stdpath("config") })
      vim.bo.bufhidden = "wipe"
    else
      vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(samples_dir, sample.name)))
    end
    sample.buf = vim.api.nvim_get_current_buf()
  end)
  map_keys(sample.buf)
end

local function fill_grid()
  S.page_samples = page_samples()
  for i, win in ipairs(S.wins.grid) do
    local sample = S.page_samples[i]
    if sample then
      show_sample(win, sample)
    else
      vim.api.nvim_win_call(win, function()
        vim.cmd("enew")
        vim.bo.bufhidden = "wipe"
      end)
      map_keys(vim.api.nvim_win_get_buf(win))
    end
  end
end

---Load the variant with the current preview and repaint the lab.
local function apply()
  local overrides = S.preview and { [S.slots[S.slot_i].slot] = S.preview } or nil
  vale.unload()
  local ok, err = pcall(vale.load, S.variant, overrides)
  if not ok then
    vim.notify("vale lab: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name, modeline = false })
  -- Terminal colours are fixed when a terminal starts: restart it on ANSI slots.
  if S.slots[S.slot_i].phase == "ansi" then
    for i, sample in ipairs(S.page_samples) do
      if sample.name == "terminal" then
        show_sample(S.wins.grid[i], sample)
      end
    end
  end
  panel.render_panel(S)
  panel.render_strip(S)
end

local function select_slot(i)
  S.slot_i = ((i - 1) % #S.slots) + 1
  S.preview = nil
  build_candidates()
  S.cand_i = 1
  for idx, cand in ipairs(S.cands) do
    if cand.hex == S.current_hex then
      S.cand_i = idx
    end
  end
  apply()
end

local function cycle(step)
  S.cand_i = ((S.cand_i - 1 + step) % #S.cands) + 1
  local hex = S.cands[S.cand_i].hex
  S.preview = hex ~= S.current_hex and hex or nil
  apply()
end

local function lock()
  local slot = S.slots[S.slot_i]
  local hex = S.cands[S.cand_i].hex
  local ok, err = writer.write(S.variant, slot.slot, hex)
  if not ok then
    vim.notify("vale lab: " .. err, vim.log.levels.ERROR)
    return
  end
  local all = read_locked()
  all[S.variant] = all[S.variant] or {}
  all[S.variant][slot.slot] = true
  save_locked(all)
  S.locked = all[S.variant]
  S.preview = nil
  build_candidates()
  apply()
  vim.notify(("vale lab: %s = %s (vale-%s)"):format(slot.slot, hex, S.variant))
end

---Re-read everything from disk (after an edit to any vale file).
local function reload()
  if not S then
    return
  end
  local name = S.slots[S.slot_i] and S.slots[S.slot_i].slot
  S.slots = read_slots()
  S.slot_i = 1
  for i, slot in ipairs(S.slots) do
    if slot.slot == name then
      S.slot_i = i
    end
  end
  local keep = S.preview
  build_candidates()
  S.preview = keep
  apply()
end

local function set_variant(variant)
  S.variant = variant
  S.locked = read_locked()[variant] or {}
  select_slot(S.slot_i)
end

local function next_page()
  S.page = S.page % S.page_count + 1
  fill_grid()
  apply()
end

-- File watchers: any .lua under lua/vale (palettes, semantics, groups,
-- integrations, candidates) triggers a debounced reload.
local function watch()
  local dirs = { "", "palettes", "groups", "integrations", "lab", "reference" }
  local timer = assert(vim.uv.new_timer())
  S.watchers = { timer }
  for _, sub in ipairs(dirs) do
    local w = assert(vim.uv.new_fs_event())
    w:start(vim.fs.joinpath(root, sub), {}, function(_, fname)
      if fname and fname:match("%.lua$") then
        timer:stop()
        timer:start(120, 0, vim.schedule_wrap(reload))
      end
    end)
    S.watchers[#S.watchers + 1] = w
  end
end

---@param keep boolean keep the vale variant active instead of restoring
function M.close(keep)
  if not S then
    return
  end
  local s = S
  S = nil
  for _, w in ipairs(s.watchers or {}) do
    if not w:is_closing() then
      w:close()
    end
  end
  pcall(vim.api.nvim_del_augroup_by_id, s.augroup)
  for buf in pairs(s.mapped) do
    if vim.api.nvim_buf_is_valid(buf) then
      for _, lhs in ipairs(s.lhs) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
      end
    end
  end
  if vim.api.nvim_tabpage_is_valid(s.tab) and #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(s.tab))
  end
  for _, buf in pairs(s.bufs) do
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  if keep then
    vim.cmd.colorscheme("vale-" .. s.variant)
  elseif s.prev_colors then
    pcall(vim.cmd.colorscheme, s.prev_colors)
  end
end

map_keys = function(buf)
  if S.mapped[buf] then
    return
  end
  S.mapped[buf] = true
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = "Vale lab: " .. desc })
  end
  map("]c", function()
    cycle(1)
  end, "next candidate")
  map("[c", function()
    cycle(-1)
  end, "previous candidate")
  map("]s", function()
    select_slot(S.slot_i + 1)
  end, "next slot")
  map("[s", function()
    select_slot(S.slot_i - 1)
  end, "previous slot")
  map("<CR>", lock, "lock candidate into palette")
  map("<Tab>", next_page, "next sample page")
  map("v", function()
    set_variant(S.variant == "night" and "day" or "night")
  end, "toggle night/day")
  map("q", function()
    M.close(false)
  end, "close and restore colorscheme")
  map("Q", function()
    M.close(true)
  end, "close and keep vale")
end

local function scratch(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "valelab"
  pcall(vim.api.nvim_buf_set_name, buf, name)
  return buf
end

local function style(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = true
  vim.wo[win].winfixwidth = true
  vim.wo[win].winfixheight = true
end

---@param variant? ValeVariant
function M.open(variant)
  variant = variant or "night"
  if S then
    vim.api.nvim_set_current_tabpage(S.tab)
    return set_variant(variant)
  end

  S = {
    variant = variant,
    prev_colors = vim.g.colors_name,
    page = 1,
    page_count = math.ceil(#SAMPLES / PER_PAGE),
    slot_i = 1,
    cand_i = 1,
    mapped = {},
    lhs = { "]c", "[c", "]s", "[s", "<CR>", "<Tab>", "v", "q", "Q" },
    lookup = lookup,
    wins = { grid = {} },
    bufs = {},
  }
  S.locked = read_locked()[variant] or {}
  S.slots = read_slots()
  vale.load(variant) -- lookup() needs vale.current before the first render

  vim.cmd("tabnew")
  S.tab = vim.api.nvim_get_current_tabpage()
  local main = vim.api.nvim_get_current_win()

  S.bufs.panel = scratch("vale-lab://panel")
  vim.cmd("vertical botright 50split")
  S.wins.panel = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(S.wins.panel, S.bufs.panel)
  style(S.wins.panel)

  vim.api.nvim_set_current_win(main)
  S.bufs.strip = scratch("vale-lab://strip")
  vim.cmd("belowright 3split")
  S.wins.strip = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(S.wins.strip, S.bufs.strip)
  style(S.wins.strip)

  -- 2 rows × 3 columns in the remaining area
  vim.api.nvim_set_current_win(main)
  vim.cmd("belowright split")
  local rows = { main, vim.api.nvim_get_current_win() }
  for _, row in ipairs(rows) do
    vim.api.nvim_set_current_win(row)
    vim.cmd("belowright vsplit")
    vim.cmd("belowright vsplit")
    vim.cmd("wincmd =")
  end
  for _, row in ipairs(rows) do
    vim.api.nvim_set_current_win(row)
    for _ = 1, 3 do
      S.wins.grid[#S.wins.grid + 1] = vim.api.nvim_get_current_win()
      vim.cmd("wincmd l")
    end
  end
  map_keys(S.bufs.panel)
  map_keys(S.bufs.strip)
  fill_grid()
  vim.api.nvim_set_current_win(S.wins.grid[1])

  S.augroup = vim.api.nvim_create_augroup("vale.lab", { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = S.augroup,
    callback = function()
      if S and not vim.api.nvim_tabpage_is_valid(S.tab) then
        M.close(false)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = S.augroup,
    callback = vim.schedule_wrap(function()
      if S then
        panel.render_panel(S)
      end
    end),
  })
  watch()
  set_variant(variant)
end

---@return boolean
function M.is_open()
  return S ~= nil
end

return M
