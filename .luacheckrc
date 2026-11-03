std = "lua51"
max_line_length = false
exclude_files = { "tools/bin" }
files["tools/test.lua"] = { ignore = { "1" } }

globals = {
    "UbermocForeverDB",
    "SLASH_UBERMOCFOREVER1",
    "SlashCmdList",
}

read_globals = {
    "UIParent",
    "C_Texture",
    "date",
    "C_CVar",
    "InCombatLockdown",
    "SetOverrideBinding",
    "ClearOverrideBindings",
    "GetBindingAction",
    "C_AddOns",
    "C_GamePad",
    "GetAddOnMetadata",
    "IsAddOnLoaded",
    "CreateFrame",
    "GetBuildInfo",
    "GetTime",
    "geterrorhandler",
    "seterrorhandler",
}
