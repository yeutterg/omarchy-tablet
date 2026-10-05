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
- **Files:**
  - `home/.local/bin/stay-awake-cover` +
    `home/.config/systemd/user/stay-awake-cover.service` — see "Cover closed:
    keep playing audio" below; it now holds the lid inhibitor for Stay Awake.
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

### Lock screen number pad and PIN — 2026-10-05
- **Files:**
  - `home/.config/omarchy/plugins/tablet.lock/` — copy of Omarchy's
    `omarchy.lock` plugin (`manifest.json` has `clonedFrom: "omarchy.lock"`, so
    it keeps the lock screen's trusted `authentication` capability and Omarchy
    routes lock calls to it). Changes are marked `omarchy-tablet`:
    `Service.qml` adds the PIN check and tablet-mode watcher; `LockView.qml`
    adds the 3×4 number pad and PIN dots, and says "Enter PIN or Password"
    while the keyboard is attached.
  - `home/.local/bin/lock-pin` — `set` / `remove` / `keypad always|detached` /
    `status`, plus `check` and `reset` for the plugin.
  - `home/.config/hypr/extras/50-tablet.lua` — the tablet-mode switch also
    writes `1`/`0` to `$XDG_RUNTIME_DIR/omarchy-tablet/tablet-mode` (`0` at
    login).
  - `install.sh` — copies plugins instead of linking (Omarchy's
    `omarchy-plugin-validate` refuses symlinks inside a plugin) and enables
    them, which disables the built-in `omarchy.lock`.
- **Behaviour:** With a PIN set, the lock screen shows a number pad: always by
  default, or only while the keyboard is detached after `lock-pin keypad
  detached` (saved next to the PIN, outside the repo). It submits as soon as the PIN's length is reached (or on ✓).
  Typing on a keyboard still goes to the password and PAM, as before.
- **PIN storage:** `lock-pin set` stores a salted SHA-512 crypt hash
  (`openssl passwd -6`) and the PIN length in
  `~/.local/state/omarchy-tablet/lock-pin/` (mode 600). Nothing about the PIN
  is in this repo. The PIN goes to `lock-pin check` on stdin, not argv.
- **Limits:** 5 wrong PINs disable the PIN until a password (or fingerprint)
  unlock. The PIN is checked outside PAM, so it doesn't count toward PAM's
  faillock, and it can't be used for sudo, login or disk unlock. Anyone with
  access to your user account could brute-force a 4-digit hash offline, but
  they would already be past the lock screen.
- **Why:** squeekboard can't draw over a session lock, so with the keyboard
  detached there was no way to unlock without fingerprint.
- **Watch:** On Omarchy updates, diff `/usr/share/omarchy/shell/plugins/lock/`
  against this copy and port changes; the built-in stays disabled while
  `tablet.lock` is enabled. If the plugin fails to load, the screen can't
  lock: run `omarchy plugin enable omarchy.lock`.
