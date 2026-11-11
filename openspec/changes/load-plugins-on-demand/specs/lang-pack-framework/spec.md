# Spec Delta

## ADDED Requirements

### Requirement: Packs load on their filetypes
A pack MAY declare `filetypes`. Its `packs` plugins SHALL then load, and its optional `on_load` function run, on the first buffer of one of those filetypes, and that buffer SHALL get the same LSP, indent, ftplugin and keymap behaviour as if the plugins had loaded at startup. A plugin entry with `eager = true` SHALL load at startup. Packs without `filetypes` SHALL load at startup as before, and every pack's `setup` SHALL still run at startup.

#### Scenario: C# plugins wait for a C# file
- **WHEN** Neovim starts and the user edits only Lua files
- **THEN** roslyn.nvim and easy-dotnet.nvim are not on the runtimepath and register no autocmds

#### Scenario: First C# buffer works fully
- **WHEN** the user then opens a `.cs` file
- **THEN** the C# plugins load, the roslyn server attaches to that buffer, and the pack's keymaps work in it

#### Scenario: Eager plugin entry
- **WHEN** the python pack declares `filetypes = { "python" }` and marks venv-selector `eager = true`
- **THEN** venv-selector is set up at startup while the other python plugins wait for the first Python buffer
