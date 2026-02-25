# Worktree CLI Command Map

## Current commands

- `worktree list`
  - Lists branches that have active worktrees
  - Marks main worktree as `* <branch> (main)`
  - `--plain` prints raw branch names only

- `worktree new`
  - Creates worktree from branch
  - Supports `--branch`, `--base`, `--clean`, `--cd`
  - Adds new worktree folder into VS Code workspace when available

- `worktree switch`
  - Resolves branch/path to worktree path
  - `--cd` emits shell command for wrapper eval
  - Completion suggests active worktree branches

- `worktree remove`
  - Removes worktree by positional, `--branch`, or `--path`
  - Supports `--force`
  - Removes corresponding VS Code workspace folder entry

- `worktree sync`
  - Backfills existing worktrees into VS Code workspace folders
  - Only updates workspace file in main/base worktree root

## zsh wrapper behavior

- `worktree switch` with arg: auto-`cd` using `--cd` output
- `worktree switch` without arg: interactive `fzf` picker
- `worktree new` without args: interactive existing-branch picker
- `worktree new -c|--create`: interactive new-branch prompt
- `worktree remove` without args: interactive `fzf` picker

## Key contract

The Go binary does not change parent shell directory directly. It prints values/commands; zsh wrapper performs the shell `cd`.
