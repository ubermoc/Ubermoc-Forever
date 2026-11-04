local ADDON, ns = ...

local MAX_LINES = 200
local buffer = {}

function ns.Log(text)
    buffer[#buffer + 1] = ("%.1f %s"):format(GetTime(), tostring(text))
    if #buffer > MAX_LINES then
        table.remove(buffer, 1)
    end
    -- Keep a copy in the saved variables so it can be read from disk after /reload.
    if ns.db then
        local saved = ns.db.log
        if not saved then
            saved = {}
            ns.db.log = saved
        end
        saved[#saved + 1] = date("%Y-%m-%d %H:%M:%S") .. " " .. tostring(text)
        if #saved > MAX_LINES then
            table.remove(saved, 1)
        end
    end
    if ns.db and ns.db.debug then
        print("|cff66ccffUBF|r " .. tostring(text))
    end
end

function ns.PrintLog()
    if #buffer == 0 then
        print(ns.L.DEBUG_EMPTY)
        return
    end
    for i = math.max(1, #buffer - 19), #buffer do
        print(buffer[i])
    end
end

-- Record Lua errors that come from this addon, then pass them on unchanged.
local previous = geterrorhandler()
seterrorhandler(function(err)
    if type(err) == "string" and err:find(ADDON, 1, true) then
        ns.Log("ERROR " .. err)
        -- Errors from this load, for the auto test's results.
        ns.errors = ns.errors or {}
        if #ns.errors < 20 then
            ns.errors[#ns.errors + 1] = err
        end
    end
    return previous(err)
end)
