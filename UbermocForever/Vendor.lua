----------------------------------------------------------------------
-- Ubermoc Forever: selling junk and repairing at a vendor
--
-- Ported from Ubermoc UI (Main.lua, sellGrayItems / repairGear / onMerchantShow). When a vendor opens (MERCHANT_SHOW):
-- - Repair: if the vendor repairs and something is damaged, the guild bank pays when you are allowed to use it for
--   repairs and both your daily allowance and the bank cover the whole cost (CanGuildBankRepair,
--   GetGuildBankWithdrawMoney (-1 = no limit), GetGuildBankMoney, RepairAllItems(true)); otherwise your own money
--   pays (RepairAllItems(false)), or a chat line says it is not enough.
-- - Sell junk: grey items are sold with the game's own "Sell all junk" (C_MerchantFrame.SellAllJunkItems, the vendor
--   window's button), only at a vendor that buys (C_MerchantFrame.IsSellAllJunkEnabled); if that call is missing they
--   are sold a few per moment from the bags.
-- Every call above is in the Forever API (forever-addon-kit data/forever_api.json). A chat line says what was sold and
-- what the repair cost.
----------------------------------------------------------------------
local _, UF = ...

local V = {}
UF.Vendor = V

local function cfg()
    local d = UF.DB()
    d.vendor = d.vendor or {}
    local v = d.vendor
    if v.sell == nil then v.sell = true end
    if v.repair == nil then v.repair = true end
    if v.guild == nil then v.guild = true end
    return v
end
V.cfg = cfg
function V.toggleSell() local v = cfg(); v.sell = not v.sell end
function V.toggleRepair() local v = cfg(); v.repair = not v.repair end
function V.toggleGuild() local v = cfg(); v.guild = not v.guild end

local function coinText(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, s = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
        if ok and s then return s end
    end
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return g .. "g " .. sv .. "s " .. c .. "c"
end

-- Who pays for a repair of this cost: "guild", "self" or nil (not enough money). Pure, for the test.
function V.payer(cost, useGuild, inGuild, canGuild, allowance, bank, money)
    if useGuild and inGuild and canGuild and (allowance == -1 or allowance >= cost) and bank >= cost then return "guild" end
    if money >= cost then return "self" end
    return nil
end

function V.repair()
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    local v = cfg()
    local who = V.payer(cost, v.guild, IsInGuild and IsInGuild(), CanGuildBankRepair and CanGuildBankRepair(),
        GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0, GetGuildBankMoney and GetGuildBankMoney() or 0, GetMoney())
    if not who then
        UF.say("Not enough money to repair (" .. coinText(cost) .. ").")
        return
    end
    RepairAllItems(who == "guild")
    UF.say("Repaired for " .. coinText(cost) .. (who == "guild" and " (guild bank)." or "."))
end

-- The grey items in the bags: count, their sell value and where they are.
function V.junk()
    local C = C_Container
    local total, slots = 0, {}
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return 0, 0, slots end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue and not info.isLocked then
                local price = 0
                if info.hyperlink then
                    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                    local ok, _, _, _, _, _, _, _, _, _, _, sellPrice = pcall(get, info.hyperlink)
                    price = (ok and sellPrice) or 0
                end
                total = total + price * (info.stackCount or 1)
                slots[#slots + 1] = { bag, slot }
            end
        end
    end
    return #slots, total, slots
end

function V.sell()
    local count, total, slots = V.junk()
    if count == 0 then return end
    local MF = C_MerchantFrame
    local soldAll = MF and MF.SellAllJunkItems and pcall(MF.SellAllJunkItems)
    if not soldAll and C_Container and C_Container.UseContainerItem then
        -- a few per moment so a full bag does not freeze the game
        local i = 0
        local function step()
            if not (MerchantFrame and MerchantFrame:IsShown()) then return end
            for _ = 1, 6 do
                i = i + 1
                local sl = slots[i]
                if not sl then break end
                pcall(C_Container.UseContainerItem, sl[1], sl[2])
            end
            if i < #slots and C_Timer then C_Timer.After(0.05, step) end
        end
        step()
    end
    UF.say("Sold " .. count .. " grey item" .. (count == 1 and "" or "s") .. (total > 0 and (" for " .. coinText(total)) or "") .. ".")
end

function V.onMerchantShow()
    local v = cfg()
    if v.repair then pcall(V.repair) end
    if v.sell then
        local buys = true
        if C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled then
            local ok, enabled = pcall(C_MerchantFrame.IsSellAllJunkEnabled)
            if ok and enabled == false then buys = false end
        end
        -- wait a moment: the vendor window is not open yet when the vendor event arrives
        if buys and C_Timer then C_Timer.After(0.3, function() pcall(V.sell) end) end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function() V.onMerchantShow() end)
