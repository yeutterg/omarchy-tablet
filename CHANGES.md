# Changes from Omarchy's defaults

Every intentional deviation from what Omarchy ships, for tablets and
detachables in general. Git history has the exact diffs.

### Power button: short press locks, hold for the menu — 2026-10-12
- **Files:** `home/.local/bin/stay-awake-power-button`,
  `home/.config/hypr/extras/50-tablet.lua`
- **Change:** A short press locks and turns the screen off whether or not Stay
  Awake is on (before, with Stay Awake off it opened the system menu). Holding
  the button for 0.7 s opens the system menu. Hyprland now runs the script on
  both press (`down`) and release (`up`); the script times the press itself,
  because Hyprland's long-press bind fires at the key repeat delay (250 ms),
  which an ordinary tap reaches.
- **Why:** Lock like a phone; reboot and shut down stay one hold away.
- **While locked,** a short press wakes the lock screen, which blanks itself
  again after a few idle seconds. Hyprland turns the display on for any key
  press, so by release the script can't tell whether it was dark.
- **Needs omarchy-lock-pin 0.1.2:** the lock screen appearing under the
  pointer counted as movement and woke the display about a second after the
  press blanked it.

### On-screen keyboard plugin as the input method — 2026-10-04, plugin since 2026-10-12
- **Package:** `python-pywayland` (for the plugin's helper).
- **Plugin:** [omarchy-on-screen-keyboard](https://github.com/yeutterg/omarchy-on-screen-keyboard)
  (`io.github.yeutterg.onscreen-keyboard`), added by `install.sh` with
  `omarchy plugin add --enable` and placed in the bar's right section. It finds
  the tablet-mode switch itself and adds its own Hyprland binds at runtime.
- **Files:**
  - `home/.config/systemd/user/omarchy-fcitx5.service.d/onscreen-keyboard-instead.conf`
    — a never-true condition so Omarchy's fcitx5 doesn't start.
  - `home/.config/environment.d/10-omarchy-fcitx.conf` — masks Omarchy's file of
    the same name, so `QT_IM_MODULE`/`XMODIFIERS`/`SDL_IM_MODULE`/`INPUT_METHOD`
    don't point apps at fcitx.
  - `home/.config/chromium-flags.conf` — Omarchy's flags plus
    `--enable-wayland-ime` and `--wayland-text-input-version=3`, so Chromium
    tells the input method about focused text fields.
- **Why:** Show a keyboard only when the keyboard is detached *and* a text field
  is focused. That needs the on-screen keyboard to be the Wayland input method,
  and only one input method can run, so it replaces fcitx5.
- **History:** Until 2026-10-12 the keyboard was squeekboard, with layouts, a
  GTK stylesheet and theme hooks in this repo. squeekboard can't float, and
  Hyprland ignores binds from its virtual keyboard, so keys like dictation
  couldn't work; the plugin replaced it.
- **Costs:** Omarchy uses fcitx5 to turn CapsLock compose sequences
  (`~/.XCompose`) into text; apps that rely on fcitx for that may lose them.
  Apps without text-input-v3 support (most Electron apps unless given the IME
  flags) won't pop the keyboard up.

### Stay Awake also covers the lid and power button — 2026-10-04
Extends Omarchy's Stay Awake toggle (coffee cup, `omarchy toggle idle`) so
long-running jobs keep going with the lid closed or after pressing the power
button.
- **Files:**
  - `home/.local/bin/stay-awake-cover` +
    `home/.config/systemd/user/stay-awake-cover.service` — see "Cover closed:
    keep playing audio" below; it now holds the lid inhibitor for Stay Awake.
  - `home/.local/bin/stay-awake-power-button` +
    `home/.config/hypr/extras/50-tablet.lua` — the power button (Omarchy
    default: open the system menu) now locks and turns the screen off while
    Stay Awake is on; press again to wake. With Stay Awake off it opens the
    system menu as before.
    **2026-10-05:** a second press within 1.5 s is ignored (logged to the
    journal as `stay-awake-power-button`). Tablets can report one press from
    two devices (ACPI "Power Button" and the vendor HID buttons); the second
    report locked and blanked the screen about a second after waking it.
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

### Cover closed: keep playing audio — 2026-10-05
- **Packages:** `jq`, `libpulse` (for `pactl`); both ship with Omarchy.
- **Files:** `home/.local/bin/stay-awake-cover` +
  `home/.config/systemd/user/stay-awake-cover.service` (replace the earlier
  `stay-awake-lid-inhibitor` + `stay-awake-lid.{path,service}`).
- **Change:** An always-on user service checks every 5 s and holds a logind
  `handle-lid-switch` inhibitor while Omarchy's Stay Awake is on **or** any audio
  output stream is playing (a PipeWire/Pulse sink input that isn't corked), plus
  60 s after audio stops so gaps between tracks don't count. Omarchy default:
  closing the lid locks and suspends, which stops playback.
- **Why:** Close the cover and keep listening, like a phone: the lock and screen
  off still happen, only the suspend is skipped.
- **Behaviour once released:** logind is expected to act on the still-closed
  lid and suspend. Not yet tested.
- **Cost:** A closed tablet playing audio keeps running on battery. The
  low-battery hook still suspends.
- **Watch:** Machines that installed the old version keep a dangling
  `default.target.wants/stay-awake-lid.path` link; `systemctl --user disable
  stay-awake-lid.path` before pulling, or delete the link.

### Stay Awake turns on while herdr agents work — 2026-10-05
- **Package:** `herdr` (not in packages.txt; without it the service idles).
- **Files:** `home/.local/bin/stay-awake-agents` +
  `home/.config/systemd/user/stay-awake-agents.service`.
- **Change:** A user service checks every 10 s whether any agent in any running
  herdr session has status `working` (`herdr session list --json`, then
  `herdr agent list` per session socket). If so and Stay Awake is off, it turns
  it on with `omarchy-toggle-idle stay-awake` and leaves a marker in
  `~/.local/state/stay-awake-agents/auto`. Once no agent has been working for
  30 s, it turns Stay Awake off again, but only if the marker is there.
  `blocked` (waiting on you), `idle` and `done` don't count as working.
- **Manual wins:** Stay Awake that was already on is never touched. Turning it
  off while agents work (by hand or via the low-battery hook) stays off until
  all agents stop. On battery at or below 10% (Omarchy's warning level) it
  isn't turned on.
- **Why:** Leave agents running with the cover closed or the screen off
  without remembering to toggle Stay Awake, and without leaving it on after.
- **Relies on:** `herdr` CLI JSON (`sessions[].running/socket_path`,
  `result.agents[].agent_status`) and `HERDR_SOCKET_PATH` picking the session.
  Check these if herdr changes its API.

### Lock screen number pad and PIN — 2026-10-05, plugin since 2026-10-12
- **Plugin:** [omarchy-lock-pin](https://github.com/yeutterg/omarchy-lock-pin)
  (`io.github.yeutterg.lock-pin`), added and enabled by `install.sh`. A clone of
  Omarchy's lock screen (`clonedFrom: omarchy.lock`, `authentication`
  capability) with an on-screen number pad and an optional 4–6 digit PIN; it
  adds its own tablet-mode switch binds at runtime for the "only while
  detached" pad mode.
- **PIN storage:** the plugin's `lock-pin set` stores a salted SHA-512 crypt
  hash in `~/.local/state/omarchy-lock-pin/` (mode 600). Nothing about the PIN
  is in this repo. After 5 wrong PINs the PIN stops working until a password
  unlock.
- **History:** Until 2026-10-12 this repo shipped the plugin as
  `home/.config/omarchy/plugins/tablet.lock/` (copied by `install.sh`), the
  `lock-pin` script in `~/.local/bin`, and a tablet-mode file written by
  `50-tablet.lua`. `install.sh` moves an existing PIN from
  `~/.local/state/omarchy-tablet/lock-pin/` and removes the old plugin.
- **Why:** squeekboard (and any on-screen keyboard) can't draw over a session
  lock, so with the keyboard detached there was no way to unlock without
  fingerprint.
- **Watch:** On Omarchy updates the plugin's copy of the lock screen may need
  porting. If it fails to load, the screen can't lock: run
  `omarchy plugin enable omarchy.lock`.
### Screen rotation, by hand or from the accelerometer — 2026-10-12, plugin since 2026-10-12
- **Package:** `iio-sensor-proxy` (for Auto; `monitor-sensor`).
- **Plugin:** [omarchy-display-rotation](https://github.com/yeutterg/omarchy-display-rotation)
  (`io.github.yeutterg.display-rotation`), added and enabled by `install.sh`.
  A clone of Omarchy's display panel (`clonedFrom: omarchy.monitor`) with a
  Rotation row; its service rotates the first eDP/LVDS/DSI output with
  `hyprctl eval` (monitor `transform`, plus `input:touchdevice` and
  `input:tablet` `output`/`transform`), runs `monitor-sensor --accel` while
  Auto is on, and turns the screen back after a Hyprland config reload.
- **History:** First built here as `tablet-rotate`, `tablet-autorotate` and
  `tablet-autorotate.service`, driven by a rotation row in the Dell repo's
  display panel copy. Moved into one generic plugin so any tablet gets the row
  and the Dell repo needs no panel copy; `install.sh` stops the old service.
- **Why:** Omarchy has no rotation, and a rotated screen without rotated touch
  input puts taps in the wrong place.
- **Limits:** The accelerometer mapping assumes a landscape-native panel.

### Bar stays put in tablet mode — 2026-10-12
- **Plugin:** the on-screen keyboard plugin (0.2.3) disables the bar's centre
  drag area while in tablet mode (`lockBarInTabletMode`, on by default).
- **Why:** The bar's drag-to-move (press-and-hold 200 ms) has no setting, and a
  finger triggers it by accident.
- **History:** First a `bar-position-guard` user service here that put the bar
  back after a move; replaced the same day by disabling the drag itself.
### Tray for touch — 2026-10-12
- **Plugin:** [omarchy-tray-touch](https://github.com/yeutterg/omarchy-tray-touch)
  (`io.github.yeutterg.tray-touch`, `clonedFrom: omarchy.tray`), added by
  `install.sh`. Stock tray except: a left click/tap on the chevron keeps the
  drawer open (Omarchy: hover only), icon clicks in the first 500 ms after it
  opens are ignored, and it closes after an icon is used or 6 s idle.
- **Why:** A finger only hovers while touching, so the drawer opened for one
  tap and that tap launched the app sliding under it (1Password full screen);
  icons couldn't be reached on purpose.
- **History:** First published as omarchy-tray-menu (click shows the menu
  instead of opening the app); replaced the same day, since app clicks should
  stay stock.
