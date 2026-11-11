# Tasks

## 1. Profiler core

- [x] 1.1 Create `lua/config/profile.lua` with an `enabled()` check on `NVIM_PROFILE=1` and require it first in `init.lua`; verify with `nvim --headless +"lua print(vim.fn.exists(':ProfileReport'))" +qa` printing `0` without the variable and `2` with it
- [x] 1.2 Wrap `vim.api.nvim_create_autocmd` to time Lua callbacks by event × group, forwarding arguments and return values; verify with a headless test in `tests/profile.lua` that a callback returning `true` still deletes itself and its run is counted
- [x] 1.3 Record LSP requests from the `LspRequest` autocmd (pending → complete/cancel); verify in `tests/profile.lua` using a fake in-process LSP server (`vim.lsp.start` with a Lua `cmd` function) that two requests are counted with timings
- [x] 1.4 Wrap `vim.system`, `vim.fn.jobstart` and `vim.uv.spawn` to count processes by executable and runtime; verify in `tests/profile.lua` that spawning `true` three ways records three runs under `true`
- [x] 1.5 Add `jit.profile` sampling with stack-to-module attribution (plugin dir → plugin name, config `lua/<mod>` → `config:<mod>`); verify in `tests/profile.lua` that a busy loop in a module under a fake plugin path is attributed to that plugin

## 2. Commands and snapshots

- [x] 2.1 Implement `:ProfileReport` (read-only scratch buffer sorted by cost plus session facts) and JSON snapshot under `stdpath("state")/profile/`; verify in `tests/profile.lua` that the file exists and decodes with all sections
- [x] 2.2 Implement `:ProfileReset`; verify in `tests/profile.lua` that counters are zero and uptime restarts after a reset
- [x] 2.3 Implement `:ProfileCompare` with per-hour normalisation and differences; verify in `tests/profile.lua` with two synthetic snapshots that the rendered rows show both values and their difference
- [x] 2.4 Document "Measuring a session" in the README (start with `NVIM_PROFILE=1`, report, compare) and verify the documented commands run as written

## 3. Baseline

- [ ] 3.1 Run a real working session of at least two hours on the imported configuration with `NVIM_PROFILE=1`, save the snapshot as `docs/profiles/baseline.json`, and verify `:ProfileCompare` can open it
- [ ] 3.2 Summarise the baseline's top ten costs (autocmd groups, LSP methods, processes, modules) in `docs/profiles/README.md` and check each of the suspects listed in the proposal of `trim-editor-hooks` against them
