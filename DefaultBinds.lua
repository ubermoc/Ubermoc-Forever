-- UbermocForever/DefaultBinds.lua
-- Offers the default controller key bindings once, in a confirmation popup.
--
-- The layout below is taken from the Ubermoc UI add-on's saved bindings (2026-11-11): face buttons on action
-- buttons 1-4, D-pad on 8/7/6/5, triggers on 10/12, bumpers target the nearest enemy/friend, and the Shift, Ctrl
-- and Ctrl+Shift layers reach the extra action bars. Entries that only work with Ubermoc UI's own frames, and
-- keyboard keys, are left out on purpose.
--
-- Nothing changes until the player answers "Use defaults". Their previous bindings for those keys are saved
-- first, so "/ubermocbinds restore" puts them back. Bindings are never changed during combat: the change waits
-- for PLAYER_REGEN_ENABLED.
local ADDON, ns = ...

-- Raise this number to ask again after the default layout changes.
local LAYOUT_VERSION = 1

local DEFAULTS = {
    -- X / Square
    { "PAD3", "ACTIONBUTTON1" },
    { "SHIFT-PAD3", "MULTIACTIONBAR1BUTTON1" },
    { "CTRL-PAD3", "MULTIACTIONBAR2BUTTON1" },
    { "CTRL-SHIFT-PAD3", "MULTIACTIONBAR3BUTTON1" },
    -- A / Cross
    { "PAD1", "ACTIONBUTTON2" },
    { "SHIFT-PAD1", "MULTIACTIONBAR1BUTTON2" },
    { "CTRL-PAD1", "MULTIACTIONBAR2BUTTON2" },
    { "CTRL-SHIFT-PAD1", "MULTIACTIONBAR3BUTTON2" },
    -- B / Circle
    { "PAD2", "ACTIONBUTTON3" },
    { "SHIFT-PAD2", "MULTIACTIONBAR1BUTTON3" },
    { "CTRL-PAD2", "MULTIACTIONBAR2BUTTON3" },
    { "CTRL-SHIFT-PAD2", "MULTIACTIONBAR3BUTTON3" },
    -- Y / Triangle
    { "PAD4", "ACTIONBUTTON4" },
    { "SHIFT-PAD4", "MULTIACTIONBAR1BUTTON4" },
    { "CTRL-PAD4", "MULTIACTIONBAR2BUTTON4" },
    { "CTRL-SHIFT-PAD4", "MULTIACTIONBAR3BUTTON4" },
    -- D-pad up
    { "PADDUP", "ACTIONBUTTON8" },
    { "SHIFT-PADDUP", "MULTIACTIONBAR1BUTTON8" },
    { "CTRL-PADDUP", "MULTIACTIONBAR2BUTTON8" },
    { "CTRL-SHIFT-PADDUP", "MULTIACTIONBAR3BUTTON8" },
    -- D-pad right
    { "PADDRIGHT", "ACTIONBUTTON7" },
    { "SHIFT-PADDRIGHT", "MULTIACTIONBAR1BUTTON7" },
    { "CTRL-PADDRIGHT", "MULTIACTIONBAR2BUTTON7" },
    { "CTRL-SHIFT-PADDRIGHT", "MULTIACTIONBAR3BUTTON7" },
    -- D-pad down
    { "PADDDOWN", "ACTIONBUTTON6" },
    { "SHIFT-PADDDOWN", "MULTIACTIONBAR1BUTTON6" },
    { "CTRL-PADDDOWN", "MULTIACTIONBAR2BUTTON6" },
    { "CTRL-SHIFT-PADDDOWN", "MULTIACTIONBAR3BUTTON6" },
    -- D-pad left
    { "PADDLEFT", "ACTIONBUTTON5" },
    { "SHIFT-PADDLEFT", "MULTIACTIONBAR1BUTTON5" },
    { "CTRL-PADDLEFT", "MULTIACTIONBAR2BUTTON5" },
    { "CTRL-SHIFT-PADDLEFT", "MULTIACTIONBAR3BUTTON5" },
    -- right trigger
    { "PADRTRIGGER", "ACTIONBUTTON10" },
    { "SHIFT-PADRTRIGGER", "MULTIACTIONBAR1BUTTON10" },
    { "CTRL-PADRTRIGGER", "MULTIACTIONBAR2BUTTON10" },
    { "CTRL-SHIFT-PADRTRIGGER", "MULTIACTIONBAR3BUTTON10" },
    -- left trigger
    { "PADLTRIGGER", "ACTIONBUTTON12" },
    { "SHIFT-PADLTRIGGER", "MULTIACTIONBAR1BUTTON12" },
    { "CTRL-PADLTRIGGER", "MULTIACTIONBAR2BUTTON12" },
    { "CTRL-SHIFT-PADLTRIGGER", "MULTIACTIONBAR3BUTTON12" },
    -- right bumper
    { "PADRSHOULDER", "TARGETNEARESTENEMY" },
    { "SHIFT-PADRSHOULDER", "TARGETNEARESTENEMY" },
    { "CTRL-PADRSHOULDER", "TARGETNEARESTENEMY" },
    { "CTRL-SHIFT-PADRSHOULDER", "TARGETNEARESTENEMY" },
    -- left bumper
    { "PADLSHOULDER", "TARGETNEARESTFRIEND" },
    { "SHIFT-PADLSHOULDER", "TARGETNEARESTFRIEND" },
    { "CTRL-PADLSHOULDER", "TARGETNEARESTFRIEND" },
    { "CTRL-SHIFT-PADLSHOULDER", "TARGETNEARESTFRIEND" },
    -- right stick click
    { "PADRSTICK", "MULTIACTIONBAR4BUTTON1" },
    { "SHIFT-PADRSTICK", "MULTIACTIONBAR4BUTTON2" },
    { "CTRL-PADRSTICK", "MULTIACTIONBAR4BUTTON3" },
    { "CTRL-SHIFT-PADRSTICK", "MULTIACTIONBAR4BUTTON4" },
    -- left stick click
    { "PADLSTICK", "TOGGLEAUTORUN" },
    { "SHIFT-PADLSTICK", "MULTIACTIONBAR1BUTTON9" },
    { "CTRL-PADLSTICK", "MULTIACTIONBAR1BUTTON11" },
    { "CTRL-SHIFT-PADLSTICK", "MULTIACTIONBAR2BUTTON9" },
    -- paddle 4
    { "PADPADDLE4", "JUMP" },
    { "SHIFT-PADPADDLE4", "JUMP" },
    { "CTRL-PADPADDLE4", "JUMP" },
    { "CTRL-SHIFT-PADPADDLE4", "JUMP" },
    -- Back / View
    { "PADBACK", "TOGGLEWORLDMAP" },
}

local function State()
    local db = ns.db
    if not db then return nil end
    db.defaultBinds = db.defaultBinds or {}
    return db.defaultBinds
end

local pendingApply, pendingPrompt = false, false

-- Sets every default binding and saves the previous action of each key (only the first time, so a second
-- "apply" can never overwrite the player's original bindings).
function ns:ApplyDefaultBinds()
    local state = State()
    if not state then return false end
    if InCombatLockdown() then
        pendingApply = true
        self:Print("In combat: the default key bindings will be applied when combat ends.")
        return false
    end
    state.backup = state.backup or {}
    local changed = 0
    for _, bind in ipairs(DEFAULTS) do
        local key, action = bind[1], bind[2]
        if state.backup[key] == nil then
            state.backup[key] = GetBindingAction(key) or ""
        end
        if SetBinding(key, action) then changed = changed + 1 end
    end
    SaveBindings(GetCurrentBindingSet())
    state.applied = true
    state.askedVersion = LAYOUT_VERSION
    self:Print(string.format("Default key bindings applied (%d). Put your old ones back with /ubermocbinds restore.", changed))
    return true
end

-- Puts back what each key was bound to before the defaults were applied.
function ns:RestoreOldBinds()
    local state = State()
    if not state or not state.backup or next(state.backup) == nil then
        self:Print("There are no saved bindings to restore.")
        return false
    end
    if InCombatLockdown() then
        self:Print("Bindings cannot be changed in combat. Try again after combat.")
        return false
    end
    local restored = 0
    for key, old in pairs(state.backup) do
        if old == "" then
            SetBinding(key)
        else
            SetBinding(key, old)
        end
        restored = restored + 1
    end
    SaveBindings(GetCurrentBindingSet())
    state.backup = nil
    state.applied = false
    self:Print(string.format("Restored your previous key bindings (%d keys).", restored))
    return true
end

local PROMPT_TEXT = "Ubermoc Forever\n\nUse the default controller key bindings?\n\n"
    .. "This sets the face buttons, D-pad, triggers, bumpers and sticks (and their Shift, Ctrl and Ctrl+Shift layers) "
    .. "to the Ubermoc layout. Your current bindings are saved first. "
    .. "Type /ubermocbinds restore later to put them back."

-- Blizzard's confirmation popup (Blizzard_StaticPopup/StaticPopup.lua) is written in Lua, so the linter's API list
-- does not know it. It is read through _G so a missing function degrades to a chat message instead of an error.
local function ShowPrompt()
    local state = State()
    if not state then return end
    if InCombatLockdown() then
        pendingPrompt = true
        return
    end
    local showConfirmation = _G["StaticPopup_ShowCustomGenericConfirmation"]
    if not showConfirmation then
        ns:Print("Type /ubermocbinds apply to use the default controller key bindings.")
        return
    end
    showConfirmation({
        text = PROMPT_TEXT,
        acceptText = "Use defaults",
        cancelText = "No thanks",
        referenceKey = "UbermocForeverDefaultBinds",
        callback = function()
            ns:ApplyDefaultBinds()
        end,
        cancelCallback = function()
            local s = State()
            if s then s.askedVersion = LAYOUT_VERSION end
            ns:Print("Okay, your key bindings were not changed. Type /ubermocbinds to be asked again.")
        end,
    })
end
ns.ShowDefaultBindsPrompt = ShowPrompt

-- Ask once per layout version, a few seconds after the first login, and never while the add-on or its
-- controller support is switched off.
local function AskIfNeeded()
    local state = State()
    if not state then return end
    if ns.db.enabled == false or ns.db.controllerEnabled == false then return end
    if state.askedVersion == LAYOUT_VERSION then return end
    local isShown = _G["StaticPopup_IsCustomGenericConfirmationShown"]
    if isShown and isShown("UbermocForeverDefaultBinds") then return end
    ShowPrompt()
end

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function(isInitialLogin)
    if not isInitialLogin then return end
    C_Timer.After(4, AskIfNeeded)
end)

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pendingApply then
        pendingApply = false
        ns:ApplyDefaultBinds()
    elseif pendingPrompt then
        pendingPrompt = false
        AskIfNeeded()
    end
end)

SLASH_UBERMOCFOREVERBINDS1 = "/ubermocbinds"
SlashCmdList["UBERMOCFOREVERBINDS"] = function(msg)
    local command = strlower((msg or ""):match("^%s*(%S*)") or "")
    if command == "apply" then
        ns:ApplyDefaultBinds()
    elseif command == "restore" then
        ns:RestoreOldBinds()
    elseif command == "" or command == "ask" then
        ShowPrompt()
    else
        ns:Print("/ubermocbinds        asks whether to use the default controller key bindings")
        ns:Print("/ubermocbinds apply   applies them without asking")
        ns:Print("/ubermocbinds restore puts your previous bindings back")
    end
end
