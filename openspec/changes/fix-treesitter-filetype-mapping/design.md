# Design

## Context

See proposal.md for the failure. `lua/plugins/treesitter.lua` `apply()` currently: builds `wanted` (base list + pack parsers), installs it, then computes `fts` via `get_filetypes()` for each parser and registers a `FileType` autocmd with `pattern = fts`. The pattern list is frozen before nvim-treesitter's `plugin/filetypes.lua` registers mappings such as `c_sharp → cs`.

## Goals / Non-Goals

**Goals:** highlighting starts for every filetype a declared parser serves; packs can state filetypes explicitly (to document, restrict, extend, or opt out); `tex` stays on vimtex deliberately.

**Non-Goals:** changing which parsers are installed; changing indentation strategy (treesitter indentexpr is still set wherever treesitter starts, as today).

## Decisions

### D1. Decide at FileType time, not at startup
The autocmd has no pattern; its callback resolves `vim.treesitter.language.get_lang(ev.match)` when the buffer gets its filetype. By then every plugin has registered its mappings. Cost: two table lookups per FileType event (measured ~0.4 µs). *Alternative:* keep the pattern list but compute it later (e.g. on `VimEnter`) — rejected, still a snapshot that misses registrations made later by lazily-set-up plugins.

### D2. Two entry forms, explicit wins
Bare `"parser"` → registry lookup. `parser = { fts }` → exactly those filetypes (registered via `vim.treesitter.language.register` so `get_lang` resolves them). Explicit lists from several packs are unioned; any explicit list overrides a bare declaration of the same parser. Without the "explicit means only these" rule, a lookup would silently re-enable filetypes a pack excluded (`svg`, `tex`).

### D3. Merged shape
`LangMerged.treesitter` becomes `{ parsers: string[], filetypes: table<string, string[]> }` (`filetypes` only holds explicitly declared parsers). The base list inside `treesitter.lua` stays bare parser names.

### D4. Explicit declarations in packs
Packs whose parser and filetype names differ declare them explicitly for readability, even where the lookup would find them (dotnet, bash, web, bibtex); json uses the explicit form to add `jsonc`, replacing its load-time `register` call; latex uses `latex = {}`.

## Risks / Trade-offs

- [A plugin buffer whose filetype maps to a parser (octo → markdown, kulala_ui → markdown) now gets treesitter started by the config as well] → `vim.treesitter.start` on an already-highlighted buffer re-attaches the same highlighter; no behaviour change observed.
- [Explicit lists can miss a rare filetype alias] → only used where intentional; bare names remain the default.
- [Newly highlighted filetypes pay treesitter parse cost] → same cost other languages already pay; parser load is one-time per session.
