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

## Zsh layout

- `.zshenv` bootstraps shared environment and PATH setup for every zsh process.
- `.zshrc` is now a thin loader.
- Modules live in `.zshrc.d/` and load recursively in lexical path order.
- Top-level folders define coarse order, files inside them define local order.
- Current groups are `00-core/`, `10-shell/`, `20-integrations/`, `70-os/`, and `90-local/`.
- Platform is detected as `macos`, `linux`, or `wsl`.
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
zsh -n .zshenv
zsh -n .zshrc
find .zshrc.d -type f -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
./setup --dry-run
```
