----------------------------------------------------------------------
-- Ubermoc Forever: controller pictures on quest and gossip windows.
-- The game's own Accept, Continue, Complete, Decline and Goodbye buttons are left exactly as they are (their own art,
-- their own text, their own enabled/disabled look). A small controller picture (A or B, in the game's own set for your
-- controller) is added on the left of each, the same pictures the legend uses. Nothing is written onto the game's
-- frames. Off with /ubf quest off.
----------------------------------------------------------------------
local ADDON, UF = ...
local D = {}
UF.DialogButtons = D

local overlays = {}   -- real button -> its picture frame

function D.enabled() return UF.DB().questStyle ~= false end

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
