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

- Vault references and secret values never live in this repository.
- Normal shell startup does not load a service-account token, secret file, or
  1Password SSH agent.
- Codex shells load the read-only token from the unversioned
  `~/.config/1password/op/service-account.env` file.
- Set `CODEX_DONT_USE_1PASSWORD_SERVICE_ACCOUNT=1` or
  `OP_SERVICE_ACCOUNT_DISABLED=1` when an interactive desktop approval is
  required instead.
- The unversioned `~/.config/1password/op/.env` file contains the user's Vault
  references. It is loaded only when `loadsecrets` is run explicitly.

Available commands:

```bash
loadsecrets
listsecrets
env-load .env .env.local
```

Notes:

- `loadsecrets` sources the local reference file into the current shell. It does
  not resolve the references into secret values.
- `listsecrets` prints only the configured environment-variable names.
- `env-load` remains a generic, explicit project env-file loader.

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
