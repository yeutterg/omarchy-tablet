# Changes from Omarchy's defaults

Every intentional deviation from what Omarchy ships, for tablets and
detachables in general. Git history has the exact diffs.

### On-screen keyboard (squeekboard) when detached — 2026-10-04
- **Package:** `squeekboard`.
- **Files:**
  - `home/.config/hypr/extras/50-tablet.lua` — starts squeekboard at login, sets
    `org.gnome.desktop.a11y.applications screen-keyboard-enabled` to `false` at
    login, and flips it `true`/`false` on the tablet-mode switch. The switch is
    found by reading `/proc/bus/input/devices` for a device reporting
    `SW_TABLET_MODE`, so no device name is hardcoded.
  - `home/.config/systemd/user/omarchy-fcitx5.service.d/squeekboard-instead.conf`
    — a never-true condition so Omarchy's fcitx5 doesn't start.
  - `home/.config/environment.d/10-omarchy-fcitx.conf` — masks Omarchy's file of
    the same name, so `QT_IM_MODULE`/`XMODIFIERS`/`SDL_IM_MODULE`/`INPUT_METHOD`
    don't point apps at fcitx.
  - `home/.config/chromium-flags.conf` — Omarchy's flags plus
    `--enable-wayland-ime` and `--wayland-text-input-version=3`, so Chromium
    tells the input method about focused text fields.
- **Why:** Show a keyboard only when the keyboard is detached *and* a text field
  is focused. That needs the on-screen keyboard to be the Wayland input method,
  and only one input method can run, so squeekboard replaces fcitx5.
- **Costs:** Omarchy uses fcitx5 to turn CapsLock compose sequences
  (`~/.XCompose`) into text; apps that rely on fcitx for that may lose them.
  Apps without text-input-v3 support (most Electron apps unless given the IME
  flags) won't trigger the keyboard.
- **Limits:** If you log in already detached, the keyboard stays off until the
  next attach/detach. Devices without a kernel tablet-mode switch get
  squeekboard but never turn it on.
- **Watch:** `chromium-flags.conf` is a full copy of Omarchy's; if Omarchy
  changes its default flags, update this copy.

### Stay Awake also covers the lid and power button — 2026-10-04
Extends Omarchy's Stay Awake toggle (coffee cup, `omarchy toggle idle`) so
long-running jobs keep going with the lid closed or after pressing the power
button.
- **Package:** `inotify-tools`.
- **Files:**
  - `home/.local/bin/stay-awake-lid-inhibitor` +
    `home/.config/systemd/user/stay-awake-lid.{path,service}` — while Stay
    Awake is on, hold a logind `handle-lid-switch` inhibitor. Closing the lid
    still locks and blanks the screen (Omarchy's lid binding) but doesn't
    suspend. Only the lid is inhibited; suspending on purpose still works.
  - `home/.local/bin/stay-awake-power-button` +
    `home/.config/hypr/extras/50-tablet.lua` — the power button (Omarchy
    default: open the system menu) now locks and turns the screen off while
    Stay Awake is on; press again to wake. With Stay Awake off it opens the
    system menu as before.
  - `home/.config/omarchy/hooks/battery-low.d/stay-awake-off` — on Omarchy's
    low-battery warning, turn Stay Awake off; if the lid is closed, on battery,
    with no external display, suspend right away.
- **Why:** Keep work running on a tablet without the screen on.
- **Relies on:** Omarchy's Stay Awake state file
  (`~/.local/state/omarchy/indicators/stay-awake`) and
  `omarchy-toggle-idle status` output. Check these if Omarchy changes the toggle.

### Power saver by default on battery — 2026-10-05
- **File:** `install.sh` (`default_battery_power_saver`)
- **Change:** If `~/.local/state/omarchy/powerprofiles/battery` doesn't exist,
  write `power-saver` to it and reapply the profile (Omarchy default with no
  saved choice: `balanced` on battery, `performance` on AC).
- **Why:** Longer battery life on a tablet; plugged in stays as before.
- **How it applies:** Omarchy's shell runs `omarchy-powerprofiles-set battery`
  on unplug, which uses the saved file. A profile chosen from the menu while on
  battery overwrites it, so this is only a default.
- **Watch:** If Omarchy moves the state file or changes
  `omarchy-powerprofiles-set`, update the path.
