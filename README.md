# Dotfiles

## Quickstart

1. Clone this repository into your home directory.
2. Ensure your dotfiles are linked into `$HOME` (manual symlinks or your stow workflow).
3. Run bootstrap:
   - Auto-detect platform: `./scripts/bootstrap`
   - Only macOS: `./scripts/bootstrap --only macos`
   - Only WSL: `./scripts/bootstrap --only wsl`
   - Preview only: `./scripts/bootstrap --dry-run`
4. Start a new shell session.

## Zsh layout

- `.zshrc` is now a thin loader.
- Modules live in `.zshrc.d/` and are loaded in lexical order.
- Platform is detected as `macos`, `linux`, or `wsl`.
- Local user overrides still work via `.zshrc_user` and optional `.zshrc.local`.

## Smoke checks

Run after changes:

```bash
zsh -n .zshrc
for f in .zshrc.d/*.zsh; do zsh -n "$f"; done
./scripts/bootstrap --dry-run
```
