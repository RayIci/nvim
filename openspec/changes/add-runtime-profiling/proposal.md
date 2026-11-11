# Proposal

## Why

After a few hours on a project the editor gets sluggish, but nothing measures where the time goes: startup profiling (`--startuptime`) only covers the first half second. The rewrite that follows this change removes and replaces plugins on the strength of code reading (refresh loops, per-cursor LSP traffic, linters on every insert-leave). Before changing anything, the configuration needs a way to measure a real working session, so the baseline and every later change can be compared with numbers instead of impressions.

## What Changes

- Add an opt-in runtime profiler, enabled by starting Neovim with `NVIM_PROFILE=1`, with zero cost when it is off.
- While enabled, it records:
  - time spent in Lua autocmd callbacks, grouped by event and augroup (count, total, worst call);
  - LSP requests by client and method (count, time until the response);
  - external processes started by the editor (linters, git, formatters) by command (count, total runtime);
  - sampled Lua CPU time attributed to the plugin or configuration module it ran in (this also covers decoration providers and timers, which no autocmd measurement sees);
  - session facts: uptime, loaded and listed buffers, runtimepath entries, Lua memory.
- `:ProfileReport` opens the report in a scratch buffer and saves a JSON snapshot under `stdpath("state")/profile/`.
- `:ProfileReset` clears the counters without restarting.
- `:ProfileCompare` shows two saved snapshots side by side, normalised per hour of uptime.
- Record a baseline snapshot of the configuration as imported, kept in the repository for later changes to compare against.

## Capabilities

### New Capabilities
- `runtime-profiling`: measuring where editor time goes during a working session (hot autocmds, LSP traffic, spawned processes, per-module Lua time) and comparing sessions.

### Modified Capabilities
<!-- none -->

## Impact

- New module `lua/config/profile.lua`, loaded first in `init.lua` and only when `NVIM_PROFILE=1` is set.
- No plugin changes and no change to any existing keymap.
- New `docs/profiles/` directory holding committed baseline snapshots.
- README gains a short "Measuring a session" section.
