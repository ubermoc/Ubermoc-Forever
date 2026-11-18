----------------------------------------------------------------------
-- Ubermoc Forever: fading the game's interface elements by situation.
-- Each element (player frame, action bars, minimap ...) can have an opacity from 0 to 100 for three situations: in combat, on a flight
-- path, and out of combat, or be hidden for good. (Talking to an NPC is not one of them: cinematic mode handles that by itself.) An element with no setting is never touched.
-- Opacity is set with the frames' own SetAlpha (not protected, so it works in combat too). Separate from cinematic mode.
-- Notes: docs/RESEARCH-FADE.md. Not tested in the game until the user reports.
----------------------------------------------------------------------
local ADDON, UF = ...
local F = {}
UF.Fade = F

-- Situations in priority order: an element uses the first ACTIVE one it has a value for.
F.STATES = {
    { key = "combat", label = "In combat" },
    { key = "flight", label = "On a flight path" },
    { key = "idle", label = "Out of combat" },
}

-- Elements, in the lists they are shown under (only one list is open at a time on the options page). Frame names (or dotted paths such as
-- "MainActionBar.EndCaps.LeftEndCap") that this game does not have are skipped at run time and shown as "not available". part = true marks a piece
-- that sits inside another element's frame: when it has a setting it stops following its parent's opacity and gets its own.
-- Names come from Forever's Blizzard source (docs/RESEARCH-FADE.md, docs/PROPOSAL-FADE-ELEMENTS.md).
local function E(key, label, frames, extra)
    local e = { key = key, label = label, frames = frames or {} }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    return e
end
local PART = { part = true }

-- The parts of a unit frame (player, target, focus) follow one layout in the game's XML.
local function unitParts(prefix, root, container, contentName, main, contextual, label)
    return {
        E(prefix, label .. " (all of it)", { root }),
        E(prefix .. "_portrait", label .. ": portrait", { root .. "." .. container .. ".Portrait", root .. "." .. container .. ".PlayerPortrait" }, PART),
        E(prefix .. "_art", label .. ": frame art", { root .. "." .. container .. ".FrameTexture" }, PART),
        E(prefix .. "_name", label .. ": name", { root .. "." .. contentName .. "." .. main .. ".Name" }, PART),
        E(prefix .. "_health", label .. ": health bar", { root .. "." .. contentName .. "." .. main .. ".HealthBarsContainer" }, PART),
        E(prefix .. "_power", label .. ": power bar", { root .. "." .. contentName .. "." .. main .. ".ManaBarArea", root .. "." .. contentName .. "." .. main .. ".ManaBar" }, PART),
        E(prefix .. "_icons", label .. ": icons and markers", { root .. "." .. contentName .. "." .. contextual }, PART),
    }
end
local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do for _, e in ipairs(list) do out[#out + 1] = e end end
    return out
end

F.CATEGORIES = {
    { name = "Main bar parts", elements = {
        E("mb_leftcap", "Left end cap (gryphon)", { "MainActionBar.EndCaps.LeftEndCap" }, PART),
        E("mb_rightcap", "Right end cap (gryphon)", { "MainActionBar.EndCaps.RightEndCap" }, PART),
        E("mb_border", "Bar border art", { "MainActionBar.BorderArt" }, PART),
        E("mb_page", "Page number and arrows", { "MainActionBar.ActionBarPageNumber" }, PART),
        E("mainbar", "Main action bar (all of it)", { "MainActionBar" }),
    } },
    { name = "Action bars", elements = {
        E("bar2", "Action bar 2", { "MultiBarBottomLeft" }),
        E("bar3", "Action bar 3", { "MultiBarBottomRight" }),
        E("bar4", "Action bar 4", { "MultiBarRight" }),
        E("bar5", "Action bar 5", { "MultiBarLeft" }),
        E("bar6", "Action bar 6", { "MultiBar5" }),
        E("bar7", "Action bar 7", { "MultiBar6" }),
        E("bar8", "Action bar 8", { "MultiBar7" }),
        E("stance", "Stance bar", { "StanceBar" }),
        E("petbar", "Pet action bar", { "PetActionBar" }),
        E("possess", "Possess bar", { "PossessActionBar" }),
        E("extrabtn", "Extra action button", { "ExtraActionBarFrame" }),
        E("zoneabil", "Zone ability", { "ExtraAbilityContainer" }),
        E("vehicleexit", "Vehicle exit button", { "MainMenuBarVehicleLeaveButton" }),
        E("totembar", "Totem bar", { "MultiCastActionBarFrame" }),
    } },
    { name = "Player frame", elements = join(
        unitParts("player", "PlayerFrame", "PlayerFrameContainer", "PlayerFrameContent", "PlayerFrameContentMain", "PlayerFrameContentContextual", "Player frame")
    ) },
    { name = "Target frame", elements = join(
        unitParts("target", "TargetFrame", "TargetFrameContainer", "TargetFrameContent", "TargetFrameContentMain", "TargetFrameContentContextual", "Target frame"),
        { E("tot", "Target of target", { "TargetFrame.totFrame", "TargetFrameToT" }, PART) }
    ) },
    { name = "Focus frame", elements = join(
        unitParts("focus", "FocusFrame", "TargetFrameContainer", "TargetFrameContent", "TargetFrameContentMain", "TargetFrameContentContextual", "Focus frame"),
        { E("fot", "Focus target", { "FocusFrame.totFrame", "FocusFrameToT" }, PART) }
    ) },
    { name = "Other unit frames", elements = {
        E("pet", "Pet frame", { "PetFrame" }),
        E("pet_portrait", "Pet frame: portrait", { "PetFrame.Portrait" }, PART),
        E("boss", "Boss frames", { "BossTargetFrameContainer" }),
        E("party", "Party frames", { "PartyFrame", "CompactPartyFrame" }),
        E("raid", "Raid frames", { "CompactRaidFrameContainer" }),
        E("raidmgr", "Raid frame manager (side tab)", { "CompactRaidFrameManager" }),
        E("arena", "Arena frames", { "CompactArenaFrame", "ArenaEnemyFramesContainer", "ArenaEnemyMatchFramesContainer", "ArenaEnemyPrepFramesContainer" }),
        E("castbar", "Player cast bar", { "PlayerCastingBarFrame" }),
        E("petcast", "Pet cast bar", { "PetCastingBarFrame" }),
    } },
    { name = "Class resources", elements = {
        E("classres", "Class resource bar (your class)", { "PlayerBottomManagedFrameContainer", "ComboFrame", "RuneFrame", "PaladinPowerBarFrame", "WarlockPowerFrame",
            "MageArcaneChargesFrame", "MonkHarmonyBarFrame", "EssencePlayerFrame", "DruidComboPointBarFrame", "RogueComboPointBarFrame", "InsanityBarFrame",
            "DemonHunterSoulFragmentsBar", "DevourerFuryBarFrame", "EvokerEbonMightBar" }, PART),
        E("stagger", "Monk stagger bar", { "MonkStaggerBar" }, PART),
        E("altpower", "Alternate power bar", { "AlternatePowerBar", "PlayerPowerBarAlt", "PlayerFrameAlternatePowerBarArea" }, PART),
        E("totems", "Totem icons", { "TotemFrame" }),
    } },
    { name = "Buffs and auras", elements = {
        E("buffs", "Buffs", { "BuffFrame" }),
        E("debuffs", "Debuffs", { "DebuffFrame" }),
        E("deadly", "Deadly debuffs", { "DeadlyDebuffFrame" }),
        E("defensives", "External defensives", { "ExternalDefensivesFrame" }),
    } },
    { name = "Minimap", elements = {
        E("minimap", "Minimap (all of it)", { "MinimapCluster" }),
        E("mm_map", "The map itself", { "Minimap" }, PART),
        E("mm_back", "Border and background", { "MinimapBackdrop", "MinimapCluster.BorderTop", "MinimapCluster.Background" }, PART),
        E("mm_zone", "Zone name", { "MinimapCluster.ZoneTextButton", "MinimapZoneTextButton" }, PART),
        E("mm_track", "Tracking button", { "MinimapCluster.Tracking" }, PART),
        E("mm_mail", "Mail and crafting icons", { "MinimapCluster.IndicatorFrame" }, PART),
        E("mm_zoom", "Zoom buttons", { "Minimap.ZoomIn", "Minimap.ZoomOut" }, PART),
        E("mm_cal", "Calendar button", { "GameTimeFrame" }, PART),
        E("mm_clock", "Clock", { "TimeManagerClockButton" }, PART),
        E("mm_exp", "Expansion button", { "ExpansionLandingPageMinimapButton" }, PART),
        E("mm_diff", "Instance difficulty", { "MinimapCluster.InstanceDifficulty", "MiniMapInstanceDifficulty", "GuildInstanceDifficulty" }, PART),
        E("mm_coords", "Coordinates", { "MinimapCluster.PlayerCoords", "MinimapCluster.CoordText" }, PART),
        E("mm_addons", "Addon list button", { "AddonCompartmentFrame" }, PART),
        E("queue", "Queue status eye", { "QueueStatusButton" }),
    } },
    { name = "Quests and objectives", elements = {
        E("tracker", "Objective tracker (all of it)", { "ObjectiveTrackerFrame" }),
        E("tr_quest", "Quests", { "QuestObjectiveTracker" }, PART),
        E("tr_campaign", "Campaign quests", { "CampaignQuestObjectiveTracker" }, PART),
        E("tr_world", "World quests", { "WorldQuestObjectiveTracker" }, PART),
        E("tr_bonus", "Bonus objectives", { "BonusObjectiveTracker" }, PART),
        E("tr_ach", "Achievements", { "AchievementObjectiveTracker" }, PART),
        E("tr_scen", "Scenario", { "ScenarioObjectiveTracker" }, PART),
        E("tr_prof", "Professions recipes", { "ProfessionsRecipeTracker" }, PART),
        E("tr_month", "Monthly activities", { "MonthlyActivitiesObjectiveTracker" }, PART),
        E("tr_tasks", "Tasks", { "InitiativeTasksObjectiveTracker", "AdventureObjectiveTracker" }, PART),
        E("tr_widget", "Objective widgets", { "UIWidgetObjectiveTracker", "ObjectiveTrackerUIWidgetContainer" }, PART),
    } },
    { name = "Alerts and text", elements = {
        E("alerts", "Alert popups", { "AlertFrame" }),
        E("zonetext", "Zone name", { "ZoneTextFrame" }),
        E("subzone", "Sub-zone name", { "SubZoneTextFrame" }),
        E("banner", "Boss banner", { "BossBanner" }),
        E("toasts", "Event toasts", { "EventToastManagerFrame" }),
        E("raidwarn", "Raid warnings and boss emotes", { "RaidWarningFrame", "RaidBossEmoteFrame" }),
        E("talkinghead", "Talking head", { "TalkingHeadFrame" }),
        E("errors", "Red error messages", { "UIErrorsFrame" }),
        E("loc", "Loss of control", { "LossOfControlFrame" }),
        E("procs", "Spell proc glows", { "SpellActivationOverlayFrame" }),
        E("combattext", "Floating combat text", { "CombatText" }),
        E("timers", "Timers (breath, fatigue)", { "TimerTracker", "MirrorTimerContainer" }),
        E("lowhealth", "Low health screen edge", { "LowHealthFrame" }),
        E("readycheck", "Ready check", { "ReadyCheckFrame" }),
        E("lootroll", "Group loot history", { "GroupLootHistoryFrame" }),
    } },
    { name = "Widgets and overlays", elements = {
        E("w_top", "Widgets: top centre", { "UIWidgetTopCenterContainerFrame" }),
        E("w_mini", "Widgets: below the minimap", { "UIWidgetBelowMinimapContainerFrame" }),
        E("w_power", "Widgets: power bar", { "UIWidgetPowerBarContainerFrame" }),
        E("w_center", "Widgets: centre screen", { "UIWidgetCenterScreenContainerFrame" }),
        E("durability", "Durability figure", { "DurabilityFrame" }),
        E("vehicleseat", "Vehicle seats", { "VehicleSeatIndicator" }),
        E("fps", "Frame rate", { "FramerateFrame" }),
        E("encounter", "Encounter bar", { "EncounterBar" }),
        E("meter", "Damage meter", { "DamageMeter" }),
        E("cd_ess", "Essential cooldowns", { "EssentialCooldownViewer" }),
        E("cd_util", "Utility cooldowns", { "UtilityCooldownViewer" }),
        E("cd_buffs", "Tracked buffs", { "BuffIconCooldownViewer" }),
        E("cd_bars", "Tracked buff bars", { "BuffBarCooldownViewer" }),
        E("prd", "Personal resource display", { "PersonalResourceDisplayFrame" }),
        E("npenemy", "Enemy nameplates", {}, { plates = "enemy" }),
        E("npfriendly", "Friendly nameplates", {}, { plates = "friendly" }),
        E("digsite", "Archaeology progress", { "ArcheologyDigsiteProgressBar" }),
    } },
}

-- The chat parts are set on the Chat page of the options window (ChatPage.lua), not on the Fading page: they are not in F.CATEGORIES.
F.CHAT = {
    E("chat", "Chat windows", { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4" }),
    E("chattabs", "Chat tabs", { "GeneralDockManager", "ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab" }),
    E("chatedit", "Chat edit box", { "ChatFrame1EditBox" }),
    E("chatbtns", "Chat buttons", { "ChatFrame1ButtonFrame", "ChatFrameMenuButton", "ChatFrameChannelButton" }),
    E("quickjoin", "Quick join button", { "QuickJoinToastButton" }),
}

-- Some frames hand out SECRET values (a boolean from IsMouseOver or IsIgnoringParentAlpha on a frame this addon cannot read, such as the combo
-- point frame): a test on one raises an error (340 times in a report). A secret value counts as "no".
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

F._plain = plain   -- for the offline test
-- The gamepad bar (GamepadBar.lua) has its own opacity, set on the Bars page, not on the Fading page: it is not in F.CATEGORIES.
-- Its frame is our own root frame: the buttons follow its opacity because GamepadBar multiplies by it.
-- The micro menu, bags and XP bar live here too (not in F.CATEGORIES): their fading is set on the Bars page only, so no setting is in two places.
F.GBAR = {
    E("gbar", "Gamepad bar", { "UbermocForeverGamepadBar" }),
    E("micro", "Micro menu", { "MicroMenuContainer" }),
    E("bags", "Bag bar", { "BagsBar" }),
    -- the mouse is over the bars themselves, not over the manager frame (whose area is larger and overlaps what sits at the bottom of the screen)
    E("xpall", "Experience bars (all of them)", { "StatusTrackingBarManager" }, { hover = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" } }),
}

local FADE_TIME = 0.4
local STEP = 0.1   -- the page's - and + buttons move the value by this much

----------------------------------------------------------------------
-- Settings: UF.DB().fade[elementKey] = { combat = 0..1, flight = ..., idle = ..., hide = true }
----------------------------------------------------------------------
local function store()
    local d = UF.DB()
    d.fade = d.fade or {}
    if not d.fadeNoTalk then   -- 1.3.50: the "talking to an NPC" situation was removed: its values are dropped once
        d.fadeNoTalk = true
        for k, o in pairs(d.fade) do
            o.talking = nil
            if next(o) == nil then d.fade[k] = nil end
        end
    end
    if not d.fadeV2 then   -- 1.3.51: the lists were split into more elements: settings on the old combined ones go to each new one
        d.fadeV2 = true
        local MOVE = {
            sidebars = { "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8" },
            classbars = { "stance", "petbar", "possess" },
            extra = { "zoneabil" },
            xpbar = { "xpall" },
        }
        for old, news in pairs(MOVE) do
            local o = d.fade[old]
            if o then
                for _, k in ipairs(news) do
                    d.fade[k] = {}
                    for key, v in pairs(o) do d.fade[k][key] = v end
                end
                d.fade[old] = nil
            end
        end
    end
    if not d.fadeNoParts then   -- 1.3.95: parts of the bags and the XP bars were removed (they sat inside the Bars page's elements and fought them)
        d.fadeNoParts = true
        d.fade.bagtoggle, d.fade.xpmain, d.fade.xpsecond = nil, nil, nil
        -- the frames those settings had made independent of their parent are given back by apply() when the key is no longer known (not needed: nothing applies to them now)
    end
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
function F.reset(key)
    store()[key] = nil
    local d = UF.DB()
    if d.fadeMouseBy then d.fadeMouseBy[key] = nil end
    F.evaluate()
end

-- One universal setting: the opacity any element that has a setting goes to while the mouse is over it (never lower than its own value).
-- nil = off. Elements set to Hide for good stay hidden.
-- The mouse-over opacity of all faded elements: 100% to start with (a faded element comes back fully while the mouse is over it); "Off" is remembered.
-- 1.3.120: a part can have a mouse-over opacity of its own (the Chat page): a number, false for Off, nil to follow the universal one.
function F.mouseOwn(key)
    local d = UF.DB()
    return d.fadeMouseBy and key and d.fadeMouseBy[key]
end
function F.mouse(key)
    local own = F.mouseOwn(key)
    if own == false then return nil end
    if own ~= nil then return own end
    local d = UF.DB()
    if d.fadeMouse ~= nil then return d.fadeMouse end
    if d.fadeMouseOff then return nil end
    return 1
end
function F.setMouse(v)
    local d = UF.DB()
    if v == nil then d.fadeMouse = nil; d.fadeMouseOff = true
    else d.fadeMouse = math.max(0, math.min(1, v)); d.fadeMouseOff = nil end
    F.evaluate()
end
function F.stepMouse(dir)
    local v = F.mouse()
    if v == nil then v = 1 end
    F.setMouse(math.floor(v / STEP + 0.5) * STEP + dir * STEP)
end
-- v: nil = follow the universal setting, false = Off for this part, a number 0..1
function F.setMouseOwn(key, v)
    local d = UF.DB()
    d.fadeMouseBy = d.fadeMouseBy or {}
    if v == nil or v == false then d.fadeMouseBy[key] = v
    else d.fadeMouseBy[key] = math.max(0, math.min(1, v)) end
    F.evaluate()
end
function F.stepMouseOwn(key, dir)
    local v = F.mouse(key)
    if v == nil then v = 1 end
    F.setMouseOwn(key, math.floor(v / STEP + 0.5) * STEP + dir * STEP)
end

function F.percentText(v) return v == nil and "Normal" or (math.floor(v * 100 + 0.5) .. "%") end

----------------------------------------------------------------------
-- Which situations are on right now
----------------------------------------------------------------------
function F.active()
    local a = {}
    a.combat = (InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))) and true or false
    a.flight = (UnitOnTaxi and UnitOnTaxi("player")) and true or false
    a.idle = not a.combat
    return a
end

-- The opacity wanted for an element now: 0 when hidden, else the first active situation it has a value for, else nil (left alone).
-- Settings that come from another page rather than from the element's own situations (the chat edit box fading by itself, Chat.lua):
-- used only when the element has no value of its own for the situation that is on.
F.implicit = {}
local function implicitGoal(key)
    local fn = F.implicit[key]
    return fn and fn() or nil
end
function F.goal(key, active)
    local o = store()[key]
    if not o then return implicitGoal(key) end
    if o.hide then return 0 end
    for _, st in ipairs(F.STATES) do
        if active[st.key] and o[st.key] ~= nil then return o[st.key] end
    end
    return implicitGoal(key)
end

----------------------------------------------------------------------
-- Applying
----------------------------------------------------------------------
local byKey = {}
for _, c in ipairs(F.CATEGORIES) do for _, e in ipairs(c.elements) do byKey[e.key] = e end end
for _, e in ipairs(F.CHAT) do byKey[e.key] = e end
for _, e in ipairs(F.GBAR) do byKey[e.key] = e end
F.byKey = byKey

-- A frame by name or by a dotted path ("MainActionBar.EndCaps.LeftEndCap"); nil when this game does not have it.
local function frameOf(name)
    local f = _G
    for part in string.gmatch(name, "[^%.]+") do
        if type(f) ~= "table" then return nil end
        f = f[part]
        if f == nil then return nil end
    end
    if f == _G or type(f) ~= "table" or not f.SetAlpha then return nil end
    if f.IsForbidden and f:IsForbidden() then return nil end
    return f
end
F._frameOf = frameOf

-- How many of an element's frames this game has (nameplates always count: they come and go).
function F.found(e)
    if e.plates then return 1, 1 end
    local n = 0
    for _, name in ipairs(e.frames) do if frameOf(name) then n = n + 1 end end
    return n, #e.frames
end

local cur = {}         -- element key -> opacity shown now (1 when not touched)
local touchedKeys = {} -- element keys whose frames we have set
local ignoring = {}    -- frame -> whether it ignored its parent's opacity before we changed that (parts only)
local driver = CreateFrame("Frame")
driver:Hide()
local acc = 0

-- Nameplates are not under one frame: each one's unit frame is set. enemy = can be attacked.
local function applyPlates(kind, a)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame
        local unit = plate.namePlateUnitToken or (uf and uf.unit)
        if uf and unit and uf.SetAlpha and not (uf.IsForbidden and uf:IsForbidden()) then
            local enemy = UnitCanAttack and UnitCanAttack("player", unit) and true or false
            if (kind == "enemy") == enemy then pcall(uf.SetAlpha, uf, a) end
        end
    end
end

-- A part sits inside another element's frame: with its own setting it stops following that frame's opacity, and goes back to it when the
-- setting is cleared.
local function setIndependent(f, on)
    if not f.SetIgnoreParentAlpha then return end
    if on then
        if ignoring[f] == nil then
            local ok, was = pcall(f.IsIgnoringParentAlpha, f)
            ignoring[f] = (ok and plain(was)) and true or false
            pcall(f.SetIgnoreParentAlpha, f, true)
        end
    elseif ignoring[f] ~= nil then
        pcall(f.SetIgnoreParentAlpha, f, ignoring[f])
        ignoring[f] = nil
    end
end

local function apply(key, a, independent)
    local e = byKey[key]
    if e.plates then applyPlates(e.plates, a); return end
    for _, name in ipairs(e.frames) do
        local f = frameOf(name)
        if f then
            if e.part then setIndependent(f, independent) end
            pcall(f.SetAlpha, f, a)
        end
    end
end

F._apply = apply   -- for the offline test

-- Is the mouse over any of the element's frames? A texture has no mouse area, so its parent frame is used.
local function hovering(key)
    local e = byKey[key]
    if not e or e.plates then return false end
    for _, name in ipairs(e.hover or e.frames) do
        local f = frameOf(name)
        if f then
            local target = f.IsMouseOver and f or (f.GetParent and f:GetParent())
            if target and target.IsMouseOver then
                local ok, over = pcall(target.IsMouseOver, target)
                if ok and plain(over) then return true end
            end
        end
    end
    return false
end
-- The opacity wanted for an element now, with the mouse-over setting taken into account.
function F.wanted(key, active, isOver)
    local goal = F.goal(key, active)
    local m = F.mouse(key)
    if goal ~= nil and m ~= nil and goal < m and not F.hidden(key) and isOver then return m end
    return goal
end

-- Reveals (used by Chat.lua): an element that has a setting is shown fully for a while (a new chat message) or until released (the chat
-- edit box in use), then fades back over its own time instead of the usual quick one. Hidden-for-good elements stay hidden.
local revealUntil, held, revealFade = {}, {}, {}
function F.reveal(key, seconds, fadeSeconds)
    revealUntil[key] = GetTime() + (seconds or 5)
    revealFade[key] = fadeSeconds
    driver:Show()
end
function F.hold(key, on)
    held[key] = on or nil
    driver:Show()
end
local function revealed(key) return held[key] or (revealUntil[key] and GetTime() < revealUntil[key]) end
F._revealed = function(key) return revealed(key) and true or false end   -- for the offline test

-- Is the game's Edit Mode open? Then no fading is applied (what is hidden must be seen to be moved).
function F.editing()
    local m = _G.EditModeManagerFrame
    if m and m.IsShown then
        local ok, v = pcall(m.IsShown, m)
        return ok and not (issecretvalue and issecretvalue(v)) and v == true
    end
    return false
end

-- Elements that are hidden for good by something else (the gamepad layout hides the game's bottom art): key -> function returning true.
-- The universal mouse-over opacity and the reveals do not lift them.
F.forced = {}

-- The opacity wanted for an element right now, everything taken into account (isOver may be a function, asked only when needed).
function F.target(key, active, isOver)
    if F.editing() then return nil end
    local fc = F.forced[key]
    if fc and fc() then return 0 end
    local goal = F.goal(key, active)
    if goal ~= nil and F.mouse(key) ~= nil and goal < F.mouse(key) then
        local over = isOver
        if type(isOver) == "function" then over = isOver() end
        goal = F.wanted(key, active, over)
    end
    if goal ~= nil and not F.hidden(key) and revealed(key) then goal = 1 end
    return goal
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
        local goal = F.target(key, active, function() return hovering(key) end)
        local c = cur[key] or 1
        if goal ~= nil or touchedKeys[key] then
            any = true
            local target = goal or 1
            local before = c
            if c < target then c = math.min(target, c + dt / FADE_TIME)
            elseif c > target then c = math.max(target, c - dt / (revealFade[key] or FADE_TIME)) end
            if c == target and not revealed(key) then revealFade[key] = nil end
            cur[key] = c
            if c ~= before or force then apply(key, c, goal ~= nil or c ~= 1) end   -- the game resets some frames' opacity by itself: re-applied twice a second
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

-- /ubf fade: which elements this game has, and the ones it does not (so a wrong name can be found).
function F.report()
    local have, missing, total = 0, {}, 0
    for _, c in ipairs(F.CATEGORIES) do
        for _, e in ipairs(c.elements) do
            total = total + 1
            if F.found(e) > 0 then have = have + 1 else missing[#missing + 1] = e.label end
        end
    end
    for _, e in ipairs(F.CHAT) do
        total = total + 1
        if F.found(e) > 0 then have = have + 1 else missing[#missing + 1] = e.label end
    end
    UF.say("Fading: " .. have .. " of " .. total .. " elements found in this game.")
    if #missing > 0 then UF.say("Not available: " .. table.concat(missing, ", ") .. ".") end
end

-- Copy and paste an element's settings, and put one element's settings on every element of the list it is in.
local clipboard
local function copyOf(o) local c = {}; for k, v in pairs(o or {}) do c[k] = v end; return c end
function F.copy(key) local o = store()[key]; clipboard = { from = byKey[key] and byKey[key].label or key, data = copyOf(o) }; return clipboard end
function F.hasClipboard() return clipboard ~= nil end
function F.clipboardFrom() return clipboard and clipboard.from end
function F.paste(key)
    if not clipboard then return false end
    local s = store()
    if next(clipboard.data) == nil then s[key] = nil else s[key] = copyOf(clipboard.data) end
    F.evaluate()
    return true
end
function F.applyToList(key)
    local s = store()
    local data = copyOf(s[key])
    for _, c in ipairs(F.CATEGORIES) do
        local inList = false
        for _, e in ipairs(c.elements) do if e.key == key then inList = true end end
        if inList then
            for _, e in ipairs(c.elements) do
                if e.key ~= key then
                    if next(data) == nil then s[e.key] = nil else s[e.key] = copyOf(data) end
                end
            end
            F.evaluate()
            return #c.elements - 1
        end
    end
    return 0
end

-- Opacity put back for everything (the options page's "Reset all", and when the addon is switched off).
function F.resetAll()   -- the Fading page's elements; the chat parts have their own page and are kept
    local s = store()
    for key in pairs(s) do
        local chat = false
        for _, e in ipairs(F.CHAT) do if e.key == key then chat = true end end
        for _, e in ipairs(F.GBAR) do if e.key == key then chat = true end end
        if not chat then s[key] = nil end
    end
    F.evaluate()
end
function F.resetChat() local s = store(); for _, e in ipairs(F.CHAT) do s[e.key] = nil end; F.evaluate() end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "UNIT_FLAGS", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() F.evaluate() end)
-- Flying starts and ends without a dedicated event here: keep looking while there are settings.
local poll = 0
ev:SetScript("OnUpdate", function(_, dt)
    poll = poll + dt
    if poll < 0.5 then return end
    poll = 0
    if next(store()) ~= nil then driver:Show() end
end)
UF.OnLogin(function() F.evaluate() end)
