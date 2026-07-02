# Enforcement — making the rules mandatory, not optional

A skill the agent *may* load is advice. Advice degrades exactly when it is
needed most: under context pressure, late in a long session, the model
forgets its own rules. Enforcement moves the rules out of the model's
discretion and into the harness, where they run deterministically on every
session and every tool call — 24/7, zero tokens until violated.

## The three layers

| Layer | Mechanism | Cost | Can the model skip it? |
|---|---|---|---|
| 1. Hard guard | `PreToolUse` hook blocks flooding tool calls | 0 tokens until a violation | **No** — the harness denies the call |
| 2. Always-on rules | `SessionStart` hook or memory-file block injects `core-rules.md` | ~250 tokens/session, prefix-cache-friendly | No — injected before the first turn |
| 3. On-demand detail | The skill's modules, loaded per situation | Only when loaded | Yes — by design (progressive disclosure) |

Layer 1 is the teeth, layer 2 is the memory, layer 3 is the textbook.

## Layer 1: the hard guard (`hooks/gardener_guard.py pre-tool-use`)

Registered by `install.sh` as a `PreToolUse` hook on `Read|Bash`. On a
violation it exits 2; the harness blocks the tool call and feeds the stderr
message back to the agent. Every deny message names the cheaper move, so
the agent self-corrects in one step instead of being silently stuck.

Blocked by default:

- **Read** of forbidden paths: `node_modules/`, `vendor/`, `.venv/`,
  `dist/`, `build/`, `target/`, `.next/`, `.git/` internals
- **Read** of lockfiles (`package-lock.json`, `yarn.lock`, `Cargo.lock`, …)
  and build artifacts (`*.min.js`, `*.map`, archives, bytecode)
- **Read** of files > 256 KB without `offset`/`limit` (images, PDFs and
  notebooks exempt — the Read tool handles those natively)
- **Bash** unfiltered dumps: `cat` of a lockfile, of `node_modules/` files,
  or of minified bundles with no pipe to a filter

With `GARDENER_STRICT=1` additionally blocked:

- unbounded `git log` (no `-n`, no `--oneline`, no `head`/`tail`)
- unfiltered test runs (`npm test`, `pytest`, … with no pipe or redirect)

Escape hatches (deliberate, visible — not loopholes):

- `GARDENER_DISABLE=1` — turns the guard off entirely
- `GARDENER_ALLOW=1 <command>` — one-shot Bash override when the user
  explicitly asked for the exact content; the marker in the command line
  keeps the override auditable in the transcript
- Blocked large Read → retry with explicit `offset`/`limit` passes

The guard **fails open**: any internal error exits 0. A token-saver that
breaks the workflow has failed its own quality gate.

## Layer 2: always-on core rules

`core-rules.md` is the single source of truth for the ~20-line rules block.
Two delivery paths, automatically deduplicated:

1. **SessionStart hook** (default, registered by `install.sh`): injects the
   block at session start — *unless* a global or project `CLAUDE.md`
   already contains the `gardener:core-rules` marker or a "Token
   Efficiency" section. No double-paying.
2. **Memory-file block** (`install.sh --with-memory-block`): appends the
   block to `~/.claude/CLAUDE.md` (Claude Code) or `~/.hermes/SOUL.md`
   (Hermes). Preferable for harnesses without hook support; also the more
   prefix-cache-stable placement.

Pick one; the hook detects the other. `uninstall.sh` removes only
marker-delimited blocks, never hand-written sections.

## Layer 3: the skill itself

Unchanged progressive disclosure: `SKILL.md` is the map, modules load on
demand. Enforcement does not replace judgment — the guard blocks the
mechanical failure modes, the modules teach the strategic ones
(delegation, caching structure, model routing, measurement).

## Harness support matrix

| Harness | Layer 1 (hooks) | Layer 2 | Layer 3 |
|---|---|---|---|
| Claude Code | ✅ `install.sh` | ✅ SessionStart or CLAUDE.md | ✅ |
| Hermes / other markdown-skill harnesses | ❌ no hook API | ✅ `--with-memory-block` into SOUL.md/AGENT.md | ✅ |
| Direct API agents (custom loop) | ✅ wrap tool dispatch: call the guard on stdin-JSON before executing | ✅ prepend `core-rules.md` to the system prompt | ✅ |

For custom loops: pipe `{"tool_name": "Read", "tool_input": {...}}` to
`gardener_guard.py pre-tool-use`; exit 2 means deny and stderr is the
feedback to give the model.

## Why not a daemon?

"Runs 24/7" does not require a background process. Hooks are event-driven:
they exist as configuration and execute in milliseconds exactly when a
session starts or a tool is called. A daemon would burn resources to poll
for events the harness already delivers — the guard is permanent without
being resident.
