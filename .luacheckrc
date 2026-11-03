std = "lua51"
max_line_length = false
exclude_files = { "tools/bin" }
files["tools/test.lua"] = { globals = { "print", "CreateFrame", "GetBuildInfo", "GetTime", "geterrorhandler", "seterrorhandler", "C_AddOns", "C_GamePad", "SlashCmdList", "UIParent" } }

globals = {
    "UbermocForeverDB",
    "SLASH_UBERMOCFOREVER1",
    "SlashCmdList",
}

read_globals = {
    "UIParent",
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
