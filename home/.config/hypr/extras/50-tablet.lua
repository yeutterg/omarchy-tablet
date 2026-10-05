-- omarchy-tablet: Hyprland settings for any tablet or detachable running Omarchy.
-- Linked into ~/.config/hypr/extras/ by install.sh. Files there load in name
-- order, so device repos (60-*.lua) can override anything set here.

-- Tablet-mode switches, found from the kernel rather than hardcoded by name:
-- any input device whose switch bitmap has SW_TABLET_MODE (bit 1) set. On a
-- Dell Latitude 7350 Detachable this is "Intel HID switches".
local function tablet_mode_switches()
  local names, name = {}, nil
  local f = io.open("/proc/bus/input/devices", "r")
  if not f then return names end
  for line in f:lines() do
    name = line:match('^N: Name="(.*)"$') or name
    local bits = line:match("^B: SW=(.*)$")
    local low = bits and tonumber(bits:match("(%x+)%s*$"), 16)
    if low and math.floor(low / 2) % 2 == 1 then
      names[#names + 1] = name
    end
  end
  f:close()
  return names
end

-- On-screen keyboard: squeekboard is the input method (fcitx5 is disabled by
-- this repo), so it pops up when a text field is focused. It only shows while
-- the screen-keyboard setting is on, which follows the tablet-mode switch: on
-- when the keyboard is detached, off when it is attached.
local osk = "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled "
o.exec_on_start(osk .. "false")
o.launch_on_start("squeekboard")
for _, switch in ipairs(tablet_mode_switches()) do
  o.bind("switch:on:" .. switch, nil, osk .. "true", { locked = true })
  o.bind("switch:off:" .. switch, nil, osk .. "false", { locked = true })
end

-- Power button: with Stay Awake on, lock and turn the screen off instead of
-- opening the system menu (was: "Power menu"). Off: opens the menu as before.
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Power menu, or lock and screen off with Stay Awake", os.getenv("HOME") .. "/.local/bin/stay-awake-power-button", { locked = true })
