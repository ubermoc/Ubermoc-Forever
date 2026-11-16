----------------------------------------------------------------------
-- Ubermoc Forever: /ubf scan (a tool for the author, not something players need)
-- Walks the item ids the game knows and saves the items that are used on other items (class 0 or 8 with a "Use:" line
-- that talks about a weapon, armor or a slot) with their class, subclass and use text, into UbermocForeverDB.scan. The file
-- under WTF/.../SavedVariables is then read offline to build the "which piece can this go on" rules from the game's own
-- wording instead of guessing. Slow on purpose (a few ids per tick) so the game stays smooth.
----------------------------------------------------------------------
local _, UF = ...

local S = { running = false, nextId = 1, last = 60000, found = 0, seen = 0 }
UF.Scan = S

local WORDS = { "weapon", "armor", "enchant", "attach", "apply", "equipment", "boots", "chest", "gloves", "bracer", "cloak",
                "shield", "ring", "helm", "leg ", "legs", "shoulder", "belt", "waist", "trinket", "ranged", "item", "melee" }
local KEEP = { [0] = true, [8] = true }
local PER_TICK = 25

local function mentions(text)
    local t = text:lower()
    for _, w in ipairs(WORDS) do if t:find(w, 1, true) then return true end end
end

local function useLines(id)
    local out
    local ok, data = pcall(function() return C_TooltipInfo and C_TooltipInfo.GetItemByID(id) end)
    if not (ok and data and data.lines) then return nil end
    for _, l in ipairs(data.lines) do
        local t = l.leftText
        if type(t) == "string" and t:find("^Use:") then out = out or {}; out[#out + 1] = t end
    end
    return out
end

local function step()
    local db = UF.DB()
    db.scan = db.scan or {}
    for _ = 1, PER_TICK do
        local id = S.nextId
        if id > S.last then S.running = false; UF.say("Scan finished: " .. S.found .. " items kept. /reload to save them."); return end
        S.nextId = id + 1
        S.seen = S.seen + 1
        local ok, _, _, _, _, _, class, sub = pcall(C_Item.GetItemInfoInstant, id)
        if ok and class and KEEP[class] then
            pcall(C_Item.RequestLoadItemDataByID, id)
            local lines = useLines(id)
            if lines and mentions(table.concat(lines, " ")) then
                local name = select(1, GetItemInfo(id))
                db.scan[id] = { class = class, sub = sub, name = name, use = lines }
                S.found = S.found + 1
            end
        end
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    if not S.running then return end
    S.acc = (S.acc or 0) + dt
    if S.acc < 0.1 then return end
    S.acc = 0
    pcall(step)
end)

function UF.scan(arg)
    if arg == "stop" then S.running = false; UF.say("Scan stopped at id " .. S.nextId .. "."); return end
    if arg == "status" then
        UF.say(("Scan: %s, at id %d of %d, %d kept."):format(S.running and "running" or "not running", S.nextId, S.last, S.found))
        return
    end
    local n = tonumber(arg)
    if n then S.last = n end
    if arg == "reset" then UF.DB().scan = {}; S.nextId, S.found = 1, 0; UF.say("Scan data cleared."); return end
    S.running = true
    UF.say(("Scan started (ids %d to %d). /ubf scan status shows progress, /ubf scan stop pauses it. Type /reload when it says finished."):format(S.nextId, S.last))
end
