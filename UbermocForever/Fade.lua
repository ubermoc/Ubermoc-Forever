----------------------------------------------------------------------
-- Ubermoc Forever: fading the game's interface elements by situation.
-- Each element (player frame, action bars, minimap ...) can have an opacity from 0 to 100 for four situations: talking to an NPC,
-- in combat, on a flight path, and out of combat, or be hidden for good. An element with no setting is never touched.
-- Opacity is set with the frames' own SetAlpha (not protected, so it works in combat too). Separate from cinematic mode.
-- Notes: docs/RESEARCH-FADE.md. Not tested in the game until the user reports.
----------------------------------------------------------------------
local ADDON, UF = ...
local F = {}
UF.Fade = F

-- Situations in priority order: an element uses the first ACTIVE one it has a value for.
F.STATES = {
    { key = "talking", label = "Talking to an NPC" },
    { key = "combat", label = "In combat" },
    { key = "flight", label = "On a flight path" },
    { key = "idle", label = "Out of combat" },
}

-- Elements, in the lists they are shown under (only one list is open at a time on the options page). Frame names that this game does
-- not have are skipped at run time. A frame must not sit inside another frame of the same element's list.
F.CATEGORIES = {
    { name = "Unit frames", elements = {
        { key = "player", label = "Player frame", frames = { "PlayerFrame" } },
        { key = "pet", label = "Pet frame", frames = { "PetFrame" } },
        { key = "target", label = "Target frame", frames = { "TargetFrame", "TargetFrameToT" } },
        { key = "focus", label = "Focus frame", frames = { "FocusFrame" } },
        { key = "party", label = "Party and raid frames", frames = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" } },
        { key = "castbar", label = "Player cast bar", frames = { "PlayerCastingBarFrame" } },
        { key = "buffs", label = "Buffs", frames = { "BuffFrame" } },
        { key = "debuffs", label = "Debuffs", frames = { "DebuffFrame" } },
    } },
    { name = "Action bars", elements = {
        { key = "mainbar", label = "Main action bar", frames = { "MainActionBar" } },
        { key = "sidebars", label = "Extra action bars", frames = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" } },
        { key = "classbars", label = "Stance, pet and possess bars", frames = { "StanceBar", "PetActionBar", "PossessActionBar" } },
        { key = "extra", label = "Extra and zone abilities", frames = { "ExtraAbilityContainer" } },
        { key = "xpbar", label = "Experience and reputation bar", frames = { "StatusTrackingBarManager" } },
    } },
    { name = "Minimap and trackers", elements = {
        { key = "minimap", label = "Minimap", frames = { "MinimapCluster" } },
        { key = "tracker", label = "Quest and objective tracker", frames = { "ObjectiveTrackerFrame" } },
        { key = "queue", label = "Queue status eye", frames = { "QueueStatusButton" } },
    } },
    { name = "Chat and menus", elements = {
        { key = "chat", label = "Chat windows", frames = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4" } },
        { key = "chattabs", label = "Chat tabs", frames = { "ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab" } },
        { key = "micro", label = "Micro menu", frames = { "MicroMenuContainer" } },
        { key = "bags", label = "Bag bar", frames = { "BagsBar" } },
    } },
}

local FADE_TIME = 0.4
local STEP = 0.1   -- the page's - and + buttons move the value by this much

----------------------------------------------------------------------
-- Settings: UF.DB().fade[elementKey] = { talking = 0..1, combat = ..., flight = ..., idle = ..., hide = true }
----------------------------------------------------------------------
local function store()
    local d = UF.DB()
    d.fade = d.fade or {}
    return d.fade
end
function F.get(key) return store()[key] end
function F.value(key, state) local o = store()[key]; return o and o[state] end
function F.hidden(key) local o = store()[key]; return o and o.hide == true or false end

local function prune(key)
    local o = store()[key]
    if o and next(o) == nil then store()[key] = nil end
end

function F.set(key, state, v)
    local s = store()
    s[key] = s[key] or {}
    if v == nil then s[key][state] = nil else s[key][state] = math.max(0, math.min(1, v)) end
    prune(key)
    F.evaluate()
end
-- Moves a state's value one step (-1 or +1); from "normal" a step down starts at 90 %, a step up at 100 %.
function F.step(key, state, dir)
    local v = F.value(key, state)
    if v == nil then v = 1 end
    v = math.floor(v / STEP + 0.5) * STEP + dir * STEP
    F.set(key, state, v)
end
function F.toggleHide(key)
    local s = store()
    s[key] = s[key] or {}
    s[key].hide = (not s[key].hide) or nil
    prune(key)
    F.evaluate()
end
function F.reset(key) store()[key] = nil; F.evaluate() end

function F.percentText(v) return v == nil and "Normal" or (math.floor(v * 100 + 0.5) .. "%") end

----------------------------------------------------------------------
-- Which situations are on right now
----------------------------------------------------------------------
local function shown(n) local f = _G[n]; return f and f.IsShown and f:IsShown() end
function F.active()
    local a = {}
    a.talking = (shown("GossipFrame") or shown("QuestFrame")) and true or false
    a.combat = (InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))) and true or false
    a.flight = (UnitOnTaxi and UnitOnTaxi("player")) and true or false
    a.idle = not a.combat
    return a
end

-- The opacity wanted for an element now: 0 when hidden, else the first active situation it has a value for, else nil (left alone).
function F.goal(key, active)
    local o = store()[key]
    if not o then return nil end
    if o.hide then return 0 end
    for _, st in ipairs(F.STATES) do
        if active[st.key] and o[st.key] ~= nil then return o[st.key] end
    end
    return nil
end

----------------------------------------------------------------------
-- Applying
----------------------------------------------------------------------
local byKey = {}
for _, c in ipairs(F.CATEGORIES) do for _, e in ipairs(c.elements) do byKey[e.key] = e end end
F.byKey = byKey

local function frameOf(name)
    local f = _G[name]
    if type(f) == "table" and f.SetAlpha and not (f.IsForbidden and f:IsForbidden()) then return f end
end

local cur = {}         -- element key -> opacity shown now (1 when not touched)
local touchedKeys = {} -- element keys whose frames we have set
local driver = CreateFrame("Frame")
driver:Hide()
local acc = 0

local function apply(key, a)
    for _, name in ipairs(byKey[key].frames) do
        local f = frameOf(name)
        if f then pcall(f.SetAlpha, f, a) end
    end
end

local reapply = 0
local function tick(self, dt)
    local active = F.active()
    local moving = false
    reapply = reapply + dt
    local force = reapply >= 0.5
    if force then reapply = 0 end
    local any = false
    for key in pairs(byKey) do
        local goal = F.goal(key, active)
        local c = cur[key] or 1
        if goal ~= nil or touchedKeys[key] then
            any = true
            local target = goal or 1
            local before = c
            if c < target then c = math.min(target, c + dt / FADE_TIME)
            elseif c > target then c = math.max(target, c - dt / FADE_TIME) end
            cur[key] = c
            if c ~= before or force then apply(key, c) end   -- the game resets some frames' opacity by itself: re-applied twice a second
            touchedKeys[key] = (goal ~= nil) or (c ~= 1) or nil
            if c ~= target then moving = true end
        end
    end
    -- nothing set and nothing easing back: the driver rests (the poll below wakes it)
    if not any and not moving then self:Hide() end
end
driver:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    local d = acc
    acc = 0
    tick(self, d)
end)

function F.evaluate() driver:Show() end

-- Opacity put back for everything (the options page's "Reset all", and when the addon is switched off).
function F.resetAll() UF.DB().fade = {}; F.evaluate() end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "UNIT_FLAGS" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() F.evaluate() end)
-- The talk windows close without every event: keep looking while there are settings.
local poll = 0
ev:SetScript("OnUpdate", function(_, dt)
    poll = poll + dt
    if poll < 0.5 then return end
    poll = 0
    if next(store()) ~= nil then driver:Show() end
end)
UF.OnLogin(function() F.evaluate() end)
