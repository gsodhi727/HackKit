#!/usr/bin/env bash
# ============================================================
#  HackKit — Recon Pipeline
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash recon.sh -d target.com
#  Only run this against targets you are authorised to test.
# ============================================================
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

usage() {
  echo -e "${CYAN}${BOLD}HackKit — Recon Pipeline${RESET}"
  echo ""
  echo "  Usage: $0 -d <domain> [-o output_dir] [-t threads] [--skip-screenshots] [--skip-urls]"
  echo ""
  echo "  Options:"
  echo "    -d  Domain to recon (required)"
  echo "    -o  Output directory (default: ./recon-<domain>)"
  echo "    -t  Number of threads, 1-500 (default: 50)"
  echo "    --skip-screenshots   Skip gowitness"
  echo "    --skip-urls          Skip URL collection (gau/waybackurls/katana)"
  echo "    --nuclei-only        Same as --skip-urls (kept for compatibility)"
  echo "    -h  Show this help"
  echo ""
  exit "${1:-0}"
}

DOMAIN=""
OUT_DIR=""
THREADS=50
SKIP_SCREENSHOTS=false
SKIP_URLS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -d)          hk_need_arg "$@"; DOMAIN="$2"; shift 2 ;;
    -o)          hk_need_arg "$@"; OUT_DIR="$2"; shift 2 ;;
    -t)          hk_need_arg "$@"; THREADS="$2"; shift 2 ;;
    --skip-screenshots)       SKIP_SCREENSHOTS=true; shift ;;
    --skip-urls|--nuclei-only) SKIP_URLS=true;       shift ;;
    -h|--help)   usage 0 ;;
    *) echo "Unknown option: $1"; usage 1 ;;
  esac
done

[[ -z "$DOMAIN" ]] && { echo -e "${RED}Error: -d <domain> is required${RESET}"; usage 1; }
DOMAIN="${DOMAIN,,}"
hk_valid_domain "$DOMAIN" || die "Invalid domain: '$DOMAIN' (expected something like example.com)"
hk_valid_int "$THREADS" 1 500 || die "Invalid thread count: '$THREADS' (1-500)"

hk_require subfinder dnsx httpx

OUT_DIR="${OUT_DIR:-./recon-${DOMAIN}}"
HK_LOG_DIR="$OUT_DIR/logs"
mkdir -p "$OUT_DIR"/{subs,alive,urls,screenshots,nuclei,ports,logs}
SUBS="$OUT_DIR/subs"; ALIVE="$OUT_DIR/alive"; URLS="$OUT_DIR/urls"

# ── 1. Subdomain enumeration ──────────────────────────────────
step "Subdomain Enumeration → $SUBS/all.txt"
: >"$SUBS/subfinder.txt"; : >"$SUBS/assetfinder.txt"; : >"$SUBS/chaos.txt"
pids=()
subfinder -d "$DOMAIN" -silent -o "$SUBS/subfinder.txt" 2>>"$HK_LOG_DIR/subfinder.log" & pids+=($!)
if hk_have assetfinder; then
  assetfinder --subs-only "$DOMAIN" >"$SUBS/assetfinder.txt" 2>>"$HK_LOG_DIR/assetfinder.log" & pids+=($!)
fi
# chaos needs a ProjectDiscovery API key; don't run it (and fail) without one.
if hk_have chaos && [[ -n "${PDCP_API_KEY:-${CHAOS_KEY:-}}" ]]; then
  chaos -d "$DOMAIN" -silent -o "$SUBS/chaos.txt" 2>>"$HK_LOG_DIR/chaos.log" & pids+=($!)
fi
for pid in "${pids[@]}"; do
  wait "$pid" || warn "a subdomain source failed — see $HK_LOG_DIR/"
done

# Explicit file list (a glob would also read all.txt while it's being written).
{ echo "$DOMAIN"; cat "$SUBS/subfinder.txt" "$SUBS/assetfinder.txt" "$SUBS/chaos.txt"; } \
  | tr 'A-Z' 'a-z' | grep -E "(^|\.)${DOMAIN//./\\.}$" | sort -u >"$SUBS/all.txt" || true
log "$(hk_count "$SUBS/all.txt") unique subdomains found"

# ── 2. DNS resolution ────────────────────────────────────────
step "DNS Resolution → $SUBS/resolved.txt"
: >"$SUBS/resolved.txt"
RESOLVERS="$WORDLISTS/resolvers.txt"
if hk_have puredns && hk_have massdns && [[ -s "$RESOLVERS" ]]; then
  hk_run puredns puredns resolve "$SUBS/all.txt" -r "$RESOLVERS" -w "$SUBS/resolved.txt" -q \
    || hk_run dnsx dnsx -l "$SUBS/all.txt" -silent -o "$SUBS/resolved.txt" || true
else
  hk_run dnsx dnsx -l "$SUBS/all.txt" -silent -o "$SUBS/resolved.txt" || true
fi
log "$(hk_count "$SUBS/resolved.txt") resolved"

if [[ ! -s "$SUBS/resolved.txt" ]]; then
  warn "No subdomain resolved — nothing more to scan. Check $HK_LOG_DIR/ and your DNS."
  exit 0
fi

# ── 3. HTTP Probing ───────────────────────────────────────────
# httpx's -status-code/-title output ("https://x [200] [Title]") is for humans;
# the next tools need bare URLs, so keep both.
step "HTTP Probe → $ALIVE/alive.txt"
: >"$ALIVE/httpx_details.txt"
hk_run httpx httpx -l "$SUBS/resolved.txt" \
  -silent -no-color -status-code -title -tech-detect \
  -threads "$THREADS" \
  -o "$ALIVE/httpx_details.txt" >/dev/null || true
awk '{print $1}' "$ALIVE/httpx_details.txt" | sort -u >"$ALIVE/alive.txt"
log "$(hk_count "$ALIVE/alive.txt") alive hosts (details: $ALIVE/httpx_details.txt)"

# ── 4. Port Scan ─────────────────────────────────────────────
if hk_have naabu; then
  step "Port Scan → $OUT_DIR/ports/ports.txt"
  hk_run naabu naabu -list "$SUBS/resolved.txt" -top-ports 1000 -silent \
    -o "$OUT_DIR/ports/ports.txt" >/dev/null || true
else
  warn "naabu not installed — skipping port scan"
fi

# ── 5. URL Collection ─────────────────────────────────────────
if [[ "$SKIP_URLS" == false ]]; then
  step "URL Collection → $URLS/all_urls.txt"
  : >"$URLS/gau.txt"; : >"$URLS/wayback.txt"; : >"$URLS/katana.txt"
  pids=()
  if hk_have gau; then
    echo "$DOMAIN" | gau --subs --threads "$THREADS" >"$URLS/gau.txt" 2>>"$HK_LOG_DIR/gau.log" & pids+=($!)
  fi
  if hk_have waybackurls; then
    echo "$DOMAIN" | waybackurls >"$URLS/wayback.txt" 2>>"$HK_LOG_DIR/waybackurls.log" & pids+=($!)
  fi
  if hk_have katana && [[ -s "$ALIVE/alive.txt" ]]; then
    katana -list "$ALIVE/alive.txt" -silent -depth 3 -o "$URLS/katana.txt" \
      >/dev/null 2>>"$HK_LOG_DIR/katana.log" & pids+=($!)
  fi
  for pid in "${pids[@]}"; do
    wait "$pid" || warn "a URL source failed — see $HK_LOG_DIR/"
  done
  if hk_have uro; then
    cat "$URLS/gau.txt" "$URLS/wayback.txt" "$URLS/katana.txt" | sort -u | uro >"$URLS/all_urls.txt" \
      2>>"$HK_LOG_DIR/uro.log" || warn "uro failed — see $HK_LOG_DIR/uro.log"
  else
    cat "$URLS/gau.txt" "$URLS/wayback.txt" "$URLS/katana.txt" | sort -u >"$URLS/all_urls.txt"
  fi
  log "$(hk_count "$URLS/all_urls.txt") unique URLs collected"
fi

# ── 6. Screenshots ───────────────────────────────────────────
if [[ "$SKIP_SCREENSHOTS" == false && -s "$ALIVE/alive.txt" ]]; then
  if hk_have gowitness; then
    step "Screenshots → $OUT_DIR/screenshots/"
    hk_run gowitness gowitness scan file -f "$ALIVE/alive.txt" \
      --screenshot-path "$OUT_DIR/screenshots/" >/dev/null \
      || warn "gowitness needs Chrome/Chromium installed"
  else
    warn "gowitness not installed — skipping screenshots"
  fi
fi

# ── 7. Nuclei Scan ───────────────────────────────────────────
if hk_have nuclei && [[ -s "$ALIVE/alive.txt" ]]; then
  step "Nuclei Vulnerability Scan → $OUT_DIR/nuclei/results.txt"
  hk_run nuclei nuclei -l "$ALIVE/alive.txt" \
    -severity critical,high,medium -silent \
    -o "$OUT_DIR/nuclei/results.txt" >/dev/null || true
elif ! hk_have nuclei; then
  warn "nuclei not installed — skipping vulnerability scan"
fi

# ── 8. Subdomain Takeover Check ──────────────────────────────
if hk_have subzy; then
  step "Subdomain Takeover → $OUT_DIR/nuclei/takeover.txt"
  hk_run subzy subzy run --targets "$SUBS/resolved.txt" \
    --output "$OUT_DIR/nuclei/takeover.txt" >/dev/null || true
else
  warn "subzy not installed — skipping takeover check"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Recon Complete for: $DOMAIN${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "  Subdomains : $(hk_count "$SUBS/all.txt")"
echo -e "  Resolved   : $(hk_count "$SUBS/resolved.txt")"
echo -e "  Alive      : $(hk_count "$ALIVE/alive.txt")"
[[ -f "$OUT_DIR/ports/ports.txt" ]]   && echo -e "  Open ports : $(hk_count "$OUT_DIR/ports/ports.txt")"
[[ -f "$URLS/all_urls.txt" ]]         && echo -e "  URLs       : $(hk_count "$URLS/all_urls.txt")"
[[ -f "$OUT_DIR/nuclei/results.txt" ]] && echo -e "  Nuclei hits: $(hk_count "$OUT_DIR/nuclei/results.txt")"
echo -e "  Output dir : ${BOLD}$OUT_DIR${RESET}"
echo -e "  Logs       : $HK_LOG_DIR/"
echo ""
