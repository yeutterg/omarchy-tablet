#!/bin/bash

# Link this repo's home/ tree into $HOME (home/.config/x -> ~/.config/x).
# Safe to re-run. A real file already at a target is moved aside to
# <file>.pre-dotfiles before being replaced by a link. Pass --force to install
# on hardware this repo doesn't recognise.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
force=${1:-}

# Only for tablets and detachables: DMI chassis type 30 (tablet), 31
# (convertible) or 32 (detachable).
chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)
if [[ ! $chassis =~ ^3[012]$ && $force != --force ]]; then
  echo "This doesn't look like a tablet (chassis type ${chassis:-unknown}). Rerun with --force to install anyway."
  exit 1
fi

link_tree() {
  local rel target
  while IFS= read -r -d '' rel; do
    rel=${rel#./}
    target=$HOME/$rel
    mkdir -p "$(dirname "$target")"

    if [[ -e $target && ! -L $target ]]; then
      mv "$target" "$target.pre-dotfiles"
      echo "Moved existing $target to $target.pre-dotfiles"
    fi

    ln -sfn "$repo/home/$rel" "$target"
    echo "Linked $target"
  done < <(cd "$repo/home" && find . -type f -not -path './.config/omarchy/plugins/*' -print0)
}

# Tablet features that are their own Omarchy plugins. Each is added from git
# once (then updated with `omarchy plugin update`) and enabled; enabling puts
# its button in the bar (the display plugin replaces the stock display panel).
plugin_deps=(
  "io.github.yeutterg.onscreen-keyboard https://github.com/yeutterg/omarchy-on-screen-keyboard"
  "io.github.yeutterg.display-rotation https://github.com/yeutterg/omarchy-display-rotation"
  "io.github.yeutterg.lock-pin https://github.com/yeutterg/omarchy-lock-pin"
  "io.github.yeutterg.tray-touch https://github.com/yeutterg/omarchy-tray-touch"
)
install_plugin_deps() {
  local dep id url
  for dep in "${plugin_deps[@]}"; do
    read -r id url <<<"$dep"
    if [[ ! -e $HOME/.config/omarchy/plugins/$id ]]; then
      omarchy-plugin-add "$url" --enable --yes || { echo "Couldn't add $id; see $url"; continue; }
    fi
  done
  omarchy-bar put io.github.yeutterg.onscreen-keyboard --section right >/dev/null 2>&1 || true
  # Earlier versions of this repo: squeekboard was the keyboard,
  # tablet-autorotate.service rotated the screen, and the lock screen was a
  # copied tablet.lock plugin with its PIN under omarchy-tablet/. Clean up.
  pkill -x squeekboard 2>/dev/null && echo "Stopped squeekboard" || true
  if systemctl --user is-active --quiet tablet-autorotate.service 2>/dev/null; then
    systemctl --user stop tablet-autorotate.service && echo "Stopped tablet-autorotate.service"
  fi
  local old_lock=$HOME/.config/omarchy/plugins/tablet.lock
  local old_pin=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-tablet/lock-pin
  local new_pin=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-lock-pin
  if [[ -d $old_pin && ! -e $new_pin/hash ]]; then
    mkdir -p "$new_pin" && chmod 700 "$new_pin" && cp -a "$old_pin/." "$new_pin/" && echo "Moved the lock PIN to $new_pin"
  fi
  [[ -e $new_pin/hash || ! -e $old_pin/hash ]] && rm -rf "$old_pin"
  if [[ -d $old_lock ]]; then
    omarchy-plugin-disable tablet.lock >/dev/null 2>&1 || true
    rm -rf "$old_lock" && echo "Removed the old tablet.lock plugin"
  fi
}

# hyprgrass: touchscreen move/resize for windows (hypr/extras/55-touch-windows.lua).
# hyprpm builds it against the running Hyprland; it asks for sudo the first
# time. After a Hyprland update, `hyprpm update` rebuilds it.
install_hyprgrass() {
  command -v hyprpm >/dev/null || return 0
  hyprpm list 2>/dev/null | grep -q hyprgrass && return 0
  if ! pacman -Q meson glm &>/dev/null; then
    echo "Skipping hyprgrass: install meson and glm first (see packages.txt)"
    return 0
  fi
  hyprpm update && hyprpm add https://github.com/horriblename/hyprgrass && hyprpm enable hyprgrass \
    && hyprpm reload -n && echo "Installed hyprgrass" \
    || echo "Couldn't install hyprgrass; run: hyprpm update && hyprpm add https://github.com/horriblename/hyprgrass && hyprpm enable hyprgrass"
}

# Remove links into this repo whose file was moved or deleted here.
prune_stale_links() {
  local link
  while IFS= read -r -d '' link; do
    if [[ $(readlink "$link") == "$repo/"* && ! -e $link ]]; then
      rm "$link"
      echo "Removed stale link $link"
    fi
  done < <(find "$HOME/.config" "$HOME/.local" "$HOME/.claude" -type l -print0 2>/dev/null)
}

# Enable the systemd user units this repo ships (those with an [Install] section).
enable_units() {
  local unit
  [[ -d $repo/home/.config/systemd/user ]] || return 0
  systemctl --user daemon-reload
  for unit in "$repo"/home/.config/systemd/user/*.{service,path,timer}; do
    [[ -f $unit ]] && grep -q '^\[Install\]' "$unit" || continue
    systemctl --user enable --now "${unit##*/}" && echo "Enabled ${unit##*/}"
  done
}

# Report packages from packages.txt that aren't installed (doesn't install them).
check_packages() {
  local missing
  [[ -f $repo/packages.txt ]] || return 0
  missing=$(grep -vE '^\s*(#|$)' "$repo/packages.txt" | while read -r pkg; do pacman -Q "$pkg" &>/dev/null || echo "$pkg"; done)
  if [[ -n $missing ]]; then
    echo "Missing packages. Install with:"
    echo "  sudo pacman -S --needed $(echo $missing)"
  fi
}

# Hyprland only loads ~/.config/hypr/extras/*.lua once hyprland.lua asks for it.
# Add that one line (after Omarchy's toggles, or at the end) if it's missing.
ensure_hypr_extras_loader() {
  local conf=$HOME/.config/hypr/hyprland.lua
  local loader
  loader=$(cat <<'LUA'
for file in io.popen("find -L ~/.config/hypr/extras -maxdepth 1 -type f -name '*.lua' 2>/dev/null | sort"):lines() do dofile(file) end
LUA
)
  [[ -d $repo/home/.config/hypr/extras && -f $conf ]] || return 0
  grep -qF "$loader" "$conf" && return 0

  local block="
-- Drop-in files from repos like omarchy-tablet, loaded in name order.
$loader"
  if grep -q '^require("default.hypr.toggles")' "$conf"; then
    BLOCK=$block awk '{ print } /^require\("default\.hypr\.toggles"\)/ { print ENVIRON["BLOCK"] }' "$conf" >"$conf.tmp"
    mv "$conf.tmp" "$conf"
  else
    printf '%s\n' "$block" >>"$conf"
  fi
  echo "Added the hypr/extras loader to $conf"
}

# Power saver on battery by default. Omarchy saves one profile per power
# source and applies it when the power source changes, falling back to
# balanced on battery. Seed power-saver only when nothing is saved yet, so a
# profile picked later from the menu still wins.
default_battery_power_saver() {
  local state=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/powerprofiles/battery
  [[ -e $state ]] && return 0
  mkdir -p "${state%/*}"
  echo power-saver >"$state"
  echo "Set power-saver as the battery power profile"
  omarchy-powerprofiles-set autodetect 2>/dev/null || true
}

link_tree
install_plugin_deps
install_hyprgrass
prune_stale_links
enable_units
check_packages
ensure_hypr_extras_loader
default_battery_power_saver

echo "Done. Run 'hyprctl reload' to apply Hyprland changes; some changes (environment.d, WirePlumber, input method) apply on next login."
