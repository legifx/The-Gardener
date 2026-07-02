# The Gardener 🌱 — `token-saver`

An agent skill that prunes LLM token consumption by **40-80%** (workload-
dependent) **without sacrificing output quality**. Works with Claude Code,
Hermes Agent, and any agent harness that loads markdown skills.

Like a gardener, it doesn't just cut — it prunes so the plant grows better:
a fuller context window means *worse* model output ("context rot"), so every
token kept out of the window is both money saved and quality preserved.

## How it works

Six layers, loaded progressively (the skill takes its own medicine —
`SKILL.md` is a small map, details live in modules loaded only when needed):

1. **Context hygiene** — grep first, read line ranges, cap tool output,
   forbidden paths, checkpoint + compact at natural boundaries.
2. **Project memory** — one lean persistent file (≤ 5,000 tokens) replaces
   re-explaining the project every session.
3. **Delegation** — subagents search in their own context, return a
   bounded summary; includes the 4-15× multi-agent cost warning.
4. **Caching** — stable-prefix prompt structure for ~90% cheaper cache
   reads; never re-buy a deterministic tool result.
5. **Output discipline & model routing** — diffs not files, structure not
   prose; expensive models plan, cheap models execute, with an automatic
   escalation rule after two failures.
6. **Measurement & quality gate** — before/after protocol; a saving only
   counts if the quality gate passes.

The two biggest levers are **caching** and **context hygiene** — they alone
account for most of the realistic 40-80% range. No miracle claims: your
savings depend on workload; long-running projects with recurring sessions
benefit most, one-shot trivia the least.

## Enforced, not optional (24/7)

Since v1.1.0 the skill has teeth: `install.sh` registers **deterministic
Claude Code hooks** that run on every session and every tool call — the
model cannot forget or skip them, and they cost zero tokens until violated:

- A `PreToolUse` guard **blocks** context-flooding calls (reads of
  `node_modules/`, lockfiles, minified bundles, unscoped reads of huge
  files, unfiltered `cat` dumps) and answers every block with the cheaper
  alternative, so the agent self-corrects in one step.
- A `SessionStart` hook injects the ~20-line core rules into every session
  — automatically skipped if your `CLAUDE.md` already carries them.
- Escape hatches: `GARDENER_DISABLE=1`, `GARDENER_STRICT=1` (also blocks
  unbounded `git log` / unfiltered test runs), one-shot `GARDENER_ALLOW=1`.

No daemon needed — hooks are event-driven configuration, permanent without
being resident. Details: [modules/enforcement.md](modules/enforcement.md).

## Installation

### Claude Code (skill + enforcement hooks)

```bash
git clone https://github.com/legifx/The-Gardener.git
cd The-Gardener
./install.sh
```

Idempotent, backs up `settings.json` before touching it. Restart your
Claude Code session afterwards so the hooks load.

### Hermes Agent (or other markdown-skill harnesses)

```bash
./install.sh --hermes --with-memory-block   # or --all for both harnesses
```

No hook API there, so `--with-memory-block` puts the core rules into the
agent's memory file (`SOUL.md`) — always-on layer 2 instead of layer 1.
Any harness that reads a `SKILL.md` with YAML frontmatter picks up the
skill itself.

Removal: `./uninstall.sh` (removes hooks, links, and marker-delimited
blocks; backs up everything it modifies).

## Quickstart

1. Install (above). The skill auto-triggers on long sessions, context
   warnings, cost questions, and at the start of large tasks.
2. For each project, create a memory file from
   `templates/CLAUDE.md.template` — this is the highest-leverage 15 minutes
   you can spend.
3. At milestones, write a checkpoint from `templates/session-checkpoint.md`,
   commit, and compact the session.
4. Measure: see `modules/measurement.md` for the before/after protocol.

See [examples/before-after.md](examples/before-after.md) for the same task
done naively (~205k tokens, 2 fix attempts) vs. with the skill (~52k tokens,
1 attempt).

## Repository layout

```
SKILL.md                     # entry point — the map
core-rules.md                # the always-on ~20-line rules block
modules/                     # the six layers + enforcement, loaded on demand
hooks/gardener_guard.py      # deterministic PreToolUse/SessionStart guard
hooks/test_guard.sh          # guard self-tests
install.sh / uninstall.sh    # skill link + hook registration (idempotent)
templates/                   # project memory + session checkpoint starters
examples/before-after.md     # fictional worked example (acme-shop)
```

---

## Deutsch (Kurzfassung)

**The Gardener** (`token-saver`) ist ein Agent-Skill, das den Token-Verbrauch
von LLM-Agenten um realistisch 40-80 % senkt — ohne Qualitätsverlust.
Kernidee: Ein volles Kontextfenster verschlechtert die Modellleistung
("Context Rot"); Token-Hygiene ist daher Qualitätssicherung, nicht nur
Kostensenkung.

Seit v1.1.0 ist das Skill **verpflichtend statt optional**: `./install.sh`
registriert deterministische Claude-Code-Hooks — ein `PreToolUse`-Guard
blockiert kontextflutende Tool-Aufrufe (node_modules, Lockfiles, ungefilterte
Dumps) und nennt dabei die günstigere Alternative; ein `SessionStart`-Hook
lädt die Kernregeln automatisch in jede Session. Läuft 24/7 ohne Daemon,
kostet 0 Token bis zum Verstoß. Notausgänge: `GARDENER_DISABLE=1`,
`GARDENER_ALLOW=1`. Deinstallation: `./uninstall.sh`.

Danach pro Projekt eine Gedächtnis-Datei aus
`templates/CLAUDE.md.template` anlegen — der größte Einzelhebel neben
Prompt-Caching. Details in den `modules/` (Englisch).

## License

MIT — see [LICENSE](LICENSE).
