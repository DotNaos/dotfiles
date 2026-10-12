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
(cd ~/dotfiles/tools/dotfiles && go build -o dotfiles ./cmd/dotfiles)
~/dotfiles/setup --config-only
```

Go must already be provided by the system. Rebuild the CLI after updating the
checkout; setup checks that the selected CLI supports configuration preservation.

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

Agent Memory's app connection, scope rules, and exact-client read check are
documented in [AGENT_MEMORY.md](AGENT_MEMORY.md). An app-provided connection need
not appear in `config.toml` or `codex mcp list`.

Codex config layers use additive dotted keys. A platform layer may add settings
but must not redefine a key from an earlier layer; conflicting keys stop the
render instead of producing an ambiguous config. Global `AGENTS.md` guidance is
managed only from the base layer.

For personal Remote Space work, this shared guidance makes the configured
`remote_space_native` tools the default for every agent, including commands and
file writes. Supported reads use its dedicated tools; general operations use
`host_call`. Existing authorization and safety checks still apply. Missing native
tools require an explicit availability report and a normal reload or fresh chat;
an independently permitted hosted connection remains an explicit fallback.
The separate `remote_space_read` connection cannot run commands or writes.
Only these server/tool names are portable: connection details remain in the
protected local configuration described below. Existing chats may retain old
guidance or tool catalogs until normally reloaded; fresh chats receive the new
default. Work installations must keep their separate connection boundaries.

The global Environment Awareness rule establishes the local execution context
and requires reading a remote host's versioned `environment_instructions` through
its configured MCP connection before first operational use. The host maintains
the complete guide and capability snapshot; dotfiles keeps only the portable
bootstrap rule. Cache `host_id`, connection/route, `version` and `content_version`
in the session, refreshing when context or connection changes. An installed
`remote-mcp --environment-instructions --json` is a permitted local fallback
only when its installed version is known to support this discovery mode. Do not
probe older binaries with unknown flags: they may start a server. A CLI snapshot
is not proof that a remote client connection works. Host capabilities, restrictions
on an execution route and human authorization remain separate.

This repository currently manages the Codex entry point only. Other agents can
receive the host's guide through the same MCP discovery contract; no Claude or
Copilot configuration migration is introduced here.

The renderer writes only `AGENTS.md` and `config.toml` into
`~/.local/state/dotfiles/rendered/.codex/`. The linker then links those two files
individually into `~/.codex/` and backs up conflicting targets. It never links or
copies the complete live Codex directory. Authentication, sessions, memories,
databases, logs, caches, app state, and installed or bundled plugins and skills
remain local and unversioned.

To inspect or apply only the Codex files:

```bash
# Build the existing Go CLI after a clone or an update.
(cd tools/dotfiles && go build -o dotfiles ./cmd/dotfiles)
./scripts/link-home --only codex --dry-run
./scripts/link-home --only codex
```

Rendering requires this CLI build (or an up-to-date installed `dotfiles` CLI).
`DOTFILES_CLI` can select an explicit binary. Setup never installs or downloads
the CLI automatically.

Settings added or changed by Codex are preserved outside this repository in
`~/.config/dotfiles/codex/<platform>/<role>.local.toml`. This private file has
owner-only permissions, as does the rendered configuration. Keep actual MCP
commands, addresses, arguments and credentials out of the public source layers.
No connection details are logged by the preservation step.

On the first rebuild, existing settings that differ from the current source
defaults are imported once. Without previous history, an old default and a
deliberate edit cannot be distinguished. Later rebuilds use local hashes to
recognize client edits: unchanged settings follow updated source defaults;
local additions, changes and deletions survive. Arrays are preserved together.
The reserved `_dotfiles_codex` table records deleted paths in the private file
and is omitted from Codex's configuration. Removing a deletion record restores
the corresponding default.

Private settings are scoped by platform and role. Switching roles does not
import the previous role's live settings. A malformed input, unsafe symlink or
detected concurrent edit stops rendering before replacing the working config.
`--dry-run` validates without creating or updating files. The local
`last-render.json` stores context and hashes rather than setting values.
Simultaneous renders fail safely so they can be retried. If publishing is
interrupted, a protected `.publish-pending` marker blocks further rendering
until local recovery has checked the private settings, output and history;
do not clear this marker without reviewing or restoring those files.

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
  Doppler machine-token variables. Human Doppler login state stays in the
  Doppler CLI's local login store.
- Local development uses the `local-development` Doppler project and `dev`
  config. It does not create identities or tokens.
- Personal 1Password use, the desktop app, and its SSH agent are outside this
  development-secret path and remain available when explicitly requested.

Available commands:

```bash
withsecrets <command> [argument ...]
env-load .env .env.local
```

Notes:

- `withsecrets` uses the existing Doppler login, injects `local-development/dev`
  values only into the child process, and writes no `.env` or fallback file.
  Sign in explicitly with `doppler login` when needed; shell startup never
  starts a browser login.
- For another project's secrets, use its configured directory and run
  `doppler run --no-fallback -- <command>` directly. Doppler's
  [directory scopes](https://docs.doppler.com/docs/secrets-setup-guide) select
  its project and config; `withsecrets` always selects local development.
- `env-load` remains a generic, explicit project env-file loader.

## Local Python growth audit

Use the optional, read-only Git worktree check before committing project changes:

```bash
bash ~/dotfiles/scripts/check-python-growth.sh /path/to/repository
bash ~/dotfiles/scripts/check-python-growth.sh --base origin/main /path/to/repository
```

Without `--base`, it compares against the current branch point with local
`origin/main` (or `main`/`master`/`trunk`); it never fetches. `--base REF`
compares with that exact Git revision, including commits made on the branch.
It inspects staged, unstaged, and non-ignored untracked source/config files,
reporting new Python files/manifests, added interpreter references, and edits
to legacy Python for manual review. Approved Python scopes must be evaluated
by the user; the scan is heuristic and not a comprehensive language detector.

Findings return exit code `0` and are **not** a CI or pre-commit gate.
Invalid repository/ref or other Git errors return `2`. No project files,
hooks, CI configuration, or interpreter installations are changed.
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
