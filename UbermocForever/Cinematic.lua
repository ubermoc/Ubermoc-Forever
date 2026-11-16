----------------------------------------------------------------------
-- Ubermoc Forever: cinematic camera while talking to an NPC (quest giver, gossip).
-- The game's own quest and gossip windows are left exactly as they are. Only the world around them changes: the
-- camera moves in and turns to the NPC, black bars slide in, and the rest of the interface fades out. Everything
-- is put back when the talk ends, when combat starts, and after a reload in the middle of a talk.
-- Notes and sources: docs/RESEARCH-CINEMATIC.md. Not tested in the game until the user reports.
----------------------------------------------------------------------
local ADDON, UF = ...
local C = {}
UF.Cinematic = C

local ZOOM = 5         -- how close the camera comes (yards), only ever closer than the player had it
local BARS = 0.11      -- black bars, as a share of the screen height (each)
local FADE_IN = 0.8    -- seconds to ease in
local FADE_OUT = 0.6   -- seconds to ease out
local FACE_CVARS = {   -- the camera turns toward the NPC (the same ones UbermocUI uses)
    test_cameraTargetFocusInteractEnable = "1",
    test_cameraTargetFocusInteractStrengthPitch = "1.00",
    test_cameraTargetFocusInteractStrengthYaw = "1.00",
}
-- Windows that stay visible while the rest of the interface fades.
local KEEP = { "GossipFrame", "QuestFrame", "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "UbermocForeverGameCursor",
    "UbermocForeverGameLegend", "UbermocForeverItemMenu" }

local function getCVar(c) local f = (C_CVar and C_CVar.GetCVar) or GetCVar; return f and f(c) end
local function setCVar(c, v) local f = (C_CVar and C_CVar.SetCVar) or SetCVar; return f(c, v) end

local S = { active = false, k = 0, goal = 0 }
local kept = {}   -- frame -> its earlier ignore-parent-alpha setting
local dress, drv

-- On unless the user turned it off with /ubf cinema off.
function C.enabled() return UF.DB().cinema ~= false end

-- Is the player talking to an NPC right now? The game's own windows are the proof.
function C.talking()
    local function shown(n) local f = _G[n]; return f and f.IsShown and f:IsShown() end
    return (shown("GossipFrame") or shown("QuestFrame")) and true or false
end

----------------------------------------------------------------------
-- Saved CVars: saved first (in the saved variables), so a reload or crash in the middle of a talk still puts them back.
----------------------------------------------------------------------
local function put(cvar, value)
    local cur = getCVar(cvar)
    if cur == nil then return end   -- this game build does not have it
    local d = UF.DB()
    d.cinemaBackup = d.cinemaBackup or {}
    if d.cinemaBackup[cvar] == nil then d.cinemaBackup[cvar] = cur end
    pcall(setCVar, cvar, value)
end

function C.restoreCVars()
    local d = UF.DB()
    local b = d.cinemaBackup
    if not b then return end
    for cvar, v in pairs(b) do
        if pcall(setCVar, cvar, v) then b[cvar] = nil end
    end
    if next(b) == nil then d.cinemaBackup = nil end
end

----------------------------------------------------------------------
-- Screen dressing: black bars (plain colour only)
----------------------------------------------------------------------
local function makeDress()
    if dress then return dress end
    dress = CreateFrame("Frame", "UbermocForeverCinematic", UIParent)
    dress:SetAllPoints(WorldFrame or UIParent)
    dress:SetFrameStrata("BACKGROUND")
    dress:SetFrameLevel(1)
    dress:EnableMouse(false)
    if dress.SetIgnoreParentAlpha then dress:SetIgnoreParentAlpha(true) end
    dress.top = dress:CreateTexture(nil, "ARTWORK")
    dress.top:SetColorTexture(0, 0, 0, 1)
    dress.top:SetPoint("TOPLEFT"); dress.top:SetPoint("TOPRIGHT")
    dress.bot = dress:CreateTexture(nil, "ARTWORK")
    dress.bot:SetColorTexture(0, 0, 0, 1)
    dress.bot:SetPoint("BOTTOMLEFT"); dress.bot:SetPoint("BOTTOMRIGHT")
    dress:Hide()
    return dress
end

local function paint(k)
    local D = makeDress()
    local h = D:GetHeight() or 0
    if h <= 1 then h = UIParent:GetHeight() or 768 end
    local bar = math.max(0.01, math.floor(h * BARS * k + 0.5))
    D.top:SetHeight(bar); D.bot:SetHeight(bar)
    D:SetShown(k > 0.001)
end

local function keepVisible(on)
    if on then
        for _, n in ipairs(KEEP) do
            local f = _G[n]
            if f and f.SetIgnoreParentAlpha and kept[f] == nil and not (f.IsForbidden and f:IsForbidden()) then
                local ok, was = pcall(f.GetIgnoreParentAlpha, f)
                kept[f] = ok and was or false
                pcall(f.SetIgnoreParentAlpha, f, true)
            end
        end
    else
        for f, was in pairs(kept) do pcall(f.SetIgnoreParentAlpha, f, was) end
        wipe(kept)
    end
end

----------------------------------------------------------------------
-- Start and stop
----------------------------------------------------------------------
local function start()
    if S.active or InCombatLockdown() or not C.enabled() then return end
    local em = _G.EditModeManagerFrame
    if em and em.IsShown and em:IsShown() then return end
    S.active, S.goal = true, 1
    for cvar, v in pairs(FACE_CVARS) do put(cvar, v) end
    S.oldZoom = GetCameraZoom and GetCameraZoom()
    if S.oldZoom and S.oldZoom > ZOOM + 0.05 and CameraZoomIn then pcall(CameraZoomIn, S.oldZoom - ZOOM) end
    keepVisible(true)
    if drv then drv:Show() end
end

-- snap = true: put everything back at once (combat, reload, leaving the world).
local function stop(snap)
    if not S.active then return end
    S.active, S.goal = false, 0
    if S.oldZoom and GetCameraZoom and not InCombatLockdown() then
        local cur = GetCameraZoom()
        if cur and S.oldZoom > cur + 0.05 and CameraZoomOut then pcall(CameraZoomOut, S.oldZoom - cur) end
    end
    S.oldZoom = nil
    C.restoreCVars()
    if snap then
        S.k = 0
        paint(0)
        UIParent:SetAlpha(1)
        keepVisible(false)
    end
    if drv then drv:Show() end
end

local function tick(self, dt)
    if S.active then
        if not C.talking() then stop(false)
        elseif InCombatLockdown() then stop(true) end
    end
    if S.k < S.goal then S.k = math.min(S.goal, S.k + dt / FADE_IN)
    elseif S.k > S.goal then S.k = math.max(S.goal, S.k - dt / FADE_OUT) end
    paint(S.k)
    UIParent:SetAlpha(1 - S.k)
    if not S.active and S.k <= 0 then
        UIParent:SetAlpha(1)
        keepVisible(false)
        self:Hide()
    end
end

function C.stopNow() stop(true) end

drv = CreateFrame("Frame")
drv:Hide()
drv:SetScript("OnUpdate", tick)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" or e == "PLAYER_LEAVING_WORLD" then
        stop(true)
    else
        -- the window is shown a moment after the event
        C_Timer.After(0.1, function() if C.talking() then start() end end)
    end
end)

-- After a reload or crash in the middle of a talk: put the settings back.
UF.OnLogin(function() C.restoreCVars(); UIParent:SetAlpha(1) end)
