# Dotfiles

1. Clone

```bash
git clone https://github.com/DotNaos/dotfiles.git ~/dotfiles
```

1. Setup

This automatically detects your platform and checks for sudo access to pick the right setup path for you.

```bash
./dotfiles/setup
```

On Linux/WSL, the setup installs base packages with `apt` when available and then
adds the shared CLI toolchain with a user-local Linuxbrew under `~/.linuxbrew`.

Platform-specific system notes (e.g., macOS Touch ID for `sudo`) live in `docs/system/`.

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

## Zsh layout

- `.zshenv` bootstraps shared environment and PATH setup for every zsh process.
- `.zshrc` is now a thin loader.
- Modules live in `.zshrc.d/` and load recursively in lexical path order.
- Top-level folders define coarse order, files inside them define local order.
- Current groups are `00-core/`, `10-shell/`, `20-integrations/`, `70-os/`, and `90-local/`.
- Context exposes `DOTFILES_PLATFORM`, `DOTFILES_ROLE`, `DOTFILES_MODE`, and `DOTFILES_SHELL`.
- Local user overrides still work via `.zshrc_user` and optional `.zshrc.local`.

## Secrets and env

- Secret helpers live in `.zshrc.d/10-shell/50-secrets.zsh`.
- Shared secret references belong in `.zshrc.d/10-shell/60-shared-secrets.zsh`.
- Shell startup does not resolve 1Password secrets or require `op`.
- If `~/.env` exists, it is sourced quietly as the user's own home-level overrides.
- Project-specific secrets stay in each project, for example `.env.1password` as a template and `.env.local` as an injected destination.

Shared secret reference module:

```bash
export OPENAI_API_KEY="op://Private/OpenAI/api key"
export ANTHROPIC_API_KEY="op://Private/Anthropic/api key"
```

Available helpers:

```bash
op-ready
op-read-ref op://Private/example/password
secrets-shared-load
secrets-shared-run -- env | grep API_KEY
env-load .env .env.local
env-run .env.1password -- pnpm dev
env-inject .env.1password .env.local
```

Notes:

- `.zshrc.d/10-shell/60-shared-secrets.zsh` is autoloaded and should only export literal `op://...` references.
- `~/.env` is for user-owned home-level env vars and is sourced automatically when present.
- `secrets-shared-load` resolves all currently exported `op://...` variables, or only the names you pass explicitly.
- `secrets-shared-run` and `env-run` use `op run`, so secrets only exist for the spawned process.
- `env-inject` uses `op inject` and writes `.env.local` with mode `0600` by default.
- If `op` is missing or not signed in, shell startup stays quiet; manual helpers print a short error.

## Smoke checks

Run after changes:

```bash
bash -n setup
bash -n scripts/setup
bash -n scripts/link-home
bash -n scripts/render-configs
bash -n scripts/system/apply
bash -n scripts/system/macos
find scripts/system -type f -perm -111 -print0 | xargs -0 -n1 bash -n
zsh -n .zshenv
zsh -n .zshrc
find .zshrc.d -type f -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
./scripts/render-configs --dry-run
./setup --dry-run
```
