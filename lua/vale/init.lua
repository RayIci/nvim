---vale: theme engine. A theme is `themes/<name>/` in the config directory
---(night.lua and/or day.lua pure-data palettes, optional semantics.lua); each
---variant loads as the colorscheme `<name>-<variant>`.
---Layers: palette (pure data) → semantics (role → palette name: shared
---default, then theme, then variant overrides) → groups/* and integrations/*.
---@class Vale
local M = {}

---@alias ValeVariant "night"|"day"
---@alias ValeRoles table<string, string> role → "#RRGGBB"

---Unsaved studio edits applied on top of the files.
---@class ValeOverrides
---@field palette? table<string, string> "block.key" → "#RRGGBB"
---@field semantics? table replaces the theme's semantics.lua (same shape: role = name, night = {}, day = {})

M.variants = { "night", "day" }

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

---Directory holding every theme (user data, outside the plugin code).
---@return string
function M.themes_dir()
  return vim.fs.joinpath(vim.fn.stdpath("config") --[[@as string]], "themes")
end

---@param name string
---@param file? string file inside the theme directory
---@return string
function M.theme_path(name, file)
  local dir = vim.fs.joinpath(M.themes_dir(), name)
  return file and vim.fs.joinpath(dir, file) or dir
end

---@param name string
---@param variant ValeVariant
---@return string
function M.palette_path(name, variant)
  return M.theme_path(name, variant .. ".lua")
end

---Read a palette fresh from disk (dofile, so edits are seen on reload).
---@param name string
---@param variant ValeVariant
---@return table
function M.read_palette(name, variant)
  return dofile(M.palette_path(name, variant))
end

---A theme's own semantics overrides ({} when it has none).
---@param name string
---@return table
function M.read_semantics(name)
  local path = M.theme_path(name, "semantics.lua")
  return vim.uv.fs_stat(path) and dofile(path) or {}
end

---Every theme on disk with the variants it has, sorted by name.
---@return { name: string, variants: ValeVariant[] }[]
function M.list()
  local out = {}
  for name, kind in vim.fs.dir(M.themes_dir()) do
    if kind == "directory" then
      local variants = vim.tbl_filter(function(v)
        return vim.uv.fs_stat(M.palette_path(name, v)) ~= nil
      end, M.variants)
      if #variants > 0 then
        out[#out + 1] = { name = name, variants = variants }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
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

---Role → palette name after layering: shared default, the theme's
---semantics (its semantics.lua, or an unsaved replacement), then its
---per-variant table.
---@param name string
---@param variant ValeVariant
---@param theme_semantics? table replacement for the theme's semantics.lua
---@return table<string, string>
function M.role_names(name, variant, theme_semantics)
  local names = vim.deepcopy(require("vale.semantics"))
  local theme = theme_semantics or M.read_semantics(name)
  for role, value in pairs(theme) do
    if type(value) == "string" then
      names[role] = value
    end
  end
  for role, value in pairs(theme[variant] or {}) do
    names[role] = value
  end
  return names
end

---Map semantic roles to hex for a resolved palette.
---@param c table resolved palette
---@param names table<string, string> role → palette name (see role_names)
---@return ValeRoles
function M.roles(c, names)
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

---Build every highlight group for a theme variant without applying it.
---@param name string
---@param variant ValeVariant
---@param overrides? ValeOverrides
---@return table<string, vim.api.keyset.highlight> groups, table c, ValeRoles r
function M.build(name, variant, overrides)
  overrides = overrides or {}
  local c = M.resolve(M.read_palette(name, variant), overrides.palette)
  local r = M.roles(c, M.role_names(name, variant, overrides.semantics))
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

---The theme variant loaded last (nil before any vale theme loads).
---@type { name: string, variant: ValeVariant, c: table, r: ValeRoles }|nil
M.current = nil

---Load a theme variant as the active colorscheme `<name>-<variant>`.
---@param name string
---@param variant ValeVariant
---@param overrides? ValeOverrides unsaved studio edits
function M.load(name, variant, overrides)
  local groups, c, r = M.build(name, variant, overrides)

  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
  vim.o.termguicolors = true
  vim.o.background = variant == "day" and "light" or "dark"
  vim.g.colors_name = name .. "-" .. variant

  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  for i, key in ipairs(M.ansi_order) do
    vim.g["terminal_color_" .. (i - 1)] = c.ansi[key]
  end

  M.current = { name = name, variant = variant, c = c, r = r }
  -- lualine `require`s its theme; drop the cached table so edits and studio
  -- previews reach the statusline on the next ColorScheme.
  package.loaded["lualine.themes." .. name .. "-" .. variant] = nil
end

return M
