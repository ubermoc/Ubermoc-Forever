-- UbermocForever/Core.lua
-- Every addon file is called with (addonName, privateTable). The private table
-- is shared across this addon's files and is invisible to other addons, which
-- makes it the right place for shared state instead of a global.
local addonName, ns = ...

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

-- Defaults are kept separate from saved data so new settings appear for
-- existing users without wiping what they already configured.
local defaults = {
    enabled = true,
    scale = 1.0,
    controllerEnabled = true,
    -- Controller type: 0 = auto-detect from the device itself (default),
    -- then 1..5 in the settings dropdown order below.
    controllerType = 0,
    debug = false,
}
local events = CreateFrame("Frame")

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

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------

ns.db = UbermocForeverDB or {}
local handlers = {}

-- ---------------------------------------------------------------------------
-- Controller detection (presence + type)
-- C_GamePad.IsEnabled() is the gamepad *support* setting, not device
-- presence. Real connection state comes from GAME_PAD_CONNECTED /
-- GAME_PAD_DISCONNECTED; for the initial value we ask the client which
-- gamepad devices it currently sees.
--
-- Device TYPE comes from two verified APIs:
--  * C_GamePad.GetDeviceRawState(deviceID) -> GamePadRawState with
--    vendorID / productID (USB ids, e.g. 0x045E Microsoft, 0x054C Sony,
--    0x057E Nintendo, 0x28DE Valve Steam Controller).
--  * C_GamePad.GetDeviceMappedState(deviceID) -> GamePadMappedState with
--    labelStyle, the button-label family Blizzard itself uses to pick its
--    button art ("Shapes" = PlayStation, "Letters" = Xbox, "Reverse" =
--    Switch-style, "Generic"). Same source as Blizzard's own
--    InputDeviceIconSetManager.
-- The detected type is cached in ns.controllerType and can be overridden
-- from the settings (db.controllerType: 0 = auto-detect).
-- ---------------------------------------------------------------------------

local knownVendors = {
    [0x045E] = "Xbox",        -- Microsoft
    [0x046D] = "Xbox",        -- Microsoft (older id)
    [0x0738] = "Xbox",        -- Mad Catz, mostly Xbox-protocol pads
    [0x054C] = "DualShock",   -- Sony
    [0x057E] = "Switch",      -- Nintendo
    [0x0F0D] = "Switch",      -- Hori, Switch-protocol pads
    [0x28DE] = "Steam",       -- Valve (Steam Deck / Steam Controller)
}

local labelStyleToType = {
    Shapes = "DualShock",
    Letters = "Xbox",
    Reverse = "Switch",
}

-- Dropdown order shared with Options.lua: stored value -> type name.
local typeNamesByValue = { "DualShock", "Xbox", "Switch", "Steam", "Generic" }

ns.controllerConnected = false
ns.controllerType = nil      -- detected type name, e.g. "Steam"
ns.controllerName = nil      -- device name reported by the client

local function FirstDeviceID()
    if not C_GamePad.GetAllDeviceIDs then return nil end
    local deviceIDs = C_GamePad.GetAllDeviceIDs()
    if type(deviceIDs) ~= "table" or #deviceIDs == 0 then return nil end
    -- Prefer whichever device currently has gamepad focus, if the client says so.
    if C_GamePad.GetActiveDeviceID then
        local active = C_GamePad.GetActiveDeviceID()
        for _, id in ipairs(deviceIDs) do
            if id == active then return id end
        end
    end
    return deviceIDs[1]
end

local function DetectDeviceType(deviceID)
    if not deviceID then return nil, nil end

    local name, vendorID, productID
    if C_GamePad.GetDeviceRawState then
        local ok, raw = pcall(C_GamePad.GetDeviceRawState, deviceID)
        if ok and type(raw) == "table" then
            name = raw.name
            vendorID = tonumber(raw.vendorID)
            productID = tonumber(raw.productID)
        end
    end

    local detected
    if vendorID then
        detected = knownVendors[vendorID]
    end

    -- Fall back to the label family Blizzard uses for its own button prompts.
    if C_GamePad.GetDeviceMappedState then
        local ok, mapped = pcall(C_GamePad.GetDeviceMappedState, deviceID)
        if ok and type(mapped) == "table" and mapped.labelStyle then
            ns.controllerLabelStyle = mapped.labelStyle
            detected = detected or labelStyleToType[mapped.labelStyle]
        end
    end

    if not detected then
        -- A device we see but cannot name. Report the ids so the user can tell
        -- us which pad it is and we can add it to the list above.
        if vendorID and productID then
            ns:Debug(("unrecognised gamepad: vendor=%s product=%s")
                :format(string.format("0x%04X", vendorID), string.format("0x%04X", productID)))
        end
        detected = "Generic"
    end

    return detected, name
end

function ns:GetControllerType()
    local override = tonumber(ns.db and ns.db.controllerType)
    if override and override > 0 then
        -- Options dropdown: 0 = auto-detect, 1..5 pick a type explicitly.
        return typeNamesByValue[override] or "Generic"
    end
    return ns.controllerType
end

function ns:RefreshControllerState()
    local deviceID = FirstDeviceID()
    if not deviceID then
        ns.controllerConnected = false
        ns.controllerType = nil
        ns.controllerName = nil
        return
    end
    ns.controllerConnected = true
    local detected, name = DetectDeviceType(deviceID)
    ns.controllerType = detected
    ns.controllerName = name
    ns:Debug(("controller: %s (%s)")
        :format(tostring(name or "unknown device"), tostring(detected or "?")))
end

function ns:RegisterEvent(event, handler)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], handler)
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event, ...)
    if handlers[event] then
        for _, handler in ipairs(handlers[event]) do
            handler(...)
        end
    end
end)

ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName then return end

    UbermocForeverDB = ApplyDefaults(UbermocForeverDB or {}, defaults)
    ns.db = UbermocForeverDB
    -- Drop the old saved key: connection state is live runtime state, not config.
    ns.db.controllerConnected = nil
    ns:RefreshControllerState()

    events:UnregisterEvent("ADDON_LOADED")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    if ns.db.enabled then
        ns:Print("loaded. Type /ubermoc for options.")
    end
end)

-- ---------------------------------------------------------------------------
-- Controller state: keep the live flags in sync with device events.
-- (RefreshControllerState() above provides the initial value.)
-- GAME_PAD_CONNECTED/DISCONNECTED carry no payload, and on Deck the same
-- physical pad can re-enumerate as a new virtual device, so refresh the
-- whole picture on every change. ACTIVE_GAME_MODE_UPDATED tells us when the
-- game switches between controller and keyboard/mouse mode.
-- ---------------------------------------------------------------------------

ns:RegisterEvent("GAME_PAD_CONNECTED", function()
    ns:RefreshControllerState()
    ns:Debug(("gamepad connected (type: %s)")
        :format(tostring(ns:GetControllerType() or "?")))
end)
ns:RegisterEvent("GAME_PAD_DISCONNECTED", function()
    ns:RefreshControllerState()
    if not ns.controllerConnected then
        ns:Print("controller disconnected.")
    end
    ns:Debug("gamepad disconnected")
end)
ns:RegisterEvent("GAME_PAD_ACTIVE_CHANGED", function(isActive)
    ns:Debug(("gamepad active: %s") :format(tostring(isActive)))
    if isActive then
        ns:RefreshControllerState()
    end
end)
ns:RegisterEvent("ACTIVE_GAME_MODE_UPDATED", function(gameMode)
    ns:Debug(("game mode changed: %s") :format(tostring(gameMode)))
    ns:RefreshControllerState()
end)

-- ---------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------

local PREFIX = "|cff33ff99" .. addonName .. "|r:"

function ns:Print(...)
    print(PREFIX, ...)
end

function ns:Debug(...)
    if ns.db and ns.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900" .. addonName .. " debug|r:", ...)
    end
end

-- ---------------------------------------------------------------------------
-- Opening the right settings page
-- The Settings panel is built by Blizzard's own addon code, so these helpers
-- wait for it instead of assuming it exists. OpenKeybinds jumps to the game's
-- Keybindings page (the category id Blizzard stores on Settings once its
-- settings definitions load), which is where controller and keyboard bindings
-- are configured.
-- ---------------------------------------------------------------------------

function ns:OpenSettings()
    if not Settings then
        ns:Print("Settings UI not available in this client.")
        return false
    end
    if not ns.settingsCategory then
        ns:Print("Settings not ready yet. Use /reload after login.")
        return false
    end
    Settings.OpenToCategory(ns.settingsCategory:GetID())
    return true
end

function ns:OpenKeybinds()
    if not Settings or not SettingsPanel then
        ns:Print("Settings UI not available in this client.")
        return false
    end
    local categoryID = Settings.KEYBINDINGS_CATEGORY_ID
    if not categoryID then
        -- Blizzard's settings definitions register the Keybindings category
        -- lazily; opening the panel once forces them to load, then retry.
        SettingsPanel:Open()
        C_Timer.After(0.1, function()
            local id = Settings.KEYBINDINGS_CATEGORY_ID
            if id then
                Settings.OpenToCategory(id)
            else
                ns:Print("The Keybindings page is not available in this client.")
            end
        end)
        return true
    end
    Settings.OpenToCategory(categoryID)
    return true
end

-- ---------------------------------------------------------------------------
-- Controller buttons on the addon's bindings (diagnostics)
-- Blizzard's gamepad key names (Blizzard_SharedXML/Shared/GamepadConstants.lua):
-- PAD1-PAD4 are face buttons, PADDUP/PADD_DOWN etc. the d-pad, PADLSHOULDER /
-- PADRSHOULDER the bumpers, PADLTRIGGER / PADRTRIGGER the triggers. The addon's
-- own actions use the NUMPAD keys (NUMPAD0-9, NUMPADENTER, NUMPADDECIMAL) bound
-- with SetBindingClick on secure buttons; looking those bindings up tells us
-- which controller button is wired to which action.
-- ---------------------------------------------------------------------------

local BINDING_KEYS = {
    "NUMPAD0", "NUMPAD1", "NUMPAD2", "NUMPAD3", "NUMPAD4",
    "NUMPAD5", "NUMPAD6", "NUMPAD7", "NUMPAD8", "NUMPAD9",
    "NUMPADENTER", "NUMPADDECIMAL",
}

local GAMEPAD_BUTTON_NAMES = {
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
}

function ns:GetControllerBindings()
    local found = {}
    if not C_KeyBindings or not C_KeyBindings.GetBindingByKey then return found end
    for _, key in ipairs(BINDING_KEYS) do
        local binding = select(1, pcall(C_KeyBindings.GetBindingByKey, key))
        if type(binding) == "string" and binding ~= "" then
            table.insert(found, { key = key, binding = binding })
        end
    end
    return found
end

function ns:PrintControllerBindings()
    local bindings = self:GetControllerBindings()
    if #bindings == 0 then
        self:Print("No controller buttons are bound to Ubermoc actions yet.")
        return
    end
    -- Which of the bound keys is actually a gamepad button?
    local padKeys = {}
    for _, name in ipairs(GAMEPAD_BUTTON_NAMES) do padKeys[name] = true end
    local count = 0
    for _, entry in ipairs(bindings) do
        if padKeys[entry.binding:upper()] then count = count + 1 end
    end
    self:Print(("Controller buttons bound to Ubermoc actions: %d"):format(count))
    for _, entry in ipairs(bindings) do
        self:Print(("  %s -> %s"):format(entry.key, entry.binding))
    end
end

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------

SLASH_UBERMOCFOREVER1 = "/ubermoc"
SlashCmdList["UBERMOCFOREVER"] = function(msg)
    local command = msg:match("^%S*")
    command = command:lower()

    if not ns.db then
        ns:Print("Addon not fully loaded yet. Use /reload after login.")
        return
    end

    if command == "" or command == "config" then
        ns:OpenSettings()
        if ns.controllerConnected then
            local detected = ns:GetControllerType() or "Unknown"
            local name = ns.controllerName and (ns.controllerName .. " - ") or ""
            ns:Print(("Controller connected: %s%s"):format(name, detected))
        else
            ns:Print("Controller connected: no gamepad device seen.")
        end
    elseif command == "keybinds" then
        ns:OpenKeybinds()
    elseif command == "bindings" then
        ns:PrintControllerBindings()
    elseif command == "toggle" then
        ns.db.enabled = not ns.db.enabled
        ns:Print("now " .. (ns.db.enabled and "enabled" or "disabled") .. ".")
    elseif command == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("debug " .. (ns.db.debug and "on" or "off") .. ".")
    else
        ns:Print("commands: config, keybinds, bindings, toggle, debug")
    end
end
