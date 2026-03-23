# Seed a minimal system PATH early so shell startup does not depend on
# inherited environment state before Homebrew and modules run.
if [[ -z "${PATH:-}" ]]; then
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fi

# Non-interactive shells should not load prompt tooling or other interactive
# shell setup. This prevents `source ~/.zshrc` from emitting starship errors
# in CLI-only commands.
if [[ ! -o interactive ]]; then
  return 0
fi

# Initialize Homebrew/Linuxbrew environment
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
  eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

for system_dir in /usr/bin /bin /usr/sbin /sbin; do
  case ":${PATH:-}:" in
    *":$system_dir:"*) ;;
    *) PATH="${PATH:+$PATH:}$system_dir" ;;
  esac
done
export PATH

# Ensure Zinit exists
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "${ZINIT_HOME}" ]]; then
  echo "Zinit not found, installing..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load Zinit
source "${ZINIT_HOME}/zinit.zsh"

DOTFILES_ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$DOTFILES_ZSH_CACHE_DIR"
ZINIT[ZCOMPDUMP_PATH]="${DOTFILES_ZSH_CACHE_DIR}/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"

# Keep this file minimal (bootstrap/loader only).
# Put all regular configuration in modules under ~/.zshrc.d/.
#
# Modules load recursively in lexical path order, so top-level numbered
# folders define the coarse order and numbered files inside each folder
# define the local order.
ZSHRC_D="${ZDOTDIR:-$HOME}/.zshrc.d"
if [[ -d "$ZSHRC_D" ]]; then
  for __dotfiles_module in "$ZSHRC_D"/**/*.zsh(N); do
    source "$__dotfiles_module"
  done
  unset __dotfiles_module
fi

# fnm
FNM_PATH="/home/oli/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
