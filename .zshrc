# Reuse the universal zsh bootstrap when `.zshrc` is sourced manually in an
# already-running shell.
if [[ -z ${__DOTFILES_ENV_READY:-} && -r "${ZDOTDIR:-$HOME}/.zshenv" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshenv"
fi

# Non-interactive shells should not load prompt tooling or other interactive
# shell setup. This prevents `source ~/.zshrc` from emitting starship errors
# in CLI-only commands.
if [[ ! -o interactive ]]; then
  return 0
fi

# Re-sourcing configuration must not duplicate hooks, plugins or completion work.
[[ -n ${__DOTFILES_RC_READY:-} ]] && return 0
typeset -g __DOTFILES_RC_READY=1

# Plugin installation is an explicit maintenance action, never startup work.
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"
  DOTFILES_ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  ZINIT[ZCOMPDUMP_PATH]="${DOTFILES_ZSH_CACHE_DIR}/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"
fi

# Only load previously installed plugins. Missing plugins can be installed with
# the normal zinit commands explicitly; opening a terminal never downloads them.
dotfiles_zinit_snippet() {
  (( $+functions[zinit] )) || return 0
  local snippet="$1"
  [[ -r "${ZINIT[SNIPPETS_DIR]}/$snippet/$snippet" ]] || return 0
  zinit snippet "$snippet"
}
dotfiles_zinit_light() {
  (( $+functions[zinit] )) || return 0
  [[ -d "${ZINIT[PLUGINS_DIR]}/${1//\//---}" ]] || return 0
  zinit light "$1"
}

# Keep this file minimal (bootstrap/loader only).
# Put all regular configuration in modules under ~/.zshrc.d/.
#
# Modules load recursively in lexical path order, so top-level numbered
# folders define the coarse order and numbered files inside each folder
# define the local order.
ZSHRC_D="${ZDOTDIR:-$HOME}/.zshrc.d"
if [[ -d "$ZSHRC_D" ]]; then
  for __dotfiles_module in "$ZSHRC_D"/**/*.zsh(N); do
    # Core and paths were already loaded by .zshenv.
    case "$__dotfiles_module" in
      */00-core/00-core.zsh|*/10-shell/00-paths.zsh) continue ;;
    esac
    source "$__dotfiles_module"
  done
  unset __dotfiles_module
fi
