-- omarchy-tablet: move and resize windows with the touchscreen, through the
-- hyprgrass plugin (https://github.com/horriblename/hyprgrass), installed with
-- hyprpm by install.sh. Rebuild it after a Hyprland update: `hyprpm update`.
--   Long-press a window border or gap, then drag: resize.
--   Long-press a window with two fingers, then drag: move it (tiled windows
--   swap places).

-- Load hyprpm's plugins at login (-n: notify if one fails to load).
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpm reload -n")
end)

-- Until hyprgrass is loaded its config keys and functions don't exist; the
-- config is evaluated again once it loads.
if hl.plugin and hl.plugin.hyprgrass then
  hl.config({
    plugin = {
      hyprgrass = {
        long_press_delay = 400,
        resize_on_border_long_press = true,
        -- Tablet screens need more than the default 1.0.
        sensitivity = 4.0,
      },
    },
  })

  hl.plugin.hyprgrass.bind({
    pattern = { kind = "longpress", fingers = 2 },
    action = hl.dsp.window.drag(),
    mouse = true,
  })
end
