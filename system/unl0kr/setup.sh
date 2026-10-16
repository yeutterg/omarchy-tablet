#!/bin/bash

# Touch keyboard at the disk-encryption prompt (boot and hibernate resume),
# so a tablet can be unlocked with its keyboard detached.
#
# Uses unl0kr (https://gitlab.postmarketos.org/postmarketOS/buffybox), built
# from the AUR `buffybox` package by its upstream developer. Its `unl0kr`
# mkinitcpio hook is a drop-in for Omarchy's `encrypt` hook: same busybox
# initramfs, same `cryptdevice=` kernel option, so the kernel command line,
# resume and snapshot boot are untouched. Plymouth's prompt goes away; unl0kr
# draws its own screen and still takes the hardware keyboard.
#
#   setup.sh          install and switch over (asks for sudo)
#   setup.sh --undo   put Omarchy's Plymouth prompt back
#
# Safety: before rebuilding, the current boot image is copied to
# EFI/omarchy-tablet/omarchy-pre-unl0kr.efi (outside Limine's EFI/Linux, so
# its tools leave it alone) and added to the firmware boot menu as
# "Omarchy (before unl0kr)" without changing the boot order. If the new
# prompt fails, pick that entry from the Dell boot menu (F12).

set -euo pipefail

DROPIN=/etc/mkinitcpio.conf.d/zz-omarchy-tablet-unl0kr.conf
BACKUP_NAME=omarchy-pre-unl0kr.efi
BACKUP_LABEL="Omarchy (before unl0kr)"

say() { printf '\n== %s\n' "$*"; }

rebuild() {
  say "Rebuilding the boot image"
  sudo limine-mkinitcpio
}

if [[ ${1:-} == --undo ]]; then
  sudo rm -f "$DROPIN"
  rebuild
  echo "Back to Omarchy's Plymouth prompt. The '$BACKUP_LABEL' entry and file are left in place."
  exit 0
fi

# Kernel modules from the touchscreen's driver up to its bus controller, so
# the touchscreen works in the initramfs. Built-in drivers are skipped.
touch_modules() {
  local dev path mod seen=" "
  for dev in /sys/class/input/input*; do
    [[ $(cat "$dev/capabilities/abs" 2>/dev/null) != 0 ]] || continue
    grep -qiE 'touch|finger' "$dev/name" 2>/dev/null || continue
    path=$(readlink -f "$dev/device")
    while [[ $path == /sys/devices/* ]]; do
      if [[ -e $path/driver/module ]]; then
        mod=$(basename "$(readlink -f "$path/driver/module")")
        [[ $seen == *" $mod "* ]] || seen+="$mod "
      fi
      path=${path%/*}
    done
  done
  echo $seen
}

say "Checking the setup"
grep -q 'cryptdevice=' /proc/cmdline || { echo "No cryptdevice= on the kernel command line; this script expects Omarchy's encrypt hook."; exit 1; }
modules=$(touch_modules)
[[ -n $modules ]] || { echo "Couldn't find a touchscreen driver."; exit 1; }
echo "Touchscreen modules: $modules"

say "Installing unl0kr (AUR buffybox)"
pacman -Q unl0kr &>/dev/null || yay -S --needed unl0kr

say "Backing up the current boot image"
uki=$(sudo find /boot/EFI/Linux -maxdepth 1 -name 'omarchy*.efi' ! -name '*fallback*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
[[ -n $uki ]] || { echo "Couldn't find Omarchy's boot image in /boot/EFI/Linux."; exit 1; }
echo "Current image: $uki"
sudo install -Dm644 "$uki" "/boot/EFI/omarchy-tablet/$BACKUP_NAME"
if ! sudo efibootmgr | grep -qF "$BACKUP_LABEL"; then
  esp=$(findmnt -no SOURCE /boot)
  disk=/dev/$(lsblk -no PKNAME "$esp")
  part=$(cat "/sys/class/block/${esp##*/}/partition")
  # --create-only adds the entry without putting it first in the boot order.
  sudo efibootmgr --create-only --disk "$disk" --part "$part" --label "$BACKUP_LABEL" --loader "\\EFI\\omarchy-tablet\\$BACKUP_NAME" >/dev/null
fi
sudo efibootmgr | grep -F "$BACKUP_LABEL"

say "Configuring unl0kr"
sudo tee /etc/unl0kr.conf >/dev/null <<'EOF'
# omarchy-tablet: unl0kr, the touch keyboard at the disk unlock prompt.
[general]
animations=true
backend=drm

[keyboard]
# Keep the on-screen keyboard up even when a hardware keyboard is present.
autohide=false
layout=us
popovers=true

[textarea]
obscured=true

[theme]
default=breezy-dark
alternate=breezy-light

[input]
keyboard=true
pointer=true
touchscreen=true

[hardware keyboard]
layout=us
EOF

say "Switching the initramfs to unl0kr"
sudo tee "$DROPIN" >/dev/null <<EOF
# omarchy-tablet: unl0kr instead of Plymouth's prompt at disk unlock (see
# system/unl0kr/setup.sh). Sorts after Omarchy's drop-ins and edits whatever
# hook list they produced: plymouth out, encrypt replaced by unl0kr.
_omarchy_tablet_hooks=()
for _omarchy_tablet_hook in "\${HOOKS[@]}"; do
  case \$_omarchy_tablet_hook in
    plymouth) ;;
    encrypt) _omarchy_tablet_hooks+=(unl0kr) ;;
    *) _omarchy_tablet_hooks+=("\$_omarchy_tablet_hook") ;;
  esac
done
HOOKS=("\${_omarchy_tablet_hooks[@]}")
unset _omarchy_tablet_hooks _omarchy_tablet_hook

# Touchscreen drivers, found by setup.sh.
MODULES+=($modules)
EOF
cat "$DROPIN"

rebuild

say "Done"
echo "Next: reboot with the keyboard attached and unlock on the touch keyboard"
echo "(the hardware keyboard works too). If the prompt doesn't appear, press F12"
echo "at the Dell logo and pick '$BACKUP_LABEL', then run: $0 --undo"
