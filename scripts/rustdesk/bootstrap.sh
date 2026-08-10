#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPOSITORY="DotNaos/dotfiles"
DOTFILES_REF="${RUSTDESK_DOTFILES_REF:-main}"
CONFIG_URL="https://raw.githubusercontent.com/$DOTFILES_REPOSITORY/$DOTFILES_REF/config/rustdesk.env"
RUSTDESK_RELEASE_API="https://api.github.com/repos/rustdesk/rustdesk/releases/latest"

log() {
  printf '[rustdesk] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

is_local_script() {
  [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]
}

local_config_file() {
  local root_dir

  is_local_script || return 1
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s/config/rustdesk.env\n' "$root_dir"
}

ensure_root() {
  [[ "$EUID" -eq 0 ]] && return 0
  is_local_script || fail "Pipe this script to 'sudo -E bash' or run the local file with sudo."
  require_command sudo
  exec sudo --preserve-env=RUSTDESK_CONFIG_FILE,RUSTDESK_CONFIG_STRING,RUSTDESK_ID_SERVER,RUSTDESK_RELAY_SERVER,RUSTDESK_PUBLIC_KEY,RUSTDESK_PASSWORD,RUSTDESK_DOTFILES_REF \
    bash "${BASH_SOURCE[0]}" "$@"
}

load_config() {
  local config_file="${RUSTDESK_CONFIG_FILE:-}"

  if [[ -z "$config_file" ]]; then
    config_file="$(local_config_file || true)"
  fi

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
  else
    config_file="$WORK_DIR/rustdesk.env"
    log "Loading public configuration from $CONFIG_URL"
    curl -fsSL "$CONFIG_URL" -o "$config_file"
    # shellcheck source=/dev/null
    source "$config_file"
  fi

  CONFIG_STRING="${RUSTDESK_CONFIG_STRING:-${RUSTDESK_REPO_CONFIG_STRING:-}}"
  ID_SERVER="${RUSTDESK_ID_SERVER:-${RUSTDESK_REPO_ID_SERVER:-}}"
  RELAY_SERVER="${RUSTDESK_RELAY_SERVER:-${RUSTDESK_REPO_RELAY_SERVER:-}}"
  PUBLIC_KEY="${RUSTDESK_PUBLIC_KEY:-${RUSTDESK_REPO_PUBLIC_KEY:-}}"

  if [[ -z "$CONFIG_STRING" && ( -z "$ID_SERVER" || -z "$PUBLIC_KEY" ) ]]; then
    fail "Set RUSTDESK_CONFIG_STRING, or configure both RUSTDESK_ID_SERVER and RUSTDESK_PUBLIC_KEY."
  fi
}

latest_version() {
  local release_json="$WORK_DIR/release.json"
  local version

  curl -fsSL "$RUSTDESK_RELEASE_API" -o "$release_json"
  version="$(awk -F '"' '/"tag_name"/ { print $4; exit }' "$release_json")"
  [[ -n "$version" ]] || fail "Could not determine the latest RustDesk version."
  printf '%s\n' "$version"
}

machine_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64\n' ;;
    arm64|aarch64) printf 'aarch64\n' ;;
    armv7l|armv7) printf 'armv7\n' ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac
}

download_release_asset() {
  local version="$1"
  local asset_name="$2"
  local destination="$3"
  local url="https://github.com/rustdesk/rustdesk/releases/download/$version/$asset_name"

  log "Downloading RustDesk $version ($asset_name)."
  curl -fL "$url" -o "$destination"
}

installed_version() {
  local binary="$1"

  [[ -x "$binary" ]] || return 0
  "$binary" --version 2>/dev/null | awk 'NF { print; exit }' || true
}

install_linux() {
  local version="$1"
  local arch="$2"
  local current_version
  local package

  RUSTDESK_BINARY="$(command -v rustdesk || true)"
  current_version="$(installed_version "${RUSTDESK_BINARY:-/nonexistent}")"
  if [[ "$current_version" == "$version" ]]; then
    log "RustDesk $version is already installed."
  elif command -v apt-get >/dev/null 2>&1; then
    package="$WORK_DIR/rustdesk.deb"
    if [[ "$arch" == "armv7" ]]; then
      download_release_asset "$version" "rustdesk-$version-armv7-sciter.deb" "$package"
    else
      download_release_asset "$version" "rustdesk-$version-$arch.deb" "$package"
    fi
    apt-get install -y "$package"
  elif command -v dnf >/dev/null 2>&1; then
    [[ "$arch" != "armv7" ]] || fail "RustDesk does not publish an RPM for armv7."
    package="$WORK_DIR/rustdesk.rpm"
    download_release_asset "$version" "rustdesk-$version-0.$arch.rpm" "$package"
    dnf install -y "$package"
  elif command -v yum >/dev/null 2>&1; then
    [[ "$arch" != "armv7" ]] || fail "RustDesk does not publish an RPM for armv7."
    package="$WORK_DIR/rustdesk.rpm"
    download_release_asset "$version" "rustdesk-$version-0.$arch.rpm" "$package"
    yum localinstall -y "$package"
  elif command -v pacman >/dev/null 2>&1; then
    [[ "$arch" == "x86_64" ]] || fail "RustDesk publishes its Arch package only for x86_64."
    package="$WORK_DIR/rustdesk.pkg.tar.zst"
    download_release_asset "$version" "rustdesk-$version-0-x86_64.pkg.tar.zst" "$package"
    pacman --noconfirm -U "$package"
  else
    fail "Supported package manager not found (apt, dnf, yum or pacman)."
  fi

  RUSTDESK_BINARY="$(command -v rustdesk || true)"
  [[ -x "$RUSTDESK_BINARY" ]] || fail "RustDesk binary was not installed."
  command -v systemctl >/dev/null 2>&1 || fail "RustDesk's official Linux package requires systemd."
  systemctl daemon-reload
  systemctl enable --now rustdesk
}

macos_console_user() {
  local user="${SUDO_USER:-}"

  if [[ -z "$user" || "$user" == "root" ]]; then
    user="$(stat -f '%Su' /dev/console 2>/dev/null || true)"
  fi
  [[ "$user" != "root" && "$user" != "loginwindow" ]] || user=""
  printf '%s\n' "$user"
}

install_macos_service() {
  local version="$1"
  local daemon_path="/Library/LaunchDaemons/com.carriez.RustDesk_service.plist"
  local agent_path="/Library/LaunchAgents/com.carriez.RustDesk_server.plist"
  local daemon_source="$WORK_DIR/daemon.plist"
  local agent_source="$WORK_DIR/agent.plist"
  local console_user console_uid console_home user_prefs root_prefs config_name

  curl -fsSL "https://raw.githubusercontent.com/rustdesk/rustdesk/$version/src/platform/privileges_scripts/daemon.plist" -o "$daemon_source"
  curl -fsSL "https://raw.githubusercontent.com/rustdesk/rustdesk/$version/src/platform/privileges_scripts/agent.plist" -o "$agent_source"
  install -o root -g wheel -m 0644 "$daemon_source" "$daemon_path"
  install -o root -g wheel -m 0644 "$agent_source" "$agent_path"

  console_user="$(macos_console_user)"
  if [[ -n "$console_user" ]]; then
    console_uid="$(id -u "$console_user")"
    console_home="$(dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | awk '{ print $2 }')"
    [[ -n "$console_home" ]] || console_home="/Users/$console_user"
    user_prefs="$console_home/Library/Preferences/com.carriez.RustDesk"
    root_prefs="/var/root/Library/Preferences/com.carriez.RustDesk"
    mkdir -p "$user_prefs" "$root_prefs"
    for config_name in RustDesk.toml RustDesk2.toml; do
      if [[ ! -e "$user_prefs/$config_name" ]]; then
        install -o "$console_user" -g staff -m 0600 /dev/null "$user_prefs/$config_name"
      fi
      if [[ ! -e "$root_prefs/$config_name" ]]; then
        install -o root -g wheel -m 0600 "$user_prefs/$config_name" "$root_prefs/$config_name"
      fi
    done
  fi

  launchctl bootout system/com.carriez.RustDesk_service >/dev/null 2>&1 || true
  launchctl bootstrap system "$daemon_path"
  launchctl enable system/com.carriez.RustDesk_service
  launchctl kickstart -k system/com.carriez.RustDesk_service

  if [[ -n "$console_user" ]]; then
    launchctl bootout "gui/$console_uid/com.carriez.RustDesk_server" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$console_uid" "$agent_path" >/dev/null 2>&1 || true
    launchctl enable "gui/$console_uid/com.carriez.RustDesk_server"
    launchctl kickstart -k "gui/$console_uid/com.carriez.RustDesk_server" >/dev/null 2>&1 || \
      log "The RustDesk agent will start at the next graphical login."
  else
    log "No graphical console user found; the RustDesk agent will start at login."
  fi
}

install_macos() {
  local version="$1"
  local arch="$2"
  local current_version
  local dmg="$WORK_DIR/rustdesk.dmg"
  local mount_point="$WORK_DIR/mount"

  RUSTDESK_BINARY="/Applications/RustDesk.app/Contents/MacOS/RustDesk"
  current_version="$(installed_version "$RUSTDESK_BINARY")"
  if [[ "$current_version" == "$version" ]]; then
    log "RustDesk $version is already installed."
  else
    [[ "$arch" != "armv7" ]] || fail "RustDesk does not support macOS armv7."
    download_release_asset "$version" "rustdesk-$version-$arch.dmg" "$dmg"
    mkdir -p "$mount_point"
    hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_point" >/dev/null
    ditto "$mount_point/RustDesk.app" /Applications/RustDesk.app
    hdiutil detach "$mount_point" >/dev/null
  fi

  [[ -x "$RUSTDESK_BINARY" ]] || fail "RustDesk application was not installed."
  install_macos_service "$version"
}

apply_client_config() {
  local current_id_server current_key

  "$RUSTDESK_BINARY" --option stop-service "" >/dev/null

  if [[ -n "$CONFIG_STRING" ]]; then
    "$RUSTDESK_BINARY" --config "$CONFIG_STRING" >/dev/null
  else
    "$RUSTDESK_BINARY" --option custom-rendezvous-server "$ID_SERVER" >/dev/null
    "$RUSTDESK_BINARY" --option relay-server "$RELAY_SERVER" >/dev/null
    "$RUSTDESK_BINARY" --option key "$PUBLIC_KEY" >/dev/null
  fi

  if [[ -n "${RUSTDESK_PASSWORD:-}" ]]; then
    "$RUSTDESK_BINARY" --password "$RUSTDESK_PASSWORD" >/dev/null
  fi

  current_id_server="$($RUSTDESK_BINARY --option custom-rendezvous-server | awk 'NF { print; exit }')"
  current_key="$($RUSTDESK_BINARY --option key | awk 'NF { print; exit }')"
  [[ -n "$current_id_server" ]] || fail "RustDesk did not apply an ID server."
  [[ -n "$current_key" ]] || fail "RustDesk did not apply a public server key."

  if [[ -z "$CONFIG_STRING" ]]; then
    [[ "$current_id_server" == "$ID_SERVER" ]] || fail "RustDesk ID server verification failed."
    [[ "$current_key" == "$PUBLIC_KEY" ]] || fail "RustDesk public key verification failed."
  fi
}

restart_service() {
  case "$PLATFORM" in
    linux)
      systemctl restart rustdesk
      systemctl is-active --quiet rustdesk || fail "RustDesk service is not running."
      ;;
    macos)
      launchctl kickstart -k system/com.carriez.RustDesk_service
      ;;
  esac
}

print_device_id() {
  local device_id=""

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    device_id="$($RUSTDESK_BINARY --get-id | awk 'NF { print; exit }')"
    [[ -n "$device_id" && "$device_id" != "0" ]] && break
    sleep 2
  done
  [[ -n "$device_id" && "$device_id" != "0" ]] || fail "RustDesk did not return a device ID."
  printf 'RustDesk ID: %s\n' "$device_id"
}

require_command curl
ensure_root "$@"
WORK_DIR="$(mktemp -d /tmp/dotfiles-rustdesk.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
load_config
VERSION="$(latest_version)"
ARCH="$(machine_arch)"

case "$(uname -s)" in
  Linux)
    PLATFORM="linux"
    install_linux "$VERSION" "$ARCH"
    ;;
  Darwin)
    PLATFORM="macos"
    install_macos "$VERSION" "$ARCH"
    ;;
  *)
    fail "This script supports Linux and macOS only."
    ;;
esac

ACTUAL_VERSION="$(installed_version "$RUSTDESK_BINARY")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || fail "Expected RustDesk $VERSION, found ${ACTUAL_VERSION:-unknown}."
log "Verified RustDesk CLI version $ACTUAL_VERSION."
apply_client_config
restart_service
print_device_id
