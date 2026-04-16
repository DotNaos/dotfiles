# macOS system tweaks

- Touch ID for sudo lives in `scripts/system/hooks/platform/macos/` and is applied by `./scripts/system/macos`.
- Use `./scripts/system/macos --dry-run` to preview changes without applying them.
- Running `./setup --only macos` will call the same script after packages are installed.
- Put persistent context choices in `~/.config/dotfiles/context.env`.
- The shared hook order is `base`, `platform`, `role`, `mode`, then `shell`.
- V1 only has meaningful macOS hooks on the platform layer.
