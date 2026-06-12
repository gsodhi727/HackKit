#!/usr/bin/env bash
# ============================================================
#  HackKit — Bug Bounty Toolkit Installer
#  Version : 2.0.0
#  Author  : gsodhi727  (github.com/guru)
#  GitHub  : https://github.com/gsodhi727/hackkit
#  License : MIT
# ============================================================
set -euo pipefail

# ──────────────────────── COLOURS ────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m';  BOLD='\033[1m'
DIM='\033[2m';     RESET='\033[0m'

# ──────────────────────── GLOBALS ────────────────────────────
LOG_FILE="/tmp/hackkit_install_$(date +%Y%m%d_%H%M%S).log"
TOOLS_DIR="$HOME/tools"
WORDLISTS_DIR="$HOME/wordlists"
GO_VERSION="1.22.4"
PYTHON_VENV="$HOME/.hackkit-venv"
ALIAS_FILE="/etc/profile.d/hackkit.sh"
PASS=0; FAIL=0; SKIP=0

# ──────────────────────── BANNER ─────────────────────────────
banner() {
cat <<'EOF'

  ██╗  ██╗ █████╗  ██████╗██╗  ██╗██╗  ██╗██╗████████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██║ ██╔╝██║╚══██╔══╝
  ███████║███████║██║     █████╔╝ █████╔╝ ██║   ██║
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔═██╗ ██║   ██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗██║  ██╗██║   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝

EOF
  echo -e "${CYAN}${BOLD}  ┌──────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}${BOLD}  │    Bug Bounty Toolkit Installer  v2.0  ·  by gsodhi727            │${RESET}"
  echo -e "${CYAN}${BOLD}  │    github.com/gsodhi727/hackkit        ·  80+ tools               │${RESET}"
  echo -e "${CYAN}${BOLD}  └──────────────────────────────────────────────────────────────┘${RESET}"
  echo ""
}

# ──────────────────────── HELPERS ────────────────────────────
log()     { echo -e "$(date '+%H:%M:%S') $*" >> "$LOG_FILE"; }
info()    { echo -e "${BLUE}[*]${RESET} $*";  log "[INFO]  $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; log "[OK]    $*"; ((PASS++)) || true; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; log "[WARN]  $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*";  log "[ERROR] $*"; ((FAIL++)) || true; }

section() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}${BOLD}  ▸ $*${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

progress() {
  local tool="$1"
  printf "${BLUE}  ➜ Installing %-35s${RESET}" "$tool..."
}

done_ok()   { echo -e "${GREEN}[DONE]${RESET}"; }
done_fail() { echo -e "${RED}[FAIL]${RESET}";  }
done_skip() { echo -e "${DIM}[SKIP]${RESET}";  }

run_quiet() {
  if "$@" >> "$LOG_FILE" 2>&1; then return 0; else return 1; fi
}

# ── Go tool via `go install` ──────────────────────────────────
install_go_tool() {
  local name="$1"
  local pkg="$2"
  progress "$name"
  if command -v "$name" &>/dev/null; then
    done_skip; ((SKIP++)) || true; return 0
  fi
  if run_quiet go install -v "$pkg@latest"; then
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
}

# ── Clone Python tool ─────────────────────────────────────────
install_python_tool() {
  local name="$1"
  local repo="$2"
  local dest="$TOOLS_DIR/$name"
  progress "$name"
  if [[ -d "$dest" ]]; then
    done_skip; ((SKIP++)) || true; return 0
  fi
  if run_quiet git clone --depth 1 "$repo" "$dest"; then
    if [[ -f "$dest/requirements.txt" ]]; then
      run_quiet "$PYTHON_VENV/bin/pip" install -r "$dest/requirements.txt" --quiet
    fi
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
}

# ── APT package ───────────────────────────────────────────────
install_apt() {
  local name="$1"
  local pkg="${2:-$1}"
  progress "$name"
  if dpkg -s "$pkg" &>/dev/null 2>&1; then
    done_skip; ((SKIP++)) || true; return 0
  fi
  if run_quiet apt-get install -y "$pkg"; then
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
}

# ──────────────────── PRIVILEGE CHECK ────────────────────────
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] This script must be run as root (sudo bash install.sh).${RESET}"
    exit 1
  fi
}

# ────────────────────── OS DETECTION ─────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-Linux}"
  else
    OS_ID="unknown"; OS_NAME="Unknown Linux"
  fi
  info "Detected OS: ${BOLD}$OS_NAME${RESET}"
  if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" && "$OS_ID" != "kali" ]]; then
    warn "Optimized for Debian / Ubuntu / Kali. Proceed with caution on $OS_NAME."
  fi
}

# ──────────────────── SYSTEM PACKAGES ────────────────────────
install_base_packages() {
  section "System Dependencies"
  info "Updating package lists..."
  run_quiet apt-get update -y

  local pkgs=(
    curl wget git unzip tar jq make gcc g++ build-essential
    python3 python3-pip python3-venv python3-dev
    libssl-dev libffi-dev libpcap-dev
    nmap masscan sqlmap nikto wfuzz
    dirb hydra john hashcat aircrack-ng
    dnsutils whois netcat-traditional traceroute
    p0f dnsenum dnsmap dnstracer
    theharvester recon-ng fierce
    wireshark-common tshark
    ruby-full
    libxml2 libxml2-dev libxslt-dev
    net-tools iputils-ping
    tmux vim nano
    software-properties-common apt-transport-https ca-certificates
  )

  for pkg in "${pkgs[@]}"; do
    install_apt "$pkg" "$pkg" 2>/dev/null || true
  done
}

# ──────────────────────── GO SETUP ───────────────────────────
install_go() {
  section "Go Language Setup"

  if command -v go &>/dev/null; then
    local cur
    cur=$(go version | awk '{print $3}' | sed 's/go//')
    info "Go $cur already installed — skipping"; ((SKIP++)) || true
    return 0
  fi

  progress "Go $GO_VERSION"
  local arch; arch=$(uname -m)
  local go_arch="amd64"
  [[ "$arch" == "aarch64" ]] && go_arch="arm64"
  [[ "$arch" == "armv7l"  ]] && go_arch="armv6l"

  local tarball="go${GO_VERSION}.linux-${go_arch}.tar.gz"
  local url="https://go.dev/dl/$tarball"

  if run_quiet curl -fsSL "$url" -o "/tmp/$tarball" && \
     run_quiet tar -C /usr/local -xzf "/tmp/$tarball"; then
    ln -sf /usr/local/go/bin/go    /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    rm -f "/tmp/$tarball"
    done_ok
  else
    done_fail
    error "Go installation failed — Go tools will be skipped."
    return 1
  fi

  # Persist GOPATH in shell profiles
  for rc in /root/.bashrc /root/.zshrc /home/*/.bashrc /home/*/.zshrc; do
    [[ -f "$rc" ]] || continue
    grep -q 'GOPATH' "$rc" && continue
    cat >> "$rc" <<'GOENV'

# ── Go environment (added by HackKit) ──
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
GOENV
  done
  export GOROOT=/usr/local/go
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
  success "Go $GO_VERSION installed"
}

# ──────────────────── PYTHON VENV SETUP ──────────────────────
setup_python_env() {
  section "Python3 Environment"
  progress "Virtual environment"
  if [[ -d "$PYTHON_VENV" ]]; then
    done_skip; ((SKIP++)) || true
  else
    if run_quiet python3 -m venv "$PYTHON_VENV"; then
      done_ok; ((PASS++)) || true
    else
      done_fail; ((FAIL++)) || true; return 1
    fi
  fi

  info "Upgrading pip & installing base libraries..."
  run_quiet "$PYTHON_VENV/bin/pip" install --upgrade pip setuptools wheel \
    requests httpx aiohttp dnspython beautifulsoup4 lxml \
    jsbeautifier wafw00f colorama tabulate tqdm --quiet
  success "Python venv ready → $PYTHON_VENV"

  for rc in /root/.bashrc /root/.zshrc /home/*/.bashrc /home/*/.zshrc; do
    [[ -f "$rc" ]] || continue
    grep -q 'hackkit-venv' "$rc" && continue
    echo "source $PYTHON_VENV/bin/activate" >> "$rc"
  done
}

# ──────────────────── GO TOOLS ───────────────────────────────
install_go_tools() {
  section "Go-Based Tools"

  # ── Subdomain & Recon ──
  install_go_tool "subfinder"         "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"
  install_go_tool "assetfinder"       "github.com/tomnomnom/assetfinder"
  install_go_tool "amass"             "github.com/owasp-amass/amass/v4/..."
  install_go_tool "chaos"             "github.com/projectdiscovery/chaos-client/cmd/chaos"
  install_go_tool "crobat"            "github.com/cgboal/sonarsearch/cmd/crobat"
  install_go_tool "gotator"           "github.com/Josue87/gotator"
  install_go_tool "alterx"            "github.com/projectdiscovery/alterx/cmd/alterx"

  # ── HTTP & Probing ──
  install_go_tool "httpx"             "github.com/projectdiscovery/httpx/cmd/httpx"
  install_go_tool "httprobe"          "github.com/tomnomnom/httprobe"
  install_go_tool "katana"            "github.com/projectdiscovery/katana/cmd/katana"
  install_go_tool "gospider"          "github.com/jaeles-project/gospider"
  install_go_tool "hakrawler"         "github.com/hakluke/hakrawler"

  # ── URL & Wayback Machine ──
  install_go_tool "gau"               "github.com/lc/gau/v2/cmd/gau"
  install_go_tool "waybackurls"       "github.com/tomnomnom/waybackurls"
  install_go_tool "waymore"           "github.com/xnl-h4ck3r/waymore"
  install_go_tool "galer"             "github.com/dwisiswant0/galer"

  # ── DNS ──
  install_go_tool "dnsx"              "github.com/projectdiscovery/dnsx/cmd/dnsx"
  install_go_tool "puredns"           "github.com/d3mondev/puredns/v2"
  install_go_tool "shuffledns"        "github.com/projectdiscovery/shuffledns/cmd/shuffledns"
  install_go_tool "massdns"           "github.com/blechschmidt/massdns/cmd/massdns" 2>/dev/null || true

  # ── Port & Network ──
  install_go_tool "naabu"             "github.com/projectdiscovery/naabu/v2/cmd/naabu"
  install_go_tool "tlsx"              "github.com/projectdiscovery/tlsx/cmd/tlsx"
  install_go_tool "cdncheck"          "github.com/projectdiscovery/cdncheck/cmd/cdncheck"
  install_go_tool "asnmap"            "github.com/projectdiscovery/asnmap/cmd/asnmap"
  install_go_tool "cf-check"          "github.com/dwisiswant0/cf-check"

  # ── Fuzzing & Scanning ──
  install_go_tool "ffuf"              "github.com/ffuf/ffuf/v2"
  install_go_tool "gobuster"          "github.com/OJ/gobuster/v3"
  install_go_tool "nuclei"            "github.com/projectdiscovery/nuclei/v3/cmd/nuclei"
  install_go_tool "interactsh-client" "github.com/projectdiscovery/interactsh/cmd/interactsh-client"

  # ── Screenshots ──
  install_go_tool "gowitness"         "github.com/sensepost/gowitness"

  # ── XSS ──
  install_go_tool "dalfox"            "github.com/hahwul/dalfox/v2"
  install_go_tool "kxss"              "github.com/Emoe/kxss"
  install_go_tool "Gxss"              "github.com/KathanP19/Gxss"
  install_go_tool "bxss"              "github.com/ethicalhackingplayground/bxss"

  # ── Subdomain Takeover ──
  install_go_tool "subzy"             "github.com/PentestPad/subzy"
  install_go_tool "dnstake"           "github.com/pwnesia/dnstake"
  install_go_tool "subjack"           "github.com/haccer/subjack"

  # ── OSINT ──
  install_go_tool "github-subdomains" "github.com/gwen001/github-subdomains"
  install_go_tool "socialhunter"      "github.com/utkusen/socialhunter"
  install_go_tool "trufflehog"        "github.com/trufflesecurity/trufflehog/v3"

  # ── Utilities ──
  install_go_tool "anew"              "github.com/tomnomnom/anew"
  install_go_tool "qsreplace"         "github.com/tomnomnom/qsreplace"
  install_go_tool "gron"              "github.com/tomnomnom/gron"
  install_go_tool "fff"               "github.com/tomnomnom/fff"
  install_go_tool "unfurl"            "github.com/tomnomnom/unfurl"
  install_go_tool "mapcidr"           "github.com/projectdiscovery/mapcidr/cmd/mapcidr"
  install_go_tool "notify"            "github.com/projectdiscovery/notify/cmd/notify"
  install_go_tool "cent"              "github.com/xm1k3/cent"
  install_go_tool "subzy"             "github.com/PentestPad/subzy"
}

# ──────────────── FEROXBUSTER (Rust binary) ──────────────────
install_feroxbuster() {
  section "Feroxbuster (Rust)"
  progress "feroxbuster"
  if command -v feroxbuster &>/dev/null; then
    done_skip; ((SKIP++)) || true; return 0
  fi
  local url
  url=$(curl -fsSL "https://api.github.com/repos/epi052/feroxbuster/releases/latest" \
        | jq -r '.assets[] | select(.name | test("linux-x86_64.zip")) | .browser_download_url')
  local tmp_dir; tmp_dir=$(mktemp -d)
  if run_quiet curl -fsSL "$url" -o "$tmp_dir/feroxbuster.zip" && \
     run_quiet unzip -q "$tmp_dir/feroxbuster.zip" -d "$tmp_dir" && \
     run_quiet mv "$tmp_dir/feroxbuster" /usr/local/bin/feroxbuster && \
     run_quiet chmod +x /usr/local/bin/feroxbuster; then
    rm -rf "$tmp_dir"; done_ok; ((PASS++)) || true
  else
    rm -rf "$tmp_dir"; done_fail; ((FAIL++)) || true
  fi
}

# ──────────────────── PYTHON TOOLS ───────────────────────────
install_python_tools() {
  section "Python Tools"
  mkdir -p "$TOOLS_DIR"

  install_python_tool "arjun"        "https://github.com/s0md3v/Arjun"
  install_python_tool "GitHacker"    "https://github.com/WangYihang/GitHacker"
  install_python_tool "SecretFinder" "https://github.com/m4ll0k/SecretFinder"
  install_python_tool "LinkFinder"   "https://github.com/GerbenJavado/LinkFinder"
  install_python_tool "uro"          "https://github.com/s0md3v/uro"
  install_python_tool "urless"       "https://github.com/xnl-h4ck3r/urless"
  install_python_tool "ParamSpider"  "https://github.com/devanshbatham/ParamSpider"
  install_python_tool "dirsearch"    "https://github.com/maurosoria/dirsearch"
  install_python_tool "corsy"        "https://github.com/s0md3v/Corsy"
  install_python_tool "CORStest"     "https://github.com/RUB-NDS/CORStest"
  install_python_tool "xsstrike"     "https://github.com/s0md3v/XSStrike"
  install_python_tool "byp4xx"       "https://github.com/lobuhi/byp4xx"
  install_python_tool "403fuzzer"    "https://github.com/intrudir/403fuzzer"
  install_python_tool "SSRFmap"      "https://github.com/swisskyrepo/SSRFmap"
  install_python_tool "SQLiDetector" "https://github.com/eslam3kl/SQLiDetector"
  install_python_tool "log4j-scan"   "https://github.com/fullhunt/log4j-scan"
  install_python_tool "ghauri"       "https://github.com/r0oth3x49/ghauri"

  info "Installing pip tools..."
  local pip_tools=(
    "wafw00f" "arjun" "uro" "jsbeautifier"
    "holehe" "sherlock" "dnsdumpster"
  )
  for t in "${pip_tools[@]}"; do
    progress "$t"
    if run_quiet "$PYTHON_VENV/bin/pip" install "$t" --quiet; then
      done_ok; ((PASS++)) || true
    else
      done_fail; ((FAIL++)) || true
    fi
  done
}

# ──────────────── NUCLEI TEMPLATES ───────────────────────────
setup_nuclei_templates() {
  section "Nuclei Templates"
  progress "Official templates"
  if run_quiet nuclei -update-templates -silent; then
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
  progress "cent (community templates)"
  if command -v cent &>/dev/null; then
    run_quiet cent -i "$HOME/nuclei-templates" -p || true
    done_ok; ((PASS++)) || true
  else
    done_skip; ((SKIP++)) || true
  fi
}

# ──────────────────── WORDLISTS ──────────────────────────────
setup_wordlists() {
  section "Wordlists"
  mkdir -p "$WORDLISTS_DIR"

  progress "SecLists"
  if [[ -d "$WORDLISTS_DIR/SecLists" ]]; then
    done_skip; ((SKIP++)) || true
  else
    run_quiet git clone --depth 1 \
      "https://github.com/danielmiessler/SecLists.git" \
      "$WORDLISTS_DIR/SecLists" && done_ok || done_fail
    ((PASS++)) || true
  fi

  progress "Assetnote best-dns-wordlist"
  if [[ ! -f "$WORDLISTS_DIR/best-dns-wordlist.txt" ]]; then
    run_quiet curl -fsSL \
      "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
      -o "$WORDLISTS_DIR/best-dns-wordlist.txt" && done_ok || done_fail
    ((PASS++)) || true
  else
    done_skip; ((SKIP++)) || true
  fi

  progress "Commonspeak2 subdomains"
  if [[ ! -f "$WORDLISTS_DIR/commonspeak2.txt" ]]; then
    run_quiet curl -fsSL \
      "https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt" \
      -o "$WORDLISTS_DIR/commonspeak2.txt" && done_ok || done_fail
    ((PASS++)) || true
  else
    done_skip; ((SKIP++)) || true
  fi

  ln -sf "$WORDLISTS_DIR" /usr/share/wordlists-hackkit 2>/dev/null || true
  success "Wordlists saved → $WORDLISTS_DIR"
}

# ──────────────── DNS RESOLVERS ──────────────────────────────
setup_resolvers() {
  section "DNS Resolvers"
  progress "Public resolvers"
  run_quiet curl -fsSL \
    "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
    -o "$WORDLISTS_DIR/resolvers.txt" && done_ok || done_fail
  ((PASS++)) || true
}

# ──────────────── ALIASES & HELPERS ──────────────────────────
install_helpers() {
  section "Shell Aliases & Helpers"
  cat > "$ALIAS_FILE" <<ALIASES
# ── HackKit Aliases ─────────────────────────────────────────
export WORDLISTS="\$HOME/wordlists"
export TOOLS="\$HOME/tools"
export HACKKIT_VENV="\$HOME/.hackkit-venv"

# Python venv shortcut
alias hkenv="source \$HACKKIT_VENV/bin/activate"

# Recon
alias sub-enum='f(){ subfinder -d \$1 | anew subs.txt | httpx -silent | anew alive.txt; }; f'
alias nmap-quick='nmap -sCV -T4 --open'
alias nmap-full='nmap -p- -sCV --open -T4'

# Fuzzing
alias ffuf-dir='ffuf -c -u FUZZ -w \$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt'
alias ffuf-vhost='ffuf -c -u http://TARGET -H "Host: FUZZ.TARGET" -w \$WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-110000.txt'
alias ferox-dir='feroxbuster -u'

# Probing
alias naabu-quick='naabu -top-ports 1000 -silent'
alias httpx-probe='httpx -silent -status-code -title -tech-detect'
alias nuclei-fast='nuclei -severity critical,high -silent'
alias nuclei-all='nuclei -severity critical,high,medium,low -silent'

# Tools dir shortcuts
alias tools='ls \$TOOLS'
alias wl='ls \$WORDLISTS'
ALIASES

  chmod +x "$ALIAS_FILE"
  # shellcheck source=/dev/null
  source "$ALIAS_FILE" 2>/dev/null || true
  success "Aliases installed → $ALIAS_FILE"
}

# ──────────────────── ZSH + Oh-My-Zsh ───────────────────────
install_zsh() {
  section "ZSH + Oh-My-Zsh"
  install_apt "zsh"
  progress "oh-my-zsh"
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    done_skip; ((SKIP++)) || true
  else
    run_quiet sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended && done_ok || done_fail
    ((PASS++)) || true
  fi

  progress "zsh-autosuggestions"
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    run_quiet git clone --depth 1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "$zsh_custom/plugins/zsh-autosuggestions" && done_ok || done_fail
    ((PASS++)) || true
  else
    done_skip; ((SKIP++)) || true
  fi

  if [[ -f "$HOME/.zshrc" ]]; then
    sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc" 2>/dev/null || true
    sed -i 's/plugins=.*/plugins=(git zsh-autosuggestions z colored-man-pages)/' "$HOME/.zshrc" 2>/dev/null || true
    grep -q 'hackkit' "$HOME/.zshrc" || echo "source $ALIAS_FILE" >> "$HOME/.zshrc"
  fi
}

# ──────────────── TMUX CONFIG ────────────────────────────────
setup_tmux() {
  section "Tmux Configuration"
  progress "tmux config"
  cat > "$HOME/.tmux.conf" <<'TMUX'
# ── HackKit tmux config ──────────────────────────────────────
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"
set -g status-bg colour235
set -g status-fg colour255
set -g status-left '#[fg=colour46,bold] ⚡ HackKit '
set -g status-right '#[fg=colour39]%d %b %Y  %H:%M '
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
bind | split-window -h
bind - split-window -v
TMUX
  done_ok; ((PASS++)) || true
}

# ──────────────────── DOCKER ─────────────────────────────────
install_docker() {
  section "Docker"
  progress "Docker engine"
  if command -v docker &>/dev/null; then
    done_skip; ((SKIP++)) || true; return 0
  fi
  if run_quiet curl -fsSL https://get.docker.com | bash; then
    run_quiet systemctl enable docker --quiet || true
    run_quiet systemctl start  docker --quiet || true
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
}

# ──────────────── CLEANUP ────────────────────────────────────
cleanup() {
  section "Cleanup"
  run_quiet apt-get autoremove -y
  run_quiet apt-get clean
  success "Cleanup complete"
}

# ──────────────────── SUMMARY ────────────────────────────────
print_summary() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}${BOLD}  HACKKIT — INSTALLATION SUMMARY${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  echo -e "  ${GREEN}✓ Installed :${RESET} $PASS"
  echo -e "  ${DIM}~ Skipped   : $SKIP (already present)${RESET}"
  echo -e "  ${RED}✗ Failed    :${RESET} $FAIL"
  echo ""
  echo -e "  ${BOLD}Tools dir   :${RESET} $TOOLS_DIR"
  echo -e "  ${BOLD}Wordlists   :${RESET} $WORDLISTS_DIR"
  echo -e "  ${BOLD}Python venv :${RESET} $PYTHON_VENV"
  echo -e "  ${BOLD}Log file    :${RESET} $LOG_FILE"
  echo ""
  if [[ $FAIL -gt 0 ]]; then
    warn "Some tools failed. See log: ${BOLD}$LOG_FILE${RESET}"
  else
    success "All tools installed! Happy Hunting! 🎯"
  fi
  echo ""
  echo -e "${YELLOW}  ⚡ Run: ${BOLD}source $ALIAS_FILE${RESET}${YELLOW}  — to load aliases now${RESET}"
  echo -e "${YELLOW}  ⚡ Or open a new terminal session${RESET}"
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ──────────────────────── MAIN ────────────────────────────────
main() {
  clear
  banner
  check_root
  detect_os

  echo -e "${YELLOW}${BOLD}  This will install 80+ tools. Continue? [Y/n]:${RESET} \c"
  read -r ans
  [[ "${ans,,}" =~ ^(n|no)$ ]] && { echo "Aborted."; exit 0; }

  install_base_packages
  install_go
  setup_python_env
  install_go_tools
  install_feroxbuster
  install_python_tools
  setup_nuclei_templates
  setup_wordlists
  setup_resolvers
  install_helpers
  install_zsh
  setup_tmux
  install_docker
  cleanup
  print_summary
}

main "$@"
