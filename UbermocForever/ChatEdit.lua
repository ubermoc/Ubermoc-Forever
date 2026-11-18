----------------------------------------------------------------------
-- Ubermoc Forever: the chat edit box above the chat window (UF.ChatEdit), 1.3.122. One setting on the Chat page, Off by default.
--
-- Where the game puts it: every chat window has an edit box anchored ONCE, in the XML, under the window:
--   TOPLEFT to the window's BOTTOMLEFT (-5, -2) and RIGHT to the scroll bar's RIGHT (+8)   (Blizzard_ChatFrameBase/Mainline/
--   FloatingChatFrame.xml:555-569). Nothing in the game's chat Lua reads or sets the edit box's position (searched
--   Blizzard_ChatFrame*, no call of GetPoint, GetLeft, GetTop, SetPoint, ClearAllPoints on an edit box), so what we set stays.
-- The tab bar sits ABOVE the window: the dock is anchored to the first window's Background top (FCFDock_SetPrimary,
-- FloatingChatFrame.lua:2168) and an undocked window's own tab sits on its Background top (line 1740). So "above" is above
-- the dock for a docked window and above the tab for a floating one, or the box would lie over the tabs.
-- Moving the tabs below the window is a separate step: the game re-anchors them whenever tabs change (lines 2350-2354).
--
-- Taint: only the edit box's own anchors are written (ClearAllPoints, SetPoint, inside pcall), never in combat (what waits is
-- done when the fight ends), and Off puts the game's own anchors back from the XML values above, with no reads of our own.
-- Our state is a setting in our own table; nothing is written on a game table.
----------------------------------------------------------------------
local _, UF = ...
local CE = {}
UF.ChatEdit = CE

CE.pending = false

local function cfg()
    local c = UF.Chat and UF.Chat.cfg()
    if not c then return {} end
    if c.editTop == nil then c.editTop = false end
    return c
end

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function CE.on() return cfg().editTop == true end

local function windows()
    local out = {}
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.editBox and f.editBox.SetPoint then out[#out + 1] = f end
    end
    return out
end

-- the game's own anchors (FloatingChatFrame.xml:557-560)
local function putBack(f)
    local eb = f.editBox
    eb:ClearAllPoints()
    eb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -5, -2)
    if f.ScrollBar then eb:SetPoint("RIGHT", f.ScrollBar, "RIGHT", 8, 0) end
end

-- above the dock (docked window) or above the window's own tab (floating window), with the same left and right edge
local function putOnTop(f)
    local eb = f.editBox
    local docked = plain(f.isDocked)
    local dock = _G.GENERAL_CHAT_DOCK
    eb:ClearAllPoints()
    if docked and dock then
        eb:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", -3, 2)
        eb:SetPoint("BOTTOMRIGHT", dock, "TOPRIGHT", 1, 2)
    else
        local bg = f.Background or f
        local tab = _G[(f:GetName() or "") .. "Tab"]
        local h = 32
        if tab and tab.GetHeight then
            local ok, v = pcall(tab.GetHeight, tab)
            v = ok and plain(v) or nil
            if type(v) == "number" and v > 0 then h = v end
        end
        eb:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", -3, h + 2)
        eb:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT", 1, h + 2)
    end
end

-- every window, both ways; never in combat
function CE.apply()
    if InCombatLockdown and InCombatLockdown() then CE.pending = true; return end
    CE.pending = false
    local top = CE.on()
    for _, f in ipairs(windows()) do
        pcall(top and putOnTop or putBack, f)
    end
end

function CE.toggle()
    cfg().editTop = not CE.on()
    CE.apply()
end

local f = CreateFrame("Frame")
CE._frame = f
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_CHAT_WINDOWS")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not CE.pending then return end
    -- only act while the setting is on or a change is waiting: a player who never turns this on never gets a call from us
    if CE.on() or CE.pending then CE.apply() end
end)

-- the game builds its chat windows around login; as Chat.lua does, apply again a little later
UF.OnLogin(function()
    if CE.on() then
        CE.apply()
        if C_Timer and C_Timer.After then C_Timer.After(1, CE.apply); C_Timer.After(4, CE.apply) end
    end
end)
