#!/usr/bin/env bash
# The Gardener installer — registers the token-saver skill AND its
# deterministic enforcement layer (Claude Code hooks), so the skill is not
# just available but mandatory: rules load automatically every session, and
# context-flooding tool calls are blocked by the harness itself.
#
# Usage:
#   ./install.sh                     # Claude Code (skill + hooks)
#   ./install.sh --hermes            # Hermes / markdown-skill harness only
#   ./install.sh --all               # both
#   ./install.sh --with-memory-block # also append core rules to ~/.claude/CLAUDE.md
#
# Idempotent: safe to re-run. Backs up every file it modifies.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DO_CLAUDE=1
DO_HERMES=0
WITH_MEMORY_BLOCK=0

for arg in "$@"; do
  case "$arg" in
    --claude) DO_CLAUDE=1; DO_HERMES=0 ;;
    --hermes) DO_CLAUDE=0; DO_HERMES=1 ;;
    --all) DO_CLAUDE=1; DO_HERMES=1 ;;
    --with-memory-block) WITH_MEMORY_BLOCK=1 ;;
    -h|--help) grep '^#' "$0" | head -12; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)"; exit 1 ;;
  esac
done

link_skill() { # $1 = target skills dir
  local skill_dir="$1/token-saver"
  mkdir -p "$1"
  if [ -L "$skill_dir" ]; then
    if [ "$(readlink -f "$skill_dir")" = "$REPO_DIR" ]; then
      echo "  skill link OK: $skill_dir"
      return
    fi
    mv "$skill_dir" "$skill_dir.bak-$STAMP"
  elif [ -e "$skill_dir" ]; then
    mv "$skill_dir" "$skill_dir.bak-$STAMP"
    echo "  existing dir backed up: $skill_dir.bak-$STAMP"
  fi
  ln -s "$REPO_DIR" "$skill_dir"
  echo "  skill linked: $skill_dir -> $REPO_DIR"
}

append_memory_block() { # $1 = memory file (CLAUDE.md / SOUL.md)
  if [ -f "$1" ] && grep -qi "gardener:core-rules\|Token Efficiency" "$1"; then
    echo "  core rules already present in $1 (skipped)"
    return
  fi
  [ -f "$1" ] && cp "$1" "$1.bak-$STAMP"
  { [ -f "$1" ] && [ -s "$1" ] && echo ""; cat "$REPO_DIR/core-rules.md"; } >> "$1"
  echo "  core rules appended to $1"
}

register_hooks() {
  local settings="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  [ -f "$settings" ] && cp "$settings" "$settings.bak-$STAMP"
  python3 - "$settings" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]
guard = '"$HOME/.claude/skills/token-saver/hooks/gardener_guard.py"'
entries = {
    "PreToolUse": {
        "matcher": "Read|Bash",
        "hooks": [{"type": "command",
                   "command": "python3 %s pre-tool-use" % guard,
                   "timeout": 10}],
    },
    "SessionStart": {
        "hooks": [{"type": "command",
                   "command": "python3 %s session-start" % guard,
                   "timeout": 10}],
    },
}
try:
    with open(settings_path, encoding="utf-8") as fh:
        settings = json.load(fh)
except (OSError, ValueError):
    settings = {}
hooks = settings.setdefault("hooks", {})
changed = False
for event, entry in entries.items():
    existing = hooks.setdefault(event, [])
    if any("gardener_guard.py" in h.get("command", "")
           for e in existing for h in e.get("hooks", [])):
        print("  %s hook already registered (skipped)" % event)
        continue
    existing.append(entry)
    changed = True
    print("  %s hook registered" % event)
if changed:
    with open(settings_path, "w", encoding="utf-8") as fh:
        json.dump(settings, fh, indent=2)
        fh.write("\n")
PYEOF
}

if [ "$DO_CLAUDE" = 1 ]; then
  echo "Claude Code:"
  link_skill "$HOME/.claude/skills"
  register_hooks
  [ "$WITH_MEMORY_BLOCK" = 1 ] && append_memory_block "$HOME/.claude/CLAUDE.md"
  echo "  -> restart your Claude Code session for hooks to take effect."
fi

if [ "$DO_HERMES" = 1 ]; then
  echo "Hermes / markdown-skill harness:"
  link_skill "$HOME/.hermes/skills"
  if [ "$WITH_MEMORY_BLOCK" = 1 ]; then
    append_memory_block "$HOME/.hermes/SOUL.md"
  else
    echo "  note: no hook support here - use --with-memory-block so the"
    echo "  core rules are always-on via the agent's memory file."
  fi
fi

echo "Done. Escape hatches: GARDENER_DISABLE=1 (off), GARDENER_STRICT=1 (stricter)."
