#!/usr/bin/env bash
# ============================================================
#  HackKit — Shared component installer
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#
#  One implementation used by install.sh, the Dockerfile and
#  scripts/utilities/update.sh, so the three can't drift apart.
#
#  Usage   : bash bootstrap.sh <component>...
#  Components:
#    go                 Go toolchain (skipped if a usable Go exists)
#    go-tools           Go tools from config/go-tools.txt (skip installed)
#    go-tools-update    Re-install every Go tool at @latest
#    massdns            Build massdns from source (needed by puredns)
#    feroxbuster        Install / update the feroxbuster binary
#    python-venv        Create the HackKit venv + install requirements.txt
#    python-repos       Clone tools from config/python-repos.txt
#    python-repos-update  git pull every cloned tool
#    all                Everything above (install mode)
#
#  Env:
#    HK_LOG     file that receives command output   (default /dev/null)
#    HK_STRICT  1 = exit non-zero if any item failed (default 0)
#
#  Can also be sourced; it then only defines functions and the
#  BS_PASS / BS_FAIL / BS_SKIP counters.
# ============================================================

HK_ROOT="${HK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HK_CONFIG="${HK_CONFIG:-$HK_ROOT/config}"
HK_LOG="${HK_LOG:-/dev/null}"
HK_TOOLS_DIR="${TOOLS:-$HOME/tools}"
HK_VENV="${HACKKIT_VENV:-$HOME/.hackkit-venv}"
# Used only if go.dev cannot be asked for the current release.
GO_FALLBACK_VERSION="${GO_FALLBACK_VERSION:-1.25.0}"
# Oldest Go that supports automatic toolchain switching (GOTOOLCHAIN).
GO_MIN_MINOR=21

BS_PASS=${BS_PASS:-0}; BS_FAIL=${BS_FAIL:-0}; BS_SKIP=${BS_SKIP:-0}
BS_FAILED_ITEMS=()

export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"
# Let an older local Go download the toolchain a module asks for,
# instead of failing on "requires go >= 1.xx".
export GOTOOLCHAIN=auto

_bs_line() { printf '  %-34s %b\n' "$1" "$2"; }
_ok()      { _bs_line "$1" "\033[0;32m[DONE]\033[0m"; BS_PASS=$((BS_PASS + 1)); }
_skip()    { _bs_line "$1" "\033[2m[SKIP]\033[0m";    BS_SKIP=$((BS_SKIP + 1)); }
_fail()    { _bs_line "$1" "\033[0;31m[FAIL]\033[0m"; BS_FAIL=$((BS_FAIL + 1)); BS_FAILED_ITEMS+=("$1"); }
_q()       { "$@" >>"$HK_LOG" 2>&1; }

# Lines of a config file without comments/blank lines.
_bs_entries() { grep -vE '^[[:space:]]*(#|$)' "$1"; }

hk_go_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armv7l|armv6l) echo armv6l ;;
    *)             echo unsupported ;;
  esac
}

_go_usable() {
  command -v go >/dev/null 2>&1 || return 1
  local v minor
  v=$(go env GOVERSION 2>/dev/null || go version | awk '{print $3}')
  minor=$(sed -E 's/^go1\.([0-9]+).*/\1/' <<<"$v")
  [[ "$minor" =~ ^[0-9]+$ ]] && (( minor >= GO_MIN_MINOR ))
}

hk_install_go() {
  local label="Go toolchain"
  if _go_usable; then _skip "$label ($(go env GOVERSION))"; return 0; fi

  local arch version tmp
  arch=$(hk_go_arch)
  if [[ "$arch" == unsupported ]]; then _fail "$label (arch $(uname -m))"; return 1; fi

  version=$(curl -fsSL 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n1 || true)
  [[ "$version" =~ ^go[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || version="go${GO_FALLBACK_VERSION}"

  tmp=$(mktemp -d)
  if _q curl -fsSL "https://go.dev/dl/${version}.linux-${arch}.tar.gz" -o "$tmp/go.tgz" \
     && rm -rf /usr/local/go \
     && _q tar -C /usr/local -xzf "$tmp/go.tgz"; then
    ln -sf /usr/local/go/bin/go    /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    _ok "$label ($version)"
  else
    _fail "$label ($version)"
  fi
  rm -rf "$tmp"
}

# $1 = install | update
hk_go_tools() {
  local mode="${1:-install}" name pkg
  if ! command -v go >/dev/null 2>&1; then
    _fail "Go tools (go not installed)"; return 1
  fi
  while read -r name pkg _; do
    if [[ "$mode" == install ]] && command -v "$name" >/dev/null 2>&1; then
      _skip "$name"; continue
    fi
    if _q go install "${pkg}@latest"; then _ok "$name"; else _fail "$name"; fi
  done < <(_bs_entries "$HK_CONFIG/go-tools.txt")
}

hk_install_massdns() {
  if command -v massdns >/dev/null 2>&1; then _skip "massdns"; return 0; fi
  local tmp; tmp=$(mktemp -d)
  if _q git clone --depth 1 https://github.com/blechschmidt/massdns "$tmp/massdns" \
     && _q make -C "$tmp/massdns" \
     && install -m 0755 "$tmp/massdns/bin/massdns" /usr/local/bin/massdns; then
    _ok "massdns"
  else
    _fail "massdns"
  fi
  rm -rf "$tmp"
}

# $1 = install | update
hk_install_feroxbuster() {
  local mode="${1:-install}" asset tmp
  if [[ "$mode" == install ]] && command -v feroxbuster >/dev/null 2>&1; then
    _skip "feroxbuster"; return 0
  fi
  # The "latest/download" redirect needs no GitHub API call (no rate limit)
  # and picks the binary for this CPU instead of always x86_64.
  case "$(uname -m)" in
    x86_64|amd64)  asset="x86_64-linux-feroxbuster.zip" ;;
    aarch64|arm64) asset="aarch64-linux-feroxbuster.zip" ;;
    armv7l)        asset="armv7-linux-feroxbuster.zip" ;;
    *)             asset="" ;;
  esac
  tmp=$(mktemp -d)
  if [[ -n "$asset" ]] \
     && _q curl -fsSL "https://github.com/epi052/feroxbuster/releases/latest/download/$asset" -o "$tmp/f.zip" \
     && _q unzip -o -q "$tmp/f.zip" -d "$tmp" \
     && install -m 0755 "$tmp/feroxbuster" /usr/local/bin/feroxbuster; then
    _ok "feroxbuster"
  elif command -v apt-get >/dev/null 2>&1 && _q apt-get install -y feroxbuster; then
    _ok "feroxbuster (apt)"
  else
    _fail "feroxbuster"
  fi
  rm -rf "$tmp"
}

hk_python_venv() {
  if [[ ! -x "$HK_VENV/bin/python" ]]; then
    if _q python3 -m venv "$HK_VENV"; then _ok "Python venv"; else _fail "Python venv"; return 1; fi
  else
    _skip "Python venv"
  fi
  _q "$HK_VENV/bin/pip" install --upgrade pip setuptools wheel || true
  if _q "$HK_VENV/bin/pip" install --upgrade -r "$HK_ROOT/requirements.txt"; then
    _ok "Python packages (requirements.txt)"
  else
    # One broken package must not block the rest: retry one by one.
    local pkg
    while read -r pkg; do
      if _q "$HK_VENV/bin/pip" install --upgrade "$pkg"; then _ok "pip: $pkg"; else _fail "pip: $pkg"; fi
    done < <(_bs_entries "$HK_ROOT/requirements.txt")
  fi
}

# $1 = install | update
hk_python_repos() {
  local mode="${1:-install}" name url dest
  mkdir -p "$HK_TOOLS_DIR"
  while read -r name url _; do
    dest="$HK_TOOLS_DIR/$name"
    if [[ -d "$dest/.git" ]]; then
      if [[ "$mode" == install ]]; then _skip "$name"; continue; fi
      if _q git -C "$dest" pull --ff-only; then _ok "$name"; else _fail "$name"; continue; fi
    elif _q git clone --depth 1 "$url" "$dest"; then
      _ok "$name"
    else
      _fail "$name"; continue
    fi
    if [[ -f "$dest/requirements.txt" && -x "$HK_VENV/bin/pip" ]]; then
      _q "$HK_VENV/bin/pip" install -r "$dest/requirements.txt" \
        || _bs_line "  ↳ $name requirements" "\033[1;33m[WARN]\033[0m"
    fi
  done < <(_bs_entries "$HK_CONFIG/python-repos.txt")
}

hk_bootstrap_summary() {
  echo ""
  echo "  bootstrap: $BS_PASS done, $BS_SKIP skipped, $BS_FAIL failed"
  if (( BS_FAIL > 0 )); then
    echo "  failed: ${BS_FAILED_ITEMS[*]}"
    if [[ "$HK_LOG" != /dev/null ]]; then echo "  details: $HK_LOG"; fi
  fi
}

hk_bootstrap_main() {
  set -uo pipefail
  if [[ $# -eq 0 ]]; then
    sed -n '2,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    return 2
  fi
  local c
  for c in "$@"; do
    case "$c" in
      go)                  hk_install_go ;;
      go-tools)            hk_go_tools install ;;
      go-tools-update)     hk_go_tools update ;;
      massdns)             hk_install_massdns ;;
      feroxbuster)         hk_install_feroxbuster update ;;
      python-venv)         hk_python_venv ;;
      python-repos)        hk_python_repos install ;;
      python-repos-update) hk_python_repos update ;;
      all)
        hk_install_go; hk_go_tools install; hk_install_massdns
        hk_install_feroxbuster install; hk_python_venv; hk_python_repos install ;;
      *) echo "Unknown component: $c" >&2; return 2 ;;
    esac || true
  done
  hk_bootstrap_summary
  if [[ "${HK_STRICT:-0}" == 1 ]] && (( BS_FAIL > 0 )); then return 1; fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  hk_bootstrap_main "$@"
  exit $?
fi
