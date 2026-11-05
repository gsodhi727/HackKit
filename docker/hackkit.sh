# ── HackKit Shell Environment (loaded in every session) ───────
export WORDLISTS="$HOME/wordlists"
export TOOLS="$HOME/tools"
export HACKKIT_VENV="$HOME/.hackkit-venv"
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HACKKIT_VENV/bin

# Python venv shortcut
alias hkenv="source $HACKKIT_VENV/bin/activate"

# List installed tools / wordlists
alias tools='ls $TOOLS'
alias wl='ls $WORDLISTS'

# ── Recon ──────────────────────────────────────────────────────
alias nmap-quick='nmap -sCV -T4 --open'
alias nmap-full='nmap -p- -sCV --open -T4'
alias naabu-quick='naabu -top-ports 1000 -silent'
alias httpx-probe='httpx -silent -status-code -title -tech-detect'
sub-enum() { subfinder -d "$1" | anew subs.txt | httpx -silent | anew alive.txt; }

# ── Fuzzing ────────────────────────────────────────────────────
alias ffuf-dir='ffuf -c -u FUZZ -w $WORDLISTS/SecLists/Discovery/Web-Content/raft-medium-directories.txt'
alias ffuf-vhost='ffuf -c -u http://TARGET -H "Host: FUZZ.TARGET" -w $WORDLISTS/SecLists/Discovery/DNS/subdomains-top1million-110000.txt'
alias ferox-dir='feroxbuster -u'

# ── Scanning ───────────────────────────────────────────────────
alias nuclei-fast='nuclei -severity critical,high -silent'
alias nuclei-all='nuclei -severity critical,high,medium,low -silent'

# ── HackKit launcher ───────────────────────────────────────────
export HACKKIT_HOME="/opt/hackkit"
# `hackkit` is a real command on PATH (/usr/local/bin/hackkit);
# these aliases remain for direct access to individual pipelines.
alias recon='bash /opt/hackkit/scripts/recon/recon.sh'
alias xss='bash /opt/hackkit/scripts/exploitation/xss-hunt.sh'
alias fuzz='bash /opt/hackkit/scripts/fuzzing/fuzz.sh'
alias update='bash /opt/hackkit/scripts/utilities/update.sh'
