# Delegation & Subagents

Search, research, and analysis are context-hungry: they touch many files
but only a small conclusion matters. Run them in a **subagent's** context
and let only the conclusion enter the main context.

## When to delegate

- **DO** delegate broad searches ("find all places that touch the session
  cookie"), codebase exploration, library/API research, log analysis.
- **DO** delegate anything where you expect to open more than ~5 files but
  need only a summary or a list of locations.
- **DON'T** delegate the implementation itself — the main context should
  hold the code being changed.
- **DON'T** delegate trivial lookups a single grep answers; spawning an
  agent costs more than the grep.

## Fixed return format

A subagent that dumps its whole journey into the parent defeats the purpose.
Require a fixed-format, bounded summary — **max 30 lines**:

```
FINDINGS (max 10 bullets, one line each)
LOCATIONS (file:line, max 10)
RECOMMENDATION (max 3 lines)
OPEN QUESTIONS (max 3 bullets, only if blocking)
```

State this format in the subagent prompt. If the answer cannot fit 30 lines,
the question was too broad — split it.

## Multi-agent cost warning

Parallel agents multiply cost: each carries its own system prompt, skill
text, and exploration overhead. Real-world multi-agent runs cost **4-15×**
a single-agent run.

- **DO** parallelize only genuinely independent subtasks (e.g. "research
  library A" + "research library B" + "audit test coverage").
- **DON'T** parallelize coupled work. Two agents editing related code
  produce conflicts whose resolution costs more than the time saved.
- **DON'T** spawn agents to "look busy" on a task one agent handles fine —
  default to a single agent; parallelism is the exception.

## Plan mode first

Planning is cheap (read-only, terse output). Execution is expensive
(generation, iteration, rework). Spend tokens where they are cheap:

1. **Plan** in plan/read-only mode: explore minimally, produce a concrete
   step list with files to touch.
2. **Confirm** the plan with the user (or against the requirements).
3. **Execute** the confirmed plan in one focused pass.

One precise generation beats three iterative repair loops — both in tokens
and in quality, because repair loops accumulate failed attempts in context
(context rot feeding itself).

- **DON'T** start editing "to see what happens" on a multi-file change.
- **DO** treat two consecutive failed fix attempts as a signal to stop,
  re-plan, and possibly clear the failed attempts from context.
