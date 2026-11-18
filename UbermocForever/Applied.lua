----------------------------------------------------------------------
-- Ubermoc Forever: what is already applied to a worn item (UF.Applied), 1.3.128.
-- Before something is put on a piece you wear (a poison, an oil, a sharpening stone, an armor kit, an enchant), the menu entry
-- says if the piece already carries something that this would replace, even a temporary thing with time left.
--   Temporary (poisons, oils, stones): C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot) answers a table with enchantID,
--   remainingTimeMs, chargesRemaining and hasExpirationTime, or nothing when none is active (PaperDollInfoDocumentation.lua:226-241
--   and the TemporaryItemEnchantInfo structure, 491-500; the game's own old GetWeaponEnchantInfo is built on it,
--   Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:44).
--   Permanent (armor kits, enchants): the item link of the worn piece carries the enchant id right after the item id
--   (item:<itemID>:<enchantID>:...); its name is the tooltip line of type ItemEnchantmentPermanent
--   (TooltipInfoSharedDocumentation.lua:49), read from C_TooltipInfo.GetInventoryItem. No name is known for a temporary one
--   (the documentation has no call for it), so it is described as "a poison or oil".
-- Which of the two matters depends on what is being applied: weapon stones, oils and poisons replace a temporary enchant;
-- kits, scopes and enchants replace a permanent one (kind "temporary" or "permanent", from the slots the item goes on).
-- Nothing is written anywhere; every call is inside pcall and a secret answer is treated as no answer.
----------------------------------------------------------------------
local _, UF = ...
local A = {}
UF.Applied = A

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- "12 min", "45 sec", "2 h" from milliseconds
function A.timeText(ms)
    if type(ms) ~= "number" or ms <= 0 then return nil end
    local s = math.floor(ms / 1000 + 0.5)
    if s >= 3600 then return string.format("%d h %d min", math.floor(s / 3600), math.floor((s % 3600) / 60)) end
    if s >= 60 then return math.floor(s / 60) .. " min" end
    return s .. " sec"
end

-- the temporary enchant on a worn slot: { time = "12 min" or nil, charges = n or nil } or nil
function A.temporary(slot)
    if not (C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo) then return nil end
    local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
    if not ok then return nil end
    info = plain(info)
    if type(info) ~= "table" then return nil end
    local id = plain(info.enchantID)
    if type(id) ~= "number" then return nil end
    local ms = plain(info.remainingTimeMs)
    local charges = plain(info.chargesRemaining)
    return {
        time = (plain(info.hasExpirationTime) ~= false) and A.timeText(ms) or nil,
        charges = (type(charges) == "number" and charges > 0) and charges or nil,
    }
end

-- the permanent enchant on a worn slot: { name = "..." or nil } or nil
function A.permanent(slot)
    if not GetInventoryItemLink then return nil end
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    link = ok and plain(link) or nil
    if type(link) ~= "string" then return nil end
    local enchant = tonumber(link:match("item:%-?%d+:(%d+)") or "0") or 0
    if enchant == 0 then return nil end
    local name
    local want = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    if want and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local okT, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        data = okT and plain(data) or nil
        if type(data) == "table" and type(data.lines) == "table" then
            for _, l in ipairs(data.lines) do
                if type(l) == "table" and plain(l.type) == want then
                    local t = plain(l.leftText)
                    if type(t) == "string" and t ~= "" then name = t; break end
                end
            end
        end
    end
    return { name = name }
end

-- the sentence for one slot, for what is being applied: nil when there is nothing it would replace
function A.text(slot, kind)
    if kind == "permanent" then
        local p = A.permanent(slot)
        if not p then return nil end
        return p.name and ("already enchanted: " .. p.name) or "already enchanted"
    end
    local t = A.temporary(slot)
    if not t then return nil end
    local parts = {}
    if t.time then parts[#parts + 1] = t.time .. " left" end
    if t.charges then parts[#parts + 1] = t.charges .. (t.charges == 1 and " charge" or " charges") end
    return "already has a poison or oil" .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "")
end

-- a coloured suffix for a menu entry, or "" when there is nothing
function A.hint(slot, kind)
    local ok, t = pcall(A.text, slot, kind)
    if ok and t then return "  |cffffa000" .. t .. "|r" end
    return ""
end

-- "temporary" when every slot an item goes on is a weapon slot (stones, oils, poisons), else "permanent" (kits, scopes, enchants)
function A.kindFor(slots)
    for _, s in ipairs(slots or {}) do
        if s ~= 16 and s ~= 17 then return "permanent" end
    end
    return "temporary"
end

-- one chat line when the game starts waiting for a target: which of your weapons already carry something temporary
function A.report(say)
    local parts = {}
    for _, e in ipairs({ { 16, "Main hand" }, { 17, "Off hand" }, { 18, "Ranged" } }) do
        local t = A.text(e[1], "temporary")
        if t then parts[#parts + 1] = e[2] .. " " .. t end
    end
    if #parts > 0 and say then say("Applying: " .. table.concat(parts, "; ") .. ".") end
    return parts
end
