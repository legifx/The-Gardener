#!/usr/bin/env python3
"""The Gardener - deterministic enforcement hooks for token discipline.

Two hook events, one script (stdlib only, Python 3.8+):

  gardener_guard.py pre-tool-use   PreToolUse hook: blocks context-flooding
                                   tool calls (forbidden paths, lockfiles,
                                   unscoped reads of huge files, unfiltered
                                   dumps). Exit 2 + stderr = deny; the
                                   message tells the agent the cheaper move.
  gardener_guard.py session-start  SessionStart hook: injects the core rules
                                   (core-rules.md) into context - unless a
                                   CLAUDE.md already carries them (no
                                   double-paying for the same rules).

Design principles:
  - Fail open: any internal error exits 0. The guard must never break the
    harness or block work it cannot judge.
  - Educate on deny: every block message names the cheaper alternative and
    the explicit override, so a legitimate need is one retry away.
  - Deterministic beats prompted: rules in a prompt can be forgotten under
    context pressure; a hook cannot.

Escape hatches:
  - GARDENER_DISABLE=1 in the environment disables all checks.
  - GARDENER_STRICT=1 additionally blocks unbounded-output commands
    (bare `git log`, unfiltered test runs).
  - A Bash command containing the literal token GARDENER_ALLOW is always
    allowed - a visible, deliberate override for user-requested exceptions.
"""
import json
import os
import re
import sys

FORBIDDEN_DIRS = (
    "node_modules", "vendor", ".venv", "venv", "__pycache__",
    "dist", "build", "target", ".next", ".nuxt", ".git",
)
LOCKFILES = (
    "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock",
    "bun.lockb", "cargo.lock", "poetry.lock", "uv.lock", "pipfile.lock",
    "gemfile.lock", "composer.lock", "gradle.lockfile",
)
ARTIFACT_SUFFIXES = (
    ".min.js", ".min.css", ".map", ".pyc", ".class", ".wasm",
    ".jar", ".zip", ".tar", ".gz", ".tgz", ".7z", ".rar",
)
# Files the Read tool handles natively (rendered, paginated, or cell-wise) -
# size-capping them would block legitimate use.
NATIVE_READ_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg",
    ".pdf", ".ipynb",
)
MAX_UNSCOPED_READ_BYTES = 256 * 1024  # beyond this, demand offset/limit


def deny(message):
    sys.stderr.write("token-saver guard (The Gardener): " + message + "\n")
    sys.exit(2)


def classify_path(path):
    """Return a human-readable reason if the path is forbidden, else None."""
    parts = [p.lower() for p in path.replace("\\", "/").split("/") if p]
    if not parts:
        return None
    base = parts[-1]
    for d in FORBIDDEN_DIRS:
        if d in parts[:-1]:
            return "'%s/' is on the forbidden-path list" % d
    if base in LOCKFILES:
        return "'%s' is a lockfile" % base
    if base.endswith(ARTIFACT_SUFFIXES):
        return "'%s' is a build artifact or binary" % base
    return None


def check_read(tool_input):
    path = tool_input.get("file_path") or ""
    reason = classify_path(path)
    if reason:
        deny(
            "BLOCKED Read of '%s' - %s. Reading it floods the context "
            "window for near-zero information. Extract the fact you need "
            "with a targeted command instead, e.g. "
            "grep '\"<package>\"' <file>, or git commands for .git/. "
            "If the user explicitly asked for this exact content, use "
            "Bash with GARDENER_ALLOW=1." % (path, reason)
        )
    if "offset" in tool_input or "limit" in tool_input or "pages" in tool_input:
        return
    if path.lower().endswith(NATIVE_READ_SUFFIXES):
        return
    try:
        size = os.path.getsize(path)
    except OSError:
        return
    if size > MAX_UNSCOPED_READ_BYTES:
        deny(
            "BLOCKED unscoped Read of '%s' (%d KB). Locate the target "
            "first (grep -n), then re-read only that range with "
            "offset/limit. If you genuinely need the whole file, re-read "
            "with an explicit limit parameter." % (path, size // 1024)
        )


CAT_DUMP = re.compile(r"\b(cat|more|less)\b")
STRICT_CHECKS = (
    (
        re.compile(r"\bgit(\s+-C\s+\S+)?\s+log\b"),
        re.compile(r"(-n\s*\d|--max-count|\s-\d|--oneline|\|\s*(head|tail))"),
        "unbounded `git log` - add a limit (-n 10 / --oneline) or pipe "
        "through head.",
    ),
    (
        re.compile(r"\b(npm test|npx jest|pytest|go test|cargo test)\b"),
        re.compile(r"(\||>|--quiet|\s-q\b)"),
        "unfiltered test run - pipe through `tail -30` or redirect to a "
        "log file and read only the failures.",
    ),
)


def check_bash(tool_input):
    cmd = tool_input.get("command") or ""
    if "GARDENER_ALLOW" in cmd:
        return
    # Full dump of a lockfile / forbidden dir / minified artifact,
    # with no filter in the pipeline.
    if CAT_DUMP.search(cmd) and "|" not in cmd:
        lowered = cmd.lower()
        for name in LOCKFILES:
            if name in lowered:
                deny(
                    "BLOCKED unfiltered dump of lockfile '%s'. Extract the "
                    "fact instead: grep '\"<package>\"' %s. Override for an "
                    "explicit user request: prefix the command with "
                    "GARDENER_ALLOW=1." % (name, name)
                )
        if re.search(r"\bnode_modules/", cmd):
            deny(
                "BLOCKED unfiltered dump from node_modules/. Extract facts "
                "with grep or read the package's own docs. Override: "
                "GARDENER_ALLOW=1."
            )
        if re.search(r"\S+\.min\.(js|css)\b", cmd):
            deny(
                "BLOCKED dump of a minified bundle - it is unreadable "
                "context poison. Find the source file instead. Override: "
                "GARDENER_ALLOW=1."
            )
    if os.environ.get("GARDENER_STRICT") == "1":
        for trigger, exempt, message in STRICT_CHECKS:
            if trigger.search(cmd) and not exempt.search(cmd):
                deny("BLOCKED (strict mode) " + message +
                     " Override: GARDENER_ALLOW=1.")


CORE_RULES_MARKERS = ("gardener:core-rules", "Token Efficiency")


def session_start():
    """Print core rules into context unless a CLAUDE.md already has them."""
    candidates = (
        os.path.join(os.path.expanduser("~"), ".claude", "CLAUDE.md"),
        os.path.join(os.getcwd(), "CLAUDE.md"),
    )
    for path in candidates:
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        lowered = text.lower()
        if any(marker.lower() in lowered for marker in CORE_RULES_MARKERS):
            return  # rules are already always-on via memory file
    rules_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "core-rules.md"
    )
    try:
        with open(rules_path, encoding="utf-8") as fh:
            sys.stdout.write(fh.read())
    except OSError:
        pass


def main():
    if os.environ.get("GARDENER_DISABLE") == "1":
        return
    event = sys.argv[1] if len(sys.argv) > 1 else ""
    if event == "session-start":
        session_start()
        return
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return  # fail open on malformed input
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}
    if tool == "Read":
        check_read(tool_input)
    elif tool == "Bash":
        check_bash(tool_input)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        sys.exit(0)  # fail open, always
