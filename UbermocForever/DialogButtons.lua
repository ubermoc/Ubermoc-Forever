----------------------------------------------------------------------
-- Ubermoc Forever: controller-style buttons on quest and gossip windows.
-- With a controller you never click Accept or Decline, so the game's own buttons are drawn as a strip with the
-- controller picture and the word: "(A) Accept", "(B) Decline". The game's real buttons stay where they are, fully
-- working (our A and B presses click them); only their look is covered. Nothing is written onto the game's frames
-- except the button's opacity, which is put back when the window closes. Off with /ubf quest off.
----------------------------------------------------------------------
local ADDON, UF = ...
local D = {}
UF.DialogButtons = D

local STRIP = { 0.80, 0.70, 0.33, 0.95 }   -- the gold strip
local DIM = 0.45
local overlays = {}   -- real button -> its overlay
local hidden = {}     -- real button -> its opacity before we hid it

function D.enabled() return UF.DB().questStyle ~= false end

local function shown(f) return f and f.IsShown and f:IsShown() end

local function overlayFor(b)
    local o = overlays[b]
    if o then return o end
    o = CreateFrame("Frame", nil, UIParent)
    o:EnableMouse(false)
    o:SetFrameStrata(b:GetFrameStrata())
    o:SetFrameLevel((b:GetFrameLevel() or 1) + 20)
    o:SetAllPoints(b)
    o.bg = o:CreateTexture(nil, "BACKGROUND")
    o.bg:SetAllPoints()
    o.bg:SetColorTexture(STRIP[1], STRIP[2], STRIP[3], STRIP[4])
    o.text = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    o.text:SetPoint("LEFT", 10, 0)
    o.text:SetPoint("RIGHT", -6, 0)
    o.text:SetJustifyH("LEFT")
    o:Hide()
    overlays[b] = o
    return o
end

local function hideReal(b)
    if hidden[b] == nil then hidden[b] = b:GetAlpha() end
    b:SetAlpha(0)
end

local function release()
    for b, o in pairs(overlays) do o:Hide() end
    for b, a in pairs(hidden) do pcall(b.SetAlpha, b, a) end
    wipe(hidden)
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
    for b, o in pairs(overlays) do if not p[b] then o:Hide(); if hidden[b] ~= nil then pcall(b.SetAlpha, b, hidden[b]); hidden[b] = nil end end end
    for b, pad in pairs(p) do
        local o = overlayFor(b)
        local label = (b.GetText and b:GetText()) or ""
        o.text:SetText(UF.glyph(pad) .. "  " .. label)
        local on = (not b.IsEnabled) or b:IsEnabled()
        o:SetAlpha(on and 1 or DIM)
        hideReal(b)
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
