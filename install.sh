#!/usr/bin/env bash
# ============================================================
#  HackKit — Bug Bounty Toolkit Installer
#  Version : 2.0.0
#  Author  : gsodhi727  (github.com/gsodhi727)
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
PYTHON_VENV="$HOME/.hackkit-venv"
ALIAS_FILE="/etc/profile.d/hackkit.sh"
PASS=0; FAIL=0; SKIP=0
ASSUME_YES=false
[[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]] && ASSUME_YES=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="/opt/hackkit"

# Shared Go / Python / binary installer (also used by Dockerfile and update.sh)
export HK_ROOT="$SCRIPT_DIR" HK_LOG="$LOG_FILE" TOOLS="$TOOLS_DIR" HACKKIT_VENV="$PYTHON_VENV"
# shellcheck source=scripts/lib/bootstrap.sh
source "$SCRIPT_DIR/scripts/lib/bootstrap.sh"

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

# Run a step and count it once, correctly. (The old
# "cmd && done_ok || done_fail; ((PASS++))" counted failures as passes.)
step_result() {
  if "$@"; then done_ok; ((PASS++)) || true; else done_fail; ((FAIL++)) || true; fi
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
    libxml2 libxml2-dev libxslt1-dev
    net-tools iputils-ping
    tmux vim nano
    software-properties-common apt-transport-https ca-certificates
  )

  for pkg in "${pkgs[@]}"; do
    install_apt "$pkg" "$pkg" 2>/dev/null || true
  done
}

# ─────────── GO, BINARIES & PYTHON (shared bootstrap) ────────
# The tool lists live in config/ and the install logic in
# scripts/lib/bootstrap.sh, which the Dockerfile and update.sh use too.
install_go() {
  section "Go Language Setup"
  hk_install_go || true
  if ! command -v go &>/dev/null; then
    warn "Go is not available — Go-based tools will be skipped."
    return 0
  fi

  # Persist Go paths in shell profiles
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
}

setup_python_env() {
  section "Python3 Environment"
  hk_python_venv || true
  for rc in /root/.bashrc /root/.zshrc /home/*/.bashrc /home/*/.zshrc; do
    [[ -f "$rc" ]] || continue
    grep -q 'hackkit-venv' "$rc" && continue
    echo "[ -f $PYTHON_VENV/bin/activate ] && source $PYTHON_VENV/bin/activate" >> "$rc"
  done
}

install_go_tools() {
  section "Go-Based Tools"
  hk_go_tools install || true
  section "massdns (needed by puredns)"
  hk_install_massdns || true
}

install_feroxbuster() {
  section "Feroxbuster (Rust)"
  hk_install_feroxbuster install || true
}

install_python_tools() {
  section "Python Tools"
  hk_python_repos install || true
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
    step_result run_quiet git clone --depth 1 \
      "https://github.com/danielmiessler/SecLists.git" \
      "$WORDLISTS_DIR/SecLists"
  fi

  progress "Assetnote best-dns-wordlist"
  if [[ ! -f "$WORDLISTS_DIR/best-dns-wordlist.txt" ]]; then
    step_result run_quiet curl -fsSL \
      "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
      -o "$WORDLISTS_DIR/best-dns-wordlist.txt"
  else
    done_skip; ((SKIP++)) || true
  fi

  progress "Commonspeak2 subdomains"
  if [[ ! -f "$WORDLISTS_DIR/commonspeak2.txt" ]]; then
    step_result run_quiet curl -fsSL \
      "https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt" \
      -o "$WORDLISTS_DIR/commonspeak2.txt"
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
  step_result run_quiet curl -fsSL \
    "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
    -o "$WORDLISTS_DIR/resolvers.txt"
}

# ──────────────── HACKKIT SCRIPTS ────────────────────────────
# Copy the pipelines to the same place the Docker image uses, so the
# recon/xss/fuzz aliases work no matter where the repo was cloned.
install_scripts() {
  section "HackKit Scripts"
  progress "scripts → $INSTALL_PREFIX"
  if [[ "$(realpath "$SCRIPT_DIR")" == "$(realpath -m "$INSTALL_PREFIX")" ]]; then
    # Repo was cloned straight into /opt/hackkit — nothing to copy.
    find "$INSTALL_PREFIX/scripts" -type f -name '*.sh' -exec chmod +x {} +
    done_skip; ((SKIP++)) || true; return 0
  fi
  mkdir -p "$INSTALL_PREFIX"
  if cp -r "$SCRIPT_DIR/scripts" "$SCRIPT_DIR/config" "$SCRIPT_DIR/requirements.txt" "$INSTALL_PREFIX/" \
     && find "$INSTALL_PREFIX/scripts" -type f -name '*.sh' -exec chmod +x {} +; then
    done_ok; ((PASS++)) || true
  else
    done_fail; ((FAIL++)) || true
  fi
}

# ──────────────── ALIASES & HELPERS ──────────────────────────
install_helpers() {
  section "Shell Aliases & Helpers"
  # Same file the Docker image uses, so both environments behave alike.
  if cp "$SCRIPT_DIR/docker/hackkit.sh" "$ALIAS_FILE"; then
    chmod 644 "$ALIAS_FILE"
    success "Aliases installed → $ALIAS_FILE"
  else
    error "Could not write $ALIAS_FILE"
  fi
}

# ──────────────────── ZSH + Oh-My-Zsh ───────────────────────
install_zsh() {
  section "ZSH + Oh-My-Zsh"
  install_apt "zsh"
  progress "oh-my-zsh"
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    done_skip; ((SKIP++)) || true
  else
    step_result run_quiet sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended
  fi

  progress "zsh-autosuggestions"
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    step_result run_quiet git clone --depth 1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "$zsh_custom/plugins/zsh-autosuggestions"
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
  # Distro package instead of "curl get.docker.com | bash": signed by the
  # distro, no remote script run as root. (The old pipe also sent the script
  # into the log file, so bash ran nothing while reporting success.)
  if run_quiet apt-get install -y docker.io; then
    run_quiet apt-get install -y docker-compose-v2 \
      || run_quiet apt-get install -y docker-compose-plugin \
      || run_quiet apt-get install -y docker-compose || true
    run_quiet systemctl enable --now docker || true
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
  PASS=$((PASS + BS_PASS)); FAIL=$((FAIL + BS_FAIL)); SKIP=$((SKIP + BS_SKIP))
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
    (( ${#BS_FAILED_ITEMS[@]} > 0 )) && warn "Failed: ${BS_FAILED_ITEMS[*]}"
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

  if ! $ASSUME_YES; then
    echo -e "${YELLOW}${BOLD}  This will install 80+ tools. Continue? [Y/n]:${RESET} \c"
    read -r ans
    [[ "${ans,,}" =~ ^(n|no)$ ]] && { echo "Aborted."; exit 0; }
  fi

  install_base_packages
  install_go
  setup_python_env
  install_go_tools
  install_feroxbuster
  install_python_tools
  setup_nuclei_templates
  setup_wordlists
  setup_resolvers
  install_scripts
  install_helpers
  install_zsh
  setup_tmux
  install_docker
  cleanup
  print_summary
}

main "$@"
