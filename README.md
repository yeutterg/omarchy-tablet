# omarchy-tablet

[Omarchy](https://omarchy.org) tweaks for tablets and detachables (Surface-style
devices): an on-screen keyboard that appears when the keyboard is detached, and
a Stay Awake mode that keeps the machine running with the cover closed.

Nothing here is tied to one model. Settings for specific hardware live in their
own repos and load on top of this one, for example
`omarchy-latitude-7350-detachable`.

## What's included

| Change | What it does |
|---|---|
| On-screen keyboard | squeekboard replaces fcitx5 as the input method. It pops up when a text field is focused, but only while the keyboard is detached (follows the tablet-mode switch). |
| Stay Awake: lid | While Omarchy's Stay Awake is on, closing the lid locks and blanks the screen but doesn't suspend. |
| Stay Awake: power button | While Stay Awake is on, the power button locks and turns the screen off (press again to wake). Otherwise it opens the system menu as usual. |
| Stay Awake: low battery | On Omarchy's low-battery warning, Stay Awake turns off; if the lid is closed on battery with no external display, the machine suspends. |

Details, reasons and trade-offs for each are in [CHANGES.md](CHANGES.md).

## Requirements

- Omarchy (Hyprland, Lua config)
- A tablet, convertible or detachable (DMI chassis type 30, 31 or 32)
- Packages in [packages.txt](packages.txt): `sudo pacman -S --needed squeekboard inotify-tools`

## Install

```bash
git clone https://github.com/<you>/omarchy-tablet ~/dotfiles/omarchy-tablet
~/dotfiles/omarchy-tablet/install.sh
hyprctl reload
```

Then log out and back in so the input method and environment changes apply.

`install.sh` symlinks everything under `home/` into `$HOME`, so editing a file in
`~/.config` edits the repo. A real file already in the way is moved aside to
`<file>.pre-dotfiles`. It also enables the systemd user units here and adds one
line to `~/.config/hypr/hyprland.lua` that loads `~/.config/hypr/extras/*.lua` in
name order. This repo's Hyprland settings are `extras/50-tablet.lua`, and device
repos use `60-*.lua` so they load after it.

To uninstall, delete the symlinks that point into this repo, and rename any
`*.pre-dotfiles` files back.

## Layout

```
home/                 mirrored into $HOME as symlinks
  .config/hypr/extras/50-tablet.lua   Hyprland: keyboard switch, power button
  .config/...                         fcitx5 off, Chromium IME flags, Stay Awake units and hook
  .local/bin/...                      Stay Awake helper scripts
packages.txt          packages install.sh checks for
install.sh            creates the links
CHANGES.md            every change from Omarchy's defaults, with reasons
```
