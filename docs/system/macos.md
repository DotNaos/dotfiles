# macOS system tweaks

- Touch ID for sudo: `./scripts/system/macos` prepends `pam_tid.so` to `/etc/pam.d/sudo` if it is not already present. Use `--dry-run` to see the changes without applying them.
- Running `./setup --only macos` will call the same script after packages are installed.
- System profile defaults to `client`; override with `DOTFILES_SYSTEM_PROFILE` if additional profiles are added later.
