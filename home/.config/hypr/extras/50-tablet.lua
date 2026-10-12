-- omarchy-tablet: Hyprland settings for any tablet or detachable running Omarchy.
-- Linked into ~/.config/hypr/extras/ by install.sh. Files there load in name
-- order, so device repos (60-*.lua) can override anything set here.

-- The tablet-mode switch is handled by the plugins this repo installs
-- (on-screen keyboard, lock screen PIN pad); each adds its own runtime binds.

-- Power button: with Stay Awake on, lock and turn the screen off instead of
-- opening the system menu (was: "Power menu"). Off: opens the menu as before.
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Power menu, or lock and screen off with Stay Awake", os.getenv("HOME") .. "/.local/bin/stay-awake-power-button", { locked = true })
