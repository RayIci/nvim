# Spec Delta

## ADDED Requirements

### Requirement: Octo colours follow the active colorscheme
On every colorscheme change, octo's colour palette SHALL be rebuilt from the active colorscheme's standard highlight groups (open/passing from `DiagnosticOk`, closed/failing from `DiagnosticError`, pending from `DiagnosticWarn`, merged from `Statement`, plus `DiagnosticInfo`, `Function`, `LineNr` and `Normal`), keeping octo's default for any colour whose source group lacks that attribute. The configuration SHALL NOT reference a specific colorscheme to do this.

#### Scenario: Octo under a third-party theme
- **WHEN** kanagawa-wave is active and an Octo PR buffer is open
- **THEN** the "open" state uses kanagawa-wave's `DiagnosticOk` colour

#### Scenario: Octo under vale
- **WHEN** vale-night is active
- **THEN** the "open" state uses vale-night's `DiagnosticOk` colour
