----------------------------------------------------------------------
-- Ubermoc Forever: interact on a target you cannot interact with opens its unit menu.
-- The interact key (INTERACTTARGET, bound by Binds.lua) does nothing on an enemy you can attack or on something that cannot be talked to.
-- Then the key is pointed at a hidden secure button of type "togglemenu", which opens the same menu a right click on the target's unit
-- frame gives (the game does it, so entries such as Set Focus work). GameNav then puts the highlight on the top entry of the menu.
--   * An enemy you can attack and that is alive: a state driver ([@target,harm,nodead]) switches the key, so it also works in combat.
--   * Any other target that is not interactable, not lootable, not dead: switched from Lua, out of combat only (bindings cannot change in combat;
--     the key is switched when the fight ends).
-- A dead target is left to the key (it can still be looted). Sources: Bindings_Camelot.xml (INTERACTTARGET = InteractUnit("anyinteract")),
-- SecureTemplates.lua (SECURE_ACTIONS.togglemenu), Blizzard_GamepadActionBars/MainActionBarFrame.lua (UnitIsInteractable and
-- UnitHasLootInteraction are the game's own tests for "can interact"); the idea and the secure-button method are Ubermoc UI's (Extras.lua).
-- Switch off with /ubf targetmenu off.
----------------------------------------------------------------------
local ADDON, UF = ...
local T = {}
UF.TargetMenu = T

local BTN = "UbermocForeverMenuBtn"
local MAXKEYS = 4
local owner, plain, btn, bound = nil, nil, nil, false

local function q(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and v or nil
end

function T.enabled() return UF.DB().targetMenu ~= false end

-- Ubermoc UI does the same for players and enemies: it keeps the key then, so the two do not fight over it.
local function otherAddonHasIt()
    return _G.UbermocUIAPI ~= nil and _G.UbermocUIAPI.targetMenuApply ~= nil and _G.UbermocUIDB ~= nil and _G.UbermocUIDB.targetMenuKey ~= false
end

-- A target that is not an attackable enemy, cannot be interacted with, cannot be looted and is not dead.
function T.wantsPlain()
    if not UnitExists or not q(UnitExists, "target") then return false end
    if q(UnitCanAttack, "player", "target") then return false end        -- enemies are handled by the state driver
    if q(UnitIsDead, "target") then return false end
    if UnitHasLootInteraction and q(UnitHasLootInteraction, "target") then return false end
    if UnitIsInteractable and q(UnitIsInteractable, "target") then return false end
    return true
end

local function keys()
    local out = {}
    for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do
        if k and #out < MAXKEYS then out[#out + 1] = k end
    end
    return out
end

local SNIPPET = [[
    if self:GetAttribute("off") then self:ClearBindings(); return end
    if newstate == "on" then
        for i = 1, 4 do
            local k = self:GetAttribute("key" .. i)
            if k then self:SetBindingClick(true, k, "UbermocForeverMenuBtn", "LeftButton") end
        end
    else
        self:ClearBindings()
    end
]]

local pending = false
function T.apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local off = (not T.enabled()) or otherAddonHasIt()
    -- the enemy path (the state driver reads these attributes)
    local ks = keys()
    owner:SetAttribute("off", off and true or nil)
    for i = 1, MAXKEYS do owner:SetAttribute("key" .. i, ks[i]) end
    if SecureHandlerExecute then
        pcall(SecureHandlerExecute, owner, "local newstate = self:GetAttribute('state-harm'); " .. SNIPPET)
    end
    -- the other path
    if bound then ClearOverrideBindings(plain); bound = false end
    if not off and T.wantsPlain() then
        for _, k in ipairs(ks) do SetOverrideBindingClick(plain, false, k, BTN, "LeftButton"); bound = true end
    end
end

local function build()
    btn = CreateFrame("Button", BTN, UIParent, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "togglemenu")
    btn:SetAttribute("unit", "target")
    btn:RegisterForClicks("AnyUp")
    owner = CreateFrame("Frame", "UbermocForeverMenuOwner", UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-harm", SNIPPET)
    pcall(RegisterStateDriver, owner, "harm", "[@target,harm,nodead] on; off")
    plain = CreateFrame("Frame", "UbermocForeverMenuPlain", UIParent)
    plain:RegisterEvent("PLAYER_TARGET_CHANGED")
    plain:RegisterEvent("PLAYER_REGEN_ENABLED")
    plain:RegisterEvent("UPDATE_BINDINGS")
    plain:RegisterEvent("UNIT_FLAGS")
    plain:SetScript("OnEvent", function(_, e, unit)
        if e == "UNIT_FLAGS" and unit ~= "target" then return end
        if e == "PLAYER_REGEN_ENABLED" and not pending then
            T.apply()   -- a target may have changed during the fight
            return
        end
        pcall(T.apply)
    end)
    -- a target that gets killed or becomes lootable changes without a target event: look again a couple of times a second
    local acc = 0
    plain:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        if not InCombatLockdown() and bound ~= (T.enabled() and not otherAddonHasIt() and T.wantsPlain()) then pcall(T.apply) end
    end)
end

function T.set(on)
    UF.DB().targetMenu = on and true or false
    if owner then T.apply() end
end

UF.OnLogin(function()
    build()
    T.apply()
end)
