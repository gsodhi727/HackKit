#!/usr/bin/env bash
# ============================================================
#  HackKit — Tool Updater
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : sudo bash update.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
DIM='\033[2m'

PASS=0; FAIL=0

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; ((PASS++)) || true; }
error()   { echo -e "${RED}[✗]${RESET} $*";  ((FAIL++)) || true; }

section() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}${BOLD}  ▸ $*${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

update_go_tool() {
  local name="$1"
  local pkg="$2"
  printf "  %-30s" "$name"
  if go install "$pkg@latest" &>/dev/null; then
    echo -e "${GREEN}[UPDATED]${RESET}"
    ((PASS++)) || true
  else
    echo -e "${RED}[FAIL]${RESET}"
    ((FAIL++)) || true
  fi
}

update_python_tool() {
  local name="$1"
  local dest="$HOME/tools/$name"
  printf "  %-30s" "$name"
  if [[ -d "$dest/.git" ]]; then
    if git -C "$dest" pull --quiet &>/dev/null; then
      echo -e "${GREEN}[UPDATED]${RESET}"
      ((PASS++)) || true
    else
      echo -e "${RED}[FAIL]${RESET}"
      ((FAIL++)) || true
    fi
  else
    echo -e "${DIM}[SKIP - not git]${RESET}"
  fi
}

echo ""
echo -e "${CYAN}${BOLD}  HackKit — Tool Updater${RESET}"
echo ""

section "System Packages"
apt-get update -y &>/dev/null && apt-get upgrade -y &>/dev/null && success "apt packages updated"

section "Go Tools"
update_go_tool "subfinder"     "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"
update_go_tool "httpx"         "github.com/projectdiscovery/httpx/cmd/httpx"
update_go_tool "nuclei"        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei"
update_go_tool "katana"        "github.com/projectdiscovery/katana/cmd/katana"
update_go_tool "dnsx"          "github.com/projectdiscovery/dnsx/cmd/dnsx"
update_go_tool "naabu"         "github.com/projectdiscovery/naabu/v2/cmd/naabu"
update_go_tool "alterx"        "github.com/projectdiscovery/alterx/cmd/alterx"
update_go_tool "tlsx"          "github.com/projectdiscovery/tlsx/cmd/tlsx"
update_go_tool "cdncheck"      "github.com/projectdiscovery/cdncheck/cmd/cdncheck"
update_go_tool "mapcidr"       "github.com/projectdiscovery/mapcidr/cmd/mapcidr"
update_go_tool "notify"        "github.com/projectdiscovery/notify/cmd/notify"
update_go_tool "interactsh-client" "github.com/projectdiscovery/interactsh/cmd/interactsh-client"
update_go_tool "dalfox"        "github.com/hahwul/dalfox/v2"
update_go_tool "gau"           "github.com/lc/gau/v2/cmd/gau"
update_go_tool "waybackurls"   "github.com/tomnomnom/waybackurls"
update_go_tool "ffuf"          "github.com/ffuf/ffuf/v2"
update_go_tool "gobuster"      "github.com/OJ/gobuster/v3"
update_go_tool "trufflehog"    "github.com/trufflesecurity/trufflehog/v3"
update_go_tool "subzy"         "github.com/PentestPad/subzy"

section "Nuclei Templates"
nuclei -update-templates -silent && success "Templates updated"

section "Python Tools"
update_python_tool "arjun"
update_python_tool "SecretFinder"
update_python_tool "LinkFinder"
update_python_tool "ParamSpider"
update_python_tool "dirsearch"
update_python_tool "corsy"
update_python_tool "xsstrike"
update_python_tool "ghauri"
update_python_tool "SSRFmap"

section "Feroxbuster"
if command -v feroxbuster &>/dev/null; then
  url=$(curl -fsSL "https://api.github.com/repos/epi052/feroxbuster/releases/latest" \
        | jq -r '.assets[] | select(.name | test("linux-x86_64.zip")) | .browser_download_url')
  tmp=$(mktemp -d)
  if curl -fsSL "$url" -o "$tmp/f.zip" &>/dev/null && \
     unzip -q "$tmp/f.zip" -d "$tmp" &>/dev/null && \
     mv -f "$tmp/feroxbuster" /usr/local/bin/feroxbuster; then
    rm -rf "$tmp"
    success "feroxbuster updated"
  else
    rm -rf "$tmp"
    error "feroxbuster update failed"
  fi
fi

section "DNS Resolvers"
curl -fsSL "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
  -o "$HOME/wordlists/resolvers.txt" &>/dev/null && success "Resolvers refreshed"

echo ""
echo -e "${GREEN}${BOLD}Update complete!${RESET}  ✓ $PASS updated  ✗ $FAIL failed"
echo ""
