std = "lua51"
max_line_length = false
exclude_files = { "tools/bin" }
files["tools/test.lua"] = { ignore = { "1", "21" } }

globals = {
    "UbermocForeverDB",
    "SLASH_UBERMOCFOREVER1",
    "SlashCmdList",
    -- Module namespace globals (each module assigns to its own key)
    "BindingHint",
    "Layout",
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
    "ShowUIPanel",
    "ReloadUI",
    "StaticPopup_EscapePressed",
    "CloseMenus",
    "AreAllPanelsDisallowed",
    "UnitExists",
    -- Spell/spec APIs (Layout spells, checkpoint 5)
    "C_Spell",
    "GetSpellInfo",
    "C_SpecializationInfo",
    -- Bar display diagnostics (SelfTest) and class lookup (Init.lua)
    "IsBindingForGamePad",
    "C_KeyBindings",
    "UnitClass",
    "UnitCastingInfo",
    "UnitChannelInfo",
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
    "time",
    "C_Timer",
    -- Frame globals (Blizzard UI)
    "BookPane",
    "SpellBookFrame",
    "MAX_BAG_FRAMES",
    "ContainerFrameCombinedBags",
    "ProfessionFrame",
    "ProfessionFrameContainer",
    "QuestgiverFrame",
    "GossipFrame",
    "SettingsPanel",
    -- Frame globals (Blizzard UI) — additional
    "ContainerFrame",
    "BagContainerFrame",
    -- Profession frames not in the main list above
    "ProfessionMacroFrame",
    "ProfessionSkillFrame",
    "TradeSkillFrame",
    "EngineerBox",
    "EnchantingWindow",
    "CookingFrame",
    "QuestFrame",
    "_MENU_EXCLUDE",
    "_PROF_FRAMES",
    -- Binding APIs
    "GetBindingText",
    "GetBindingKeyForAction",
    "GetBindingKey",
    -- Module namespaces
    "Layout",
    "UnitAffectingCombat",
}
write_globals = {
    -- Context engine context-query functions (set as module globals)
    "inProfessions",
    "nearNPC",
    "inMenu",
}
