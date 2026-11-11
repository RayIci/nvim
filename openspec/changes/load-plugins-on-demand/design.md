# Design

## Context

`config.pack.install()` passes every spec to one `vim.pack.add(specs, { confirm = false })`, which (during `init.lua`) behaves like `:packadd!`: every plugin is on the runtimepath immediately. `langs.setup()` installs pack plugins the same way, then runs all subsystem `apply()` calls (dap registrars, neotest adapter factories, blink providers, statusline widgets) and every pack `setup`. Neovim 0.12's `vim.pack.add` accepts `load = fun(plug_data)`, which installs and registers a plugin while leaving loading entirely to the caller; `:packadd <name>` loads it later.

## Goals / Non-Goals

**Goals:**
- Same behaviour on the first buffer or first key as when everything loaded at startup (see specs).
- Deferral is declared next to the plugin (in its module's `M.spec` or the pack's entry), not in a central list.

**Non-Goals:**
- Deferring core plugins (treesitter, blink, LSP, gitsigns, bufferline, lualine, snacks, which-key, auto-session, scope, copilot, agentdiff).
- Deferring vimtex, which its documentation says must not be lazy-loaded.

## Decisions

- **`PackSpec` gains `defer?: true`.** `install()` splits the specs: eager ones go through `vim.pack.add` as now, deferred ones through `vim.pack.add(deferred, { load = function() end })`. `config.pack.load(name)` runs `vim.cmd.packadd(name)` once and fires `User PackLoaded <name>`.
- **Filetype-triggered packs.** When a pack declares `filetypes`, `langs` installs its non-`eager` plugins deferred and creates a `once` FileType autocmd for those filetypes. On the first match it:
  1. loads the pack's plugins;
  2. runs the pack's `dap` registrar and `on_load`;
  3. re-applies the buffer's filetype (`vim.bo[buf].filetype = ft`), so ftplugin, indent, `vim.lsp.enable`'s FileType start and plugin FileType autocmds all run for that buffer as if they had existed from the start.

  Statusline widgets and blink providers stay registered at startup. They already guard with `pcall(require)` or are resolved only when used.
- **Tools on first use.** Each tool module keeps its keymaps at startup but calls a local `ensure()` before acting:
  - `ensure()` loads the plugin and runs its real setup once;
  - for neotest, `ensure()` also loads every pack's test-adapter plugins before resolving the adapter factories;
  - for dap-ui and virtual-text, `ensure()` also runs on the first `dap` session (`dap.listeners.before.launch` and `before.attach`).

  User commands (`:Octo`, `:DiffviewOpen`, `:GrugFar`) are defined as stubs that call `ensure()`, delete themselves, then re-run the original command line with its arguments.
- **Themes.** Theme plugins are installed with `defer`. `theme.lua` prepends `require("config.pack").load("<plugin>")` to every entry's `before` code, which themery runs for both preview and apply. The persisted theme is applied by themery's setup through the same `before`, so it loads first.
- **Measuring.** Apply only when the post-`trim-editor-hooks` profile shows it is needed (see proposal). Re-profile after applying and record both in `docs/profiles/`.

## Risks / Trade-offs

- [Re-applying a filetype runs FileType autocmds twice for that first buffer] → Every handler in this configuration is idempotent (keymaps are set, not toggled; LSP `vim.lsp.enable` reuses running clients). The test suite checks that the first buffer gets exactly one client per server.
- [A plugin needed before its filetype appears (venv-selector's restore, jupyter's `.ipynb` read hook)] → `eager = true` per plugin entry. The jupyter pack's pairing autocmds are configuration code, not plugin code, and stay in `setup`.
- [Hand-typed `:colorscheme` cannot find unloaded themes] → Documented limitation. The picker covers switching.
