# Spec Delta

## Purpose

Provides the vale studio: a browser page served by Neovim for creating new themes and editing existing ones, with every colour and semantic role visible at once, live preview both in the page and in Neovim itself, and nothing written to disk until the user saves.

## ADDED Requirements

### Requirement: Studio commands and server
The configuration SHALL provide `:Vale` (open the theme list), `:Vale new <name>` (open the new-theme form with the name filled in), `:Vale edit <name>` (open the editor for an existing theme) and `:Vale stop`. Opening the studio SHALL start an HTTP server inside Neovim, without external dependencies, bound to `127.0.0.1` on a free port, open the page in the default browser, and print the page URL. At most one studio server SHALL run per Neovim instance; a second `:Vale` SHALL reuse it. The server SHALL stop on `:Vale stop`, when Neovim exits, and when no page has been connected for 30 seconds.

#### Scenario: Open the studio
- **WHEN** the user runs `:Vale`
- **THEN** the default browser opens a page listing the existing themes with their variants, and the URL is shown in Neovim's messages

#### Scenario: Server lifetime
- **WHEN** the user closes the last studio page
- **THEN** the server stops within 30 seconds and its port is released

### Requirement: Studio access control
Every request SHALL carry a random token generated when the server starts and embedded in the opened URL; requests without the correct token SHALL be rejected. Requests whose `Host` header is not `127.0.0.1:<port>` or `localhost:<port>`, and state-changing requests whose `Origin` header is present and not the studio's own origin, SHALL be rejected. The page and its assets SHALL be served from files shipped with the plugin, with no build step and no network access.

#### Scenario: Foreign request
- **WHEN** another web page in the browser sends a request to the studio port without the token
- **THEN** the studio rejects it and no colour or file changes

### Requirement: Theme creation
The new-theme form SHALL ask for a theme name, which variants to create (dark only, light only, or both) and a starting point (the VS Code Modern reference, or a copy of an existing theme). Creating the theme SHALL write its palette files and, when copying a theme, its `semantics.lua`, generate the `colors/` and lualine files for each variant, and open the new theme in the editor. Names that are invalid or already taken SHALL be rejected with a message.

#### Scenario: New dark-only theme from VS Code
- **WHEN** the user creates theme `ocean` with dark only, starting from VS Code
- **THEN** `themes/ocean/night.lua` exists with the reference's dark values, `:colorscheme ocean-night` loads, and the editor for `ocean` is open

#### Scenario: Name already taken
- **WHEN** the user tries to create a theme named `vale`
- **THEN** the form shows that the name is taken and nothing is written

### Requirement: Theme editor
The editor SHALL show every palette slot of the selected variant at once, grouped as foundation, syntax, signals, UI and ANSI, with a toggle between the theme's variants. Each slot SHALL offer a hex text input accepting any `#RRGGBB` value, a colour picker, a reset to the value last saved, the WCAG 2.x contrast ratio against the colour it is used with (marked when a text colour falls below 4.5:1), and a row of generated variations of the current value (lighter, darker, more and less saturated). The editor SHALL also list each semantic role with a selector choosing which palette colour (or the plain foreground) it uses, marking roles that differ from the shared default.

#### Scenario: Custom colour
- **WHEN** the user types `#3A7BD5` into the keyword colour's hex input
- **THEN** the slot shows `#3A7BD5`, its contrast ratio updates, and the preview updates

#### Scenario: Invalid input
- **WHEN** the user types `#3A7B` into a hex input
- **THEN** the input is marked invalid and the previous colour stays in effect

#### Scenario: Remap a role
- **WHEN** the user sets the "Strings" role to `green`
- **THEN** strings in the preview and in Neovim use the palette's `green`, and the role is marked as changed from the default

### Requirement: Live preview in page and Neovim
Every unsaved change in the editor SHALL be applied to Neovim immediately as an in-memory override of the edited theme variant, which Neovim activates while the editor is open. The page SHALL show the vale sample files, one tab per language, coloured with the highlight colours Neovim computes for the current unsaved state, using Neovim's treesitter parse of each sample. When a theme's files change on disk while its editor is open, the page SHALL refresh to the new values.

#### Scenario: Change reaches both previews
- **WHEN** the user changes the function colour in the editor
- **THEN** within a second, functions in the page's code preview and in every Neovim buffer show the new colour, and no file on disk has changed

#### Scenario: Edited on disk
- **WHEN** a palette file of the theme being edited is changed in Neovim and written
- **THEN** the editor shows the new value for that slot

### Requirement: Saving and discarding
Saving SHALL write the edited palette values into the theme's palette files, changing only the lines of changed slots and keeping comments and all other lines byte-for-byte, and SHALL write the theme's `semantics.lua` containing only roles that differ from the shared default. If a palette file has unsaved changes in a Neovim buffer, saving SHALL be refused with a message. Closing the editor or stopping the studio with unsaved changes SHALL discard them and reload the colorscheme that was active before the editor opened, or the saved theme if it was active.

#### Scenario: Save
- **WHEN** the user changes the string colour of vale-night and saves
- **THEN** `git diff` on `themes/vale/night.lua` shows exactly one changed line

#### Scenario: Discard
- **WHEN** the user changes colours and closes the page without saving
- **THEN** Neovim shows the saved theme again and no file changed
