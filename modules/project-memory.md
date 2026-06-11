# Project Memory

Everything that would otherwise be re-explained or re-discovered every
session goes into one lean, persistent memory file — paid for once, reused
forever (and prefix-cached, see `modules/caching.md`).

## The file

- Name it `CLAUDE.md` (Claude Code) or `AGENT.md` (other agents), at the
  project root. Start from `templates/CLAUDE.md.template`.
- **Hard budget: ≤ 5,000 tokens** (~600 lines of terse markdown). If it grows
  past that, it has stopped being memory and become documentation — move the
  overflow into linked docs and keep only pointers.

## What belongs in it

| Section | Content |
|---|---|
| Project summary | 3-5 lines: what it is, who uses it, current phase |
| Tech stack | Languages, frameworks, versions — one line each |
| Conventions | Naming, formatting, commit style, test layout |
| Commands | Build, test, lint, run — exact invocations |
| Open TODOs | Active work items, max ~10, pruned regularly |
| Known bugs / gotchas | Things that bite, with the workaround |
| Read allowlist/denylist | Dirs worth reading vs. forbidden paths |
| State block | See below |

## What does NOT belong in it

- **DON'T** paste conversation history or session transcripts.
- **DON'T** duplicate what git already records (past fixes, file history).
- **DON'T** include anything derivable in one cheap command (`ls`, file tree).
- **DON'T** store secrets, keys, or credentials — ever.

## The state block (knowledge-graph-light)

Represent project state as compact entities + relations, not prose:

```
## State
- OrderService -> publishes -> order.created (RabbitMQ)
- checkout-ui  -> calls -> OrderService /api/v2/orders
- legacy /api/v1 -> deprecated, removal blocked by mobile-app v3.2
- payments: Stripe only; PayPal planned Q3
```

Four lines replace a 2,000-token architecture re-explanation. Update
relations when they change; delete entities that no longer exist.

## Self-update rule (end of session)

Before the session ends or compacts, update the memory file:

- **Max 10 lines of delta** per session. Forced brevity keeps the file lean.
- Add: new decisions, new gotchas discovered, changed state relations,
  TODO status changes.
- Remove: completed TODOs, fixed bugs, stale entries — removal is as
  valuable as addition.
- **DON'T** append a session log ("On Tuesday we discussed…"). Memory stores
  *current truth*, not history.

## Payoff test

A memory file is working when a fresh session can start productive work
after reading **only this file** — no exploratory directory walking, no
"let me first understand the project" phase. If the agent still explores
after reading it, the file is missing something: add that, within budget.
