#!/usr/bin/env bash
# The Gardener uninstaller — removes hooks, skill links, and injected
# core-rules blocks. Backs up every file it modifies.
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

remove_link() { # $1 = skills dir
  local skill_dir="$1/token-saver"
  if [ -L "$skill_dir" ] && [ "$(readlink -f "$skill_dir")" = "$REPO_DIR" ]; then
    rm "$skill_dir"
    echo "  removed skill link: $skill_dir"
  fi
}

remove_block() { # $1 = memory file
  [ -f "$1" ] || return 0
  if grep -q "gardener:core-rules" "$1"; then
    cp "$1" "$1.bak-$STAMP"
    sed -i '/<!-- gardener:core-rules/,/<!-- \/gardener:core-rules -->/d' "$1"
    echo "  removed core-rules block from $1 (backup: $1.bak-$STAMP)"
  fi
}

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && grep -q "gardener_guard.py" "$SETTINGS"; then
  cp "$SETTINGS" "$SETTINGS.bak-$STAMP"
  python3 - "$SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    settings = json.load(fh)
hooks = settings.get("hooks", {})
for event in list(hooks):
    hooks[event] = [
        e for e in hooks[event]
        if not any("gardener_guard.py" in h.get("command", "")
                   for h in e.get("hooks", []))
    ]
    if not hooks[event]:
        del hooks[event]
if not hooks:
    settings.pop("hooks", None)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, indent=2)
    fh.write("\n")
print("  hooks removed from " + path)
PYEOF
fi

remove_link "$HOME/.claude/skills"
remove_link "$HOME/.hermes/skills"
remove_block "$HOME/.claude/CLAUDE.md"
remove_block "$HOME/.hermes/SOUL.md"

echo "Done. Manually written 'Token Efficiency' sections (without the"
echo "gardener:core-rules marker) are left untouched."
