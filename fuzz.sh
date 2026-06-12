#!/usr/bin/env bash
# ============================================================
#  HackKit — Fuzzing Pipeline
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash fuzz.sh -u https://target.com [-m dir|vhost|param]
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; BOLD='\033[1m'; GREEN='\033[0;32m'; RESET='\033[0m'
WORDLISTS="$HOME/wordlists"

URL=""; MODE="dir"; OUT_DIR=""; THREADS=40

usage() {
  echo -e "${CYAN}${BOLD}HackKit — Fuzzer${RESET}"
  echo "  Usage: $0 -u <url> [-m dir|vhost|param] [-o output] [-t threads]"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -u) URL="$2";     shift 2 ;;
    -m) MODE="$2";    shift 2 ;;
    -o) OUT_DIR="$2"; shift 2 ;;
    -t) THREADS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done
[[ -z "$URL" ]] && { echo "Error: -u required"; usage; }

HOST=$(echo "$URL" | unfurl format %d)
OUT_DIR="${OUT_DIR:-./fuzz-${HOST}}"
mkdir -p "$OUT_DIR"

case "$MODE" in
  dir)
    echo -e "${CYAN}${BOLD}▸ Directory Fuzzing (ffuf + feroxbuster)${RESET}"
    ffuf -c -u "$URL/FUZZ" \
      -w "$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt" \
      -t "$THREADS" -ac -o "$OUT_DIR/ffuf_dirs.json" -of json 2>/dev/null || true

    feroxbuster -u "$URL" \
      -w "$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt" \
      -t "$THREADS" -s 200,204,301,302,307,401,403 \
      -o "$OUT_DIR/ferox_dirs.txt" 2>/dev/null || true
    ;;
  vhost)
    echo -e "${CYAN}${BOLD}▸ VHost Fuzzing${RESET}"
    ffuf -c -u "$URL" -H "Host: FUZZ.$HOST" \
      -w "$WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-20000.txt" \
      -t "$THREADS" -ac -o "$OUT_DIR/vhosts.json" -of json 2>/dev/null || true
    ;;
  param)
    echo -e "${CYAN}${BOLD}▸ Parameter Fuzzing (arjun)${RESET}"
    python3 "$HOME/tools/arjun/arjun.py" -u "$URL" \
      -oJ "$OUT_DIR/params.json" 2>/dev/null || \
    arjun -u "$URL" -oJ "$OUT_DIR/params.json" 2>/dev/null || true
    ;;
  *)
    echo "Unknown mode: $MODE (use dir, vhost, or param)"; exit 1 ;;
esac

echo -e "\n${GREEN}${BOLD}Fuzzing complete. Results → $OUT_DIR/${RESET}"
