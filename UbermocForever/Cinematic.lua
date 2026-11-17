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
-- Black bar thickness (a share of the screen height, each) and how far the dark edges come in (their depth and strength).
C.BAR_STEPS = { { name = "Off", h = 0 }, { name = "Thin", h = 0.06 }, { name = "Medium", h = 0.11 }, { name = "Thick", h = 0.16 } }
C.EDGE_STEPS = { { name = "Off", size = 0, alpha = 0 }, { name = "Narrow", size = 0.6, alpha = 0.8 }, { name = "Medium", size = 1, alpha = 1 },
    { name = "Wide", size = 1.5, alpha = 1.15 } }
local DEFAULT_BARS, DEFAULT_EDGES = 3, 3   -- Medium, Medium: what it was before it could be changed
local function barStep() local i = UF.DB().cinemaBars or DEFAULT_BARS; return C.BAR_STEPS[i] or C.BAR_STEPS[DEFAULT_BARS] end
local function edgeStep() local i = UF.DB().cinemaEdges or DEFAULT_EDGES; return C.EDGE_STEPS[i] or C.EDGE_STEPS[DEFAULT_EDGES] end
local VIGNETTE = { { size = 0.32, alpha = 0.6 }, { size = 0.17, alpha = 0.5 } }   -- two soft layers = cloudy dark edges
local FADE_IN = 0.8    -- seconds to ease in
local FADE_OUT = 0.6   -- seconds to ease out
local FACE_CVARS = {   -- the camera turns toward the NPC (the same ones UbermocUI uses)
    test_cameraTargetFocusInteractEnable = "1",
    test_cameraTargetFocusInteractStrengthPitch = "1.00",
    test_cameraTargetFocusInteractStrengthYaw = "1.00",
}
-- Nameplates are hidden during the talk (names in the game's own settings code and console list: nameplateShowAll etc.). The game does
-- not allow changing them in combat, so they are put back when combat is over if a fight started in the middle of a talk.
local PLATE_CVARS = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriendlyNpcs", "nameplateShowFriendlyPlayers" }
local function isPlate(c) return c:find("^nameplate") ~= nil end
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
        if not (isPlate(cvar) and InCombatLockdown()) then   -- left for after the fight
            if pcall(setCVar, cvar, v) then b[cvar] = nil end
        end
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
    -- Dark edges: for each side, two gradient layers of different depth, darkest at the screen edge.
    dress.edges = {}
    local SIDES = {
        { "TOPLEFT", "TOPRIGHT", "VERTICAL", false, false },
        { "BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true, false },
        { "TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true, true },
        { "TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false, true },
    }
    for _, sd in ipairs(SIDES) do
        for li = 1, #VIGNETTE do
            local t = dress:CreateTexture(nil, "BACKGROUND")
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:SetPoint(sd[1]); t:SetPoint(sd[2])
            t.orient, t.darkFirst, t.sideways, t.layer = sd[3], sd[4], sd[5], li
            dress.edges[#dress.edges + 1] = t
        end
    end
    dress:Hide()
    return dress
end

local function paint(k)
    local D = makeDress()
    local h = D:GetHeight() or 0
    if h <= 1 then h = UIParent:GetHeight() or 768 end
    local es = edgeStep()
    local bar = math.max(0.01, math.floor(h * barStep().h * k + 0.5))
    D.top:SetHeight(bar); D.bot:SetHeight(bar)
    D.top:SetShown(barStep().h > 0 and k > 0.001); D.bot:SetShown(barStep().h > 0 and k > 0.001)
    local w = D:GetWidth() or 0
    if w <= 1 then w = UIParent:GetWidth() or 1024 end
    for _, t in ipairs(D.edges) do
        local v = VIGNETTE[t.layer]
        local a = math.min(1, v.alpha * es.alpha) * k
        local size = v.size * es.size
        if t.sideways then t:SetWidth(math.max(0.01, w * size)) else t:SetHeight(math.max(0.01, h * size)) end
        local dark, clear = { 0, 0, 0, a }, { 0, 0, 0, 0 }
        local c1, c2 = clear, dark          -- first colour is the left/bottom end
        if t.darkFirst then c1, c2 = dark, clear end
        local ok = CreateColor and pcall(t.SetGradient, t, t.orient, CreateColor(c1[1], c1[2], c1[3], c1[4]), CreateColor(c2[1], c2[2], c2[3], c2[4]))
        if not ok then t:SetColorTexture(0, 0, 0, a * 0.4) end
        t:SetShown(a > 0.001)
    end
    D:SetShown(k > 0.001)
end

local function keepVisible(on)
    if on then
        for _, n in ipairs(KEEP) do
            local f = _G[n]
            if f and f.SetIgnoreParentAlpha and kept[f] == nil and not (f.IsForbidden and f:IsForbidden()) then
                local ok, was = pcall(f.IsIgnoringParentAlpha, f)
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
-- Everything else goes: frames that ignore the interface fade (party frames, objective widgets, chat edit box, other
-- addons' frames) or that are not under UIParent are hidden for the talk by setting their own opacity to 0, and put back at
-- the end. Only the talk window, tooltips, popups and our own frames stay. (Blizzard frames that do this by themselves:
-- party and raid frames, UI widgets, chat edit box, name plates: see docs/RESEARCH-CINEMATIC.md.)
----------------------------------------------------------------------
local dimmed = {}   -- frame -> its opacity before
local function underKeep(f)
    local p, n = f, 0
    while p and n < 50 do
        local name = p.GetName and p:GetName()
        if name and (kept[p] ~= nil or name:find("^UbermocForever")) then return true end
        p = p.GetParent and p:GetParent()
        n = n + 1
    end
    return false
end

local function sweep()
    if InCombatLockdown() or not EnumerateFrames then return end
    local f = EnumerateFrames()
    while f do
        local frame = f
        f = EnumerateFrames(f)
        pcall(function()
            if frame == UIParent or frame == WorldFrame or dimmed[frame] ~= nil then return end
            if frame.IsForbidden and frame:IsForbidden() then return end
            if not (frame.IsShown and frame:IsShown()) then return end
            local parent = frame:GetParent()
            local ignores = frame.IsIgnoringParentAlpha and frame:IsIgnoringParentAlpha()
            local outside = (parent == nil or parent == WorldFrame)
            if not (ignores or outside) then return end
            if underKeep(frame) then return end
            local a = frame:GetAlpha()
            if a and a > 0 then
                dimmed[frame] = a
                frame:SetAlpha(0)
            end
        end)
    end
end

local function undim()
    for frame, a in pairs(dimmed) do pcall(frame.SetAlpha, frame, a) end
    wipe(dimmed)
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
    for _, cvar in ipairs(PLATE_CVARS) do put(cvar, "0") end
    S.oldZoom = GetCameraZoom and GetCameraZoom()
    if S.oldZoom and S.oldZoom > ZOOM + 0.05 and CameraZoomIn then pcall(CameraZoomIn, S.oldZoom - ZOOM) end
    keepVisible(true)
    S.sweepAt = FADE_IN * 0.7   -- the rest of the interface has mostly faded by then
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
        undim()
    end
    if drv then drv:Show() end
end

local function tick(self, dt)
    if S.active then
        S.sweepAt = (S.sweepAt or 0) - dt
        if S.sweepAt <= 0 then S.sweepAt = 1; sweep() end   -- new frames can appear during a talk
    end
    if S.active then
        if not C.talking() then stop(false)
        elseif InCombatLockdown() then stop(true) end
    end
    local previewing = (not S.active) and S.previewUntil and GetTime() < S.previewUntil
    local goal = S.goal
    if not S.active then goal = previewing and 1 or 0 end
    if S.k < goal then S.k = math.min(goal, S.k + dt / FADE_IN)
    elseif S.k > goal then S.k = math.max(goal, S.k - dt / FADE_OUT) end
    paint(S.k)
    if S.active or not (previewing or S.k > 0) then UIParent:SetAlpha(1 - S.k) end   -- a preview shows the bars and edges only
    if not S.active and S.k <= 0 and not previewing then
        UIParent:SetAlpha(1)
        keepVisible(false)
        undim()
        self:Hide()
    end
end

function C.stopNow() stop(true) end

-- A short look at the bars and edges (when a setting is changed), without a talk.
function C.preview()
    if S.active then return end
    S.previewUntil = GetTime() + 2.5
    if drv then drv:Show() end
end
function C.nextBars() local d = UF.DB(); d.cinemaBars = ((d.cinemaBars or DEFAULT_BARS) % #C.BAR_STEPS) + 1; C.preview() end
function C.nextEdges() local d = UF.DB(); d.cinemaEdges = ((d.cinemaEdges or DEFAULT_EDGES) % #C.EDGE_STEPS) + 1; C.preview() end
function C.barsName() return barStep().name end
function C.edgesName() return edgeStep().name end
C._sweep, C._undim = sweep, undim   -- for the offline test

drv = CreateFrame("Frame")
drv:Hide()
drv:SetScript("OnUpdate", tick)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" or e == "PLAYER_LEAVING_WORLD" then
        stop(true)
    elseif e == "PLAYER_REGEN_ENABLED" then
        if not S.active then C.restoreCVars() end   -- the nameplates, if a fight began in the middle of a talk
    else
        -- the window is shown a moment after the event
        C_Timer.After(0.1, function() if C.talking() then start() end end)
    end
end)

-- After a reload or crash in the middle of a talk: put the settings back.
UF.OnLogin(function() C.restoreCVars(); UIParent:SetAlpha(1) end)
