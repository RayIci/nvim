# Design

## Context

`init.lua` loads `config.options`, then `config.pack` (one `vim.pack.add()` for all 111 plugins), then every plugin module's `setup()`, then the language packs. A profiler that has to see plugin autocmds and spawns must be installed before `config.pack`. Reading the current configuration found these candidates (see proposal): neo-tree's git refresh on BufEnter and CursorHold, illuminate, lightbulb, navic and ufo LSP traffic, nvim-lint on InsertLeave, and 29 BufEnter handlers. The profiler has to make each of these visible.

## Goals / Non-Goals

**Goals:**
- Attribute time to a plugin or configuration module by name, with negligible overhead while enabled (well under 5% of a handler's own cost).
- Same report shape across configurations, so the baseline can be compared with every later change.

**Non-Goals:**
- Timing Vimscript autocmds (string commands) and C internals; those are counted, not timed.
- A permanent statusline or UI; this is a diagnostic tool.

## Decisions

- **Autocmd timing by wrapping `vim.api.nvim_create_autocmd`.** The profiler replaces the function so every later Lua `callback` gets an `hrtime` wrapper keyed by `event × group`. Group ids resolve to names when the report is built. This covers plugin autocmds because it is installed before any plugin loads. Alternative: sampling only. Rejected, because it cannot tell which event triggered the work.
- **LSP via the native `LspRequest` autocmd**, not by monkey-patching the client. `pending` starts a timer per `request_id`; `complete` and `cancel` stop it. No client internals are touched.
- **Processes via wrappers on `vim.system`, `vim.fn.jobstart` and `vim.uv.spawn`.** nvim-lint spawns through libuv directly, so wrapping `vim.system` alone would miss mypy and checkstyle. The executable's basename is the key, and runtime is measured from spawn to its exit callback.
- **Lua time via `jit.profile`** in the built-in LuaJIT API (`jit.profile.start("li", cb)` at a 10 ms interval). Each sample's stack is turned into a source path with `jit.profile.dumpstack`. The path maps to a module: `site/pack/core/opt/<plugin>/` becomes the plugin name, and `<config>/lua/<mod>/` becomes `config:<mod>`. This is the only measurement that sees decoration providers (indent-blankline, rainbow-delimiters, render-markdown) and timer work. Alternative: `jit.p`. Rejected, because it is not on Neovim's `package.path` and writes to a file rather than an aggregate.
- **Snapshots as plain JSON** in `stdpath("state")/profile/<iso-time>-<appname>.json`, written through `config.state.write`. `:ProfileCompare` uses `vim.ui.select` over the directory and normalises every counter by uptime hours.
- **Baseline committed** to `docs/profiles/baseline.json` after a real working session on the imported configuration, so the comparison survives clearing the state directory.

## Risks / Trade-offs

- [Wrapping changes callback identity] → Wrappers forward all arguments and return values unchanged, so a callback returning `true` still deletes its autocmd. `nvim_del_autocmd` works on ids and is unaffected.
- [Sampling overhead] → A 10 ms interval keeps sample cost far below the work being measured. The interval is a single constant.
- [Sessions differ in what was done] → Per-hour normalisation plus session facts in the report (buffers, uptime) make differences explainable. Precision is not the aim.
