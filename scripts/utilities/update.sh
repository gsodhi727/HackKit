#!/usr/bin/env bash
# ============================================================
#  HackKit — Tool Updater
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : sudo bash update.sh
#
#  Updates exactly the tools install.sh installs (same lists in
#  config/), instead of a separate hand-maintained subset.
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# /opt/hackkit (Docker / installed copy) or a repo checkout both have config/.
[[ -d "$HK_ROOT/config" ]] || { echo "Can't find $HK_ROOT/config — run from a HackKit checkout."; exit 1; }
export HK_ROOT
HK_LOG="/tmp/hackkit_update_$(date +%Y%m%d_%H%M%S).log"
export HK_LOG

# shellcheck source=../lib/bootstrap.sh
source "$HK_ROOT/scripts/lib/bootstrap.sh"

CYAN='\033[0;36m'; BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

section() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}${BOLD}  ▸ $*${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}[!] Not root: system packages and /usr/local/bin tools will be skipped.${RESET}"
fi

echo ""
echo -e "${CYAN}${BOLD}  HackKit — Tool Updater${RESET}   (log: $HK_LOG)"

if [[ $EUID -eq 0 ]] && command -v apt-get >/dev/null 2>&1; then
  section "System Packages"
  if _q apt-get update -y && _q env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
    _ok "apt packages"
  else
    _fail "apt packages"
  fi
fi

section "Go Tools"
hk_go_tools update

section "Nuclei Templates"
if command -v nuclei >/dev/null 2>&1; then
  if _q nuclei -update-templates -silent; then _ok "nuclei templates"; else _fail "nuclei templates"; fi
else
  _skip "nuclei templates (nuclei missing)"
fi

section "Python"
hk_python_venv
hk_python_repos update

if [[ $EUID -eq 0 ]]; then
  section "Binaries"
  hk_install_feroxbuster update
  hk_install_massdns
fi

section "DNS Resolvers"
mkdir -p "${WORDLISTS:-$HOME/wordlists}"
if _q curl -fsSL "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
     -o "${WORDLISTS:-$HOME/wordlists}/resolvers.txt"; then
  _ok "resolvers.txt"
else
  _fail "resolvers.txt"
fi

echo ""
echo -e "${GREEN}${BOLD}Update complete!${RESET}  ✓ $BS_PASS updated  ~ $BS_SKIP skipped  ✗ $BS_FAIL failed"
if (( BS_FAIL > 0 )); then
  echo "  Failed: ${BS_FAILED_ITEMS[*]}  — details in $HK_LOG"
fi
echo ""
