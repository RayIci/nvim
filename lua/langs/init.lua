---Language pack framework.
---
---Adding a language = dropping one file into lua/langs/ that returns a LangPack.
---The loader merges every pack and fans the fields out to:
---  treesitter -> nvim-treesitter install + per-ft highlight/indent autocmd
---  lsp        -> vim.lsp.config() + vim.lsp.enable()
---  formatters -> conform.nvim formatters_by_ft
---  linters    -> nvim-lint linters_by_ft
---  dap        -> called with the nvim-dap module to register adapters/configs
---  mason      -> mason-tool-installer ensure_installed

---A plugin a language pack ships with, installed via vim.pack.
---@class LangPackPlugin
---@field src string "owner/name" GitHub shorthand or full URL
---@field name? string overrides the name vim.pack derives from src
---@field version? string|vim.VersionRange
---@field build? fun(path: string) run after the plugin is installed or updated

---blink.cmp source contributions from a language pack.
---@class LangCompletion
---@field providers? table<string, table> provider name -> blink.cmp provider config
---@field per_filetype? table<string, string[]> filetype -> source names
---@field default? string[] source names appended to the default list

---A statusline widget a language pack contributes to lualine (rendered by the
---lualine bridge component). `render` is evaluated at draw time.
---@class LangStatusWidget
---@field render fun(): string text to show ("" to render nothing)
---@field cond? fun(): boolean gate (e.g. filetype check); shown only when true
---@field icon? string prefixed before the render output
---@field color? table advisory; the bridge renders one component, so a widget
---  wanting its own color embeds a `%#Group#…%*` highlight in `render` instead

---One drop-in language definition. Every field is optional.
---@class LangPack
---@field treesitter? string[] parser names to install and enable
---@field lsp? table<string, table> LSP server name -> vim.lsp.config() overrides ({} for defaults)
---@field formatters? table<string, string[]> filetype -> conform formatter names
---@field linters? table<string, string[]> filetype -> nvim-lint linter names
---@field dap? fun(dap: table) register DAP adapters/configurations
---@field mason? string[] mason package names to auto-install
---@field packs? LangPackPlugin[] plugins to install via vim.pack
---@field test? fun(): table|table[] factory returning one or more neotest adapters
---@field completion? LangCompletion blink.cmp source contributions
---@field statusline? LangStatusWidget[] statusline widgets contributed to lualine
---@field setup? fun() run after all subsystem wiring (e.g. register terminal hooks)

---Merged view over all packs, consumed by lua/plugins/*.
---@class LangMerged
---@field treesitter string[]
---@field lsp table<string, table>
---@field formatters table<string, string[]>
---@field linters table<string, string[]>
---@field dap fun(dap: table)[]
---@field mason string[]
---@field packs LangPackPlugin[]
---@field test (fun(): table|table[])[]
---@field completion LangCompletion
---@field statusline LangStatusWidget[]
---@field setup fun()[]

local M = {}

---@type LangMerged
M.merged = {
  treesitter = {},
  lsp = {},
  formatters = {},
  linters = {},
  dap = {},
  mason = {},
  packs = {},
  test = {},
  completion = { providers = {}, per_filetype = {}, default = {} },
  statusline = {},
  setup = {},
}

---@param dst string[]
---@param src string[]
local function extend_unique(dst, src)
  for _, v in ipairs(src) do
    if not vim.list_contains(dst, v) then
      dst[#dst + 1] = v
    end
  end
end

---Discover lua/langs/*.lua (except this loader) and merge their packs.
---@return LangMerged
local function collect()
  local merged = M.merged
  for _, file in ipairs(vim.api.nvim_get_runtime_file("lua/langs/*.lua", true)) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    if name ~= "init" then
      ---@type boolean, LangPack|string
      local ok, pack = pcall(require, "langs." .. name)
      if not ok then
        vim.notify(("langs: failed to load %s: %s"):format(name, pack), vim.log.levels.ERROR)
      elseif type(pack) ~= "table" then
        vim.notify(("langs: %s must return a table"):format(name), vim.log.levels.ERROR)
      else
        extend_unique(merged.treesitter, pack.treesitter or {})
        extend_unique(merged.mason, pack.mason or {})
        for server, cfg in pairs(pack.lsp or {}) do
          merged.lsp[server] = vim.tbl_deep_extend("force", merged.lsp[server] or {}, cfg)
        end
        for ft, list in pairs(pack.formatters or {}) do
          merged.formatters[ft] = merged.formatters[ft] or {}
          extend_unique(merged.formatters[ft], list)
        end
        for ft, list in pairs(pack.linters or {}) do
          merged.linters[ft] = merged.linters[ft] or {}
          extend_unique(merged.linters[ft], list)
        end
        if pack.dap then
          merged.dap[#merged.dap + 1] = pack.dap
        end
        for _, plugin in ipairs(pack.packs or {}) do
          local duplicate = false
          for _, existing in ipairs(merged.packs) do
            if existing.src == plugin.src then
              duplicate = true
              break
            end
          end
          if not duplicate then
            merged.packs[#merged.packs + 1] = plugin
          end
        end
        if pack.test then
          merged.test[#merged.test + 1] = pack.test
        end
        if pack.completion then
          for provider, cfg in pairs(pack.completion.providers or {}) do
            merged.completion.providers[provider] =
              vim.tbl_deep_extend("force", merged.completion.providers[provider] or {}, cfg)
          end
          for ft, list in pairs(pack.completion.per_filetype or {}) do
            merged.completion.per_filetype[ft] = merged.completion.per_filetype[ft] or {}
            extend_unique(merged.completion.per_filetype[ft], list)
          end
          extend_unique(merged.completion.default, pack.completion.default or {})
        end
        for _, widget in ipairs(pack.statusline or {}) do
          merged.statusline[#merged.statusline + 1] = widget
        end
        if pack.setup then
          merged.setup[#merged.setup + 1] = pack.setup
        end
      end
    end
  end
  return merged
end

---Load all language packs, wire LSP servers, and push the merged language
---data into each subsystem via its apply() function (plugins/ setup ran first).
---Install pack-declared plugins with one vim.pack.add() call, wiring their
---build hooks to PackChanged first so first-install builds run.
---@param plugins LangPackPlugin[]
local function install_packs(plugins)
  if #plugins == 0 then
    return
  end
  ---@type table<string, fun(path: string)>
  local build = {}
  ---@type (string|table)[]
  local specs = {}
  for _, plugin in ipairs(plugins) do
    local src = plugin.src:match("^https?://") and plugin.src or ("https://github.com/" .. plugin.src)
    if plugin.build then
      local name = plugin.name or (src:match("([^/]+)$"):gsub("%.git$", ""))
      build[name] = plugin.build
    end
    specs[#specs + 1] = { src = src, name = plugin.name, version = plugin.version }
  end
  if next(build) then
    vim.api.nvim_create_autocmd("PackChanged", {
      group = vim.api.nvim_create_augroup("langs.pack.build", { clear = true }),
      callback = function(ev)
        local hook = build[ev.data.spec.name]
        if hook and (ev.data.kind == "install" or ev.data.kind == "update") then
          hook(ev.data.path)
        end
      end,
    })
  end
  vim.pack.add(specs, { confirm = false })
end

function M.setup()
  local merged = collect()

  -- Per-language plugins first: later wiring (dap fns, test factories,
  -- pack setup) may require() modules these plugins provide.
  install_packs(merged.packs)

  -- LSP: apply per-server overrides, then enable everything.
  for server, cfg in pairs(merged.lsp) do
    if not vim.tbl_isempty(cfg) then
      vim.lsp.config(server, cfg)
    end
  end
  vim.lsp.enable(vim.tbl_keys(merged.lsp))

  -- Subsystems whose setup already ran get their language wiring here.
  require("plugins.treesitter").apply(merged.treesitter)
  require("plugins.conform").apply(merged.formatters)
  require("plugins.lint").apply(merged.linters)
  require("plugins.dap").apply(merged.dap)
  require("plugins.mason").apply(merged.mason)
  require("plugins.blink").apply(merged.completion)
  require("plugins.neotest").apply(merged.test)
  require("plugins.lualine").apply(merged.statusline)

  -- Pack-level setup runs last, against fully-wired subsystems.
  for _, setup in ipairs(merged.setup) do
    local ok, err = pcall(setup)
    if not ok then
      vim.notify("langs setup: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M
