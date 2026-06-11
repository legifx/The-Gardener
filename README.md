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

## Installation

### Claude Code

```bash
git clone https://github.com/<your-account>/The-Gardener.git
mkdir -p ~/.claude/skills
cp -r The-Gardener ~/.claude/skills/token-saver
```

Or per project: copy to `.claude/skills/token-saver/` inside the repo.

### Hermes Agent (or other markdown-skill harnesses)

```bash
cp -r The-Gardener ~/.hermes/skills/token-saver
```

Any harness that reads a `SKILL.md` with YAML frontmatter will pick it up.

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
modules/                     # the six layers, loaded on demand
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

Installation: Repo klonen und nach `~/.claude/skills/token-saver`
(Claude Code) bzw. `~/.hermes/skills/token-saver` (Hermes) kopieren.
Danach pro Projekt eine Gedächtnis-Datei aus
`templates/CLAUDE.md.template` anlegen — der größte Einzelhebel neben
Prompt-Caching. Details in den `modules/` (Englisch).

## License

MIT — see [LICENSE](LICENSE).
