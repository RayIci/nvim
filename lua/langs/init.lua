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

---One drop-in language definition. Every field is optional.
---@class LangPack
---@field treesitter? string[] parser names to install and enable
---@field lsp? table<string, table> LSP server name -> vim.lsp.config() overrides ({} for defaults)
---@field formatters? table<string, string[]> filetype -> conform formatter names
---@field linters? table<string, string[]> filetype -> nvim-lint linter names
---@field dap? fun(dap: table) register DAP adapters/configurations
---@field mason? string[] mason package names to auto-install

---Merged view over all packs, consumed by lua/plugins/*.
---@class LangMerged
---@field treesitter string[]
---@field lsp table<string, table>
---@field formatters table<string, string[]>
---@field linters table<string, string[]>
---@field dap fun(dap: table)[]
---@field mason string[]

local M = {}

---@type LangMerged
M.merged = { treesitter = {}, lsp = {}, formatters = {}, linters = {}, dap = {}, mason = {} }

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
      end
    end
  end
  return merged
end

---Load all language packs, wire LSP servers, and push the merged language
---data into each subsystem via its apply() function (plugins/ setup ran first).
function M.setup()
  local merged = collect()

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
end

return M
