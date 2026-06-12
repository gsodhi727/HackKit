#!/usr/bin/env bash
# ============================================================
#  HackKit — Recon Pipeline
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash recon.sh -d target.com
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

usage() {
  echo -e "${CYAN}${BOLD}HackKit — Recon Pipeline${RESET}"
  echo ""
  echo "  Usage: $0 -d <domain> [-o output_dir] [-t threads] [--skip-screenshots]"
  echo ""
  echo "  Options:"
  echo "    -d  Domain to recon (required)"
  echo "    -o  Output directory (default: ./recon-<domain>)"
  echo "    -t  Number of threads (default: 50)"
  echo "    --skip-screenshots   Skip gowitness"
  echo "    --nuclei-only        Only run nuclei on discovered URLs"
  echo "    -h  Show this help"
  echo ""
  exit 0
}

DOMAIN=""
OUT_DIR=""
THREADS=50
SKIP_SCREENSHOTS=false
NUCLEI_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -d)          DOMAIN="$2";           shift 2 ;;
    -o)          OUT_DIR="$2";          shift 2 ;;
    -t)          THREADS="$2";          shift 2 ;;
    --skip-screenshots) SKIP_SCREENSHOTS=true; shift ;;
    --nuclei-only)      NUCLEI_ONLY=true;      shift ;;
    -h|--help)   usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$DOMAIN" ]] && { echo -e "${RED}Error: -d <domain> is required${RESET}"; usage; }

OUT_DIR="${OUT_DIR:-./recon-${DOMAIN}}"
mkdir -p "$OUT_DIR"/{subs,alive,urls,screenshots,nuclei,ports}

log() { echo -e "$(date '+%H:%M:%S')  $*"; }
step() { echo -e "\n${CYAN}${BOLD}▸ $*${RESET}"; }

# ── 1. Subdomain enumeration ──────────────────────────────────
step "Subdomain Enumeration → $OUT_DIR/subs/all.txt"
subfinder -d "$DOMAIN" -silent -o "$OUT_DIR/subs/subfinder.txt" &
assetfinder --subs-only "$DOMAIN" > "$OUT_DIR/subs/assetfinder.txt" &
(command -v chaos &>/dev/null && chaos -d "$DOMAIN" -silent -o "$OUT_DIR/subs/chaos.txt") &
wait

cat "$OUT_DIR/subs/"*.txt 2>/dev/null | sort -u > "$OUT_DIR/subs/all.txt"
log "$(wc -l < "$OUT_DIR/subs/all.txt") unique subdomains found"

# ── 2. DNS resolution ────────────────────────────────────────
step "DNS Resolution → $OUT_DIR/subs/resolved.txt"
puredns resolve "$OUT_DIR/subs/all.txt" \
  -r "$HOME/wordlists/resolvers.txt" \
  -w "$OUT_DIR/subs/resolved.txt" 2>/dev/null || \
  dnsx -l "$OUT_DIR/subs/all.txt" -silent -o "$OUT_DIR/subs/resolved.txt"
log "$(wc -l < "$OUT_DIR/subs/resolved.txt") resolved"

# ── 3. HTTP Probing ───────────────────────────────────────────
step "HTTP Probe → $OUT_DIR/alive/alive.txt"
httpx -l "$OUT_DIR/subs/resolved.txt" \
  -silent -status-code -title -tech-detect \
  -threads "$THREADS" \
  -o "$OUT_DIR/alive/alive.txt"
log "$(wc -l < "$OUT_DIR/alive/alive.txt") alive hosts"

# ── 4. Port Scan ─────────────────────────────────────────────
step "Port Scan → $OUT_DIR/ports/"
naabu -list "$OUT_DIR/subs/resolved.txt" \
  -top-ports 1000 -silent \
  -o "$OUT_DIR/ports/ports.txt" 2>/dev/null || true

# ── 5. URL Collection ─────────────────────────────────────────
if [[ "$NUCLEI_ONLY" == false ]]; then
  step "URL Collection → $OUT_DIR/urls/"
  cat "$OUT_DIR/alive/alive.txt" | awk '{print $1}' | \
    gau --subs --threads "$THREADS" > "$OUT_DIR/urls/gau.txt" &
  cat "$OUT_DIR/alive/alive.txt" | awk '{print $1}' | \
    waybackurls > "$OUT_DIR/urls/wayback.txt" &
  katana -list "$OUT_DIR/alive/alive.txt" \
    -silent -depth 3 -o "$OUT_DIR/urls/katana.txt" &
  wait
  cat "$OUT_DIR/urls/"*.txt | sort -u | uro > "$OUT_DIR/urls/all_urls.txt"
  log "$(wc -l < "$OUT_DIR/urls/all_urls.txt") unique URLs collected"
fi

# ── 6. Screenshots ───────────────────────────────────────────
if [[ "$SKIP_SCREENSHOTS" == false ]]; then
  step "Screenshots → $OUT_DIR/screenshots/"
  gowitness scan file -f "$OUT_DIR/alive/alive.txt" \
    --screenshot-path "$OUT_DIR/screenshots/" 2>/dev/null || true
fi

# ── 7. Nuclei Scan ───────────────────────────────────────────
step "Nuclei Vulnerability Scan → $OUT_DIR/nuclei/"
nuclei -l "$OUT_DIR/alive/alive.txt" \
  -severity critical,high,medium \
  -silent \
  -o "$OUT_DIR/nuclei/results.txt" 2>/dev/null || true

# ── 8. Subdomain Takeover Check ──────────────────────────────
step "Subdomain Takeover → $OUT_DIR/nuclei/takeover.txt"
subzy run --targets "$OUT_DIR/subs/resolved.txt" \
  --output "$OUT_DIR/nuclei/takeover.txt" 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Recon Complete for: $DOMAIN${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "  Subdomains : $(wc -l < "$OUT_DIR/subs/all.txt")"
echo -e "  Resolved   : $(wc -l < "$OUT_DIR/subs/resolved.txt")"
echo -e "  Alive      : $(wc -l < "$OUT_DIR/alive/alive.txt")"
[[ -f "$OUT_DIR/urls/all_urls.txt" ]] && \
  echo -e "  URLs       : $(wc -l < "$OUT_DIR/urls/all_urls.txt")"
[[ -f "$OUT_DIR/nuclei/results.txt" ]] && \
  echo -e "  Nuclei hits: $(wc -l < "$OUT_DIR/nuclei/results.txt")"
echo -e "  Output dir : ${BOLD}$OUT_DIR${RESET}"
echo ""
