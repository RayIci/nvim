---Lua language pack: lua_ls + stylua. lazydev (set up in plugins/lazydev.lua)
---injects Neovim runtime and plugin typings into lua_ls workspaces.
---@type LangPack
return {
  treesitter = { "lua", "luadoc" },
  lsp = {
    lua_ls = {
      settings = {
        Lua = {
          completion = { callSnippet = "Replace" },
          doc = { privateName = { "^_" } },
          hint = { enable = true, arrayIndex = "Disable" },
        },
      },
    },
  },
  formatters = { lua = { "stylua" } },
  mason = { "lua-language-server", "stylua" },
}
