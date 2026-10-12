#!/usr/bin/env bash
# Read-only advisory audit for new Python in a Git worktree.
# Findings do not fail the command. Existing code is not automatically forbidden.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-python-growth.sh [--base REF] [REPOSITORY]

Inspect changes against the branch point with origin/main (or master/trunk),
including staged, unstaged and non-ignored untracked files. --base compares
against the given exact Git revision instead. Default repository: current dir.

Findings are advisory (exit 0). Invalid input or Git errors exit 2.
No fetch, commits, hooks, CI, or project files are changed.
EOF
}

repo="."
selected_repo=0
requested_base=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      if [[ $# -lt 2 || -z "$2" ]]; then usage >&2; exit 2; fi
      requested_base="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
    *)
      if [[ "$selected_repo" -eq 1 ]]; then usage >&2; exit 2; fi
      repo="$1"
      selected_repo=1
      shift
      ;;
  esac
done

if ! root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null); then
  printf 'Not a Git worktree: %s\n' "$repo" >&2
  exit 2
fi
if [[ -n "$requested_base" ]]; then
  if ! baseline=$(git -C "$root" rev-parse --verify "$requested_base^{commit}" 2>/dev/null); then
    printf 'Unknown baseline: %s\n' "$requested_base" >&2
    exit 2
  fi
  explanation="$requested_base (explicit)"
else
  upstream=""
  for candidate in refs/remotes/origin/HEAD refs/remotes/origin/main \
    refs/heads/main refs/remotes/origin/master refs/heads/master \
    refs/remotes/origin/trunk refs/heads/trunk; do
    if git -C "$root" rev-parse --verify -q "$candidate^{commit}" >/dev/null 2>&1; then
      upstream="$candidate"
      break
    fi
  done
  if [[ -n "$upstream" ]]; then
    if ! baseline=$(git -C "$root" merge-base HEAD "$upstream"); then
      printf 'Cannot find a common ancestor with %s\n' "$upstream" >&2
      exit 2
    fi
    explanation="merge-base with $upstream"
  else
    baseline=$(git -C "$root" rev-parse --verify HEAD)
    explanation="HEAD (no local main/master/trunk reference)"
  fi
fi

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
git -C "$root" diff --no-ext-diff --name-only --diff-filter=ACMR -z "$baseline" -- > "$temporary/tracked"
git -C "$root" ls-files --others --exclude-standard -z > "$temporary/untracked"

# Detect only newly added lines, not pre-existing interpreter commands.
python_command='(^|[^[:alnum:]_.-])(python([0-9]+([.][0-9]+)?)?|pip3?|pytest|poetry)([[:space:];|<>()]|$)|(^|[[:space:];])uv[[:space:]]+(run|sync|pip)([[:space:]]|$)'
added_lines() {
  git -C "$root" diff --no-ext-diff --unified=0 "$baseline" -- "$1" |
    awk '/^\+\+\+ / {next} /^\+/ {print substr($0, 2)}'
}
has_added_lines() {
  git -C "$root" diff --no-ext-diff --unified=0 "$baseline" -- "$1" |
    awk '/^\+\+\+ / {next} /^\+/ {found=1; exit} END {exit !found}'
}

new_count=0
legacy_count=0
entry_count=0
scan_file() {
  file="$1"
  kind="$2"
  absolute="$root/$file"
  [[ -e "$absolute" || -L "$absolute" ]] || return 0

  is_new=0
  if [[ "$kind" == untracked ]] || ! git -C "$root" cat-file -e "$baseline:$file" 2>/dev/null; then
    is_new=1
  fi

  case "$file" in
    *.py|*.pyw|*.pyi|*.py.template|*.ipynb)
      if [[ "$is_new" -eq 1 ]]; then
        printf 'NEW_PYTHON_FILE  %s\n' "$file"
        ((new_count+=1))
      elif has_added_lines "$file"; then
        printf 'LEGACY_PYTHON_EDIT  %s (review existing Python changes)\n' "$file"
        ((legacy_count+=1))
      fi
      return 0
      ;;
    pyproject.toml|*/pyproject.toml|requirements*.txt|*/requirements*.txt|\
    Pipfile|*/Pipfile|Pipfile.lock|*/Pipfile.lock|poetry.lock|*/poetry.lock|\
    uv.lock|*/uv.lock|.python-version|*/.python-version|tox.ini|*/tox.ini)
      if [[ "$is_new" -eq 1 ]]; then
        printf 'PYTHON_MANIFEST  %s (new, review exemption)\n' "$file"
        ((new_count+=1))
      elif has_added_lines "$file"; then
        printf 'PYTHON_MANIFEST_EDIT  %s (review dependency changes)\n' "$file"
        ((legacy_count+=1))
      fi
      return 0
      ;;
  esac

  # Never follow a link into another project while inspecting content.
  [[ -f "$absolute" && ! -L "$absolute" ]] || return 0
  first_line=""
  IFS= read -r first_line < "$absolute" || :
  if [[ "$first_line" == '#!'* && "$first_line" == *python* ]]; then
    if [[ "$is_new" -eq 1 ]] || [[ "$kind" == untracked ]] ||
      added_lines "$file" | grep -Eq '^#!.*python'; then
      printf 'PYTHON_SHEBANG  %s\n' "$file"
      ((entry_count+=1))
      return 0
    fi
  fi

  case "$file" in
    *.sh|*.bash|*.zsh|*.fish|*.yml|*.yaml|*.json|*.toml|*.ts|*.tsx|\
    *.js|*.jsx|*.mjs|*.cjs|*.rs|*.go|*.tf|*.service|\
    Dockerfile|*/Dockerfile|Dockerfile.*|*/Dockerfile.*|\
    Makefile|*/Makefile|*.mk|bin/*|*/bin/*|scripts/*|*/scripts/*)
      if [[ "$kind" == untracked ]]; then
        if grep -aEq "$python_command" "$absolute"; then
          printf 'PYTHON_INVOCATION  %s (new file)\n' "$file"
          ((entry_count+=1))
        fi
      elif added_lines "$file" | grep -Eq "$python_command"; then
        printf 'PYTHON_INVOCATION  %s (added invocation)\n' "$file"
        ((entry_count+=1))
      fi
      ;;
  esac
}

printf 'Python growth audit: %s\n' "$root"
printf 'Baseline: %s (%s)\n' "$(git -C "$root" rev-parse --short "$baseline")" "$explanation"
while IFS= read -r -d '' file; do scan_file "$file" tracked; done < "$temporary/tracked"
while IFS= read -r -d '' file; do scan_file "$file" untracked; done < "$temporary/untracked"
printf 'Summary: %d new files/manifests, %d legacy edits, %d interpreter references.\n' \
  "$new_count" "$legacy_count" "$entry_count"
printf 'Advisory only: findings require review; approved Python scopes are not auto-classified.\n'
