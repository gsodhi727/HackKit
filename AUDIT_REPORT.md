# HackKit — Comprehensive Security & Architecture Audit Report

This report provides a detailed evaluation of the **HackKit** repository, acting as a Senior Cybersecurity Engineer, Python Architect, DevSecOps Specialist, and Open-Source Maintainer. It includes an analysis of the tool's purpose, folder structure, coding practices, dependency models, cybersecurity risks (including critical secrets exposure), feature enhancement suggestions, a proposed new directory layout, and a final scoring scorecard.

---

## 📋 PROJECT SUMMARY

### Purpose and Functionality
**HackKit** is an automated deployment system and workflow orchestration framework designed for bug bounty hunters and penetration testers. It aims to solve the tedious process of setting up a hacking workstation by consolidating base system utilities, compiler runtimes, wordlists, shell enhancements, and security tooling into a single deployable unit.

Currently, the tool provides:
1. **Interactive Bootstrap Launcher (`setup.sh`)**: Prompts users to install dependencies natively on the host or launch a containerized shell.
2. **Native Dependency Installer (`install.sh`)**: Performs system upgrades, installs Go (v1.22.4), configures a Python 3 virtual environment, clones 17+ Python-based tools, compiles 40+ Go-based tools, pulls Rust-based binaries (`feroxbuster`), downloads SecLists/Assetnote wordlists, configures custom shell aliases, sets up Oh-My-Zsh with syntax suggestions, and configures standard Tmux mouse control/pane-splitting behaviors.
3. **Container Orchestration (`Dockerfile`, `docker-compose.yml`)**: Packages all dependencies inside an isolated Ubuntu 22.04 container. Uses volumes to persist large wordlists, Go binaries, and custom templates while mounting the target workspace directory dynamically.
4. **Execution Workflows (`scripts/`)**: Includes simple shell-based execution pipelines:
   - `scripts/recon/recon.sh`: Automated subdomain discovery, live host resolution, port scanning, screenshotting, nuclei vulnerability template scanning, and subdomain takeover analysis.
   - `scripts/fuzzing/fuzz.sh`: Target parameter mapping, virtual host discovery, and recursive directory fuzzing.
   - `scripts/exploitation/xss-hunt.sh`: Automated XSS parameters scanning, reflection probing, and automated browser payload testing via DalFox.
   - `scripts/utilities/update.sh`: Clones the latest updates and pulls releases for all integrated tools.

### Target Users
- **Bug Bounty Hunters**: Individuals looking to deploy a standardized security framework on remote VPS nodes or cloud instances quickly.
- **Red Teamers & Penetration Testers**: Consultants needing clean, reproducible, and easily disposable target workstations on-demand.
- **DevSecOps Engineers**: Engineers seeking to understand how to bundle and orchestrate multi-tool open-source pipelines.

### Architecture Style
- **Monolithic Shell-Wrapped Pipeline ("Bash Glue")**: 
  The project is built around standard UNIX streams. It has no centralized daemon, database layer, REST endpoint, or queue processor. Tools are executed sequentially or in parallel using background jobs (`&`), with results read and written to flat text files. Downstream tasks read the written files to chain executions together.

---

## 🏗️ CURRENT ARCHITECTURE

```
                                +-------------------+
                                |    User Input     |
                                +---------+---------+
                                          |
                                          v
                                +-------------------+
                                |     setup.sh      |
                                +----+-----------+--+
                                     |           |
                     [Direct Native] |           | [Docker Container]
                                     v           v
                            +------------+   +------------+
                            | install.sh |   | Dockerfile |
                            +-----+------+   +-----+------+
                                  |                |
                                  +--------+-------+
                                           |
                                           v
                              +--------------------------+
                              | Global Hacking Workspace |
                              | (Go/Python Venv/Aliases) |
                              +------------+-------------+
                                           |
                    +----------------------+----------------------+
                    |                      |                      |
                    v                      v                      v
            +---------------+      +---------------+      +---------------+
            |   recon.sh    |      |    fuzz.sh    |      |  xss-hunt.sh  |
            +-------+-------+      +-------+-------+      +-------+-------+
                    |                      |                      |
                    +----------------------+----------------------+
                                           |
                                           v
                               +-----------------------+
                               |  workspace/ (Output)  |
                               | (Raw text / JSON / MD)|
                               +-----------------------+
```

### Operational Workflow
1. **Provisioning Stage**: Users run `bash setup.sh`. The launcher detects if Docker is available. If option `1` is selected, it escalates to root and calls `install.sh`. If option `2` is chosen, it runs a docker build or pulls a prebuilt container, using bind mounts to link the host's `./workspace` folder to `/root/workspace`.
2. **Environment Configuration**: Aliases (such as `sub-enum`, `nmap-quick`, `nuclei-fast`) are written to `/etc/profile.d/hackkit.sh` and sourced in shell configurations (`.bashrc` / `.zshrc`).
3. **Pipeline Scanning**: Pipelines are invoked via short aliases (`recon`, `fuzz`, `xss`). The scripts run CLI commands, redirecting `stdout`/`stderr` to target text files, then filtering results using grep/awk utilities.

---

## 🌟 STRENGTHS

1. **Broad and Relevant Toolset**: Includes ~80 high-utility tools spanning passive enumeration, active scanning, blind XSS, secret exposure scanning, and network pivoting.
2. **Simplified Docker Mounts**: Storing static directories (like wordlists and binaries) inside named Docker volumes reduces image build times and prevents the host machine from being cluttered with gigabytes of wordlist dependencies.
3. **Effective Workspace Isolation**: Mapping `./workspace` dynamically isolates the scanner's logic from target findings data, ensuring findings are stored securely on the host.
4. **Convenient Shell Integration**: The integration of Oh-My-Zsh, Tmux configs, and system-wide shell aliases significantly reduces setup friction.

---

## ⚠️ WEAKNESSES

1. **Fragile and Non-Deterministic Builds**:
   - Compiling Go tools using `@latest` (e.g., `go install github.com/...@latest`) and cloning Python tools via `git clone --depth 1` without pinning commit hashes makes the environment unstable. If a repository owner commits a breaking change or updates a command-line argument format, the installer or pipeline will immediately fail.
2. **Uncontrolled Resource Spawning**:
   - Parallel tasks in `recon.sh` are triggered via bash background forks (e.g., `subfinder ... & assetfinder ... & wait`). On standard VPS configurations (1-2 CPU cores, 1-2GB RAM), concurrent execution of intensive scanners (especially memory-heavy Go tools like `amass`) will cause the kernel to run out of memory (OOM), leading to silent task failures.
3. **Absent Error Propagation**:
   - Multiple pipeline steps append `2>/dev/null || true` or similar error suppression switches. If a dependency is missing, an API key is rejected, or a folder cannot be written to, the scripts fail silently, creating blank text files that cause downstream utilities to produce empty results.
4. **Lack of Relational State Persistence**:
   - Relying on text files makes it hard to compare historical results, perform complex analytics, query specific target attributes, or construct APIs.
5. **Hardcoded Environmental Assumptions**:
   - The installer assumes `/root/workspace`, `/opt/hackkit`, and `$HOME/tools` directories are available and writes globally to `/etc/profile.d/`. This configuration makes multi-user deployment or rootless installation difficult.

---

## 🔒 SECURITY FINDINGS

### 1. Critical Hardcoded GitHub Access Token (PAT)
- **File Location**: [workspace/push.sh:L4](file:///c:/Users/CSND/Downloads/king/git/workspace/push.sh#L4)
- **Severity**: **Critical**
- **Vulnerable Code**:
  ```bash
  TOKEN="ghp_REDACTED_GITHUB_PERSONAL_ACCESS_TOKEN"
  USERNAME="gsodhi727"
  REPO="HackKit"
  ...
  REMOTE_URL="https://${USERNAME}:${TOKEN}@github.com/${USERNAME}/${REPO}.git"
  ```
- **Impact**: Any user who clones the repository or views its history has full access to the GitHub credentials. This can lead to complete account takeover, source code tampering, and supply chain attacks on downstream users.
- **Remediation**: Revoke the exposed token immediately. Remove `push.sh` or rewrite it to ingest `$GITHUB_TOKEN` from the shell's environment variables.

### 2. Globally Disabling SSL Verification
- **File Location**: [workspace/push.sh:L12](file:///c:/Users/CSND/Downloads/king/git/workspace/push.sh#L12)
- **Severity**: **High**
- **Vulnerable Code**:
  ```bash
  # Fix SSL in WSL (corporate/self-signed CA issue)
  git config --global http.sslVerify false
  ```
- **Impact**: Disabling SSL verification exposes the user to Man-in-the-Middle (MitM) attacks. An attacker on the local network (such as a shared Wi-Fi connection, corporate firewall, or compromised router) can intercept Git traffic and inject malicious scripts or source code adjustments.
- **Remediation**: Remove the configuration line. If a custom CA is required inside a WSL/corporate environment, import the CA root certificate into the local store instead of disabling transport encryption globally.

### 3. Remote Code Execution (RCE) via Unverified Piping
- **File Location**: [setup.sh:L110](file:///c:/Users/CSND/Downloads/king/git/setup.sh#L110) & [install.sh:L549](file:///c:/Users/CSND/Downloads/king/git/install.sh#L549)
- **Severity**: **Medium**
- **Vulnerable Code**:
  ```bash
  curl -fsSL https://get.docker.com | bash
  ```
- **Impact**: Execution of unverified remote code as root allows malicious actors to exploit CDN hijacks or DNS spoofing, leading to system compromise.
- **Remediation**: Avoid piping directly to `bash`. Instead, recommend installation using native package managers (`apt`), or download, inspect, and verify the script's hash before execution.

### 4. Parameter Injection Risks in Automation Scripts
- **File Location**: [scripts/fuzzing/fuzz.sh](file:///c:/Users/CSND/Downloads/king/git/scripts/fuzzing/fuzz.sh) & [scripts/exploitation/xss-hunt.sh](file:///c:/Users/CSND/Downloads/king/git/scripts/exploitation/xss-hunt.sh)
- **Severity**: **Medium**
- **Vulnerable Pattern**:
  ```bash
  # fuzz.sh L32-33
  HOST=$(echo "$URL" | unfurl format %d)
  OUT_DIR="${OUT_DIR:-./fuzz-${HOST}}"
  ...
  # xss-hunt.sh L40
  echo "$DOMAIN" | gau --subs | grep "=" | uro > "$OUT_DIR/params.txt"
  ```
- **Impact**: Unsanitized variables parsed into pipeline paths or evaluated by subshells are susceptible to injection attacks. If a user inputs a target argument containing special characters (e.g., `-d "target.com; rm -rf /"`), command boundaries can be bypassed.
- **Remediation**: Implement strict input validation checks. Verify that target inputs strictly conform to domain names (RFC 1035) or URL formatting protocols.

---

## 📈 TOP 20 IMPROVEMENTS

| ID | Component | Improvement Title | Description | Effort | Impact | Classification |
|---|---|---|---|---|---|---|
| 1 | **Security** | Revoke exposed PAT | Immediately revoke the exposed token `ghp_...` in GitHub dashboard. | Low | Critical | Security |
| 2 | **Security** | Remove Hardcoded Credentials | Refactor `push.sh` to load credentials from environment variables (`$GITHUB_TOKEN`). | Low | Critical | Security |
| 3 | **Security** | Re-enable SSL verification | Remove `http.sslVerify false` configurations from workspaces and WSL configs. | Low | High | Security |
| 4 | **Build** | Pin Go Tool versions | Replace `@latest` references with specific version tags (e.g., `cmd/subfinder@v2.6.4`). | Med | High | Reliability |
| 5 | **Build** | Lock Python Commits | Replace basic git clones with pinned commits (e.g. `git checkout [commit_hash]`). | Med | High | Reliability |
| 6 | **Security** | Target Input Validation | Check if the target parameter is a valid domain or IP before executing pipelines. | Low | High | Security |
| 7 | **Architecture** | Python CLI Framework | Migrate script orchestrations from Bash to a robust Python CLI (e.g., `Typer` / `Click`). | High | High | Architecture |
| 8 | **Architecture** | Asynchronous Task Manager | Deploy a concurrency runner using `asyncio` to throttle concurrent executions. | High | High | Performance |
| 9 | **Architecture** | Relational Database Layer | Integrate SQLite to store target data and scan results structurally. | High | High | Scalability |
| 10 | **DevOps** | Multi-Stage Docker Builds | Build tools in compiler stages and copy binaries to a clean runtime container. | Med | Med | Performance |
| 11 | **Security** | Rootless Containerization | Add a dedicated `security` user in Dockerfile and drop root privileges. | Med | High | Security |
| 12 | **Feature** | Unified Reporting Engine | Parse tool JSON outputs to generate consolidated Markdown/HTML summaries. | Med | High | Feature |
| 13 | **Security** | Centralized Secrets Management| Store API keys (Shodan, Chaos) in a git-ignored `.env` file instead of configurations. | Med | High | Security |
| 14 | **Reliability** | Structured Logging | Replace standard shell outputs with JSON-based file logging. | Med | Med | DX |
| 15 | **Reliability** | Checkpoint Resume Scans | Check if a scan stage succeeded and allow resuming without starting over. | Med | High | Reliability |
| 16 | **DX** | Non-Interactive Flags | Implement `--silent` or `--no-interactive` flags to support automated builds. | Low | Med | DX |
| 17 | **Feature** | Webhook Notifications | Add direct Slack/Discord alerts when scans complete. | Med | Med | Feature |
| 18 | **DevOps** | CI/CD Linting Suite | Integrate GitHub actions checking shell structures (`shellcheck`) and Python (`ruff`). | Med | Med | DX |
| 19 | **Feature** | Dashboard UI | Deploy a simple interface (e.g., Streamlit) to monitor, search, and visualize targets. | High | High | Feature |
| 20 | **Feature** | Scheduling Engine | Support running scheduled cron scans for continuous asset tracking. | Med | Med | Feature |

---

## 🏗️ PROPOSED NEW STRUCTURE

To transition the project from raw shell script wrappers into a modular, secure, and extensible Python-based security platform, we propose the following directory structure:

```
HackKit/
├── cli/
│   ├── __init__.py
│   ├── main.py              # Central entrypoint using Typer framework
│   └── commands/            # Extensible sub-commands
│       ├── recon.py         # Sub-command logic for recon mapping
│       ├── fuzz.py          # Sub-command logic for target fuzzing
│       └── exploit.py       # Sub-command logic for vulnerability scans
├── core/
│   ├── __init__.py
│   ├── config.py            # Settings manager (using Pydantic-Settings & .env)
│   ├── logger.py            # Centralized structured JSON logger
│   ├── runner.py            # Async subprocess process pooler (throttling & retries)
│   └── db.py                # Database interface (SQLite / SQLAlchemy)
├── modules/
│   ├── __init__.py
│   ├── base.py              # BasePlugin parent class
│   ├── recon/               # Subdomain enum, resolvers, HTTP probes
│   ├── scanning/            # Port scanners, vulnerability templates
│   ├── fuzzing/             # Directories, virtual hosts, parameters
│   ├── exploitation/        # Blind XSS, takeovers
│   └── reporting/           # Report generators (HTML, PDF, Markdown)
├── configs/
│   ├── default_config.yaml  # Default tool paths and scan profiles
│   └── credentials.env.example
├── docker/
│   ├── Dockerfile           # Optimized multi-stage Docker build
│   └── docker-compose.yml
├── tests/                   # Pytest automation tests
├── docs/                    # MkDocs documentation
└── scripts/
    └── setup.sh             # Entrypoint installation bootstrap script
```

---

## 📅 IMPLEMENTATION ROADMAP

### Phase 1: Immediate Remediation (1 Week)
* **Objective**: Fix critical security holes and add basic script safety checks.
* **Tasks**:
  1. Revoke the exposed GitHub token.
  2. Remove `push.sh` or configure it to load `$GITHUB_TOKEN` from the shell environment.
  3. Remove the Git global command that disables SSL verification (`http.sslVerify false`).
  4. Double-quote all variables in shell pipelines to prevent word-splitting bugs.
  5. Add basic domain verification checks using regex rules at script entry points.
  6. Add a `.shellcheckrc` and integrate basic shell scanning.

### Phase 2: Core Engine Refactoring (1 Month)
* **Objective**: Migrate the core logic to a modular Python framework.
* **Tasks**:
  1. Initialize the Python project and configure dependency management using `pyproject.toml` or `requirements.txt`.
  2. Build the main CLI app using the `Typer` framework.
  3. Pin Go package versions in `install.sh` and `Dockerfile` rather than using `@latest`.
  4. Create an async subprocess executor in Python with a configurable concurrency limit (e.g., maximum 5 parallel tools) to prevent VPS crashes.
  5. Build a parser to extract tool logs and store findings inside an SQLite database.
  6. Configure a unified `.env` manager for API tokens.

### Phase 3: Scaling & Platform Features (3 Months)
* **Objective**: Deploy multi-user configurations, continuous integration, and dashboards.
* **Tasks**:
  1. Expose the execution logic via a FastAPI backend, enabling remote scan invocation.
  2. Develop a Streamlit or React web dashboard to search domain histories, review nuclei vulnerability alerts, and view screenshot galleries.
  3. Build a plugin SDK allowing users to write simple Python scripts to integrate new security tools.
  4. Build automated reporting templates supporting PDF and HTML exports.
  5. Support scheduled target scans using Celery or background cron engines.
  6. Integrate automated webhook notifications for Slack, Discord, and Telegram.

---

## 📊 FINAL SCORES

### Architecture: 4 / 10
* **Reasoning**: The project relies heavily on raw shell file chaining and UNIX stdout piping. The absence of version pinning for Go packages and Python repositories makes builds fragile and non-deterministic. There is no central orchestrator or process pool manager, leading to frequent OOM crashes on smaller VPS systems.

### Security: 2 / 10
* **Reasoning**: The exposure of a hardcoded personal access token, globally disabling SSL verification, and downloading/piping unverified third-party code directly into root shells present significant security risks. Input fields also lack sanitization, which could lead to command injection vulnerabilities.

### Scalability: 3 / 10
* **Reasoning**: The scan data is stored entirely as unstructured text files on the local filesystem. Without a centralized database or queue manager, the tool is limited to single-node operations and cannot easily perform historical comparisons or scale to scan large target lists.

### Maintainability: 4 / 10
* **Reasoning**: Upgrading or adding tool configurations requires modifying core installation scripts. The use of mutable `@latest` versions for tool packages means external updates will frequently introduce breaking changes or syntax mismatches that break pipelines.

### Production Readiness: 3 / 10
* **Reasoning**: While HackKit is a great personal toolkit for bug bounty hunters looking for a quick terminal environment, its security risks and fragile code execution model make it unsuitable for corporate DevSecOps environments or continuous pipeline scanning.
