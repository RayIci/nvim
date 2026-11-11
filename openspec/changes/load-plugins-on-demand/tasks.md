# Tasks

## 0. Gate

- [ ] 0.1 Take a working-session profile after `trim-editor-hooks` is applied and compare it with `docs/profiles/baseline.json`; record the decision (apply or archive unapplied) in `docs/profiles/README.md` with the language-plugin BufEnter cost and runtime-lookup cost that justify it. Stop here if the decision is not to apply

## 1. Deferred installation

- [ ] 1.1 Add `defer` to `PackSpec`, split `install()` into eager and deferred `vim.pack.add` calls, and add `config.pack.load(name)` firing `User PackLoaded`; verify with `tests/pack.lua` that a deferred fixture plugin is installed but absent from `&runtimepath` until `load()`, and that its `plugin/` file runs exactly once

## 2. Language packs on their filetypes

- [ ] 2.1 Extend `lua/langs/init.lua` and the `LangPack` class with `filetypes`, `on_load` and per-plugin `eager`, with the load → dap registrar → `on_load` → filetype re-apply sequence; verify with `tests/plugin-modules.lua` plus a fixture pack that its plugin loads on the first matching buffer only and that buffer runs its ftplugin once
- [ ] 2.2 Declare `filetypes` (and `eager` where needed) in the dotnet, java, kotlin, python, jupyter, sql, http, markdown and mdx packs; verify with a headless run that opening only a Lua file leaves roslyn.nvim, kulala.nvim and vim-dadbod off the runtimepath, and that opening a `.cs` file attaches roslyn once with the pack's keymaps present

## 3. Tools on first use

- [ ] 3.1 Defer dap-ui and dap-virtual-text, neotest with adapters, octo, diffview and grug-far behind `ensure()` and command stubs; verify with `tests/pack.lua` that each plugin is absent after startup, that its which-key entries exist, and that the first key or command (including `:DiffviewOpen` with arguments) works without a second invocation

## 4. Themes

- [ ] 4.1 Defer the theme plugins and inject `config.pack.load` into each themery entry's `before`; verify with a headless start that only the persisted theme's plugin is on the runtimepath, and manually that previewing and selecting an unloaded theme in `<leader>ut` works and persists

## 5. Measure and document

- [ ] 5.1 Profile a working session with the change applied, save it under `docs/profiles/`, and compare it with the gate's profile using `:ProfileCompare`; document the result and the `:colorscheme` limitation in the README
