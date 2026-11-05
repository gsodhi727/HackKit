# ============================================================
#  HackKit — All-in-One Bug Bounty Docker Container
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Build   : docker build -t hackkit .
#  Run     : docker run -it --rm hackkit
# ============================================================
FROM ubuntu:22.04

LABEL maintainer="gsodhi727 <github.com/gsodhi727>" \
      description="HackKit — Bug Bounty Toolkit Installer · 80+ tools" \
      version="2.0.0"

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Go paths ──────────────────────────────────────────────────
ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=$PATH:/usr/local/go/bin:/root/go/bin:/root/.hackkit-venv/bin
# Let Go fetch a newer toolchain when a tool's go.mod needs one.
ENV GOTOOLCHAIN=auto

# ── Tool dirs ─────────────────────────────────────────────────
ENV TOOLS=/root/tools
ENV WORDLISTS=/root/wordlists
ENV HACKKIT_VENV=/root/.hackkit-venv

# 1 = fail the build if any single tool fails to install.
ARG HK_STRICT=0
ENV HK_STRICT=$HK_STRICT

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ─────────────────────────────────────────────────────────────
# Stage 1: System packages
#   Core packages must install (the build fails otherwise).
#   Extras are tried one by one, so one missing package can't take
#   the whole list down with it. (Before, "chromium-browser" — a snap
#   stub that can't install in Docker — sat in the same apt line with
#   "|| true", hiding any failure of the entire list.)
# ─────────────────────────────────────────────────────────────
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git unzip tar jq make gcc g++ build-essential \
      python3 python3-pip python3-venv python3-dev \
      libssl-dev libffi-dev libpcap-dev libxml2 libxml2-dev libxslt1-dev \
      dnsutils whois netcat-traditional traceroute net-tools iputils-ping \
      nmap tmux vim nano zsh \
 && for pkg in masscan sqlmap nikto wfuzz dirb hydra john hashcat \
               dnsmap dnstracer theharvester wireshark-common tshark ruby-full; do \
      apt-get install -y --no-install-recommends "$pkg" \
        || echo "WARN: optional package '$pkg' not available — skipped"; \
    done \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ─────────────────────────────────────────────────────────────
# Stage 2-5: Go, Go tools, massdns, feroxbuster, Python
#   All done by scripts/lib/bootstrap.sh from the lists in config/,
#   the same code install.sh and update.sh use. Each step prints a
#   DONE/SKIP/FAIL line per tool, so failures show in the build log
#   instead of being swallowed by "2>/dev/null || true".
# ─────────────────────────────────────────────────────────────
COPY scripts/lib/bootstrap.sh /opt/hackkit/scripts/lib/bootstrap.sh
COPY config/ /opt/hackkit/config/
COPY requirements.txt /opt/hackkit/requirements.txt

RUN HK_STRICT=1 bash /opt/hackkit/scripts/lib/bootstrap.sh go
RUN bash /opt/hackkit/scripts/lib/bootstrap.sh go-tools massdns \
 && go clean -cache -modcache
RUN bash /opt/hackkit/scripts/lib/bootstrap.sh feroxbuster
RUN bash /opt/hackkit/scripts/lib/bootstrap.sh python-venv python-repos \
 && rm -rf /root/.cache/pip

# ─────────────────────────────────────────────────────────────
# Stage 6: Wordlists
# ─────────────────────────────────────────────────────────────
RUN mkdir -p "$WORDLISTS" \
 && git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$WORDLISTS/SecLists" \
 && rm -rf "$WORDLISTS/SecLists/.git" \
 && { curl -fsSL "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
        -o "$WORDLISTS/best-dns-wordlist.txt" || echo "WARN: best-dns-wordlist download failed"; } \
 && { curl -fsSL "https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt" \
        -o "$WORDLISTS/commonspeak2.txt" || echo "WARN: commonspeak2 download failed"; } \
 && { curl -fsSL "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
        -o "$WORDLISTS/resolvers.txt" || echo "WARN: resolvers download failed"; }

# ─────────────────────────────────────────────────────────────
# Stage 7: Nuclei templates
# ─────────────────────────────────────────────────────────────
RUN nuclei -update-templates -silent || echo "WARN: nuclei template download failed — run 'update' inside the container"

# ─────────────────────────────────────────────────────────────
# Stage 8: Shell environment
# ─────────────────────────────────────────────────────────────
COPY install.sh /opt/hackkit/
COPY scripts/ /opt/hackkit/scripts/
RUN chmod +x /opt/hackkit/install.sh && find /opt/hackkit/scripts -type f -name "*.sh" -exec chmod +x {} +

# ── Container aliases, entrypoint & tmux ──
COPY docker/hackkit.sh /etc/profile.d/hackkit.sh
COPY docker/entrypoint.sh /usr/local/bin/hackkit-entrypoint
RUN chmod 644 /etc/profile.d/hackkit.sh && chmod 755 /usr/local/bin/hackkit-entrypoint

COPY docker/.tmux.conf /root/.tmux.conf

# Oh-My-Zsh (cloned directly rather than piping a remote install script into sh)
RUN git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /root/.oh-my-zsh \
 && cp /root/.oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc \
 && git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Configure .zshrc
RUN echo 'source /etc/profile.d/hackkit.sh' >> /root/.zshrc \
 && sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' /root/.zshrc \
 && sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions z colored-man-pages)/' /root/.zshrc

# ─────────────────────────────────────────────────────────────
# MOTD
# ─────────────────────────────────────────────────────────────
RUN cat > /etc/motd <<'MOTD'

  ██╗  ██╗ █████╗  ██████╗██╗  ██╗██╗  ██╗██╗████████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██║ ██╔╝██║╚══██╔══╝
  ███████║███████║██║     █████╔╝ █████╔╝ ██║   ██║
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔═██╗ ██║   ██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗██║  ██╗██║   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝

  Bug Bounty Toolkit  ·  by gsodhi727  ·  github.com/gsodhi727/hackkit
  Type 'tools' to list tool dirs, 'wl' to list wordlists.
  Start with:  recon -d target.com   |   xss -d target.com   |   fuzz -u https://target.com
  Keep tools fresh with:  update

MOTD

# ─────────────────────────────────────────────────────────────
# Final
# ─────────────────────────────────────────────────────────────
WORKDIR /root/workspace

# No arguments → MOTD + zsh. With arguments → run them (see docker/entrypoint.sh).
ENTRYPOINT ["/usr/local/bin/hackkit-entrypoint"]
