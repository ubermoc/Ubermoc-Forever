local _, ns = ...

ns.L = {
    LOADED = "Ubermoc Forever %s loaded (%s). Type /ubf for options.",
    CONFLICT = "Ubermoc UI is also enabled. Both addons bind the gamepad, so disable one of them.",
    DEBUG_ON = "Debug logging on.",
    DEBUG_OFF = "Debug logging off.",
    DEBUG_EMPTY = "Debug log is empty.",
    YES = "yes",
    NO = "no",
    PAD_ENABLED = "Gamepad enabled: %s",
    PAD_NONE = "No controllers found.",
    PAD_LINE = "[%d] %s | labels: %s | vendor %d product %d | %d buttons, %d axes, %d sticks %s%s",
    PAD_ACTIVE = " (active)",
    PAD_COMBINED = " (combined)",
    PADTEST_NONE = "No controller state.",
    PADTEST_BUTTONS = "Buttons: ",
    PADTEST_AXES = "Axes: ",
    PADMAP_BUTTONS = "Buttons (index=binding, 0-based): ",
    PADMAP_AXES = "Axes (index=name, 0-based): ",
    PADMAP_STICKS = "Sticks (index=name, 0-based): ",
    HELP = "Commands: /ubf pad (list controllers), /ubf padtest (live button readout), /ubf padmap (list every button name), /ubf debug (toggle logging), /ubf log (show recent log), /ubf version",
}
