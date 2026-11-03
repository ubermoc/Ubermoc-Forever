local _, ns = ...

-- Another controller addon can leave its binds saved in the game's key bindings
-- after it is turned off. Those keep firing underneath this layout. This backs
-- them up, clears them, and can put them back.
local Binds = {}
ns.Binds = Binds

-- The game writes modifier combinations in this order.
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

local function say(key, ...)
    print(ns.L[key]:format(...))
end

-- Saved binds on controller buttons, as { ["SHIFT-PAD1"] = "ACTIONBUTTON10", ... }.
function Binds.Scan()
    local found = {}
    for button in pairs(ns.Layout.ValidKeys()) do
        for _, prefix in ipairs(MODIFIERS) do
            local key = prefix .. button
            local action = GetBindingAction(key)
            if action and action ~= "" then
                found[key] = action
            end
        end
    end
    return found
end

local function count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function Binds.BackupCount()
    local backup = ns.db.bindBackup
    return backup and count(backup.binds) or 0
end

-- Returns true and how many were cleared, or false and a reason.
function Binds.Clear()
    if InCombatLockdown() then
        return false, "combat"
    end
    local found = Binds.Scan()
    local backup = ns.db.bindBackup or { binds = {} }
    ns.db.bindBackup = backup
    backup.time = date("%Y-%m-%d %H:%M:%S")
    for key, action in pairs(found) do
        backup.binds[key] = backup.binds[key] or action
        SetBinding(key)
    end
    SaveBindings(GetCurrentBindingSet())
    ns.Log("cleared " .. count(found) .. " saved controller binds")
    return true, count(found)
end

function Binds.Restore()
    if InCombatLockdown() then
        return false, "combat"
    end
    local backup = ns.db.bindBackup
    if not backup then
        return false, "none"
    end
    local restored = 0
    for key, action in pairs(backup.binds) do
        SetBinding(key, action)
        restored = restored + 1
    end
    SaveBindings(GetCurrentBindingSet())
    ns.db.bindBackup = nil
    ns.Log("restored " .. restored .. " saved controller binds")
    return true, restored
end

-- /ubf binds <args>
function Binds.Command(args)
    local word = args:match("^(%S*)"):lower()
    if word == "clear" then
        local ok, result = Binds.Clear()
        say(ok and "BINDS_CLEARED" or "BINDS_COMBAT", result)
    elseif word == "restore" then
        local ok, result = Binds.Restore()
        if ok then
            say("BINDS_RESTORED", result)
        else
            say(result == "combat" and "BINDS_COMBAT" or "BINDS_NO_BACKUP")
        end
    elseif word == "" or word == "status" then
        say("BINDS_STATUS", count(Binds.Scan()), Binds.BackupCount())
    else
        say("BINDS_HELP")
    end
end
