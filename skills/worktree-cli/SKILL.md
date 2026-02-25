---
name: worktree-cli
description: Manage and extend a custom Git worktree CLI (Go + Cobra) plus zsh integration for interactive switching/creation/removal, workspace sync, and dotfiles wiring. Use this skill when users ask to add or modify worktree commands, shell wrappers, completions, or VS Code workspace synchronization behavior.
---

# Worktree CLI Skill

Use this skill when working on the custom `worktree` CLI in dotfiles.

## Scope

This skill covers:
- Go CLI command behavior in `tools/worktree`
- Cobra subcommands, flags, completions
- zsh wrapper behavior in `.zshrc.d/35-worktree.zsh`
- alias/completion wiring in zsh modules
- VS Code workspace folder sync behavior for worktrees

## Source of truth files

- CLI: `tools/worktree/internal/app/root.go`
- Completion command: `tools/worktree/internal/app/completion.go`
- Entrypoint: `tools/worktree/cmd/worktree/main.go`
- zsh wrapper/install hook: `.zshrc.d/35-worktree.zsh`
- aliases: `.zshrc.d/20-aliases.zsh`
- completions loader: `.zshrc.d/40-completions.zsh`

For command semantics and examples, read `references/command-map.md`.

## Working rules

1. Always resolve operations from main/base worktree context, not current satellite cwd.
2. `switch` must resolve from actual `git worktree list` data.
3. Interactive shell UX belongs in zsh wrapper, not in Go binary.
4. Binary should print paths or `cd ...` output; shell wrapper does parent-shell `cd` via `eval`.
5. Workspace sync should only modify the first `*.code-workspace` in the main worktree root.

## Implementation checklist

When adding/changing commands:
1. Update Cobra command registration (`NewRootCommand`).
2. Add command options struct if needed.
3. Add help examples and flag completions.
4. Keep branch/path resolution consistent with shared helpers.
5. Run `gofmt` and `go build ./...` in `tools/worktree`.
6. Ensure zsh wrapper behavior still matches command output contract.

## Validation commands

Run from `tools/worktree`:
- `gofmt -w internal/app/root.go internal/app/completion.go cmd/worktree/main.go`
- `go build ./...`
- `go run ./cmd/worktree --help`
- `go run ./cmd/worktree list --help`
- `go run ./cmd/worktree new --help`
- `go run ./cmd/worktree switch --help`
- `go run ./cmd/worktree remove --help`
- `go run ./cmd/worktree sync --help`

Then reload shell if zsh modules changed:
- `source ~/.zshrc`

## Future TODO direction

- Add config support (e.g. `~/.config/worktree/config.*`) for feature toggles.
- Make workspace-sync default disabled, enable via explicit config/flag.
