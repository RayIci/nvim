## Why

Commit-message generation currently lives inside `lua/plugins/sidekick.lua` (~470 lines), tangled with Sidekick's CLI setup and keymaps. It is one-shot and non-interactive: the generated message lands in the commit buffer and the only way to change it is to edit by hand or regenerate from scratch. It supports two harnesses (`copilot`, `claude`), stores its settings in the shared `config.prefs` store — which caches the whole file in memory and so clobbers changes made by other Neovim instances — and always invokes the harness with its full tool surface, paying MCP-server startup cost for a task that needs no tools at all.

Pulling this into a dedicated `commitsmith` plugin gives it room to become what it should be: a short conversation with an agent about the commit message, with the buffer updated on every revision. The plugin lives in this repository for now and is designed to move to its own repository later without rework.

## What Changes

- **New plugin `commitsmith`** under `lua/commitsmith/`, wired from `lua/plugins/commitsmith.lua` (setup options, keymaps, fallback callback). All commit-generation code is removed from `lua/plugins/sidekick.lua`, which returns to configuring Sidekick only.
- **Three harnesses**: `codex`, `claude`, `copilot` — each an adapter owning its own argv construction, streaming event parsing, resume mechanism and lean-mode flags.
- **Global persisted settings** (`harness`, per-harness `model`, `lean`) in the plugin's own `stdpath("data")/commitsmith/settings.json`, read fresh on every access so a change made in one Neovim instance is picked up by the next read in another. `config.prefs` is no longer used for commit settings.
- **`:Commitsmith` command with subcommands**: `harness`, `model`, `generate`, `chat`, `stop`, `clear`, `lean`.
- **Interactive chat window**: a per-commit-buffer transcript showing the prompt sent (staged diff collapsed, expandable), each agent reply, and each refinement. A free-form input box plus canned refinements (`shorter`, `more detail`, `fix type/scope`, `regenerate`). Opening the window is independent of generation — it attaches to whatever is in flight or already produced.
- **Hybrid conversation model**: turn 1 sends rules + diff and pins a harness session id where possible; later turns resume that session, silently degrading to a full stateless replay (marked in the transcript) when resume is unavailable or fails.
- **Streaming** (`stream` default, `batch` opt-out): tokens render live in the window; the commit buffer is written once per completed revision, never mid-stream.
- **Lean mode**: an opt-in global toggle that invokes the harness with no tools and no MCP servers, since the diff is supplied inline and the agent needs none.
- **Cancellation**: `:Commitsmith stop` kills an in-flight generation. Starting a second generation while one is running is still refused.
- **Fallback stays in this config**: outside a `gitcommit` buffer, `generate` calls the `on_fallback(prompt)` callback supplied by `lua/plugins/commitsmith.lua`, which routes to `sidekick.cli.send`. The plugin itself has no Sidekick dependency.

## Capabilities

### New Capabilities
- `commit-message-ai`: everything the `commitsmith` plugin owns — harness/model selection and persistence, headless generation, the refinement conversation and its window, streaming, lean invocation, cancellation, and the non-commit-buffer fallback contract. Scoped so it can move to the plugin's own repository verbatim.

### Modified Capabilities
- `git-integration`: the two commit-message requirements are removed and replaced by a single wiring requirement — this configuration installs `commitsmith`, supplies its options and keymaps, and provides the fallback callback that routes to Sidekick.

## Non-goals

- No change to Sidekick's own CLI behaviour, prompts, or keymaps beyond deleting the commit-generation code from its module.
- No automatic generation when a commit buffer opens; generation stays user-triggered.
- No transcript persistence across commit buffers — closing the commit buffer discards its conversation.
- No publishing to GitHub in this change; the plugin stays in-repo.

## Impact

- **New**: `lua/commitsmith/` (init, settings, prompt, session, buffer, harness adapters, ui), `lua/plugins/commitsmith.lua`.
- **Modified**: `lua/plugins/sidekick.lua` (strip ~330 lines of commit-generation code), `lua/plugins/init.lua` (register `commitsmith`), `lua/plugins/whichkey.lua` (chat keymap labels), `README.md` (keymap table + commit-generation section).
- **Keymaps**: `<leader>am`/`<leader>gm` (generate) and `<leader>aM`/`<leader>gM` (harness+model) keep their meaning; new `<leader>ac` (global) and buffer-local `<leader>gc` in `gitcommit` buffers open the chat window.
- **Settings migration**: the `sidekick_commit_generation` key in `prefs.json` is read once, if present, to seed the new settings file, then ignored.
- No new plugin dependencies; the window is built on existing `nui.nvim` or plain API.
