# Design

## Context

See proposal.md for motivation and the specs (`vale-engine`, `vale-studio`, `ui-shell`, `git-integration`) for requirements. Relevant current state:

- Plugins load with native `vim.pack` and are set up explicitly in `lua/plugins/init.lua`. The config directory is on `runtimepath`, so top-level `colors/` and `lua/lualine/themes/` files are found by `:colorscheme` and lualine's `theme = "auto"`.
- Themery (`lua/plugins/theme.lua`) takes a static theme list at setup and restores the persisted colorscheme by name. `livePreview = true` runs `:colorscheme` on every cursor move, so loads must be fast and stateless.
- Built earlier in this change and kept as the engine: `lua/vale/init.lua` (load/resolve/roles), `groups/*`, 35 `integrations/*` modules, `semantics.lua`, `reference/vscode_modern.lua`, `lualine.lua`, the palette format (verified: 1,057 groups, none overridden by plugin `ColorScheme` hooks; load ≈1.5 ms), the single-line `writer`, samples with C#/Java/Rust project scaffolding, and theme-agnostic lualine/neo-tree/octo wiring.
- Built earlier and now replaced: the `:ValeLab` tab UI (`lab/init.lua`, `lab/panel.lua`) and hand-written `lab/candidates.lua`.
- In-tree plugin precedent: `lua/commitsmith/` with a thin `lua/plugins/commitsmith.lua`, written to be extracted to its own repository later.

## Goals / Non-Goals

**Goals:**
- Plugin code (`lua/vale/`) and user theme data (`themes/`) are separate, so vale can move to its own repository later without taking the user's themes with it.
- One engine for every theme; vale-night/day are ordinary themes, not special cases.
- The page never computes syntax colours itself: Neovim renders, the page displays, so the two previews cannot disagree.
- Zero dependencies: `vim.uv` for the server, `vim.ui.open` for the browser, plain HTML/CSS/JS assets.

**Non-Goals:**
- Using the studio over SSH/remote connections.
- Deleting or renaming themes from the studio (delete the directory by hand).
- Exporting ghostty/kitty/wezterm/tmux/starship themes (the palette format keeps it possible).
- LSP semantic tokens in the page preview (treesitter only there; Neovim itself shows full LSP colouring).
- User-facing plugin options beyond the themes directory.

## Decisions

### D1. Layout: plugin code vs theme data

```
<config>/
  lua/vale/                       PLUGIN (extractable)
    init.lua                      engine API: load(name, variant, overrides?), themes(), paths
    semantics.lua                 shared default role mapping (VS Code)
    groups/  integrations/        highlight modules: function(r, c) → { Group = spec }
    lualine.lua                   lualine theme builder
    reference/vscode_modern.lua   VS Code values per palette key (hex only, sources)
    template.lua                  palette text template: every key with its role comment
    slots.lua                     slot metadata for the page: group, label, `on`, text flag
    samples/                      token-checklist samples (+ csharp/java/rust projects)
    studio/
      init.lua                    :Vale commands, session state, lifecycle
      server.lua                  HTTP/1.1 over vim.uv (static files, JSON, SSE)
      api.lua                     routes → engine/render/writer/generate
      render.lua                  sample → coloured spans (D8)
      writer.lua                  palette line edits + semantics.lua generation (D10)
      generate.lua                create theme files and shims (D5)
      assets/index.html app.js style.css
  themes/                         USER DATA
    vale/night.lua day.lua semantics.lua
  colors/<name>-<variant>.lua                 generated: require("vale").load(name, variant)
  lua/lualine/themes/<name>-<variant>.lua     generated: require("vale.lualine")(name, variant)
```

The themes directory defaults to `stdpath("config") .. "/themes"`.

### D2. Palette format (unchanged)

Pure-data Lua, one `key = "#RRGGBB", -- role` per line, blocks `base`/`accent`/`signal`/`ansi`/`ui`, names allowed in `ansi`/`ui`, VS Code alpha colours pre-blended, identical keys in every palette of every theme. Accent names describe hue families, not roles, so palettes stay meaningful for terminal ports. *Alternatives:* JSON (no comments), TOML (parser needed).

### D3. Layered semantics

Roles resolve through: `lua/vale/semantics.lua` (shared default) → `themes/<name>/semantics.lua` top-level keys → its `night`/`day` sub-tables. Values are palette names (`"green"`, `"ui.selection"`); "plain foreground" is simply `"fg"`, an existing base name, so it needs no special case. A theme file holds only differences:

```lua
return { string = "green", variable = "fg", day = { folder = "amber" } }
```

vale's existing day-only `folder = "amber"` override moves from the shared file into `themes/vale/semantics.lua`.

### D4. Loading with overrides

`load(name, variant, overrides)` reads `themes/<name>/<variant>.lua` with `dofile` (fresh on every load), applies `overrides.palette` (`"block.key" → hex`) and `overrides.semantics` (`role → name`) on top of the files, resolves, builds all modules, `hi clear`, sets `background`/`colors_name = name .. "-" .. variant`, applies groups and `terminal_color_0..15`, and drops the cached lualine theme module. The studio previews by loading with overrides; nothing touches disk.

### D5. Theme generation

`generate.create(name, variants, from)`: validate `^[a-z0-9][a-z0-9-]*$` and not taken. `from = "vscode"`: render each variant from `template.lua` text with values taken from the reference (via the writer's line substitution, so output matches the hand-written format exactly). `from = <theme>`: copy that theme's variant files (and `semantics.lua`) byte-for-byte; a variant the source lacks falls back to the reference. Then write the `colors/` and lualine shims per variant. Shims contain only one `require` line, so they never need regenerating when the engine changes.

### D6. Server and protocol

`vim.uv.new_tcp()` bound to `127.0.0.1:0`; minimal HTTP/1.1: request line, headers, `Content-Length` bodies only (no chunked uploads), `Connection: close` except the SSE stream. libuv callbacks run in a fast context, so every Neovim API call is wrapped in `vim.schedule`. Routes:

| Method | Path | Purpose |
|---|---|---|
| GET | `/`, `/app.js`, `/style.css` | page assets |
| GET | `/api/themes` | theme list with variants |
| GET | `/api/theme/<name>` | palettes, theme semantics, default semantics, reference, slot metadata |
| POST | `/api/create` | D5 |
| POST | `/api/preview` | apply overrides live in Neovim, return rendered samples (D8) |
| POST | `/api/save` | D10 |
| POST | `/api/close` | discard session (also triggered by D11) |
| GET | `/api/events` | server-sent events: `changed` when theme files change on disk; keep-alive every 15 s |

The page debounces preview requests (~60 ms) while dragging a picker.

### D7. Access control

A 128-bit token from `vim.uv.random` is put in the opened URL (`/?t=…`); the page sends it back as `X-Vale-Token` (and `?t=` for the SSE stream). Rejected with 403: wrong or missing token; `Host` other than `127.0.0.1:<port>`/`localhost:<port>` (DNS-rebinding guard); POSTs with an `Origin` other than the studio's own. Static assets need the token too, so the port reveals nothing.

### D8. Preview rendering in Neovim

Each sample is loaded once per session into a hidden scratch buffer with its filetype; its treesitter captures (highlights query, including injections) are collected once as `(row, col_start, col_end, capture, priority)`. On every preview, after the overrides are applied, each distinct capture group is resolved with `nvim_get_hl(0, { name = "@capture.lang", link = false })` (falling back through the capture's dotted parents to the base group), overlapping captures are flattened by priority/order the way the highlighter does, and the page receives per sample `{ lines, spans: [{row, s, e, fg, bg, bold, italic, underline}], normal: {fg, bg}, linenr, cursorline }`. Only colour resolution repeats per preview, so it stays in the low milliseconds.

### D9. Page

Plain ES modules, no framework. Theme list view; new-theme form; editor view with a night/day toggle, slots grouped by `slots.lua` groups, each row: swatch, hex input (validated `#RRGGBB`), native `<input type="color">`, reset (to saved value), contrast vs its `on` colour (WCAG 2.x, computed in JS, marked under 4.5:1 for text slots), and a variations row computed in JS in OKLCH (lightness ±0.05/±0.10, chroma ±0.03, clamped to sRGB). A "Roles" section lists every semantic role with a `<select>` of palette names plus "plain text"; roles differing from the shared default are marked. Preview pane with a tab per sample. Unsaved slots and roles are highlighted; Save/Discard buttons.

### D10. Saving

The writer computes every changed palette line first (single-line substitution inside the right block; refuses on 0 or >1 matches), then writes each palette file once, so a failed edit writes nothing. If a palette file's buffer is modified in Neovim, the save is refused. `themes/<name>/semantics.lua` is regenerated from the effective overrides (a small generated data file with a header comment; roles equal to the default are omitted; the file is deleted when empty). After saving, the session's overrides reset and the theme reloads from disk.

### D11. Session and lifecycle

Opening an editor records the active colorscheme, then activates the edited theme variant. Discard (button, `/api/close`, `:Vale stop`, `VimLeavePre`, or the last SSE stream disconnecting for 30 s) drops overrides and reloads the recorded colorscheme, or the saved theme if it was the active one. The server stops when no stream has been connected for 30 s, on `:Vale stop`, and on `VimLeavePre`.

### D12. Themery discovery

`lua/plugins/theme.lua` globs `stdpath("config") .. "/colors/*.lua"` at setup and prepends one entry per file, named after the colorscheme. It references no theme by name except the first-launch fallback (`vale-night`). Themes created in a session appear in Themery after restart (they load immediately via `:colorscheme` and the studio).

### D13. Hot reload

`fs_event` watchers on the edited theme's directory (and, during development, `lua/vale/`) debounce changes, reload the active theme if it is a vale theme, and push `changed` over SSE so the page re-fetches the theme.

### D14. Theme-agnostic config (kept from earlier)

Configuration outside vale never names vale: lualine labels read `DiagnosticError/Info/Ok`/`Statement`; neo-tree uses a theme's `FolderIcon` group when defined, else `#E5C07B`; octo's palette is re-read from standard groups on every `ColorScheme`.

### D15. VS Code reference (kept)

`reference/vscode_modern.lua` values come from `microsoft/vscode` theme JSON include chains and colour registries, each with its source; it is the "start from VS Code" source for D5 and the reset baseline shown in the studio for vale.

## Risks / Trade-offs

- [Hand-rolled HTTP parsing] → The server only serves its own page: reject anything unexpected (bad request line, missing Content-Length on POST, bodies > 1 MB) with 400/413 and close.
- [Fast-context API errors in uv callbacks] → All Neovim calls go through `vim.schedule`; one wrapper per route.
- [Browser does not open] → The URL is always printed; `vim.ui.open` errors are reported, not fatal.
- [Preview speed while dragging a picker] → Debounce in the page, captures cached per session, only colour resolution repeats; Neovim-side `:colorscheme` load is ~1.5 ms.
- [Save racing a hand edit] → Refuse when the palette buffer is modified; the writer refuses ambiguous lines.
- [Plugin extraction later] → Theme data already lives outside `lua/vale/`; the only config coupling is `plugins/theme.lua` (`:Vale` command, discovery), which is generic.
- [Coverage drifts as plugins are added] → Integration list in the spec; a new plugin's integration module belongs to the change that adds it.

## Migration Plan

Within this change (nothing released): move `lua/vale/palettes/{night,day}.lua` to `themes/vale/`, move the day folder override into `themes/vale/semantics.lua`, regenerate `colors/vale-*.lua` and the lualine shims with the `(name, variant)` form, move `lua/vale/lab/samples/` to `lua/vale/samples/`, turn `lab/candidates.lua` into `slots.lua` (metadata only), move the writer into `studio/`, and remove `lab/init.lua`, `lab/panel.lua`, `lab/contrast.lua` and `:ValeLab`. The persisted lab state file (`stdpath("state")/vale-lab.json`) is no longer read. Themery users keep their persisted selection by name.

## Open Questions

- Base shade count (currently 14 base slots) can grow during tuning; adding a key means adding it to `template.lua`, the reference and every theme's palettes, which the generator could automate later.
