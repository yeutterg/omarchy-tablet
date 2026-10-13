-- omarchy-tablet: Hyprland settings for any tablet or detachable running Omarchy.
-- Linked into ~/.config/hypr/extras/ by install.sh. Files there load in name
-- order, so device repos (60-*.lua) can override anything set here.

-- The tablet-mode switch is handled by the plugins this repo installs
-- (on-screen keyboard, lock screen PIN pad); each adds its own runtime binds.

-- Power button (was: open the system menu): a short press locks and turns
-- the screen off (Stay Awake keeps the machine running), holding it opens the
-- system menu. The script times the press, so it gets both press and release.
local power_button = os.getenv("HOME") .. "/.local/bin/stay-awake-power-button"
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Lock and screen off; hold for the power menu", power_button .. " down", { locked = true })
o.bind("XF86PowerOff", nil, power_button .. " up", { locked = true, release = true })
