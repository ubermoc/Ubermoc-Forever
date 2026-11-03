local _, ns = ...

-- /ubf test: one command that checks the build, then records a short button trace so that
-- what the game really did with each press is saved to disk and can be read after /reload.
local Report = {}
ns.Report = Report

local DURATION = 30
local POLL = 0.02
local MATCH = 0.4        -- seconds a listener hit or a cast may trail the physical press
local MAX_PRESSES = 80
local SAMPLE_DELAY = 0.15

local recording
local banner

-- Decides what happened to each press. Pure, so the smoke test can run it.
-- presses: { time, button, x, y, x2, y2 }; hits: { time, key }; casts: { time, event }
function Report.Analyze(presses, hits, casts, start)
    local summary = { taken = 0, leaked = 0, ignored = 0 }
    local rows = {}
    for _, press in ipairs(presses) do
        local taken, leaked
        for _, hit in ipairs(hits) do
            if hit.key == press.button and hit.time >= press.time - POLL * 2 and hit.time <= press.time + MATCH then
                taken = true
            end
        end
        for _, cast in ipairs(casts) do
            if cast.time >= press.time - POLL * 2 and cast.time <= press.time + MATCH then
                leaked = true
            end
        end
        local moved = press.x2 and (math.abs(press.x2 - press.x) + math.abs(press.y2 - press.y)) or 0
        local verdict = leaked and "ability fired" or taken and "taken by addon" or "nothing happened"
        local bucket = leaked and "leaked" or taken and "taken" or "ignored"
        summary[bucket] = summary[bucket] + 1
        rows[#rows + 1] = ("%.1fs %s: %s%s"):format(press.time - (start or 0), press.button, verdict,
            moved > 1 and (", cursor moved " .. math.floor(moved)) or "")
    end
    return summary, rows
end

local function environment()
    local list = {}
    for i = 1, (C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0) do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) and not name:find("^Blizzard_") then
            list[#list + 1] = name
        end
    end
    local cvars = {}
    for _, name in ipairs({ "GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt",
        "GamePadCursorLeftClick", "GamePadCursorRightClick", "GamePadCursorCentering", "GamePadCursorAutoEnable",
        "GamePadCursorAutoDisableSticks", "GamePadCursorAutoDisableJump" }) do
        cvars[name] = tostring(C_CVar.GetCVar(name))
    end
    local active = ns.Pad.GetActive()
    return {
        addons = table.concat(list, ", "),
        cvars = cvars,
        controller = active and ("%s (labels %s)"):format(active.name, tostring(active.labelStyle)) or "none",
        nativeGamepad = tostring(ns.HasNativeGamepad()),
        cursorOn = tostring(IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled()),
        cursorAuto = tostring(ns.Cursor.Auto()),
        cursorActions = tostring(ns.Cursor.ActionsOn()),
        windowOpen = tostring(ns.Cursor.WindowOpen()),
        labelStyle = tostring(ns.Labels.ActiveStyle()),
    }
end

local function setBanner(text)
    if not banner then
        banner = CreateFrame("Frame", nil, UIParent)
        banner:SetSize(520, 50)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -60)
        banner:SetFrameStrata("TOOLTIP")
        banner.bg = banner:CreateTexture(nil, "BACKGROUND")
        banner.bg:SetAllPoints()
        banner.bg:SetColorTexture(0, 0, 0, 0.6)
        banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        banner.text:SetPoint("TOPLEFT", 8, -6)
        banner.text:SetPoint("BOTTOMRIGHT", -8, 6)
    end
    banner.text:SetText(text)
    banner:Show()
end

local function finish(reason)
    local run = recording
    if not run then
        return
    end
    recording = nil
    run.frame:SetScript("OnUpdate", nil)
    run.frame:UnregisterAllEvents()
    if banner then
        banner:Hide()
    end
    ns.Cursor.trace = nil
    local summary, rows = Report.Analyze(run.presses, run.hits, run.casts, run.start)
    local report = ns.db.report
    report.presses = rows
    report.summary = summary
    report.stopped = reason
    local line = ns.L.TEST_RESULT:format(#run.presses, summary.taken, summary.leaked, summary.ignored)
    report.verdict = line
    ns.Log("test: " .. line)
    print(line)
    print(ns.L.TEST_SAVED)
end

local function begin()
    local run = { start = GetTime(), presses = {}, hits = {}, casts = {}, down = {}, frame = CreateFrame("Frame") }
    recording = run
    run.frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    run.frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    run.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    run.frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            finish("combat started")
        else
            run.casts[#run.casts + 1] = { time = GetTime(), event = event }
        end
    end)
    ns.Cursor.trace = function(key)
        run.hits[#run.hits + 1] = { time = GetTime(), key = key }
    end
    local since = 0
    run.frame:SetScript("OnUpdate", function(_, elapsed)
        local now = GetTime()
        for _, press in ipairs(run.presses) do
            if not press.x2 and now >= press.time + SAMPLE_DELAY then
                press.x2, press.y2 = GetCursorPosition()
            end
        end
        if now - run.start >= DURATION then
            finish("time up")
            return
        end
        since = since + elapsed
        if since < POLL then
            return
        end
        since = 0
        setBanner(ns.L.TEST_BANNER:format(math.ceil(DURATION - (now - run.start))))
        local state = C_GamePad.GetDeviceMappedState()
        if not state then
            return
        end
        for index, down in ipairs(state.buttons) do
            local button = C_GamePad.ButtonIndexToBinding(index - 1)
            if down and not run.down[index] and button and #run.presses < MAX_PRESSES then
                local x, y = GetCursorPosition()
                run.presses[#run.presses + 1] = { time = now, button = button, x = x, y = y }
            end
            run.down[index] = down
        end
    end)
end

function Report.Run()
    if InCombatLockdown() then
        print(ns.L.TEST_COMBAT)
        return
    end
    if recording then
        finish("restarted")
    end
    ns.RunSelfTest()
    local _, build, _, toc = GetBuildInfo()
    ns.db.report = {
        time = date("%Y-%m-%d %H:%M:%S"),
        game = ns.gameType,
        toc = toc,
        build = build,
        environment = environment(),
        labels = (function()
            local out = {}
            for _, device in ipairs(ns.Pad.GetDevices()) do
                out[#out + 1] = ("%s: %s"):format(device.name, tostring(device.labelStyle))
            end
            return out
        end)(),
        log = (function()
            local out, saved = {}, ns.db.log or {}
            for i = math.max(1, #saved - 29), #saved do
                out[#out + 1] = saved[i]
            end
            return out
        end)(),
    }
    print(ns.L.TEST_START:format(DURATION))
    begin()
end

function Report.Stop()
    if recording then
        finish("stopped")
    else
        print(ns.L.TEST_NONE)
    end
end
