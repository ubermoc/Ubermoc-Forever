std = "lua51"
max_line_length = false
exclude_files = { "tools/bin" }
files["tools/test.lua"] = { ignore = { "1", "21" } }

globals = {
    "UbermocForeverDB",
    "SLASH_UBERMOCFOREVER1",
    "SlashCmdList",
}

read_globals = {
    "UIParent",
    "SetCursorPosition",
    "GetCursorPosition",
    "SimulateMouseClick",
    "SimulateMouseWheel",
    "Enum",
    "WorldFrame",
    "GetMouseFoci",
    "CloseAllWindows",
    "hooksecurefunc",
    "PlaySound",
    "SOUNDKIT",
    "HideUIPanel",
    "ToggleGameMenu",
    "GameMenuFrame",
    "SetBinding",
    "SaveBindings",
    "GetCurrentBindingSet",
    "GetUIPanel",
    "IsGamePadCursorControlEnabled",
    "SetGamePadCursorControl",
    "CanAutoSetGamePadCursorControl",
    "_G",
    "UISpecialFrames",
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
