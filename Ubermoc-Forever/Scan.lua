----------------------------------------------------------------------
-- Ubermoc Forever: /ubf scan (a tool for the author, not something players need)
-- Walks the item ids the game knows and saves the items that are used on other items (class 0 or 8 with a "Use:" line
-- that talks about a weapon, armor or a slot) with their class, subclass and use text, into UbermocForeverDB.scan. The file
-- under WTF/.../SavedVariables is then read offline to build the "which piece can this go on" rules from the game's own
-- wording instead of guessing. Slow on purpose (a few ids per tick) so the game stays smooth.
----------------------------------------------------------------------
local _, UF = ...

local S = { running = false, nextId = 1, last = 60000, found = 0, seen = 0, budget = 50 }
UF.Scan = S

local WORDS = { "weapon", "armor", "enchant", "attach", "apply", "equipment", "boots", "chest", "gloves", "bracer", "cloak",
                "shield", "ring", "helm", "leg ", "legs", "shoulder", "belt", "waist", "trinket", "ranged", "item", "melee" }
local KEEP = { [0] = true, [8] = true }
local PER_TICK = 150   -- ids per frame; most are skipped without loading anything

local function mentions(text)
    local t = text:lower()
    for _, w in ipairs(WORDS) do if t:find(w, 1, true) then return true end end
end

local USE = (ITEM_SPELL_TRIGGER_ONUSE or "Use:"):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

local function useLines(id)
    local out
    local ok, data = pcall(function() return C_TooltipInfo and C_TooltipInfo.GetItemByID(id) end)
    if not (ok and data and data.lines and #data.lines > 0) then return nil, false end
    for _, l in ipairs(data.lines) do
        local t = l.leftText
        if type(t) == "string" and t:find("^" .. USE) then out = out or {}; out[#out + 1] = t end
    end
    return out, true
end

-- Items of the wanted classes are asked for first and read a few ticks later, once the game has loaded their data.
local pending = {}     -- id -> { class, sub, tries, wait }
S.classed, S.loaded = 0, 0

local function resolve(id, p)
    local lines, loaded = useLines(id)
    if not loaded then
        p.tries = p.tries + 1
        return p.tries >= 240   -- give up after about 4 seconds
    end
    S.loaded = S.loaded + 1
    p.done = true   -- never counted twice, whatever happens next
    if lines and mentions(table.concat(lines, " ")) then
        local name
        if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
        if not name and GetItemInfo then name = (GetItemInfo(id)) end
        local db = UF.DB()
        db.scan = db.scan or {}
        db.scan[id] = { class = p.class, sub = p.sub, name = name, use = lines }
        S.found = S.found + 1
    end
    return true
end

local function saveStats()
    local db = UF.DB()
    db.scanStats = { errors = S.errors or 0, nextId = S.nextId, classed = S.classed, loaded = S.loaded, found = S.found, last = S.last }
end

local function step()
    saveStats()
    for id, p in pairs(pending) do
        p.wait = p.wait - 1
        if p.wait <= 0 then
            local ok, done = pcall(resolve, id, p)
            if not ok then
                S.errors = (S.errors or 0) + 1
                S.lastError = tostring(done)
                UF.DB().scanError = S.lastError
                done = true
            end
            if done or p.done then pending[id] = nil end
        end
    end
    if S.nextId > S.last then
        if next(pending) == nil then
            S.running = false
            UF.say(("Scan finished: %d items kept (%d of %d candidates had data). /reload to save them."):format(S.found, S.loaded, S.classed))
        end
        return
    end
    local t0 = debugprofilestop and debugprofilestop() or 0
    for n = 1, 5000 do
        -- as many ids as fit in the time budget for this frame (milliseconds), so a fast PC goes fast and a slow one stays smooth
        if debugprofilestop and n % 20 == 0 and debugprofilestop() - t0 > S.budget then break end
        local id = S.nextId
        if id > S.last then break end
        S.nextId = id + 1
        local ok, _, _, _, _, _, class, sub = pcall(C_Item.GetItemInfoInstant, id)
        if ok and class and KEEP[class] then
            S.classed = S.classed + 1
            pcall(C_Item.RequestLoadItemDataByID, id)
            pending[id] = { class = class, sub = sub, tries = 0, wait = 12 }
        end
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    if not S.running then return end
    pcall(step)
end)

function UF.scan(arg)
    if arg == "stop" then S.running = false; UF.say("Scan stopped at id " .. S.nextId .. "."); return end
    if arg == "status" then
        UF.say(("Scan: %s, at id %d of %d, %d kept, %d candidates, %d with data, %d errors."):format(S.running and "running" or "not running", S.nextId, S.last, S.found, S.classed, S.loaded, S.errors or 0))
        if S.lastError then UF.say("Last scan error: " .. S.lastError) end
        return
    end
    local b = arg and arg:match("^budget%s+(%d+)$")
    if b then S.budget = tonumber(b); UF.say("Scan time budget per frame: " .. S.budget .. " ms."); return end
    local from = arg and arg:match("^from%s+(%d+)$")
    if from then S.nextId = tonumber(from); arg = nil end
    local n = tonumber(arg)
    if n then S.last = n end
    if arg == "reset" then UF.DB().scan = {}; S.nextId, S.found, S.classed, S.loaded = 1, 0, 0, 0; pending = {}; UF.say("Scan data cleared."); return end
    S.running = true
    UF.say(("Scan started (ids %d to %d). /ubf scan status shows progress, /ubf scan stop pauses it. Type /reload when it says finished."):format(S.nextId, S.last))
end
