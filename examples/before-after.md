# Before / After: the same task, two ways

Fictional project **acme-shop** — a mid-size e-commerce codebase
(~400 source files, Node/TypeScript, Postgres).

**Task:** "Discounts are applied before tax in the cart total, but the
requirements say after tax. Fix it and add a regression test."

All numbers are illustrative, but the proportions are realistic.

## Before: the naive run (~205,000 input tokens)

| Step | Action | Tokens (approx.) |
|---|---|---|
| 1 | Read `src/cart/` wholesale "to get oriented" (14 files) | 85,000 |
| 2 | Read `package-lock.json` while looking for the tax lib version | 38,000 |
| 3 | Run full test suite, 600 lines of output into context | 9,000 |
| 4 | First fix attempt in the wrong file (`cartView.ts`), fails | 12,000 |
| 5 | Re-read 5 files already read in step 1 | 30,000 |
| 6 | Second attempt in `cartTotals.ts`, works | 11,000 |
| 7 | Reprint both full files in the answer + long explanation | 20,000 output |

Side effects: by step 5 the window is ~80% full; the model starts forgetting
constraints from the requirements (context rot). The wrong-file attempt in
step 4 happened *because* orientation was bulk reading instead of targeted
search. Quality gate: passed, but only on the second attempt.

## After: with token-saver (~52,000 input tokens)

| Step | Action | Tokens (approx.) |
|---|---|---|
| 1 | Read `CLAUDE.md` project memory (state block says: totals live in `cartTotals.ts`, tax via `TaxService`) | 3,500 |
| 2 | `grep -n "discount" src/cart/` → 4 hits | 300 |
| 3 | Read `cartTotals.ts` lines 30-90 only | 1,200 |
| 4 | Plan (3 lines), confirm, then one targeted edit | 2,000 |
| 5 | Run only the cart test file, output `| tail -20` | 800 |
| 6 | Add regression test, re-run, green | 4,000 |
| 7 | Answer with a 10-line diff + one-line summary | 1,500 output |
| — | Stable prefix (system + skill + memory) cache-read on every turn | ~38,000 read at ~10% cost |

Quality gate: passed on the first attempt — the memory file's state block
pointed directly at the right file, so the wrong-file detour never happened.

## The comparison

| | Naive | token-saver | Delta |
|---|---|---|---|
| Input tokens (full price) | ~205,000 | ~14,000 (+38k cache-read) | **-80%+ effective cost** |
| Output tokens | ~20,000 | ~1,500 | -92% |
| Fix attempts | 2 | 1 | quality up, not just cost down |
| Peak context fill | ~80% | ~25% | reasoning headroom preserved |

The headline insight: the biggest single saving (step 1+2+5 in the naive
run, ~150k tokens) came from **not reading what was never needed** — and
that same discipline is what prevented the wrong-file attempt. Token
reduction and quality improvement were the same move.
