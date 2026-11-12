-- UbermocForever/DefaultBinds.lua
-- Offers the default controller key bindings once, in a confirmation popup.
--
-- The layout follows the clock, like a gamepad ring around the character:
--   * main bar first (no modifier);
--   * then action bar 2 (Shift), bar 3 (Ctrl) and bar 4 (Ctrl+Shift);
--   * each button starts at its own slot on the MAIN bar - A/Cross is always
--     the A-slot, never a different slot on another bar.
-- On the main bar the face buttons sit in their natural diamond (X bottom, Y
-- top, A right, B left), the D-pad takes 8/7/6/5 clockwise from up, and the
-- triggers/bumpers group takes 10/9/12/11 clockwise from 3:00. On every other
-- bar the same four buttons take that bar's own 3:00/6:00/9:00/12:00 slots,
-- verified against Blizzard's own binding table (Bindings_Camelot.xml): slot
-- 1 is 3:00, 2 is 6:00, 3 is 9:00 and 4 is 12:00 on the side bars.
-- Bumpers target the nearest enemy/friend instead of a bar slot. Entries that
-- only work with Ubermoc UI's own frames, and keyboard keys, are left out on
-- purpose.
--
-- Nothing changes until the player answers "Use defaults". Their previous bindings for those keys are saved
-- first, so "/ubermocbinds restore" puts them back. Bindings are never changed during combat: the change waits
-- for PLAYER_REGEN_ENABLED.
local ADDON, ns = ...

-- Raise this number to ask again after the default layout changes.
local LAYOUT_VERSION = 2

-- Bar order for the modifier layers, clockwise from the main bar:
--   none        -> main bar (ACTIONBUTTON1-12)
--   SHIFT-      -> action bar 2 (MULTIACTIONBAR1* = MultiBarBottomLeft)
--   CTRL-       -> action bar 3 (MULTIACTIONBAR2* = MultiBarBottomRight)
--   CTRL-SHIFT- -> action bar 4 (MULTIACTIONBAR3* = MultiBarRight)
-- (verified against Blizzard's Bindings_Camelot.xml, which maps each
-- MULTIACTIONBARn to its bar frame).
local LAYERS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }

-- The four clock positions on a bar, per layer: slot 1 is at 3:00, 2 at 6:00,
-- 3 at 9:00, 4 at 12:00 (side bars run top-to-bottom; the main bar numbers
-- left-to-right). On the MAIN bar the face buttons instead use their natural
-- diamond so A is always the A-slot.
local FACE_SLOTS = { 3, 4, 2, 1 } -- PAD3 X bottom, PAD4 Y top, PAD1 A right, PAD2 B left

-- Build "<layer prefix><bar command>" for one button and layer index.
local function BarCommand(layerIndex, slot)
    if layerIndex == 1 then
        return "ACTIONBUTTON" .. slot
    end
    return "MULTIACTIONBAR" .. (layerIndex - 1) .. "BUTTON" .. slot
end

-- Bind one button across all four layers: the same clock position on each bar.
local function ClockBinds(key, mainSlot, sideSlot)
    local binds = {}
    for layerIndex, prefix in ipairs(LAYERS) do
        local slot = (layerIndex == 1 and mainSlot) or sideSlot
        table.insert(binds, { prefix .. key, BarCommand(layerIndex, slot) })
    end
    return binds
end

-- Bind one button across all four layers onto one fixed command (targeting).
local function SameBind(key, command)
    local binds = {}
    for _, prefix in ipairs(LAYERS) do
        table.insert(binds, { prefix .. key, command })
    end
    return binds
end

local DEFAULTS = {}

-- Face buttons: main-bar diamond, then the 3:00/6:00/9:00/12:00 slots of the
-- next three bars. X (PAD3) is bottom on the main bar and 6:00 elsewhere, and
-- so on for every button.
for _, entry in ipairs({
    { key = "PAD3", mainSlot = FACE_SLOTS[1], sideSlot = 2 }, -- X / Square (bottom)
    { key = "PAD4", mainSlot = FACE_SLOTS[2], sideSlot = 4 }, -- Y / Triangle (top)
    { key = "PAD1", mainSlot = FACE_SLOTS[3], sideSlot = 1 }, -- A / Cross (right, 3:00)
    { key = "PAD2", mainSlot = FACE_SLOTS[4], sideSlot = 3 }, -- B / Circle (left, 9:00)
}) do
    for _, bind in ipairs(ClockBinds(entry.key, entry.mainSlot, entry.sideSlot)) do
        table.insert(DEFAULTS, bind)
    end
end

-- D-pad: 8/7/6/5 on the main bar (clockwise from up), and each side bar's own
-- ring clockwise from its top: 4 (12:00), 1 (3:00), 3 (9:00), 2 (6:00).
for _, entry in ipairs({
    { key = "PADDUP", mainSlot = 8, sideSlot = 4 },
    { key = "PADDRIGHT", mainSlot = 7, sideSlot = 1 },
    { key = "PADDDOWN", mainSlot = 6, sideSlot = 2 },
    { key = "PADDLEFT", mainSlot = 5, sideSlot = 3 },
}) do
    for _, bind in ipairs(ClockBinds(entry.key, entry.mainSlot, entry.sideSlot)) do
        table.insert(DEFAULTS, bind)
    end
end

-- Triggers and bumpers: one clockwise group on the main bar - right trigger
-- at 3:00 (10), right bumper at 6:00 (9), left trigger at 9:00 (12), left
-- bumper at 12:00 (11) - and each side bar's own clock slots. The bumpers
-- instead target the nearest enemy/friend on every layer.
for _, entry in ipairs({
    { key = "PADRTRIGGER", mainSlot = 10, sideSlot = 1 }, -- right trigger, 3:00
    { key = "PADLSHOULDER", command = "TARGETNEARESTFRIEND" }, -- left bumper
    { key = "PADLTRIGGER", mainSlot = 12, sideSlot = 3 }, -- left trigger, 9:00
    { key = "PADRSHOULDER", command = "TARGETNEARESTENEMY" }, -- right bumper
}) do
    if entry.command then
        for _, bind in ipairs(SameBind(entry.key, entry.command)) do
            table.insert(DEFAULTS, bind)
        end
    else
        for _, bind in ipairs(ClockBinds(entry.key, entry.mainSlot, entry.sideSlot)) do
            table.insert(DEFAULTS, bind)
        end
    end
end

-- Right stick click: its own little clock on bar 5 (MULTIACTIONBAR4*), so it
-- never overlaps the face-button bars.
for index, key in ipairs({ "PADRSTICK", "SHIFT-PADRSTICK", "CTRL-PADRSTICK", "CTRL-SHIFT-PADRSTICK" }) do
    table.insert(DEFAULTS, { key, "MULTIACTIONBAR4BUTTON" .. index })
end

-- Left stick click: auto run; its modified layers reach bar 2's free slots.
table.insert(DEFAULTS, { "PADLSTICK", "TOGGLEAUTORUN" })
table.insert(DEFAULTS, { "SHIFT-PADLSTICK", "MULTIACTIONBAR1BUTTON9" })
table.insert(DEFAULTS, { "CTRL-PADLSTICK", "MULTIACTIONBAR1BUTTON11" })
table.insert(DEFAULTS, { "CTRL-SHIFT-PADLSTICK", "MULTIACTIONBAR2BUTTON9" })

-- Paddle 4 (only pads with paddles report it) and Back / View.
for _, prefix in ipairs(LAYERS) do
    table.insert(DEFAULTS, { prefix .. "PADPADDLE4", "JUMP" })
end
table.insert(DEFAULTS, { "PADBACK", "TOGGLEWORLDMAP" })

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
    local changed, cleared = 0, 0
    for _, bind in ipairs(DEFAULTS) do
        local key, action = bind[1], bind[2]
        if state.backup[key] == nil then
            state.backup[key] = GetBindingAction(key) or ""
        end
        if action == "" then
            -- Button the previous layout version used but this one no longer
            -- binds: clear it so a stale action cannot hide behind a key the
            -- new layout leaves free.
            SetBinding(key)
            cleared = cleared + 1
        elseif SetBinding(key, action) then
            changed = changed + 1
        end
    end
    SaveBindings(GetCurrentBindingSet())
    state.applied = true
    state.askedVersion = LAYOUT_VERSION
    local suffix = ""
    if cleared > 0 then
        suffix = (" Cleared %d key(s) from the old layout."):format(cleared)
    end
    self:Print(string.format("Default key bindings applied (%d).%s Put your old ones back with /ubermocbinds restore.", changed, suffix))
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

-- Ask once per layout version, a few seconds after the first login.
local function AskIfNeeded()
    local state = State()
    if not state then return end
    if state.askedVersion == LAYOUT_VERSION then return end
    -- A player who already applied an older version: their untouched original
    -- keys are still in the backup, so re-applying is safe - but it goes
    -- through the same confirmation popup rather than changing bindings on
    -- its own. If they decline, nothing changes and the old layout stays.
    if state.applied then
        ns:Print("The default controller layout changed (it now starts on the main bar and runs clockwise). Type /ubermocbinds to update it, or /ubermocbinds restore to go back first.")
    end
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
