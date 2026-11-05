#!/usr/bin/env bash
# Stand-in for the real recon tools, used by tests/smoke.sh.
# Dispatches on the name it was called as (symlinked per tool) and
# writes small, predictable output so the pipelines can be checked
# end to end without network access or real targets.
name="$(basename "$0")"
out=""; args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in -o|-w|--output|-oJ) out="${args[$((i + 1))]}" ;; esac
done
emit() { if [[ -n "$out" ]]; then printf '%s\n' "$@" >"$out"; else printf '%s\n' "$@"; fi; }

case "$name" in
  subfinder)   emit a.example.com b.example.com ;;
  assetfinder) emit c.example.com unrelated.other.com ;;     # must be filtered out
  dnsx|puredns) emit a.example.com b.example.com ;;
  httpx)       emit "https://a.example.com [200] [Home] [nginx]" "https://b.example.com [301] [] []" ;;
  naabu)       echo "naabu: simulated failure" >&2; exit 1 ;;  # exercise the warning path
  gau)         emit "https://a.example.com/search?q=1" "https://a.example.com/about" ;;
  waybackurls) emit "https://b.example.com/item?id=2" ;;
  katana)      emit "https://a.example.com/login" ;;
  uro|kxss|Gxss) cat ;;
  nuclei)
    # Fail if nuclei is handed httpx's decorated lines instead of bare URLs.
    while read -r l; do [[ "$l" == *" "* ]] && { echo "bad input: $l" >&2; exit 3; }; done <"${args[1]}"
    emit "[info] https://a.example.com" ;;
  subzy|gowitness) emit "" ;;
  dalfox)      emit "[POC] https://a.example.com/search?q=<x>" ;;
  ffuf|feroxbuster|arjun) emit "{}" ;;
  *)           echo "fake-tool: unknown $name" >&2; exit 1 ;;
esac
