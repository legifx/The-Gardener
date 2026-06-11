# Caching

The cheapest token is one the provider has already processed. Prompt prefix
caching typically cuts input cost by ~90% on cache hits and is the single
biggest lever in agent workloads, where the same system prompt, skill text,
and project context are resent on every turn.

## Rule 1: Stable content first, variable content last

Prefix caches match from the **start** of the prompt. One changed byte
invalidates everything after it.

Order your prompt/context like this:

```
1. System prompt            (never changes)        ─┐
2. Skill / policy text      (changes per release)   ├─ cacheable prefix
3. Project memory file      (changes per session)  ─┘
4. Conversation history     (grows per turn)       ── appended, cache-friendly
5. Current task + fresh data (changes per turn)    ── always last
```

- **DO** keep timestamps, request IDs, random seeds, and "today's date" out
  of the early prompt sections — a timestamp in the system prompt destroys
  the cache every single call.
- **DO** append to conversation history; never rewrite or reorder earlier
  turns mid-session.
- **DON'T** inject volatile data (current metrics, search results) above
  stable instructions.

## Rule 2: cache_control breakpoints (direct Anthropic API use)

When calling the API directly, mark the end of each stable section:

```json
{"type": "text", "text": "<system prompt>",
 "cache_control": {"type": "ephemeral"}}
```

- Place breakpoints at section boundaries: after system prompt, after tool
  definitions, after project context. (Check current API docs for the
  breakpoint limit per request.)
- Cache TTL is short (minutes). Agents in an active loop hit it naturally;
  batch jobs with long gaps between calls may not — measure, don't assume.
- Agent harnesses like Claude Code handle this automatically — your job
  there is only Rule 1: don't break the prefix.

## Rule 3: Tool-result cache (within a session)

Deterministic tool calls with identical inputs return identical outputs.
Re-running them re-buys the same tokens.

- **DO** before any file read or search: check whether the same read/search
  already happened this session. Reference the earlier result ("as read
  above, `config.ts` sets retries to 3") instead of re-loading it.
- **DO** re-read only what changed: after editing lines 40-60, do not
  re-read the whole file to "verify" — the edit result already confirmed it.
- **DON'T** re-read a file after every small edit as a ritual.
- **Exception:** re-read when the file may have changed outside your edits
  (another process, another agent, user edits). Correctness beats caching.

## Rule 4: Semantic caching (documented, not implemented here)

Gateway-level semantic caches return stored answers for *similar* (not
identical) queries. Useful for repetitive, **stateless** queries (FAQ-style
lookups, classification of similar inputs).

**Limits — read before adopting:** agent tasks are state-dependent. "Fix the
failing test" has a different correct answer every time even though the
words match. Semantic caching applied to stateful agent work returns
confidently stale answers — a quality failure, not a saving. Restrict it to
queries whose answer depends only on the query text.
