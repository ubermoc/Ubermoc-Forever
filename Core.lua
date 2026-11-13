-- Core.lua: shared state, saved settings, event dispatch, slash command. Loaded first (it is first in the .toc).
-- Every file gets (addonName, ns): ns is one table shared by all of this addon's files.
local addonName, ns = ...

ns.name = addonName
local DB_NAME = "UbermocForeverDB"   -- must match "## SavedVariables:" in the .toc

local defaults = {
    debug = false,
    binds = {},   -- row -> the key the player pressed ("" = cleared on purpose); read/written by Bind.lua claimedKey/BindPress
}
-- NOTE: there is deliberately NO "enabled" flag any more (R-2.1, user 2026-11-13): while the addon is
-- installed it is on. Options.lua deletes the old flag from saved data; nothing here reads it.
-- NOTE: navWindows is GONE too (user 2026-11-13: "that should happen automatically"): window navigation
-- is always on, no checkbox. Options.lua deletes a stale saved navWindows from earlier builds.

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- Event dispatch: ANY number of files can listen to the same event. (A single "handlers[event] = fn" would let the
-- second file replace the first one.)
local frame = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do fn(...) end
end)

function ns:Print(...)
    print("|cff33ff99" .. addonName .. "|r:", ...)
end

function ns:Debug(...)
    if ns.db and ns.db.debug then print("|cffff9900" .. addonName .. " debug|r:", ...) end
end

-- ns.db exists from ADDON_LOADED on. Anything that needs it must run on or after PLAYER_LOGIN, or inside this handler.
ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName then return end
    _G[DB_NAME] = ApplyDefaults(_G[DB_NAME] or {}, defaults)
    ns.db = _G[DB_NAME]
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    if ns.db then ns:Print("loaded. Type /ubermoc for options.") end
end)

SLASH_UBERMOC1 = "/ubermoc"
SlashCmdList["UBERMOC"] = function(msg)
    if not ns.db then ns:Print("not ready yet."); return end
    local command = (msg or ""):match("^(%S*)"):lower()
    if command == "" or command == "config" then
        -- R-2.1: the options page is OUR PAGE IN THE GAME'S SETTINGS WINDOW (Esc -> Options).
        if ns.settingsCategory then
            Settings.OpenToCategory(ns.settingsCategory:GetID())
        else
            ns:Print("options not ready yet.")
        end
    elseif command == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif ns.SlashSubcommands and ns.SlashSubcommands[command] then
        ns.SlashSubcommands[command]()
    else
        ns:Print("commands: config, binds, unbind, debug")
    end
end
