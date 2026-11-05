#!/usr/bin/env bash
# ============================================================
#  HackKit — helpers shared by the recon / fuzz / xss scripts
#  Source it:  source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# ============================================================

# shellcheck disable=SC2034  # colours are used by the scripts that source this
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

# Tools live in Go's bin dir and the HackKit venv; make sure they're found
# even when the script runs outside a login shell (cron, docker exec, sudo).
export GOPATH="${GOPATH:-$HOME/go}"
export WORDLISTS="${WORDLISTS:-$HOME/wordlists}"
export HACKKIT_VENV="${HACKKIT_VENV:-$HOME/.hackkit-venv}"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin:$HACKKIT_VENV/bin"

log()  { echo -e "${DIM}$(date '+%H:%M:%S')${RESET}  $*"; }
step() { echo -e "\n${CYAN}${BOLD}▸ $*${RESET}"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*" >&2; }
die()  { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

hk_have() { command -v "$1" >/dev/null 2>&1; }

# Abort if any of the listed tools is missing.
hk_require() {
  local t missing=()
  for t in "$@"; do hk_have "$t" || missing+=("$t"); done
  (( ${#missing[@]} == 0 )) || die "Missing required tool(s): ${missing[*]} — run install.sh or use the Docker image."
}

# Option parsing: make sure "-d" is followed by a value, not another flag.
hk_need_arg() {
  [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || die "Option $1 needs a value"
}

# RFC 1035-style hostname: labels of [a-z0-9-], no leading/trailing hyphen.
hk_valid_domain() {
  [[ ${#1} -le 253 && "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

# http(s)://host[:port][/path] — host is a domain, IPv4 or localhost.
hk_valid_url() {
  [[ "$1" =~ ^https?://([A-Za-z0-9.-]+)(:[0-9]{1,5})?(/[^[:space:]\;\|\`\$\<\>]*)?$ ]]
}

hk_valid_int() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= ${2:-1} && $1 <= ${3:-100000} )); }

# Line count that is 0 (not an error) for missing files.
hk_count() { if [[ -s "$1" ]]; then wc -l <"$1" | tr -d ' '; else echo 0; fi; }

# Run a step, keep its stderr in a log, and warn (don't hide) on failure.
#   hk_run <name> <command...>
# Needs HK_LOG_DIR set by the caller.
hk_run() {
  local name="$1"; shift
  if "$@" 2>>"$HK_LOG_DIR/$name.log"; then
    return 0
  fi
  warn "$name failed — see $HK_LOG_DIR/$name.log"
  return 1
}
