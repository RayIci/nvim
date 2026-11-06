---Plugin installation through native vim.pack (see :h vim.pack).
---Lockfile: nvim-pack-lock.json next to init.lua — keep it under version control.
---Update flow: :lua vim.pack.update()  ->  review buffer  ->  :write to apply.
---
---`install()` is the single installer: the core plugins (shared dependencies
---below plus each lua/plugins/*.lua module's `M.spec`) and the language packs
---(lua/langs/init.lua) both go through it.
---@class ConfigPack
local M = {}

---One plugin to install.
---@class PackSpec
---@field src string "owner/name" GitHub shorthand or full URL
---@field name? string overrides the name vim.pack derives from src
---@field version? string|vim.VersionRange
---@field build? fun(path: string) run after the plugin is installed or updated

---Build hooks by plugin name, filled by install(); one PackChanged handler
---serves every call.
---@type table<string, fun(path: string)>
local builds = {}

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("config.pack.build", { clear = true }),
  callback = function(ev)
    local hook = builds[ev.data.spec.name]
    if hook and (ev.data.kind == "install" or ev.data.kind == "update") then
      hook(ev.data.path)
    end
  end,
})

---Install and load plugins with one vim.pack.add() call. Build hooks are
---registered first, so they also run on the first install.
---@param specs (string|PackSpec)[] "owner/name" shorthand or full specs
function M.install(specs)
  local add = {} ---@type vim.pack.Spec[]
  for _, spec in ipairs(specs) do
    spec = type(spec) == "string" and { src = spec } or spec
    local src = spec.src:match("^https?://") and spec.src or ("https://github.com/" .. spec.src)
    if spec.build then
      builds[spec.name or (src:match("([^/]+)$"):gsub("%.git$", ""))] = spec.build
    end
    add[#add + 1] = { src = src, name = spec.name, version = spec.version }
  end
  if #add > 0 then
    vim.pack.add(add, { confirm = false })
  end
end

---Plugins no single setup module owns: libraries several modules depend on,
---and vim-tmux-navigator, whose keymaps live in config/keymaps.lua because its
---no-mappings flag must be set before its script is sourced.
M.shared = {
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  "nvim-tree/nvim-web-devicons",
  "nvim-neotest/nvim-nio",
  "christoomey/vim-tmux-navigator",
}

-- Shared dependencies first, then every setup module's own specs
-- (lua/plugins/*.lua, M.spec) in setup order.
M.install(vim.list_extend(vim.list_extend({}, M.shared), require("plugins").specs()))

return M
