#!/bin/bash

# Remove the files and plugins installed by this repo. Only symlinks that point
# back into this checkout are removed. Files saved by install.sh as
# *.pre-dotfiles are restored when their original path is free.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

plugin_ids=(
  io.github.yeutterg.onscreen-keyboard
  io.github.yeutterg.display-rotation
  io.github.yeutterg.lock-pin
  io.github.yeutterg.tray-touch
)

disable_services() {
  local unit
  for unit in stay-awake-agents.service stay-awake-cover.service; do
    systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  done
}

remove_plugins() {
  local id target
  for id in "${plugin_ids[@]}"; do
    target=$HOME/.config/omarchy/plugins/$id
    if [[ -e $target || -L $target ]]; then
      omarchy plugin remove "$id" --yes
    fi
  done
}

remove_repo_links() {
  local root link
  for root in "$HOME/.config" "$HOME/.local/bin"; do
    [[ -e $root ]] || continue
    while IFS= read -r -d '' link; do
      if [[ $(readlink "$link") == "$repo/"* ]]; then
        rm "$link"
        echo "Removed $link"
      fi
    done < <(find "$root" -type l -print0 2>/dev/null)
  done
}

restore_backups() {
  local backup target
  while IFS= read -r -d '' backup; do
    target=${backup%.pre-dotfiles}
    if [[ ! -e $target && ! -L $target ]]; then
      mv "$backup" "$target"
      echo "Restored $target"
    fi
  done < <(find "$HOME/.config" -type f -name '*.pre-dotfiles' -print0 2>/dev/null)
}

restore_battery_default() {
  local state=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/powerprofiles/battery
  if [[ -f $state && $(<"$state") == power-saver ]]; then
    rm "$state"
    omarchy-powerprofiles-set autodetect >/dev/null 2>&1 || true
    echo "Restored Omarchy's default battery profile selection"
  fi
}

disable_services
remove_plugins
remove_repo_links
restore_backups
restore_battery_default

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user reset-failed omarchy-fcitx5.service >/dev/null 2>&1 || true
systemctl --user start omarchy-fcitx5.service >/dev/null 2>&1 || true

hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || true

echo "Removed omarchy-tablet. Log out and back in once to restore the fcitx5 input-method environment."
