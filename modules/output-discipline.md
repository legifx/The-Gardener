# Output Discipline & Model Routing

Output tokens cost ~5× input tokens and — worse — everything you generate
re-enters the context as history. Verbose output is a tax you pay twice.

## Output rules

- **DO** default to terse. Answer the question, then stop.
- **DO** use structured formats: tables for comparisons, JSON for data,
  bullet lists for findings. Structure carries more information per token
  than prose.
- **DON'T** add unrequested explanation paragraphs, summaries of what you
  just did, or "Key takeaways" sections after every action.
- **DON'T** narrate intentions ("Now I will open the file to look at…") —
  just do it.

## Diffs, not whole files

- **DO** emit only the changed hunk with minimal surrounding context:

```diff
--- a/src/cart.ts
@@ -42,7 +42,7 @@
-  const total = items.reduce((s, i) => s + i.price, 0);
+  const total = items.reduce((s, i) => s + i.price * i.qty, 0);
```

- **DON'T** reprint a 400-line file to change one line.
- **DON'T** quote back code that is already in context ("Here is your
  function again for reference: …"). Reference it by `file:line` instead.

## Model routing

Match model capability to task difficulty. A frontier model formatting JSON
wastes money; a small model designing architecture wastes quality (and then
money on the rework).

| Tier | Use for | Examples |
|---|---|---|
| Expensive / frontier | Planning, architecture, hard debugging, security-sensitive code, ambiguous requirements | system design, root-cause analysis, API design |
| Mid-tier | Mechanical execution of a confirmed plan, routine implementation, test writing from clear specs | "implement step 3 of the plan", boilerplate, refactors with clear rules |
| Smallest | Trivial classification, formatting, extraction, yes/no checks | label commit messages, reformat JSON, extract URLs |

Configuration pattern (hybrid approach):

```
plan/architecture  -> frontier model
execute/implement  -> mid-tier model
classify/format    -> small model
```

## Escalation rule (quality safety net)

Routing down must never silently degrade results:

> **After two failed attempts on the same task with a smaller model,
> escalate to the next tier automatically.** Do not retry a third time.

Failed attempts pollute context and compound (each retry sees the previous
failures). Two strikes → escalate, and consider clearing the failed
attempts from context before the stronger model starts.

- **DON'T** loop a small model five times to "save money" — five failures
  cost more than one frontier call and leave a worse context behind.
- **DO** route back down once the hard part is solved and execution becomes
  mechanical again.
