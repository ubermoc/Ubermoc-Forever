----------------------------------------------------------------------
-- Ubermoc Forever: the name as the health bar (phase 2 of name-only nameplates)
--
-- On a name-only plate the name itself is the health bar: the part of the name that stands for the
-- health left keeps its colour, the part that stands for the missing health is white, and the health
-- percent is written to the right of the name in the reaction colour. Only while an Enemies or a
-- Friendly name-only option is on; with both off the game's own name stays (phase 1's look).
--
-- We never see a health number: the value is secret for our code. A secret is only ever passed
-- straight to a call that accepts it (SetText 664, SetFormattedText 539, SetValue 355 in
-- DOCS/SimpleFontStringAPIDocumentation.lua and DOCS/SimpleStatusBarAPIDocumentation.lua), or asked
-- with issecretvalue (FrameScriptDocumentation.lua 287) and type. Nothing of it is compared,
-- formatted, joined or stored. The game fills our own hidden bar from it, and the bar's texture tells
-- the clip frame where the missing part of the name starts.
--
-- The game's own name keeps its own alpha and is hidden only after our text is in place without an
-- error, so when anything of ours fails the plate still shows the game's name.
-- Everything here is OUR frames (children of the plate's unit frame, so the plate's fading and
-- visibility carry over). Nothing is written on a game frame; the only reads of a game piece are
-- GetJustifyH (SimpleFontAPIDocumentation.lua 104) and GetFont (33), both plain answers. No hook, no
-- update loop, no game method.
----------------------------------------------------------------------
local _, UF = ...
local NH = {}
UF.NameHealth = NH

local objs = setmetatable({}, { __mode = "k" })   -- plate unit frame -> our objects

local function db()
    local d = UF.DB()
    d.plates = d.plates or {}
    if d.plates.health == nil then d.plates.health = true end
    if d.plates.percent == nil then d.plates.percent = true end
    return d.plates
end
NH.db = db

-- one of our two settings, flipped on the options page; the plates on screen are restyled through
-- Nameplates, which reads the settings itself
function NH.toggle(which)
    if which ~= "health" and which ~= "percent" then return end
    local d = db()
    d[which] = not d[which]
    local N = UF.Nameplates
    if N and N.applyAll then N.applyAll() end
end

-- nil for a secret value: a secret is never tested, only passed on or asked about
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- the reaction colour, plain numbers (nothing known: white), as Ubermoc UI's reactionColor
function NH.reactionColor(unit)
    if type(unit) ~= "string" or not UnitReaction then return 1, 1, 1 end
    local ok, react = pcall(UnitReaction, "player", unit)
    if not ok then return 1, 1, 1 end
    react = plain(react)
    if type(react) ~= "number" then return 1, 1, 1 end
    if react <= 2 then return 0.85, 0.15, 0.15 end
    if react == 4 then return 1, 0.85, 0.1 end
    if react >= 5 then return 0.15, 0.8, 0.15 end
    return 1, 0.5, 0.1
end

-- the colour of the name itself: class colour when the class token is readable, the reaction colour
-- otherwise, grey when the unit is tapped by others. Plain numbers only, so it can be tested.
function NH.baseColor(unit)
    if type(unit) ~= "string" then return 1, 1, 1 end
    if UnitIsTapDenied then
        local ok, denied = pcall(UnitIsTapDenied, unit)
        if ok and plain(denied) == true then return 0.55, 0.55, 0.55 end
    end
    if UnitIsPlayer and UnitClass then
        local ok, isPlayer = pcall(UnitIsPlayer, unit)
        if ok and plain(isPlayer) == true then
            local ok2, className, token = pcall(UnitClass, unit)
            if ok2 then
                token = plain(token)
                if type(token) == "string" and RAID_CLASS_COLORS then
                    local c = RAID_CLASS_COLORS[token]
                    if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
                        return c.r, c.g, c.b
                    end
                end
            end
        end
    end
    return NH.reactionColor(unit)
end

-- where the game's name draws its text (a plain answer, Blizzard_NamePlateUnitFrame.lua 678-760)
local function justifyOf(name)
    if not (name and name.GetJustifyH) then return "CENTER" end
    local ok, j = pcall(name.GetJustifyH, name)
    if ok and (j == "LEFT" or j == "RIGHT" or j == "CENTER") then return j end
    return "CENTER"
end

-- our objects, made once for each plate
function NH.ensure(uf)
    if not (uf and CreateFrame) then return nil end
    local o = objs[uf]
    if o then return o end
    local oknf, nf = pcall(CreateFrame, "Frame", nil, uf)
    local okc, clip = pcall(CreateFrame, "Frame", nil, uf)
    local oks, sb = pcall(CreateFrame, "StatusBar", nil, uf)
    local oke, ev = pcall(CreateFrame, "Frame", nil, uf)
    if not (oknf and okc and oks and oke) then return nil end
    o = { uf = uf, nf = nf, clip = clip, sb = sb, ev = ev }
    o.ours = nf:CreateFontString(nil, "OVERLAY")
    o.copy = clip:CreateFontString(nil, "OVERLAY")
    o.pct = nf:CreateFontString(nil, "OVERLAY")
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(nf:GetFrameLevel() + 1)     -- the white copy draws over the coloured name
    pcall(sb.SetStatusBarTexture, sb, "Interface\\Buttons\\WHITE8x8")
    o.tex = sb:GetStatusBarTexture()
    if type(o.tex) ~= "table" or not o.tex.SetVertexColor then return nil end
    pcall(o.tex.SetVertexColor, o.tex, 1, 1, 1, 0)   -- the fill is invisible: only its edge is used
    ev:SetScript("OnEvent", function(_, event, payload)
        if objs[uf] ~= o or not o.shown then return end
        -- the payload can be a secret unit token (type() still says "string" for one): only a plain one may be compared
        local who = plain(payload)
        if type(who) == "string" and type(o.unit) == "string" and who ~= o.unit then return end
        NH.update(uf, o.unit)
    end)
    objs[uf] = o
    return o
end

-- true only when ours is in place and the game's name is hidden
function NH.show(uf, unit, opts)
    if not uf or type(unit) ~= "string" then return false end
    opts = (type(opts) == "table") and opts or db()
    if not (opts.health or opts.percent) then
        NH.clear(uf)
        return false
    end
    if not (UnitName and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100) then
        NH.clear(uf)
        return false
    end
    local o = NH.ensure(uf)
    if not o then return false end
    local name = uf.name
    if type(name) ~= "table" then
        NH.clear(uf)
        return false
    end
    o.name = name
    -- the layout first: plain values only, every anchor of OUR object onto the game's name
    local j = justifyOf(name)
    pcall(o.ours.SetJustifyH, o.ours, j)
    pcall(o.ours.ClearAllPoints, o.ours)
    pcall(o.ours.SetPoint, o.ours, j, name, j, 0, 0)
    -- the game's own font, size and flags; the flags are TEXT ("OUTLINE", or "" for none), not a number. When they cannot be
    -- read, the game's standard font: a text without any font raises "Font not set" and ours would never show
    local okf, f, sz, fl = pcall(name.GetFont, name)
    if not (okf and type(f) == "string" and type(sz) == "number" and type(fl) == "string") then
        f, sz, fl = STANDARD_TEXT_FONT, 12, "OUTLINE"
    end
    if type(f) == "string" then
        pcall(o.ours.SetFont, o.ours, f, sz, fl)
        -- the white copy must be the same font, else its letters do not fall on the coloured ones
        pcall(o.copy.SetFont, o.copy, f, sz, fl)
        pcall(o.pct.SetFont, o.pct, f, sz, fl)
    end
    pcall(o.copy.ClearAllPoints, o.copy)
    pcall(o.copy.SetJustifyH, o.copy, "CENTER")     -- the same text, so its centre falls on ours
    pcall(o.copy.SetPoint, o.copy, "CENTER", o.ours, "CENTER", 0, 0)
    pcall(o.pct.ClearAllPoints, o.pct)
    pcall(o.pct.SetJustifyH, o.pct, "LEFT")
    pcall(o.pct.SetPoint, o.pct, "LEFT", o.ours, "RIGHT", 4, 0)
    pcall(o.sb.ClearAllPoints, o.sb)
    pcall(o.sb.SetPoint, o.sb, "TOPLEFT", o.ours, "TOPLEFT", 0, 0)
    pcall(o.sb.SetPoint, o.sb, "BOTTOMRIGHT", o.ours, "BOTTOMRIGHT", 0, 0)
    pcall(o.clip.ClearAllPoints, o.clip)
    pcall(o.clip.SetPoint, o.clip, "TOPLEFT", o.tex, "TOPRIGHT", 0, 0)
    pcall(o.clip.SetPoint, o.clip, "BOTTOMRIGHT", o.sb, "BOTTOMRIGHT", 0, 0)
    -- colours: plain numbers, never a health tint (SetTextColor does not accept a secret for our code)
    local r, g, b = NH.baseColor(unit)
    pcall(o.ours.SetTextColor, o.ours, r, g, b)
    pcall(o.copy.SetTextColor, o.copy, 1, 1, 1)
    pcall(o.pct.SetTextColor, o.pct, NH.reactionColor(unit))
    -- nothing of the secret name is tested, joined or stored: it goes straight to SetText, and a failure clears
    local okn, nm = pcall(UnitName, unit)
    if not okn then
        NH.clear(uf)
        return false
    end
    if not pcall(o.ours.SetText, o.ours, nm) then
        NH.clear(uf)
        return false
    end
    if not pcall(o.copy.SetText, o.copy, nm) then
        NH.clear(uf)
        return false
    end
    -- the health percent (a secret) is asked once, inside pcall (a restricted unit can make the call itself raise), and is only
    -- passed on to SetValue and SetFormattedText
    local okp, pct = pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)
    if not okp then
        NH.clear(uf)
        return false
    end
    o.showHealth, o.showPct = opts.health, opts.percent
    if opts.health then
        if not pcall(o.sb.SetMinMaxValues, o.sb, 0, 100) then
            NH.clear(uf)
            return false
        end
        if not pcall(o.sb.SetValue, o.sb, pct) then
            NH.clear(uf)
            return false
        end
        o.sb:Show()
        o.clip:Show()
    else
        o.sb:Hide()
        o.clip:Hide()
    end
    if opts.percent then
        if not pcall(o.pct.SetFormattedText, o.pct, "%.0f%%", pct) then
            NH.clear(uf)
            return false
        end
        o.pct:Show()
    else
        o.pct:Hide()
    end
    -- this plate's own unit events, on OUR frame: the old unit's go before the new ones
    o.unit = unit
    pcall(o.ev.UnregisterAllEvents, o.ev)
    pcall(o.ev.RegisterUnitEvent, o.ev, "UNIT_HEALTH", unit)
    pcall(o.ev.RegisterUnitEvent, o.ev, "UNIT_MAXHEALTH", unit)
    o.nf:Show()
    o.shown = true
    -- the game's name is hidden last, with phase 1's helpers so its own alpha comes back
    local N = UF.Nameplates
    if not (N and N.hide) then
        NH.clear(uf)
        return false
    end
    pcall(N.hide, name)
    return true
end

-- health changed: the bar value and the percent text, nothing else
function NH.update(uf, unit)
    local o = objs[uf]
    if not o or not o.shown or type(unit) ~= "string" then return end
    if not (UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100) then return end
    local okp, v = pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)
    if not okp then return end
    if o.showHealth and not pcall(o.sb.SetValue, o.sb, v) then
        NH.clear(uf)
        return
    end
    if o.showPct and not pcall(o.pct.SetFormattedText, o.pct, "%.0f%%", v) then
        NH.clear(uf)
        return
    end
end

-- ours goes away and the game's name gets its own alpha back
function NH.clear(uf)
    local o = objs[uf]
    if not o then return end
    o.shown = false
    o.showHealth, o.showPct = false, false
    if o.nf then o.nf:Hide() end
    if o.clip then o.clip:Hide() end
    if o.sb then o.sb:Hide() end
    pcall(o.ev.UnregisterAllEvents, o.ev)
    local N = UF.Nameplates
    local name = o.name
    if N and N.restore and type(name) == "table" then pcall(N.restore, name) end
    o.name = nil
end
