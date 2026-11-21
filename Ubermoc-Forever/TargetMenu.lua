----------------------------------------------------------------------
-- Ubermoc Forever: interact on a target you cannot interact with opens its unit menu.
-- The interact key (INTERACTTARGET, bound by Binds.lua) does nothing on an enemy you can attack or on something that cannot be talked to.
-- Then the key is pointed at a hidden secure button of type "togglemenu", which opens the same menu a right click on the target's unit
-- frame gives (the game does it, so entries such as Set Focus work). GameNav then puts the highlight on the top entry of the menu.
--   * Out of combat the key is switched from Lua (bindings cannot change in combat) by the game's own order for the interact button
--     (Blizzard_GamepadActionBars/MainActionBarFrame.lua, interactActions): something to interact with next to you (the soft interact target in range,
--     a corpse to skin or loot, an herb) comes FIRST and keeps the key; then a lootable or interactable target; only after that, an attackable
--     enemy or a target with nothing to interact with gets the menu. A targeted player gets the menu too (as Ubermoc UI did).
--   * In combat a state driver ([combat,@target,harm,nodead], and not while there is a soft interact target) switches the key for enemies.
-- A dead target is left to the key (it can still be looted). Sources: Bindings_Camelot.xml (INTERACTTARGET = InteractUnit("anyinteract")),
-- SecureTemplates.lua (SECURE_ACTIONS.togglemenu), Blizzard_GamepadActionBars/MainActionBarFrame.lua (UnitIsInteractable and
-- UnitHasLootInteraction are the game's own tests for "can interact"); the idea and the secure-button method are Ubermoc UI's (Extras.lua).
-- Switch off with /ubf targetmenu off.
----------------------------------------------------------------------
local ADDON, UF = ...
local T = {}
UF.TargetMenu = T

local BTN = "UbermocForeverMenuBtn"
local MAXKEYS = 8   -- the interact key has up to 8 bindings (four layers on the keyboard side and the paddles)
local owner, plain, btn, bound = nil, nil, nil, false

local function q(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and v or nil
end

function T.enabled() return UF.DB().targetMenu ~= false end

-- The game's first choice for the interact button: a soft interact target in range (a corpse to skin, an herb, an NPC).
local function softInteract()
    local there = (UnitExists and q(UnitExists, "softinteract")) or (UnitIsGameObject and q(UnitIsGameObject, "softinteract"))
    if not there then return false end
    if UnitIsInInteractRange then return q(UnitIsInInteractRange, "softinteract") and true or false end
    return true
end
T.softInteract = softInteract

-- Should the interact key open the target's menu right now (out of combat)? Follows the game's own order (see the header).
function T.wants()
    if not UnitExists or not q(UnitExists, "target") then return false end
    if softInteract() then return false end                                 -- skinning, looting, an NPC next to you: the key's normal job
    if q(UnitIsDead, "target") then return false end                        -- a dead target can still be looted
    if UnitHasLootInteraction and q(UnitHasLootInteraction, "target") then return false end
    if q(UnitIsPlayer, "target") then return true end                       -- a player: their menu (whisper, invite, inspect ...)
    if UnitIsInteractable and q(UnitIsInteractable, "target") then return false end
    return true                                                            -- an enemy, or something with nothing to interact with
end
T.wantsPlain = T.wants

local function keys()
    local out = {}
    for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do
        if k and #out < MAXKEYS then out[#out + 1] = k end
    end
    return out
end

local SNIPPET = [[
    if self:GetAttribute("off") then self:ClearBindings(); return end
    local name = self:GetAttribute("btnname")
    if newstate == "on" then
        for i = 1, 8 do
            local k = self:GetAttribute("key" .. i)
            if k then self:SetBindingClick(true, k, name, "RightButton") end
        end
    else
        self:ClearBindings()
    end
]]

-- The key is pointed at the target frame itself with a right click: the game then does exactly what a right click on the frame does
-- (TargetFrame_OpenMenu, Blizzard_UnitFrame/Mainline/TargetFrame.lua), with the menu placed next to the frame. If there is no target frame,
-- the hidden "togglemenu" button below is the fallback (its menu has no anchor of its own).
function T.target()
    local f = _G.TargetFrame
    if f and f.IsObjectType and f:IsObjectType("Button") then return "TargetFrame" end
    return BTN
end

local pending = false
function T.apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local off = not T.enabled()
    -- the enemy path (the state driver reads these attributes)
    local ks = keys()
    owner:SetAttribute("off", off and true or nil)
    owner:SetAttribute("btnname", T.target())
    for i = 1, MAXKEYS do owner:SetAttribute("key" .. i, ks[i]) end
    if SecureHandlerExecute then
        pcall(SecureHandlerExecute, owner, "local newstate = self:GetAttribute('state-harm'); " .. SNIPPET)
    end
    -- the other path
    if bound then ClearOverrideBindings(plain); bound = false end
    if not off and T.wants() then
        for _, k in ipairs(ks) do SetOverrideBindingClick(plain, false, k, T.target(), "RightButton"); bound = true end
    end
end

local function build()
    btn = CreateFrame("Button", BTN, UIParent, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "togglemenu")
    btn:SetAttribute("unit", "target")
    btn:RegisterForClicks("AnyUp")
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER", UIParent, "CENTER")   -- a menu closes when its owner is not visible, so the fallback button is a real (tiny) frame
    btn:HookScript("PreClick", function() T.clicks = (T.clicks or 0) + 1 end)   -- counted for /ubf targetmenu: did the key reach the button?
    owner = CreateFrame("Frame", "UbermocForeverMenuOwner", UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-harm", SNIPPET)
    pcall(RegisterStateDriver, owner, "harm", "[combat,@softinteract,exists] off; [combat,@target,harm,nodead] on; off")
    plain = CreateFrame("Frame", "UbermocForeverMenuPlain", UIParent)
    plain:RegisterEvent("PLAYER_TARGET_CHANGED")
    plain:RegisterEvent("PLAYER_REGEN_ENABLED")
    plain:RegisterEvent("UPDATE_BINDINGS")
    plain:RegisterEvent("UNIT_FLAGS")
    plain:SetScript("OnEvent", function(_, e, unit)
        if e == "UNIT_FLAGS" and unit ~= "target" then return end
        if e == "PLAYER_REGEN_ENABLED" and not pending then
            if UF.diag then UF.diag("ours", "interact key re-applied") end
            T.apply()   -- a target may have changed during the fight
            return
        end
        UF.try("TargetMenu.apply", T.apply)
    end)
    -- a soft interact target comes and goes as you move, and a target dies or becomes lootable, with no event: look again four times a second
    local acc = 0
    plain:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        if not InCombatLockdown() and bound ~= (T.enabled() and T.wants()) then pcall(T.apply) end
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

-- what the game did with the key, for /ubf targetmenu
if hooksecurefunc and _G.TargetFrame_OpenMenu then
    hooksecurefunc("TargetFrame_OpenMenu", function() T.opened = (T.opened or 0) + 1 end)
end
if hooksecurefunc and _G.UnitPopup_OpenMenu then
    hooksecurefunc("UnitPopup_OpenMenu", function(which) T.popup = (T.popup or 0) + 1; T.popupWhich = which end)
end

-- /ubf targetmenu: what it sees right now (for a report when it does not work)
function T.report()
    local function yn(v) return v and "yes" or "no" end
    UF.say("Target menu: " .. (T.enabled() and "on" or "off") .. ", keys " .. (#keys() > 0 and table.concat(keys(), " ") or "NONE (INTERACTTARGET is not bound)")
        .. ", in combat " .. yn(InCombatLockdown()) .. ", switched to the menu now " .. yn(bound))
    UF.say("Target menu: target " .. yn(q(UnitExists, "target")) .. ", enemy " .. yn(q(UnitCanAttack, "player", "target")) .. ", player " .. yn(q(UnitIsPlayer, "target"))
        .. ", dead " .. yn(q(UnitIsDead, "target")) .. ", interactable " .. yn(UnitIsInteractable and q(UnitIsInteractable, "target"))
        .. ", lootable " .. yn(UnitHasLootInteraction and q(UnitHasLootInteraction, "target")) .. ", soft interact in range " .. yn(softInteract())
        .. ", so the menu is " .. yn(T.wants()))
    local G = UF.GameNav
    UF.say("Target menu: A pressed " .. ((G and G.clicks) or 0) .. " times since login, submenus opened by A: " .. ((G and G.subTries) or 0) .. ", last from the entry: " .. tostring(G and G.lastSub))
    UF.say("Target menu: the key is pointed at " .. T.target() .. "; its menu function ran " .. (T.opened or 0) .. " times, the game's unit menu was built " .. (T.popup or 0) .. " times (last: " .. tostring(T.popupWhich) .. "); fallback button clicks " .. (T.clicks or 0) .. "; a menu is open now: " .. yn(UF.GameNav and UF.GameNav.openMenus and #UF.GameNav.openMenus() > 0))
end
