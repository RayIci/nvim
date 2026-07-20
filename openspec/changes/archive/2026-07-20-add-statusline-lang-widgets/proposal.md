## Why

The old config showed contextual per-buffer indicators in the statusline — active LSP clients, formatters, linters, and the active Python virtualenv — each with a distinguishing icon. The current config only shows LSP clients; formatters, linters, and the venv indicator were never ported. Bringing them back restores at-a-glance visibility of what tooling is actually acting on the current buffer.

The venv indicator is different from the other three: it depends on a language-pack plugin (`venv-selector`, owned by the python pack), so hardcoding it into the shared statusline module would leak python-specific knowledge into the UI. This is the opening to give the language-pack framework the one fan-out hook it still lacks — a way for a pack to contribute a statusline widget.

## What Changes

- Add **formatter** and **linter** indicators to lualine (buffer-scoped, with icons + colors), alongside the existing LSP-clients indicator. Each hides when empty.
- Add a **`statusline` field to the language-pack framework** (`LangPack`): a pack may declare one or more statusline widgets (a render function + optional `cond`, `icon`, `color`). The langs loader merges them and `lualine` gains an `apply()` that surfaces them through a single dynamic bridge component — resolving the ordering constraint (lualine's sections are fixed at setup, before packs are collected and before `venv-selector` lazy-loads).
- The **python pack** declares a venv widget (`🐍 <venv-name>`, shown only for Python buffers, hidden when no venv is active) via that new field.
- Keep the global widgets (LSP/formatters/linters) in the statusline module directly — they read global registries keyed by the current buffer and are not pack-specific.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `ui-shell`: The statusline gains buffer-scoped LSP / formatter / linter indicators (icon-distinguished) plus a bridge that renders language-pack-contributed widgets, the first of which is the Python venv indicator.
- `lang-pack-framework`: `LangPack` gains an optional `statusline` field so a pack can contribute statusline widgets, merged and applied to lualine like the other subsystem fan-outs.

## Impact

- `lua/langs/init.lua` — add `statusline` to `LangPack`/`LangMerged`, collect and merge it, and call `require("plugins.lualine").apply(merged.statusline)`.
- `lua/plugins/lualine.lua` — add inline formatter/linter components (with icons/colors) next to the existing LSP one; add a bridge component and an `apply()` that stores and renders pack widgets.
- `lua/langs/python.lua` — declare the venv widget via the new `statusline` field.
- No new dependencies; `venv-selector` is already installed by the python pack.
