#!/usr/bin/env bash
# ============================================================
#  HackKit — Smart Setup Launcher
#  Author  : gsodhi727  (github.com/gsodhi727/hackkit)
#  Usage   : bash setup.sh
#
#  Presents two installation methods:
#    [1] Direct install on this machine  (runs install.sh)
#    [2] Docker container                (builds & runs image)
# ============================================================
set -euo pipefail

# ──────────────────────── COLOURS ────────────────────────────
RED='\033[0;31m';   GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';  CYAN='\033[0;36m';   BOLD='\033[1m'
DIM='\033[2m';      RESET='\033[0m'

# ──────────────────────── BANNER ─────────────────────────────
clear
cat <<'EOF'

  ██╗  ██╗ █████╗  ██████╗██╗  ██╗██╗  ██╗██╗████████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██║ ██╔╝██║╚══██╔══╝
  ███████║███████║██║     █████╔╝ █████╔╝ ██║   ██║
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔═██╗ ██║   ██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗██║  ██╗██║   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝

EOF
echo -e "${CYAN}${BOLD}  ┌──────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}${BOLD}  │   Bug Bounty Toolkit  v2.0  ·  by gsodhi727                      │${RESET}"
echo -e "${CYAN}${BOLD}  │   github.com/gsodhi727/hackkit    ·  80+ tools ready              │${RESET}"
echo -e "${CYAN}${BOLD}  └──────────────────────────────────────────────────────────────┘${RESET}"
echo ""

# ──────────────── ENVIRONMENT DETECTION ──────────────────────
DOCKER_OK=false
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_OK=true
fi

ROOT_OK=false
if [[ $EUID -eq 0 ]]; then
  ROOT_OK=true
fi

# ──────────────────────── MENU ───────────────────────────────
echo -e "${BOLD}  Choose your installation method:${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}[1]${RESET}  ${BOLD}Direct Install${RESET}  — Install all tools directly on this machine"
echo -e "       ${DIM}Best for: VPS, dedicated VM, Kali/Ubuntu/Debian system${RESET}"
echo ""
echo -e "  ${BLUE}${BOLD}[2]${RESET}  ${BOLD}Docker Container${RESET} — Run everything inside an isolated container"
echo -e "       ${DIM}Best for: any machine with Docker; no system changes${RESET}"

if $DOCKER_OK; then
  echo -e "       ${GREEN}✓ Docker is available on this system${RESET}"
else
  echo -e "       ${YELLOW}⚠ Docker not found — will install it first${RESET}"
fi

echo ""
echo -e "  ${DIM}[q]  Quit${RESET}"
echo ""
echo -ne "${CYAN}${BOLD}  Your choice [1/2/q]: ${RESET}"
read -r CHOICE

echo ""

# ════════════════════════════════════════════════════════════
# OPTION 1 — DIRECT INSTALL
# ════════════════════════════════════════════════════════════
direct_install() {
  echo -e "${GREEN}${BOLD}  ▸ Direct Installation selected${RESET}"
  echo ""

  if ! $ROOT_OK; then
    echo -e "${RED}  [!] Direct install requires root privileges.${RESET}"
    echo -e "${YELLOW}  Run: ${BOLD}sudo bash setup.sh${RESET}"
    exit 1
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  INSTALLER="$SCRIPT_DIR/install.sh"

  if [[ ! -f "$INSTALLER" ]]; then
    echo -e "${RED}  [!] install.sh not found at $INSTALLER${RESET}"
    echo -e "  Make sure you cloned the full repository."
    exit 1
  fi

  chmod +x "$INSTALLER"
  bash "$INSTALLER"
}

# ════════════════════════════════════════════════════════════
# OPTION 2 — DOCKER
# ════════════════════════════════════════════════════════════
docker_install() {
  echo -e "${BLUE}${BOLD}  ▸ Docker Installation selected${RESET}"
  echo ""
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # ── Install Docker if missing ─────────────────────────────
  if ! $DOCKER_OK; then
    echo -e "${YELLOW}  [!] Docker not found. Installing Docker Engine...${RESET}"
    if ! command -v curl &>/dev/null; then
      apt-get update -y &>/dev/null && apt-get install -y curl &>/dev/null
    fi
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker --quiet 2>/dev/null || true
    systemctl start  docker --quiet 2>/dev/null || true
    echo -e "${GREEN}  [✓] Docker installed${RESET}"
    echo ""
  fi

  # ── Sub-menu: how to run Docker ───────────────────────────
  echo -e "${BOLD}  Docker options:${RESET}"
  echo ""
  echo -e "  ${GREEN}${BOLD}[a]${RESET}  ${BOLD}Build & Run now${RESET}      — Build the image and launch a shell immediately"
  echo -e "  ${BLUE}${BOLD}[b]${RESET}  ${BOLD}Build image only${RESET}     — Build the image (tag: hackkit) without launching"
  echo -e "  ${CYAN}${BOLD}[c]${RESET}  ${BOLD}Docker Compose${RESET}       — Use docker compose (recommended, persistent volumes)"
  echo -e "  ${YELLOW}${BOLD}[d]${RESET}  ${BOLD}Pull prebuilt image${RESET} — Pull gsodhi727/hackkit from Docker Hub (fastest)"
  echo ""
  echo -ne "${CYAN}${BOLD}  Docker option [a/b/c/d]: ${RESET}"
  read -r DCHOICE
  echo ""

  # ── Workspace dir ────────────────────────────────────────
  mkdir -p "$SCRIPT_DIR/workspace"

  case "${DCHOICE,,}" in
    a)
      echo -e "${BLUE}  [*] Building HackKit Docker image...${RESET}"
      echo -e "  ${DIM}This may take 10–20 minutes on first run.${RESET}"
      echo ""
      docker build -t hackkit "$SCRIPT_DIR"
      echo ""
      echo -e "${GREEN}  [✓] Build complete. Launching shell...${RESET}"
      echo ""
      docker run -it --rm \
        --hostname hackkit \
        --cap-add NET_RAW \
        --cap-add NET_ADMIN \
        --network host \
        -v "$SCRIPT_DIR/workspace:/root/workspace" \
        hackkit
      ;;
    b)
      echo -e "${BLUE}  [*] Building HackKit Docker image (no launch)...${RESET}"
      echo -e "  ${DIM}This may take 10–20 minutes on first run.${RESET}"
      echo ""
      docker build -t hackkit "$SCRIPT_DIR"
      echo ""
      echo -e "${GREEN}  [✓] Image 'hackkit' built successfully!${RESET}"
      echo ""
      echo -e "  To launch later:"
      echo -e "  ${BOLD}  docker run -it --rm --cap-add NET_RAW --network host -v \$(pwd)/workspace:/root/workspace hackkit${RESET}"
      ;;
    c)
      if ! command -v "docker" &>/dev/null || ! docker compose version &>/dev/null 2>&1; then
        echo -e "${YELLOW}  [!] Docker Compose not available. Falling back to docker run.${RESET}"
        docker_install
        return
      fi
      echo -e "${BLUE}  [*] Using Docker Compose...${RESET}"
      echo ""
      docker compose -f "$SCRIPT_DIR/docker-compose.yml" build
      echo ""
      echo -e "${GREEN}  [✓] Build complete. Launching shell...${RESET}"
      echo ""
      docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm hackkit
      ;;
    d)
      echo -e "${BLUE}  [*] Pulling gsodhi727/hackkit from Docker Hub...${RESET}"
      if docker pull gsodhi727/hackkit:latest; then
        echo ""
        echo -e "${GREEN}  [✓] Image pulled. Launching shell...${RESET}"
        echo ""
        docker run -it --rm \
          --hostname hackkit \
          --cap-add NET_RAW \
          --cap-add NET_ADMIN \
          --network host \
          -v "$SCRIPT_DIR/workspace:/root/workspace" \
          gsodhi727/hackkit:latest
      else
        echo -e "${YELLOW}  [!] Pull failed (image may not be published yet).${RESET}"
        echo -e "  Falling back to local build..."
        DCHOICE="a"
        docker_install
      fi
      ;;
    *)
      echo -e "${RED}  Invalid choice. Exiting.${RESET}"
      exit 1
      ;;
  esac
}

# ══════════════════════════════════════════
# DISPATCH
# ══════════════════════════════════════════
case "${CHOICE,,}" in
  1) direct_install ;;
  2) docker_install ;;
  q|quit|exit)
    echo -e "${DIM}  Bye! Run bash setup.sh whenever you're ready.${RESET}"
    exit 0
    ;;
  *)
    echo -e "${RED}  Invalid choice '${CHOICE}'. Run bash setup.sh again.${RESET}"
    exit 1
    ;;
esac
