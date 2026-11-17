----------------------------------------------------------------------
-- Ubermoc Forever: aim mark for ground spells.
-- While the game is waiting for a spot on the ground (a ground spell such as Heroic Leap, Blizzard or Rain of Fire was
-- pressed) a white dot shows where the spell will land. It is only there while that is happening. "Aim distance" moves
-- where the game's centred pointer rests (higher on the screen = further from the character); an addon cannot set an
-- exact number of yards. The game settings changed are saved first and put back. Notes: docs/RESEARCH-GROUND-SPELLS.md.
----------------------------------------------------------------------
local ADDON, UF = ...
local A = {}
UF.Aim = A

-- Aim distance steps: where the pointer rests, as a share of the screen height from the bottom.
A.DISTANCES = {
    { name = "Closest", h = 0.40 }, { name = "Close", h = 0.50 }, { name = "Middle", h = 0.60 },
    { name = "Far", h = 0.72 }, { name = "Furthest", h = 0.85 },
}
A.SIZES = { { name = "Small", px = 5 }, { name = "Medium", px = 9 }, { name = "Large", px = 14 } }

local function cfg()
    local d = UF.DB()
    d.aim = d.aim or {}
    local a = d.aim
    if a.on == nil then a.on = true end
    if not a.v2 then   -- 1.3.26: new starting values, Middle distance and a Small dot
        a.v2 = true
        a.dist, a.size = 3, 1
    end
    a.dist = a.dist or 3     -- 0 = leave the game's own height alone
    a.size = a.size or 1
    return a
end
A.cfg = cfg

local function getCVar(c) local f = (C_CVar and C_CVar.GetCVar) or GetCVar; return f and f(c) end
local function setCVar(c, v) local f = (C_CVar and C_CVar.SetCVar) or SetCVar; return f(c, v) end

-- Saved first, so every setting can be put back.
local function put(cvar, value)
    local cur = getCVar(cvar)
    if cur == nil then return end
    local d = UF.DB()
    d.aimBackup = d.aimBackup or {}
    if d.aimBackup[cvar] == nil then d.aimBackup[cvar] = cur end
    if cur ~= value then pcall(setCVar, cvar, value) end
end

function A.restore()
    local d = UF.DB()
    local b = d.aimBackup
    if not b then return end
    for cvar, v in pairs(b) do
        if pcall(setCVar, cvar, v) then b[cvar] = nil end
    end
    if next(b) == nil then d.aimBackup = nil end
end

-- The aim stays at the centred pointer (the dot's place) instead of a stick-moved cursor; the height is the chosen distance.
function A.apply()
    local a = cfg()
    if not a.on then A.restore(); return end
    put("GamePadCursorForTargeting", "0")
    local step = A.DISTANCES[a.dist]
    if step then put("CursorCenteredYPos", string.format("%.2f", step.h))
    else
        local d = UF.DB()
        if d.aimBackup and d.aimBackup.CursorCenteredYPos ~= nil then
            pcall(setCVar, "CursorCenteredYPos", d.aimBackup.CursorCenteredYPos); d.aimBackup.CursorCenteredYPos = nil
        end
    end
end

----------------------------------------------------------------------
-- The dot
----------------------------------------------------------------------
local mark
local function build()
    if mark then return mark end
    mark = CreateFrame("Frame", "UbermocForeverAimMark", UIParent)
    mark:SetFrameStrata("TOOLTIP")
    mark:SetSize(2, 2)
    mark:EnableMouse(false)
    mark:Hide()
    mark.dot = mark:CreateTexture(nil, "OVERLAY")
    mark.dot:SetColorTexture(1, 1, 1, 1)      -- white
    mark.dot:SetPoint("CENTER")
    -- round: the game's own circle mask
    local ok, m = pcall(mark.CreateMaskTexture, mark)
    if ok and m then
        m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        m:SetAllPoints(mark.dot)
        mark.dot:AddMaskTexture(m)
    end
    return mark
end

local function centerFraction()
    local v = tonumber(getCVar("CursorCenteredYPos") or "")
    if v and v > 0 and v < 1 then return v end
    return 0.5
end

local function pointerVisible()
    local ok, cur = pcall(function() return IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled() end)
    return ok and cur and true or false
end

-- Is the game waiting for a ground spot right now?
function A.aiming() return (SpellIsTargeting and SpellIsTargeting()) and true or false end

local sigSeen
local function update()
    local a = cfg()
    local want = a.on and A.aiming() and not pointerVisible()
    if want then
        local m = build()
        local px = (A.SIZES[a.size] or A.SIZES[2]).px
        local h = UIParent:GetHeight() or 768
        local sig = px .. "|" .. centerFraction() .. "|" .. h
        if sig ~= sigSeen then
            sigSeen = sig
            m:ClearAllPoints()
            m:SetPoint("CENTER", UIParent, "BOTTOM", 0, h * centerFraction())
            m.dot:SetSize(px, px)
        end
        if not m:IsShown() then m:Show() end
    elseif mark and mark:IsShown() then
        mark:Hide()
    end
end

local acc = 0
local drv = CreateFrame("Frame")
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    acc = 0
    update()
end)

-- Settings buttons (the options window calls these).
function A.toggle() local a = cfg(); a.on = not a.on; A.apply() end
function A.nextDistance()
    local a = cfg()
    a.dist = (a.dist % #A.DISTANCES) + 1
    A.apply()
end
function A.nextSize() local a = cfg(); a.size = (a.size % #A.SIZES) + 1; sigSeen = nil end
function A.distanceName() local s = A.DISTANCES[cfg().dist]; return s and s.name or "Game's own" end
function A.sizeName() return (A.SIZES[cfg().size] or A.SIZES[2]).name end

-- Release to cast was removed (1.3.40). If an earlier version changed the game's press-and-hold settings, they are put back once.
UF.OnLogin(function()
    local d = UF.DB()
    if d.groundBackup then
        for c, v in pairs(d.groundBackup) do pcall(setCVar, c, v) end
        d.groundBackup = nil
    end
    d.ground = nil
    A.apply()
end)
