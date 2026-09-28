# Spec Delta

## Purpose

Provides `:ValeLab`, an interactive workspace for choosing vale's colours one slot at a time against real multi-language code, with live preview, a contrast readout and locking of the chosen values into the palette.

## ADDED Requirements

### Requirement: Lab workspace
The `:ValeLab [night|day]` command SHALL open a dedicated tab with a grid of sample buffers, a side panel for the current slot, and a palette strip that lists every palette slot as locked or pending. It SHALL activate the requested variant (night by default). Closing the tab SHALL restore the colorscheme that was active before the lab opened, unless the user loaded a vale variant from inside the lab.

#### Scenario: Open the lab
- **WHEN** the user runs `:ValeLab day`
- **THEN** a new tab shows sample buffers, the slot panel and the palette strip, and `vale-day` is active

#### Scenario: Close the lab
- **WHEN** the user had tokyonight-night active, opened `:ValeLab`, and closes the lab tab
- **THEN** tokyonight-night is active again

### Requirement: Multi-language samples with a shared token checklist
The lab SHALL ship sample files for Python, C#, Java, Kotlin, Rust, TypeScript, Lua, SQL and Bash, plus JSON, YAML, Markdown and Dockerfile. Each code sample SHALL contain every token kind in a single shared checklist that the language supports: keyword, control-flow keyword, function definition, function call, method, parameter, type/class, builtin type, property/field, constant, number, boolean, string, escape sequence, regex, comment, doc comment, TODO marker, decorator/attribute, operator, punctuation, namespace/import, generic type parameter. The C# and Java samples SHALL include minimal project files so their language servers attach and semantic tokens appear. When the grid cannot show every sample at once, the user SHALL be able to page through them.

#### Scenario: Semantic tokens in C# sample
- **WHEN** the lab is open and roslyn has finished loading
- **THEN** the C# sample buffer has LSP semantic token highlights applied

#### Scenario: Page samples
- **WHEN** the user presses the page key in the lab
- **THEN** the grid shows the next set of samples

### Requirement: Candidate cycling with live preview
For the current slot, the side panel SHALL list 3–5 candidate colours as swatches with their hex values, and candidate 1 SHALL always be the VS Code Modern reference value for that slot. `]c` and `[c` SHALL select the next and previous candidate and repaint every lab buffer and UI element with it immediately, without writing any file. The user SHALL be able to move to the next and previous slot in the picking order. The candidates offered for each slot SHALL be loaded from an editable candidates file that is re-read when it is saved.

#### Scenario: Preview a candidate
- **WHEN** the current slot is "keyword" and the user presses `]c`
- **THEN** every keyword in every visible sample changes to the next candidate colour and the palette file on disk is unchanged

#### Scenario: Reference first
- **WHEN** any slot is shown in the side panel
- **THEN** the first candidate is that slot's VS Code Modern reference value, labelled as such

#### Scenario: New candidates arrive
- **WHEN** the candidates file is edited and saved while the lab is open
- **THEN** the side panel shows the new candidates for the current slot

### Requirement: Contrast readout
Each candidate SHALL show its WCAG 2.x contrast ratio against the background it is used on (the editor background by default), and candidates below 4.5:1 for text slots SHALL be marked.

#### Scenario: Low-contrast warning
- **WHEN** a text-slot candidate has a contrast ratio of 3.2:1 against the editor background
- **THEN** the panel shows `3.2:1` with a low-contrast marker

### Requirement: Lock into the palette
Pressing `<CR>` on a candidate SHALL write its hex value into the active variant's palette file for that slot, change only that entry's value, keep its comment and the rest of the file byte-for-byte, and mark the slot as locked in the palette strip.

#### Scenario: Lock a colour
- **WHEN** the user presses `<CR>` on candidate 2 for the night "string" slot
- **THEN** the night palette file's string entry holds candidate 2's hex, its comment is unchanged, and `git diff` shows only that one line changed

### Requirement: Hot reload
While the lab is open, saving a palette file, the semantic mapping, or any vale highlight module SHALL reload the active vale variant, and every buffer SHALL show the new colours without reopening the lab.

#### Scenario: Hand-edit the palette
- **WHEN** the user edits a hex value in the night palette and writes the file with the lab open
- **THEN** the samples repaint with the new value
