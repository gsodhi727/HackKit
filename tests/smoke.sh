#!/usr/bin/env bash
# ============================================================
#  HackKit — smoke tests for the pipeline scripts
#  Runs offline: real tools are replaced by tests/fake-tool.sh.
#  Usage: bash tests/smoke.sh
# ============================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"; mkdir -p "$BIN"
for t in subfinder assetfinder dnsx httpx naabu gau waybackurls katana uro nuclei subzy \
         gowitness dalfox kxss Gxss ffuf feroxbuster arjun; do
  ln -s "$ROOT/tests/fake-tool.sh" "$BIN/$t"
done
chmod +x "$ROOT/tests/fake-tool.sh"
# Fake tools first; keep only system dirs so real tools can't leak in.
export PATH="$BIN:/usr/bin:/bin"
export HOME="$WORK/home" WORDLISTS="$WORK/wl"
mkdir -p "$HOME" "$WORDLISTS/SecLists/Discovery/Web-Content" "$WORDLISTS/SecLists/Discovery/DNS"
echo admin >"$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt"
echo www   >"$WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-20000.txt"

PASS=0; FAIL=0
ok()   { echo "  ok   $*"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }
expect_exit() {  # expect_exit <code> <description> <cmd...>
  local want="$1" desc="$2"; shift 2
  "$@" >"$WORK/out" 2>&1; local got=$?
  if [[ "$got" == "$want" ]]; then ok "$desc"; else bad "$desc (exit $got, wanted $want)"; sed 's/^/       /' "$WORK/out"; fi
}
has_lines() {    # has_lines <file> <n> <description>
  local n; n=$( [[ -f "$1" ]] && wc -l <"$1" | tr -d ' ' || echo missing)
  if [[ "$n" == "$2" ]]; then ok "$3"; else bad "$3 ($1 has $n lines, wanted $2)"; fi
}

R="$ROOT/scripts/recon/recon.sh"; X="$ROOT/scripts/exploitation/xss-hunt.sh"; F="$ROOT/scripts/fuzzing/fuzz.sh"
cd "$WORK" || exit 1

echo "Input validation"
expect_exit 0 "recon -h"                         bash "$R" -h
expect_exit 1 "recon rejects missing -d"         bash "$R"
expect_exit 1 "recon rejects -d without value"   bash "$R" -d
expect_exit 1 "recon rejects injection in -d"    bash "$R" -d 'example.com;id'
expect_exit 1 "recon rejects bad thread count"   bash "$R" -d example.com -t abc
expect_exit 1 "xss rejects bad domain"           bash "$X" -d '../../etc'
expect_exit 1 "fuzz rejects non-http URL"        bash "$F" -u 'file:///etc/passwd'
expect_exit 1 "fuzz rejects unknown mode"        bash "$F" -u https://example.com -m nope

echo "Recon pipeline (fake tools)"
expect_exit 0 "recon runs end to end" bash "$R" -d Example.com -o "$WORK/r"
has_lines "$WORK/r/subs/all.txt"        4 "subdomains merged, out-of-scope host dropped"
has_lines "$WORK/r/alive/alive.txt"     2 "alive.txt holds bare URLs"
has_lines "$WORK/r/urls/all_urls.txt"   4 "URL sources merged"
has_lines "$WORK/r/nuclei/results.txt"  1 "nuclei got clean input"
grep -q "naabu failed" "$WORK/out" && ok "tool failure is reported, not hidden" || bad "naabu failure not reported"

echo "XSS pipeline (fake tools)"
expect_exit 0 "xss runs end to end" bash "$X" -d example.com -o "$WORK/x"
has_lines "$WORK/x/params.txt"         2 "only URLs with parameters kept"
has_lines "$WORK/x/dalfox_results.txt" 1 "dalfox output written"
rm "$BIN/gau" "$BIN/waybackurls"; ln -s /bin/true "$BIN/gau"
expect_exit 0 "xss exits cleanly when no parameters are found" bash "$X" -d example.com -o "$WORK/x2"

echo "Fuzz pipeline (fake tools)"
expect_exit 0 "fuzz dir mode"   bash "$F" -u https://example.com/ -o "$WORK/f"
expect_exit 0 "fuzz vhost mode" bash "$F" -u https://example.com -m vhost -o "$WORK/f"
expect_exit 0 "fuzz param mode" bash "$F" -u https://example.com -m param -o "$WORK/f"

echo ""
echo "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
