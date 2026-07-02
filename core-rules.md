<!-- gardener:core-rules v1 -->
## Token Efficiency (always on)

Core rules from the `token-saver` skill — apply in every session; load the
skill itself for details on large tasks, long sessions, or cost questions:

- Locate first, read second: grep/glob for the target, then read only the
  relevant line range — never bulk-read directories or whole large files
- Never read: node_modules/, dist/, build/, lockfiles, binaries, .git
  internals — extract facts with targeted commands instead
- Cap tool output: pipe long commands through `head`/`tail`/filters;
  redirect huge logs to a file and read slices
- Don't re-read files or re-run identical searches already done this
  session — reference the earlier result
- Output discipline: diffs instead of whole files, tables/lists instead of
  prose, no unrequested explanation paragraphs, never quote back code
  already in context
- At milestones: commit + checkpoint + compact the session; clear context
  between unrelated tasks
- Quality gate: a token saving only counts if tests pass and no requirement
  was optimized away
<!-- /gardener:core-rules -->
