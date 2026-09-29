---Creates themes: palette files (from the VS Code reference via the palette
---template, or copied from an existing theme) plus the one-line colorscheme
---and lualine shims for each variant.
local vale = require("vale")
local writer = require("vale.studio.writer")

local M = {}

local plugin_dir = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))) -- lua/vale

---@param name string
---@return string|nil err
function M.check_name(name)
  if type(name) ~= "string" or not name:match("^[a-z0-9][a-z0-9-]*$") then
    return "use lowercase letters, digits and hyphens (starting with a letter or digit)"
  end
  if vim.uv.fs_stat(vale.theme_path(name)) then
    return ("a theme named %q already exists"):format(name)
  end
  local installed = vim.fn.getcompletion("", "color")
  for _, v in ipairs(vale.variants) do
    if vim.list_contains(installed, name .. "-" .. v) then
      return ("the colorscheme %q already exists"):format(name .. "-" .. v)
    end
  end
end

---Palette text for a variant, filled from the VS Code reference. Template
---entries that name another colour keep the name when it resolves to the
---reference value (so the new palette has the same structure as vale's).
---@param name string
---@param variant ValeVariant
---@return string[]
function M.from_reference(name, variant)
  local template = vim.fn.readfile(vim.fs.joinpath(plugin_dir, "template.lua"))
  -- drop the template's own preamble, fill the header placeholders
  while template[1] and not template[1]:find("{{name}}", 1, true) do
    table.remove(template, 1)
  end
  template[1] = template[1]:gsub("{{name}}", name):gsub("{{variant}}", variant)

  local ref = dofile(vim.fs.joinpath(plugin_dir, "reference", "vscode_modern.lua"))[variant]
  local tpl = dofile(vim.fs.joinpath(plugin_dir, "template.lua"))
  local edits = {}
  for block, keys in pairs(ref) do
    for key, hex in pairs(keys) do
      local tv = tpl[block][key]
      local named = tv and tv:sub(1, 1) ~= "#"
      local target = named and (ref.base[tv] or ref.accent[tv] or ref.signal[tv])
      edits[block .. "." .. key] = (named and target and target:upper() == hex:upper()) and tv or hex
    end
  end
  return assert(writer.apply(template, edits))
end

---@param name string
---@param variant ValeVariant
local function write_shims(name, variant)
  local config = vim.fn.stdpath("config") --[[@as string]]
  local colorscheme = name .. "-" .. variant
  vim.fn.mkdir(vim.fs.joinpath(config, "colors"), "p")
  vim.fn.mkdir(vim.fs.joinpath(config, "lua", "lualine", "themes"), "p")
  vim.fn.writefile(
    { ("require(%q).load(%q, %q)"):format("vale", name, variant) },
    vim.fs.joinpath(config, "colors", colorscheme .. ".lua")
  )
  vim.fn.writefile(
    { ("return require(%q)(%q, %q)"):format("vale.lualine", name, variant) },
    vim.fs.joinpath(config, "lua", "lualine", "themes", colorscheme .. ".lua")
  )
end

---Create a theme.
---@param name string
---@param variants ValeVariant[]
---@param from string "vscode" or an existing theme name
---@return boolean ok, string? err
function M.create(name, variants, from)
  local err = M.check_name(name)
  if err then
    return false, err
  end
  if type(variants) ~= "table" or #variants == 0 then
    return false, "choose at least one variant"
  end
  for _, v in ipairs(variants) do
    if not vim.list_contains(vale.variants, v) then
      return false, ("unknown variant %q"):format(tostring(v))
    end
  end
  if from ~= "vscode" and not vim.uv.fs_stat(vale.theme_path(from)) then
    return false, ("no theme named %q to copy"):format(tostring(from))
  end

  vim.fn.mkdir(vale.theme_path(name), "p")
  for _, v in ipairs(variants) do
    local source = from ~= "vscode" and vale.palette_path(from, v) or nil
    local lines
    if source and vim.uv.fs_stat(source) then
      lines = vim.fn.readfile(source)
      lines[1] = ("-- %s theme, %s variant (copied from %s)."):format(name, v, from)
    else
      lines = M.from_reference(name, v)
    end
    vim.fn.writefile(lines, vale.palette_path(name, v))
    write_shims(name, v)
  end
  if from ~= "vscode" then
    local sem = vale.theme_path(from, "semantics.lua")
    if vim.uv.fs_stat(sem) then
      local lines = writer.semantics_lines(dofile(sem), name)
      if lines then
        vim.fn.writefile(lines, vale.theme_path(name, "semantics.lua"))
      end
    end
  end
  return true
end

return M
