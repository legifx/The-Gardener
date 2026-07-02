---
name: token-saver
description: >
  Reduces LLM agent token consumption by 40-80% without sacrificing output
  quality. Use when starting a large or multi-step task, when the session is
  getting long, when a context warning appears, when the user asks about cost
  or token usage, or when output quality degrades mid-session (context rot).
  Covers context hygiene, project memory, delegation, caching, output
  discipline, and measurement.
---

# token-saver

Token reduction as a **quality practice**, not just a cost practice.

## Core principle (non-negotiable)

LLM performance degrades as the context window fills ("context rot").
Every measure in this skill must pass one test:

> It reduces tokens **AND** preserves or improves answer quality.

Measures that trade quality for tokens are forbidden. Never:
- Skip reading a file you actually need to change correctly.
- Truncate requirements or acceptance criteria.
- Summarize away error messages you have not yet resolved.

Saving tokens by producing a worse answer is a net loss — the rework costs
more than the savings.

## How to use this skill

This skill follows progressive disclosure: this file is the map, the modules
are the territory. **Load only the module you need, when you need it.**

| Situation | Load |
|---|---|
| Starting any session / about to read files | [modules/context-hygiene.md](modules/context-hygiene.md) |
| Re-explaining the project every session | [modules/project-memory.md](modules/project-memory.md) |
| Research, broad search, or analysis task ahead | [modules/delegation.md](modules/delegation.md) |
| Structuring prompts, system text, or API calls | [modules/caching.md](modules/caching.md) |
| Writing responses, picking a model | [modules/output-discipline.md](modules/output-discipline.md) |
| Proving the savings / pre-delivery check | [modules/measurement.md](modules/measurement.md) |
| Making the rules mandatory (hooks, 24/7) / a guard blocked a call | [modules/enforcement.md](modules/enforcement.md) |

## Decision tree

```
New session on a known project?
├─ Project memory file exists? → read it INSTEAD of re-exploring (project-memory)
└─ No memory file? → create one from the template (templates/CLAUDE.md.template)

About to gather information?
├─ Need an overview? → grep/glob/outline first, never bulk-read (context-hygiene)
├─ Broad or multi-file research? → delegate to a subagent (delegation)
└─ Already read it this session? → reference the earlier result (caching)

About to respond or generate?
├─ Changing code? → emit diffs, not whole files (output-discipline)
├─ Mechanical task? → route to a cheaper model (output-discipline)
└─ Task milestone done? → checkpoint: commit + compact (context-hygiene)

Before delivering?
└─ Run the quality gate checklist (measurement) — savings only count if it passes.
```

## The six layers at a glance

1. **Context hygiene** — read surgically, cap tool output, checkpoint and
   compact at natural boundaries, clear context between unrelated tasks.
2. **Project memory** — a lean persistent memory file (≤ 5,000 tokens) holds
   everything that would otherwise be re-explained every session.
3. **Delegation** — subagents do the searching in their own context and
   return a fixed-format summary; the main context stays clean.
4. **Caching** — stable content leads the prompt (prefix caching); never
   re-load a deterministic tool result you already have.
5. **Output discipline & model routing** — terse, structured output; expensive
   models plan, cheap models execute, with an escalation rule as safety net.
6. **Measurement & quality gate** — measure before/after per task; a saving
   only counts if the quality gate passes.

Plus **layer 0, enforcement**: `install.sh` registers deterministic hooks
(Claude Code) that inject the core rules every session and hard-block
context-flooding tool calls — the layers above become mandatory, not
advisory. If a "token-saver guard" message blocked one of your tool calls,
follow the cheaper move it names; see
[modules/enforcement.md](modules/enforcement.md) for overrides.

## Biggest levers first

If you apply only two things: **prefix caching** (layer 4) and **context
hygiene** (layer 1). Together they typically account for most of the
realistic 40-80% reduction. Layers 2-3 compound the effect on long-running
projects; layers 5-6 keep it honest.

## Templates

- [templates/CLAUDE.md.template](templates/CLAUDE.md.template) — project memory starter
- [templates/session-checkpoint.md](templates/session-checkpoint.md) — checkpoint format

## Example

See [examples/before-after.md](examples/before-after.md) for a fictional
project ("acme-shop") showing the same task done naively vs. with this skill.
