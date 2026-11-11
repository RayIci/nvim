# Proposal

## Why

snacks.nvim is installed but used only for notifications. Meanwhile five other plugins cover jobs it already does, or that Neovim 0.12 does natively, each with its own autocmds and highlight handling:
- telescope + fzf-native + ui-select: pickers and `vim.ui.select`;
- noice: cmdline and messages. It is configured to look like the native bottom cmdline anyway, and it needs a `ui_attach` hack to stop `:restart` hanging;
- lspsaga: a definition jump, finders and code actions;
- vim-illuminate: reference highlighting on every cursor move, with LSP, treesitter and regex providers;
- indent-blankline: indent guides.

Moving these onto snacks and native APIs removes eight plugins without changing any key.

Apply after `remove-neogit-and-diffbandit`.

## What Changes

- Pickers move from telescope to the snacks picker, with the same keys: `<leader><leader>`, `<leader>ff` (resume) and `<leader>fg`/`fb`/`fh`/`fr`/`fw`/`fd`/`fk`/`fs`/`ft`/`fn`. The same ignore lists apply, and hidden files are included.
- LSP pickers (`gO`, `<leader>ldb`/`ldw`, `<leader>lhi`/`lho`) and the integrations that used telescope (octo, auto-session's session search `<leader>ql`, venv-selector `<leader>-pp`) use the snacks picker.
- `vim.ui.select` and `vim.ui.input` render through snacks. Code actions show the server name next to each action.
- noice is removed. The cmdline is Neovim's own bottom cmdline, and notifications and long messages go through the snacks notifier. `<leader>un` dismisses notifications and `<leader>fn` opens the notification history.
- lspsaga is removed:
  - `gd` and `grt` jump natively, or offer a picker when there are several targets;
  - `grr` and `gri` open reference and implementation pickers;
  - `gra` and `<leader>la` use native code actions;
  - `<leader>lf` opens one picker combining references and implementations.
- vim-illuminate is replaced by snacks' LSP reference highlighting. `]]`/`[[` keep jumping between references.
- indent-blankline is replaced by snacks indent guides, with the same `│` character and scope highlight, excluded from the same panels.
- vale.nvim gains highlight coverage for the snacks picker, words and indent (cross-repository task in the vale.nvim repository).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `ui-shell`: fuzzy finding, selection prompts, cmdline/messages and notification history change provider; indent guides change provider; telescope-only row-alignment requirement is removed.
- `lsp-and-diagnostics`: attach keymaps and the `<leader>l` tree no longer use lspsaga.
- `editing-experience`: reference highlighting and navigation are LSP-backed.
- `git-integration`: octo lists through the snacks picker.
- `debugging`: the DAP-buffer completion exclusion refers to picker prompts generally.

## Impact

- Removed plugins: telescope.nvim, telescope-fzf-native.nvim, telescope-ui-select.nvim, noice.nvim, nui.nvim (no remaining user once neo-tree goes in `move-explorer-to-snacks`; until then it stays as a shared dependency), lspsaga.nvim, vim-illuminate, indent-blankline.nvim.
- Edited: `lua/plugins/snacks.lua` (picker, input, words, indent, notifier), `lua/plugins/telescope.lua` → removed, `lua/plugins/lsp.lua`, `lua/plugins/noice.lua` → removed, `lua/plugins/lspsaga.lua` → removed, `lua/plugins/illuminate.lua` → removed, `lua/plugins/indent.lua` → removed, `lua/plugins/octo.lua`, `lua/plugins/auto-session.lua`, `lua/plugins/todo-comments.lua`, `lua/langs/python.lua`, `lua/plugins/blink.lua` (comment only), `README.md`.
- Cross-repo: RayIci/vale.nvim `lua/vale/integrations/snacks.lua`.
