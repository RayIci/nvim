---vale: personal colorscheme (vale-night / vale-day), anchored on VS Code Modern.
---Layers: palettes/<variant>.lua (pure data) → semantics.lua (role → palette
---name) → groups/* and integrations/* (group → spec built from roles).
---@class Vale
local M = {}

---@alias ValeVariant "night"|"day"
---@alias ValeRoles table<string, string> role → "#RRGGBB"

local root = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))

M.blocks = { "base", "accent", "signal", "ansi", "ui" }

-- Terminal slot order for the named ansi keys (0-15).
M.ansi_order = {
  "black",
  "red",
  "green",
  "yellow",
  "blue",
  "magenta",
  "cyan",
  "white",
  "bright_black",
  "bright_red",
  "bright_green",
  "bright_yellow",
  "bright_blue",
  "bright_magenta",
  "bright_cyan",
  "bright_white",
}

-- Highlight modules, applied in order (later ones win on conflicts).
M.modules = {
  "vale.groups.editor",
  "vale.groups.syntax",
  "vale.groups.treesitter",
  "vale.groups.lsp",
  "vale.groups.diagnostics",
  "vale.integrations",
}

---@param variant ValeVariant
---@return string
function M.palette_path(variant)
  return vim.fs.joinpath(root, "palettes", variant .. ".lua")
end

---Read a palette fresh from disk (dofile, so edits are seen on reload).
---@param variant ValeVariant
---@return table
function M.read_palette(variant)
  return dofile(M.palette_path(variant))
end

---Resolve a palette into a flat colour table: base/accent/signal names at the
---top level, plus `ui` and `ansi` sub-tables with names resolved to hex.
---@param p table raw palette
---@param overrides? table<string, string> "block.key" → "#RRGGBB"
---@return table
function M.resolve(p, overrides)
  p = vim.deepcopy(p)
  for slot, hex in pairs(overrides or {}) do
    local block, key = slot:match("^(%w+)%.([%w_]+)$")
    if block and p[block] then
      p[block][key] = hex
    end
  end
  local c = {}
  for _, block in ipairs({ "base", "accent", "signal" }) do
    for k, v in pairs(p[block]) do
      c[k] = v
    end
  end
  for _, block in ipairs({ "ui", "ansi" }) do
    c[block] = {}
    for k, v in pairs(p[block]) do
      c[block][k] = v:sub(1, 1) == "#" and v or c[v]
    end
  end
  return c
end

---Map semantic roles to hex for a resolved palette.
---@param c table resolved palette
---@param variant ValeVariant
---@return ValeRoles
function M.roles(c, variant)
  local sem = require("vale.semantics")
  local names = vim.tbl_extend("force", sem, sem[variant] or {})
  local r = {}
  for role, name in pairs(names) do
    if type(name) == "string" then
      local ui = name:match("^ui%.(.+)$")
      r[role] = ui and c.ui[ui] or c[name]
      if not r[role] then
        error(("vale: role %q points at unknown palette name %q"):format(role, name))
      end
    end
  end
  return r
end

---Build every highlight group for a variant without applying it.
---@param variant ValeVariant
---@param overrides? table<string, string>
---@return table<string, vim.api.keyset.highlight> groups, table c, ValeRoles r
function M.build(variant, overrides)
  local c = M.resolve(M.read_palette(variant), overrides)
  local r = M.roles(c, variant)
  local groups = {}
  for _, mod in ipairs(M.modules) do
    for name, spec in pairs(require(mod)(r, c)) do
      groups[name] = spec
    end
  end
  return groups, c, r
end

---Drop cached vale modules so edits to semantics/groups/integrations apply.
function M.unload()
  for name in pairs(package.loaded) do
    if name == "vale.semantics" or name:match("^vale%.groups") or name:match("^vale%.integrations") then
      package.loaded[name] = nil
    end
  end
end

---Colours of the currently loaded variant (nil when vale is not active).
---@type { variant: ValeVariant, c: table, r: ValeRoles }|nil
M.current = nil

---Load a variant as the active colorscheme.
---@param variant ValeVariant
---@param overrides? table<string, string> "block.key" → "#RRGGBB" (lab preview)
function M.load(variant, overrides)
  local groups, c, r = M.build(variant, overrides)

  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
  vim.o.termguicolors = true
  vim.o.background = variant == "day" and "light" or "dark"
  vim.g.colors_name = "vale-" .. variant

  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  for i, key in ipairs(M.ansi_order) do
    vim.g["terminal_color_" .. (i - 1)] = c.ansi[key]
  end

  M.current = { variant = variant, c = c, r = r }
  -- lualine `require`s its theme; drop the cached table so edits and lab
  -- previews reach the statusline on the next ColorScheme.
  package.loaded["lualine.themes.vale-" .. variant] = nil
end

return M
