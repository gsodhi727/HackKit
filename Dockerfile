# ============================================================
#  HackKit — All-in-One Bug Bounty Docker Container
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Build   : docker build -t hackkit .
#  Run     : docker run -it --rm hackkit
# ============================================================
FROM ubuntu:22.04

LABEL maintainer="guru <github.com/guru>" \
      description="HackKit — Bug Bounty Toolkit Installer · 80+ tools" \
      version="2.0.0"

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Go paths ──────────────────────────────────────────────────
ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=$PATH:/usr/local/go/bin:/root/go/bin:/root/tools/bin
ENV GO_VERSION=1.22.4

# ── Tool dirs ─────────────────────────────────────────────────
ENV TOOLS=/root/tools
ENV WORDLISTS=/root/wordlists
ENV HACKKIT_VENV=/root/.hackkit-venv

# ─────────────────────────────────────────────────────────────
# Stage 1: System packages
# ─────────────────────────────────────────────────────────────
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl wget git unzip tar jq make gcc g++ build-essential \
    python3 python3-pip python3-venv python3-dev \
    libssl-dev libffi-dev libpcap-dev \
    nmap masscan sqlmap nikto wfuzz \
    dirb hydra john hashcat \
    dnsutils whois netcat-traditional traceroute \
    dnsmap dnstracer \
    theharvester \
    wireshark-common tshark \
    ruby-full \
    libxml2 libxml2-dev libxslt-dev \
    net-tools iputils-ping \
    tmux vim nano zsh \
    software-properties-common apt-transport-https ca-certificates \
    chromium-browser || true \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ─────────────────────────────────────────────────────────────
# Stage 2: Go installation
# ─────────────────────────────────────────────────────────────
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
      x86_64)  GO_ARCH="amd64" ;; \
      aarch64) GO_ARCH="arm64" ;; \
      armv7l)  GO_ARCH="armv6l" ;; \
      *)       GO_ARCH="amd64" ;; \
    esac; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" \
         -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    ln -sf /usr/local/go/bin/go    /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# ─────────────────────────────────────────────────────────────
# Stage 3: Go-based tools
# ─────────────────────────────────────────────────────────────
RUN go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest 2>/dev/null || true && \
    go install github.com/tomnomnom/assetfinder@latest                        2>/dev/null || true && \
    go install github.com/projectdiscovery/chaos-client/cmd/chaos@latest      2>/dev/null || true && \
    go install github.com/Josue87/gotator@latest                               2>/dev/null || true && \
    go install github.com/projectdiscovery/alterx/cmd/alterx@latest           2>/dev/null || true && \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest             2>/dev/null || true && \
    go install github.com/tomnomnom/httprobe@latest                           2>/dev/null || true && \
    go install github.com/projectdiscovery/katana/cmd/katana@latest           2>/dev/null || true && \
    go install github.com/jaeles-project/gospider@latest                      2>/dev/null || true && \
    go install github.com/hakluke/hakrawler@latest                            2>/dev/null || true && \
    go install github.com/lc/gau/v2/cmd/gau@latest                           2>/dev/null || true && \
    go install github.com/tomnomnom/waybackurls@latest                        2>/dev/null || true && \
    go install github.com/dwisiswant0/galer@latest                            2>/dev/null || true && \
    go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest               2>/dev/null || true && \
    go install github.com/d3mondev/puredns/v2@latest                          2>/dev/null || true && \
    go install github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest   2>/dev/null || true && \
    go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest          2>/dev/null || true && \
    go install github.com/projectdiscovery/tlsx/cmd/tlsx@latest               2>/dev/null || true && \
    go install github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest       2>/dev/null || true && \
    go install github.com/projectdiscovery/asnmap/cmd/asnmap@latest           2>/dev/null || true && \
    go install github.com/ffuf/ffuf/v2@latest                                 2>/dev/null || true && \
    go install github.com/OJ/gobuster/v3@latest                               2>/dev/null || true && \
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest        2>/dev/null || true && \
    go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest 2>/dev/null || true && \
    go install github.com/sensepost/gowitness@latest                          2>/dev/null || true && \
    go install github.com/hahwul/dalfox/v2@latest                             2>/dev/null || true && \
    go install github.com/Emoe/kxss@latest                                    2>/dev/null || true && \
    go install github.com/KathanP19/Gxss@latest                               2>/dev/null || true && \
    go install github.com/ethicalhackingplayground/bxss@latest                2>/dev/null || true && \
    go install github.com/PentestPad/subzy@latest                             2>/dev/null || true && \
    go install github.com/pwnesia/dnstake@latest                              2>/dev/null || true && \
    go install github.com/haccer/subjack@latest                               2>/dev/null || true && \
    go install github.com/gwen001/github-subdomains@latest                    2>/dev/null || true && \
    go install github.com/utkusen/socialhunter@latest                         2>/dev/null || true && \
    go install github.com/trufflesecurity/trufflehog/v3@latest                2>/dev/null || true && \
    go install github.com/tomnomnom/anew@latest                               2>/dev/null || true && \
    go install github.com/tomnomnom/qsreplace@latest                          2>/dev/null || true && \
    go install github.com/tomnomnom/gron@latest                               2>/dev/null || true && \
    go install github.com/tomnomnom/fff@latest                                2>/dev/null || true && \
    go install github.com/tomnomnom/unfurl@latest                             2>/dev/null || true && \
    go install github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest         2>/dev/null || true && \
    go install github.com/projectdiscovery/notify/cmd/notify@latest           2>/dev/null || true && \
    go install github.com/xm1k3/cent@latest                                   2>/dev/null || true && \
    go install github.com/dwisiswant0/cf-check@latest                         2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# Stage 4: Feroxbuster (Rust binary)
# ─────────────────────────────────────────────────────────────
RUN set -eux; \
    FEROX_URL=$(curl -fsSL \
      "https://api.github.com/repos/epi052/feroxbuster/releases/latest" \
      | jq -r '.assets[] | select(.name | test("linux-x86_64.zip")) | .browser_download_url' \
    ); \
    mkdir -p /tmp/ferox && \
    curl -fsSL "$FEROX_URL" -o /tmp/ferox/feroxbuster.zip && \
    unzip -q /tmp/ferox/feroxbuster.zip -d /tmp/ferox && \
    mv /tmp/ferox/feroxbuster /usr/local/bin/feroxbuster && \
    chmod +x /usr/local/bin/feroxbuster && \
    rm -rf /tmp/ferox

# ─────────────────────────────────────────────────────────────
# Stage 5: Python environment + tools
# ─────────────────────────────────────────────────────────────
RUN python3 -m venv $HACKKIT_VENV && \
    $HACKKIT_VENV/bin/pip install --upgrade pip setuptools wheel --quiet && \
    $HACKKIT_VENV/bin/pip install \
      requests httpx aiohttp dnspython beautifulsoup4 lxml \
      jsbeautifier wafw00f colorama tabulate tqdm \
      holehe sherlock wafw00f arjun uro \
      --quiet

# Clone Python tools
RUN mkdir -p $TOOLS && \
    git clone --depth 1 https://github.com/s0md3v/Arjun             $TOOLS/arjun         && \
    git clone --depth 1 https://github.com/WangYihang/GitHacker      $TOOLS/GitHacker     && \
    git clone --depth 1 https://github.com/m4ll0k/SecretFinder       $TOOLS/SecretFinder  && \
    git clone --depth 1 https://github.com/GerbenJavado/LinkFinder    $TOOLS/LinkFinder    && \
    git clone --depth 1 https://github.com/devanshbatham/ParamSpider  $TOOLS/ParamSpider   && \
    git clone --depth 1 https://github.com/maurosoria/dirsearch       $TOOLS/dirsearch     && \
    git clone --depth 1 https://github.com/s0md3v/Corsy              $TOOLS/corsy         && \
    git clone --depth 1 https://github.com/s0md3v/XSStrike            $TOOLS/xsstrike      && \
    git clone --depth 1 https://github.com/lobuhi/byp4xx              $TOOLS/byp4xx        && \
    git clone --depth 1 https://github.com/swisskyrepo/SSRFmap        $TOOLS/SSRFmap       && \
    git clone --depth 1 https://github.com/eslam3kl/SQLiDetector      $TOOLS/SQLiDetector  && \
    git clone --depth 1 https://github.com/r0oth3x49/ghauri           $TOOLS/ghauri        && \
    # Install requirements for each tool
    for d in $TOOLS/*/; do \
      [ -f "$d/requirements.txt" ] && \
        $HACKKIT_VENV/bin/pip install -r "$d/requirements.txt" --quiet || true; \
    done

# ─────────────────────────────────────────────────────────────
# Stage 6: Wordlists
# ─────────────────────────────────────────────────────────────
RUN mkdir -p $WORDLISTS && \
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git $WORDLISTS/SecLists && \
    curl -fsSL "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
         -o $WORDLISTS/best-dns-wordlist.txt || true && \
    curl -fsSL "https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt" \
         -o $WORDLISTS/commonspeak2.txt || true && \
    curl -fsSL "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
         -o $WORDLISTS/resolvers.txt || true

# ─────────────────────────────────────────────────────────────
# Stage 7: Nuclei templates
# ─────────────────────────────────────────────────────────────
RUN nuclei -update-templates -silent 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# Stage 8: Shell environment
# ─────────────────────────────────────────────────────────────
COPY install.sh /opt/hackkit/
COPY scripts/ /opt/hackkit/scripts/
RUN chmod +x /opt/hackkit/install.sh && find /opt/hackkit/scripts -type f -name "*.sh" -exec chmod +x {} +

# ── 15. Container Aliases & Tmux ──
COPY docker/hackkit.sh /etc/profile.d/hackkit.sh
RUN chmod +x /etc/profile.d/hackkit.sh

COPY docker/.tmux.conf /root/.tmux.conf

# Oh-My-Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended 2>/dev/null || true && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true

# Configure .zshrc
RUN echo 'source /etc/profile.d/hackkit.sh' >> /root/.zshrc && \
    sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/' /root/.zshrc 2>/dev/null || true && \
    sed -i 's/plugins=.*/plugins=(git zsh-autosuggestions z colored-man-pages)/' /root/.zshrc 2>/dev/null || true

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
  Run 'bash /opt/hackkit/scripts/recon/recon.sh -d target.com' to start!

MOTD

# ─────────────────────────────────────────────────────────────
# Final
# ─────────────────────────────────────────────────────────────
WORKDIR /root/workspace

# Print MOTD and start zsh on entry
ENTRYPOINT ["/bin/bash", "-c", "cat /etc/motd; exec zsh -l"]
