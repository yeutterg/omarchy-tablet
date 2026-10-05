# Omarchy Dotfiles for Tablets

[Omarchy](https://omarchy.org) customizations for tablets and detachables
(Surface-style devices). Nothing here is tied to one model.

**Complementary repo:** hardware-specific fixes load on top of this one. For the
Dell Latitude 7350 Detachable, see
[omarchy-dell-latitude-7350-detachable](https://github.com/yeutterg/omarchy-dell-latitude-7350-detachable).

## Customizations

| Customization | Summary |
|---|---|
| [On-screen keyboard](#on-screen-keyboard) | squeekboard pops up for text fields, only while the keyboard is detached |
| [Stay Awake with the cover closed](#stay-awake-with-the-cover-closed) | Omarchy's Stay Awake also covers the lid and power button, turns on by itself while herdr agents work, audio keeps playing with the cover closed, and a low-battery safety valve |
| [Power saver on battery](#power-saver-on-battery) | Battery defaults to the power-saver profile instead of balanced |

### On-screen keyboard
- squeekboard replaces fcitx5 as the Wayland input method (fcitx5 is disabled,
  its environment variables masked), so it appears when a text field is focused.
- It's only enabled while the tablet-mode switch says the keyboard is detached.
  The switch is found from the kernel, not by device name.
- Chromium gets the IME flags it needs to request the keyboard.
- Trade-offs: no fcitx-based compose sequences; apps without text-input-v3
  (most Electron apps) won't trigger the keyboard.

### Stay Awake with the cover closed
- **Lid:** while Stay Awake is on, or while audio is playing (and for a minute
  after it stops), closing the lid locks and blanks the screen but doesn't
  suspend, so music keeps playing.
- **herdr agents:** Stay Awake turns on while any herdr agent is working and
  off again once they've all stopped, unless you turned it on yourself.
  Turning it off by hand mid-run sticks until the agents stop.
- **Power button:** while Stay Awake is on, it locks and turns the screen off
  (press again to wake); otherwise it opens the system menu as usual.
- **Low battery:** Stay Awake turns off, and a closed machine on battery with no
  external display suspends.

### Power saver on battery
Omarchy remembers one power profile for AC and one for battery, and switches
when you plug in or unplug. With nothing saved, battery uses `balanced`;
`install.sh` saves `power-saver` instead. Picking another profile from the menu
while on battery still replaces it.

Full details, reasons and things to watch on Omarchy updates are in
[CHANGES.md](CHANGES.md).

## Install

Requires Omarchy on a tablet, convertible or detachable (DMI chassis type
30–32), plus the packages in [packages.txt](packages.txt).

```bash
sudo pacman -S --needed squeekboard jq libpulse
git clone https://github.com/yeutterg/omarchy-tablet ~/dotfiles/omarchy-tablet
~/dotfiles/omarchy-tablet/install.sh
hyprctl reload   # then log out and back in for the input method
```

`install.sh` symlinks `home/` into `$HOME` (a real file in the way is moved to
`<file>.pre-dotfiles`), enables the systemd user units, and adds one line to
`~/.config/hypr/hyprland.lua` that loads `~/.config/hypr/extras/*.lua` in name
order. This repo's Hyprland settings are `extras/50-tablet.lua`; device repos
use `60-*.lua`. To uninstall, delete the symlinks into this repo and restore any
`*.pre-dotfiles` files.
