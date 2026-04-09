<div align="center">

![header](https://capsule-render.vercel.app/api?type=waving&color=0:282a36,100:bd93f9&height=200&section=header&text=~/.dotfiles&fontSize=48&fontColor=f8f8f2&fontAlignY=30&desc=Chezmoi%20%C2%B7%20Nix%20%C2%B7%20AI%20tooling&descSize=16&descColor=8be9fd&descAlignY=55&animation=fadeIn)

<p>
  <a href="https://github.com/signalridge/dotfiles/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/signalridge/dotfiles/ci.yml?style=for-the-badge&logo=github&label=CI"></a>&nbsp;
  <a href="https://opensource.org/licenses/MIT"><img alt="License" src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge"></a>&nbsp;
  <img alt="macOS" src="https://img.shields.io/badge/macOS-Sonoma+-000000?style=for-the-badge&logo=apple&logoColor=white">&nbsp;
  <img alt="Linux" src="https://img.shields.io/badge/Linux-supported-FCC624?style=for-the-badge&logo=linux&logoColor=black">
</p>

<p>
  <a href="https://github.com/twpayne/chezmoi"><img alt="chezmoi" src="https://img.shields.io/badge/chezmoi-4B91E2?style=for-the-badge&logo=chezmoi&logoColor=white"></a>&nbsp;
  <a href="https://github.com/LnL7/nix-darwin"><img alt="nix-darwin" src="https://img.shields.io/badge/nix--darwin-5277C3?style=for-the-badge&logo=nixos&logoColor=white"></a>&nbsp;
  <a href="https://www.anthropic.com/claude-code"><img alt="Claude Code" src="https://img.shields.io/badge/Claude_Code-191919?style=for-the-badge&logo=anthropic&logoColor=white"></a>&nbsp;
  <a href="https://openai.com/index/introducing-codex/"><img alt="Codex CLI" src="https://img.shields.io/badge/Codex_CLI-111111?style=for-the-badge&logo=openai&logoColor=white"></a>&nbsp;
  <a href="https://brew.sh/"><img alt="Homebrew" src="https://img.shields.io/badge/Homebrew-FBB040?style=for-the-badge&logo=homebrew&logoColor=black"></a>
</p>

[English](README.md) | [中文](README.zh-CN.md) | [日本語](README.ja.md)

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=22&pause=1000&color=BD93F9&center=true&vCenter=true&width=600&lines=Declarative+dev+environment+with+chezmoi+%2B+Nix;Cross-platform+macOS+%2B+Linux+support;Automated+plugin+sync+for+Claude+Code;Modern+CLI+toolchain+with+Rust-based+tools)](https://git.io/typing-svg)

</div>

---

## What This Repo Is

A reproducible personal workstation setup built around:

- `chezmoi` for dotfiles, templating, and bootstrap orchestration
- `Nix` for declarative packages (`nix-darwin` on macOS + `flakey-profile` on macOS/Linux)
- `aqua` + `mise` for CLI/runtime pinning outside Nix where practical (`codex` and `claude-code` are pinned in global `mise`)
- Shared AI tooling for `Claude Code` and `Codex CLI`

This is a real daily-driver setup, not a demo template. The README focuses on what is actually implemented in this repository today.

---

## Highlights

- Unified bootstrap pipeline (`.chezmoiscripts/00..10`) with idempotent post-apply maintenance
- Cross-platform package strategy:
  - Nix user packages on macOS/Linux
  - nix-darwin system config on macOS
  - Homebrew/MAS integration on macOS
- Shared AI skills marketplace sync to `~/.agents/skills` for Claude/Codex
- Multi-provider account switching for managed wrappers:
  - `claude-manage` / `claude-with`
  - `codex-manage` / `codex-with`
- Automated dependency upkeep via GitHub Actions (versions, flake locks, aqua packages, mise tools)
- `C1/C2/C3/C4` routing: advisory in `C1`, direct deterministic flow in `C2`, OpenSpec governance for `C3`/`C4`

---

## Why This Repo

- **Profiles everywhere**: `.chezmoidata/` drives `shared` / `work` / `private` packages across Nix, Homebrew, and MAS
- **End-to-end bootstrap**: staged scripts from `00` to `11` keep setup deterministic and composable
- **macOS polish**: nix-darwin system defaults, Homebrew + MAS integration, post-apply maintenance scripts
- **Workflow guardrails**: pre-commit checks + Claude hooks to reduce risky edits and command misuse
- **DX automation**: Justfile routines, fzf navigation helpers, AI-assisted commit flows
- **CI parity**: template rendering and `nix flake check` on macOS + Linux matrix
- **Dual AI stack**: Claude Code and Codex CLI are managed declaratively in one repo

---

## Motivation

Setting up a new development machine is tedious: dozens of packages to install, many tools to configure, and years of shell/runtime tweaks to remember.

This repository solves that with a declarative baseline and practical bootstrap pipeline, so one repo can recreate a working environment across machines with predictable outcomes.

Core principles:

- **Reproducibility**: same setup logic, same versioned data, repeatable outcomes
- **Declarative first**: package and tool configuration lives in tracked YAML/templates
- **Modular profiles**: work/private/headless behavior is data-driven, not hardcoded forks
- **AI-augmented workflows**: managed prompts, hooks, skills, and provider switching
- **Security layering**: separate mechanisms for dotfile secrets, password store, and key backups

---

## Table of Contents

- [What This Repo Is](#what-this-repo-is)
- [Highlights](#highlights)
- [Why This Repo](#why-this-repo)
- [Motivation](#motivation)
- [Table of Contents](#table-of-contents)
- [Architecture](#architecture)
- [Repository Map](#repository-map)
- [Bootstrap Flow (What Actually Runs)](#bootstrap-flow-what-actually-runs)
- [Quick Start](#quick-start)
  - [Option 1: Run `init.sh` directly](#option-1-run-initsh-directly)
  - [Option 2: Pin to a tag/branch and review first](#option-2-pin-to-a-tagbranch-and-review-first)
  - [Option 3: Clone and run locally (best auditability)](#option-3-clone-and-run-locally-best-auditability)
  - [Useful `init.sh` flags](#useful-initsh-flags)
- [First Run Prompts](#first-run-prompts)
- [Daily Operations](#daily-operations)
  - [Chezmoi](#chezmoi)
  - [Nix](#nix)
  - [macOS (`nix-darwin`)](#macos-nix-darwin)
  - [Tests](#tests)
- [AI Tooling (Claude + Codex)](#ai-tooling-claude--codex)
  - [Shared Skill Distribution](#shared-skill-distribution)
- [Tool Chains](#tool-chains)
  - [Modern CLI Replacements](#modern-cli-replacements)
  - [Shell Environment](#shell-environment)
  - [Development Tools](#development-tools)
- [Shell Functions](#shell-functions)
  - [Project Navigation](#project-navigation)
  - [Git Workflow](#git-workflow)
  - [Environment Setup](#environment-setup)
- [Package Management](#package-management)
- [Multi-Profile Configuration](#multi-profile-configuration)
- [Security \& Secrets](#security--secrets)
- [CI and Automation](#ci-and-automation)
  - [Validation](#validation)
  - [Automated Upkeep](#automated-upkeep)
- [Workflow Routing (C1-C4)](#workflow-routing-c1-c4)
- [Additional Docs](#additional-docs)
- [Acknowledgements](#acknowledgements)
- [Stats](#stats)
- [License](#license)

---

## Architecture

This repository combines `chezmoi` templating with Nix-based package management and AI tooling overlays:

- `chezmoi`: source-of-truth orchestration for scripts/templates
- `nix-darwin` (macOS): system-level configuration
- `flakey-profile` (macOS/Linux): user package profile
- `aqua` + `mise`: CLI/runtime tooling layer outside Nix (`codex` and `claude-code` are managed by global `mise`)
- `dot_claude` + `dot_codex`: tool-specific global guidance and configuration

| Component     | macOS          | Linux          |
| ------------- | -------------- | -------------- |
| Dotfiles      | chezmoi        | chezmoi        |
| System Config | nix-darwin     | N/A            |
| User Packages | flakey-profile | flakey-profile |
| GUI Apps      | Homebrew/MAS   | N/A            |

---

## Repository Map

```text
.
├── .chezmoidata/
│   ├── nix.yaml                # Nix package sets (shared/work/private)
│   ├── homebrew.yaml           # Homebrew taps/brews/casks/MAS apps
│   └── versions.yaml           # Pinned tool/plugin revisions
├── .chezmoiscripts/            # Bootstrap + maintenance pipeline (00..10)
├── nix-config/
│   ├── flake.nix.tmpl
│   └── modules/
│       ├── system.nix.tmpl     # nix-darwin system config
│       ├── apps.nix.tmpl       # Homebrew + MAS wiring
│       ├── profile.nix.tmpl    # flakey-profile package profile
│       └── host-users.nix
├── dot_local/bin/              # CLI wrappers (Claude/Codex/keys)
├── dot_claude/                 # Claude global instructions/hooks/templates
├── dot_codex/                  # Codex global instructions/config/prompts
├── private_dot_config/         # Tool configs (tmux, mise, aqua, gopass, ...)
├── docs/                       # Focused guides
└── tests/                      # Bootstrap/script regression tests
```

---

## Bootstrap Flow (What Actually Runs)

The `chezmoi` script chain is staged and numbered:

1. `00` install Nix (Determinate installer with arch/mirror detection)
2. `01` optionally restore encrypted keys-manage files (`useEncryption=true`)
3. `02` macOS: apply nix-darwin system configuration
4. `03` switch flakey-profile package profile
5. `04` bootstrap gopass store (interactive clone)
6. `05` install pinned aqua installer/version
7. `06` install tools from `private_dot_config/aquaproj-aqua/aqua.yaml` (excluding `codex`/`claude-code`)
8. `07` install runtimes/tools via `mise` (including global `codex`/`claude-code`)
9. `08` install pinned nix-index database
10. `10` periodic Homebrew update/upgrade (7-day interval)

---

## Quick Start

> [!WARNING]
> This repository modifies shell, package managers, and system settings.
> Fork and review before running on a machine you care about.

### Option 1: Run `init.sh` directly

```bash
curl -fsSL https://raw.githubusercontent.com/signalridge/dotfiles/main/init.sh | sh
```

### Option 2: Pin to a tag/branch and review first

```bash
REF="<tag-or-branch>"
curl -fsSLo init.sh "https://raw.githubusercontent.com/signalridge/dotfiles/${REF}/init.sh"
shasum -a 256 init.sh || sha256sum init.sh
sh init.sh --ref "${REF}"
```

### Option 3: Clone and run locally (best auditability)

```bash
git clone https://github.com/signalridge/dotfiles.git
cd dotfiles
git checkout <tag-or-commit>
./init.sh
```

### Useful `init.sh` flags

```bash
./init.sh --repo signalridge/dotfiles
./init.sh --ref v1.2.3
./init.sh --depth 1
./init.sh --ssh
```

---

## First Run Prompts

`chezmoi` data prompts include:

- `work` (work machine switch)
- `headless` (container/server without full desktop assumptions)
- `useEncryption` (enable encrypted key restore flow)
- `installMasApps` (macOS App Store apps)

For most first-time users of this repo: keep `useEncryption = false` unless you have your own keys-manage backup repo and key material.

---

## Daily Operations

The generated global Justfile lives at `~/.config/just/.justfile`.

### Chezmoi

```bash
just apply
just diff
just update
just re-add
```

### Nix

```bash
just up
just upp nixpkgs
just gc
just verify
just optimize
```

### macOS (`nix-darwin`)

```bash
just darwin
just darwin-check
just darwin-build
```

### Tests

```bash
bash tests/run.sh
pre-commit run --all-files
```

---

## AI Tooling (Claude + Codex)

### Shared Skill Distribution

Managed by [skimi](https://github.com/timonwong/skimi).

---

## Tool Chains

This setup keeps the original modern CLI stack and shell ergonomics.

### Modern CLI Replacements

| Classic | Modern                                           | Description                           |
| ------- | ------------------------------------------------ | ------------------------------------- |
| `ls`    | [eza](https://github.com/eza-community/eza)      | Git integration, icons, tree views    |
| `cat`   | [bat](https://github.com/sharkdp/bat)            | Syntax highlighting, git integration  |
| `grep`  | [ripgrep](https://github.com/BurntSushi/ripgrep) | Lightning-fast regex search           |
| `find`  | [fd](https://github.com/sharkdp/fd)              | Intuitive syntax, respects .gitignore |
| `cd`    | [zoxide](https://github.com/ajeetdsouza/zoxide)  | Smart directory jumping               |

### Shell Environment

| Tool                                                | Role                                      |
| --------------------------------------------------- | ----------------------------------------- |
| [starship](https://github.com/starship/starship)    | Minimal, blazing-fast prompt              |
| [sheldon](https://github.com/rossmacarthur/sheldon) | Fast zsh plugin manager                   |
| [atuin](https://github.com/atuinsh/atuin)           | Shell history with fuzzy search           |
| [direnv](https://github.com/direnv/direnv)          | Per-directory environment variables       |
| [fzf](https://github.com/junegunn/fzf)              | Fuzzy finder for files, history, and more |

### Development Tools

| Tool                                                | Role                                              |
| --------------------------------------------------- | ------------------------------------------------- |
| [mise](https://github.com/jdx/mise)                 | Polyglot runtime manager (Node, Python, Go, Rust) |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git                               |
| [yazi](https://github.com/sxyazi/yazi)              | Fast terminal file manager                        |
| [tmux](https://github.com/tmux/tmux)                | Terminal multiplexer                              |

---

## Shell Functions

### Project Navigation

```bash
dev                 # FZF-powered project selector (with ghq)
mkcd <dir>          # Create directory and cd into it
dotcd               # Jump to chezmoi source
```

### Git Workflow

```bash
fgc                 # Fuzzy git checkout (branches)
fgl                 # Fuzzy git log viewer
fga                 # Fuzzy git add (select files)
aicommit            # Generate commit message with AI
```

### Environment Setup

```bash
create_direnv_venv  # Create Python venv with direnv
create_direnv_nix   # Create Nix flake with direnv
create_py_project   # Quick Python project setup with uv
```

---

## Package Management

| Source         | Platform     | Description                 |
| -------------- | ------------ | --------------------------- |
| Nix packages   | macOS, Linux | Reproducible, rollback-able |
| Homebrew casks | macOS only   | GUI applications            |
| Mac App Store  | macOS only   | App Store exclusives        |

Package lists live in `.chezmoidata/` and support `shared` / `work` / `private` segmentation.

After migrating `codex` and `claude-code` from `aqua` to `mise`, reclaim old `aqua` package data with:

```bash
aqua rm -m pl openai/codex anthropics/claude-code
aqua vacuum -d 0
du -sh "${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua/pkgs"
```

---

## Multi-Profile Configuration

```bash
# For work machines
chezmoi init --apply --promptBool work=true signalridge

# For personal machines (default)
chezmoi init --apply signalridge

# For headless servers (no GUI configs)
chezmoi init --apply --promptBool headless=true signalridge
```

---

## Security & Secrets

This repo uses multiple layers with different purposes:

1. `chezmoi` secret decryption via `age` command wrapper and `~/.ssh/main`
2. `gopass` configured with `age` backend for API key/password storage
3. `keys-manage` encrypted backup repo using OpenSSL PBKDF2 (`AES-256-CBC`)
4. Claude hook guardrails to block risky git/history-rewrite flows

See:

- `docs/keys-manage-guide.md`
- `docs/gopass-new-device-setup.md`
- `docs/claude-provider.md`

---

## CI and Automation

### Validation

- `.github/workflows/ci.yml`
  - pre-commit checks
  - template render validation
  - `nix flake check` (macOS + Linux matrix)

- `.github/workflows/tests.yml`
  - manual bootstrap/script test suite (`bash tests/run.sh`)

### Automated Upkeep

- `.github/workflows/scheduler.yml` (daily trigger)
- `.github/workflows/update-versions.yml`
- `.github/workflows/update-flake-lock.yml`
- `.github/workflows/update-aqua-packages.yml`
- `.github/workflows/update-mise-tools.yml` (auto-updates tools in the `# mise-update:begin/end` block)

---

## Workflow Routing (C1-C4)

> [!IMPORTANT]
> This repository routes implementation by `C1/C2/C3/C4` classification before coding.

| Category | Intent                                                                                       | Primary Path                       |
| -------- | -------------------------------------------------------------------------------------------- | ---------------------------------- |
| `C1`     | Advisory/read-only request                                                                   | Analyze and report only            |
| `C2`     | Deterministic change                                                                         | Implement directly                 |
| `C3`     | Governed change (guardrail or high-control)                                                  | OpenSpec standard lifecycle        |
| `C4`     | Discovery-required program (new project / major refactor / high ambiguity with high control) | OpenSpec discovery-first lifecycle |

Boundary and ownership:

- `C1` is advisory only and does not include file changes.
- `C2` deterministic changes can be implemented directly.
- `C3` and `C4` require governed execution with explicit step-by-step confirmation.

---

## Additional Docs

- `docs/claude-provider.md`
- `docs/keys-manage-guide.md`
- `docs/gopass-new-device-setup.md`
- `docs/tmux.md`

---

## Acknowledgements

- [chezmoi](https://github.com/twpayne/chezmoi) - Dotfiles manager
- [nix-darwin](https://github.com/LnL7/nix-darwin) - Declarative macOS configuration
- [flakey-profile](https://github.com/lf-/flakey-profile) - Cross-platform Nix profile management
- [wshobson/agents](https://github.com/wshobson/agents) - Claude Code plugins marketplace

---

## Stats

![Alt](https://repobeats.axiom.co/api/embed/81ef9a8c511918fc0eece9bd09bb46ba78eefd0c.svg "Repobeats analytics image")

---

## License

MIT
