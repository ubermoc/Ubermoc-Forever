----------------------------------------------------------------------
-- Ubermoc Forever: the gamepad layout (one bar for the controller).
-- One row of the game's own action buttons at the bottom of the screen. With no modifier held it shows action bar 1, with the first
-- modifier action bar 2, with the second action bar 3, with both action bar 4: the same four layers Binds.lua fills (UF.LAYERS), so the row
-- always shows what the buttons under your thumbs do right now. The game's bottom art goes (end caps, bar art, page arrows, bars 2 to 4,
-- micro menu, bags, experience bar: through the Fading engine, Fade.lua, so the Fading page can still override a part) and the buttons'
-- key labels are hidden. Buttons with nothing on them are removed and the rest are centred and spaced evenly (Hide empty buttons).
--
-- The buttons stay the game's own (cooldowns, tooltips, dragging, clicking all work); only where they sit changes, as in Ubermoc UI's action
-- bars (ActionBars.lua there). Rules that came from that design and from docs/LUA-WOW-GUIDE.md: the buttons are protected, so they are only
-- moved out of combat (a layout asked for in a fight waits for its end), notes about them live in our own tables (writing a field on a
-- protected button taints it), and alpha (which is allowed in combat) is what shows the held layer. Notes: docs/RESEARCH-GAMEPAD-BAR.md.
----------------------------------------------------------------------
local ADDON, UF = ...
local B = {}
UF.GamepadBar = B

B.SIZES = { 36, 40, 44, 48, 52 }        -- button size
B.GAPS = { 0, 2, 4, 6, 8, 12 }          -- space between buttons
B.RAISES = { 0, 12, 24, 48, 96, 150 }   -- how far above the bottom edge of the screen

-- The game's buttons of each layer: action bar 1 is the main bar, then the first three multi bars (the bindings MULTIACTIONBAR1..3 of Binds.lua).
local BAR_BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton" }
local PREFIXES = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }   -- same order as UF.LAYERS
local PER_BAR = 12
-- The game's bottom art, as Fade.lua element keys (frames: Fade.lua F.CATEGORIES).
local ART_KEYS = { "mainbar", "bar2", "bar3", "bar4", "micro", "bags", "xpall" }
B.ART_KEYS = ART_KEYS

local function cfg()
    local d = UF.DB()
    d.gbar = d.gbar or {}
    local c = d.gbar
    if c.on == nil then c.on = false end
    if c.hideEmpty == nil then c.hideEmpty = true end
    if c.hideArt == nil then c.hideArt = true end
    c.size = c.size or 44
    c.gap = c.gap or 6
    c.raise = c.raise or 24
    return c
end
B.cfg = cfg

----------------------------------------------------------------------
-- Pure helpers (tested offline)
----------------------------------------------------------------------
-- Which layer is held: 1 none, 2 shift, 3 ctrl, 4 both. Anything else (alt) falls back to the plain layer.
function B.layerFor(shift, ctrl, alt)
    if alt then return 1 end
    if shift and ctrl then return 4 end
    if ctrl then return 3 end
    if shift then return 2 end
    return 1
end

-- The left edge of each of n buttons of size s with gap g, centred in a row of total width W; evenly spaced.
function B.rowX(n, s, g, W)
    local out = {}
    if n <= 0 then return out end
    local width = n * s + (n - 1) * g
    local x0 = ((W or width) - width) / 2
    for k = 1, n do out[k] = x0 + (k - 1) * (s + g) end
    return out
end

function B.rowWidth(n, s, g) return n <= 0 and 0 or n * s + (n - 1) * g end

local function stepOf(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
    return 1
end
function B.nextSize() local c = cfg(); c.size = B.SIZES[(stepOf(B.SIZES, c.size) % #B.SIZES) + 1]; B.layoutSoon() end
function B.nextGap() local c = cfg(); c.gap = B.GAPS[(stepOf(B.GAPS, c.gap) % #B.GAPS) + 1]; B.layoutSoon() end
function B.nextRaise() local c = cfg(); c.raise = B.RAISES[(stepOf(B.RAISES, c.raise) % #B.RAISES) + 1]; B.layoutSoon() end
function B.toggle() local c = cfg(); c.on = not c.on; B.layoutSoon(); if UF.Fade then UF.Fade.evaluate() end end
function B.toggleEmpty() local c = cfg(); c.hideEmpty = not c.hideEmpty; B.layoutSoon() end
function B.toggleArt() local c = cfg(); c.hideArt = not c.hideArt; B.layoutSoon(); if UF.Fade then UF.Fade.evaluate() end end

----------------------------------------------------------------------
-- The game's buttons
----------------------------------------------------------------------
local taken = setmetatable({}, { __mode = "k" })     -- button -> how it was before (our own table: nothing is written on the button)
local btnPos = setmetatable({}, { __mode = "k" })    -- button -> where we want it
local btnBusy = setmetatable({}, { __mode = "k" })
local btnHooked = setmetatable({}, { __mode = "k" })
local wantAlpha = setmetatable({}, { __mode = "k" }) -- button -> 1 when it is on the held layer and shown
local lastLevel = setmetatable({}, { __mode = "k" })
local layerOf = setmetatable({}, { __mode = "k" })
local root
local pending = false
local layers = {}   -- [i] = { buttons = { btn... }, shown = { btn... } }

local function layerButtons(i)
    local out = {}
    for n = 1, PER_BAR do
        local b = _G[BAR_BUTTONS[i] .. n]
        if b then out[#out + 1] = b end
    end
    return out
end

-- Is this slot empty? (A button carries its action number; HasAction tells.)
local function isEmpty(btn)
    local act = btn.action
    if type(act) ~= "number" and btn.CalculateAction then
        local ok, a = pcall(btn.CalculateAction, btn)
        if ok then act = a end
    end
    if type(act) ~= "number" and btn.GetAttribute then
        local ok, a = pcall(btn.GetAttribute, btn, "action")
        if ok then act = a end
    end
    if type(act) ~= "number" or not HasAction then return false end
    local ok, has = pcall(HasAction, act)
    if not ok then return false end
    if issecretvalue and issecretvalue(has) then return false end
    return not has
end

local function reapply(btn)
    local w = btnPos[btn]
    if not w or btnBusy[btn] or not root then return end
    if InCombatLockdown() then pending = true; return end
    btnBusy[btn] = true
    pcall(function()
        local par = btn:GetParent()
        local pe = par and par.GetEffectiveScale and par:GetEffectiveScale()
        local re = root:GetEffectiveScale()
        if pe and re and pe > 0 then btn:SetScale(re / pe) end
        btn:SetSize(w.s, w.s)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", w.x, 0)
    end)
    btnBusy[btn] = false
end

local function take(btn)
    if not taken[btn] then
        local pts = {}
        for i = 1, btn:GetNumPoints() do pts[i] = { btn:GetPoint(i) } end
        taken[btn] = { pts = pts, scale = btn:GetScale(), w = btn:GetWidth(), h = btn:GetHeight() }
        if not btnHooked[btn] then
            btnHooked[btn] = true
            -- the game moves or resizes its buttons itself now and then (edit mode, a bar layout): put it back
            hooksecurefunc(btn, "SetPoint", function(self) if btnPos[self] and not btnBusy[self] then reapply(self) end end)
            hooksecurefunc(btn, "SetSize", function(self) if btnPos[self] and not btnBusy[self] then reapply(self) end end)
        end
    end
    pcall(btn.SetIgnoreParentAlpha, btn, true)   -- the bar's own opacity (the art fades with it) must not carry the buttons
end

local function dress(btn, hide)
    pcall(function()
        if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(hide and 0 or 1) end
    end)
end

local function release(btn)
    local st = taken[btn]
    if not st then return end
    taken[btn], btnPos[btn], wantAlpha[btn] = nil, nil, nil
    pcall(function()
        btn:SetAlpha(1)
        btn:SetIgnoreParentAlpha(false)
        btn:SetScale(st.scale)
        btn:SetSize(st.w, st.h)
        btn:ClearAllPoints()
        for _, p in ipairs(st.pts) do btn:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end)
    dress(btn, false)
end

----------------------------------------------------------------------
-- Which layer is held: alpha shows it (alpha may change in combat, positions may not)
----------------------------------------------------------------------
local function talking()
    return UF.Cinematic and UF.Cinematic.talking and UF.Cinematic.enabled and UF.Cinematic.enabled() and UF.Cinematic.talking()
end

function B.refresh()
    local c = cfg()
    if not c.on or not root or #layers == 0 then return end
    if talking() then return end   -- the cinematic camera hides everything that ignores the fade, these buttons included
    local held = B.layerFor(IsShiftKeyDown and IsShiftKeyDown(), IsControlKeyDown and IsControlKeyDown(), IsAltKeyDown and IsAltKeyDown())
    for i, L in ipairs(layers) do
        local active = (i == held)
        for _, btn in ipairs(L.buttons) do
            local a = (active and L.shown[btn]) and 1 or 0
            wantAlpha[btn] = a
            local ok, cur = pcall(btn.GetAlpha, btn)
            if not ok or cur ~= a then pcall(btn.SetAlpha, btn, a) end
            -- layers sit on top of each other: the held one takes the mouse (frame levels only change out of combat)
            if not InCombatLockdown() then
                local lvl = (root:GetFrameLevel() or 1) + (active and 40 or 20)
                if lastLevel[btn] ~= lvl then lastLevel[btn] = lvl; pcall(btn.SetFrameLevel, btn, lvl) end
            end
        end
    end
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local function ensureRoot()
    if root then return end
    root = CreateFrame("Frame", "UbermocForeverGamepadBar", UIParent)
    root:SetSize(10, 10)
    root:SetFrameStrata("MEDIUM")
end

function B.layout()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local c = cfg()
    if not c.on then
        for b in pairs(taken) do release(b) end
        layers = {}
        if root then root:Hide() end
        return
    end
    ensureRoot()
    local s, g = c.size, c.gap
    local carrying = false
    if GetCursorInfo then
        local ok, ct = pcall(GetCursorInfo)
        carrying = ok and ct ~= nil   -- something is being dragged: every slot stays so it can be dropped on
    end
    layers = {}
    local W = B.rowWidth(PER_BAR, s, g)
    for i = 1, #BAR_BUTTONS do
        local all = layerButtons(i)
        local L = { buttons = all, shown = {} }
        local shownList, hiddenList = {}, {}
        for _, btn in ipairs(all) do
            if c.hideEmpty and not carrying and isEmpty(btn) then hiddenList[#hiddenList + 1] = btn
            else shownList[#shownList + 1] = btn end
        end
        local xs = B.rowX(#shownList, s, g, W)
        for k, btn in ipairs(shownList) do
            L.shown[btn] = true
            btnPos[btn] = { x = xs[k], s = s }
        end
        for _, btn in ipairs(hiddenList) do btnPos[btn] = { x = -5000, s = s } end   -- out of sight and out of the mouse's way
        for _, btn in ipairs(all) do take(btn); layerOf[btn] = i; dress(btn, c.hideArt) end
        layers[i] = L
    end
    root:SetSize(math.max(W, 10), s)
    root:ClearAllPoints()
    root:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, c.raise)
    root:Show()
    for _, L in ipairs(layers) do for _, btn in ipairs(L.buttons) do reapply(btn) end end
    B.refresh()
end

local timer
function B.layoutSoon()
    if timer then return end
    timer = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function() timer = nil; pcall(B.layout) end)
    else
        timer = nil; pcall(B.layout)
    end
end

-- Which action bars are on in the game's settings? (A bar that is off keeps its buttons hidden, so its layer shows nothing.)
function B.report()
    local c = cfg()
    local function yn(v) return v and "yes" or "no" end
    UF.say("Gamepad layout: " .. (c.on and "on" or "off") .. ", size " .. c.size .. ", gap " .. c.gap .. ", raise " .. c.raise
        .. ", hide empty " .. yn(c.hideEmpty) .. ", hide the game's art " .. yn(c.hideArt))
    for i = 1, #BAR_BUTTONS do
        local all = layerButtons(i)
        local shown, empty = 0, 0
        for _, b in ipairs(all) do
            if b.IsShown and b:IsShown() then shown = shown + 1 end
            if isEmpty(b) then empty = empty + 1 end
        end
        UF.say("Gamepad layout: layer " .. i .. " (" .. BAR_BUTTONS[i] .. "n): " .. #all .. " buttons found, " .. shown .. " shown by the game, " .. empty .. " empty"
            .. (#all == 0 and " (not in this game)" or ""))
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
UF.OnLogin(function()
    -- the game's bottom art goes through the Fading engine (an explicit setting on the Fading page still wins)
    if UF.Fade and UF.Fade.implicit then
        for _, key in ipairs(ART_KEYS) do
            UF.Fade.implicit[key] = function() local c = cfg(); return (c.on and c.hideArt) and 0 or nil end
        end
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED",
                         "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED",
                         "UPDATE_OVERRIDE_ACTIONBAR", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e)
        if e == "MODIFIER_STATE_CHANGED" then B.refresh(); return end
        if e == "PLAYER_REGEN_ENABLED" and not pending then B.refresh(); return end
        if cfg().on or e == "PLAYER_ENTERING_WORLD" then B.layoutSoon() end
    end)
    -- the modifier events do not always arrive for the controller's emulated keys: look a few times a second
    local acc = 0
    ev:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        if cfg().on then B.refresh() end
    end)
    B.layoutSoon()
end)
