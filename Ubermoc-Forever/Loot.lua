----------------------------------------------------------------------
-- Ubermoc Forever: fast loot
--
-- Ported from Ubermoc UI (Main.lua, "Fast loot"): with the game's Auto Loot on, every slot is taken the moment the loot
-- opens (LOOT_READY, Blizzard_APIDocumentationGenerated/LootDocumentation.lua, payload autoloot) instead of one item per
-- game tick, and the game's loot window stays invisible while that happens. Anything that could not be taken (full
-- bags, a bind-on-pickup item waiting for its question, a roll) shows the window again.
-- As the master looter nothing is taken, so the game's "who gets this item" choice still comes up (the idea of the
-- QuickLooter addon; in Forever the loot method is C_PartyInfo.GetLootMethod, PartyInfoDocumentation.lua: method 2 =
-- Masterlooter, LootConstantsDocumentation.lua, and masterLootPartyID 0 = the player).
-- The game keeps Auto Loot per character, so it is switched on once for each character (as Ubermoc UI does).
--
-- Two ways of taking the slots (the option below, SavedVariables fastLootLoop, default "two"):
--   one   every slot at once, right away (the in-house way)
--   two   one slot every 0.033 s, newest first (SpeedyAutoLoot's way, SpeedyAutoLoot/SpeedyAutoLoot.lua: it staggers
--         the takes instead of running them all in one tick)
-- Both hide the window while taking, show it again if anything is left, and leave the master looter alone.
----------------------------------------------------------------------
local _, UF = ...

local L = {}
UF.Loot = L

local MASTER_LOOTER = 2
local STAGGER = 0.033   -- SpeedyAutoLoot's stagger (SpeedyAutoLoot/SpeedyAutoLoot.lua takes one slot every 0.033 s)

function L.enabled() return UF.DB().fastLoot ~= false end
function L.toggle() local d = UF.DB(); d.fastLoot = not L.enabled() end

-- quick loop one (the in-house way) or two (SpeedyAutoLoot's way)
function L.loop() return UF.DB().fastLootLoop or "two" end
function L.nextLoop() local d = UF.DB(); d.fastLootLoop = (L.loop() == "one") and "two" or "one" end
function L.loopName() return (L.loop() == "two") and "Staggered loop" or "Instant loop" end

-- Are we the master looter? (then the game must ask who gets each item)
function L.isMasterLooter()
    if not (C_PartyInfo and C_PartyInfo.GetLootMethod) then return false end
    local ok, method, partyID = pcall(C_PartyInfo.GetLootMethod)
    if not ok or (issecretvalue and (issecretvalue(method) or issecretvalue(partyID))) then return false end
    return method == MASTER_LOOTER and partyID == 0
end

-- Should this loot be taken now? autoLoot is LOOT_READY's payload (the game's Auto Loot, with the modifier that flips it).
function L.wanted(autoLoot)
    if not L.enabled() then return false end
    local okA, al = pcall(GetCVar, "autoLootDefault")
    local on = okA and al == "1"
    if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then on = not on end
    if not (on or autoLoot) then return false end
    return not L.isMasterLooter()
end

local hidden = false
local function reveal()
    if hidden and _G.LootFrame then pcall(_G.LootFrame.SetAlpha, _G.LootFrame, 1) end
    hidden = false
end

-- something left (bags full, a roll in progress, a bind-on-pickup question): show the window again
local function revealSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            if hidden and GetNumLootItems and GetNumLootItems() > 0 then reveal() end
        end)
    end
end

-- quick loop two: one slot a tick, newest first (SpeedyAutoLoot's way)
local function takeStaggered(n)
    local i = n
    local function step()
        if i >= 1 then
            pcall(LootSlot, i)
            i = i - 1
            if i >= 1 then
                if C_Timer and C_Timer.After then C_Timer.After(STAGGER, step) end
            else
                revealSoon()
            end
        end
    end
    step()
end

function L.onReady(autoLoot)
    if not L.wanted(autoLoot) then return end
    local n = GetNumLootItems and GetNumLootItems() or 0
    if n == 0 then return end
    if _G.LootFrame then pcall(_G.LootFrame.SetAlpha, _G.LootFrame, 0); hidden = true end
    if L.loop() == "two" then
        takeStaggered(n)
        return
    end
    -- quick loop one: every slot at once, right away
    for i = n, 1, -1 do pcall(LootSlot, i) end
    revealSoon()
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, autoLoot)
    if event == "LOOT_CLOSED" then reveal(); return end
    if event == "LOOT_READY" then L.onReady(autoLoot); return end
    -- PLAYER_LOGIN: the game's Auto Loot on, once for each character (a new character starts with it off)
    local d = UF.DB()
    local g = UnitGUID and UnitGUID("player")
    if not g or not L.enabled() then return end
    d.autoLootChars = d.autoLootChars or {}
    if d.autoLootChars[g] then return end
    d.autoLootChars[g] = true
    pcall(SetCVar, "autoLootDefault", "1")
end)
