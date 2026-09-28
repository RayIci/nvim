# Spec Delta

## MODIFIED Requirements

### Requirement: LaTeX language pack
The configuration SHALL provide a latex pack with texlab LSP, tex-fmt formatting, the latex and bibtex treesitter parsers, vimtex (quickfix mode off; WSL uses a SumatraPDF forward-search viewer, non-WSL uses zathura), and wrapping.nvim for soft-wrap editing. The latex parser SHALL be installed (for LaTeX injected into other languages, e.g. markdown math) but SHALL NOT start treesitter highlighting in `tex` buffers, because vimtex's math text objects, math-zone detection and concealment depend on its own syntax highlighting. The bibtex parser SHALL highlight `bib` buffers.

#### Scenario: LaTeX editing
- **WHEN** a `.tex` file is opened
- **THEN** texlab attaches and vimtex commands (e.g. `:VimtexCompile`) are available

#### Scenario: vimtex keeps syntax highlighting
- **WHEN** a `.tex` file is opened
- **THEN** treesitter highlighting is not active in the buffer and vimtex's syntax highlighting is

#### Scenario: BibTeX highlighting
- **WHEN** a `.bib` file is opened
- **THEN** treesitter highlighting via the bibtex parser is active
