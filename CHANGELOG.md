# Changelog

## 1.1.0 — 2026-07-02

### Added
- **Enforcement layer** (`modules/enforcement.md`): the skill is now
  mandatory, not advisory — deterministic Claude Code hooks run 24/7.
  - `hooks/gardener_guard.py` — `PreToolUse` guard blocks context-flooding
    tool calls (forbidden paths, lockfiles, unscoped reads > 256 KB,
    unfiltered dumps); `SessionStart` injects the core rules with
    automatic deduplication against existing CLAUDE.md blocks.
    Fails open, educates on every deny, stdlib-only (Python 3.8+).
  - Escape hatches: `GARDENER_DISABLE=1`, `GARDENER_STRICT=1`,
    one-shot `GARDENER_ALLOW=1` Bash override.
- `core-rules.md` — single source of truth for the always-on rules block
  (marker-delimited for clean install/uninstall).
- `install.sh` — one-command install: skill symlink + hook registration
  (idempotent, backs up `settings.json` and memory files);
  `--hermes`/`--all` targets, `--with-memory-block` option.
- `uninstall.sh` — clean removal of hooks, links, and injected blocks.
- `hooks/test_guard.sh` — self-test suite for the guard.

### Fixed
- README install instructions: `cp -r` copied the `.git` directory into
  the skills folder and silently nested the repo when re-run; replaced
  with `install.sh` (symlink, idempotent).
- README clone URL placeholder (`<your-account>`) replaced with the real
  repository URL.

## 1.0.0 — 2026-06-11

- Initial release: six-layer token-saver skill (context hygiene, project
  memory, delegation, caching, output discipline & model routing,
  measurement & quality gate), templates, worked example.
