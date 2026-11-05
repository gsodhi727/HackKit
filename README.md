# ⚡ HackKit — Bug Bounty Toolkit Installer

<p align="center">
  <img src="https://img.shields.io/badge/Tools-80%2B-blueviolet?style=for-the-badge&logo=linux"/>
  <img src="https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20Kali-orange?style=for-the-badge&logo=ubuntu"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker"/>
  <img src="https://img.shields.io/badge/Go-1.22-00ADD8?style=for-the-badge&logo=go"/>
  <img src="https://img.shields.io/badge/Python-3.x-3776AB?style=for-the-badge&logo=python"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Author-guru-ff69b4?style=for-the-badge"/>
</p>

> **One command** to deploy a fully equipped bug bounty environment —  
> install directly on your machine **or** spin up an isolated Docker container.  
> 80+ tools, wordlists, resolvers, ZSH, Tmux, automated pipelines — all included.

---

## 📋 Prerequisites

- **OS:** Ubuntu 22.04 LTS, Debian 12, or Kali Linux 2024
- **Python:** Python 3.8+ (Virtual Environment recommended)
- **System Tools:** `nmap`, `sqlmap`, `git`, `curl` (automatically installed via `install.sh`)

---

## 🚀 Quick Start — Pick Your Method

```bash
# 1. Clone the repo
git clone https://github.com/gsodhi727/hackkit.git /opt/hackkit
cd /opt/hackkit

# 2. Run the smart launcher — it will ask you what to do
bash setup.sh
```

The **`setup.sh`** launcher presents an interactive menu:

```
  Choose your installation method:

  [1]  Direct Install   — Install all tools directly on this machine
       Best for: VPS, dedicated VM, Kali / Ubuntu / Debian

  [2]  Docker Container — Run everything inside an isolated container
       Best for: any machine with Docker; zero system changes
```

---

## 🎛️ The `hackkit` Command — start it by name

Once installed (direct **or** Docker), the whole toolkit is launched just by
typing its name:

```bash
hackkit
```

This opens the **Control Center** — an interactive menu that drives every
pipeline (recon, fuzzing, XSS), checks your install, lists tools, and updates
templates. You can also call any action directly:

```bash
hackkit recon  -d target.com        # full recon pipeline
hackkit fuzz   -u https://target.com -m dir
hackkit xss    -d target.com
hackkit doctor                      # ✅ health-check: is everything installed & on PATH?
hackkit tools                       # list installed tools
hackkit update                      # update tools + nuclei templates
hackkit help
```

> **Tip:** run `hackkit doctor` right after installing. It verifies the core
> tools resolve on your `PATH`, confirms SecLists / resolvers / nuclei-templates
> are present, and tells you exactly what to fix if something is missing.

---

## 🖥️ Method 1 — Direct Install (VPS / Linux)

Install all 80+ tools natively on your system.  
Everything is configured: Go, Python venv, ZSH, Oh-My-Zsh, Tmux, wordlists, aliases.

### One-liner

```bash
sudo apt-get update -y && sudo apt-get install git curl -y \
  && git clone https://github.com/gsodhi727/hackkit.git /opt/hackkit \
  && cd /opt/hackkit \
  && sudo bash setup.sh
```

When the menu appears, press **`1`** then Enter.

### Or run the installer directly

```bash
sudo bash install.sh
```

### What it does

| Step | Action |
|------|--------|
| 1 | Updates apt & installs system packages (`nmap`, `john`, `sqlmap`, etc.) |
| 2 | Installs Go 1.22 + sets `GOPATH` |
| 3 | Creates isolated Python venv at `~/.hackkit-venv` |
| 4 | Installs 50+ Go tools via `go install` |
| 5 | Installs Feroxbuster (Rust binary) |
| 6 | Clones 15+ Python tools, installs their requirements |
| 7 | Downloads Nuclei templates (official + community) |
| 8 | Downloads SecLists, Assetnote, Commonspeak2 wordlists |
| 9 | Downloads public DNS resolvers |
| 10 | Installs ZSH + Oh-My-Zsh + zsh-autosuggestions |
| 11 | Configures Tmux |
| 12 | Installs shell aliases in `/etc/profile.d/hackkit.sh` |

> Tested on **Ubuntu 22.04 LTS**, **Debian 12**, **Kali Linux 2024**

---

## 🐳 Method 2 — Docker Container

Run the entire toolkit inside a container — no changes to your host system.  
Works on **Windows (WSL2 / Docker Desktop)**, **macOS**, and **Linux**.

### One-liner (build + run)

```bash
git clone https://github.com/gsodhi727/hackkit.git /opt/hackkit
cd /opt/hackkit
bash setup.sh    # choose option 2 → option a
```

### Docker sub-options (shown inside setup.sh)

```
  [a]  Build & Run now      — Build the image and launch a shell immediately
  [b]  Build image only     — Build the image (tag: hackkit) without launching
  [c]  Docker Compose       — Use docker compose (recommended, persistent volumes)
  [d]  Pull prebuilt image  — Pull gsodhi727/hackkit from Docker Hub (fastest)
```

### Manual Docker commands

```bash
# Build the image
docker build -t hackkit .

# Launch interactive shell
docker run -it --rm \
  --hostname hackkit \
  --cap-add NET_RAW \
  --cap-add NET_ADMIN \
  --network host \
  -v $(pwd)/workspace:/root/workspace \
  hackkit

# Build & launch with Docker Compose (persistent volumes)
docker compose run --rm hackkit

# Pull from Docker Hub (no build needed)
docker pull gsodhi727/hackkit && docker run -it --rm --network host gsodhi727/hackkit
```

### Persistent volumes (Docker Compose)

Docker Compose stores these in named volumes — they survive container restarts:

| Volume | Contains |
|--------|----------|
| `hackkit-wordlists` | SecLists, DNS lists, resolvers |
| `hackkit-gobin` | Go tool binaries |
| `hackkit-tools` | Cloned Python tools |
| `hackkit-nuclei` | Nuclei templates |

Your **`workspace/`** folder is bind-mounted from the host, so all recon results stay on your machine even after the container stops.

---

## 📊 Side-by-Side Comparison

| Feature | Direct Install | Docker |
|---------|:--------------:|:------:|
| Works on any OS | Linux/Kali only | ✅ Win/Mac/Linux |
| Persistent tools | ✅ | ✅ (named volumes) |
| Modifies host system | ✅ yes | ❌ no |
| Network access (nmap, etc.) | ✅ full | ✅ `--network host` |
| Startup time | Fast (tools already there) | ~5s (after first build) |
| First-time setup | 10–20 min | 10–20 min (build) |
| Rootless operation | needs sudo | after build |
| Works offline | ✅ | ✅ (after build) |

---

## 🛠️ Tools Included (80+)

### 🔍 Subdomain & Recon

| Tool | Description |
|------|-------------|
| `subfinder` | Fast passive subdomain enumeration |
| `assetfinder` | Finds related domains and assets |
| `amass` | In-depth DNS enumeration (OWASP) |
| `chaos` | ProjectDiscovery chaos dataset |
| `crobat` | Rapid7 Sonar search |
| `gotator` | Permutation-based subdomain generator |
| `alterx` | Subdomain alteration & permutation |
| `dnsx` | Fast DNS resolver & prober |
| `puredns` | Recursive DNS resolver (wildcard filter) |
| `shuffledns` | DNS bruteforce wrapper |

### 🌐 HTTP Probing & Crawling

| Tool | Description |
|------|-------------|
| `httpx` | Fast multi-purpose HTTP toolkit |
| `httprobe` | Probes live HTTP/HTTPS servers |
| `katana` | Next-gen web crawler |
| `gospider` | Fast web spider |
| `hakrawler` | Simple, fast crawler |
| `gowitness` | Web screenshot utility |
| `naabu` | Fast port scanner |
| `tlsx` | TLS certificate grabber |
| `cdncheck` | CDN provider detector |
| `asnmap` | ASN to IP range mapping |

### 🕵️ URL & Wayback Machine

| Tool | Description |
|------|-------------|
| `gau` | URLs from AlienVault, Wayback, etc. |
| `waybackurls` | Pull URLs from Wayback Machine |
| `waymore` | Advanced Wayback fetcher + filtering |
| `galer` | URLs from page source |
| `unfurl` | Extract URL components |

### 💥 Fuzzing & Scanning

| Tool | Description |
|------|-------------|
| `ffuf` | Fast web fuzzer |
| `gobuster` | Directory, DNS, VHost busting |
| `feroxbuster` | ⚡ Recursive content discovery (Rust) |
| `nuclei` | Template-based vulnerability scanner |
| `interactsh-client` | OOB interaction client |
| `dirsearch` | Web path discovery |

### 🔐 XSS & Injection

| Tool | Description |
|------|-------------|
| `dalfox` | XSS scanner & analyzer |
| `kxss` | Reflected XSS finder |
| `Gxss` | XSS reflection checker |
| `bxss` | Blind XSS injector |
| `XSStrike` | Advanced XSS suite |
| `ghauri` | Advanced SQL injection |
| `sqlmap` | Classic SQL injection |

### 🔎 OSINT & Secrets

| Tool | Description |
|------|-------------|
| `github-subdomains` | Subdomains in GitHub repos |
| `socialhunter` | Social media OSINT |
| `trufflehog` | Secrets in git history (v3) |
| `SecretFinder` | API keys from JS files |
| `LinkFinder` | Endpoints from JS files |
| `GitHacker` | Exposed `.git` exploiter |
| `theharvester` | Email, subdomain collector |

### 🧩 Takeover & Bypass

| Tool | Description |
|------|-------------|
| `subzy` | Subdomain takeover checker |
| `subjack` | Hostile takeover tool |
| `dnstake` | DNS takeover checker |
| `corsy` | CORS misconfiguration scanner |
| `byp4xx` | Bypass 40x responses |
| `403fuzzer` | 403 bypass fuzzer |
| `wafw00f` | WAF detection |

### 🔧 SSRF & Parameters

| Tool | Description |
|------|-------------|
| `SSRFmap` | SSRF payload automation |
| `ParamSpider` | Parameter discovery |
| `arjun` | HTTP parameter discovery |

### ⚙️ Utilities

| Tool | Description |
|------|-------------|
| `anew` | Append unique lines |
| `qsreplace` | Replace query string values |
| `gron` | Make JSON greppable |
| `mapcidr` | Subnet/CIDR utility |
| `notify` | Slack/Discord/Telegram alerts |
| `cent` | Community nuclei templates |
| `uro` | URL deduplication |

### 🐚 System Tools

| Tool | Description |
|------|-------------|
| `nmap` | Network scanner |
| `masscan` | Fast port scanner |
| `john` | Password cracker |
| `hydra` | Brute-force tool |
| `aircrack-ng` | Wireless auditing |
| `nikto` | Web server scanner |
| `sqlmap` | SQL injection |

---

## 🚀 Automation Scripts

> The easiest entry point is the **`hackkit`** command (see above). The raw
> scripts below are what it calls under the hood, and can still be run directly.

```bash
# Full recon pipeline
bash scripts/recon/recon.sh -d target.com
bash scripts/recon/recon.sh -d target.com -o ./results --skip-screenshots

# XSS hunting
bash scripts/exploitation/xss-hunt.sh -d target.com
bash scripts/exploitation/xss-hunt.sh -d target.com -b https://your.xss.ht

# Fuzzing
bash scripts/fuzzing/fuzz.sh -u https://target.com -m dir
bash scripts/fuzzing/fuzz.sh -u https://target.com -m vhost
bash scripts/fuzzing/fuzz.sh -u https://target.com -m param

# Update all tools
sudo bash scripts/utilities/update.sh
```

Inside Docker, these are available as short aliases:
```bash
recon -d target.com
xss   -d target.com
fuzz  -u https://target.com
update
```

---

## 🔤 Built-in Aliases

```bash
hkenv         # activate Python venv
sub-enum      # subfinder | httpx pipeline
nmap-quick    # nmap -sCV -T4 --open
nmap-full     # nmap -p- full scan
ffuf-dir      # directory fuzzing
ffuf-vhost    # virtual host fuzzing
ferox-dir     # feroxbuster
naabu-quick   # top 1000 ports
httpx-probe   # status + title + tech
nuclei-fast   # critical & high only
nuclei-all    # all severities
tools         # list tool dirs
wl            # list wordlists
```

---

## 📂 Project Structure

```
hackkit/
├── setup.sh             ← ⭐ Start here — smart menu launcher
├── install.sh           ← Direct installer (Method 1)
├── bin/
│   └── hackkit          ← 🎛️ Global command — `hackkit` opens the Control Center
├── Dockerfile           ← Docker image definition (Method 2)
├── docker-compose.yml   ← Docker Compose with volumes
├── requirements.txt     ← Python dependencies
├── scripts/
│   ├── recon/           ← Recon automation pipeline (recon.sh)
│   ├── exploitation/    ← XSS discovery pipeline (xss-hunt.sh)
│   ├── fuzzing/         ← Multi-mode fuzzer (fuzz.sh)
│   └── utilities/       ← One-command tool updater (update.sh)
├── docker/
│   ├── hackkit.sh       ← Aliases for container sessions
│   └── .tmux.conf       ← Tmux config
└── workspace/           ← Your results (git-ignored)
```

---

## ⚠️ Legal Disclaimer

> This toolkit is for **authorized security testing and bug bounty programs only**.  
> Unauthorized use against systems you do not own or have permission to test is **illegal**.  
> The author accepts no responsibility for misuse.

---

## 🤝 Contributing

PRs welcome! To add a tool:
- **Go tool** → add `install_go_tool "name" "github.com/..."` in `install.sh`
- **Python tool** → add `install_python_tool "name" "https://github.com/..."` in `install.sh`
- **Dockerfile** → add the corresponding `RUN go install ...` or `git clone` line

---

## 📄 License

[MIT](LICENSE) — by **gsodhi727** · free to fork, customize, and share.
