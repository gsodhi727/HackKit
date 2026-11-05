#!/usr/bin/env bash
# ============================================================
#  HackKit — Fuzzing Pipeline
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash fuzz.sh -u https://target.com [-m dir|vhost|param]
#  Only run this against targets you are authorised to test.
# ============================================================
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

URL=""; MODE="dir"; OUT_DIR=""; THREADS=40; WORDLIST=""

usage() {
  echo -e "${CYAN}${BOLD}HackKit — Fuzzer${RESET}"
  echo "  Usage: $0 -u <url> [-m dir|vhost|param] [-w wordlist] [-o output] [-t threads]"
  echo ""
  echo "    -u  Target URL, e.g. https://target.com (required)"
  echo "    -m  dir (default) | vhost | param"
  echo "    -w  Custom wordlist (default: a SecLists list for the mode)"
  echo "    -o  Output directory (default: ./fuzz-<host>)"
  echo "    -t  Threads, 1-500 (default: 40)"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -u) hk_need_arg "$@"; URL="$2";      shift 2 ;;
    -m) hk_need_arg "$@"; MODE="$2";     shift 2 ;;
    -w) hk_need_arg "$@"; WORDLIST="$2"; shift 2 ;;
    -o) hk_need_arg "$@"; OUT_DIR="$2";  shift 2 ;;
    -t) hk_need_arg "$@"; THREADS="$2";  shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1"; usage 1 ;;
  esac
done
[[ -z "$URL" ]] && { echo "Error: -u required"; usage 1; }
hk_valid_url "$URL" || die "Invalid URL: '$URL' (expected http(s)://host[:port][/path])"
hk_valid_int "$THREADS" 1 500 || die "Invalid thread count: '$THREADS' (1-500)"

URL="${URL%/}"                # avoid "https://x.com//FUZZ"
HOST="${URL#*://}"; HOST="${HOST%%/*}"; HOST="${HOST%%:*}"
OUT_DIR="${OUT_DIR:-./fuzz-${HOST}}"
HK_LOG_DIR="$OUT_DIR/logs"
mkdir -p "$OUT_DIR" "$HK_LOG_DIR"

pick_wordlist() {
  local wl="${WORDLIST:-$1}"
  [[ -f "$wl" ]] || die "Wordlist not found: $wl (install SecLists via install.sh, or pass -w)"
  echo "$wl"
}

case "$MODE" in
  dir)
    WL=$(pick_wordlist "$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt")
    hk_have ffuf || hk_have feroxbuster || die "Need ffuf or feroxbuster for dir mode"
    step "Directory Fuzzing (ffuf + feroxbuster)"
    if hk_have ffuf; then
      hk_run ffuf ffuf -c -u "$URL/FUZZ" -w "$WL" -t "$THREADS" -ac \
        -o "$OUT_DIR/ffuf_dirs.json" -of json || true
    fi
    if hk_have feroxbuster; then
      hk_run feroxbuster feroxbuster -u "$URL" -w "$WL" -t "$THREADS" \
        -s 200,204,301,302,307,401,403 --no-state \
        -o "$OUT_DIR/ferox_dirs.txt" || true
    fi
    ;;
  vhost)
    WL=$(pick_wordlist "$WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-20000.txt")
    hk_require ffuf
    step "VHost Fuzzing"
    hk_run ffuf ffuf -c -u "$URL" -H "Host: FUZZ.$HOST" -w "$WL" -t "$THREADS" -ac \
      -o "$OUT_DIR/vhosts.json" -of json || true
    ;;
  param)
    # Arjun is a pip package (CLI "arjun"); the old "$TOOLS/arjun/arjun.py" path never existed.
    hk_require arjun
    step "Parameter Fuzzing (arjun)"
    hk_run arjun arjun -u "$URL" -t "$THREADS" -oJ "$OUT_DIR/params.json" || true
    ;;
  *)
    die "Unknown mode: $MODE (use dir, vhost, or param)" ;;
esac

echo -e "\n${GREEN}${BOLD}Fuzzing complete. Results → $OUT_DIR/${RESET}  (logs: $HK_LOG_DIR/)"
