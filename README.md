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

## RustDesk client deployment

RustDesk is installed from the latest official GitHub release, configured for a
self-hosted OSS server, registered as a system service and restarted. The
bootstrap prints only the device's RustDesk ID; it never stores or prints a
permanent access password.

Configure the public server values in `config/rustdesk.env`. Prefer
`RUSTDESK_REPO_CONFIG_STRING`, exported from **Settings → Network → Export Server
Config** on an already configured client. The official
[client configuration guide](https://rustdesk.com/docs/en/self-host/client-configuration/)
documents importing that string with `--config`; a complete `RustDesk2.toml`
import is intentionally not used because it can include unrelated, device-local
settings. The deployment flags are also checked against the installed version
and the corresponding official RustDesk release. If no config string is
available, set the ID server, optional relay server and public key in the same
file.

On an existing dotfiles checkout:

```powershell
# Windows PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\dotfiles\scripts\rustdesk\bootstrap.ps1"
```

```bash
# macOS or Linux
sudo ./dotfiles/scripts/rustdesk/bootstrap.sh
```

For a new device without a checkout, run one remote bootstrap command after the
pull request has been merged:

```powershell
# Windows PowerShell
irm https://raw.githubusercontent.com/DotNaos/dotfiles/main/scripts/rustdesk/bootstrap.ps1 | iex
```

```bash
# macOS or Linux
curl -fsSL https://raw.githubusercontent.com/DotNaos/dotfiles/main/scripts/rustdesk/bootstrap.sh | sudo -E bash
```

Environment variables override repository values for one deployment:

```bash
RUSTDESK_CONFIG_STRING='...' \
RUSTDESK_PASSWORD='secret-manager-value' \
sudo --preserve-env=RUSTDESK_CONFIG_STRING,RUSTDESK_PASSWORD \
  ./dotfiles/scripts/rustdesk/bootstrap.sh
```

The equivalent Windows variables are `RUSTDESK_CONFIG_STRING`,
`RUSTDESK_ID_SERVER`, `RUSTDESK_RELAY_SERVER`, `RUSTDESK_PUBLIC_KEY` and the
optional secret `RUSTDESK_PASSWORD`. A password should only be supplied through
the process environment or a secret manager. macOS still requires Screen
Recording, Accessibility and Input Monitoring approval, unless those permissions
are deployed through MDM.

## Smoke checks

Run after changes:

```bash
bash -n setup
bash -n scripts/setup
bash -n scripts/link-home
bash -n scripts/render-configs
bash -n scripts/system/apply
bash -n scripts/system/macos
bash -n scripts/rustdesk/bootstrap.sh
find scripts/system -type f -perm -111 -print0 | xargs -0 -n1 bash -n
zsh -n .zshenv
zsh -n .zshrc
find .zshrc.d -type f -name '*.zsh' -print0 | xargs -0 -n1 zsh -n
./scripts/render-configs --dry-run
./setup --dry-run
```
