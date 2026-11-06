local _, ns = ...

-- BarLabels: shows the controller button name on each main-bar slot the
-- layout has bound to a pad key (X, A, B, Y, ...).
--
-- Why we write the button's own HotKey instead of the binding display:
-- GetBindingKey("ACTIONBUTTONn") reports the action's PRIMARY key, and the
-- keyboard default ("1") always wins over the pad key we register — verified
-- in-game (build 70790): the pad binding is registered ("layout main bar
-- bound" 12/12 in the self test) yet the bar still reads "1". So we put the
-- pad name into the same HotKey FontString the game uses for its pad glyph
-- (top-right, tall box — Blizzard_ActionBar/Shared/ActionButton.lua,
-- UpdateHotkeys), and re-apply it from a hook on UpdateHotkeys so the label
-- survives every game re-render. Same net effect as Ubermoc UI's per-slot
-- labels, but on the game's own buttons.

local BarLabels = {}
ns.BarLabels = BarLabels

local SLOT_COUNT = 12

-- Short names for the hotkey box (same values as the FRIENDLY table in
-- Input/Layout.lua; short forms only — this is a small label, not a status
-- line).
local SHORT = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADDUP = "UP", PADDRIGHT = "RIGHT", PADDDOWN = "DOWN", PADDLEFT = "LEFT",
    PADLSHOULDER = "L1", PADRSHOULDER = "R1", PADLTRIGGER = "L2", PADRTRIGGER = "R2",
    PADPADDLE1 = "R4", PADPADDLE2 = "L4", PADPADDLE3 = "R5", PADPADDLE4 = "L5",
    PADFORWARD = "ST", PADBACK = "SEL", PADLSTICK = "L3", PADRSTICK = "R3",
}

-- Write our label into the button's HotKey FontString, using the game's own
-- layout for a "gamepad key" hotkey (Blizzard_ActionBar/Shared/ActionButton.lua).
local function paint(btn, text)
    local hotkey = btn.HotKey
    if not hotkey then return end
    local w = btn:GetSize()
    hotkey:SetSize(w, 16)
    hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", btn.hotkeyTextGamepadX or 0, btn.hotkeyTextGamepadY or 0)
    hotkey:SetText(text)
    hotkey:Show()
end

-- Main bar buttons are ActionButton1..12 (GetActionButtonForID,
-- Blizzard_ActionBar/Shared/ActionButton.lua).
local function buttonFor(slot)
    local btn = _G["ActionButton" .. slot]
    if btn and btn.HotKey then return btn end
    return nil
end

local function ensureHooked(btn)
    if not btn.ubfBarLabelHooked and type(btn.UpdateHotkeys) == "function" then
        btn.ubfBarLabelHooked = true
        -- Re-apply our label whenever the game refreshes the hotkey text.
        hooksecurefunc(btn, "UpdateHotkeys", function(self)
            if self.ubfBarLabel then
                paint(self, self.ubfBarLabel)
            end
        end)
    end
end

-- Label every main-bar slot the layout binds. Called when the layout is on.
function BarLabels.Apply()
    if InCombatLockdown() then return end
    local c = ns.db and ns.db.layout
    local on = c and c.enabled and true or false
    for slot = 1, SLOT_COUNT do
        local btn = buttonFor(slot)
        if btn then
            local text = on and (c.slots and SHORT[c.slots[slot]]) or nil
            if text then
                ensureHooked(btn)
                btn.ubfBarLabel = text
                paint(btn, text)
            else
                btn.ubfBarLabel = nil
                -- Let the game re-render its own hotkey (e.g. "1").
                pcall(function() btn:UpdateHotkeys() end)
            end
        end
    end
end

-- Remove our labels and hand the hotkeys back to the game.
function BarLabels.Remove()
    if InCombatLockdown() then return end
    for slot = 1, SLOT_COUNT do
        local btn = buttonFor(slot)
        if btn then
            btn.ubfBarLabel = nil
            pcall(function() btn:UpdateHotkeys() end)
        end
    end
end
