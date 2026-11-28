----------------------------------------------------------------------
-- Ubermoc Forever: controller pictures on quest and gossip windows.
-- The game's own Accept, Continue, Complete, Decline and Goodbye buttons are left exactly as they are (their own art,
-- their own text, their own enabled/disabled look). A small controller picture (A or B, in the game's own set for your
-- controller) is added on the left of each, the same pictures the legend uses. Nothing is written onto the game's
-- frames. Part of cinematic mode: /ubf cinema off hides them.
----------------------------------------------------------------------
local ADDON, UF = ...
local D = {}
UF.DialogButtons = D

local overlays = {}   -- real button -> its picture frame

function D.enabled() return UF.DB().cinema ~= false end   -- part of cinematic mode

local function shown(f) return f and f.IsShown and f:IsShown() end

local function overlayFor(b)
    local o = overlays[b]
    if o then return o end
    o = CreateFrame("Frame", nil, UIParent)
    o:EnableMouse(false)
    o:SetFrameStrata(b:GetFrameStrata())
    o:SetFrameLevel((b:GetFrameLevel() or 1) + 5)
    o:SetSize(28, 28)
    o:SetPoint("LEFT", b, "LEFT", 6, 0)
    o.text = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    o.text:SetPoint("CENTER")
    o:Hide()
    overlays[b] = o
    return o
end

local function release()
    for b, o in pairs(overlays) do o:Hide() end
end

-- Which real button carries which controller button right now.
local function plan()
    local out = {}
    local G = UF.GameNav
    if not G then return out end
    local q, g = _G.QuestFrame, _G.GossipFrame
    if shown(q) then
        local a = G.dialogStart and G.dialogStart()
        local b = G.dialogCloser and G.dialogCloser(q)
        -- only the real Accept / Continue / Complete buttons (the start button can also be a reward or an option)
        local an = a and a.GetName and a:GetName()
        if an == "QuestFrameAcceptButton" or an == "QuestFrameCompleteQuestButton" or an == "QuestFrameCompleteButton" then
            out[a] = "PAD1"
        end
        if b and b ~= a then out[b] = "PAD2" end
    elseif shown(g) then
        local b = _G.GossipFrameGreetingGoodbyeButton or (g.GreetingPanel and g.GreetingPanel.GoodbyeButton)
        if b and b.IsVisible and b:IsVisible() then out[b] = "PAD2" end
    end
    return out
end

local function update()
    if not D.enabled() or InCombatLockdown() then release(); return end
    local p = plan()
    for b, o in pairs(overlays) do if not p[b] then o:Hide() end end
    for b, pad in pairs(p) do
        local o = overlayFor(b)
        o.text:SetText(UF.glyph(pad))
        local on = (not b.IsEnabled) or b:IsEnabled()
        o:SetAlpha(on and 1 or 0.5)
        o:Show()
    end
end

local acc = 0
local drv = CreateFrame("Frame")
drv:Hide()
drv:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    if not (shown(_G.QuestFrame) or shown(_G.GossipFrame)) then
        release()
        self:Hide()
        return
    end
    update()
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() drv:Show() end)

function D.refresh() if not D.enabled() then release() else drv:Show() end end

----------------------------------------------------------------------
-- One quest, nothing else to say: open it at once (no list to pick from), so the window is the Accept / Decline page.
-- An NPC with several quests or any other option (a vendor, a trainer) still shows its list. Part of cinematic mode.
-- Calls: C_GossipInfo.GetAvailableQuests / GetActiveQuests / GetOptions and SelectAvailableQuest / SelectActiveQuest, which
-- take the quest ID (the same calls the game's own gossip buttons make, Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua).
----------------------------------------------------------------------
-- Pure: what to open from the lists the game gives. Returns "available" or "active" and the quest ID, or nil.
function D.autoTarget(available, active, options)
    available, active, options = available or {}, active or {}, options or {}
    if #options > 0 or (#available + #active) ~= 1 then return nil end
    if #available == 1 then return "available", available[1].questID end
    if active[1].isComplete then return "active", active[1].questID end   -- a quest to turn in; one still in progress only shows its list
end

local recent = {}   -- npc guid .. quest id -> time it was opened by us (so declining does not open it again at once)
local function seenRecently(key)
    local t = recent[key]
    return t and GetTime() - t < 60
end

local function auto()
    if not (UF.Cinematic and UF.Cinematic.enabled()) or InCombatLockdown() then return end
    local g = _G.GossipFrame
    if not (g and g.IsShown and g:IsShown()) or not C_GossipInfo then return end
    local ok, kind, id = pcall(function()
        return D.autoTarget(C_GossipInfo.GetAvailableQuests(), C_GossipInfo.GetActiveQuests(), C_GossipInfo.GetOptions())
    end)
    if not ok or not kind then return end
    -- the NPC's GUID can be a secret value (instances, combat); a secret used as a table key errors, so it is left out then
    local guid = UnitGUID and UnitGUID("npc")
    if issecretvalue and issecretvalue(guid) then guid = "hidden" end
    local key = tostring(guid) .. ":" .. tostring(id)
    if seenRecently(key) then return end
    recent[key] = GetTime()
    if kind == "available" then C_GossipInfo.SelectAvailableQuest(id) else C_GossipInfo.SelectActiveQuest(id) end
end

local ev2 = CreateFrame("Frame")
pcall(ev2.RegisterEvent, ev2, "GOSSIP_SHOW")
ev2:SetScript("OnEvent", function() C_Timer.After(0.05, auto) end)
