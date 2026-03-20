# Dotfiles

## Rootless Ubuntu Server Setup

Use this when you do not have `root` or `sudo` on the server.

Clone the repo:

```bash
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles
```

Link the dotfiles into your home directory:

```bash
# example if you use stow
stow .
```

Install the local tool set, including a local `zsh`:

```bash
./scripts/bootstrap \
  --only linux \
  --rootless
```

What happens after install:

- The setup tries to change your login shell to the local `zsh` automatically.
- If the server blocks that, it adds a small fallback to `~/.profile` so new interactive logins jump into the local `zsh` anyway.
- If you want to start it manually right away, run:

```bash
~/.linuxbrew/bin/zsh -l
```

If you want a different install location:

```bash
DOTFILES_ROOTLESS_BREW_PREFIX="$HOME/somewhere/homebrew" \
  ./scripts/bootstrap \
  --only linux \
  --rootless
```

## Quickstart

1. Clone this repository into your home directory.
2. Ensure your dotfiles are linked into `$HOME` (manual symlinks or your stow workflow).
3. Run bootstrap:
   - Auto-detect platform:

```bash
./scripts/bootstrap
```

   - Only macOS:

```bash
./scripts/bootstrap --only macos
```

   - Only WSL:

```bash
./scripts/bootstrap --only wsl
```

   - Rootless Linux/WSL:

```bash
./scripts/bootstrap \
  --only linux \
  --rootless
```

   - Preview only:

```bash
./scripts/bootstrap --dry-run
```
4. Start a new shell session.

## Zsh layout

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
zsh -n .zshrc
find .zshrc.d -type f -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
./scripts/bootstrap --dry-run
```
