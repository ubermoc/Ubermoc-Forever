local _, ns = ...

-- The game draws controller buttons from a "label style" it keeps for each
-- controller: Generic (numbers), Letters (A B X Y), Shapes (PlayStation) or
-- Reverse (Switch). Steam Input shows the game an Xbox-style pad that is
-- labelled Generic, so by default this switches Valve's pad to Letters. The
-- art is Blizzard's own and the same on every game build.
local Labels = {}
ns.Labels = Labels

Labels.STYLES = { "Generic", "Letters", "Shapes", "Reverse" }

local VALVE = 10462
local AUTO = "AUTO"       -- Letters for Valve's pad, everything else left alone
local DEFAULT = "DEFAULT" -- leave every controller as the game has it
local applying = false

function Labels.Choice()
    return ns.db.labelStyle or AUTO
end

function Labels.SetChoice(choice)
    ns.db.labelStyle = choice ~= AUTO and choice or nil
    return Labels.Apply()
end

-- One line saying what happened, for the options window and the slash command.
function Labels.Describe(result)
    return ns.L.LABELS_RESULT:format(result.changed, result.same, result.missing, result.failed, Labels.ActiveStyle())
end

local function valvePadPresent(ids)
    for _, id in ipairs(ids) do
        if id.vendorID == VALVE then
            return true
        end
    end
    return false
end

-- The style wanted for one controller's config, or nil to leave it alone. In Auto the
-- all-devices config follows too whenever a Valve pad is connected, because the
-- combined controller the game reports takes its style from there.
local function wanted(id, ids)
    local choice = Labels.Choice()
    if choice == DEFAULT then
        return nil
    elseif choice == AUTO then
        if id.vendorID == VALVE or (not id.vendorID and valvePadPresent(ids)) then
            return "Letters"
        end
        return nil
    end
    return choice
end

local function configIDs()
    local ids = { {} } -- the config that applies to all devices
    for _, deviceID in ipairs(C_GamePad.GetAllDeviceIDs()) do
        local raw = C_GamePad.GetDeviceRawState(deviceID)
        if raw and raw.vendorID and raw.vendorID ~= 0 then
            ids[#ids + 1] = { vendorID = raw.vendorID, productID = raw.productID }
        end
    end
    return ids
end

-- Returns a table: changed, same (already the wanted style), missing (no config to change), failed.
function Labels.Apply()
    local result = { changed = 0, same = 0, missing = 0, failed = 0 }
    if applying or InCombatLockdown() then
        return result
    end
    applying = true
    local ids = configIDs()
    for _, id in ipairs(ids) do
        local style = wanted(id, ids)
        if style then
            local name = tostring(id.vendorID or "all") .. "/" .. tostring(id.productID or "all")
            local ok, config = pcall(C_GamePad.GetConfig, id)
            if not ok or not config then
                result.missing = result.missing + 1
                ns.Log("labels " .. name .. ": no config to change")
            elseif config.labelStyle == style then
                result.same = result.same + 1
            else
                config.labelStyle = style
                local saved, err = pcall(C_GamePad.SetConfig, config)
                ns.Log(("labels %s -> %s: %s"):format(name, style, saved and "ok" or tostring(err)))
                if saved then
                    result.changed = result.changed + 1
                else
                    result.failed = result.failed + 1
                end
            end
        end
    end
    if result.changed > 0 then
        local ok, err = pcall(C_GamePad.ApplyConfigs)
        ns.Log("labels apply configs: " .. (ok and "ok" or tostring(err)))
    end
    applying = false
    return result
end

-- What the active controller says its labels are now.
function Labels.ActiveStyle()
    local active = ns.Pad.GetActive()
    return active and active.labelStyle or "?"
end

function Labels.PrintStatus()
    print(ns.L.LABELS_CHOICE:format(Labels.Choice()))
    for _, id in ipairs(configIDs()) do
        local ok, config = pcall(C_GamePad.GetConfig, id)
        print(ns.L.LABELS_LINE:format(tostring(id.vendorID or "all"), tostring(id.productID or "all"),
            ok and config and tostring(config.labelStyle) or "no config"))
    end
    for _, device in ipairs(ns.Pad.GetDevices()) do
        print(ns.L.LABELS_DEVICE:format(device.id, device.name, device.labelStyle))
    end
end

-- /ubf labels <args>
function Labels.Command(args)
    local word = args:match("^(%S*)"):lower()
    if word == "" or word == "status" then
        Labels.PrintStatus()
        return
    end
    local choice
    if word == "auto" then
        choice = AUTO
    elseif word == "default" then
        choice = DEFAULT
    else
        for _, style in ipairs(Labels.STYLES) do
            if style:lower() == word then
                choice = style
            end
        end
    end
    if not choice then
        print(ns.L.LABELS_HELP)
        return
    end
    local result = Labels.SetChoice(choice)
    print(ns.L.LABELS_SET:format(choice, Labels.Describe(result)))
end

Labels.AUTO, Labels.DEFAULT = AUTO, DEFAULT

-- Controllers show up after login, so apply whenever the list or a config changes.
-- Apply only writes when a style differs, so the changes it causes settle at once.
ns.Pad.Subscribe(function()
    Labels.Apply()
end)
