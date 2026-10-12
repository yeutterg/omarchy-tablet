/* On-screen keyboard (squeekboard) in the current Omarchy theme (omarchy-tablet).
 * Omarchy renders this into the theme folder on every theme change;
 * ~/.config/gtk-3.0/gtk.css imports it, and the theme-set hook restarts
 * squeekboard so it picks the new colors up. Selectors only match squeekboard. */

@define-color sq_bg {{ background }};
@define-color sq_key {{ lighter_background }};
@define-color sq_mod {{ dark_background }};
@define-color sq_fg {{ foreground }};
@define-color sq_dim {{ dark_foreground }};
@define-color sq_accent {{ accent }};
@define-color sq_alert {{ red }};

sq_view {
    background: @sq_bg;
    box-shadow: inset 0 2px 0 0 @sq_accent;
    font-family: monospace;
    padding-top: 2px;
}

sq_button {
    color: @sq_fg;
    background: @sq_key;
    border: 1px solid alpha(@sq_fg, 0.15);
    border-radius: 0;
    box-shadow: none;
}

/* Margin only: a color rule this specific would beat the classes below */
sq_view.wide sq_button {
    margin: 3px;
}

/* Shift, backspace, 123/ABC, settings, emoji tabs */
sq_button.altline,
sq_button.special,
sq_button.special-2,
sq_button.special-3,
sq_button.wide,
sq_button.change-view,
sq_button.change-view-2,
sq_button.change-view-3,
sq_button.emoji-group,
sq_button.character-group,
sq_button.subtle-highlight,
sq_button.subtle-highlight-2 {
    color: @sq_dim;
    background: @sq_mod;
    border: 1px solid alpha(@sq_fg, 0.1);
}

sq_button.placeholder,
sq_button.placeholder-2 {
    background: transparent;
    border-color: transparent;
}

sq_button:active,
sq_button.altline:active,
sq_button.special:active,
sq_button.special-2:active,
sq_button.special-3:active,
sq_button.wide:active,
sq_button.change-view:active,
sq_button.change-view-2:active,
sq_button.change-view-3:active,
sq_button.emoji-group:active,
sq_button.character-group:active,
sq_button.subtle-highlight:active,
sq_button.subtle-highlight-2:active {
    color: @sq_bg;
    background: @sq_accent;
    border-color: @sq_accent;
}

/* Shift held for one letter, and caps lock */
sq_button.latched {
    color: @sq_accent;
    background: @sq_mod;
    border-color: @sq_accent;
}

sq_button.locked {
    color: @sq_bg;
    background: @sq_accent;
    border-color: @sq_accent;
}

#Return {
    color: @sq_accent;
    background: @sq_mod;
    border-color: alpha(@sq_accent, 0.6);
}

#Return:active {
    color: @sq_bg;
    background: @sq_accent;
}

/* Hold-to-dictate key: lights up in the theme's alert color, like the bar's
 * voxtype indicator, while held */
#dictate {
    color: @sq_dim;
    background: @sq_mod;
}

#dictate:active {
    color: @sq_bg;
    background: @sq_alert;
    border-color: @sq_alert;
}
