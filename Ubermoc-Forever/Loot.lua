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
----------------------------------------------------------------------
local _, UF = ...

local L = {}
UF.Loot = L

local MASTER_LOOTER = 2

function L.enabled() return UF.DB().fastLoot ~= false end
function L.toggle() local d = UF.DB(); d.fastLoot = not L.enabled() end

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

function L.onReady(autoLoot)
    if not L.wanted(autoLoot) then return end
    local n = GetNumLootItems and GetNumLootItems() or 0
    if n == 0 then return end
    if _G.LootFrame then pcall(_G.LootFrame.SetAlpha, _G.LootFrame, 0); hidden = true end
    for i = n, 1, -1 do pcall(LootSlot, i) end
    -- something left (bags full, a roll in progress, a bind-on-pickup question): show the window again
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            if hidden and GetNumLootItems and GetNumLootItems() > 0 then reveal() end
        end)
    end
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
