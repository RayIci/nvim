# Proposal

## Why

Treesitter highlighting never starts for filetypes whose name differs from their parser's name — `cs` (c_sharp), `sh` (bash), `typescriptreact`/`javascriptreact` (tsx/javascript), `bib` (bibtex), `gitconfig`, `gitrebase`, `gitdiff`, `svg`/`xsd`/`xslt` (xml). `lua/plugins/treesitter.lua` builds its `FileType` pattern list during `init.lua` by asking `vim.treesitter.language.get_filetypes(parser)`, but the parser↔filetype registrations come from nvim-treesitter's `plugin/filetypes.lua`, which Neovim sources only after `init.lua`. At that moment `get_filetypes("c_sharp")` returns just `{ "c_sharp" }`, so `.cs` buffers (filetype `cs`) never match. The parsers are installed; they are simply never started. LaTeX (`tex`) is excluded by the same accident, which happens to be what vimtex requires.

## What Changes

- A language pack's `treesitter` field accepts two entry forms: a bare parser name (`"python"`), or `parser = { filetypes }` naming exactly the filetypes the parser runs on. An empty list (`latex = {}`) installs the parser without ever starting it.
- The loader decides per buffer, when the `FileType` event fires (after all plugin registrations), instead of from a pattern list computed at startup: bare parsers start on whatever filetypes the treesitter registry maps to them; explicit parsers start only on their listed filetypes.
- Explicit filetype lists are registered with Neovim's treesitter registry by the loader.
- Packs updated: dotnet (`c_sharp` → `cs`, `csharp`), bash (`bash` → `bash`, `sh`), web (`javascript` → `javascript`, `javascriptreact`; `tsx` → `typescriptreact`, `typescript.tsx`), latex (`latex = {}`, `bibtex` → `bib`), json (`json` → `json`, `jsonc`, replacing its load-time registration workaround).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `lang-pack-framework`: treesitter entries can declare the filetypes a parser serves, and highlighting starts for every filetype a pack's parser serves (not only filetypes named like the parser).
- `language-packs`: the latex pack installs its parser without enabling treesitter highlighting for `tex` buffers, leaving highlighting to vimtex.

## Impact

- Code: `lua/plugins/treesitter.lua` (apply + FileType callback), `lua/langs/init.lua` (merge of the new entry forms, `LangPack`/`LangMerged` types), packs `dotnet`, `bash`, `web`, `latex`, `json`.
- Behaviour: C#, shell, TSX/JSX, BibTeX and git config/rebase/diff buffers gain treesitter highlighting and treesitter indentation; `tex` stays on vimtex's syntax deliberately.
- No new dependencies.
