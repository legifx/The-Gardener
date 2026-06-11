# Measurement & Quality Gate

Unmeasured optimization is folklore. Measure per task, compare before/after,
and let savings count **only** when the quality gate passes.

## Measuring token usage

Pick whatever your harness offers; all of these work:

- **ccusage** (community CLI for Claude Code): per-session and per-day token
  and cost breakdowns from local logs — good for before/after comparisons.
- **`/context`** (in Claude Code): live snapshot of what occupies the
  context window — system prompt, tools, skills, messages. Use it to find
  what is eating the window *right now*.
- **Status line**: configure it to show current context usage so degradation
  is visible before the warning fires, not after.
- **API usage dashboards / response `usage` fields**: when calling the API
  directly, log `input_tokens`, `output_tokens`,
  `cache_read_input_tokens` per call. Cache-read share is your prefix-cache
  hit rate — if it is low, revisit `modules/caching.md` Rule 1.

## Before/after protocol

For a representative recurring task (e.g. "fix a failing test", "add an
endpoint"):

1. Run it the usual way. Record: total tokens, cost, wall time, and whether
   the quality gate (below) passed.
2. Apply this skill's layers. Run a comparable task. Record the same.
3. Compare honestly — same task class, similar difficulty.

```
| Task            | Tokens  | Cache-read % | Gate passed |
|-----------------|---------|--------------|-------------|
| add endpoint v1 | 210,000 | 12%          | yes         |
| add endpoint v2 |  74,000 | 61%          | yes         |
```

- **DON'T** compare a hard task against an easy one and credit the skill.
- **DON'T** report savings from a run where the gate failed — that run
  produced rework, not savings.

## The quality gate

Run this checklist **before delivering any result**. Every "no" blocks
delivery — fix it first, even if fixing costs tokens.

```
QUALITY GATE
[ ] Tests pass (run them — do not assume; paste the failing output if not)
[ ] Every stated requirement is implemented — list each one and check it off
[ ] Nothing was optimized away: no skipped file that the change depended on,
    no truncated requirement, no summarized-away error message
[ ] Edge cases the requirements imply are handled (empty input, errors, auth)
[ ] The diff contains only intended changes (no accidental deletions,
    no drive-by reformatting)
[ ] If anything was skipped or is uncertain, it is stated explicitly
    in the final answer — not hidden
```

## The honest accounting rule

A token saving is real only if:

> tokens(optimized run) < tokens(naive run), **and** the quality gate
> passed in the optimized run.

If the gate failed, count the rework tokens against the "saving". This rule
is what keeps every other module in this skill honest — context hygiene,
delegation, and model routing are all judged by it.
