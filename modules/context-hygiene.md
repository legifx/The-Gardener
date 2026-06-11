# Context Hygiene

Every token that enters the context window stays there until compaction.
Treat context as a scarce, quality-critical resource: a fuller window means
worse reasoning, not just higher cost.

## Rule 1: Read surgically, never bulk

- **DO** locate first, read second: `grep -n "functionName" src/` →
  then read only the matching line range.
- **DO** use file outlines (headings, function signatures) to decide
  whether a full read is needed at all.
- **DON'T** read a whole file "to get oriented" when you need one function.
- **DON'T** read entire directories or glob-read `src/**/*` into context.

```
DON'T: read src/checkout/payment.ts          (1,800 lines → ~20k tokens)
DO:    grep -n "applyDiscount" src/checkout/ (3 lines)
       read payment.ts lines 410-460         (~600 tokens)
```

## Rule 2: Cap tool output

Long command output is context poison — most of it is never used.

- **DO** pipe through `| head -50`, `| tail -50`, or a filter (`grep`, `jq`).
- **DO** redirect huge outputs to a file and read only the relevant slice:
  `npm test 2>&1 | tail -30` or `build.log` + grep for `error`.
- **DO** prefer counting/summarizing flags: `wc -l`, `--stat`, `--summary`.
- **DON'T** run `cat large-file.json`, bare `npm test`, or `git log` without
  limits and let hundreds of lines flood the context.

## Rule 3: Forbidden paths

Never read these into context unless the user explicitly asks:

- `node_modules/`, `vendor/`, `.venv/`, `target/`, `dist/`, `build/`, `out/`
- Lockfiles: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`,
  `poetry.lock`, `Gemfile.lock`
- Binary/media files: images, fonts, archives, compiled artifacts, minified
  bundles (`*.min.js`, `*.map`)
- `.git/` internals (use `git` commands instead)
- Generated code marked as such, large fixtures, datasets

If you need a fact *about* such a file (e.g. "which version of X is
installed?"), extract it with a targeted command (`grep '"react"' package.json`),
do not read the file.

## Rule 4: Checkpoint discipline

Compact at natural boundaries, not when the context warning forces you.

- **DO** after each completed milestone: commit (or have the user commit),
  write a checkpoint note (see `templates/session-checkpoint.md`), then
  compact or restart the session.
- **DO** treat "tests green + committed" as the ideal compaction point: all
  needed state is now in git and the checkpoint file, not in the transcript.
- **DON'T** push on at 90% context capacity — quality is already degrading
  and compaction under pressure loses nuance.

## Rule 5: Clear between unrelated tasks

- **DO** clear/reset context when switching to an unrelated task. The old
  task's files and errors are dead weight that actively distracts the model.
- **DON'T** carry a debugging session's stack traces into a documentation
  task "just in case".

## Quick self-check before any read

1. Do I know what I'm looking for? → grep for it instead.
2. Have I already read this file this session? → reference it, don't re-read.
3. Is it on the forbidden list? → extract the fact with a command.
4. Do I need the whole file? → read the line range only.
