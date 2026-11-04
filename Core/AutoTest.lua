local ADDON, ns = ...

-- Auto test: when switched on (/ubf autotest on), the self test runs by itself on every
-- load and the results are kept in the saved variables in a fixed shape, so a script on
-- the computer can read them after the game writes the file. The game only writes saved
-- variables when the UI unloads (/reload or logout), so the results of one load reach the
-- disk at the next /reload.
local AutoTest = {}
ns.AutoTest = AutoTest

local DELAY = 2          -- seconds after entering the world, so every module has finished setting up
local HISTORY = 20

local events = {}
local ran = false
local started = GetTime()

local function stamp(text)
    events[#events + 1] = ("%.1f %s"):format(GetTime() - started, text)
end

function AutoTest.Enabled()
    return ns.db and ns.db.autotest == true
end

function AutoTest.SetEnabled(on)
    ns.db.autotest = on and true or false
end

local function version()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return getMeta(ADDON, "Version") or "?"
end

local function failureSet(run)
    local set = {}
    for _, line in ipairs(run and run.failures or {}) do
        set[line.name or line] = true
    end
    return set
end

-- Builds the stored result from the self test's rows. Pure, so the offline test can run it.
-- rows: { name, ok, detail }; previous: the last stored result for this game, or nil.
function AutoTest.Summarize(rows, previous, errors)
    local failures, new, fixed = {}, {}, {}
    local before = failureSet(previous)
    local now = {}
    for _, r in ipairs(rows) do
        if not r.ok then
            failures[#failures + 1] = { name = r.name, detail = r.detail or "" }
            now[r.name] = true
            if previous and not before[r.name] then
                new[#new + 1] = r.name
            end
        end
    end
    for name in pairs(before) do
        if not now[name] then
            fixed[#fixed + 1] = name
        end
    end
    table.sort(fixed)
    errors = errors or {}
    return {
        total = #rows,
        passed = #rows - #failures,
        failed = #failures,
        failures = failures,
        newFailures = new,
        fixed = fixed,
        errors = errors,
        -- ok means nothing got worse: no failure that the last run did not have, and no Lua error.
        ok = #new == 0 and #errors == 0,
    }
end

function AutoTest.Run(trigger)
    local previous = ns.db.autotestResult
    if previous and previous.game ~= ns.gameType then
        previous = nil
    end
    local okRun, err = pcall(ns.RunSelfTest)
    local rows = {}
    local selftest = ns.db.selftest
    if okRun and selftest then
        rows = selftest.results
    else
        rows[1] = { name = "self test ran", ok = false, detail = tostring(err) }
    end
    for name, module in pairs({ Pad = ns.Pad, Layout = ns.Layout, Cursor = ns.Cursor, Labels = ns.Labels,
        Binds = ns.Binds, Tabs = ns.Tabs, Legend = ns.Legend, Options = ns.Options, GameMenu = ns.GameMenu }) do
        rows[#rows + 1] = { name = "module " .. name .. " loaded", ok = type(module) == "table", detail = "" }
    end
    local errors = {}
    for _, line in ipairs(ns.errors or {}) do
        errors[#errors + 1] = line
    end
    local result = AutoTest.Summarize(rows, previous, errors)
    local gameVersion, build, _, toc = GetBuildInfo()
    result.seq = ((ns.db.autotestResult and ns.db.autotestResult.seq) or 0) + 1
    result.time = date("%Y-%m-%d %H:%M:%S")
    result.epoch = time()
    result.version = version()
    result.game = ns.gameType
    result.gameVersion = gameVersion
    result.build = build
    result.toc = toc
    result.trigger = trigger
    result.events = events
    result.results = rows
    ns.db.autotestResult = result

    local history = ns.db.autotestHistory or {}
    ns.db.autotestHistory = history
    history[#history + 1] = ("%s %s %s: %d passed, %d failed, %d new, %d errors"):format(result.time, result.game,
        result.version, result.passed, result.failed, #result.newFailures, #errors)
    while #history > HISTORY do
        table.remove(history, 1)
    end
    ns.Log("autotest: " .. history[#history])
    print(ns.L.AUTOTEST_DONE:format(result.passed, result.failed, #result.newFailures, #errors))
    return result
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            stamp("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        stamp("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- isInitialLogin, isReloadingUi (both games' API documentation)
        stamp(("PLAYER_ENTERING_WORLD login=%s reload=%s"):format(tostring(arg1), tostring(arg2)))
        if ran or not AutoTest.Enabled() then
            return
        end
        ran = true
        local trigger = arg2 and "reload" or arg1 and "login" or "world"
        if C_Timer and C_Timer.After then
            C_Timer.After(DELAY, function() AutoTest.Run(trigger) end)
        else
            AutoTest.Run(trigger)
        end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

function AutoTest.Command(rest)
    rest = (rest or ""):lower()
    if rest == "on" or rest == "off" then
        AutoTest.SetEnabled(rest == "on")
        print(AutoTest.Enabled() and ns.L.AUTOTEST_ON or ns.L.AUTOTEST_OFF)
    elseif rest == "now" then
        AutoTest.Run("command")
    else
        local last = ns.db.autotestResult
        print(ns.L.AUTOTEST_STATUS:format(AutoTest.Enabled() and ns.L.YES or ns.L.NO,
            last and ("%s, %d passed, %d failed"):format(last.time, last.passed, last.failed) or ns.L.AUTOTEST_NEVER))
    end
end
