#!/usr/bin/env bash
# ============================================================
#  HackKit — Bug Bounty Toolkit Installer
#  Version : 2.1.0
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
FEROX_VERSION="2.11.0"          # pinned; see install_feroxbuster
PYTHON_VENV="$HOME/.hackkit-venv"
ALIAS_FILE="/etc/profile.d/hackkit.sh"
PASS=0; FAIL=0; SKIP=0

# Repo root (so we can find manifests/ and bin/ regardless of CWD)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_MANIFEST="$REPO_DIR/manifests/go-tools.txt"

# Resume / reproducibility state
STATE_DIR="$HOME/.hackkit"
STATE_FILE="$STATE_DIR/install-state"   # one completed step name per line
LOCK_FILE="$STATE_DIR/tools.lock"       # resolved tool versions after install
RESUME=false                            # --resume: skip steps already marked done
FORCE=false                             # --force: redo steps even if marked done
ASSUME_YES=false                        # -y / --yes: no prompt

# ──────────────────────── ARG PARSING ────────────────────────
for arg in "$@"; do
  case "$arg" in
    --resume)      RESUME=true ;;
    --force)       FORCE=true ;;
    -y|--yes)      ASSUME_YES=true ;;
    -h|--help)
      cat <<USAGE
HackKit installer
  sudo bash install.sh [options]

Options:
  --resume    Skip steps already completed in a previous run (idempotent re-run)
  --force     Re-run every step even if previously completed
  -y, --yes   Do not prompt for confirmation
  -h, --help  Show this help
USAGE
      exit 0 ;;
  esac
done

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
  echo -e "${CYAN}${BOLD}  │    Bug Bounty Toolkit Installer  v2.1  ·  by gsodhi727            │${RESET}"
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

# ── Retry a command with exponential backoff (for flaky networks) ──
# Usage: retry <attempts> <cmd> [args...]
retry() {
  local attempts="$1"; shift
  local n=1 delay=2
  while true; do
    if "$@" >> "$LOG_FILE" 2>&1; then return 0; fi
    if (( n >= attempts )); then
      log "[RETRY] giving up after $n attempts: $*"
      return 1
    fi
    log "[RETRY] attempt $n failed, retrying in ${delay}s: $*"
    sleep "$delay"
    n=$(( n + 1 )); delay=$(( delay * 2 ))
  done
}

# ── Step-level state (idempotency / --resume) ─────────────────
init_state() { mkdir -p "$STATE_DIR"; touch "$STATE_FILE"; }

step_done() { grep -qxF "$1" "$STATE_FILE" 2>/dev/null; }

mark_done() { step_done "$1" || echo "$1" >> "$STATE_FILE"; }

# do_step <name> <function>: run a step unless --resume says it's already done.
# A step is marked "done" only if it added no new failures, so --resume
# re-runs steps that had failures (already-installed items skip quickly).
# --force re-runs everything regardless.
do_step() {
  local name="$1"; local fn="$2"
  if $RESUME && ! $FORCE && step_done "$name"; then
    section "$name"
    info "Already completed in a previous run — skipping (use --force to redo)."
    return 0
  fi
  local fail_before=$FAIL
  "$fn" || true
  if (( FAIL == fail_before )); then
    mark_done "$name"
  else
    warn "Step '$name' had failures — not marked complete (will retry on --resume)."
  fi
}

# ── Record a resolved tool version into the lockfile ──────────
record_lock() {
  local name="$1" value="$2"
  [[ -z "$value" ]] && return 0
  mkdir -p "$STATE_DIR"
  # replace any existing line for this tool, then append
  if [[ -f "$LOCK_FILE" ]]; then
    grep -vE "^${name}[[:space:]]" "$LOCK_FILE" > "$LOCK_FILE.tmp" 2>/dev/null || true
    mv "$LOCK_FILE.tmp" "$LOCK_FILE"
  fi
  printf '%s\t%s\n' "$name" "$value" >> "$LOCK_FILE"
}

# Resolve the module version baked into an installed Go binary.
go_installed_version() {
  local bin; bin="$(command -v "$1" 2>/dev/null)" || return 0
  [[ -n "$bin" ]] || return 0
  go version -m "$bin" 2>/dev/null | awk '$1=="mod"{print $3; exit}'
}

# ── Go tool via `go install` ──────────────────────────────────
# Usage: install_go_tool <name> <module> [version]   (version default: latest)
install_go_tool() {
  local name="$1"
  local pkg="$2"
  local ver="${3:-latest}"
  progress "$name"
  if command -v "$name" &>/dev/null && ! $FORCE; then
    done_skip; ((SKIP++)) || true
    record_lock "$name" "$(go_installed_version "$name")"
    return 0
  fi
  if retry 3 go install -v "$pkg@$ver"; then
    done_ok; ((PASS++)) || true
    record_lock "$name" "$(go_installed_version "$name")"
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
  if retry 3 git clone --depth 1 "$repo" "$dest"; then
    if [[ -f "$dest/requirements.txt" ]]; then
      retry 2 "$PYTHON_VENV/bin/pip" install -r "$dest/requirements.txt" --quiet
    fi
    record_lock "$name" "$(git -C "$dest" rev-parse --short HEAD 2>/dev/null)"
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

  # Fetch the official SHA256 for this exact file from go.dev's signed
  # download manifest, so we verify integrity instead of trusting the
  # transport alone (no more unverified tarball).
  local expected_sha
  expected_sha=$(curl -fsSL "https://go.dev/dl/?mode=json&include=all" 2>>"$LOG_FILE" \
    | jq -r --arg f "$tarball" '.[].files[] | select(.filename==$f) | .sha256' 2>/dev/null \
    | head -n1)

  if ! retry 3 curl -fsSL "$url" -o "/tmp/$tarball"; then
    done_fail; error "Go download failed — Go tools will be skipped."; return 1
  fi

  if [[ -n "$expected_sha" && "$expected_sha" != "null" ]]; then
    local actual_sha
    actual_sha=$(sha256sum "/tmp/$tarball" | awk '{print $1}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      done_fail
      error "Go checksum MISMATCH — refusing to install."
      error "  expected: $expected_sha"
      error "  actual:   $actual_sha"
      rm -f "/tmp/$tarball"
      return 1
    fi
    log "[OK] Go tarball sha256 verified: $actual_sha"
  else
    warn "Could not fetch official Go checksum — proceeding without verification."
  fi

  if run_quiet tar -C /usr/local -xzf "/tmp/$tarball"; then
    ln -sf /usr/local/go/bin/go    /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    rm -f "/tmp/$tarball"
    record_lock "go" "$GO_VERSION"
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

  if [[ ! -f "$GO_MANIFEST" ]]; then
    error "Go tools manifest not found: $GO_MANIFEST"
    warn  "Did you clone the full repo? Skipping Go tools."
    return 1
  fi

  info "Reading tool list from ${BOLD}manifests/go-tools.txt${RESET}"
  # Read name/module/version from the manifest (skip blanks & comments).
  while read -r name module version _rest; do
    [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue
    [[ -z "${module:-}" ]] && continue
    install_go_tool "$name" "$module" "${version:-latest}"
  done < "$GO_MANIFEST"
}

# ──────────────── FEROXBUSTER (Rust binary) ──────────────────
# Pinned to FEROX_VERSION and verified against the GitHub-published
# asset digest (sha256) — no more `releases/latest` / unverified binary.
install_feroxbuster() {
  section "Feroxbuster (Rust) — v$FEROX_VERSION"
  progress "feroxbuster"
  if command -v feroxbuster &>/dev/null && ! $FORCE; then
    done_skip; ((SKIP++)) || true
    record_lock "feroxbuster" "v$FEROX_VERSION"
    return 0
  fi

  local arch; arch=$(uname -m)
  local target="x86_64"
  [[ "$arch" == "aarch64" ]] && target="aarch64"
  [[ "$arch" == "armv7l"  ]] && target="armv7"

  # Query the PINNED release tag (not "latest") for the matching asset.
  local meta asset_name url digest
  meta=$(curl -fsSL "https://api.github.com/repos/epi052/feroxbuster/releases/tags/v${FEROX_VERSION}" 2>>"$LOG_FILE" || true)
  asset_name=$(jq -r --arg t "$target" \
    '.assets[] | select(.name | test($t) and test("linux") and endswith(".zip")) | .name' \
    <<<"$meta" 2>/dev/null | head -n1)
  url=$(jq -r --arg n "$asset_name" '.assets[] | select(.name==$n) | .browser_download_url' <<<"$meta" 2>/dev/null | head -n1)
  digest=$(jq -r --arg n "$asset_name" '.assets[] | select(.name==$n) | .digest // empty' <<<"$meta" 2>/dev/null | head -n1)

  if [[ -z "$url" || "$url" == "null" ]]; then
    done_fail; error "Could not locate feroxbuster v$FEROX_VERSION asset for $target."; ((FAIL++)) || true; return 1
  fi

  local tmp_dir; tmp_dir=$(mktemp -d)
  if ! retry 3 curl -fsSL "$url" -o "$tmp_dir/feroxbuster.zip"; then
    rm -rf "$tmp_dir"; done_fail; error "feroxbuster download failed."; ((FAIL++)) || true; return 1
  fi

  # Verify against GitHub's published digest (format: sha256:<hex>)
  if [[ -n "$digest" && "$digest" == sha256:* ]]; then
    local expected="${digest#sha256:}"
    local actual; actual=$(sha256sum "$tmp_dir/feroxbuster.zip" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
      done_fail
      error "feroxbuster checksum MISMATCH — refusing to install."
      error "  expected: $expected"
      error "  actual:   $actual"
      rm -rf "$tmp_dir"; ((FAIL++)) || true; return 1
    fi
    log "[OK] feroxbuster sha256 verified: $actual"
  else
    warn "No published digest for feroxbuster asset — proceeding without verification."
  fi

  if run_quiet unzip -q "$tmp_dir/feroxbuster.zip" -d "$tmp_dir" && \
     run_quiet mv "$tmp_dir/feroxbuster" /usr/local/bin/feroxbuster && \
     run_quiet chmod +x /usr/local/bin/feroxbuster; then
    rm -rf "$tmp_dir"; record_lock "feroxbuster" "v$FEROX_VERSION"; done_ok; ((PASS++)) || true
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

# ──────────────── HACKKIT LAUNCHER COMMAND ──────────────────
# Installs the global `hackkit` command so the whole toolkit can
# be started just by typing its name.
install_launcher() {
  section "HackKit Launcher Command"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local launcher="$SCRIPT_DIR/bin/hackkit"
  progress "hackkit command"
  if [[ ! -f "$launcher" ]]; then
    done_fail; error "bin/hackkit not found — did you clone the full repo?"; return 1
  fi
  chmod +x "$launcher"
  # Symlink into PATH; symlink is resolved by the launcher itself.
  ln -sf "$launcher" /usr/local/bin/hackkit
  # Record the repo location for the launcher to find scripts.
  grep -q 'HACKKIT_HOME' "$ALIAS_FILE" 2>/dev/null || \
    echo "export HACKKIT_HOME=\"$SCRIPT_DIR\"" >> "$ALIAS_FILE"
  done_ok; ((PASS++)) || true
  success "Launcher ready → type ${BOLD}hackkit${RESET} to start"
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

  # Prefer the distro's packaged docker.io (signed via apt) over a
  # piped remote script. Fall back to the official script, but download
  # it to disk first so it can be inspected/logged rather than run blind.
  if run_quiet apt-get install -y docker.io && command -v docker &>/dev/null; then
    run_quiet systemctl enable docker || true
    run_quiet systemctl start  docker || true
    done_ok; ((PASS++)) || true
    return 0
  fi

  local script="/tmp/get-docker-$$.sh"
  if retry 3 curl -fsSL https://get.docker.com -o "$script"; then
    log "[INFO] Fetched Docker install script to $script (run with: sh $script)"
    if run_quiet sh "$script"; then
      run_quiet systemctl enable docker || true
      run_quiet systemctl start  docker || true
      rm -f "$script"; done_ok; ((PASS++)) || true
    else
      rm -f "$script"; done_fail; ((FAIL++)) || true
    fi
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
  echo -e "  ${BOLD}Lock file   :${RESET} $LOCK_FILE  ${DIM}(resolved versions)${RESET}"
  echo -e "  ${BOLD}Log file    :${RESET} $LOG_FILE"
  if [[ $FAIL -gt 0 ]]; then
    echo -e "  ${DIM}Re-run just the failed steps with:  sudo bash install.sh --resume${RESET}"
  fi
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
  echo -e "${GREEN}${BOLD}  ▶ Then just type:  hackkit${RESET}   ${DIM}(opens the control center)${RESET}"
  echo -e "${DIM}     hackkit doctor   — verify everything installed${RESET}"
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ──────────────────────── MAIN ────────────────────────────────
main() {
  clear
  banner
  check_root
  detect_os
  init_state

  if $RESUME; then
    info "Resume mode: steps completed in a previous run will be skipped."
  fi
  if $FORCE; then
    warn "Force mode: every step will be re-run."
  fi

  if ! $ASSUME_YES; then
    echo -e "${YELLOW}${BOLD}  This will install 80+ tools. Continue? [Y/n]:${RESET} \c"
    read -r ans
    [[ "${ans,,}" =~ ^(n|no)$ ]] && { echo "Aborted."; exit 0; }
  fi

  do_step "System Dependencies"   install_base_packages
  do_step "Go Language Setup"     install_go
  do_step "Python3 Environment"   setup_python_env
  do_step "Go-Based Tools"        install_go_tools
  do_step "Feroxbuster"           install_feroxbuster
  do_step "Python Tools"          install_python_tools
  do_step "Nuclei Templates"      setup_nuclei_templates
  do_step "Wordlists"             setup_wordlists
  do_step "DNS Resolvers"         setup_resolvers
  do_step "Shell Aliases"         install_helpers
  do_step "HackKit Launcher"      install_launcher
  do_step "ZSH + Oh-My-Zsh"       install_zsh
  do_step "Tmux Configuration"    setup_tmux
  do_step "Docker"                install_docker
  do_step "Cleanup"               cleanup
  print_summary
}

main "$@"
