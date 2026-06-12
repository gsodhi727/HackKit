#!/usr/bin/env bash
# ============================================================
#  HackKit — XSS Hunter Pipeline
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash xss-hunt.sh -d target.com
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; BOLD='\033[1m'; GREEN='\033[0;32m'; RESET='\033[0m'

DOMAIN=""; OUT_DIR=""; BLIND_XSS_URL=""

usage() {
  echo -e "${CYAN}${BOLD}HackKit — XSS Hunter${RESET}"
  echo "  Usage: $0 -d <domain> [-o output_dir] [-b blind_xss_url]"
  echo "  Options:"
  echo "    -d   Domain to test (required)"
  echo "    -o   Output directory (default: ./xss-<domain>)"
  echo "    -b   Blind XSS callback URL (e.g., https://yoursite.xss.ht)"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -d) DOMAIN="$2";        shift 2 ;;
    -o) OUT_DIR="$2";       shift 2 ;;
    -b) BLIND_XSS_URL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done
[[ -z "$DOMAIN" ]] && { echo "Error: -d required"; usage; }

OUT_DIR="${OUT_DIR:-./xss-${DOMAIN}}"
mkdir -p "$OUT_DIR"

step() { echo -e "\n${CYAN}${BOLD}▸ $*${RESET}"; }

step "Collecting URLs with parameters"
echo "$DOMAIN" | gau --subs | grep "=" | uro > "$OUT_DIR/params.txt"
echo "$DOMAIN" | waybackurls | grep "=" | anew "$OUT_DIR/params.txt" > /dev/null
echo "  → $(wc -l < "$OUT_DIR/params.txt") parameterized URLs"

step "Checking reflected parameters (kxss)"
cat "$OUT_DIR/params.txt" | kxss 2>/dev/null > "$OUT_DIR/reflected.txt" || true

step "DalFox XSS scan"
dalfox file "$OUT_DIR/params.txt" \
  --silence \
  ${BLIND_XSS_URL:+--blind "$BLIND_XSS_URL"} \
  -o "$OUT_DIR/dalfox_results.txt" 2>/dev/null || true

step "Gxss parameter reflection check"
cat "$OUT_DIR/params.txt" | Gxss -c 100 -p Xss > "$OUT_DIR/gxss.txt" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}XSS Hunt complete for $DOMAIN${RESET}"
echo "  Results → $OUT_DIR/"
