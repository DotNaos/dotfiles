# Papercuts

## 2026-08-04T21:27:26Z — gpt-5.6-sol — Codex

./setup --dry-run emitted "USER: unbound variable" from scripts/setup when USER was absent, even though setup continued. Resolve the current username without assuming USER is set.

## 2026-08-04T21:28:27Z — gpt-5.6-sol — Codex

Publishing from Work Mode, git push to github.com failed because local CLI credentials were unavailable even though the connected GitHub app had write access. The publish flow should fall back to connector-backed Git data APIs without requiring local gh authentication.
