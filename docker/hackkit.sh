# shellcheck shell=sh
# ── HackKit Shell Environment (loaded in every login session) ──
# Installed to /etc/profile.d/hackkit.sh by install.sh and the Dockerfile.
# Keep this POSIX sh: /etc/profile sources it with sh/dash, not bash.
export WORDLISTS="$HOME/wordlists"
export TOOLS="$HOME/tools"
export HACKKIT_VENV="$HOME/.hackkit-venv"
export GOROOT=/usr/local/go
export GOPATH="$HOME/go"
case ":$PATH:" in
  *":$GOPATH/bin:"*) ;;
  *) export PATH="$PATH:$GOROOT/bin:$GOPATH/bin:$HACKKIT_VENV/bin" ;;
esac

# Python venv shortcut
alias hkenv='. "$HACKKIT_VENV/bin/activate"'

# List installed tools / wordlists
alias tools='ls "$TOOLS"'
alias wl='ls "$WORDLISTS"'

# ── Recon ──────────────────────────────────────────────────────
alias nmap-quick='nmap -sCV -T4 --open'
alias nmap-full='nmap -p- -sCV --open -T4'
alias naabu-quick='naabu -top-ports 1000 -silent'
alias httpx-probe='httpx -silent -status-code -title -tech-detect'
# (function names can't contain "-" in POSIX sh, so alias to an underscore name)
sub_enum() { subfinder -d "$1" | anew subs.txt | httpx -silent | anew alive.txt; }
alias sub-enum='sub_enum'

# ── Fuzzing ────────────────────────────────────────────────────
alias ffuf-dir='ffuf -c -u FUZZ -w "$WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt"'
alias ffuf-vhost='ffuf -c -u http://TARGET -H "Host: FUZZ.TARGET" -w "$WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-110000.txt"'
alias ferox-dir='feroxbuster -u'

# ── Scanning ───────────────────────────────────────────────────
alias nuclei-fast='nuclei -severity critical,high -silent'
alias nuclei-all='nuclei -severity critical,high,medium,low -silent'

# ── Script shortcuts ───────────────────────────────────────────
alias recon='bash /opt/hackkit/scripts/recon/recon.sh'
alias xss='bash /opt/hackkit/scripts/exploitation/xss-hunt.sh'
alias fuzz='bash /opt/hackkit/scripts/fuzzing/fuzz.sh'
alias hk-update='bash /opt/hackkit/scripts/utilities/update.sh'
alias update='hk-update'
