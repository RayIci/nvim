# Spec Delta

## Purpose

Provides a clear visual indication of the source location where a debug session is currently stopped, helping users understand execution state while stepping through code.

## ADDED Requirements

### Requirement: Stopped execution location is visually indicated

The debugging configuration SHALL display a right-arrow indicator beside the source line where execution is stopped and SHALL apply a distinct background highlight to that entire line.

#### Scenario: Execution stops at a source location

- **WHEN** a debug session stops at a source line
- **THEN** a right-arrow indicator appears beside that line and the line receives the stopped-location background highlight

#### Scenario: Execution moves to another source location

- **WHEN** stepping or another debugger action moves execution to a different source line
- **THEN** the indicator and background highlight move to the new stopped line and are removed from the previous line

#### Scenario: Execution resumes or ends

- **WHEN** execution resumes, the debug session terminates, or the debug session exits
- **THEN** the stopped-location indicator and background highlight are removed

#### Scenario: Existing editor indicators are present

- **WHEN** the stopped line also contains breakpoints, diagnostics, or virtual text
- **THEN** the stopped-location indicator and highlight remain visible without removing or corrupting those existing editor indicators
