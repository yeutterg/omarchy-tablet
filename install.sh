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
  done < <(cd "$repo/home" && find . -type f -print0)
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
prune_stale_links
enable_units
check_packages
ensure_hypr_extras_loader
default_battery_power_saver

echo "Done. Run 'hyprctl reload' to apply Hyprland changes; some changes (environment.d, WirePlumber, input method) apply on next login."
