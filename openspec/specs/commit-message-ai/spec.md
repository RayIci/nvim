# commit-message-ai Specification

## Purpose
AI-assisted commit-message authoring inside Neovim: selecting and persisting which agent CLI harness and model to use, generating a Conventional Commits message from the staged diff without leaving the commit buffer, and refining that message through a short conversation with the agent until it is right.

## Requirements

### Requirement: Self-contained commit-message plugin
The commit-message generation logic SHALL live in a self-contained `commitsmith` plugin module that does not depend on Sidekick or on the host configuration's preference store, so it can be relocated to its own repository without code changes. The plugin SHALL expose a `setup(opts)` entry point accepting its configuration, and SHALL NOT register keymaps that the host configuration has not asked for.

#### Scenario: Plugin configured by the host
- **WHEN** the host configuration calls the plugin's `setup()` with options
- **THEN** the plugin registers its command and applies the supplied options
- **AND** no Sidekick module is required by the plugin itself

#### Scenario: Relocatable module
- **WHEN** the plugin directory is moved to a standalone repository and loaded from there
- **THEN** it functions identically without edits to its own source

### Requirement: Harness selection and persistence
The plugin SHALL support the `codex`, `claude`, and `copilot` harnesses for headless commit-message generation. It SHALL provide a selection flow that discovers which harnesses are installed, presents them for selection with their availability shown, and then presents the model choices for the selected harness. The selected harness and its model SHALL be persisted in storage owned by the plugin, global to the user rather than scoped to a project or session.

Persisted settings SHALL be read from storage on each access rather than from an in-process cache, so that a setting changed in one Neovim instance is observed by any other instance on its next read.

The built-in model list for each harness SHALL be overridable through `setup()`, and the model picker SHALL offer a free-text entry for a model that is not in the list.

#### Scenario: Choose a harness
- **WHEN** the user invokes the harness subcommand
- **THEN** the plugin presents `codex`, `claude`, and `copilot`, each marked installed or missing
- **AND** selecting one stores it as the active harness

#### Scenario: Model picker follows the harness
- **WHEN** the user selects a harness
- **THEN** the plugin presents only the model choices for that harness, including a default/automatic option and a free-text custom entry
- **AND** selecting a model stores it against that harness

#### Scenario: Settings survive restart
- **WHEN** the user restarts Neovim after selecting a harness and model
- **THEN** the next generation uses the persisted harness and model without reselection

#### Scenario: Settings shared across instances
- **WHEN** the user changes the harness in one Neovim instance
- **THEN** another already-running Neovim instance uses the new harness on its next generation

#### Scenario: Custom model entry
- **WHEN** the user picks the custom entry in the model picker and types a model identifier
- **THEN** that identifier is persisted and passed to the harness on subsequent generations

### Requirement: Headless commit-message generation
The plugin SHALL generate commit messages from a `gitcommit` buffer by reading the staged diff, invoking the persisted harness non-interactively with the diff supplied inline, and replacing the commit buffer's message lines above the first comment line with the result. The generated message SHALL follow Conventional Commits: a single `type(scope): summary` title line of at most 72 characters, then a body wrapped at 72 characters that begins with a short introductory sentence, followed by a `- ` bullet list of concrete changes, with an optional closing rationale paragraph. The harness SHALL be instructed to return only the raw commit message, and the plugin SHALL strip code fences and surrounding quotes from the response.

Generation SHALL be triggered only by explicit user action; opening a commit buffer SHALL NOT start generation.

When the commit buffer already contains a message, such as during `git commit --amend`, that message SHALL be supplied to the harness as the current draft to revise.

#### Scenario: Generate from a commit buffer
- **WHEN** the user invokes the generate action in a `gitcommit` buffer with staged changes
- **THEN** the plugin runs the persisted harness non-interactively with the staged diff
- **AND** progress is indicated while generation runs
- **AND** the returned message replaces the commit buffer's lines above the comment block, leaving the comment block intact

#### Scenario: No automatic message on a fresh commit
- **WHEN** the user runs `git commit` with staged changes and the commit buffer opens empty
- **THEN** no message is generated or inserted automatically

#### Scenario: Amend supplies the existing message
- **WHEN** the user runs `git commit --amend` and then invokes the generate action
- **THEN** no generation ran automatically when the buffer opened
- **AND** the existing message is included in the request as the draft to revise

#### Scenario: No staged changes
- **WHEN** the user invokes the generate action with nothing staged
- **THEN** the plugin reports that there are no staged changes and does not invoke the harness

#### Scenario: Response cleanup
- **WHEN** the harness returns a message wrapped in code fences or quotes
- **THEN** the fences and surrounding quotes are removed before the message is applied

### Requirement: Interactive refinement conversation
The plugin SHALL maintain a conversation for each commit buffer, comprising the request sent, every harness reply, and every user refinement. The user SHALL be able to refine the current message by sending further instructions, and each completed revision SHALL replace the commit message in the commit buffer. Whether revisions are applied automatically or require explicit acceptance SHALL be configurable, defaulting to automatic application on every revision.

The conversation SHALL be scoped to its commit buffer: it SHALL survive closing the conversation window and SHALL be discarded when the commit buffer is wiped, so a newly opened commit buffer starts a fresh conversation. The user SHALL be able to clear the conversation and start over without closing the buffer or the window.

The first turn SHALL send the full context and, where the harness supports pinning or reporting a session identifier, record it. Later turns SHALL resume that session when possible and SHALL otherwise resend the full context together with the current message and the refinement. A turn that resends full context because resume was unavailable SHALL be marked as such in the conversation.

#### Scenario: Refine the message
- **WHEN** the user sends a refinement instruction for a generated message
- **THEN** the harness is asked to revise the message accordingly
- **AND** the resulting revision replaces the commit message in the commit buffer

#### Scenario: Explicit acceptance mode
- **WHEN** automatic application is disabled in configuration and a revision completes
- **THEN** the commit buffer is left unchanged until the user accepts the revision

#### Scenario: Conversation outlives the window
- **WHEN** the user closes the conversation window and reopens it for the same commit buffer
- **THEN** the previous turns are still shown

#### Scenario: Conversation ends with the buffer
- **WHEN** the commit buffer is wiped and a new commit buffer is opened
- **THEN** the new buffer starts with an empty conversation

#### Scenario: Clear and restart
- **WHEN** the user invokes the clear action
- **THEN** the conversation is emptied, any recorded session identifier is dropped, and the next generation starts fresh

#### Scenario: Resume unavailable
- **WHEN** a refinement cannot resume the harness session
- **THEN** the plugin resends the full context with the current message and the refinement instead of failing
- **AND** the conversation marks that turn as having resent full context

### Requirement: Conversation window
The plugin SHALL provide a window, opened and closed independently of generation, that displays the conversation for the current commit buffer and offers a free-form input for refinements. The window SHALL attach to whatever state exists when it opens, including a generation already in progress and a message already applied to the buffer. Opening the window when no generation has run SHALL start one.

The staged diff SHALL be shown collapsed as a summary within the request entry, expandable on demand.

The window SHALL offer canned refinement actions alongside the free-form input, including at minimum shortening, adding detail, correcting the type or scope, and regenerating from scratch.

The window's placement SHALL default to a right-hand vertical split and SHALL be configurable to other placements.

#### Scenario: Open the window mid-generation
- **WHEN** the user triggers generation and then opens the conversation window before it completes
- **THEN** the window shows the request and the reply as it arrives

#### Scenario: Open the window after generation
- **WHEN** the user opens the conversation window after a message has already been applied
- **THEN** the window shows the completed conversation and is ready to accept a refinement

#### Scenario: Open the window first
- **WHEN** the user opens the conversation window in a commit buffer where no generation has run
- **THEN** a generation is started

#### Scenario: Collapsed diff
- **WHEN** a request entry containing the staged diff is displayed
- **THEN** the diff is summarized rather than printed in full
- **AND** the user can expand it to see the full diff

#### Scenario: Canned refinement
- **WHEN** the user triggers a canned refinement from the window
- **THEN** that instruction is sent as a refinement turn without the user typing it

### Requirement: Streaming and batch output
The plugin SHALL support a streaming output mode, in which harness output is rendered progressively in the conversation window, and a batch mode, in which the reply appears once complete. The mode SHALL be configurable and SHALL default to streaming.

The commit buffer SHALL be written only when a revision is complete, never progressively, in either mode.

In batch mode the outgoing turn SHALL appear in the conversation immediately, with progress indicated until the reply arrives.

#### Scenario: Streaming render
- **WHEN** streaming mode is active and a generation is running
- **THEN** the reply appears progressively in the conversation window

#### Scenario: Commit buffer written once
- **WHEN** a reply is streaming
- **THEN** the commit buffer is unchanged until the revision completes
- **AND** the completed message is then written in a single update

#### Scenario: Batch mode feedback
- **WHEN** batch mode is active and a generation is running
- **THEN** the outgoing turn is already visible in the conversation and progress is indicated
- **AND** the reply is added when it completes

### Requirement: Lean invocation without tools or MCP servers
The plugin SHALL provide a global, persisted toggle that invokes the harness without MCP servers and without its tool surface, since the staged diff is supplied inline and no tools are required. The flags used to achieve this SHALL be specific to the selected harness. The toggle SHALL default to off and SHALL be changeable from Neovim.

#### Scenario: Lean invocation
- **WHEN** the lean toggle is enabled and a generation runs
- **THEN** the harness is invoked with its MCP servers and tool surface disabled

#### Scenario: Lean applies to every turn
- **WHEN** the lean toggle is enabled and the user sends a refinement
- **THEN** that invocation also disables MCP servers and tools

#### Scenario: Toggle persists globally
- **WHEN** the user toggles lean mode and restarts Neovim
- **THEN** the setting is still in effect

### Requirement: Concurrency and cancellation
The plugin SHALL refuse to start a second generation for a commit buffer while one is in flight, reporting that one is already running. The plugin SHALL provide an action that cancels an in-flight generation, terminating the harness process and leaving the commit buffer unchanged.

#### Scenario: Refuse a concurrent generation
- **WHEN** the user triggers generation while one is already running for that buffer
- **THEN** the plugin reports that a generation is in progress and starts no second process

#### Scenario: Cancel a generation
- **WHEN** the user invokes the stop action during a generation
- **THEN** the harness process is terminated, the conversation records the cancellation, and the commit buffer is unchanged
- **AND** a new generation can then be started

#### Scenario: Buffer closed during generation
- **WHEN** the commit buffer is wiped while a generation is in flight
- **THEN** the generation is abandoned and no message is applied

### Requirement: Command surface and buffer scoping
The plugin SHALL expose a single user command with subcommands for selecting the harness, selecting the model, generating, toggling the conversation window, stopping, clearing, and toggling lean mode, with completion for the subcommand names.

Subcommands that change global settings SHALL work in any buffer. Subcommands that act on a conversation SHALL require a `gitcommit` buffer and SHALL report a clear error elsewhere. The generate subcommand SHALL be the exception: outside a `gitcommit` buffer it SHALL delegate to the configured fallback.

#### Scenario: Settings subcommands anywhere
- **WHEN** the user invokes the harness, model, or lean subcommand from any buffer
- **THEN** the corresponding global setting flow runs

#### Scenario: Conversation subcommands require a commit buffer
- **WHEN** the user invokes the chat, stop, or clear subcommand outside a `gitcommit` buffer
- **THEN** the plugin reports that the action requires a commit buffer and does nothing else

#### Scenario: Subcommand completion
- **WHEN** the user requests completion for the command
- **THEN** the available subcommand names are offered

### Requirement: Fallback outside commit buffers
The plugin SHALL accept a fallback callback through its configuration and SHALL invoke it with a commit-message prompt when generation is requested outside a `gitcommit` buffer. That prompt SHALL carry the same Conventional Commits rules as the headless prompt but SHALL instruct the agent to obtain the staged diff itself rather than embedding it. The plugin SHALL NOT itself know about or depend on whatever the callback routes to.

The Conventional Commits rules SHALL be defined once and shared between the headless and fallback prompts.

#### Scenario: Generate outside a commit buffer
- **WHEN** the user invokes the generate action outside a `gitcommit` buffer
- **THEN** the plugin calls the configured fallback callback with the fallback prompt
- **AND** no harness process is started by the plugin

#### Scenario: Fallback prompt fetches its own diff
- **WHEN** the fallback prompt is rendered
- **THEN** it instructs the agent to inspect the staged changes itself
- **AND** it carries the same title, body, bullet-list and raw-output rules as the headless prompt

#### Scenario: No fallback configured
- **WHEN** generation is requested outside a `gitcommit` buffer and no fallback callback was configured
- **THEN** the plugin reports that the action requires a commit buffer

### Requirement: Missing harness is an error
When the persisted harness is not installed, the plugin SHALL fail the generation with an error naming the harness and pointing at the harness-selection subcommand. It SHALL NOT silently substitute another harness and SHALL NOT silently route to the fallback.

#### Scenario: Persisted harness not installed
- **WHEN** the user triggers generation and the persisted harness executable is not on `PATH`
- **THEN** the plugin reports the missing harness and how to change the selection
- **AND** no other harness is used and no fallback is invoked
