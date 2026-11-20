----------------------------------------------------------------------
-- Ubermoc Forever: controller layouts
-- What each controller calls its buttons (used as text when the game's own picture is missing) and which of the
-- game's own button picture styles each controller uses. The pictures themselves are the game's: it defines
-- KEY_PAD1_LTR, KEY_PAD1_SHP and so on as inline atlas markup (Gamepad_Ltr_A_64 ...), so no art is shipped here.
----------------------------------------------------------------------
local _, UF = ...

UF.SETS = {
    xbox = { name = "Xbox", short = "Xbox", labels = {
        PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
        PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSTICK = "Left stick", PADRSTICK = "Right stick",
        PADBACK = "View", PADFORWARD = "Menu", PADSYSTEM = "Xbox", PADSOCIAL = "Share",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right" } },
    ps5 = { name = "PlayStation", short = "PlayStation", labels = {
        PAD1 = "Cross", PAD2 = "Circle", PAD3 = "Square", PAD4 = "Triangle", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L3", PADRSTICK = "R3",
        PADBACK = "Create", PADFORWARD = "Options", PADSYSTEM = "PS button", PADSOCIAL = "Touchpad",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right" } },
    ps3 = { name = "PlayStation 3", short = "PS3", labels = {
        PAD1 = "Cross", PAD2 = "Circle", PAD3 = "Square", PAD4 = "Triangle", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L3", PADRSTICK = "R3",
        PADBACK = "Select", PADFORWARD = "Start", PADSYSTEM = "PS button", PADSOCIAL = "-",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right" } },
    switch = { name = "Nintendo Switch", short = "Switch", labels = {
        PAD1 = "B", PAD2 = "A", PAD3 = "Y", PAD4 = "X", PADLSHOULDER = "L", PADRSHOULDER = "R",
        PADLTRIGGER = "ZL", PADRTRIGGER = "ZR", PADLSTICK = "Left stick", PADRSTICK = "Right stick",
        PADBACK = "Minus", PADFORWARD = "Plus", PADSYSTEM = "Home", PADSOCIAL = "Capture",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right" } },
    steam = { name = "Steam Controller / Steam Deck", short = "Steam Deck", labels = {
        PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L-stick", PADRSTICK = "R-stick",
        PADBACK = "View", PADFORWARD = "Menu", PADSYSTEM = "Steam", PADSOCIAL = "-",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "R4", PADPADDLE2 = "L4", PADPADDLE3 = "R5", PADPADDLE4 = "L5" } },
}
UF.SET_ORDER = { "xbox", "ps5", "ps3", "switch", "steam" }

-- The game's picture styles (see SetGamepadBindingStrings in Blizzard_SharedXML/SharedConstants.lua):
-- _LTR letters (Xbox), _SHP shapes (PlayStation), _REV reversed letters (Nintendo: the bottom button is B).
UF.STYLE = { xbox = "_LTR", steam = "_LTR", ps5 = "_SHP", ps3 = "_SHP", switch = "_REV" }

-- The picture for a button, as text that can go in any label. Falls back to the generic picture, then to words.
function UF.glyph(pad, setId)
    setId = setId or UF.activeSet()
    local suffix = UF.STYLE[setId] or ""
    local s = _G["KEY_" .. pad .. suffix] or _G["KEY_" .. pad]
    if type(s) == "string" and s ~= "" then return s end
    local set = UF.SETS[setId]
    return (set and set.labels[pad]) or pad
end

-- A button's name in words, for tooltips and for when the picture is missing.
function UF.label(pad, setId)
    local set = UF.SETS[setId or UF.activeSet()]
    return (set and set.labels[pad]) or pad
end
