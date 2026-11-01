# Spec Delta

## MODIFIED Requirements

### Requirement: Required plugin integrations
Plugin integrations SHALL cover at least: gitsigns, diffview, neogit, git-conflict, telescope, neo-tree, bufferline, lualine, barbecue/navic, which-key, noice, snacks, trouble, todo-comments, indent-blankline, rainbow-delimiters, flash, illuminate, blink.cmp, lspsaga, lightbulb, nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, neotest, overseer, grug-far, render-markdown, toggleterm, nvim-ufo, multicursor, sidekick, mason, window-picker, copilot, vim-dadbod-ui, easy-dotnet, kulala and agentdiff.

#### Scenario: Integration is present
- **WHEN** vale-night is active and the user opens telescope, neo-tree, and a diffview
- **THEN** their windows, borders, selections and diff regions use vale-night colours, not colours linked from a previous theme or the Neovim default

#### Scenario: Agent review colours
- **WHEN** vale-night is active and a file shows pending agent changes
- **THEN** the overlay's removed lines, added lines, hint and conflict marks use vale-night colours
