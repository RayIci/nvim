## 1. Plugin skeleton and settings

- [x] 1.1 Create `lua/commitsmith/init.lua` with `setup(opts)` merging defaults: `harnesses`, `models` overrides, `output = "stream"`, `conversation = "auto"`, `apply = "auto"`, `window = { layout = "right", width = 84 }`, `on_fallback`. Register `:Commitsmith` with subcommand completion.
- [x] 1.2 Create `lua/commitsmith/settings.lua` backed by `stdpath("data")/commitsmith/settings.json`, holding `harness`, `models` and `lean`. Read the file on every `get`; on `set`, re-read, merge the single key, write. No in-process cache (see design D5).
- [x] 1.3 Seed settings on first run from `prefs.json`'s `sidekick_commit_generation` key when `harness` is unset, mapping `tool` → `harness`; leave the old key in place.
- [x] 1.4 Create `lua/commitsmith/prompt.lua` with one Conventional Commits rule block rendered two ways: diff inlined (headless) and agent-fetches-diff (fallback). Include an optional "current draft to revise" section for amend and refinement turns.

## 2. Harness adapters

- [x] 2.1 Define the adapter contract in `lua/commitsmith/harness/init.lua`: `available()`, `build(opts)`, `parse(chunk, state)`, `finalize(result)`, `session_id(state)`; plus registry lookup and installed-harness discovery.
- [x] 2.2 `harness/claude.lua` — `--print`; `--output-format stream-json --include-partial-messages` for stream, `--output-format text` for batch; `--model` when not default; pin `--session-id <uuid>`, resume with `--resume <id>`; lean → `--strict-mcp-config --restricted`.
- [x] 2.3 `harness/codex.lua` — `codex exec`; `--json` JSONL for stream, `-o <tmpfile>` for batch; `-m` when not default; capture the session id from the JSONL event stream, resume with `codex exec resume <id>`; lean → `-c mcp_servers={} -s read-only`.
- [x] 2.4 `harness/copilot.lua` — `-p`; `--output-format json --stream on` for stream, `-s/--silent` for batch (drop the stale `--no-color`); `--model` when not `auto`; pin `--session-id <uuid>`, resume with `--resume <id>`; lean → `--disable-builtin-mcps` + empty `--available-tools`.
- [x] 2.5 Per-harness model lists with a default/automatic entry, overridable via `setup({ models = { … } })`, plus a `custom…` free-text entry in the picker.

## 3. Verify harness invocations outside Neovim

- [x] 3.1 For each harness, run the batch command by hand against a real staged diff and confirm stdout is the bare commit message.
- [x] 3.2 For each harness, confirm the lean flags are accepted and that MCP servers do not start. Verified: copilot accepts an empty `--available-tools` and reports `github-mcp-server` as `disabled` in `session.mcp_servers_loaded`, so no enumeration fallback is needed. codex's `resume` subcommand rejects `-s`, so lean differs between new and resumed turns (design D6 amended).
- [x] 3.3 For each harness, confirm the session pin/resume round-trip works and capture one real streaming event sample per harness to write the parsers against. Findings recorded in design.md: codex emits no text deltas, rejects `-s`/`--color` on `resume`, and hangs unless stdin is closed.

## 4. Generation and commit buffer

- [x] 4.1 `lua/commitsmith/buffer.lua` — replace lines above the first `#` comment, preserve the comment block, reset the cursor. Port and keep the fence/quote stripping from today's `clean_commit_message`.
- [x] 4.2 `lua/commitsmith/session.lua` — per-`bufnr` transcript (turns, current message, status, session id, process handle), cleared on `BufWipeout`; `clear()` resets in place.
- [x] 4.3 Generation pipeline: read `git diff --staged --no-ext-diff`, error on empty; build the prompt; dispatch through the adapter with `vim.system`; on completion apply to the buffer per the `apply` setting.
- [x] 4.4 Conversation ladder: turn 1 full context + pin session; turn 2+ resume, falling back to stateless replay on any failure and recording a `full context replayed` marker on that turn. Honour `conversation = "auto" | "session" | "replay"`.
- [x] 4.5 Amend support: when the commit buffer opens non-empty, include the existing message as the draft to revise. No automatic generation on buffer open.
- [x] 4.6 Concurrency: refuse a second generation for a buffer; `stop` kills the process via the `vim.system` handle, records the cancellation and leaves the buffer untouched. Abandon cleanly if the buffer is wiped mid-flight.
- [x] 4.7 Hard-error when the persisted harness is not on `PATH`, naming it and pointing at `:Commitsmith harness`.

## 5. Conversation window

- [x] 5.1 `lua/commitsmith/ui/window.lua` — transcript buffer, right-split default, layout configurable; renders request/reply/refinement turns, the replay marker, and status.
- [x] 5.2 Collapsed diff summary (`staged diff: N files, +X/-Y`) inside the request entry, expandable in place.
- [x] 5.3 `lua/commitsmith/ui/input.lua` — free-form refinement input, submit sends a refinement turn.
- [x] 5.4 Canned refinements on single keys: shorter, more detail, fix type/scope, regenerate.
- [x] 5.5 Attach semantics: opening mid-generation streams into the transcript; opening after completion shows the finished conversation; opening with no prior generation starts one.
- [x] 5.6 Streaming renders to the window only; write the commit buffer once per completed revision. In batch mode show the outgoing turn immediately plus a progress indicator.

## 6. Command surface

- [x] 6.1 Subcommands `harness`, `model`, `generate`, `chat`, `stop`, `clear`, `lean` with completion.
- [x] 6.2 Scoping: settings subcommands work anywhere; `chat`/`stop`/`clear` error outside `gitcommit`; `generate` outside `gitcommit` calls `on_fallback(prompt)`, or errors when none is configured.

## 7. Wire into this configuration

- [x] 7.1 Add `lua/plugins/commitsmith.lua` calling `setup()` with `on_fallback = function(prompt) require("sidekick.cli").send({ prompt = prompt }) end` and the keymaps: `<leader>am`/`<leader>aM`/`<leader>ac` global, buffer-local `<leader>gm`/`<leader>gM`/`<leader>gc` on `FileType gitcommit`.
- [x] 7.2 Register `require("plugins.commitsmith").setup()` in `lua/plugins/init.lua` under the AI section.
- [x] 7.3 Strip commit-message generation from `lua/plugins/sidekick.lua`: remove the prompts, tool/model tables, spinner, preference helpers, headless command builder, generation pipeline, pickers, `<leader>am`/`<leader>aM`, `:SidekickCommitSettings`, and the `gitcommit` autocmd. Keep the `commit` entry in Sidekick's `prompts` table for the interactive path.
- [x] 7.4 Add which-key labels for `<leader>ac` and the buffer-local `<leader>gc`. (No edit needed: whichkey.lua declares groups only; per-key labels come from each keymap's `desc`, which the wiring sets.)
- [x] 7.5 Update `README.md`: keymap table rows for `<leader>a`/`<leader>g`, and rewrite the commit-generation section for the three harnesses, the conversation window, and lean mode.

## 8. Verify in Neovim

- [x] 8.1 Fresh start with no settings file: `:Commitsmith harness` lists all three with installed/missing status; picking one opens its model picker; the choice lands in `stdpath("data")/commitsmith/settings.json`.
- [x] 8.2 Existing `prefs.json` with `sidekick_commit_generation`: confirm the harness and model are seeded on first run.
- [x] 8.3 Two concurrent Neovim instances: change the harness in A, generate in B, confirm B uses the new harness.
- [x] 8.4 For each of the three harnesses: stage a change, `git commit`, press `<leader>gm`, confirm a conforming message lands above the comment block. (Fixed two bugs found here: session ids came from unseeded `math.random`, identical in every Neovim process, so a pinned `--session-id` collided and every run after the first failed; and an empty stderr was reported as a blank reason, hiding it.)
- [x] 8.5 Open the window mid-generation and confirm the reply streams in; confirm the commit buffer is untouched until completion.
- [x] 8.6 Send a free-form refinement and a canned refinement; confirm the buffer is replaced on each revision and the transcript grows.
- [x] 8.7 Set `apply = "manual"` and confirm the buffer stays unchanged until the revision is accepted.
- [x] 8.8 Force `conversation = "replay"`, then `"session"`; confirm both produce revisions and that the replay marker appears only in the replay path.
- [x] 8.9 Toggle `:Commitsmith lean` and confirm the invocation carries the lean flags and starts no MCP servers.
- [x] 8.10 `:Commitsmith stop` mid-generation: process dies, buffer untouched, a new generation can start. Trigger generate twice in a row and confirm the second is refused.
- [x] 8.11 Close the window and reopen: transcript intact. Wipe the commit buffer, open a new one: transcript empty. `:Commitsmith clear`: transcript emptied in place.
- [x] 8.12 In a Lua buffer: `:Commitsmith chat`/`stop`/`clear` error politely; `harness`/`model`/`lean` work; `<leader>am` routes to Sidekick.
- [x] 8.13 `git commit --amend`: nothing generated on open; generating includes the previous message as the draft.
- [x] 8.14 Set the harness to one that is not installed and confirm the hard error names it and points at the selection subcommand.
- [x] 8.15 Commit with nothing staged and confirm the no-staged-changes message, with no harness process started.
- [x] 8.16 Run `openspec validate extract-commitsmith-plugin --strict`.
