## Context

The statusline (lualine, `lua/plugins/lualine.lua`) currently shows a single inline LSP-clients component. The old config additionally showed formatters, linters, and a Python venv indicator, each with a distinguishing icon/color. We want those back.

Three of the four widgets read **global** state keyed by the current buffer (`vim.lsp.get_clients`, `conform.list_formatters`, `lint.linters_by_ft`). The fourth — venv — reads `require("venv-selector").venv()`, a plugin owned by the python language pack.

Two load-order facts constrain the venv widget:
- lualine's **section list is fixed at `setup()`**, which runs in `require("plugins")` — *before* `require("langs").setup()` collects any pack.
- `venv-selector` is **lazy**: the python pack defers its setup to the first `python` FileType, so it isn't loaded at startup at all.

## Goals / Non-Goals

**Goals**
- Restore formatter/linter/LSP indicators in the statusline, icon-distinguished, each hidden when empty.
- Show the active Python venv (`🐍 <name>`) for Python buffers only, hidden when no venv is active.
- Give the language-pack framework a first-class way for a pack to contribute a statusline widget, consistent with its existing per-subsystem `apply()` fan-out.

**Non-Goals**
- A general-purpose statusline registry with a public `register()` for arbitrary (non-pack) code. Deferred until a non-pack registrant actually exists.
- Reworking lualine theming, separators, or the other sections.
- Making the global LSP/formatter/linter widgets pack-driven — they are global and stay in the statusline module.

## Decisions

### D1: Split global widgets from pack widgets
Global widgets (LSP, formatters, linters) live **directly in `lualine.lua`** as inline function components with icons/colors. Only the pack-specific venv widget goes through the framework.
- *Why:* LSP/formatters/linters don't know about language packs; routing them through the pack framework would be indirection with no benefit. Keeping them inline matches the existing LSP component and the old config.
- *Alternative rejected:* One uniform mechanism for all four — adds a layer for three widgets that don't need it.

### D2: Add a `statusline` field to `LangPack`, applied via `lualine.apply()`
A pack MAY declare `statusline` = a list of neutral widget specs `{ render = fun():string, cond? = fun():boolean, icon? = string, color? = table }`. The loader merges them into `LangMerged.statusline` and calls `require("plugins.lualine").apply(merged.statusline)` — mirroring `treesitter.apply`, `conform.apply`, etc.
- *Why:* lualine is the only subsystem with `setup()` but no `apply()`; this fills the gap in the established pattern and keeps the `venv-selector` dependency inside `python.lua` (locality) instead of leaking into the shared UI module.
- *Alternative rejected:* Hardcode venv in `lualine.lua` — couples the UI module to a python plugin; the third pack widget would pile on.
- *Alternative rejected:* Standalone `lib.status` registry with public `register()` — YAGNI; realistic registrants are packs, which the field covers. The bridge's backing table can grow a `register()` later if a non-pack needs it.

### D3: Surface pack widgets through one dynamic bridge component
`lualine.setup()` places a single bridge component in `lualine_x`: at render time it iterates the widgets stored by `apply()`, evaluates each `cond`, and concatenates the non-empty `render()` outputs (each may prefix its `icon` / embed its highlight).
- *Why:* dissolves the ordering constraint — the section list is fixed at setup, but the bridge reads a table that `apply()` fills afterward, and evaluates lazily at render time (so `venv-selector` loading only on first Python buffer is fine).
- *Alternative rejected:* Re-run `lualine.setup()` from `apply()` to append real components — works and gives per-widget lualine colors for free, but re-setups the whole statusline and is heavier than a single bridge. A widget that wants a distinct color can embed a `%#Group#…%*` highlight in its `render()` string.

### D4: venv render semantics
`render()` returns `""` when `venv-selector` is absent/unloaded or no venv is selected (guarded by `pcall`); the bridge omits empty widgets, so nothing shows. `cond` restricts it to `vim.bo.filetype == "python"`.

## Risks / Trade-offs

- **Bridge concatenates into one lualine component** → pack widgets share one color slot. *Mitigation:* a widget needing its own color embeds a highlight group in its returned string; venv only needs an icon, so this is a non-issue today.
- **Render-time `require("venv-selector")` on every statusline refresh** → tiny overhead. *Mitigation:* `pcall` + early return on empty; lualine refresh is throttled, and the `cond` skips non-Python buffers entirely.
- **`apply()` runs after `setup()`** → if `apply()` is never called (e.g. no packs declare `statusline`), the bridge renders empty and is harmless.

## Migration Plan

Additive only; no data or persisted state involved. Rollback = revert the three files. If the bridge or a widget misbehaves, removing the `statusline` field from `python.lua` disables the venv widget without touching the global indicators.

## Open Questions

None. The bridge's backing table is exposed through a public `register()` on the statusline module, so a plugin's setup can contribute a widget directly (not only language packs). `apply()` appends via `register()` rather than replacing, so pack widgets and plugin widgets coexist regardless of registration order. A standalone `lib.status` registry remains unnecessary — `register()` on the statusline module covers both registrant kinds.
