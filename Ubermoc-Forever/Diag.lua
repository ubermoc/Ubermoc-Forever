----------------------------------------------------------------------
-- Ubermoc Forever: a combat timeline, for finding out why something is slow to work after a fight (the author's report: stealth not
-- available straight after killing a mob). It keeps the last 80 events in the saved settings (DB.combatLog) and `/ubf combat` prints the
-- ones around the last time combat ended, with times relative to it:
--   * the game's own signals: combat starting and ending, stealth coming on or off, a cast of the player's starting, succeeding or failing,
--     the red error text the game shows ("You can't do that while in combat"), the target changing, loot opening and closing
--   * what this addon does when combat ends, from the places that react to it (the window buttons, the gamepad layout, the interact key,
--     the nameplate settings), so a delay of ours shows up as work done after combat ended
--   * for six seconds after combat ends: when you are no longer in combat and when Stealth becomes usable (every quarter second)
--   * conversations with an NPC: opening and closing, and when this addon's window buttons and its cinematic camera start and stop
-- The reading after one kill, or after one conversation, tells whether the game still held you in combat (its own timer), refused the cast
-- (and what it said), or never got the key (no cast at all while our buttons were still taken).
-- Nothing here changes anything in the game: it only listens and writes down.
----------------------------------------------------------------------
local _, UF = ...

local D = { MAX = 80, STEALTH = 1784, WINDOW = 6, STEP = 0.25 }
UF.Diag = D

local function text(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return "(hidden)" end
    return tostring(v)
end

local function store()
    local d = UF.DB()
    d.combatLog = d.combatLog or {}
    return d.combatLog
end

function D.log(kind, a, b)
    local L = store()
    L[#L + 1] = { t = GetTime and GetTime() or 0, k = kind, a = text(a), b = text(b) }
    while #L > D.MAX do table.remove(L, 1) end
end
-- the other modules write down what they do through this
function UF.diag(kind, a, b) D.log(kind, a, b) end

local function spellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" then return n end
    end
    return nil
end

local function stealthUsable()
    if IsPlayerSpell and not IsPlayerSpell(D.STEALTH) then return nil end      -- not a stealth class: nothing to watch
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable = pcall(C_Spell.IsSpellUsable, D.STEALTH)
        if ok and not (issecretvalue and issecretvalue(usable)) then return usable and true or false end
    end
    return nil
end

-- the six seconds after combat ends: when combat is over and when Stealth can be used
local watch
local function startWatch()
    watch = { t0 = GetTime and GetTime() or 0, acc = 0, combat = nil, usable = nil }
end

function D.sample()
    if not watch then return end
    local now = GetTime and GetTime() or 0
    if now - watch.t0 > D.WINDOW then watch = nil; return end
    local combat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    if combat ~= watch.combat then watch.combat = combat; D.log("in-combat", combat and "yes" or "no") end
    local usable = stealthUsable()
    if usable ~= nil and usable ~= watch.usable then watch.usable = usable; D.log("stealth-usable", usable and "yes" or "no") end
end

local EVENTS = { "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
                 "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_STEALTH", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                 "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED", "UI_ERROR_MESSAGE",
                 "PLAYER_TARGET_CHANGED", "LOOT_READY", "LOOT_CLOSED", "PLAYER_DEAD" }

-- A refused stealth cast saves itself: when a cast of Stealth, Prowl or Shadowmeld fails, the last ten seconds of the timeline are kept as an
-- incident (DB.stealthIncidents, the last 12) with the game's own error text that follows it, and one line says what happened, so the problem
-- does not have to be repeated on purpose: play, and when it happens the evidence is already there.
local STEALTHY = { "stealth", "prowl", "shadowmeld" }
local function isStealthSpell(id)
    if id == D.STEALTH then return true end
    local n = spellName(id)
    if not n then return false end
    n = n:lower()
    for _, w in ipairs(STEALTHY) do if n:find(w, 1, true) then return true end end
    return false
end

local pending      -- the incident waiting for the game's error text (up to a second)

local function lastKind(kinds, now)
    local L = store()
    for i = #L, 1, -1 do
        if kinds[L[i].k] then return now - L[i].t, L[i].k end
    end
end

local function finishIncident()
    local inc = pending
    pending = nil
    if not inc then return end
    local d = UF.DB()
    d.stealthIncidents = d.stealthIncidents or {}
    d.stealthIncidents[#d.stealthIncidents + 1] = inc
    while #d.stealthIncidents > 12 do table.remove(d.stealthIncidents, 1) end
    local since = inc.sinceFight and string.format("%.1f s after the fight ended", inc.sinceFight)
        or inc.sinceTalk and string.format("%.1f s after the talk ended", inc.sinceTalk) or "with no recent fight or talk"
    UF.say(string.format("Stealth refused %s. In combat: %s. The game said: %s. (/ubf combat has the timeline.)", since, inc.inCombat and "yes" or "no", inc.text or "nothing"))
end

D.finishIncident = finishIncident      -- for the test

local function newIncident(spellID)
    local now = GetTime and GetTime() or 0
    local L = store()
    local events = {}
    for i = math.max(1, #L - 14), #L do
        local e = L[i]
        if now - e.t <= 10 then events[#events + 1] = string.format("%+.2f %s%s%s", e.t - now, e.k, e.a and (" " .. e.a) or "", e.b and (" " .. e.b) or "") end
    end
    local fight = lastKind({ ["combat-ended"] = true }, now)
    local talk = lastKind({ ["talk-ended"] = true }, now)
    pending = { at = now, spell = spellID, inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
                sinceFight = fight and fight <= 30 and fight or nil, sinceTalk = talk and talk <= 30 and talk or nil, events = events }
    if C_Timer and C_Timer.After then C_Timer.After(1, finishIncident) else finishIncident() end
end

-- one event, from the game (also called by the test)
function D.on(event, a, b, c)
    if event == "PLAYER_REGEN_ENABLED" then
        D.log("combat-ended", IsStealthed and IsStealthed() and "stealthed" or "visible")
        startWatch()
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        D.log("talk-ended", event)
        startWatch()
    elseif event == "PLAYER_REGEN_DISABLED" then
        D.log("combat-started")
    elseif event == "UPDATE_STEALTH" then
        D.log("stealth", IsStealthed and IsStealthed() and "on" or "off")
    elseif event:find("^UNIT_SPELLCAST") then
        if a ~= "player" then return end
        D.log(event:sub(6), c, spellName(c))                 -- the spell id (UNIT_SPELLCAST_* gives it third) and its name
        if event == "UNIT_SPELLCAST_FAILED" and not pending and isStealthSpell(c) then newIncident(c) end
    elseif event == "UI_ERROR_MESSAGE" then
        D.log("error-text", b or a)
        if pending and not pending.text then pending.text = text(b or a) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        D.log("target", UnitExists and UnitExists("target") and (UnitIsDead and UnitIsDead("target") and "dead" or "alive") or "none")
    else
        D.log(event:lower())
    end
end

local ev
function D.start()
    if ev then return end
    ev = CreateFrame("Frame")
    for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, e, a, b, c) UF.try("Diag.on", D.on, e, a, b, c) end)
    local acc = 0
    ev:SetScript("OnUpdate", function(_, dt)
        if not watch then return end
        acc = acc + dt
        if acc < D.STEP then return end
        acc = 0
        UF.try("Diag.sample", D.sample)
    end)
end
if UF.OnLogin then UF.OnLogin(D.start) end

-- /ubf combat: the events around the last end of combat, relative to it
function D.report()
    local inc = UF.DB().stealthIncidents
    if inc and #inc > 0 then
        UF.say(#inc .. " refused Stealth cast(s) saved; the last one:")
        local last = inc[#inc]
        UF.say(string.format("  in combat %s, %s, the game said: %s", last.inCombat and "yes" or "no",
            last.sinceFight and string.format("%.1f s after a fight", last.sinceFight) or last.sinceTalk and string.format("%.1f s after a talk", last.sinceTalk) or "no recent fight or talk", tostring(last.text)))
    end
    local L = store()
    if #L == 0 then UF.say("Nothing recorded yet: kill something, try Stealth, then /ubf combat."); return end
    local base
    for i = #L, 1, -1 do if L[i].k == "combat-ended" or L[i].k == "talk-ended" then base = L[i].t; break end end
    base = base or L[#L].t
    UF.say(string.format("Last events (seconds from the end of the fight or the talk%s):", base == L[#L].t and "" or ", which is 0.00"))
    for i = math.max(1, #L - 24), #L do
        local e = L[i]
        UF.say(string.format("  %+.2f  %s%s%s", e.t - base, e.k, e.a and (" " .. e.a) or "", e.b and (" " .. e.b) or ""))
    end
end
