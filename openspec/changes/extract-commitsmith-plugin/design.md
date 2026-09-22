## Context

`lua/plugins/sidekick.lua` does two unrelated jobs: it configures `folke/sidekick.nvim`, and it implements headless commit-message generation. The second job is ~330 of its ~470 lines and has nothing to do with Sidekick except a fallback call and a shared prompt string.

Today's generation flow: read `git diff --staged`, append it to a prompt, run `copilot --prompt` or `claude --print` via `vim.system`, strip fences/quotes from stdout, and replace the commit buffer's lines above the first `#` comment. Settings (`tool`, `models[tool]`) live under the `sidekick_commit_generation` key in the shared `config.prefs` store.

Verified CLI capabilities on this machine (claude 2.1.278, codex-cli 0.154.0, copilot 1.0.87):

| | one-shot | clean output | streaming | resume | no MCP / no tools |
|---|---|---|---|---|---|
| claude | `--print` | `--output-format text\|json` | `--output-format stream-json --include-partial-messages` | `--session-id <uuid>` to pin, `--resume <id>` | `--strict-mcp-config` (no `--mcp-config` ⇒ zero servers), `--restricted` |
| codex | `codex exec` | `-o <file>` (last message only) | `--json` (JSONL, **no text deltas**) | `codex exec resume <id>`, id from `thread.started`; rejects `-s` and `--color` | `-c mcp_servers={}`, `-s read-only` (new sessions only) |
| copilot | `-p/--prompt` | `-s/--silent` | `--output-format json` + `--stream on` | `--session-id <id>` to pin, `--resume <id>` | `--disable-builtin-mcps`, `--disable-mcp-server <name>` per server (no "disable all" flag), `--available-tools` |

## Goals / Non-Goals

**Goals**
- A self-contained plugin that can move to its own repository with a `git mv` plus a `vim.pack` entry change.
- Three harnesses behind one adapter interface; adding a fourth touches one file.
- A short, interactive conversation that rewrites the commit message in place.
- Settings that are genuinely global across concurrent Neovim instances.
- An opt-in invocation mode with no tool/MCP startup overhead.

**Non-Goals**
- Not a general chat UI — the conversation's only product is a commit message.
- Not a Sidekick replacement or wrapper; the plugin does not depend on Sidekick.
- Not persisting conversations beyond the life of a commit buffer.
- Not auto-detecting harness model lists (no CLI exposes one).

## Decisions

### D1: Adapter-per-harness with a narrow interface

Each of `lua/commitsmith/harness/{claude,codex,copilot}.lua` returns a table:

```
{
  name, label, default_model, models,
  available(),                  -- executable on PATH
  build(opts) -> cmd[], stdin?, -- opts: prompt, model, lean, session (pin|resume), format
  parse(chunk, state) -> events -- streaming: normalize to {delta=…} / {done=…} / {error=…}
  finalize(result) -> text,     -- batch: extract the message from stdout
  session_id(state) -> string?  -- what to resume with next turn, if anything
}
```

*Why:* the three CLIs disagree on every axis (flag names, output shape, session semantics, MCP suppression). A narrow interface keeps that divergence in three small files instead of smeared through branching. *Trade-off:* three streaming parsers to maintain. Accepted — streaming is a stated requirement and `batch` remains a working fallback if a parser breaks.

### D2: Hybrid conversation — pin a session, degrade to replay

Turn 1 always sends the full context (rules + staged diff) and, where the CLI allows, pins a session id we generate (`claude --session-id`, `copilot --session-id`). codex cannot be told an id, so we read it from the `--json` event stream.

Turn 2+ attempts `--resume`/`exec resume` with only the refinement text. On any failure — id never captured, resume rejected, session expired, CLI flags changed — the turn falls back to a **stateless replay**: rules + diff + latest message + refinement, as one fresh call.

*Why:* resume is cheap and natural when it works, but three different id strategies (one of them parse-based) is exactly the kind of thing that rots across CLI releases. The ladder means a broken resume costs tokens, not a broken feature.

*Degradation is silent but visible*: no notification, but the transcript records a dim `· full context replayed` marker on that turn. *Rejected:* a hard error on resume failure (interrupts the task for something recoverable); a user-facing session/replay choice (no one wants to make this decision per commit). A `conversation = "auto" | "session" | "replay"` option exists to force either end for debugging.

### D3: Streaming renders to the window only; the buffer is written on completion

The window transcript updates token by token. The commit buffer is replaced once, when a revision completes.

*Why:* a half-written commit message in the buffer is a footgun — `:wq` at the wrong moment commits a truncated message. The buffer is the artifact, not a progress indicator. *Trade-off:* the buffer feels less "live" than the window; acceptable, since the window is where you are watching.

`output = "stream" | "batch"`, default `stream`. In `batch` the transcript still records the outgoing turn immediately, then a spinner, then the reply — so the window is never blank while work is happening.

### D4: Transcript keyed to the commit buffer

State lives in a table keyed by `bufnr`, cleared on `BufWipeout`. Closing the chat window does not touch it; reopening re-renders. `:Commitsmith clear` resets the conversation in place (drops turns and any session id) without closing anything.

*Why:* a commit buffer is exactly the scope of one commit message. Persisting across buffers would mean deciding when a conversation is stale, which is a worse problem than retyping a refinement.

### D5: Settings in the plugin's own file, read on every access

`stdpath("data")/commitsmith/settings.json`, holding `{ harness, models = {…}, lean }`. Every `get` reads the file; every `set` re-reads, merges its one key, and writes.

*Why:* `config.prefs` caches the whole JSON in memory on first read and writes the entire cache back on `set` — two Neovim instances overwrite each other's keys with stale snapshots, which directly contradicts "persisted across different Neovim instances". The file is a few hundred bytes and is read a handful of times per commit, so skipping the cache entirely is both the correct and the simplest fix.

*Why a separate file rather than fixing `config.prefs`:* the plugin must own its state to be movable. Fixing `config.prefs`' clobbering for its other consumers is a separate concern, out of scope here.

On first run, if `harness` is unset and `prefs.json` contains `sidekick_commit_generation`, seed from it (mapping `tool` → `harness`) so the existing choice survives the extraction.

### D6: Lean mode disables tools, not just MCP

`lean = true` invokes the harness with no tool surface at all:

- claude: `--strict-mcp-config --restricted`
- codex: `-c mcp_servers={} -s read-only` on a new session, `-c mcp_servers={}` alone on a resumed one (`resume` rejects `-s`)
- copilot: `--disable-builtin-mcps --available-tools` (empty allowlist)

*Why:* the diff is supplied inline, so the agent needs zero tools; MCP startup is merely the loudest part of the overhead. This also sidesteps copilot's missing "disable all MCP servers" flag — with an empty tool allowlist there is nothing to enumerate `--disable-mcp-server` for.

*Trade-off:* in the session-resume path the flags must be re-passed on every turn, since each invocation is a fresh process. *Rejected:* enumerating `copilot mcp list` and emitting one `--disable-mcp-server` per server — an extra subprocess per generation to solve a problem the tool allowlist already solves.

`lean` defaults to `false` (today's behaviour) and is toggled globally with `:Commitsmith lean`.

### D7: Command surface and blast radius

One command, `:Commitsmith <subcommand>`, with completion. Settings subcommands work anywhere; buffer-scoped ones require a `gitcommit` buffer:

| subcommand | in `gitcommit` | elsewhere |
|---|---|---|
| `generate` | generate in background | `on_fallback(prompt)` |
| `chat` | toggle window | error: not a commit buffer |
| `stop` / `clear` | act on the conversation | error: not a commit buffer |
| `harness` / `model` / `lean` | global setting | global setting |

### D8: Missing harness is a hard error

If the persisted harness is not on `PATH`, generation fails with a message naming the harness and pointing at `:Commitsmith harness`. *Why:* silently switching harnesses changes the model, cost and output style without consent; falling through to Sidekick would hide a broken install behind a different UX. *Rejected:* auto-pick next available (surprising); silent Sidekick fallback (masks the real problem).

### D9: One prompt template

`prompt.lua` owns a single Conventional Commits rule block, rendered two ways: with the diff inlined (headless), or with an instruction to run `git diff --staged` (the fallback prompt handed to `on_fallback`). *Why:* today's two near-identical strings in `sidekick.lua` drift independently; the rules are the part that must not diverge.

### D10: Amend feeds the existing message in as context

When the commit buffer opens non-empty (`git commit --amend`, or a re-run after abort), the existing message is included in turn 1 as the current draft to revise. No generation runs automatically — the spec's no-auto-generation rule is preserved.

### Verified against the installed CLIs

The probes in tasks 3.1-3.3 were run against a scratch repository with a real staged
diff. All three harnesses returned a bare, conforming commit message in batch mode with
the lean flags applied. Four findings changed the implementation:

- **codex emits no incremental text deltas.** Its `--json` stream is four events
  (`thread.started`, `turn.started`, `item.completed`, `turn.completed`) and the entire
  message arrives at once in `item.completed.item.text`. Streaming mode therefore cannot
  make codex type a message out; the adapter emits one large delta on arrival and the
  window shows progress until then. This is a property of the CLI, not something the
  plugin can work around, so `output = "stream"` is honoured but degenerate for codex.
- **`codex exec resume` takes a strict subset of `codex exec`'s flags.** Passing `-s`
  or `--color` aborts with exit 2 and a usage error. Lean mode on a resumed codex turn
  is therefore `-c mcp_servers={}` alone, without `-s read-only`.
- **codex blocks on stdin.** It prints "Reading additional input from stdin..." and waits
  forever when stdin stays open, even with the prompt passed as an argument. Every codex
  invocation must hand it a closed or empty stdin.
- **copilot omits the blank line after the title.** It otherwise follows the prompt, so
  title/body separation is normalized when the message is applied rather than by
  tightening the prompt further.

- **The prompt must travel on stdin, not argv.** Linux caps a single argv entry at
  `MAX_ARG_STRLEN` (128 KB) independently of total `ARG_MAX`, and a staged diff passes
  that routinely -- a 180 KB diff aborts with `E2BIG: argument list too long` before the
  harness starts. All three CLIs read the prompt from stdin instead (`claude --print`
  and `copilot` with no prompt flag, `codex exec -`), which also settles codex's stdin
  wait. Verified against a 179,699-byte diff: the argv form raises E2BIG, the stdin form
  succeeds.
- **git must not be run from the commit buffer's own directory.** A commit buffer lives
  inside the git dir, and `git commit` exports `GIT_INDEX_FILE` (and `GIT_DIR`) as paths
  relative to the work tree's top level. Running `git diff --staged` with cwd `.git/`
  resolves `.git/index` to `.git/.git/index`, which does not exist; git then reads an
  empty index and reports every staged file as a deletion -- a whole repository as
  `+0/-N`. This only appears when Neovim is launched *as git's editor*, so opening
  `COMMIT_EDITMSG` by hand in a test never shows it. git runs the editor from the top
  level, so its cwd is used, but only after checking that its git dir is the one holding
  the buffer -- otherwise a commit buffer opened by hand while Neovim sits in another
  repository would diff the wrong tree. `GIT_INDEX_FILE` is deliberately left in place:
  a partial commit points it at a temporary index, and that is the index being committed.

- **A failing harness reports why on stdout in stream mode.** Errors arrive as JSON
  events, not on stderr, so discarding stdout left only "exited with code 1" -- which is
  what a context-window overflow looked like when a small-context model met a large diff.
  The runner now keeps a bounded tail of stdout and prefers, in order: an error event
  seen mid-stream, stderr, a message dug out of the output, and only then the exit code.
- **codex resume is occasionally not yet resumable** immediately after the turn that
  created the thread, presumably before its session file is flushed. The ladder absorbs
  this as a replay, which is the behaviour D2 was built for.

Confirmed as designed: copilot accepts an empty `--available-tools` allowlist, and its
`session.mcp_servers_loaded` event reports `github-mcp-server` with
`"status": "disabled"` under lean mode, so D6 needs no per-server enumeration fallback.
claude's `result` event carries `is_error` and the full `result` text, which is preferred
over accumulated deltas as the authoritative message. Session resume round-trips
correctly on all three: each recalled its previous reply when asked.

## Risks / Trade-offs

- **Three streaming parsers are the most version-fragile part.** Each is written against a captured event sample from the installed CLI. Mitigation: `batch` is a complete, simple path; a parser failure degrades to it rather than failing the generation.
- **Hardcoded model lists go stale** (today's list already contains models that may not exist). Mitigation: `setup()` accepts a per-harness `models` override, and the picker offers a free-text `custom…` entry.
- **A model's context window bounds the diff it can take.** A small-context model paired
  with a large staged diff fails inside the harness; the plugin surfaces the harness's own
  message rather than guessing a size limit of its own, since the ceiling is per-model.
- **codex cannot stream token-by-token**, so the streaming setting buys nothing for that harness beyond a progress indicator. Accepted: the alternative is hiding a setting per harness, which is worse than a setting that is simply less visible on one of them.
- **No-cache settings reads assume the file stays tiny.** It holds three keys; if it ever grows, revisit with an mtime check.

## Migration Plan

1. Build `commitsmith` alongside the existing code — both paths work.
2. Switch `lua/plugins/init.lua` to call `commitsmith.setup()`, keeping Sidekick's `<leader>am` mapping until verified.
3. Delete commit-generation code from `lua/plugins/sidekick.lua`.
4. Seed settings from `prefs.json` on first run; leave the old key in place (harmless).

No rollback concerns: reverting the commit restores the previous module, and the old `prefs.json` key is never deleted.

## Open Questions

- Should `commitsmith` eventually expose a `lualine` component showing the active harness/model? Out of scope; noted for the standalone repository.
