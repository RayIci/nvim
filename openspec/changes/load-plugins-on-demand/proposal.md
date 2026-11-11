# Proposal

## Why

Every plugin is on the runtimepath and set up from the first second. That has two costs, and both last the whole session, not only startup:
- **Handlers for languages not in use.** Language plugins register handlers that run on every buffer switch whether or not their language is open: BufEnter currently has roslyn ×3, kulala ×2, dotnet solution autoselect, venv-selector's uv detection and markdown-preview.
- **Runtimepath size.** It has 129 entries, so every runtime lookup (ftplugin, indent, syntax, `require` of an uncached module) scans all of them. Seventeen of those are colorschemes other than the active one.

**This change is conditional.** The user reported slowness after long sessions, not at startup. Apply it only if the profile taken after `trim-editor-hooks` (see `add-runtime-profiling`) still shows language-plugin BufEnter handlers or runtime lookups among the top costs. Otherwise archive it unapplied.

Apply after `add-guided-conflict-resolution`.

## What Changes

- **Language packs can declare `filetypes`.** Their plugins then load, and a new `on_load` hook runs, on the first buffer of one of those filetypes. That buffer behaves exactly as if the plugins had been loaded at startup.
  - The pack's existing `setup` hook still runs at startup, for cheap wiring such as keymaps and terminal hooks.
  - A plugin entry can opt out with `eager = true`, for example venv-selector, whose cached-venv restore must be armed before the first Python buffer.
  - Packs without `filetypes` behave as today.
- **Heavier tools load on first use:** dap-ui and dap-virtual-text (first debug session or `<leader>d` UI key), neotest and its adapters (first `<leader>t` key), octo (first `<leader>gh` key or `:Octo`), diffview (first `<leader>gd`/`<leader>gCm` key or `:Diffview*`) and grug-far (first `<leader>s` key or `:GrugFar`). Their keys and which-key entries exist from startup.
- **Themes load when chosen.** Only the active colorscheme's plugin is on the runtimepath at startup. Picking or previewing a theme in `<leader>ut` loads its plugin first. The picker's list, live preview and persistence are unchanged.
- vimtex, nvim-treesitter, blink.cmp, LSP, gitsigns, bufferline, lualine, snacks and the session stack stay eager.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `plugin-management`: plugins are still all installed through vim.pack, but not all are loaded at startup; tools load on first use.
- `lang-pack-framework`: new optional `filetypes` field, `on_load` hook, and per-plugin `eager` flag.
- `ui-shell`: theme plugins load when chosen.

## Impact

- Edited: `lua/config/pack.lua` (deferred loading through `vim.pack.add`'s `load` function and `:packadd`), `lua/langs/init.lua` (filetype-triggered pack loading), the language packs that declare `filetypes` (python, jupyter, dotnet, java, kotlin, sql, http, markdown, mdx, latex excluded), `lua/plugins/theme.lua`, `lua/plugins/dap.lua`, `lua/plugins/neotest.lua`, `lua/plugins/octo.lua`, `lua/plugins/diffview.lua`, `lua/plugins/grug-far.lua`, `README.md`.
- Limitation: `:colorscheme <name>` typed by hand only finds the active theme, the configuration's own themes, and themes already previewed in this session. The picker remains the way to switch.
