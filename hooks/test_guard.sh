#!/usr/bin/env bash
# Self-test for gardener_guard.py. Run: bash hooks/test_guard.sh
set -u
GUARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gardener_guard.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

check() { # $1=name $2=expected_exit $3=json (env via CHECK_ENV)
  local out; local code
  out=$(echo "$3" | env ${CHECK_ENV:-} python3 "$GUARD" pre-tool-use 2>&1); code=$?
  if [ "$code" = "$2" ]; then
    PASS=$((PASS+1)); echo "PASS: $1"
  else
    FAIL=$((FAIL+1)); echo "FAIL: $1 (expected exit $2, got $code) $out"
  fi
}

read_json() { printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1"; }
bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

# --- Read guards ---
check "deny node_modules read"   2 "$(read_json /proj/node_modules/react/index.js)"
check "deny lockfile read"       2 "$(read_json /proj/package-lock.json)"
check "deny minified read"       2 "$(read_json /proj/dist-src/app.min.js)"
check "deny .git internals"      2 "$(read_json /proj/.git/HEAD)"
check "allow .github read"       0 "$(read_json /proj/.github/workflows/ci.yml)"
check "allow normal source read" 0 "$(read_json /proj/src/index.ts)"

# --- size cap ---
head -c 300000 /dev/zero | tr '\0' 'x' > "$TMP/big.txt"
check "deny unscoped big read"   2 "$(read_json "$TMP/big.txt")"
check "allow ranged big read"    0 "$(printf '{"tool_name":"Read","tool_input":{"file_path":"%s","limit":100}}' "$TMP/big.txt")"

# --- Bash guards ---
check "deny cat lockfile"        2 "$(bash_json 'cat package-lock.json')"
check "allow cat lockfile|grep"  0 "$(bash_json 'cat package-lock.json | grep react')"
check "deny cat node_modules"    2 "$(bash_json 'cat node_modules/react/package.json')"
check "allow GARDENER_ALLOW"     0 "$(bash_json 'GARDENER_ALLOW=1 cat package-lock.json')"
check "allow normal command"     0 "$(bash_json 'ls -la src/')"

# --- strict mode ---
CHECK_ENV="GARDENER_STRICT=1" check "strict: deny bare git log"    2 "$(bash_json 'git log')"
CHECK_ENV="GARDENER_STRICT=1" check "strict: allow git log -n 5"   0 "$(bash_json 'git log -n 5')"
CHECK_ENV="GARDENER_STRICT=1" check "strict: deny bare npm test"   2 "$(bash_json 'npm test')"
CHECK_ENV="GARDENER_STRICT=1" check "strict: allow npm test|tail"  0 "$(bash_json 'npm test 2>&1 | tail -30')"
CHECK_ENV="" check "non-strict: allow bare git log" 0 "$(bash_json 'git log')"

# --- kill switch & fail-open ---
CHECK_ENV="GARDENER_DISABLE=1" check "disable: allow anything" 0 "$(read_json /proj/node_modules/x.js)"
check "fail open on garbage input" 0 'this is not json'

# --- session-start dedup ---
mkdir -p "$TMP/home-marked/.claude" "$TMP/home-clean/.claude"
printf '# x\n<!-- gardener:core-rules v1 -->\n' > "$TMP/home-marked/.claude/CLAUDE.md"
out=$(HOME="$TMP/home-marked" python3 "$GUARD" session-start)
if [ -z "$out" ]; then PASS=$((PASS+1)); echo "PASS: session-start dedup (marker present -> silent)"
else FAIL=$((FAIL+1)); echo "FAIL: session-start dedup printed rules despite marker"; fi
out=$(cd "$TMP" && HOME="$TMP/home-clean" python3 "$GUARD" session-start)
if echo "$out" | grep -q "Token Efficiency"; then PASS=$((PASS+1)); echo "PASS: session-start injects rules when absent"
else FAIL=$((FAIL+1)); echo "FAIL: session-start did not inject rules"; fi

echo "----------------------------------------"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
