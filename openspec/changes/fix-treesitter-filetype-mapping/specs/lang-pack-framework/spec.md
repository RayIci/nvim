# Spec Delta

## ADDED Requirements

### Requirement: Treesitter parser-to-filetype mapping
A language pack's `treesitter` field SHALL accept two entry forms, which MAY be mixed in one pack: a bare parser name (e.g. `"python"`), or a `parser = { filetypes }` entry. Every declared parser SHALL be installed. Treesitter highlighting and indentation SHALL be started for a buffer when the `FileType` event fires, by resolving the buffer's filetype to a parser through Neovim's treesitter registry at that moment (after all plugins have registered their mappings), and then:
- for a parser declared bare, starting on any filetype the registry maps to it;
- for a parser declared with a filetype list, starting only on the listed filetypes, and registering that list with the treesitter registry; an empty list installs the parser without starting it on any filetype.

When several packs declare the same parser, explicit filetype lists SHALL be combined, and an explicit list SHALL take precedence over a bare declaration.

#### Scenario: Parser name differs from filetype
- **WHEN** a pack declares the bare parser `c_sharp` and a `.cs` file (filetype `cs`) is opened
- **THEN** treesitter highlighting is active in that buffer

#### Scenario: Explicit filetype list restricts
- **WHEN** a pack declares `xml = { "xml" }` and an `.svg` file (filetype `svg`, mapped to the xml parser by nvim-treesitter) is opened
- **THEN** treesitter highlighting is not started in that buffer

#### Scenario: Explicit filetype list adds
- **WHEN** a pack declares `json = { "json", "jsonc" }` and a `.jsonc` file is opened
- **THEN** treesitter highlighting via the json parser is active

#### Scenario: Install without enabling
- **WHEN** a pack declares `latex = {}`
- **THEN** the latex parser is installed, and opening a `.tex` file does not start treesitter highlighting

#### Scenario: Filetypes without a pack parser
- **WHEN** a buffer of a filetype with no declared parser (e.g. `neo-tree`, `qf`) is created
- **THEN** no treesitter highlighting is started and no error is shown
