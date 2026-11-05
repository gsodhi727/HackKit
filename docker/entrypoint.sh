#!/usr/bin/env bash
# ============================================================
#  HackKit — container entrypoint
#    docker run -it hackkit                      → MOTD + zsh
#    docker run hackkit recon -d target.com      → run a pipeline
#    docker run hackkit scripts/recon/recon.sh -d target.com
#    docker run hackkit nmap -h                  → any command
#  (The old entrypoint was "bash -c '...; exec zsh -l'", which
#   silently ignored every argument, so the documented
#   "docker compose run --rm hackkit scripts/..." never worked.)
# ============================================================
set -e
# shellcheck source=hackkit.sh
. /etc/profile.d/hackkit.sh

if [[ $# -eq 0 ]]; then
  cat /etc/motd
  exec zsh -l
fi

case "$1" in
  recon)  shift; exec bash /opt/hackkit/scripts/recon/recon.sh "$@" ;;
  xss)    shift; exec bash /opt/hackkit/scripts/exploitation/xss-hunt.sh "$@" ;;
  fuzz)   shift; exec bash /opt/hackkit/scripts/fuzzing/fuzz.sh "$@" ;;
  update) shift; exec bash /opt/hackkit/scripts/utilities/update.sh "$@" ;;
  scripts/*.sh)
    if [[ -f "/opt/hackkit/$1" ]]; then
      script="/opt/hackkit/$1"; shift
      exec bash "$script" "$@"
    fi
    ;;
esac
exec "$@"
