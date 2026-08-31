# Dotfiles

1. Clone

```bash
git clone https://github.com/DotNaos/dotfiles.git ~/dotfiles
```

1. Setup

This detects your context and configures your user home only. It does not install
packages, use `sudo`, change `/etc`, or run system hooks. Systems own machine
and package provisioning.

```bash
./dotfiles/setup --config-only
```

`./setup --config-only` is the stable entry point for system automation. The
default `./setup` is also config-only for compatibility. Add `--dry-run` to
inspect the planned rendering and links without changing the home.

Persistent context preferences live in `~/.config/dotfiles/context.env`.
Environment variables still override that file when you need a one-off run.

```bash
DOTFILES_PLATFORM=macos
DOTFILES_ROLE=default
DOTFILES_MODE=interactive
DOTFILES_SHELL=zsh
```

Context precedence is:

1. direct environment variable
2. `~/.config/dotfiles/context.env`
3. auto-detection
4. hard default

Managed app configs are rendered from `context/base/` plus optional overlays in:

- `context/platform/<platform>/`
- `context/role/<role>/`
- `context/mode/<mode>/`
- `context/shell/<shell>/`

## SSH

The shared `~/.ssh/config` is installed on both graphical clients and headless
systems. Short names are canonicalized only when they contain no dots:

```bash
ssh os-pc
```

resolves through:

```text
os-pc.vpn.os-home.net
```

The configuration contains no device IP addresses or device-specific key
mapping. Tailscale and the authoritative `vpn.os-home.net` records remain the
source of truth. Existing conflicting `~/.ssh/config` files are backed up by the
normal dotfiles linker before the managed file is linked, and `~/.ssh` is kept
at mode `700`.

## Codex

Global Codex guidance and configuration use the same context renderer and home
linker as the other managed applications:

- `context/base/codex/AGENTS.md` contains portable global guidance.
- `context/base/codex/config.toml` contains shared Codex defaults.
- `context/platform/<platform>/codex/config.toml` contains platform-specific
  additions such as desktop preferences and local launcher paths.

Codex config layers use additive dotted keys. A platform layer may add settings
but must not redefine a key from an earlier layer; conflicting keys stop the
render instead of producing an ambiguous config. Global `AGENTS.md` guidance is
managed only from the base layer.

The renderer writes only `AGENTS.md` and `config.toml` into
`~/.local/state/dotfiles/rendered/.codex/`. The linker then links those two files
individually into `~/.codex/` and backs up conflicting targets. It never links or
copies the complete live Codex directory. Authentication, sessions, memories,
databases, logs, caches, app state, and installed or bundled plugins and skills
remain local and unversioned.

To inspect or apply only the Codex files:

```bash
./scripts/link-home --only codex --dry-run
./scripts/link-home --only codex
```

Codex agents record small, non-blocking workflow friction in the current
repository's `PAPERCUTS.md` through the managed `papercut` CLI. The CLI is linked
into `~/.local/bin/papercut` by the normal setup or Codex-only linking flow and
does not perform transcript analysis or call another model.

## Zsh layout

- `.zshenv` bootstraps shared environment and PATH setup for every zsh process.
- `.zshrc` is now a thin loader.
- Modules live in `.zshrc.d/` and load recursively in lexical path order.
- Top-level folders define coarse order, files inside them define local order.
- Current groups are `00-core/`, `10-shell/`, `20-integrations/`, `70-os/`, and `90-local/`.
- Context exposes `DOTFILES_PLATFORM`, `DOTFILES_ROLE`, `DOTFILES_MODE`, and `DOTFILES_SHELL`.
- Local user overrides still work via `.zshrc_user` and optional `.zshrc.local`.

## Secrets and env

- Vault references and secret values never live in this repository.
- Shell startup explicitly removes inherited 1Password service-account and
  Infisical machine-token variables. Human Infisical login state stays in the
  macOS Keychain.
- Local development uses the delete-protected `Local Development` Infisical
  project. It does not create identities or tokens.
- Personal 1Password use, the desktop app, and its SSH agent are outside this
  development-secret path and remain available when explicitly requested.

Available commands:

```bash
withsecrets <command> [argument ...]
env-load .env .env.local
```

Notes:

- `withsecrets` authenticates as the signed-in human, injects the Local
  Development values only into the child process, and writes no `.env` file.
- `env-load` remains a generic, explicit project env-file loader.

## Smoke checks

Run after changes:

```bash
bash -n setup
bash -n scripts/setup
bash -n scripts/link-home
bash -n scripts/render-configs
bash -n scripts/smoke-config-only
zsh -n .zshenv
zsh -n .zshrc
find .zshrc.d -type f -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
./scripts/render-configs --dry-run
./setup --config-only --dry-run
./scripts/smoke-config-only
```
