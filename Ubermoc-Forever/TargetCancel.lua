----------------------------------------------------------------------
-- Ubermoc Forever: B cancels the "pick a target" state (UF.TargetCancel), 1.3.127.
-- Using a poison, an oil, an armor kit or an enchant from a bag leaves the game waiting for you to pick the item it goes on
-- (a targeting cursor: SpellIsTargeting is true, as the paper doll code checks with SpellCanTargetItem / SpellIsTargeting). The
-- game cancels that with a right click or Escape; a controller had no way (B closed a window, or did nothing).
-- While the game waits, B is taken and sent to a secure button of ours that runs the game's own secure slash command
-- /stopspelltarget (SlashCommands.lua:397, STOPSPELLTARGET: SecureCmdOptionParse, then SpellStopTargeting()), the call the game's
-- own gamepad Back button makes (MainActionBarFrame.lua:463). So no protected call is made from our code.
-- B is only taken for as long as the game waits and never in combat (the game blocks key changes then, and Nav's owner
-- frame gives all bindings back when combat starts). The game's R1 and R2 clicks are NOT touched: Nav.Push gets noClicks, so
-- the cursor can still click the item the thing goes on.
----------------------------------------------------------------------
local _, UF = ...
local T = {}
UF.TargetCancel = T

local BUTTON = "UbermocForeverCancelTarget"
local entry

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function button()
    local b = _G[BUTTON]
    if b then return b end
    b = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/stopspelltarget")
    return b
end
T.button = button

-- is the game waiting for a target? false when it cannot be asked
function T.waiting()
    if not SpellIsTargeting then return false end
    local ok, v = pcall(SpellIsTargeting)
    return ok and plain(v) == true
end

-- Is one of the game's own question windows up (the "replace this enchant?" question after an armor kit, for one)? Then A and B
-- belong to GameNav, which answers it (A accepts, B declines), so B is not taken for the cancel.
local function questionUp()
    for i = 1, 4 do
        local p = _G["StaticPopup" .. i]
        if p and p.IsShown then
            local ok, shown = pcall(p.IsShown, p)
            if ok and plain(shown) == true then return true end
        end
    end
    return false
end
T.questionUp = questionUp

-- one look: take B while the game waits, give it back when it does not
function T.update()
    local want = T.waiting() and not (InCombatLockdown and InCombatLockdown()) and not questionUp()
    local Nav = UF.Nav
    if not Nav then return end
    if want then
        if entry and Nav.IsTop and not Nav.IsTop(entry) then   -- a window opened after us and took B: take it back
            Nav.Pop(entry); entry = nil
        end
        if not entry then
            button()
            entry = Nav.Push({}, { PAD2 = { BUTTON, "LeftButton" } }, true, true)   -- noClicks, shared: GameNav keeps working beside it
        end
    elseif entry then
        Nav.Pop(entry); entry = nil
    end
end

local acc = 0
local f = CreateFrame("Frame")
T._frame = f   -- for the offline test
f:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    pcall(T.update)
end)
