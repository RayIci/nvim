# system-clipboard Specification

## Purpose

Make yank/put use the host system clipboard reliably across the environments this config runs in (WSL, native Linux under Wayland or X11, macOS, and headless/SSH sessions) by explicitly selecting a clipboard provider instead of relying solely on Neovim's autodetection.

## Requirements

### Requirement: Environment-aware clipboard provider
The configuration SHALL select a system-clipboard provider based on the detected environment rather than relying solely on Neovim's autodetection, and SHALL set `clipboard = unnamedplus` so yanks and puts use the system clipboard. Detection SHALL cover WSL (preferring `win32yank.exe`, falling back to WSLg/X11 forwarding then `clip.exe`/PowerShell), Wayland (`wl-clipboard`), X11 (`xclip`/`xsel`), macOS (`pbcopy`/`pbpaste`), and headless/SSH sessions (OSC 52). If `vim.g.clipboard` is already set, the module SHALL NOT override it. On startup the module SHALL emit an informational notification naming the detected environment and chosen provider.

#### Scenario: WSL uses win32yank
- **WHEN** Neovim starts on WSL with `win32yank.exe` available
- **THEN** `vim.g.clipboard` is set to the win32yank provider
- **AND** a startup notification reports the environment and provider (e.g. `WSL [win32yank]`)

#### Scenario: Yank reaches the system clipboard
- **WHEN** text is yanked with `clipboard = unnamedplus` active
- **THEN** the text is available to paste in other applications on the host

#### Scenario: Respect a pre-existing provider
- **WHEN** `vim.g.clipboard` is already configured before the module runs
- **THEN** the module leaves it unchanged
