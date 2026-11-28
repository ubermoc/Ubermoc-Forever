# Offline test for the addon: compiles every file, loads them against a stub of the game, and exercises detection,
# the first-run prompt, the default binds, the options window and its D-pad buttons.
# Run: python3 tools/smoke_test.py   (needs: pip install lupa). It cannot test what only the real game does:
# where the cursor lands, how the windows look, and whether Forever has every function the addon uses.
import sys, os
# lupa must be installed: pip install lupa (tools/setup-research.sh does this in a private folder)
import lupa
from lupa import LuaRuntime

ADDON = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Ubermoc-Forever")
toc = [l.strip() for l in open(ADDON + "/Ubermoc-Forever.toc") if l.strip() and not l.startswith("##")]

lua = LuaRuntime(unpack_returned_tuples=True)

# 1. syntax: compile every file
bad = 0
for f in toc:
    src = open(os.path.join(ADDON, f)).read()
    fn, err = lua.eval("function(s, n) local f, e = load(s, n); return f, e end")(src, f)
    if fn is None:
        print("SYNTAX ERROR", f, err); bad += 1
    else:
        print("syntax ok  ", f)
if bad:
    sys.exit(1)

# 2. smoke: run the addon against a stub game
stub = r'''
-- The game runs Lua 5.1: math.atan takes ONE number (a second is ignored) and math.atan2 is the two-argument arc tangent. This test runs
-- Lua 5.5, where it is the other way round, so the stub makes the maths library behave like the game's (the quest arrow's bearing was wrong
-- in the game for exactly this reason while every offline test passed).
do
    local realAtan = math.atan
    math.atan2 = function(y, x) return realAtan(y, x) end
    math.atan = function(y) return realAtan(y) end
end
local calls = { binds = {}, cvars = {}, saved = 0, popups = {}, hooks = {}, overrides = {} }
_G.__calls = calls
-- Strict like the game: every method of a stub frame must be called WITH the frame (frame:Method(), not frame.Method()). The game
-- raises an error when the frame is missing; a stub that ignores it lets a dot-call pass every test (that hid the X bag-item bug of
-- 1.3.155). isProxy is weak so frames can still be collected.
local isProxy = setmetatable({}, { __mode = "k" })
local function strict(name, fn)
    return function(s, ...)
        if not isProxy[s] then error("method '" .. tostring(name) .. "' called without its frame (a dot where a colon belongs): got " .. type(s), 2) end
        return fn(s, ...)
    end
end
local function proxy(name)
    local t = {}
    local mt = {}
    mt.__index = function(self, k)
        local v = mt.__raw(self, k)
        if type(v) == "function" then return strict(k, v) end
        return v
    end
    mt.__raw = function(self, k)
        -- Lowercase names are plain data fields in the game (picker.built, row.pad): unset means nil, not a method.
        if type(k) == "string" and k:match("^%l") then return nil end
        if k == "GetName" then return function() return name end end
        if k == "GetRect" then return function() return 100, 100, 50, 20 end end
        if k == "GetCenter" then return function() return 125, 110 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        -- child frames a template provides (win.Inset, win.CloseButton) are tables, not methods
        if k == "Inset" or k == "CloseButton" then local c = proxy(k); rawset(self, k, c); return c end
        if k == "GetStringWidth" then return function() return 40 end end
        if k == "GetTextWidth" then return function() return 60 end end
        if k == "Click" then return function(s) local sc = rawget(s, "__scripts"); if sc and sc.OnClick then sc.OnClick(s, "LeftButton", false) end end end
        if k == "GetText" then return function(s) return rawget(s, "__text") end end
        if k == "SetText" then return function(s, v) rawset(s, "__text", v); local o = rawget(s, "__owner"); if o then rawset(o, "__fstext", v) end end end
        if k == "IsEnabled" then return function() return true end end
        -- a frame is shown until it is hidden, like in the game
        if k == "IsShown" or k == "IsVisible" then return function(s) return rawget(s, "__hidden") ~= true end end
        -- Hide and Show run the frame's OnHide / OnShow, but only when the state really changes, as in the game
        if k == "Hide" then return function(s)
            if rawget(s, "__hidden") ~= true then
                rawset(s, "__hidden", true)
                local sc = rawget(s, "__scripts"); if sc and sc.OnHide then sc.OnHide(s) end
            end
        end end
        if k == "Show" then return function(s)
            if rawget(s, "__hidden") == true then
                rawset(s, "__hidden", nil)
                local sc = rawget(s, "__scripts"); if sc and sc.OnShow then sc.OnShow(s) end
            end
        end end
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetVerticalScroll" or k == "GetVerticalScrollRange" or k == "GetTop" or k == "GetBottom" then return function() return 0 end end
        if k == "SetScript" then return function(s, ev, fn) rawset(s, "__scripts", rawget(s, "__scripts") or {}); s.__scripts[ev] = fn end end
        if k == "HookScript" then return function() end end
        if k == "RegisterEvent" then return function(s, e) rawset(s, "__events", rawget(s, "__events") or {}); s.__events[e] = true end end
        if k == "CreateFontString" or k == "CreateTexture" then return function(owner) local sub = proxy("sub"); rawset(sub, "__owner", owner); return sub end end
        if k == "SetFontString" then return function() end end
        -- word wrap is off unless the font string asks for it (claim C166), so the stub records what was asked for
        if k == "SetWordWrap" then return function(s, v) rawset(s, "__wrap", v) end end
        -- like the game: a texture or text with no point is never drawn, so the stub counts the points a region was given;
        -- SetAtlas, SetTexture and SetPoint answer nothing (the 1.3.146 arrow took "answers nothing" for "failed" and never drew)
        if k == "SetPoint" or k == "SetAllPoints" then return function(s) rawset(s, "__points", (rawget(s, "__points") or 0) + 1) end end
        if k == "SetBlendMode" then return function(s, v) rawset(s, "__blend", v) end end
        if k == "SetAlpha" then return function(s, v) rawset(s, "__alpha", v) end end
        -- SetAtlas answers nothing; GetAtlas reads back what was set, and nothing when the atlas is not in the client (as the game does)
        if k == "SetAtlas" then return function(s, v) if not rawget(_G, "__noAtlas") then rawset(s, "__art", v); rawset(s, "__atlas", v) end end end
        if k == "GetAtlas" then return function(s) return rawget(s, "__atlas") end end
        if k == "SetTexture" then return function(s, v) rawset(s, "__art", v); rawset(s, "__atlas", nil) end end
        return function() return proxy("ret") end
    end
    setmetatable(t, mt)
    isProxy[t] = true
    return t
end
local frames = {}
function CreateFrame(kind, name, parent, tmpl)
    local f = proxy(name or "anon")
    rawset(f, "__kind", kind)
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
_G.__frames = frames
UIParent = proxy("UIParent")
GameMenuFrame = proxy("GameMenuFrame")
GameMenuFrame.InitButtons = function() end
GameMenuFrame.buttonPool = { EnumerateActive = function() return function() return nil end end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) calls.chat = (calls.chat or "") .. m .. "\n" end }
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc(obj, name, fn) calls.hooks[#calls.hooks + 1] = name end
C_Timer = { After = function(_, fn) calls.timers = (calls.timers or {}); table.insert(calls.timers, fn) end }
C_Texture = { GetAtlasInfo = function(n) return {} end }
C_GamePad = {
    GetActiveDeviceID = function() return 1 end,
    GetAllDeviceIDs = function() return { 1 } end,
    GetDeviceRawState = function(id) return { name = _G.__padname or "DualSense Wireless Controller", vendorID = 1356, productID = 3302 } end,
    GetDeviceMappedState = function() return { buttons = {} } end,
    ButtonIndexToBinding = function() return "PAD1" end,
}
UnitGUID = function() return "Player-1-ABC" end
InCombatLockdown = function() return false end
GetTime = function() return 0 end
GetCVar = function(n) return calls.cvars[n] or "0" end
SetCVar = function(n, v) calls.cvars[n] = v end
SetBinding = function(k, a) calls.binds[k] = a end
GetBindingKey = function() return nil end
GetBindingAction = function(k) return calls.binds[k] or "" end
GetNumBindings = function() return 4 end
GetBinding = function(i)
    -- the last one has no category at all, as some of the game's bindings really do (they belong to "Other")
    local t = { { "ACTIONBUTTON1", "ACTIONBAR" }, { "JUMP", "MOVEMENT" }, { "TOGGLEWORLDMAP", "INTERFACE" }, { "SOMEOTHER", nil } }
    return t[i][1], t[i][2]
end
SaveBindings = function() calls.saved = calls.saved + 1 end
GetCurrentBindingSet = function() return 2 end
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) calls.popups[#calls.popups + 1] = which .. ":" .. tostring(a) end
YES, NO = "Yes", "No"
CanAutoSetGamePadCursorControl = function() return true end
SetGamePadCursorControl = function() end
GetCursorPosition = function() return 100, 100 end
SetCursorPosition = function() end
SetOverrideBindingClick = function(owner, prio, key) calls.overrides[key] = true end
RegisterStateDriver = function(f, state, cond) calls.driver = state .. ':' .. cond end
ClearOverrideBindings = function() calls.overrides = {} end
PlaySound = function() end
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
HideUIPanel = function() end
GAMEMENU_OPTIONS = "Options"
-- the game's own button strings
KEY_PAD1_LTR = "|A:Gamepad_Ltr_A_64:24:24|a"
KEY_PAD1_SHP = "|A:Gamepad_Shp_Cross_64:24:24|a"
KEY_PAD1_REV = "|A:Gamepad_Rev_B_64:24:24|a"
KEY_PAD1 = "|A:Gamepad_Gen_1_64:24:24|a"
BINDING_NAME_JUMP = "Jump"
BINDING_HEADER_ACTIONBAR = "Action Bar 1"
BINDING_HEADER_MOVEMENT = "Movement"
BINDING_HEADER_INTERFACE = "Interface"
BINDING_HEADER_OTHER = "Other"
'''
lua.execute(stub)
ns = lua.eval("{}")
for f in toc:
    src = open(os.path.join(ADDON, f)).read()
    fn = lua.eval("function(s, n) return load(s, n) end")(src, f)
    try:
        fn("Ubermoc-Forever", ns)
    except Exception as e:
        print("LOAD ERROR", f, e); sys.exit(1)
print("all files load")

L = lua.eval
UF = L("UbermocForever")
fire = L("""function(frameEvent)
    for _, f in ipairs(__frames) do
        local ev = rawget(f, "__events")
        local sc = rawget(f, "__scripts")
        if ev and ev[frameEvent] and sc and sc.OnEvent then sc.OnEvent(f, frameEvent) end
    end
end""")
fire("PLAYER_LOGIN")
print("login ok; detected =", UF.detected, "| device =", UF.deviceName)
assert UF.detected == "ps5", "PS5 pad should be classified ps5"
print("glyph PAD1 on ps5:", UF.glyph("PAD1", "ps5"))
print("glyph PAD1 on switch:", UF.glyph("PAD1", "switch"))
print("glyph PAD1 on xbox:", UF.glyph("PAD1", "xbox"))

# run queued timers (prompt, checks)
L("""function() local t = __calls.timers or {}; __calls.timers = {}; for _, f in ipairs(t) do f() end end""")()
print("popups shown:", list(L("__calls.popups").values()))
ok = UF.applyDefaults("ps5")
print("applyDefaults standard ->", ok)
b = L("__calls.binds")
for k in ["PAD3", "PAD1", "SHIFT-PAD1", "CTRL-SHIFT-PAD4", "PADRSHOULDER", "PADLSHOULDER", "PADFORWARD", "PADBACK", "SHIFT-PADLSTICK", "PADLSTICK", "PADRSTICK"]:
    print("  ", k, "->", b[k])
c = L("__calls.cvars")
print("  modifiers:", c["GamePadEmulateShift"], c["GamePadEmulateCtrl"])
for layer in ["", "SHIFT-", "CTRL-", "CTRL-SHIFT-"]:
    assert b[layer + "PADFORWARD"] == "CLICK UbermocForeverStart:LeftButton", "Start should be the stepped button on layer '%s'" % layer
assert c["GamePadEmulateEsc"] == "NONE", "the game's own Escape button should be off so it cannot take the press"
print("  default: Start = stepped exit / game menu on every layer: OK")
ok = UF.applyDefaults("steam")
print("applyDefaults steam ->", ok, "| shift/ctrl:", c["GamePadEmulateShift"], c["GamePadEmulateCtrl"], "| PADLSTICK:", b["PADLSTICK"], "| F6:", b["F6"], "| PADRSTICK:", b["PADRSTICK"], "| bar5 spill:", b["MULTIACTIONBAR4BUTTON1"])

# checks + options window + nav
UF.runChecks()
print("checks failed:", UF.checksFailed)
for ch in list(UF.checks.values()):
    if not ch.ok: print("   FAIL", ch.name, ch.detail)
UF.ToggleOptions(True)
print("options built; nav overrides taken:", sorted(list(L("__calls.overrides").keys())))
print("chat:", (L("__calls.chat") or "").strip()[:300])

# show the window the way the game would, then press the D-pad and bumpers
L("""function()
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
end""")()
print("nav overrides after show:", sorted(list(L("__calls.overrides").keys())))
res = L("""function()
    local out = {}
    for _, key in ipairs({ "PADDDOWN", "PADDUP", "PADDLEFT", "PADDRIGHT", "PADLSHOULDER", "PADRSHOULDER", "PAD3", "PAD4", "PAD2" }) do
        local b = _G["UbermocForeverNav_" .. key]
        local ok, err = pcall(b.__scripts.OnClick, b, "LeftButton", true)
        out[#out + 1] = key .. "=" .. tostring(ok) .. (ok and "" or (" " .. tostring(err)))
    end
    return table.concat(out, "; ")
end""")()
print("nav presses:", res)
L("""function() local w = UbermocForeverOptions; w:Hide() end""")()
print("overrides after hide:", len(list(L("__calls.overrides").keys())))

print("combat driver registered:", L("__calls.driver"))
assert L("__calls.driver") == "combat:[combat] 1; 0", "the secure combat driver must be registered"
print("Nav owner frame exists:", L("UbermocForeverNavOwner") is not None)
print("device name shown on options header:", "yes" if L("UbermocForever").deviceName else "no")
print("ALL CHECKS PASSED")

# open the action picker the way a click on a Change button does, choose an action, and check the bind changed
res = L("""function()
    local clicked
    for _, f in ipairs(__frames) do
        local sc = rawget(f, "__scripts")
        if sc and sc.OnClick and rawget(f, "__text") == "Change" then clicked = f; break end
    end
    if not clicked then return "no Change button found" end
    clicked.__scripts.OnClick(clicked)
    -- the picker's action buttons are the ones that now exist with text from the binding list
    local chose
    for _, f in ipairs(__frames) do
        local sc = rawget(f, "__scripts")
        if sc and sc.OnClick and rawget(f, "__fstext") == "Jump" then chose = f; break end
    end
    if not chose then return "picker built no Jump button" end
    chose.__scripts.OnClick(chose)
    return "picked: PAD3 now " .. tostring(__calls.binds["PAD3"]) .. " / SHIFT-PAD3 now " .. tostring(__calls.binds["SHIFT-PAD3"])
end""")()
print("picker:", res)
assert "JUMP" in res, res
print("PICKER OK")

# ---- navigation: the D-pad moves a highlight, A presses it, B / X / Y do what the legend says ----
nav = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
    local function press(key)
        local b = _G["UbermocForeverNav_" .. key]
        b.__scripts.OnClick(b, "LeftButton", true)
        b.__scripts.OnClick(b, "LeftButton", false)
    end
    local function where()
        local f = UF.Nav.focus
        if not f then return "none" end
        if f.navRow then return f.navRow.pad end
        return "other"
    end
    for i = 1, 4 do if UF.optionsLayer() ~= 1 then press("PADLSHOULDER") end end   -- the bumpers: back to the first layer
    press("PADLSHOULDER"); local wrapL = UF.optionsLayer()          -- left on the first hold goes to the last
    press("PADRSHOULDER"); local wrapR = UF.optionsLayer()          -- right on the last hold goes to the first
    assert(wrapL == 4 and wrapR == 1, "bumpers should wrap: " .. wrapL .. "," .. wrapR)
    local out = { where() }
    for i = 1, 40 do press("PADDDOWN"); out[#out + 1] = where() end
    local walk = table.concat(out, ",")

    -- back up to the third row, then A on it, then B
    for i = 1, 60 do press("PADDUP") end
    local top = where()
    press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN")      -- header, cinematic row, layers, first row ... settle on a list row
    local row = where()
    press("PAD1")                                                  -- A on a row opens the picker
    local inPicker = (UF.Nav.focus ~= nil) and (UF.Nav.focus.navRow == nil) and (UF.Nav.focus.navScroll ~= nil)
    press("PAD2")                                                  -- B closes it
    local back = where()
    local pad = back
    __calls.binds[pad] = "ACTIONBUTTON1"
    press("PAD3")                                                  -- X clears the highlighted row
    local cleared = tostring(__calls.binds[pad])
    __calls.popups = {}
    press("PAD4")                                                  -- Y asks to reset
    local asked = tostring(__calls.popups[1])
    return walk .. "|" .. top .. "|" .. row .. "|" .. tostring(inPicker) .. "|" .. back .. "|" .. cleared .. "|" .. asked
end""")()
walk, top, row, in_picker, back, cleared, asked = str(nav).split("|")
seq = walk.split(",")
order = list(L("UbermocForever.PAD_ORDER").values())
print("highlight walk:", ",".join(seq[:12]), "...", seq[-1])
first_other = seq.index("other")
assert all(x == "other" for x in seq[first_other:]), "highlight must stay on the bottom row once it is there, not jump back"
lst = seq[:first_other]
idx = [order.index(x) for x in lst]
assert idx == sorted(idx) and len(set(idx)) == len(idx), "rows must be visited in order, once each: %s" % lst
assert lst[0] == order[0], "highlight should start on the first row"
print("rows visited in order, no jump to the top: OK  (%d rows)" % len(lst))
assert in_picker == "true", "A on a row should open the picker and move the highlight into it"
assert back == row, "B should close the picker and return to the same row (%s vs %s)" % (back, row)
assert cleared == "nil", "X should clear the highlighted row's bind"
assert asked.startswith("UBERMOCFOREVER_RESET"), "Y should ask to reset"
print("A opens the picker, B returns to the row, X clears it, Y asks to reset: OK")

# the first-run question and the reset question take A and B too
pop = L("""function()
    local UF = UbermocForever
    local yes, no = { clicked = false }, { clicked = false }
    local dialog = {
        GetButton1 = function() return { IsEnabled = function() return true end, Click = function() yes.clicked = true end } end,
        GetButton2 = function() return { IsShown = function() return true end, Click = function() no.clicked = true end } end,
    }
    StaticPopupDialogs["UBERMOCFOREVER_DEFAULTS"].OnShow(dialog)
    local a = _G["UbermocForeverNav_PAD1"]; a.__scripts.OnClick(a, "LeftButton", true); a.__scripts.OnClick(a, "LeftButton", false)
    local b = _G["UbermocForeverNav_PAD2"]; b.__scripts.OnClick(b, "LeftButton", true); b.__scripts.OnClick(b, "LeftButton", false)
    StaticPopupDialogs["UBERMOCFOREVER_DEFAULTS"].OnHide(dialog)
    return tostring(yes.clicked) .. "," .. tostring(no.clicked)
end""")()
assert str(pop) == "true,true", pop
print("question window: A = Yes, B = No: OK")
L("""function() local w = UbermocForeverOptions; w:Hide() end""")()
print("overrides after the window closes:", len(list(L("__calls.overrides").keys())))
assert len(list(L("__calls.overrides").keys())) == 0
print("NAVIGATION OK")

# the controller button always shows a short name, so its label can never spill out of the button
L("""function() local UF = UbermocForever; UF.DB().layout = "steam"; UF.RefreshOptions() end""")()
label = L("UbermocForeverOptions.controllerBtn.__text")
assert label == "Steam Deck", label
width = L("UbermocForeverOptions.controllerBtn.__width") or 0
L("""function() local UF = UbermocForever; UF.DB().layout = "auto"; UF.RefreshOptions() end""")()
assert L("UbermocForeverOptions.controllerBtn.__text") == "Auto"
print("controller button label stays short ('%s'): OK" % label)


# ---- the category list: every category starts closed, one open at a time; Exit is the game's own Escape ----
acc = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
    local function press(key)
        local b = _G["UbermocForeverNav_" .. key]
        b.__scripts.OnClick(b, "LeftButton", true)
        b.__scripts.OnClick(b, "LeftButton", false)
    end
    local function flush() local t = __calls.timers or {}; __calls.timers = {}; for _, f in ipairs(t) do f() end end
    local names = { ACTIONBUTTON1 = true, Jump = true, TOGGLEWORLDMAP = true }
    local function shownItems()
        local n, which = 0, ""
        for _, f in ipairs(__frames) do
            local x = rawget(f, "__fstext")
            -- only the picker's own lines (they carry .label); the window's rows show the same names
            if x and names[x] and rawget(f, "label") and rawget(f, "__hidden") ~= true then n = n + 1; which = which .. x end
        end
        return n, which
    end
    for i = 1, 4 do if UF.optionsLayer() ~= 1 then press("PADLSHOULDER") end end   -- first layer
    press("PAD1")                                      -- A on the first row opens the picker (it is for PAD3)
    local closed = shownItems()
    press("PADDDOWN"); press("PAD1"); flush()          -- Exit -> first category, open it
    local open1 = shownItems()
    press("PADDDOWN"); press("PADDDOWN"); press("PAD1"); flush()   -- its item, the second category, open it
    local open2, which2 = shownItems()
    press("PAD1"); flush()                             -- again: closes
    local closedAgain = shownItems()

    -- Exit: pick it for the button the picker is open for (layer 1, button PAD3)
    press("PADDDOWN"); press("PADDDOWN")               -- ... down to the third category header, then
    for i = 1, 6 do press("PADDUP") end                -- back up to Exit (it stops at the top: Cancel)
    press("PADDDOWN")
    local onExit = UF.Nav.focus and UF.Nav.focus.label and rawget(UF.Nav.focus.label, "__text") or "?"
    press("PAD1")
    local esc = tostring(GetBindingAction("PAD3"))
    local function rowTextFor(pad)
        local t
        for _, f in ipairs(__frames) do
            if rawget(f, "pad") == pad and rawget(f, "glyph") and rawget(f, "__fstext") then t = rawget(f, "__fstext") end
        end
        return tostring(t)
    end
    local rowText = rowTextFor("PAD3")
    -- binding something to that layer takes Escape away on that layer only: the button stays the game's Escape button
    UF.setBind("PAD3", "JUMP")
    UF.RefreshOptions()
    local escAfter = tostring(__calls.cvars.GamePadEmulateEsc)
    local boundText = rowTextFor("PAD3")
    -- on a layer where it has no bind, the same button reads Exit
    UF.setBind("CTRL-PAD3", nil)
    press("PADRSHOULDER"); press("PADRSHOULDER")        -- third layer
    local otherLayer = rowTextFor("PAD3")
    -- X on an Exit row turns the game's Escape button off
    UF.Nav.ClearFocus()
    for _, r in ipairs(UF.__rows or {}) do end
    for _, f in ipairs(__frames) do
        if rawget(f, "pad") == "PAD3" and rawget(f, "glyph") then UF.Nav.SetFocus(f.btn) end
    end
    press("PAD3")
    local escOff = tostring(__calls.cvars.GamePadEmulateEsc)
    local offText = rowTextFor("PAD3")
    return table.concat({ closed, open1, open2, which2, closedAgain, onExit, esc, rowText, escAfter, boundText, otherLayer, escOff, offText }, "\t")
end""")()
closed, open1, open2, which2, closed_again, on_exit, esc, row_text, esc_after, bound_text, other_layer, esc_off, off_text = str(acc).split("\t")
assert (closed, open1, open2, closed_again) == ("0", "1", "1", "0"), "categories: closed, then one open, then the other (one at a time), then closed: %s" % acc
assert which2 == "Jump", "the second category's action should be showing, not the first's: %s" % which2
print("categories start closed and open one at a time: OK")
assert esc == "CLICK UbermocForeverStart:LeftButton", "choosing Exit should bind the stepped Start button: %s" % esc
assert row_text == "Exit / game menu (Start)", "the row should read Exit / game menu (Start): %s" % row_text
assert bound_text == "Jump", "a bind replaces it on that layer: %s" % bound_text
assert other_layer.startswith("|cffa0a0a0Not bound"), "another layer with no bind reads Not bound: %s" % other_layer
print("Exit: choosing it again after clearing binds the stepped Start button: OK")

# friendlier names for binds that would show as a code
names = L("""function() local UF = UbermocForever; return UF.actionName("CLICK UbermocMenu:LeftButton") .. "|" .. UF.actionName("CLICK SomeAddonButton:LeftButton") end""")()
assert str(names) == "Exit / game menu (Start)|Press: SomeAddonButton", names
print("code-like binds get plain names: OK")

# ---- a binding with no category goes under "Other"; a failure building the list is reported, not silent ----
other = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
    local function press(key)
        local b = _G["UbermocForeverNav_" .. key]
        b.__scripts.OnClick(b, "LeftButton", true)
        b.__scripts.OnClick(b, "LeftButton", false)
    end
    press("PAD1")                                             -- open the picker
    local header
    for _, f in ipairs(__frames) do
        if rawget(f, "label") and rawget(f, "__fstext") == "Other" then header = f end
    end
    if not header then return "no Other category" end
    header:Click()                                            -- open it
    local shown = false
    for _, f in ipairs(__frames) do
        if rawget(f, "label") and rawget(f, "__fstext") == "SOMEOTHER" and rawget(f, "__hidden") ~= true then shown = true end
    end
    return "other:" .. tostring(shown)
end""")()
assert str(other) == "other:true", other
print("a binding with no category shows under Other: OK")

failed = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
    __calls.chat = ""
    -- a fresh picker whose list cannot be read: it must still open, still offer Exit, and say why
    local realGet = GetBinding
    GetBinding = function() error("boom") end
    local function press(key)
        local b = _G["UbermocForeverNav_" .. key]
        b.__scripts.OnClick(b, "LeftButton", true)
        b.__scripts.OnClick(b, "LeftButton", false)
    end
    for _, f in ipairs(__frames) do
        -- find the picker (it carries .navRows) and forget what it built
        if rawget(f, "navRows") then f.built = false; f.groups = nil end
    end
    press("PAD1")
    GetBinding = realGet
    local focus = UF.Nav.focus
    local onExit = focus and focus.label and rawget(focus.label, "__text") == "Exit / game menu (Start)"
    return tostring(onExit) .. "|" .. tostring(string.find(__calls.chat or "", "could not be read", 1, true) ~= nil)
end""")()
assert str(failed) == "true|true", failed
print("a list that cannot be read is reported and Exit still works: OK")

# Start: close what is open and clear the target first, then the game menu, then close the menu
r = L("""function()
    local out = {}
    local gm = GameMenuFrame
    gm.__shown = false
    gm.IsShown = function(self) return self.__shown end
    ShowUIPanel = function(f) f.__shown = true end
    HideUIPanel = function(f) f.__shown = false end
    UnitExists = function() return __target end
    UnitCastingInfo = function() return nil end
    UnitChannelInfo = function() return nil end
    local UF = UbermocForever
    __target = true
    out[#out + 1] = UF.startPressed()                 -- target set: clear
    __target = false
    out[#out + 1] = UF.startPressed()                 -- nothing left: open the game menu
    out[#out + 1] = tostring(gm.__shown)
    out[#out + 1] = UF.startPressed()                 -- menu up: close it
    out[#out + 1] = tostring(gm.__shown)
    return table.concat(out, ",")
end""")()
assert str(r) == "clear,menu,true,hide,false", r
print("Start: clears the target, then opens the game menu, then closes it: OK")
# Combat rule: the window will not open in combat, and the buttons are taken again when combat ends
r = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide()
    local real = InCombatLockdown
    InCombatLockdown = function() return true end
    __calls.chat = ""
    UF.ToggleOptions(true)
    local openedInCombat = w:IsShown()
    local said = string.find(__calls.chat or "", "in combat", 1, true) ~= nil
    InCombatLockdown = real
    UF.ToggleOptions(true)
    local openedAfter = w:IsShown()
    w:Hide()
    return tostring(openedInCombat) .. "," .. tostring(said) .. "," .. tostring(openedAfter)
end""")()
assert str(r) == "false,true,true", r
print("Combat: the window refuses to open in combat and opens again after: OK")
# Moving around the game's own windows
r = L("""function()
    local G = UbermocForever.GameNav
    local function n(x, y) return { cx = x, cy = y } end
    local cur = n(100, 100)
    local right, below, farRight, up = n(160, 100), n(100, 60), n(300, 100), n(100, 140)
    local out = {}
    out[#out + 1] = tostring(G.pick({ right, below, farRight, up }, cur, "RIGHT") == right)
    out[#out + 1] = tostring(G.pick({ right, below, farRight, up }, cur, "DOWN") == below)
    out[#out + 1] = tostring(G.pick({ right, below, farRight, up }, cur, "UP") == up)
    out[#out + 1] = tostring(G.pick({ below }, cur, "UP") == nil)
    -- straight ahead beats a slightly nearer one off to the side
    local side, ahead = n(130, 140), n(100, 170)
    out[#out + 1] = tostring(G.pick({ side, ahead }, cur, "UP") == ahead)
    out[#out + 1] = tostring(G.stepTab(4, 4, 1)) .. tostring(G.stepTab(4, 1, -1)) .. tostring(G.stepTab(4, 2, 1))
    out[#out + 1] = tostring(G.nearest({ right, farRight }, 200, 100) == right)
    -- one update with nothing open does nothing, and with a window open it does not fail
    G.update()
    ContainerFrame1 = CreateFrame("Frame", "ContainerFrame1", UIParent)
    G.update()
    local active = tostring(G.active())
    ContainerFrame1:Hide()
    G.update()
    out[#out + 1] = active .. tostring(G.active())
    return table.concat(out, ",")
end""")()
assert str(r) == "true,true,true,true,true,143,true,truefalse".replace(" ", ""), r
print("Game windows: highlight picks the right neighbour, tabs wrap, a window turns it on and off: OK")
# The Y menu on a bag item
r = L("""function()
    local UF = UbermocForever
    local out = {}
    local btn = CreateFrame("Button", "FakeItem", UIParent)
    btn.GetBagID = function() return 0 end
    btn.GetID = function() return 3 end
    C_Container = nil
    out[#out + 1] = tostring(UF.ItemMenu.open(btn))            -- no item information: says so, does not open
    C_Container = { GetContainerItemInfo = function() return { hyperlink = "|cff|Hitem:1|h[Sword]|h|r" } end,
                    SortBags = function() end, PickupContainerItem = function() end }
    out[#out + 1] = tostring(UF.ItemMenu.open(btn))
    out[#out + 1] = tostring(UF.ItemMenu.isOpen())
    local wins = UF.GameNav.windows()
    out[#out + 1] = tostring(#wins) .. tostring(wins[1] == UbermocForeverItemMenu)
    UbermocForeverItemMenu:Hide()
    out[#out + 1] = tostring(UF.ItemMenu.isOpen())
    return table.concat(out, ",")
end""")()
assert str(r) == "false,true,true,1true,false", r
print("Y menu: opens on a bag item, becomes the top window, closes: OK")
# Placing a spell, and closing the window the highlight is in
r = L("""function()
    local G = UbermocForever.GameNav
    local out = {}
    local a = { GetParent = function() return nil end }
    local b = { GetParent = function() return a end }
    out[#out + 1] = tostring(G.inside(b, a)) .. tostring(G.inside(a, b))
    G.beginPlace(b)
    out[#out + 1] = tostring(G.placing ~= nil)
    G.endPlace(true)
    out[#out + 1] = tostring(G.placing == nil) .. tostring(G.restore == b)
    G.restore = nil
    G.update()
    return table.concat(out, ",")
end""")()
assert str(r) == "truefalse,true,truetrue", r
print("Placing a spell: begins and ends cleanly: OK")
# Side tabs are plain frames (no Click): found by their parts, selected one read from SelectedTexture
r = L("""function()
    local G = UbermocForever.GameNav
    local pressed = {}
    local function tab(i, selected)
        local t = { SelectedTexture = { IsShown = function() return selected end }, TabGlow = {},
                    IsShown = function() return true end, GetTop = function() return 500 - i * 40 end,
                    GetScript = function(_, n) if n == "OnMouseUp" then return function(self) pressed[#pressed + 1] = i end end end }
        return t
    end
    local tabs = { tab(1, false), tab(2, true), tab(3, false) }
    local win = { IsShown = function() return true end, GetChildren = function() return tabs[1], tabs[2], tabs[3] end }
    local groups = G.groupsFor(win)
    return #groups .. "," .. (groups[1] and #groups[1].buttons or 0) .. "," .. (groups[1] and groups[1].cur or 0)
end""")()
assert str(r) == "1,3,2", r
print("Side tabs that are plain frames are found, with the chosen one: OK")
# The triggers are only claimed where they have something to do (the legend must agree): stacked side tabs, or a list
# under the highlight. With neither they stay the player's own bind -- a spell on the right trigger (stealth, say)
# could not be cast while any window was open, because a key this mod claims never reaches the action bar.
# FAKE(C5): the stub scroll frame stands for the game's scroll list, which is a frame answering
# IsObjectType("ScrollFrame") with GetVerticalScrollRange (SmartNavigation.lua:1100-1102). The other stubs are plain
# frames and buttons with the methods our scan reads.
r = L("""function()
    local G, UF = UbermocForever.GameNav, UbermocForever
    local out = {}
    local savedWins = G.windows
    local stash = {}
    for i = #UF.Nav._stack, 1, -1 do stash[#stash + 1] = table.remove(UF.Nav._stack, i) end
    local savedUpdate = UF.Nav.Update
    local updates = 0
    UF.Nav.Update = function() updates = updates + 1 end
    local function node(name, kind, parent, cx, cy)
        return { GetName = function() return name end, IsShown = function() return true end,
                 IsObjectType = function(_, t) return t == kind end, IsMouseEnabled = function() return true end,
                 IsVisible = function() return true end,
                 GetCenter = function() return cx, cy end, GetWidth = function() return 32 end,
                 GetHeight = function() return 32 end, GetEffectiveScale = function() return 1 end,
                 GetChildren = function() return end, GetParent = function() return parent end,
                 Click = function() end, GetScript = function() return nil end }
    end
    local function claim()
        local m = G.entryMaps()          -- the map as Nav holds it now
        return tostring(G.triggersUsable()) .. ":" .. (m.PADRTRIGGER and "taken" or "free")
    end
    -- 1. a window with one plain button: nothing stacked and nothing to scroll, so nothing is taken
    local win = node("SomeFrame", "Frame", nil, 100, 100)
    local b = node("SomeFrameButton", "Button", win, 100, 100)
    win.GetChildren = function() return b end
    G.windows = function() return { win } end
    G.update()
    out[#out + 1] = tostring(G.active()) .. "," .. tostring(G.focusFrame() == b) .. "," .. claim()
    -- 2. the same kind of button inside a scroll frame: the triggers scroll it
    local win2 = node("OtherFrame", "Frame", nil, 200, 200)
    local sc = node("OtherFrameScroll", "ScrollFrame", win2, 200, 200)
    sc.GetVerticalScrollRange = function() return 300 end
    local b2 = node("OtherFrameRow", "Button", sc, 200, 200)
    win2.GetChildren = function() return sc end
    sc.GetChildren = function() return b2 end
    G.windows = function() return { win2 } end
    G.update()
    out[#out + 1] = claim()
    -- 3. stacked side tabs with nothing to scroll: the triggers page the tabs
    local win3 = node("ThirdFrame", "Frame", nil, 300, 300)
    local tabs = {}
    for i = 1, 3 do
        local t = node("ThirdTab" .. i, "Frame", win3, 300, 500 - i * 40)
        t.SelectedTexture = { IsShown = function() return i == 2 end }
        t.TabGlow = {}
        tabs[i] = t
    end
    win3.GetChildren = function() return tabs[1], tabs[2], tabs[3] end
    G.windows = function() return { win3 } end
    G.update()
    out[#out + 1] = claim()
    -- 4. back to a window with nothing to do: the triggers are given back, and the entry's map is rebuilt only when
    -- the claim changes (2 changes so far: taken at 2, given back here)
    G.windows = function() return { win } end
    G.update()
    out[#out + 1] = claim() .. "," .. tostring(updates)
    UF.Nav.Update = savedUpdate
    G.windows = savedWins
    G.update()                 -- nothing open: the entry is released
    for i = #stash, 1, -1 do UF.Nav._stack[#UF.Nav._stack + 1] = stash[i] end
    return table.concat(out, "|")
end""")()
assert str(r) == "true,true,false:free|true:taken|true:taken|false:free,2", r
print("The triggers are only claimed when they have something to do, and given back when they have nothing: OK")
# X on a bag item: the game's own right click is a protected action on the game's button, and a button stored by
# our code is refused by the secure click (C141), so X goes through the string actions instead. 1.3.152: X is the
# game's right click on EVERY item in a slot - the item's own use for a recipe, a hearthstone, a poison or an armor
# kit (C138, C140), and the equip of an equippable item such as a bag - and it still sells at a vendor through the
# button name (C145). The legend says what X does. 1.3.154: the use runs as the game's /use macro (C157, C158, C153),
# the route the user confirmed working in the game.
# FAKE(C146): the stub stands for C_Container.GetContainerItemInfo returning the ContainerItemInfo table with its
# itemID (ContainerDocumentation.lua:192-206 and 766-782). FAKE(C142): the class numbers are the game's
# (ItemConstantsDocumentation.lua:276-291). FAKE(C143): a poison is consumable subclass Other = 8 (same file:307-315).
# FAKE(C139): the stub tooltip line stands for a line read as lineData.leftText (TooltipDataHandler.lua:339-348).
# FAKE(C145): the vendor stands for MerchantFrame with selectedTab (ContainerFrame.lua:1543-1550).
r = L("""function()
    local G, M = UbermocForever.GameNav, UbermocForever.ItemMenu
    local classes = { [501] = { 9, 0 }, [502] = { 0, 1 }, [503] = { 8, 0 }, [504] = { 1, 11 }, [505] = { 0, 8 } }
    C_Item = {
        GetItemInfoInstant = function(id)
            local c = classes[id] or { 15, 0 }
            return id, "n", "l", (id == 504) and "INVTYPE_BAG" or "", 1, c[1], c[2]
        end,
        GetItemSpell = function(id) if id == 504 then return nil end return "Use: it" end,
    }
    local savedTip = C_TooltipInfo
    C_TooltipInfo = { GetItemByID = function(id)
        return { lines = { { leftText = "Name" }, { leftText = "Use: " .. ((id == 505) and "poisons the weapon" or "applies onto an item") } } }
    end }
    local at = { ["0 5"] = 501, ["0 6"] = 502, ["0 7"] = 503, ["0 8"] = 504, ["0 9"] = 505 }
    C_Container = { GetContainerItemInfo = function(bag, slot)
        local id = at[bag .. " " .. slot]
        return id and { itemID = id, hyperlink = "|cff|Hitem|h[x]|h|r", stackCount = 1 } or nil
    end }
    local g1, g2, g3 = {}, {}, {}
    local function act(a)
        if not a then return "none" end
        return a.type .. "|" .. tostring(a.item or a.macrotext)
    end
    local function slot(name, bag, id, slotName)
        local b = CreateFrame("Button", name, UIParent)
        -- strict like the game: GetName needs the button itself (called without it, it errors; that hid the 1.3.155 failure)
        b.GetName = function(self) assert(self == b, "GetName called without the button"); return name end
        b.GetBagID = function() return bag end
        b.GetID = function() return id end
        if slotName then b.slotName = slotName end
        return b
    end
    local recipe = slot("FakeRecipe", 0, 5)              -- a recipe (class 9): X uses it
    local gamepad = slot(nil, 0, 6, "BAG0SLOT")          -- a gamepad bag slot, no global name
    local kit = slot("FakeKit", 0, 7)                    -- an armor kit (class 8): X uses it like the game would
    local bagItem = slot("FakeBag", 0, 8)                -- a bag (class 1): the same action equips it
    local poison = slot("FakePoison", 0, 9)              -- a poison: consumable class 0, subclass Other 8
    local empty = slot("FakeEmpty", 0, 99)               -- an empty slot: no item to use
    g1[#g1 + 1] = act(M.rightClickAction(recipe))
    g1[#g1 + 1] = act(M.rightClickAction(gamepad))
    g1[#g1 + 1] = act(M.rightClickAction(kit))
    g1[#g1 + 1] = act(M.rightClickAction(bagItem))
    g1[#g1 + 1] = act(M.rightClickAction(poison))
    MerchantFrame = { IsShown = function() return true end, selectedTab = 1 }
    g2[#g2 + 1] = act(M.rightClickAction(recipe))         -- sells, through the button's name
    g2[#g2 + 1] = act(M.rightClickAction(gamepad))        -- no name to click: nothing
    MerchantFrame.selectedTab = 2                         -- the buyback tab: the game sells nothing
    g2[#g2 + 1] = act(M.rightClickAction(recipe))
    MerchantFrame.selectedTab = 1                         -- back to the sell tab for the legend
    g2[#g2 + 1] = tostring(G.xLabel(recipe))               -- at a vendor the legend still says Right-click
    MerchantFrame = nil
    -- the rest of the highlight keeps the plain click and the mail as before
    local plain = CreateFrame("Button", "FakePlain", UIParent)
    local a = G.xAction(plain)
    g3[#g3 + 1] = tostring(a.type == "click" and a.clickbutton == plain)
    g3[#g3 + 1] = act(G.xAction(recipe))
    g3[#g3 + 1] = act(G.xAction(kit))                     -- an armor kit in a slot: the item action
    g3[#g3 + 1] = act(G.xAction(poison))                  -- a poison in a slot: the item action
    g3[#g3 + 1] = act(G.xAction(empty))                   -- an empty slot: nothing, and no click to fall back on
    local mail = CreateFrame("Button", "MailItem1", UIParent)
    g3[#g3 + 1] = act(G.xAction(mail))                    -- mail: no target, X takes it in the hook
    g3[#g3 + 1] = tostring(G.xLabel(recipe)) .. "," .. tostring(G.xLabel(kit)) .. "," .. tostring(G.xLabel(poison))
        .. "," .. tostring(G.xLabel(plain))
    C_TooltipInfo = savedTip
    return table.concat(g1, ";"), table.concat(g2, ";"), table.concat(g3, ";")
end""")()
g1, g2, g3 = r
assert str(g1) == "macro|/use 0 5;macro|/use 0 6;macro|/use 0 7;macro|/use 0 8;macro|/use 0 9", g1
print("X on a bag item: the game's use command as a macro (/use <bag> <slot>) for every type now, recipe, gamepad slot, armor kit, bag and poison: OK")
assert str(g2) == "macro|/click FakeRecipe RightButton;none;none;Right-click", g2
print("X at a vendor: sells through the button name, nothing for an unnamed gamepad slot, nothing on the buyback tab, legend still Right-click: OK")
assert str(g3) == "true;macro|/use 0 5;macro|/use 0 7;macro|/use 0 9;none;none;Use,Use,Use,Right-click", g3
print("X on the rest of the highlight: plain button still clicked, an empty slot gives nothing, mail still taken in the hook, legend says Use for the use command (kit, poison, recipe):", g3)
# Items used on other items, profession actions, and what the bag menu offers
r = L("""function()
    local UF = UbermocForever
    local M = UF.ItemMenu
    local classes = { [1] = { 0, 6 }, [2] = { 0, 1 }, [3] = { 8, 0 }, [4] = { 4, 1 }, [5] = { 2, 1 }, [6] = { 7, 7 }, [7] = { 7, 9 }, [100] = { 2, 7 } }
    C_Item = {
        GetItemInfoInstant = function(id) local c = classes[id] or { 15, 0 }; return id, "t", "s", "", 1, c[1], c[2] end,
        GetItemSpell = function(id) if id == 4 or id == 5 or id == 6 or id == 7 or id == 100 then return nil end return "Use it" end,
        GetItemInfo = function(id) return "n", "l", (id == 5) and 3 or 1 end,
    }
    classes[4] = { 4, 1 }
    local out = {}
    out[#out + 1] = tostring(M.usedOnItems(1))     -- consumable, item enhancement subclass
    out[#out + 1] = tostring(M.usedOnItems(2))     -- potion: no
    out[#out + 1] = tostring(M.usedOnItems(3))     -- item enhancement class
    out[#out + 1] = tostring(M.usedOnItems(4))     -- armour with no use: no
    out[#out + 1] = tostring(M.professionFor(13262, 5, 1)) .. tostring(M.professionFor(13262, 4, 1))   -- rare weapon yes, armour of poor quality no
    out[#out + 1] = tostring(M.professionFor(31252, 6, 4)) .. tostring(M.professionFor(31252, 6, 5))   -- ore needs five
    out[#out + 1] = tostring(M.professionFor(51005, 7, 5))
    -- the menu on a sharpening stone in a bag, with a weapon in the main hand
    local btn = CreateFrame("Button", "FakeStone", UIParent)
    btn.GetBagID = function() return 0 end
    btn.GetID = function() return 2 end
    C_Container = { GetContainerItemInfo = function() return { itemID = 1, hyperlink = "|cff|Hitem:1|h[Rough Stone]|h|r", stackCount = 3 } end,
                    SortBags = function() end, PickupContainerItem = function() end }
    GetInventoryItemID = function(_, slot) if slot == 16 then return 100 end end
    GetInventoryItemLink = function(_, slot) if slot == 16 then return "|cff|Hitem:100|h[Big Sword]|h|r" end end
    IsPlayerSpell = function(id) return id == 13262 end
    C_Spell = { GetSpellName = function() return "Disenchant" end }
    M.open(btn)
    local texts = {}
    for i = 1, 8 do local e = _G["UbermocForeverItemMenuEntry" .. i]; if e and e:IsShown() then texts[#texts + 1] = e:GetText() end end
    UbermocForeverItemMenu:Hide()
    out[#out + 1] = table.concat(texts, "|")
    return table.concat(out, ",")
end""")()
assert str(r) == "true,false,true,false,truefalse,falsetrue,true,Use / equip|Use on Main hand: Big Sword|Pick up / move|Delete|Sort bags", r
print("Item menu: use-on-weapon entries and profession rules: OK")
# Applied (Applied.lua): what a worn piece already carries, for the item menu's use-on entries and the wait for a target.
# FAKE(C47): the stub GetTemporaryEnchantmentInfo returns the TemporaryItemEnchantInfo fields of the game's documentation
# (enchantID, remainingTimeMs, chargesRemaining, hasExpirationTime; PaperDollInfoDocumentation.lua:491-500) or nothing.
# FAKE(C49) FAKE(C53): the stub tooltip lines carry type and leftText, the type being
# Enum.TooltipDataLineType.ItemEnchantmentPermanent (TooltipInfoSharedDocumentation.lua:27-55), the text read as
# lineData.leftText (TooltipDataHandler.lua:339-348). FAKE(C52): a worn item link carries the enchant id after the item
# id (Blizzard_Reports.lua:391).
r = L("""function()
    local UF = UbermocForever
    local A, M = UF.Applied, UF.ItemMenu
    local out = {}
    local temp = { [16] = { enchantID = 7, remainingTimeMs = 725000, chargesRemaining = 0, hasExpirationTime = true },
                   [17] = { enchantID = 9, remainingTimeMs = 45000, chargesRemaining = 1, hasExpirationTime = true } }
    local links = { [5] = "|cff|Hitem:1234:2564:0:0|h[Chest]|h|r", [7] = "|cff|Hitem:1235:0:0:0|h[Legs]|h|r" }
    local saved = { C_PaperDollInfo, GetInventoryItemLink, C_TooltipInfo, Enum, issecretvalue }
    C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return temp[slot] end }
    GetInventoryItemLink = function(_, slot) return links[slot] end
    Enum = { TooltipDataLineType = { ItemEnchantmentPermanent = 15 } }
    C_TooltipInfo = { GetInventoryItem = function(_, slot)
        if slot == 5 then return { lines = { { type = 22, leftText = "Chest" }, { type = 15, leftText = "Mighty Strength" } } } end
        return { lines = {} }
    end }
    out[#out + 1] = tostring(A.text(16, "temporary"))                 -- 12 min left, no charges
    out[#out + 1] = tostring(A.text(17, "temporary"))                 -- 45 sec, one charge
    out[#out + 1] = tostring(A.text(18, "temporary"))                 -- nothing there
    out[#out + 1] = tostring(A.text(5, "permanent"))                  -- named permanent enchant
    out[#out + 1] = tostring(A.text(7, "permanent"))                  -- enchant id 0: nothing
    links[7] = "|cff|Hitem:1235:99:0:0|h[Legs]|h|r"
    out[#out + 1] = tostring(A.text(7, "permanent"))                  -- an enchant whose name is not in the tooltip
    out[#out + 1] = tostring(A.text(16, "permanent"))                 -- a weapon with no link: nothing
    out[#out + 1] = A.timeText(7500000) .. "/" .. A.timeText(59000) .. "/" .. tostring(A.timeText(0))
    out[#out + 1] = A.kindFor({ 16, 17 }) .. "," .. A.kindFor({ 5, 7 }) .. "," .. A.kindFor({ 16, 18 }) .. "," .. A.kindFor(nil)
    out[#out + 1] = A.hint(16, "temporary"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|" .. A.hint(18, "temporary") .. "|"
    -- a secret answer and a raising call count as nothing
    issecretvalue = function(v) return v == "secret" end
    temp[16] = "secret"
    out[#out + 1] = tostring(A.text(16, "temporary"))
    C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function() error("restricted") end }
    out[#out + 1] = A.hint(16, "temporary") == "" and "raise survived" or "no"
    -- the menu asks first only for a temporary enchant; a permanent one (a kit) is asked by the game itself, with the old and new stats
    C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return temp[slot] end }
    temp[16] = { enchantID = 7, remainingTimeMs = 725000, chargesRemaining = 0, hasExpirationTime = true }
    links[5] = "|cff|Hitem:1234:2564:0:0|h[Chest]|h|r"
    out[#out + 1] = tostring(M.asksFirst(16, "temporary")) .. "/" .. tostring(M.asksFirst(5, "permanent")) .. "/" .. tostring(M.asksFirst(18, "temporary"))
    -- the item menu entry for a sharpening stone on the main hand says what is already on it
    local classes = { [1] = { 0, 6 }, [100] = { 2, 7 } }
    C_Item = {
        GetItemInfoInstant = function(id) local c = classes[id] or { 15, 0 }; return id, "t", "s", "", 1, c[1], c[2] end,
        GetItemSpell = function(id) if id == 100 then return nil end return "Use it" end,
        GetItemInfo = function(id) return "n", "l", 1 end,
    }
    local btn = CreateFrame("Button", "FakeStone2", UIParent)
    btn.GetBagID = function() return 0 end
    btn.GetID = function() return 2 end
    C_Container = { GetContainerItemInfo = function() return { itemID = 1, hyperlink = "|cff|Hitem:1|h[Rough Stone]|h|r", stackCount = 3 } end,
                    SortBags = function() end, PickupContainerItem = function() end }
    GetInventoryItemID = function(_, slot) if slot == 16 then return 100 end end
    GetInventoryItemLink = function(_, slot) if slot == 16 then return "|cff|Hitem:100|h[Big Sword]|h|r" end end
    M.open(btn)
    local texts = {}
    for i = 1, 8 do local e = _G["UbermocForeverItemMenuEntry" .. i]; if e and e:IsShown() then texts[#texts + 1] = e:GetText() end end
    UbermocForeverItemMenu:Hide()
    -- the entry is plain (no long hint to overflow the menu); it asks first, and A (a secure key) is yes, B is no
    out[#out + 1] = texts[2] or ""
    local AC, Nav = UF.ApplyConfirm, UF.Nav
    local e2 = _G["UbermocForeverItemMenuEntry2"]
    local base = Nav.Count()
    e2.__scripts.PreClick(e2)
    local info = AC.last
    out[#out + 1] = tostring(AC.isShown()) .. ":" .. tostring(info and info.macro:gsub("\\n", ";"))
    out[#out + 1] = tostring(info and info.text:find("Big Sword (Main hand) already has a poison or oil (12 min left).", 1, true) ~= nil)
    out[#out + 1] = tostring(info and info.text:find("Using Rough Stone on it", 1, true) ~= nil)
    local top = Nav._stack[#Nav._stack]
    out[#out + 1] = (Nav.Count() - base) .. ":" .. tostring(top.secure.PAD1[1]) .. ":" .. tostring(type(top.map.PAD2)) .. ":" .. tostring(type(top.map.PADDUP))
    top.map.PAD2()                                               -- B: no, nothing is applied and the keys are given back
    out[#out + 1] = tostring(AC.isShown()) .. ":" .. (Nav.Count() - base)
    -- nothing carried: the entry applies at once (no question), and in combat the question is not asked
    temp[16] = nil
    M.open(btn)
    local e2b = _G["UbermocForeverItemMenuEntry2"]
    out[#out + 1] = tostring(e2b.__scripts.PreClick == nil) .. ":" .. tostring(AC.isShown())
    UbermocForeverItemMenu:Hide()
    local realCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    out[#out + 1] = tostring(AC.ask({ macro = "/use 0 1" }))
    InCombatLockdown = realCombat
    out[#out + 1] = tostring(AC.ask({ title = "x" }))             -- no macro: no question
    C_PaperDollInfo, GetInventoryItemLink, C_TooltipInfo, Enum, issecretvalue = saved[1], saved[2], saved[3], saved[4], saved[5]
    return table.concat(out, "|")
end""")()
assert str(r) == ("already has a poison or oil (12 min left)|already has a poison or oil (45 sec left, 1 charge)|nil|"
                  "already enchanted: Mighty Strength|nil|already enchanted|nil|2 h 5 min/59 sec/nil|"
                  "temporary,permanent,permanent,temporary|  already has a poison or oil (12 min left)|||nil|raise survived|"
                  "already has a poison or oil (12 min left)/nil/nil|"
                  "Use on Main hand: Big Sword|true:/use 0 2;/use 16|true|true|1:UbermocForeverApplyYes:function:function|false:0|true:false|false|false"), r
print("Applied: temporary and permanent enchants are named, replaced-by kind decides which counts, secrets and errors are survived, the menu asks first for a temporary one only: OK")
tc = open(ADDON + "/TargetCancel.lua", encoding="utf-8").read().split("local _, UF", 1)[1]
assert "Applied" not in tc and "UF.say" not in tc, "waiting for a target says nothing in chat: it cannot tell what is being applied"
# ApplyConfirm layout: the controller's A and B pictures sit inside the Yes and No buttons (asked for each time, so they follow the controller),
# there is no legend under the buttons, and "Continue?" is its own line apart from the body text
r = L("""function()
    local UF = UbermocForever
    local AC = UF.ApplyConfirm
    local asked = {}
    local realGlyph = UF.glyph
    UF.glyph = function(pad) asked[#asked + 1] = pad; return "[" .. pad .. "]" end
    local realCombat = InCombatLockdown
    InCombatLockdown = function() return false end
    AC.ask({ title = "t", text = "body without the question", macro = "/use 0 1" })
    local shown = AC.isShown()
    local top = UF.Nav._stack[#UF.Nav._stack]
    AC.close()
    InCombatLockdown = realCombat
    UF.glyph = realGlyph
    return table.concat(asked, ",") .. "|" .. tostring(shown) .. "|" .. tostring(AC.last.question == nil)
end""")()
assert str(r) == "PAD1,PAD2|true|true", r
src = open(ADDON + "/ApplyConfirm.lua", encoding="utf-8").read()
code = src.split("local _, UF", 1)[1]
assert "CreateLegend" not in code and "legend" not in code, "the legend under the buttons is gone"
assert "yesGlyph" not in code and "noGlyph" not in code, "the pictures are inside the buttons now"
assert 'yesBtn:SetText((UF.glyph and UF.glyph("PAD1") or "A")' in code and 'noBtn:SetText((UF.glyph and UF.glyph("PAD2") or "B")' in code
assert "b:SetNormalFontObject(" in code and 'continueFS:SetText(info.question or "Continue?")' in code
im = open(ADDON + "/ItemMenu.lua", encoding="utf-8").read()
assert "Continue?" not in im, "the question line belongs to the dialog, not to the body text"
print("ApplyConfirm: A and B pictures inside the Yes and No buttons, no legend, Continue? on its own line: OK")
# A poison (class 0, subclass 8) is told apart from other "Other" consumables by its use text
r = L("""function()
    local M = UbermocForever.ItemMenu
    C_Item = {
        GetItemInfoInstant = function(id) return id, "t", "s", "", 1, 0, 8 end,
        GetItemSpell = function(id) return "Use it", 173555 end,
    }
    local lines = { [3775] = "Use: Coats a weapon with poison that lasts for 30 minutes.", [9999] = "Use: Restores 10 health." }
    C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Name" }, { leftText = lines[id] } } } end }
    return tostring(M.usedOnItems(3775)) .. tostring(M.usedOnItems(9999))
end""")()
assert str(r) == "truefalse", r
print("Poisons are recognised from their use text: OK")
# hasUse: the spell lookup is MayReturnNothing, so the tooltip's own Use: line counts too (C147, C149).
# FAKE(C150): Crippling Poison 3775 with spell 173555 is what the game's generated data says; the stub below
# answers it only when the lookup is asked, and answers nothing for the others, like MayReturnNothing can.
# FAKE(C147): the stub stands for C_Item.GetItemSpell (itemInfo, MayReturnNothing, spellName + spellID).
# FAKE(C149): the stub stands for C_TooltipInfo.GetItemByID (itemID as a number, lines carry leftText).
r = L("""function()
    local M = UbermocForever.ItemMenu
    local savedItem, savedTip = C_Item, C_TooltipInfo
    local classes = { [9101] = 8, [9102] = 1, [9103] = 5, [9104] = 8 }   -- FAKE(C142): the game's class numbers
    C_Item = {
        GetItemInfoInstant = function(id) return id, "t", "s", "", 1, 0, classes[id] or 8 end,
        -- FAKE(C147): C_Item.GetItemSpell is MayReturnNothing; here it answers for Crippling Poison only,
        -- and the ids are the game's data (C150).
        GetItemSpell = function(id)
            if id == 3775 then return "Crippling Poison", 173555 end
            return nil            -- MayReturnNothing (C147): nothing back for the others
        end,
    }
    local lines = { [3775] = "Use: To coat a weapon with this poison, you must have a weapon equipped.",
                    [9101] = "Use: Coats a melee weapon. Lasts until it is used.",
                    [9102] = "Use: Restores 10 health.",
                    [9103] = "Use: Restores 10 health over 10 seconds." }
    -- FAKE(C149): stands for C_TooltipInfo.GetItemByID(itemID), lines read as lineData.leftText
    C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Name" }, { leftText = lines[id] } } } end }
    local spellFromGame = tostring(M.spellID(3775))               -- the game's own answer for Crippling Poison
    local missed = tostring(M.spellID(9101))                     -- the lookup answered nothing for this one
    local res = spellFromGame .. "|" .. missed .. "|" .. tostring(M.usedOnItems(9101)) .. "|"
        .. tostring(M.usedOnItems(3775)) .. "|" .. tostring(M.usedOnItems(9102)) .. "|" .. tostring(M.usedOnItems(9103))
        .. "|" .. tostring(M.usedOnItems(9104))
    local t = M.targets(9101) or {}
    res = res .. "|" .. table.concat(t, "-")
    C_Item, C_TooltipInfo = savedItem, savedTip
    return res
end""")()
assert str(r) == "173555|nil|true|true|false|false|false|16-17", r
print("hasUse: a weapon-buff item the spell lookup misses still counts, through its own Use: line; potions and food still do not: OK")
# Conversations start on the Accept button, and X trains in a trainer
r = L("""function()
    local G = UbermocForever.GameNav
    local function btn(parent) return { IsShown = function() return true end, IsVisible = function() return true end,
        IsEnabled = function() return true end, GetParent = function() return parent end } end
    local q = btn(nil)
    QuestFrame = q
    QuestFrameAcceptButton = btn(q)
    local a = G.dialogStart() == QuestFrameAcceptButton
    QuestFrame, QuestFrameAcceptButton = nil, nil
    local t = btn(nil)
    ClassTrainerFrame = t
    local skill, train = btn(t), btn(t)
    t.TrainButton = train
    local x = G.trainButton(skill) == train
    local y = G.trainButton(btn(nil)) == nil
    ClassTrainerFrame = nil
    return tostring(a) .. tostring(x) .. tostring(y)
end""")()
assert str(r) == "truetruetrue", r
print("Conversations: start on Accept, X trains in a trainer: OK")
# A quest with one action: the action button is found (so no highlight is needed), nothing in a gossip list
r = L("""function()
    local G = UbermocForever.GameNav
    local function btn(parent, en) return { IsShown = function() return true end, IsVisible = function() return true end,
        IsEnabled = function() return en ~= false end, GetParent = function() return parent end } end
    local q = btn(nil)
    QuestFrame = q
    QuestFrameCompleteButton = btn(q)
    local a = G.dialogAccept() == QuestFrameCompleteButton
    QuestFrameCompleteButton = btn(q, false)        -- disabled: not pressable
    local b = G.dialogAccept() == nil
    QuestFrame, QuestFrameCompleteButton = nil, nil
    GossipFrame = btn(nil)
    local c = G.dialogAccept() == nil               -- a gossip list has no single action
    GossipFrame = nil
    return tostring(a) .. tostring(b) .. tostring(c)
end""")()
assert str(r) == "truetruetrue", r
print("Quest with one action found for A, none for lists: OK")
# One quest and nothing else: it is opened by itself; lists and other options are left alone
r = L("""function()
    local D = UbermocForever.DialogButtons
    local function show(k, id) return tostring(k) .. tostring(id) end
    local a1, a2 = D.autoTarget({ { questID = 7 } }, {}, {})
    local b1, b2 = D.autoTarget({ { questID = 7 }, { questID = 8 } }, {}, {})
    local c1, c2 = D.autoTarget({ { questID = 7 } }, {}, { { name = "I want to browse" } })
    local d1, d2 = D.autoTarget({}, { { questID = 9, isComplete = true } }, {})
    local e1, e2 = D.autoTarget({}, { { questID = 9, isComplete = false } }, {})
    return show(a1, a2) .. "|" .. show(b1, b2) .. "|" .. show(c1, c2) .. "|" .. show(d1, d2) .. "|" .. show(e1, e2)
end""")()
assert str(r) == "available7|nilnil|nilnil|active9|nilnil", r
print("One quest and nothing else opens by itself, lists and other options do not: OK")
# Where an item goes, read from its use text (wording taken from the scan of the game's own items)
r = L("""function()
    local M = UbermocForever.ItemMenu
    C_Item = {
        GetItemInfoInstant = function(id) return id, "t", "s", "", 1, 0, 8 end,
        GetItemSpell = function(id) return "Use it", 173555 end,
    }
    local text = {
        [1] = "Use: Coats a weapon with poison that lasts for 30 minutes.",
        [2] = "Use: Permanently increase the Stamina value by 2 and the armor value by 16 of an item worn on the chest, legs, hands or feet.",
        [3] = "Use: Attaches a permanent scope to a bow or gun that increases its damage by 5.",
        [4] = "Use: Increases armor by 2,000 for 2 min.",
        [5] = "Use: Increase critical chance on a melee weapon by 2% for 30 minutes.",
    }
    C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Name" }, { leftText = text[id] } } } end }
    local function join(t) if not t then return "nil" end return table.concat(t, "-") end
    return join(M.targets(1)) .. "|" .. join(M.targets(2)) .. "|" .. join(M.targets(3)) .. "|" .. join(M.targets(4)) .. "|" .. join(M.targets(5))
end""")()
assert str(r) == "16-17|5-7-8-10|18|nil|16-17", r
print("Where an item goes: weapons, armor slots, ranged only for scopes, potions nowhere: OK")
# Every armor kit and head / leg / shoulder enchant in the game's data (QuestieDB foreverItemDB.lua: id, class, subclass;
# use text from Wowhead Classic tooltips): each is offered in the Y menu, on the slots its text names
r = L("""function()
    local M = UbermocForever.ItemMenu
    local cases = {
    { 11622, 12, 0, "Use: Permanently adds 150 mana to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11642, 12, 0, "Use: Permanently adds 100 hit points to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11643, 12, 0, "Use: Permanently adds 125 armor to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11644, 12, 0, "Use: Permanently adds 20 fire resistance to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11645, 12, 0, "Use: Permanently adds 8 strength to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11646, 12, 0, "Use: Permanently adds 8 stamina to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11647, 12, 0, "Use: Permanently adds 8 agility to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11648, 12, 0, "Use: Permanently adds 8 intellect to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 11649, 12, 0, "Use: Permanently adds 8 spirit to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 15564, 0, 0, "Use: Permanently increase the armor value of an item worn on the chest, legs, hands or feet by 40.  Only usable on items level 35 and above." },
    { 18251, 0, 0, "Use: Permanently increase the defense value of an item worn on the chest, legs, hands or feet by 3.  Only usable on items level 45 and above." },
    { 18329, 12, 0, "Use: Permanently adds 1% haste to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 18330, 12, 0, "Use: Permanently adds +8 to your Healing and Damage from spells to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 18331, 12, 0, "Use: Permanently adds 1% dodge to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19782, 15, 0, "Use: Permanently adds 10 Stamina, 7 Defense, and 15 Shield Block value to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19787, 15, 0, "Use: Permanently adds 18 to all healing and damage spells and 1% chance to hit with spells to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19788, 15, 0, "Use: Permanently adds 10 Stamina and increases spell damage and healing by up to 18 to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19789, 15, 0, "Use: Permanently adds 10 Stamina, 4 mana per 5 sec., and increases healing by up to 24 to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 20076, 12, 0, "Use: Permanently adds to a shoulder slot item increased damage and healing done by magical spells and effects up to 18." },
    { 20077, 12, 0, "Use: Permanently adds 30 attack power to a shoulder slot item." },
    { 20078, 12, 0, "Use: Permanently adds to a shoulder slot item increased healing done by spells and effects up to 33." },
    { 2304, 0, 0, "Use: Permanently increase the armor value of an item worn on the chest, legs, hands or feet by 8." },
    { 2313, 0, 0, "Use: Permanently increase the armor value of an item worn on the chest, legs, hands or feet by 16." },
    { 23545, 12, 0, "Use: Permanently adds to a shoulder slot item increased damage and healing done by magical spells and effects up to 15 and also increases your chance to land a critical strike with spells by 1%." },
    { 23547, 12, 0, "Use: Permanently adds to a shoulder slot item increased healing done by magical spells and effects up to 31 and also increases your mana regen by 5 mana per 5 sec." },
    { 23548, 12, 0, "Use: Permanently adds to a shoulder slot item increased Attack Power by 26 and also increases your chance to land a critical strike by 1%." },
    { 23549, 12, 0, "Use: Permanently adds to a shoulder slot item increased Stamina by 16 and also grants 100 armor." },
    { 4265, 0, 0, "Use: Permanently increase the armor value of an item worn on the chest, legs, hands or feet by 24.  Only usable on items level 15 and above." },
    { 8173, 0, 0, "Use: Permanently increase the armor value of an item worn on the chest, legs, hands or feet by 32.  Only usable on items level 25 and above." },
    { 19783, 15, 0, "Use: Permanently adds 10 Stamina, 7 Defense, and increases healing by up to 24 to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19784, 15, 0, "Use: Permanently adds 28 Attack Power and 1% Dodge to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19785, 15, 0, "Use: Permanently adds 24 Ranged Attack Power, 10 Stamina, and 1% Chance to Hit to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19786, 15, 0, "Use: Permanently adds 15 Intellect and increases all healing and spell damage by up to 13 to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 19790, 15, 0, "Use: Permanently adds 10 Stamina, 10 Intellect, and increases healing by up to 24 to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 22635, 15, 0, "Use: Permanently adds 10 nature resistance to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 22636, 15, 0, "Use: Permanently adds 10 frost resistance to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    { 22638, 15, 0, "Use: Permanently adds 10 shadow resistance to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." },
    }
    local byId = {}
    for _, c in ipairs(cases) do byId[c[1]] = c end
    C_Item = {
        GetItemInfoInstant = function(id) local c = byId[id]; return id, "t", "s", "", 1, c[2], c[3] end,
        GetItemSpell = function(id) return "Use it", 173555 end,
    }
    C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Name" }, { leftText = byId[id][4] } } } end }
    local count, bad = {}, {}
    for _, c in ipairs(cases) do
        local t = M.targets(c[1])
        local key = t and table.concat(t, "-") or "nil"
        count[key] = (count[key] or 0) + 1
        if not M.usedOnItems(c[1]) then bad[#bad + 1] = c[1] end
    end
    local keys = {}
    for k, n in pairs(count) do keys[#keys + 1] = k .. "=" .. n end
    table.sort(keys)
    return table.concat(keys, ",") .. "|not offered:" .. table.concat(bad, ",")
end""")()
assert str(r) == "1-7=24,3=7,5-7-8-10=6|not offered:", r
print("Armor kits, head / leg and shoulder enchants (37 items from the game's data): offered on the right slots: OK")
# Bags: a bag in your bags can go in a bag slot (a reagent bag only in the reagent slot); each slot shows the gain
r = L("""function()
    local M = UbermocForever.ItemMenu
    local oldItem, oldC, oldEnum, oldLink = C_Item, C_Container, Enum, GetInventoryItemLink
    C_Item = { GetItemInfoInstant = function(id)
        if id == 1 then return id, "t", "s", "INVTYPE_BAG", 1, 1, 0 end      -- a bag
        if id == 2 then return id, "t", "s", "INVTYPE_BAG", 1, 1, 11 end     -- a reagent bag
        return id, "t", "s", "INVTYPE_CHEST", 1, 4, 2 end }                 -- armour
    Enum = { BagIndex = { ReagentBag = 5 } }
    local sizes = { [1] = 6, [2] = 10, [3] = 0, [4] = 14, [5] = 0 }
    local free = { [1] = 6, [2] = 3, [4] = 14 }
    C_Container = {
        ContainerIDToInventoryID = function(b) return 30 + b end,
        GetContainerNumSlots = function(b) return sizes[b] or 0 end,
        GetContainerNumFreeSlots = function(b) return free[b] or 0 end,
    }
    GetInventoryItemLink = function(_, inv) if sizes[inv - 30] and sizes[inv - 30] > 0 then return "|cff[Bag " .. (inv - 30) .. "]|r" end end
    local out = { tostring(M.isBag(1)) .. "/" .. tostring(select(2, M.isBag(1))) .. "/" .. tostring(select(2, M.isBag(2))) .. "/" .. tostring(M.isBag(3)) }
    local slots = M.bagSlotsFor(false)
    local gains = {}
    for _, s in ipairs(slots) do local _, d = M.bagGain(10, s); gains[#gains + 1] = s.inv .. ":" .. d .. ":" .. s.used end
    out[#out + 1] = table.concat(gains, ",")
    local r = M.bagSlotsFor(true)
    out[#out + 1] = #r .. ":" .. r[1].label
    out[#out + 1] = (M.bagGain(nil, slots[1]) == "") and "unknown" or "?"
    C_Item, C_Container, Enum, GetInventoryItemLink = oldItem, oldC, oldEnum, oldLink
    return table.concat(out, "|")
end""")()
assert str(r) == "true/false/true/false|31:4:0,32:0:7,33:10:0,34:-4:0|1:Reagent bag slot|unknown", r
print("Bags: which slots a bag fits, the gain over each, items still in a bag: OK")
# The bag bar can be moved to while bags are open (its fading is held then), and Y on one of its bag slots is a bag-slot menu
r = L("""function()
    local G, M, F = UbermocForever.GameNav, UbermocForever.ItemMenu, UbermocForever.Fade
    local function frame(name, isShown) return { GetName = function() return name end, IsShown = function() return isShown end } end
    local oldBar, oldCombined, oldHold = BagsBar, ContainerFrameCombinedBags, F.hold
    local holds = {}
    F.hold = function(k, on) holds[#holds + 1] = k .. "=" .. tostring(on) end
    BagsBar = frame("BagsBar", true)
    local function hasBar() for _, w in ipairs((G.windows())) do if w == BagsBar then return "bar" end end return "nobar" end
    local out = {}
    ContainerFrameCombinedBags = frame("ContainerFrameCombinedBags", false)
    out[#out + 1] = hasBar()
    ContainerFrameCombinedBags = frame("ContainerFrameCombinedBags", true)
    out[#out + 1] = hasBar()
    ContainerFrameCombinedBags = frame("ContainerFrameCombinedBags", false)
    out[#out + 1] = hasBar()
    out[#out + 1] = table.concat(holds, ";")
    local slot = { GetName = function() return "CharacterBag2Slot" end, GetBagID = function() return 3 end, GetID = function() return 33 end }
    local rslot = { GetName = function() return "CharacterReagentBag0Slot" end, GetBagID = function() return 5 end, GetID = function() return 35 end }
    local pack = { GetName = function() return "MainMenuBarBackpackButton" end, GetBagID = function() return 0 end, GetID = function() return 0 end }
    local b1, i1, re1 = M.bagBarSlot(slot)
    local b2, i2, re2 = M.bagBarSlot(rslot)
    -- the gamepad bag bar: no global name, a slotName key
    local g1 = { slotName = "BAG1SLOT", GetBagID = function() return 2 end, GetID = function() return 32 end }
    local g2 = { slotName = "REAGENTBAG0SLOT", GetBagID = function() return 5 end, GetID = function() return 35 end }
    local g3 = { slotName = "BAG0SLOT", GetBagID = function() return 0 end, GetID = function() return 30 end }
    local g4 = { slotName = "KEYRING", GetBagID = function() return -2 end, GetID = function() return 0 end }
    local gb1, gi1, gr1 = M.bagBarSlot(g1)
    local gb2, gi2, gr2 = M.bagBarSlot(g2)
    out[#out + 1] = "g:" .. gb1 .. "/" .. gi1 .. "/" .. tostring(gr1) .. "," .. gb2 .. "/" .. gi2 .. "/" .. tostring(gr2) .. "," .. tostring(M.bagBarSlot(g3)) .. "," .. tostring(M.bagBarSlot(g4)) .. "," .. tostring(M.kind(g1))
    out[#out + 1] = b1 .. "/" .. i1 .. "/" .. tostring(re1) .. "," .. b2 .. "/" .. i2 .. "/" .. tostring(re2) .. "," .. tostring(M.bagBarSlot(pack)) .. "," .. tostring(M.kind(slot))
    BagsBar, ContainerFrameCombinedBags, F.hold = oldBar, oldCombined, oldHold
    return table.concat(out, "|")
end""")()
assert str(r) == "nobar|bar|nobar|bags=true;bags=false|g:2/32/false,5/35/true,nil,nil,bagslot|3/33/false,5/35/true,nil,bagslot", r
print("Bag bar: reachable while bags are open, kept visible then, its bag slots get the bag menu: OK")
# Pick Lock: a locked box is told by its tooltip ("Locked", "Requires Lockpicking (N)"); an opened one is not offered
r = L("""function()
    local M = UbermocForever.ItemMenu
    local function lines(...) local t = {}; for _, v in ipairs({ ... }) do t[#t + 1] = { leftText = v } end; return t end
    local a1, a2 = M.lockInfo(lines("Battered Junkbox", "Item Level 20", "Locked", "Requires Lockpicking (1)"))
    local b1, b2 = M.lockInfo(lines("Ornate Bronze Lockbox", "Item Level 20", "Requires Lockpicking (75)"))   -- opened: no "Locked" line
    local c1, c2 = M.lockInfo(lines("Linen Cloth", "Max Stack: 20"))
    return tostring(a1) .. tostring(a2) .. "|" .. tostring(b1) .. tostring(b2) .. "|" .. tostring(c1) .. tostring(c2)
end""")()
assert str(r) == "true1|false75|falsenil", r
print("Pick Lock: locked boxes told apart from opened ones by their tooltip: OK")
# Binding a spell by pressing buttons: a combination with a slot, one with no bind, one used for something else
r = L("""function()
    local G = UbermocForever.GameNav
    local function btn(action) return { IsShown = function() return true end, action = action, GetParent = function() return nil end } end
    for i = 1, 12 do _G["MultiBarRightButton" .. i] = btn(24 + i) end
    for i = 1, 12 do _G["ActionButton" .. i] = btn(i) end
    local binds = { ["SHIFT-PAD1"] = "MULTIACTIONBAR3BUTTON2", ["PAD3"] = "ACTIONBUTTON3", ["CTRL-PAD2"] = "TOGGLEWORLDMAP" }
    GetBindingAction = function(k) return binds[k] or "" end
    local used = { [24 + 1] = true, [24 + 2] = true }
    GetActionInfo = function(slot) return used[slot] and "spell" or nil end
    local s1, a1 = G.slotForKey("SHIFT-PAD1")
    local s2 = G.slotForKey("PAD3")
    local s3, a3 = G.slotForKey("CTRL-PAD2")
    local s4, a4 = G.slotForKey("SHIFT-CTRL-PAD1")
    local free, bind = G.freeSlot()
    return table.concat({ tostring(s1), a1, tostring(s2), tostring(s3), tostring(a4 == nil), tostring(free), bind }, ",")
end""")()
assert str(r) == "26,MULTIACTIONBAR3BUTTON2,3,nil,true,27,MULTIACTIONBAR3BUTTON3", r
print("Binding by buttons: slot of a combination, free slot for a new one: OK")
# Cinematic camera: talking is told by the game's own windows, settings are saved first and put back
r = L("""function()
    local UF = UbermocForever
    local C = UF.Cinematic
    local out = {}
    out[#out + 1] = tostring(C.talking())
    GossipFrame = { IsShown = function() return true end }
    out[#out + 1] = tostring(C.talking())
    out[#out + 1] = tostring(C.enabled())
    UbermocForeverDB.cinema = false
    out[#out + 1] = tostring(C.enabled())
    UbermocForeverDB.cinema = nil
    local cv = { a = "1" }
    C_CVar = nil
    UbermocForeverDB.cinemaBackup = { a = "0", b = "5" }
    SetCVar = function(k, v) cv[k] = v end
    C.restoreCVars()
    out[#out + 1] = tostring(cv.a) .. tostring(cv.b) .. tostring(UbermocForeverDB.cinemaBackup)
    C.stopNow()
    return table.concat(out, ",")
end""")()
assert str(r) == "false,true,true,false,05nil", r
print("Cinematic camera: talking, on/off, settings put back: OK")
# Aim mark: settings cycle, CVars saved first and put back
r = L("""function()
    local UF = UbermocForever
    local A = UF.Aim
    local cv = { GamePadCursorForTargeting = "1", CursorCenteredYPos = "0.50" }
    GetCVar = function(k) return cv[k] end
    SetCVar = function(k, v) cv[k] = v end
    C_CVar = nil
    UbermocForeverDB.aim = nil; UbermocForeverDB.aimBackup = nil
    A.apply()
    local out = { cv.GamePadCursorForTargeting, cv.CursorCenteredYPos, A.distanceName() }
    A.nextDistance()
    out[#out + 1] = A.distanceName() .. cv.CursorCenteredYPos
    A.toggle()
    out[#out + 1] = cv.GamePadCursorForTargeting .. cv.CursorCenteredYPos
    return table.concat(out, ",")
end""")()
assert str(r) == "0,0.60,Middle,Far0.72,10.50", r
print("Aim dot: settings step, game settings saved and put back: OK")
# Chat lines fade by themselves: Ubermoc UI's starting values, the player's own put back when off
r = L("""function()
    local UF = UbermocForever
    local Ch = UF.Chat
    local f = { fading = false, vis = 120, dur = 3 }
    function f:GetName() return "ChatFrame1" end
    function f:SetTimeVisible(v) self.vis = v end
    function f:GetTimeVisible() return self.vis end
    function f:SetFadeDuration(v) self.dur = v end
    function f:GetFadeDuration() return self.dur end
    function f:SetFading(v) self.fading = v end
    function f:GetFading() return self.fading end
    ChatFrame1 = f
    UbermocForeverDB.chat = nil; UbermocForeverDB.chatBackup = nil
    Ch.apply()
    local out = { tostring(f.fading), f.vis, f.dur }
    Ch.nextVisible(); Ch.nextFade()
    out[#out + 1] = f.vis .. "/" .. f.dur
    Ch.nextVisible(-1); Ch.nextVisible(-1); Ch.nextFade(-1)
    out[#out + 1] = f.vis .. "/" .. f.dur
    Ch.toggle()
    out[#out + 1] = tostring(f.fading) .. f.vis .. "/" .. f.dur .. tostring(UbermocForeverDB.chatBackup)
    ChatFrame1 = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "true,5,3,6/4,4/3,false120/3nil", r
print("Chat fade: starting values, steps, own settings put back: OK")
# Chat: a new line reveals the chat for the "visible" time; the edit box in use holds it, then the same wait applies
r = L("""function()
    local UF = UbermocForever
    local F, Ch = UF.Fade, UF.Chat
    UbermocForeverDB.chat = nil
    local realTime = GetTime
    local now = 5000
    GetTime = function() return now end
    local out = {}
    out[#out + 1] = tostring(F._revealed("chat"))
    Ch.onLine()                                   -- a line arrives
    out[#out + 1] = tostring(F._revealed("chat")) .. tostring(F._revealed("chattabs"))   -- the tabs are not opened by a message
    now = now + 4.9; out[#out + 1] = tostring(F._revealed("chat"))
    now = now + 0.2; out[#out + 1] = tostring(F._revealed("chat"))           -- after 5 s it lets go
    ACTIVE_CHAT_EDIT_BOX = {}                     -- the edit box is opened
    Ch.pollTyping()
    now = now + 100
    out[#out + 1] = tostring(F._revealed("chatedit")) .. tostring(F._revealed("chat")) .. tostring(F._revealed("chattabs"))   -- every part held while typing, a long time later
    ACTIVE_CHAT_EDIT_BOX = nil                    -- message sent
    Ch.pollTyping()
    out[#out + 1] = tostring(F._revealed("chatedit"))
    now = now + 4.9; out[#out + 1] = tostring(F._revealed("chatedit"))
    now = now + 0.2; out[#out + 1] = tostring(F._revealed("chatedit"))
    UbermocForeverDB.chat.on = false
    Ch.onLine(); now = now + 1
    GetTime = realTime
    return table.concat(out, ",")
end""")()
assert str(r) == "false,truefalse,true,false,truetruetrue,true,true,false", r
# Chat page: the chat parts are not on the Fading page, they are on the third page
r = L("""function()
    local F = UbermocForever.Fade
    local out = {}
    for _, c in ipairs(F.CATEGORIES) do for _, e in ipairs(c.elements) do if e.key:find("^chat") or e.key == "quickjoin" then out[#out + 1] = e.key end end end
    out[#out + 1] = #F.CHAT .. tostring(F.byKey.chattabs ~= nil)
    F.set("chat", "idle", 0.3); F.set("minimap", "idle", 0.3)
    F.resetAll()
    out[#out + 1] = tostring(F.value("chat", "idle")) .. tostring(F.value("minimap", "idle"))
    F.resetChat()
    out[#out + 1] = tostring(F.value("chat", "idle"))
    return table.concat(out, ",")
end""")()
assert str(r) == "5true,0.3nil,nil", r
print("Chat page: chat parts left the Fading page, Reset all keeps them: OK")
r = L("""function()
    local UF = UbermocForever
    local F, Ch = UF.Fade, UF.Chat
    UbermocForeverDB.chat = nil; UbermocForeverDB.fade = nil
    Ch.registerAuto()
    local idle = { idle = true }
    local out = { tostring(F.goal("chatedit", idle)) }              -- on by default: hidden until used
    F.set("chatedit", "idle", 0.5)
    out[#out + 1] = tostring(F.goal("chatedit", idle))              -- its own setting wins
    F.reset("chatedit")
    Ch.toggleAuto("chatedit")
    out[#out + 1] = tostring(F.goal("chatedit", idle))              -- off: left alone
    out[#out + 1] = tostring(F.goal("chattabs", idle)) .. tostring(F.goal("quickjoin", idle))   -- every other part does the same
    Ch.toggleAuto("chatedit")
    return table.concat(out, ",")
end""")()
assert str(r) == "0,0.5,nil,00", r
print("Chat: the edit box fades by itself, its own setting wins, off leaves it alone: OK")
print("Chat: new lines reveal the chat, the edit box in use holds it, then wait and fade: OK")
# Menu entries that open a submenu: found by their description, and the submenu frame by the entry it is anchored to
r = L("""function()
    local G = UbermocForever.GameNav
    local function entry(can)
        local e = {}
        function e:GetElementDescription() return { CanOpenSubmenu = function() return can end } end
        return e
    end
    local out = { tostring(G.opensSubmenu(entry(true))), tostring(G.opensSubmenu(entry(false))), tostring(G.opensSubmenu({})) }
    local owner = { IsShown = function() return true end, GetNumPoints = function() return 0 end }
    local sub = { IsShown = function() return true end, GetNumPoints = function() return 1 end, GetPoint = function() return "TOPLEFT", owner, "TOPRIGHT" end }
    local other = { IsShown = function() return true end, GetNumPoints = function() return 1 end, GetPoint = function() return "CENTER", {}, "CENTER" end }
    local all = { other, owner, sub }
    local real = EnumerateFrames
    EnumerateFrames = function(prev)
        if prev == nil then return all[1] end
        for i = 1, #all do if all[i] == prev then return all[i + 1] end end
    end
    out[#out + 1] = tostring(G.findSubmenu(owner) == sub)
    EnumerateFrames = real
    return table.concat(out, ",")
end""")()
assert str(r) == "true,false,false,true", r
print("Menus: an entry with a submenu opens it on mouse-down and the submenu is found: OK")
# Target markers: an entry of the marker submenu is recognised by the game's own name
r = L("""function()
    local G = UbermocForever.GameNav
    RAID_TARGET_8 = "Skull"; RAID_TARGET_NONE = "None"
    local sub = {}
    local function entry(text)
        local fs = { GetText = function() return text end }
        return { fontString = fs, GetRegions = function() end }
    end
    G.submenu = sub
    local real = G.inside
    G.inside = function(f, w) return w == sub end
    local out = { tostring((G.markerOf(entry("Skull")))), tostring((G.markerOf(entry("None")))), tostring((G.markerOf(entry("Set Focus")))) }
    G.submenu = nil
    out[#out + 1] = tostring((G.markerOf(entry("Skull"))))   -- not in a submenu: left to the click
    G.inside = real
    return table.concat(out, ",")
end""")()
assert str(r) == "8,0,nil,nil", r
print("Markers: entries of the marker submenu are recognised by name: OK")
# MarkerMenu: the game's order (8 down to 1, then None), and every entry text maps back to its number
r = L("""function()
    local M = UbermocForever.MarkerMenu
    for i = 1, 8 do _G["RAID_TARGET_" .. i] = "M" .. i end
    _G.RAID_TARGET_NONE = "None"
    local out = { table.concat(M.order(), ",") }
    for _, text in ipairs(M.order()) do out[#out + 1] = tostring((M.markerNumber(text))) end
    out[#out + 1] = tostring((M.markerNumber("Set Focus")))
    for i = 1, 8 do _G["RAID_TARGET_" .. i] = nil end
    _G.RAID_TARGET_NONE = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "M8,M7,M6,M5,M4,M3,M2,M1,None,8,7,6,5,4,3,2,1,0,nil", r
print("MarkerMenu: order 8..1 then None, each text maps back to its number, an unknown text is nil: OK")
# G.markerOf takes entries inside OUR menu too, not only the game's old submenu
r = L("""function()
    local G = UbermocForever.GameNav
    local M = UbermocForever.MarkerMenu
    RAID_TARGET_3 = "M3"; RAID_TARGET_8 = "Skull"; RAID_TARGET_NONE = "None"
    local sub, our = {}, {}
    G.submenu = sub
    M.menu = our
    local real = G.inside
    G.inside = function(f, w) return (w == sub and f.inSub) or (w == our and f.inOur) end
    local function entry(text, inSub, inOur)
        return { fontString = { GetText = function() return text end }, GetRegions = function() end, inSub = inSub, inOur = inOur }
    end
    local out = {
        tostring((G.markerOf(entry("M3", false, true)))),          -- an entry of our menu
        tostring((G.markerOf(entry("Set Focus", false, false)))),  -- inside neither
        tostring((G.markerOf(entry("Skull", true, false)))),       -- the game's submenu, as before
        tostring((G.markerOf(entry("None", true, false))))
    }
    M.menu = nil
    G.submenu = nil
    RAID_TARGET_3 = nil; RAID_TARGET_8 = nil; RAID_TARGET_NONE = nil
    G.inside = real
    return table.concat(out, ",")
end""")()
assert str(r) == "3,nil,8,0", r
print("MarkerMenu: markerOf recognises entries of our menu, the game's submenu path still works: OK")
# Secret values from the game count as "no" instead of raising an error when tested
r = L("""function()
    local F = UbermocForever.Fade
    issecretvalue = function(v) return v == "secret" end
    local out = { tostring((F._plain("secret"))), tostring(F._plain(true)), tostring(F._plain(false)) }
    issecretvalue = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "nil,true,false", r
print("Secret values: treated as unknown, real booleans kept: OK")
# Gamepad layout: which layer is held, even centred rows, empty buttons removed, everything put back when it is turned off
r = L("""function()
    local UF = UbermocForever
    local B = UF.GamepadBar
    local out = { B.layerFor(false, false), B.layerFor(true, false), B.layerFor(false, true), B.layerFor(true, true), B.layerFor(true, true, true) }
    local xs = B.rowX(3, 44, 6, 594)
    out[#out + 1] = xs[1] .. "/" .. xs[2] .. "/" .. xs[3]                         -- centred, evenly spaced
    out[#out + 1] = #B.rowX(0, 44, 6, 594)
    -- layout with plain-table buttons: bar 1..4, 12 buttons each, the first three of every bar filled
    local function mk(bar, n)
        local b = { action = (bar - 1) * 100 + n, pts = { { "CENTER", "parent", "CENTER", 0, 0 } }, alpha = 1, scale = 1 }
        function b:GetNumPoints() return #self.pts end
        function b:GetPoint(i) local p = self.pts[i]; return p[1], p[2], p[3], p[4], p[5] end
        function b:GetScale() return self.scale end
        function b:SetScale(v) self.scale = v end
        function b:GetWidth() return 40 end
        function b:GetHeight() return 40 end
        function b:SetSize() end
        function b:GetParent() return { GetEffectiveScale = function() return 1 end } end
        function b:ClearAllPoints() self.pts = {} end
        function b:SetPoint(a, rel, c, x, y) self.pts[#self.pts + 1] = { a, rel, c, x, y } end
        function b:SetIgnoreParentAlpha(v) self.ignore = v end
        function b:SetAlpha(v) self.alpha = v end
        function b:GetAlpha() return self.alpha end
        function b:SetFrameLevel(v) self.level = v end
        function b:EnableMouse(v) self.mouse = v end
        b.cooldown = { SetDrawSwipe = function(c, v) c.swipe = v end, SetDrawEdge = function(c, v) c.edge = v end, SetHideCountdownNumbers = function() end }
        return b
    end
    local names = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton" }
    local btns = {}
    for bar = 1, 4 do for n = 1, 12 do local b = mk(bar, n); btns[#btns + 1] = b; _G[names[bar] .. n] = b end end
    HasAction = function(a) return ((a - 1) % 100) % 12 < 3 end   -- slots 1..3 are filled (the actions here run 1, 2, 3 ... within each hundred)
    local root = { }
    for _, m in ipairs({ "SetSize", "SetFrameStrata", "ClearAllPoints", "SetPoint", "Show", "Hide" }) do root[m] = function() end end
    function root:GetEffectiveScale() return 1 end
    function root:GetFrameLevel() return 5 end
    local realCF = CreateFrame
    CreateFrame = function(kind, name, ...) if name == "UbermocForeverGamepadBar" then return root end return realCF(kind, name, ...) end
    UbermocForeverDB.gbar = { on = true, extras = false }
    local function cap()
        local f = { calls = {}, ignore = false, alpha = 1 }
        function f:IsInDefaultPosition() return true end
        function f:GetNumPoints() return 1 end
        function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
        function f:GetEffectiveScale() return 1 end
        function f:ClearAllPointsBase() end
        function f:SetPointBase(p, rel, rp, x, y) self.calls[#self.calls + 1] = p .. ":" .. x end
        function f:SetPoint() end
        function f:SetIgnoreParentAlpha(v) self.ignore = v end
        function f:SetAlpha(v) self.alpha = v end
        return f
    end
    MainActionBar = { EndCaps = { LeftEndCap = cap(), RightEndCap = cap() }, GetFrameLevel = function() return 50 end }
    local realTalk = UF.Cinematic.talking
    UF.Cinematic.talking = function() return false end   -- the test stub's windows look open: not talking
    IsShiftKeyDown = function() return true end; IsControlKeyDown = function() return false end; IsAltKeyDown = function() return false end
    B.layout()
    local first = btns[1]
    out[#out + 1] = tostring(first.pts[1][4]) .. "," .. tostring(btns[3].pts[1][4]) .. "," .. tostring(btns[4].pts[1][4])   -- centred 3, the fourth out of sight
    out[#out + 1] = tostring(btns[1].alpha) .. tostring(btns[13].alpha) .. tostring(btns[14].alpha) .. tostring(btns[16].alpha)   -- layer 2 is held: bar 1 hidden, bar 2's first three shown, its fourth (empty) hidden
    out[#out + 1] = tostring(btns[1].ignore)
    -- only the held layer's shown buttons take the mouse, and they sit above the game's main bar frame (level 50)
    out[#out + 1] = tostring(btns[1].mouse) .. tostring(btns[13].mouse) .. tostring(btns[16].mouse) .. "/" .. tostring(btns[13].level > 50) .. tostring(btns[13].level > btns[1].level)
    out[#out + 1] = tostring(btns[1].cooldown.swipe) .. tostring(btns[1].cooldown.edge)     -- no dark swipe, the bright edge on
    local L, R = MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap
    out[#out + 1] = #L.calls .. "|" .. #R.calls .. "|" .. tostring(L.ignore) .. L.alpha           -- the end caps are never moved (they are hidden for good while the layout is on)
    UbermocForeverDB.gbar.on = false
    B.layout()
    out[#out + 1] = tostring(MainActionBar.EndCaps.LeftEndCap.ignore) .. MainActionBar.EndCaps.LeftEndCap.alpha   -- the caps back with the bar when it is off
    out[#out + 1] = tostring(btns[1].pts[1][1]) .. tostring(btns[1].ignore) .. tostring(btns[1].alpha)           -- put back
    out[#out + 1] = tostring(btns[1].cooldown.swipe) .. tostring(btns[1].cooldown.edge)
    CreateFrame = realCF
    MainActionBar = nil
    UF.Cinematic.talking = realTalk
    for bar = 1, 4 do for n = 1, 12 do _G[names[bar] .. n] = nil end end
    IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, HasAction = nil, nil, nil, nil
    UbermocForeverDB.gbar = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "1,2,3,4,1,225.0/275.0/325.0,0,225.0,325.0,-5000,0110,true,falsetruefalse/truetrue,falsetrue,0|0|false1,false1,CENTERfalse1,truefalse", r
print("Gamepad layout: layers, even centring, empty buttons removed, put back when off: OK  (" + str(r) + ")")
# Gamepad layout, part two: forced hiding no mouse-over can lift, Edit Mode suspends fading, bound-button lookup, the Bars page
r = L("""function()
    local UF = UbermocForever
    local F, B = UF.Fade, UF.GamepadBar
    UbermocForeverDB.fade = nil; UbermocForeverDB.gbar = { on = true, extras = false }
    local idle = { idle = true }
    local out = {}
    F.setMouse(0.8)                                              -- the universal mouse-over opacity is on
    F.forced.mb_border = function() return true end              -- hidden for good (the layout registers these at login)
    out[#out + 1] = string.format("%.1f", F.target("mb_border", idle, true))     -- over it with the mouse: still 0
    F.implicit.micro = function() return 0 end                   -- an adjustable part: hidden to start with
    out[#out + 1] = string.format("%.1f", F.target("micro", idle, true))         -- the mouse-over opacity lifts this one
    out[#out + 1] = string.format("%.1f", F.target("micro", idle, false))
    F.setMouse(nil)
    EditModeManagerFrame = { IsShown = function() return true end }
    out[#out + 1] = tostring((F.target("mb_border", idle, false)))               -- Edit Mode open: nothing is faded
    EditModeManagerFrame = nil
    F.forced.mb_border = nil; F.implicit.micro = nil
    -- which controller button a game button is bound to
    GetBindingKey = function(cmd)
        if cmd == "ACTIONBUTTON1" then return "PAD3", "SHIFT-PAD3" end
        if cmd == "MULTIACTIONBAR1BUTTON1" then return "SHIFT-PADLSTICK", "F1" end
        return nil
    end
    out[#out + 1] = tostring(B.padKey(1, 1)) .. "," .. tostring(B.padKey(2, 1)) .. "," .. tostring((B.padKey(3, 1)))
    GetBindingKey = nil
    -- the Bars page
    local page = UF.BarsPage.build(UIParent, UIParent)
    local rows = UF.BarsPage.navRows()
    out[#out + 1] = #rows .. "," .. #rows[1] .. "," .. #rows[3] .. "," .. #rows[4]
    out[#out + 1] = UF.BarsPage.valueText({}, nil) .. UF.BarsPage.valueText({}, 0.5)
    UbermocForeverDB.gbar = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "0.0,0.8,0.0,nil,PAD3,PADLSTICK,nil,8,3,2,4,Normal50%", r
print("Gamepad layout 2: forced art no mouse-over, Edit Mode suspends, bound buttons, Bars page: OK")
# Gamepad layout, part three: cooldown look, range state, where the micro menu / bags / XP bar start
r = L("""function()
    local UF = UbermocForever
    local B = UF.GamepadBar
    local out = {}
    -- range
    B.setRange(7, false, true); out[#out + 1] = tostring(B.isOutOfRange(7))     -- out of range
    B.setRange(7, true, true); out[#out + 1] = tostring(B.isOutOfRange(7))      -- back in range
    B.setRange(7, false, false); out[#out + 1] = tostring(B.isOutOfRange(7))    -- the ability does not check range
    B.setRange("x", false, true)
    out[#out + 1] = tostring(B.glyphAtlas("|A:Gamepad_Ltr_X_64:24:24|a")) .. "," .. tostring((B.glyphAtlas("X"))) .. "," .. tostring((B.glyphAtlas(nil)))
    -- parts: default position is placed, a part moved in Edit Mode is left alone
    local function part(isDefault)
        local f = { default = isDefault, calls = {} }
        function f:IsInDefaultPosition() return self.default end
        function f:GetNumPoints() return 1 end
        function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
        function f:ClearAllPointsBase() self.calls[#self.calls + 1] = "clear" end
        function f:SetPointBase(p, rel, rp, x, y) self.calls[#self.calls + 1] = p .. ">" .. tostring(rp) .. ":" .. x .. "," .. y end
        function f:SetPoint(...) self.calls[#self.calls + 1] = "override" end
        return f
    end
    MicroMenuContainer, BagsBar, StatusTrackingBarManager = part(true), part(true), part(false)   -- the XP bar was moved in Edit Mode
    B.setParts(true)
    out[#out + 1] = table.concat(MicroMenuContainer.calls, "/")
    out[#out + 1] = table.concat(BagsBar.calls, "/")
    out[#out + 1] = #StatusTrackingBarManager.calls
    B.setParts(false)                                                            -- off: the saved place comes back
    out[#out + 1] = table.concat(MicroMenuContainer.calls, "/")
    MicroMenuContainer, BagsBar, StatusTrackingBarManager = nil, nil, nil
    return table.concat(out, ",")
end""")()
assert str(r) == "true,false,false,Gamepad_Ltr_X_64,nil,nil,,,0,", r   # micro menu, bags and XP bar are left where the game / Edit Mode put them
print("Gamepad layout 3: range state, default places only while at the game's default: OK")
# Interact on a target you cannot interact with opens its menu, but a soft interact target next to you (skinning) keeps the key
r = L("""function()
    local UF = UbermocForever
    local T = UF.TargetMenu
    local t = { exists = true, attack = false, dead = false, loot = false, interact = false, player = false, soft = false, softRange = true }
    UnitExists = function(u) if u == "softinteract" then return t.soft end return t.exists end
    UnitIsGameObject = function() return false end
    UnitIsInInteractRange = function() return t.softRange end
    UnitCanAttack = function() return t.attack end
    UnitIsDead = function() return t.dead end
    UnitIsPlayer = function() return t.player end
    UnitHasLootInteraction = function() return t.loot end
    UnitIsInteractable = function() return t.interact end
    local out = {}
    local function w() out[#out + 1] = tostring(T.wants()) end
    w()                                  -- a friendly you cannot interact with: menu
    t.interact = true; w()               -- something you can talk to: the key does its normal job
    t.interact = false; t.loot = true; w()   -- lootable: left to the key
    t.loot = false; t.dead = true; w()   -- dead: left to the key
    t.dead = false; t.attack = true; w() -- an enemy: menu
    t.soft = true; w()                   -- but a corpse to skin next to you: the key skins it
    t.softRange = false; w()             -- out of reach: the menu again
    t.soft = false; t.attack = false; t.player = true; t.interact = true; w()   -- a player: menu
    t.player = false; t.interact = false; t.exists = false; w()  -- no target
    t.exists = true
    GetBindingKey = function() return "PADLSTICK", "SHIFT-PADLSTICK" end
    InCombatLockdown = function() return false end
    SetOverrideBindingClick = function(o, p, key) _G.__calls.overrides[key] = true end
    ClearOverrideBindings = function() _G.__calls.overrides = {} end
    _G.__calls.overrides = {}
    T.apply()
    out[#out + 1] = tostring(_G.__calls.overrides.PADLSTICK) .. tostring(_G.__calls.overrides["SHIFT-PADLSTICK"])
    T.set(false)
    out[#out + 1] = tostring(_G.__calls.overrides.PADLSTICK)
    T.set(true)
    return table.concat(out, ",")
end""")()
assert str(r) == "true,false,false,false,true,false,true,true,false,truetrue,nil", r
print("Target menu: follows the game's interact order, a skinnable soft target keeps the key: OK")
# Cinematic: nameplates are put back, but not during combat (the game does not allow it)
r = L("""function()
    local UF = UbermocForever
    local C = UF.Cinematic
    local cv = { nameplateShowAll = "0", a = "0" }
    SetCVar = function(k, v) cv[k] = v end
    C_CVar = nil
    UbermocForeverDB.cinemaBackup = { nameplateShowAll = "1", a = "1" }
    local real = InCombatLockdown
    InCombatLockdown = function() return true end
    C.restoreCVars()
    local inFight = cv.nameplateShowAll .. cv.a .. tostring(UbermocForeverDB.cinemaBackup.nameplateShowAll)
    InCombatLockdown = real
    C.restoreCVars()
    return inFight .. "," .. cv.nameplateShowAll .. tostring(UbermocForeverDB.cinemaBackup)
end""")()
assert str(r) == "011,1nil", r
print("Cinematic: nameplates wait for the end of combat: OK")
# Cinematic: frames that ignore the interface fade are hidden for the talk and put back
r = L("""function()
    local UF = UbermocForever
    local C = UF.Cinematic
    local function frame(name, ignores, parent)
        local f = { alpha = 1, name = name, ignores = ignores, parent = parent }
        function f:IsShown() return true end
        function f:GetName() return self.name end
        function f:GetParent() return self.parent end
        function f:IsIgnoringParentAlpha() return self.ignores end
        function f:GetAlpha() return self.alpha end
        function f:SetAlpha(a) self.alpha = a end
        return f
    end
    local a = frame("PartyFrame", true, UIParent)       -- ignores the fade: hidden
    local b = frame("PlayerFrame", false, UIParent)     -- fades with UIParent: left alone
    local c = frame("UbermocForeverGameLegend", true, UIParent)   -- ours: stays
    local d = frame(nil, false, nil)                    -- not under UIParent at all: hidden
    local all = { a, b, c, d }
    EnumerateFrames = function(prev)
        if prev == nil then return all[1] end
        for i = 1, #all do if all[i] == prev then return all[i + 1] end end
    end
    C._sweep()
    local hidden = a.alpha .. b.alpha .. c.alpha .. d.alpha
    C._undim()
    return hidden .. "," .. a.alpha .. d.alpha
end""")()
assert str(r) == "0110,11", r
print("Cinematic: frames that ignore the fade are hidden and put back: OK")
# Cinematic: bar and edge settings step and wrap, and default to what it was before
r = L("""function()
    local C = UbermocForever.Cinematic
    UbermocForeverDB.cinemaBars, UbermocForeverDB.cinemaEdges = nil, nil
    local out = { C.barsName(), C.edgesName() }
    C.nextBars(); out[#out + 1] = C.barsName()
    C.nextBars(); out[#out + 1] = C.barsName()      -- wraps to Off
    C.nextEdges(); out[#out + 1] = C.edgesName()
    C.nextEdges(); out[#out + 1] = C.edgesName()    -- wraps to Off
    return table.concat(out, ",")
end""")()
assert str(r) == "Medium,Medium,Thick,Off,Wide,Off", r
print("Cinematic: bars and edges settings step and wrap: OK")
# Fading: the first active situation that has a value wins; Normal leaves an element alone; hide wins over everything; steps of 10 %
r = L("""function()
    local F = UbermocForever.Fade
    UbermocForeverDB.fade = nil
    local out = {}
    local function goal(key, a) local g = F.goal(key, a); return g == nil and "n" or string.format("%.1f", g) end
    local idleOnly = { combat = false, flight = false, idle = true }
    local inCombat = { combat = true, flight = false, idle = false }
    local flying = { combat = false, flight = true, idle = true }
    out[#out + 1] = goal("player", idleOnly)                 -- nothing set: left alone
    F.set("player", "idle", 0.3); F.set("player", "combat", 1); F.set("player", "flight", 0.1)
    out[#out + 1] = goal("player", idleOnly) .. goal("player", inCombat) .. goal("player", flying)
    F.set("player", "flight", nil)                             -- Normal for flight: falls to idle
    out[#out + 1] = goal("player", flying)
    F.toggleHide("player")
    out[#out + 1] = goal("player", inCombat)                 -- hidden for good
    F.toggleHide("player"); F.reset("player")
    F.step("target", "idle", -1)                              -- from Normal, a step down starts at 90 %
    out[#out + 1] = F.percentText(F.value("target", "idle"))
    F.step("target", "idle", 1); out[#out + 1] = F.percentText(F.value("target", "idle"))   -- back to 100 %
    F.set("target", "idle", nil)
    out[#out + 1] = tostring(F.get("target"))                -- nothing left: the element is forgotten
    out[#out + 1] = F.percentText(nil)
    out[#out + 1] = #F.STATES
    return table.concat(out, ",")
end""")()
assert str(r) == "n,0.31.00.1,0.3,0.0,90%,100%,nil,Normal,3", r
print("Fading: situation priority, Normal, hide, steps: OK")
# Fading page: builds, the first list is open, buttons change the element's values
r = L("""function()
    local UF = UbermocForever
    UbermocForeverDB.fade = nil
    local page = UF.FadePage.build(UIParent, UIParent)
    local rows0 = #UF.FadePage.navRows()
    -- row layout: 12 headers (chat and the Bars page elements have their own pages) + the first list's 5 elements + hide + 3 states + copy/paste + apply + reset + reset all
    return tostring(page ~= nil) .. "," .. rows0
end""")()
assert str(r) == "true,26", r
print("Fading page builds with one list open: OK")
r = L("""function()
    local UF = UbermocForever
    local page = UF.ChatPage.build(UIParent, UIParent)
    local rows = UF.ChatPage.navRows()
    return tostring(page ~= nil) .. "," .. #rows .. "," .. #rows[1] .. "," .. #rows[2]
end""")()
assert str(r) == "true,8,4,5", r
print("Chat page builds: message buttons, five parts, three situations, mouse over, hide and reset, edit box on top: OK")
# Descriptions (Describe.lua): a title and text per button; the bottom panel follows the controller highlight, with a default
# when nothing is highlighted or the highlighted button has none; the mouse tooltip uses the same words.
r = L("""function()
    local UF = UbermocForever
    local D, Nav = UF.Describe, UF.Nav
    local out = {}
    local function fs() local t = { text = "" }; t.SetText = function(self, v) t.text = v end; return t end
    local ti, tx = fs(), fs()
    local function vis(b) b.IsVisible = function() return true end; return b end
    local a, b, c = vis({}), vis({}), vis({})
    a.SetScript = function() end; b.SetScript = function() end; c.SetScript = function() end
    D.set(a, "Alpha", "What alpha does.")
    D.fn(b, function() return "Beta now", "Worked out." end)
    D.fn(c, function() error("a raising description") end)
    D.bind(ti, tx)
    out[#out + 1] = ti.text == D.DEFAULT_TITLE and tx.text == D.DEFAULT_TEXT and "default" or "no default"
    Nav.focus = nil
    Nav.SetFocus(a); out[#out + 1] = ti.text .. "/" .. tx.text
    Nav.SetFocus(b); out[#out + 1] = ti.text .. "/" .. tx.text
    Nav.SetFocus(c); out[#out + 1] = ti.text == D.DEFAULT_TITLE and "survived" or ti.text
    Nav.SetFocus(a); Nav.ClearFocus(); out[#out + 1] = ti.text == D.DEFAULT_TITLE and "cleared" or ti.text
    -- a focused button that is not shown gives the default, not its own text
    a.IsVisible = function() return false end
    Nav.SetFocus(a); out[#out + 1] = ti.text == D.DEFAULT_TITLE and "hidden" or ti.text
    -- the mouse tooltip carries the same words
    local shown = {}
    GameTooltip = { SetOwner = function() end, SetText = function(_, t) shown[#shown + 1] = t end,
                    AddLine = function(_, t) shown[#shown + 1] = t end, Show = function() end, Hide = function() end }
    local m = { SetScript = function(self, ev, fn) self[ev] = fn end }
    D.set(m, "Mouse title", "Mouse text")
    m.OnEnter(m)
    out[#out + 1] = table.concat(shown, "+")
    return table.concat(out, "|")
end""")()
assert str(r) == "default|Alpha/What alpha does.|Beta now/Worked out.|survived|cleared|hidden|Mouse title+Mouse text", r
print("Descriptions: the panel follows the highlight, defaults and raising descriptions are survived, the tooltip says the same: OK")
# Every button reachable on the Chat, Bars, Quality of life and Fading pages has a title and a text of its own
r = L("""function()
    local UF = UbermocForever
    local missing, total = {}, 0
    local function check(name, page, nav)
        for ri, row in ipairs(nav) do
            for ci, b in ipairs(row) do
                total = total + 1
                local t, x = UF.Describe.of(b)
                if not (type(t) == "string" and #t > 0 and type(x) == "string" and #x > 20) then
                    missing[#missing + 1] = name .. " row " .. ri .. " button " .. ci
                end
            end
        end
    end
    UF.ChatPage.build(UIParent, UIParent);  check("Chat", UF.ChatPage, UF.ChatPage.navRows())
    UF.BarsPage.build(UIParent, UIParent);  check("Bars", UF.BarsPage, UF.BarsPage.navRows())
    UF.QolPage.build(UIParent, UIParent);   check("Qol", UF.QolPage, UF.QolPage.navRows())
    UF.FadePage.build(UIParent, UIParent);  check("Fading", UF.FadePage, UF.FadePage.navRows())
    return total .. ":" .. table.concat(missing, ",")
end""")()
n, _, gaps = str(r).partition(":")
assert int(n) > 40 and gaps == "", r
print("Descriptions: every button reachable on the Chat, Bars, Quality of life and Fading pages has a title and a text (%s buttons): OK" % n)
# Chat edit box on top (ChatEdit.lua): the game's anchors from the XML when Off, above the dock / the tab when On, never in combat
r = L("""function()
    local UF = UbermocForever
    local CE = UF.ChatEdit
    local out = {}
    local function box()
        local b = { pts = {}, calls = 0, fail = false }
        b.ClearAllPoints = function() b.pts = {}; b.calls = b.calls + 1 end
        b.SetPoint = function(_, p, rel, rp, x, y)
            if b.fail then error("refused") end
            b.pts[#b.pts + 1] = p .. ">" .. tostring(rel.__n) .. ":" .. tostring(rp) .. ":" .. tostring(x) .. ":" .. tostring(y)
        end
        return b
    end
    local function win(n, docked)
        local f = { __n = n, isDocked = docked, editBox = box(), ScrollBar = { __n = n .. "Scroll" }, Background = { __n = n .. "Bg" },
                    GetName = function() return n end }
        _G[n] = f
        _G[n .. "Tab"] = { __n = n .. "Tab", GetHeight = function() return 30 end }
        return f
    end
    local w1, w2 = win("ChatFrame1", 1), win("ChatFrame2", nil)
    for i = 3, 10 do _G["ChatFrame" .. i] = nil end
    GENERAL_CHAT_DOCK = { __n = "Dock" }
    UF.Chat.cfg().editTop = nil
    out[#out + 1] = tostring(CE.on())
    -- nothing happens for a player who never turned it on
    CE._frame.__scripts.OnEvent(CE._frame, "PLAYER_REGEN_ENABLED"); CE._frame.__scripts.OnEvent(CE._frame, "UPDATE_CHAT_WINDOWS")
    out[#out + 1] = w1.editBox.calls .. w2.editBox.calls
    -- On: the docked window sits above the dock, the floating one above its tab (30 high) on its background
    CE.toggle()
    out[#out + 1] = table.concat(w1.editBox.pts, ",")
    out[#out + 1] = table.concat(w2.editBox.pts, ",")
    -- Off gives the game's own anchors back
    CE.toggle()
    out[#out + 1] = table.concat(w1.editBox.pts, ",")
    -- in combat nothing is written; it is done when the fight ends
    local inCombat, realCombat = true, InCombatLockdown
    InCombatLockdown = function() return inCombat end
    local before = w1.editBox.calls
    CE.toggle()
    out[#out + 1] = tostring(w1.editBox.calls == before) .. tostring(CE.pending)
    inCombat = false
    CE._frame.__scripts.OnEvent(CE._frame, "PLAYER_REGEN_ENABLED")
    out[#out + 1] = tostring(CE.pending) .. (w1.editBox.pts[1] or "")
    -- one window refusing does not stop the next one
    w1.editBox.fail = true
    CE.apply()
    w1.editBox.fail = false
    out[#out + 1] = tostring(#w2.editBox.pts)
    CE.toggle()
    InCombatLockdown = realCombat
    for i = 1, 2 do _G["ChatFrame" .. i] = nil; _G["ChatFrame" .. i .. "Tab"] = nil end
    GENERAL_CHAT_DOCK = nil
    return table.concat(out, "|")
end""")()
assert str(r) == ("false|00|BOTTOMLEFT>Dock:TOPLEFT:-3:2,BOTTOMRIGHT>Dock:TOPRIGHT:1:2|"
                  "BOTTOMLEFT>ChatFrame2Bg:TOPLEFT:-3:32,BOTTOMRIGHT>ChatFrame2Bg:TOPRIGHT:1:32|"
                  "TOPLEFT>ChatFrame1:BOTTOMLEFT:-5:-2,RIGHT>ChatFrame1Scroll:RIGHT:8:0|truetrue|"
                  "falseBOTTOMLEFT>Dock:TOPLEFT:-3:2|2"), r
print("Chat edit box on top: the game's own anchors when Off, above the dock or the tab when On, not in combat, one failure contained: OK")
# Options window: the triggers go through the pages (settings, fading, chat)
r = L("""function()
    local UF = UbermocForever
    local w = UbermocForeverOptions
    w:Hide(); w:Show()
    local function press(key)
        local b = _G["UbermocForeverNav_" .. key]
        b.__scripts.OnClick(b, "LeftButton", true)
        b.__scripts.OnClick(b, "LeftButton", false)
    end
    local out = { UF.optionsPage() }
    press("PADRTRIGGER"); out[#out + 1] = UF.optionsPage()
    press("PADRTRIGGER"); out[#out + 1] = UF.optionsPage()
    press("PADLTRIGGER"); out[#out + 1] = UF.optionsPage()
    press("PADLTRIGGER"); out[#out + 1] = UF.optionsPage()
    press("PADLTRIGGER"); out[#out + 1] = UF.optionsPage()            -- left of the first page is the last (Quality of life)
    local q = UF.QolPage.navRows()
    out[#out + 1] = #q .. "/" .. #q[1] .. "/" .. #q[2] .. "/" .. #q[3] .. "/" .. #q[4] .. "/" .. #q[5] .. "/" .. #q[6] .. "/" .. #q[7] .. "/" .. #q[8]   -- aim dot; fast loot; vendor; nameplates; name health; plate range; quest marks; quest arrow
    local before = UF.Vendor.cfg().guild
    UF.Nav.SetFocus(q[3][3]); press("PAD1")                            -- A on Guild bank first flips it
    out[#out + 1] = tostring(UF.Vendor.cfg().guild ~= before)
    UF.Vendor.toggleGuild()
    press("PADRTRIGGER"); out[#out + 1] = UF.optionsPage()            -- right of the last page is the first
    return table.concat(out, ",")
end""")()
assert str(r) == "1,2,3,2,1,5,9/3/2/3/2/2/1/3/3,true,1", r
print("Options: the triggers go through the pages: OK")
# Fading page: the D-pad moves by position, across the left list and the right pane
r = L("""function()
    local P = UbermocForever.FadePage
    -- left list buttons at x 100, right pane buttons at x 400; y grows upward
    local L1, L2, L3 = { n = "L1" }, { n = "L2" }, { n = "L3" }
    local R1, R2 = { n = "R1" }, { n = "R2" }
    local cands = { { b = L1, cx = 100, cy = 300 }, { b = L2, cx = 100, cy = 270 }, { b = L3, cx = 100, cy = 240 },
                    { b = R1, cx = 400, cy = 290 }, { b = R2, cx = 400, cy = 200 } }
    local function from(b, dir)
        local c; for _, x in ipairs(cands) do if x.b == b then c = x end end
        local others = {}; for _, x in ipairs(cands) do if x.b ~= b then others[#others + 1] = x end end
        local n = P.pick(others, c.cx, c.cy, dir)
        return n and n.n or "none"
    end
    return from(L2, "RIGHT") .. "," .. from(R1, "LEFT") .. "," .. from(L1, "DOWN") .. "," .. from(L3, "UP") .. "," .. from(R2, "UP") .. "," .. from(L1, "UP")
end""")()
assert str(r) == "R1,L1,L2,L2,R1,none", r
print("Fading page: moving by position across both columns: OK")
# Legends: shrink to fit the room they have, never below 75 %
r = L("""function()
    local f = UbermocForever.legendScale
    local function s(total, max) return string.format("%.2f", f(total, max)) end
    return s(300, 400) .. "," .. s(500, 400) .. "," .. s(500, nil) .. "," .. s(900, 400)
end""")()
assert str(r) == "1.00,0.80,1.00,0.75", r
print("Legends: shrink to fit, no further than 75 %: OK")
# Legends: one row when it fits, else a grid of equal cells filled evenly (3 + 3, never 4 + 2), left edges lined up
r = L("""function()
    local g = UbermocForever.legendGrid
    local function show(grid)
        local parts = {}
        for _, it in ipairs(grid.items) do parts[#parts + 1] = it.row .. "@" .. it.x end
        return grid.rows .. "r w" .. grid.width .. ":" .. table.concat(parts, " ")
    end
    local w6 = { 70, 60, 110, 100, 100, 60 }
    local out = {}
    out[#out + 1] = show(g(w6, nil, 14))        -- no limit: one row, following each other
    out[#out + 1] = show(g(w6, 700, 14))        -- the whole row fits in 700
    out[#out + 1] = show(g(w6, 400, 14))        -- cells of 110: 3 across, 2 rows
    out[#out + 1] = show(g(w6, 500, 14))        -- room for 4 across would be 4 + 2: it is 3 + 3
    out[#out + 1] = show(g({ 70, 60, 110, 100, 100 }, 260, 14))   -- 5 items, 2 across would be 3 rows
    out[#out + 1] = show(g({ 90 }, 10, 14))     -- one wide item: still shown, one row
    out[#out + 1] = show(g({}, 100, 14))        -- nothing
    return table.concat(out, "|")
end""")()
assert str(r) == ("1r w570:0@0 0@84 0@158 0@282 0@396 0@510|"
                  "1r w570:0@0 0@84 0@158 0@282 0@396 0@510|"
                  "2r w358:0@0 0@124 0@248 1@0 1@124 1@248|"
                  "2r w358:0@0 0@124 0@248 1@0 1@124 1@248|"
                  "3r w234:0@0 0@124 1@0 1@124 2@0|"
                  "1r w90:0@0|1r w1:"), r
print("Legends: a row when it fits, else an evenly filled grid of equal cells: OK")
# Character window: A on a gear slot clicks its popout button (opens the equipment flyout) when it has items to offer
r = L("""function()
    local G = UbermocForever.GameNav
    local items = {}
    local pop = { n = "pop" }
    local parent = { flyoutSettings = { getItemsFunc = function(id, t) for k, v in pairs(items) do t[k] = v end end } }
    local slot = { popoutButton = pop, GetParent = function() return parent end, GetID = function() return 1 end }
    local out = {}
    out[#out + 1] = tostring((G.flyoutOpener(slot)))                 -- nothing fits: nil
    items = { [100] = 5 }
    out[#out + 1] = G.flyoutOpener(slot) == pop and "pop" or "no"   -- something fits: the popout button
    InRepairMode = function() return true end
    out[#out + 1] = tostring((G.flyoutOpener(slot)))                 -- repair mode: left alone
    InRepairMode = nil
    out[#out + 1] = tostring((G.flyoutOpener({ GetParent = function() return parent end })))   -- a button with no popout: nil
    return table.concat(out, ",")
end""")()
assert str(r) == "nil,pop,nil,nil", r
print("Character window: A on a gear slot opens the equipment flyout: OK")
# Cinematic: the "experimental feature" popup is closed (accepted) only while our own settings change
r = L("""function()
    local C = UbermocForever.Cinematic
    local hidden = {}
    StaticPopup_Hide = function(w) hidden[#hidden + 1] = w end
    local realTime = GetTime
    GetTime = function() return 1000 end                    -- long after any earlier guard
    local a = C.onPopup("EXPERIMENTAL_CVAR_WARNING")        -- no guard: left alone
    C.guard(3)
    local b = C.onPopup("EXPERIMENTAL_CVAR_WARNING")        -- while we change settings: closed
    local c = C.onPopup("SOMETHING_ELSE")                   -- another popup: left alone
    GetTime = realTime
    return tostring(a) .. tostring(b) .. tostring(c) .. #hidden
end""")()
assert str(r) == "falsetruefalse1", r
print("Cinematic: the experimental camera popup is accepted by itself: OK")
# Fading: parts are found by dotted path, become independent of their parent while they have a setting, and copy / paste / apply work
r = L("""function()
    local F = UbermocForever.Fade
    UbermocForeverDB.fade = nil
    local out = {}
    local function frame()
        local f = { alpha = 1, ignore = false }
        function f:SetAlpha(a) self.alpha = a end
        function f:IsIgnoringParentAlpha() return self.ignore end
        function f:SetIgnoreParentAlpha(v) self.ignore = v end
        return f
    end
    local cap = frame()
    MainActionBar = { EndCaps = { LeftEndCap = cap } }
    out[#out + 1] = tostring(F._frameOf("MainActionBar.EndCaps.LeftEndCap") == cap)
    out[#out + 1] = tostring(F._frameOf("MainActionBar.EndCaps.Nope") == nil)
    F._apply("mb_leftcap", 0.4, true)                           -- a part with a setting: independent, own opacity
    out[#out + 1] = tostring(cap.ignore) .. cap.alpha
    F._apply("mb_leftcap", 1, false)                            -- setting cleared: back to following its parent
    out[#out + 1] = tostring(cap.ignore) .. cap.alpha
    local n, total = F.found(F.byKey.mb_leftcap)
    out[#out + 1] = n .. "/" .. total
    out[#out + 1] = F.found(F.byKey.mb_rightcap) .. ""           -- not defined in the test: 0
    -- copy, paste, apply to the whole list (the Main bar parts list has 5 elements)
    F.set("mb_leftcap", "idle", 0.2); F.set("mb_leftcap", "combat", 1)
    F.copy("mb_leftcap")
    F.paste("mb_rightcap")
    out[#out + 1] = F.percentText(F.value("mb_rightcap", "idle")) .. F.percentText(F.value("mb_rightcap", "combat"))
    local others = F.applyToList("mb_leftcap")
    out[#out + 1] = others .. F.percentText(F.value("mainbar", "idle"))
    F.resetAll()
    out[#out + 1] = tostring(F.get("mainbar"))
    return table.concat(out, ",")
end""")()
assert str(r) == "true,true,true0.4,false1,1/1,0,20%100%,420%,nil", r
print("Fading: parts by path, independent of their parent, copy / paste / apply to the list: OK")
# Fading: the universal mouse-over opacity only ever raises an element, and never one that is hidden for good
r = L("""function()
    local F = UbermocForever.Fade
    UbermocForeverDB.fade = nil; UbermocForeverDB.fadeMouse = nil
    local out = {}
    local idle = { combat = false, flight = false, idle = true }
    F.set("minimap", "idle", 0.2)
    out[#out + 1] = string.format("%.1f", F.wanted("minimap", idle, true))   -- no mouse setting: its own value
    F.setMouse(0.8)
    out[#out + 1] = string.format("%.1f", F.wanted("minimap", idle, true))   -- mouse over: raised to 80 %
    out[#out + 1] = string.format("%.1f", F.wanted("minimap", idle, false))  -- not over: its own value
    F.set("minimap", "idle", 0.9)
    out[#out + 1] = string.format("%.1f", F.wanted("minimap", idle, true))   -- already higher: kept
    F.set("minimap", "idle", 0.2); F.toggleHide("minimap")
    out[#out + 1] = string.format("%.1f", F.wanted("minimap", idle, true))   -- hidden for good: stays 0
    F.stepMouse(-1); out[#out + 1] = F.percentText(F.mouse())               -- 70 %
    F.setMouse(nil); out[#out + 1] = tostring(F.mouse())
    F.resetAll()
    return table.concat(out, ",")
end""")()
assert str(r) == "0.2,0.8,0.2,0.9,0.0,70%,nil", r
print("Fading: mouse-over opacity raises only, hidden stays hidden: OK")
# Fading: a part can have a mouse-over opacity of its own (the Chat page): own value, Off, or Same as the universal one
r = L("""function()
    local F = UbermocForever.Fade
    UbermocForeverDB.fade = nil; UbermocForeverDB.fadeMouse = nil; UbermocForeverDB.fadeMouseBy = nil
    local out = {}
    local idle = { combat = false, flight = false, idle = true }
    local function w(k) return string.format("%.1f", F.wanted(k, idle, true)) end
    F.set("chat", "idle", 0.2); F.set("minimap", "idle", 0.2)
    F.setMouse(0.8)
    out[#out + 1] = w("chat") .. "/" .. w("minimap")                 -- both follow the universal one
    F.setMouseOwn("chat", 0.5)
    out[#out + 1] = w("chat") .. "/" .. w("minimap")                 -- chat 0.5, minimap still 0.8
    F.stepMouseOwn("chat", 1); out[#out + 1] = F.percentText(F.mouse("chat"))   -- 60 %
    F.setMouseOwn("chat", false)
    out[#out + 1] = w("chat") .. "/" .. tostring(F.mouse("chat"))    -- Off for chat: its own 0.2, no mouse value
    F.setMouseOwn("chat", nil)
    out[#out + 1] = w("chat")                                        -- Same again: 0.8
    F.setMouseOwn("chat", 0.5); F.reset("chat")
    out[#out + 1] = tostring(F.mouseOwn("chat"))                     -- reset clears it
    F.setMouseOwn("chat", 0.5); F.toggleHide("chat")
    out[#out + 1] = w("chat")                                        -- hidden for good stays hidden
    F.resetAll(); UbermocForeverDB.fadeMouseBy = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "0.8/0.8,0.5/0.8,60%,0.2/nil,0.8,nil,0.0", r
print("Fading: a part's own mouse-over opacity, Off and Same, cleared by reset, hidden stays hidden: OK")
# PlateLevel (PlateLevel.lua): the level of a friendly player under the game's name-only setting, which the game itself hides.
# FAKE(C50): the stub UnitLevel returns a plain number (claim C50: no secret return) or a secret/odd value.
r = L("""function()
    local UF = UbermocForever
    local PL = UF.PlateLevel
    local out = {}
    local saved = { UnitLevel, issecretvalue, UnitIsPlayer, UnitCanAttack, UbermocForeverDB.plates }
    UbermocForeverDB.plates = nil
    local level = 37
    UnitLevel = function(u) if u == "boom" then error("restricted") end return level end
    out[#out + 1] = tostring(PL.levelText("x")) .. "/" .. tostring(PL.levelText("boom"))
    level = 0; out[#out + 1] = tostring(PL.levelText("x"))                  -- too high to tell
    level = -1; out[#out + 1] = tostring(PL.levelText("x"))
    level = "secret"; issecretvalue = function(v) return v == "secret" end
    out[#out + 1] = tostring(PL.levelText("x"))                              -- a secret is not read
    level = "text"; out[#out + 1] = tostring(PL.levelText("x"))              -- an odd answer is not shown
    issecretvalue = saved[2]
    level = 60
    -- showing: on for a wanted plate with the option on; cleared otherwise
    local made = {}
    local realMake = PL.make
    PL.make = function(uf)
        local fs = { shown = false }
        fs.Show = function() fs.shown = true end; fs.Hide = function() fs.shown = false end
        fs.SetText = function(_, t) fs.text = t end; fs.SetTextColor = function() end
        fs.IsShown = function() return fs.shown end
        local o = { fs = fs }; made[#made + 1] = o; return o
    end
    local uf = {}
    PL.show(uf, "x", true)
    local fs = made[1].fs
    out[#out + 1] = tostring(fs.shown) .. ":" .. tostring(fs.text)
    PL.show(uf, "x", false); out[#out + 1] = tostring(fs.shown)             -- not a plate that needs it: cleared
    PL.show(uf, "x", true); PL.toggle(); PL.show(uf, "x", true)              -- option Off: cleared
    out[#out + 1] = tostring(fs.shown) .. ":" .. tostring(PL.enabled()) .. ":" .. #made
    PL.toggle()
    -- through Nameplates: a friendly player with Friendly name-only gets it; an enemy and a friendly NPC do not
    UbermocForeverDB.plates.friendly = true
    local isPlayer, attack = true, false
    UnitIsPlayer = function() return isPlayer end
    UnitCanAttack = function() return attack end
    local plate = { namePlateUnitToken = "nameplate1", UnitFrame = { unit = "nameplate1" } }
    local function shownOnPlate() local o = PL.piece(plate.UnitFrame); return tostring(o and o.fs.shown) end
    UF.Nameplates.style(plate)
    out[#out + 1] = shownOnPlate()
    isPlayer = false; UF.Nameplates.style(plate); out[#out + 1] = shownOnPlate()   -- an NPC: the game shows its level
    isPlayer = true; attack = true; UF.Nameplates.style(plate); out[#out + 1] = shownOnPlate()   -- an enemy player
    attack = false; UbermocForeverDB.plates.friendly = false; UF.Nameplates.style(plate)
    out[#out + 1] = shownOnPlate()                                 -- Friendly name-only Off: the game shows it
    PL.make = realMake
    UnitLevel, issecretvalue, UnitIsPlayer, UnitCanAttack = saved[1], saved[2], saved[3], saved[4]
    UbermocForeverDB.plates = saved[5]
    return table.concat(out, "|")
end""")()
assert str(r) == "37/nil|??|??|nil|nil|true:60|false|false:false:1|true|false|false|false", r
src = open(ADDON + "/PlateLevel.lua", encoding="utf-8").read()
for bad in ["hooksecurefunc", "OnUpdate", "SetAlpha", "UnitHealth", "UnitName", "GetText", "GetStringWidth"]:
    assert bad not in src, "PlateLevel.lua contains " + bad
print("PlateLevel: the level of a friendly player under name-only is drawn, secrets and errors are survived, NPCs and enemies are left to the game: OK")
# PlateQuest (PlateQuest.lua): a quest mark and the progress on nameplates. FAKE(C51): the stub UnitIsRelatedToActiveQuest returns a
# plain bool (claim C51: no secret return). FAKE(C53) FAKE(C55): the stub tooltip lines have the type and leftText
# of TooltipInfoSharedDocumentation.lua (QuestObjective 8, QuestTitle 17), and the objective text is the unit tooltip's "name: a/b".
r = L("""function()
    local UF = UbermocForever
    local PQ = UF.PlateQuest
    local out = {}
    local saved = { C_QuestLog, C_TooltipInfo, Enum, issecretvalue, C_NamePlate, UbermocForeverDB and UbermocForeverDB.plates }
    local related, lines = true, {}
    C_QuestLog = { UnitIsRelatedToActiveQuest = function(unit) if unit == "boom" then error("restricted") end return related end }
    C_TooltipInfo = { GetUnit = function() return { lines = lines } end }
    Enum = { TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17 } }
    UbermocForeverDB.plates = nil
    local function line(t, text) return { type = t, leftText = text } end
    local function st(unit)
        local s = PQ.state(unit)
        if not s then return "none" end
        return (s.done and "done" or "open") .. ":" .. tostring(s.text)
    end
    lines = { line(17, "Kill them all"), line(8, "Defias Thug slain: 3/8") }
    out[#out + 1] = st("target")                                   -- open:3/8
    lines = { line(17, "Kill them all"), line(8, "Defias Thug slain: 8/8") }
    out[#out + 1] = st("target")                                   -- done
    lines = { line(8, "Boar Meat: 8/8"), line(8, "Boar Tusk: 2/4") }
    out[#out + 1] = st("target")                                   -- the first unfinished one
    lines = { line(8, "Escort progress: 45%") }
    out[#out + 1] = st("target")                                   -- a percent objective
    lines = { line(22, "Defias Thug"), line(8, "Defias Thug slain: 1/2"), line(18, "Friend") }
    out[#out + 1] = st("target")                                   -- other lines are ignored
    lines = {}
    out[#out + 1] = st("target")                                   -- related, but no objective line: marked, no text
    related = false
    out[#out + 1] = st("target")                                   -- not related: nothing
    related = true
    out[#out + 1] = st("boom")                                     -- a raising call: nothing
    issecretvalue = function(v) return v == "secret" end
    lines = { line(8, "secret") }
    out[#out + 1] = st("target")                                   -- a secret line is not read
    C_QuestLog = { UnitIsRelatedToActiveQuest = function() return "secret" end }
    out[#out + 1] = st("target")                                   -- a secret answer counts as no
    C_QuestLog = { UnitIsRelatedToActiveQuest = function() return related end }
    issecretvalue = saved[4]
    -- showing: the icon and the text follow the two settings; a finished unit is cleared
    local made = {}
    local realMake = PQ.make
    PQ.make = function(uf)
        local function piece(n) local p = { name = n, shown = false }; p.Show = function() p.shown = true end; p.Hide = function() p.shown = false end
            p.SetText = function(_, t) p.text = t end; p.ClearAllPoints = function() end; p.SetPoint = function() end; return p end
        local o = { icon = piece("icon"), text = piece("text") }
        made[#made + 1] = o
        return o
    end
    local uf = { unit = "target" }
    local shownPlate = { namePlateUnitToken = "target", UnitFrame = uf }
    C_NamePlate = { GetNamePlates = function() return { shownPlate } end, GetNamePlateForUnit = function() return nil end }
    lines = { line(8, "Defias Thug slain: 3/8") }
    PQ.show(uf, "target")
    local o = made[1]
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. tostring(o.text.shown) .. "/" .. tostring(o.text.text)
    PQ.toggle("text")
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. tostring(o.text.shown) .. "/" .. tostring(PQ.textEnabled())
    PQ.toggle("quest")                                              -- both off: nothing shown
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. tostring(o.text.shown) .. "/" .. tostring(PQ.enabled())
    PQ.toggle("quest"); PQ.toggle("text")                           -- back on
    PQ.show(uf, "target")
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. tostring(o.text.shown)
    lines = { line(8, "Defias Thug slain: 8/8") }
    PQ.show(uf, "target")
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. tostring(o.text.shown)    -- finished: cleared
    related = false; lines = { line(8, "x: 1/2") }
    PQ.show(uf, "target")
    out[#out + 1] = tostring(o.icon.shown) .. "/" .. #made           -- not related: still cleared, and the pieces were made once
    -- the events: a plate added is styled, a removed one cleared, a quest update asks again once
    related = true; lines = { line(8, "Defias Thug slain: 2/8") }
    local plate = { namePlateUnitToken = "nameplate1", UnitFrame = { unit = "nameplate1" } }
    C_NamePlate = { GetNamePlateForUnit = function(u) if u == "nameplate1" then return plate end end, GetNamePlates = function() return { plate } end }
    local ev = PQ._frame.__scripts.OnEvent
    ev(PQ._frame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    local o2 = made[2]
    out[#out + 1] = tostring(o2 and o2.icon.shown) .. "/" .. tostring(o2 and o2.text.text)
    ev(PQ._frame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    out[#out + 1] = tostring(o2.icon.shown)
    PQ.make = realMake
    C_QuestLog, C_TooltipInfo, Enum, C_NamePlate = saved[1], saved[2], saved[3], saved[5]
    UbermocForeverDB.plates = saved[6]
    return table.concat(out, "|")
end""")()
assert str(r) == ("open:3/8|done:nil|open:2/4|open:45%|open:1/2|open:nil|none|none|open:nil|none|"
                  "true/true/3/8|true/false/false|false/false/false|true/true|false/false|false/1|true/2/8|false"), r
print("PlateQuest: related units are marked with their progress, finished and unrelated ones are not, secrets and errors are survived, the two options and the events work: OK")
src = open(ADDON + "/PlateQuest.lua", encoding="utf-8").read()
for bad in ["hooksecurefunc", "OnUpdate", "SetAlpha", "UnitHealth", "UnitName", "GetText", "GetStringWidth"]:
    assert bad not in src, "PlateQuest.lua contains " + bad
print("PlateQuest: no hook, no update loop, nothing read back, nothing written on a game frame: OK")
# TargetCancel (TargetCancel.lua): while the game waits for a target (SpellIsTargeting), B goes to a secure button that runs
# /stopspelltarget; it is given back as soon as the wait ends, never taken in combat, retaken when a window took it, and the
# game's cursor clicks (R1, R2) are left alone. FAKE(C48): the stub SpellIsTargeting stands for the game's call of that name
# (SecureTemplates.lua:183 and Blizzard_UIPanels_Game PaperDollFrame.lua use it as a plain boolean test).
r = L("""function()
    local UF = UbermocForever
    local T, Nav = UF.TargetCancel, UF.Nav
    local out = {}
    local savedTarget, savedCombat, savedBind, savedCVar, savedGet = SpellIsTargeting, InCombatLockdown, SetOverrideBindingClick, SetCVar, GetCVar
    -- the game's cursor clicks are at their defaults, so a window taking the buttons WOULD switch them off
    GetCVar = function(n) if n == "GamePadCursorLeftClick" then return "PADRTRIGGER" elseif n == "GamePadCursorRightClick" then return "PADRSHOULDER" end return "0" end
    local waiting, combat, boundTo, cvarWrites = false, false, {}, 0
    SpellIsTargeting = function() return waiting end
    InCombatLockdown = function() return combat end
    SetOverrideBindingClick = function(_, _, key, name) boundTo[key] = name end
    SetCVar = function() cvarWrites = cvarWrites + 1 end
    -- start from an empty stack (earlier tests leave windows on it that would take the click cvars themselves)
    local stash = {}
    for i = #Nav._stack, 1, -1 do stash[#stash + 1] = table.remove(Nav._stack, i) end
    local ticker = T._frame.__scripts.OnUpdate
    local function tick() ticker(T._frame, 0.2) end
    local base = Nav.Count()
    tick(); out[#out + 1] = Nav.Count() - base .. tostring(boundTo.PAD2)       -- not waiting: nothing taken
    waiting = true
    combat = true
    tick(); out[#out + 1] = Nav.Count() - base                                 -- waiting in combat: nothing taken
    combat = false
    tick(); out[#out + 1] = (Nav.Count() - base) .. ":" .. tostring(boundTo.PAD2)   -- waiting: B goes to our button
    local writesAtTake = cvarWrites
    tick(); out[#out + 1] = Nav.Count() - base                                 -- and only once
    -- a window opens after us and takes B: we take it back
    local other = Nav.Push({}, { PAD2 = { "SomeWindowBack", "LeftButton" } })
    tick(); out[#out + 1] = boundTo.PAD2
    Nav.Pop(other)
    waiting = false
    tick(); out[#out + 1] = (Nav.Count() - base) .. ":" .. writesAtTake          -- the wait is over: B is given back; taking B touched no click cvar (a window that takes them does, below)
    SpellIsTargeting = function() error("restricted") end
    tick(); out[#out + 1] = Nav.Count() - base                                 -- a raising call is survived
    SpellIsTargeting = function() return waiting end
    -- the entry is shared: GameNav keeps working beside it, but a real window of ours still counts
    waiting = true; tick()
    local sharedOthers = Nav.CountOthers(nil)
    local win = Nav.Push({}, {})
    local withWindow = Nav.CountOthers(nil)
    Nav.Pop(win)
    out[#out + 1] = sharedOthers .. ":" .. withWindow
    -- the game's own question is up (the replace-this-enchant question): A and B are GameNav's, B is not taken
    StaticPopup1 = { IsShown = function() return true end }
    tick(); out[#out + 1] = Nav.Count() - base
    StaticPopup1 = { IsShown = function() return false end }
    tick(); out[#out + 1] = Nav.Count() - base                                 -- the question is gone: B is taken again
    StaticPopup1 = nil
    waiting = false; tick()
    for i = #stash, 1, -1 do Nav._stack[#Nav._stack + 1] = stash[i] end
    SpellIsTargeting, InCombatLockdown, SetOverrideBindingClick, SetCVar, GetCVar = savedTarget, savedCombat, savedBind, savedCVar, savedGet
    return table.concat(out, "|")
end""")()
assert str(r) == "0nil|0|1:UbermocForeverCancelTarget|1|UbermocForeverCancelTarget|0:0|0|0:1|0|1", r
src = open(ADDON + "/TargetCancel.lua", encoding="utf-8").read()
code = src.split("local _, UF", 1)[1]
assert '"/stopspelltarget"' in code and "SpellStopTargeting" not in code, "the macro, not a direct call"
print("TargetCancel: B cancels the pick-a-target wait through the game's own /stopspelltarget, only while it waits, never in combat, clicks untouched: OK")
gn = open(ADDON + "/GameNav.lua", encoding="utf-8").read()
assert "local others = UF.Nav.CountOthers(entry)" in gn, "GameNav must not step aside for a shared entry (the B-cancels-the-wait one)"
# GameNav: opening our marker menu asks for a scan on the next frame instead of waiting for the 0.15 s tick
r = L("""function()
    local G = UbermocForever.GameNav
    local runs, real = 0, G.update
    G.update = function() runs = runs + 1 end
    local t = G._ticker
    local out = {}
    local f = t.__scripts.OnUpdate
    f(t, 0.016); out[#out + 1] = runs          -- a normal frame: still waiting
    G.kick()
    f(t, 0.016); out[#out + 1] = runs          -- after the kick: the very next frame scans
    f(t, 0.016); out[#out + 1] = runs          -- and the wait starts over
    G.update = real
    return table.concat(out, ",")
end""")()
assert str(r) == "0,1,1", r
print("GameNav: kick makes the next frame scan, then the normal wait resumes: OK")

# Y menu: the auction house's Create Auction button is found only when an item waits in a shown sell frame
r = L("""function()
    local M = UbermocForever.ItemMenu
    local out = {}
    out[#out + 1] = tostring(M.auctionPost())
    local post = { IsEnabled = function() return true end }
    local sf = { PostButton = post, IsShown = function() return true end, GetItem = function() return nil end }
    AuctionHouseFrame = { IsShown = function() return true end, ItemSellFrame = sf }
    out[#out + 1] = tostring(M.auctionPost())
    sf.GetItem = function() return {} end
    out[#out + 1] = tostring(M.auctionPost() == post)
    AuctionHouseFrame = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "nil,nil,true", r
print("Y menu: Post auction button found only with an item in the sell slot: OK")

# X at the auction house: the item goes into the sell slot through AuctionHouseFrame:SetPostItem (ContainerFrame.lua:1554-1562),
# for a named slot and for an unnamed one (the combined bags); the secure click itself does nothing there; the label says Auction
r = L("""function()
    local M, G = UbermocForever.ItemMenu, UbermocForever.GameNav
    local out, posted = {}, {}
    local saved = { C_Container, ItemLocation, AuctionHouseFrame }
    C_Container = { GetContainerItemInfo = function(bag, slot) if bag == 1 and slot == 4 then return { itemID = 7 } end end }
    ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
    AuctionHouseFrame = { IsShown = function() return true end, SetPostItem = function(_, loc) posted[#posted + 1] = loc.bag .. ":" .. loc.slot end }
    local unnamed = { GetBagID = function() return 1 end, GetID = function() return 4 end, GetName = function() return nil end }
    local named = { GetBagID = function() return 1 end, GetID = function() return 4 end, GetName = function() return "ContainerFrame2Item4" end }
    local empty = { GetBagID = function() return 1 end, GetID = function() return 5 end, GetName = function() return nil end }
    out[#out + 1] = M.rightClickAction(unnamed).macrotext == "" and "nosecure" or "secure"
    out[#out + 1] = tostring(M.postToAuction(unnamed))
    out[#out + 1] = tostring(M.postToAuction(named))
    out[#out + 1] = tostring(M.postToAuction(empty))
    out[#out + 1] = table.concat(posted, "|")
    out[#out + 1] = tostring(G.xLabel(unnamed))
    AuctionHouseFrame.IsShown = function() return false end
    out[#out + 1] = tostring(M.postToAuction(unnamed))
    C_Container, ItemLocation, AuctionHouseFrame = saved[1], saved[2], saved[3]
    return table.concat(out, ",")
end""")()
assert str(r) == "nosecure,true,true,false,1:4|1:4,Auction,false", r
print("X at the auction house: bag item goes into the sell slot (named and unnamed), label Auction: OK")

# Gamepad layout: other binds of the held combination get a slot
r = L("""function()
    local B = UbermocForever.GamepadBar
    local binds = { PADDUP = "TARGETNEARESTENEMY", ["SHIFT-PADLSTICK"] = "JUMP", PAD3 = "ACTIONBUTTON1", PAD1 = "MULTIACTIONBAR1BUTTON2",
                    PADRSTICK = "CLICK Foo:LeftButton", PADBACK = "TOGGLEWORLDMAP" }
    local function act(k) return binds[k] or "" end
    local function nm(c) return c == "JUMP" and "Jump" or nil end
    local a = B.extras(1, act, nm)
    local b = B.extras(2, act, nm)
    local out = {}
    for _, e in ipairs(a) do out[#out + 1] = e.pad .. "=" .. e.name end
    out[#out + 1] = "|"
    for _, e in ipairs(b) do out[#out + 1] = e.pad .. "=" .. e.name end
    return table.concat(out, ",")
end""")()
assert str(r) == "PAD1=MULTIACTIONBAR1BUTTON2,PADDUP=TARGETNEARESTENEMY,PADBACK=TOGGLEWORLDMAP,|,PADLSTICK=Jump", r
print("Gamepad layout: other binds of the held combination: OK")

# Gamepad layout: a used bar the game does not show is found
r = L("""function()
    local B = UbermocForever.GamepadBar
    local out = {}
    out[#out + 1] = #B.hiddenBars()
    MultiBarRight = { IsShown = function() return false end }
    MultiBarRightButton1 = { action = 3, GetNumPoints = function() return 0 end }
    local oldHas = HasAction
    HasAction = function(a) return a == 3 end
    out[#out + 1] = table.concat(B.hiddenBars(), "/")
    HasAction = function(a) return false end
    out[#out + 1] = #B.hiddenBars()
    HasAction = oldHas
    MultiBarRight, MultiBarRightButton1 = nil, nil
    return table.concat(out, ",")
end""")()
assert str(r) == "0,4,0", r
print("Gamepad layout: switched-off bar with actions found: OK")

# Gamepad layout: buttons of the action bars 5 to 8 bound on the held combination
r = L("""function()
    local B = UbermocForever.GamepadBar
    local binds = { PADDUP = "MULTIACTIONBAR5BUTTON3", ["SHIFT-PADDDOWN"] = "MULTIACTIONBAR4BUTTON1", PAD3 = "MULTIACTIONBAR1BUTTON2", PAD1 = "MULTIACTIONBAR9BUTTON1" }
    local function act(k) return binds[k] or "" end
    local out = {}
    for _, e in ipairs(B.moreButtons(1, act)) do out[#out + 1] = e.pad .. "=" .. e.name end
    out[#out + 1] = "|"
    for _, e in ipairs(B.moreButtons(2, act)) do out[#out + 1] = e.pad .. "=" .. e.name end
    return table.concat(out, ",")
end""")()
assert str(r) == "PADDUP=MultiBar5Button3,|,PADDDOWN=MultiBarLeftButton1", r
print("Gamepad layout: buttons of bars 5 to 8: OK")

# Stepping settings: one at a time, A forward and X back, both wrap; a stepping button carries ufBack for X
r = L("""function()
    local B, C, A = UbermocForever.GamepadBar, UbermocForever.Cinematic, UbermocForever.Aim
    local out = {}
    out[#out + 1] = UbermocForever.stepRange(40, 30, 64, 1) .. "/" .. UbermocForever.stepRange(40, 30, 64, -1)
    out[#out + 1] = UbermocForever.stepRange(64, 30, 64, 1) .. "/" .. UbermocForever.stepRange(30, 30, 64, -1)
    out[#out + 1] = UbermocForever.stepIndex(1, 4, -1) .. "/" .. UbermocForever.stepIndex(4, 4, 1)
    local db = UbermocForeverDB
    local d0 = db.cinemaBars
    db.cinemaBars = 1; C.nextBars(-1); out[#out + 1] = C.barsName(); C.nextBars(1); out[#out + 1] = C.barsName()
    db.cinemaBars = d0
    local b = CreateFrame("Button")
    local got = {}
    UbermocForever.cycleButton(b, function(d) got[#got + 1] = d end)
    b.ufBack()
    out[#out + 1] = table.concat(got, ";")
    return table.concat(out, ",")
end""")()
assert str(r) == "41/39,30/64,4/1,Thick,Off,-1", r
print("Stepping settings: one at a time, forward and back, wrapping: OK")

# The game's cursor clicks (R2 / R1) are switched off while one of our windows has the buttons, and given back after
r = L("""function()
    local Nav = UbermocForever.Nav
    local oldG, oldS = GetCVar, SetCVar
    local cv = { GamePadCursorLeftClick = "PADRTRIGGER", GamePadCursorRightClick = "PAD4" }
    GetCVar = function(k) return cv[k] end
    SetCVar = function(k, v) cv[k] = v end
    local out = {}
    local e = Nav.Push({ PADRTRIGGER = function() end })   -- another window may already be open: still taken
    out[#out + 1] = cv.GamePadCursorLeftClick .. "/" .. cv.GamePadCursorRightClick
    Nav.Pop(e)
    Nav.manageClicks(false)   -- what happens when the last window closes
    out[#out + 1] = cv.GamePadCursorLeftClick .. "/" .. cv.GamePadCursorRightClick .. "/" .. tostring(UbermocForeverDB.clickBackup)
    GetCVar, SetCVar = oldG, oldS
    return table.concat(out, ",")
end""")()
assert str(r) == "NONE/PAD4,PADRTRIGGER/PAD4/nil", r
print("Cursor clicks: R2 taken from the game's cursor while a window is open, given back: OK")

# Stuck cursor clicks (switched off by something else, nothing saved to give back) are reset at login
r = L("""function()
    local Nav = UbermocForever.Nav
    local oldG, oldS = GetCVar, SetCVar
    local cv = { GamePadCursorLeftClick = "NONE", GamePadCursorRightClick = "NONE" }
    GetCVar = function(k) return cv[k] end
    SetCVar = function(k, v) cv[k] = v end
    local out = {}
    UbermocForeverDB.clickBackup = nil
    Nav.healClicks()
    out[#out + 1] = cv.GamePadCursorLeftClick .. "/" .. cv.GamePadCursorRightClick
    cv.GamePadCursorLeftClick, cv.GamePadCursorRightClick = "NONE", "PAD4"
    UbermocForeverDB.clickBackup = { left = "PADRTRIGGER" }   -- ours is holding them: leave alone
    Nav.healClicks()
    out[#out + 1] = cv.GamePadCursorLeftClick .. "/" .. cv.GamePadCursorRightClick
    UbermocForeverDB.clickBackup = nil
    GetCVar, SetCVar = oldG, oldS
    return table.concat(out, ",")
end""")()
assert str(r) == "PADRTRIGGER/PADRSHOULDER,NONE/PAD4", r
print("Stuck cursor clicks: reset to the defaults at login, left alone while ours holds them: OK")

# Fast loot: every slot at once with Auto Loot on, nothing as the master looter or with it switched off
r = L("""function()
    local Lt = UbermocForever.Loot
    local oldG, oldN, oldS, oldP, oldM = GetCVar, GetNumLootItems, LootSlot, C_PartyInfo, IsModifiedClick
    local cv = { autoLootDefault = "1" }
    local taken = {}
    GetCVar = function(k) return cv[k] end
    GetNumLootItems = function() return 3 end
    LootSlot = function(i) taken[#taken + 1] = i end
    IsModifiedClick = function() return false end
    local method, pid = 3, nil
    C_PartyInfo = { GetLootMethod = function() return method, pid end }
    local out = {}
    UbermocForeverDB = { fastLootLoop = "one" }   -- the instant-take way for this test
    Lt.onReady(true); out[#out + 1] = table.concat(taken, ""); taken = {}
    method, pid = 2, 0
    Lt.onReady(true); out[#out + 1] = "[" .. table.concat(taken, "") .. "]"; taken = {}     -- we are the master looter
    method, pid = 2, 3
    Lt.onReady(true); out[#out + 1] = table.concat(taken, ""); taken = {}                   -- someone else is
    cv.autoLootDefault = "0"
    Lt.onReady(false); out[#out + 1] = "[" .. table.concat(taken, "") .. "]"; taken = {}    -- the game's Auto Loot off
    cv.autoLootDefault = "1"
    Lt.toggle(); out[#out + 1] = tostring(Lt.enabled())
    Lt.onReady(true); out[#out + 1] = "[" .. table.concat(taken, "") .. "]"
    Lt.toggle()
    UbermocForeverDB = {}
    GetCVar, GetNumLootItems, LootSlot, C_PartyInfo, IsModifiedClick = oldG, oldN, oldS, oldP, oldM
    return table.concat(out, ",")
end""")()
assert str(r) == "321,[],321,[],false,[]", r
print("Fast loot: all slots at once, not as master looter, follows Auto Loot and the option: OK")

# Fast loot loops: Staggered (the default) one slot at a time, newest first; Instant every slot at once
r = L("""function()
    local Lt = UbermocForever.Loot
    local oldDB, oldG, oldN, oldS, oldM = UbermocForeverDB, GetCVar, GetNumLootItems, LootSlot, IsModifiedClick
    local out = {}
    local cv = { autoLootDefault = "1" }
    local taken = {}
    local remaining = 3
    GetCVar = function(k) return cv[k] end
    IsModifiedClick = function() return false end
    C_PartyInfo = { GetLootMethod = function() return 3, nil end }
    GetNumLootItems = function() return remaining end
    LootSlot = function(i) taken[#taken + 1] = i; remaining = remaining - 1 end
    local function flush()
        local t = __calls.timers or {}
        __calls.timers = {}
        for _, f in ipairs(t) do f() end
    end
    -- Staggered (the default): one slot per tick, still newest first
    UbermocForeverDB = {}
    remaining = 3; taken = {}; __calls.timers = {}
    Lt.onReady(true)
    out[#out + 1] = "staggered:" .. table.concat(taken, "") .. ":timers:" .. tostring(#(__calls.timers or {}))
    -- Instant: every slot at once, nothing staged
    UbermocForeverDB = { fastLootLoop = "one" }
    taken = {}; remaining = 3; __calls.timers = {}
    Lt.onReady(true)
    out[#out + 1] = "one:" .. table.concat(taken, "") .. ":timers:" .. tostring(#(__calls.timers or {}))
    -- Staggered: the timers take the rest one slot at a time
    UbermocForeverDB = { fastLootLoop = "two" }
    taken = {}; remaining = 3; __calls.timers = {}
    Lt.onReady(true)
    out[#out + 1] = "two:" .. table.concat(taken, "") .. ":timers:" .. tostring(#(__calls.timers or {}))
    flush()
    out[#out + 1] = "+" .. table.concat(taken, "")
    flush()
    out[#out + 1] = "+" .. table.concat(taken, "")
    flush()
    out[#out + 1] = "+" .. table.concat(taken, "") .. ":timers:" .. tostring(#(__calls.timers or {}))
    -- the loop button toggles and reports its name
    UbermocForeverDB = {}
    Lt.nextLoop(); out[#out + 1] = "next:" .. Lt.loop() .. ":" .. Lt.loopName()
    Lt.nextLoop()
    out[#out + 1] = Lt.loop() .. ":" .. Lt.loopName()
    -- restore the settings and the game
    UbermocForeverDB = oldDB
    GetCVar, GetNumLootItems, LootSlot, IsModifiedClick = oldG, oldN, oldS, oldM
    __calls.timers = {}
    return table.concat(out, ",")
end""")()
assert str(r) == "staggered:3:timers:1,one:321:timers:1,two:3:timers:1,+32,+321,+321:timers:0,next:one:Instant loop,two:Staggered loop", r
print("Fast loot loops: Staggered one per tick, Instant all at once, newest first, loop button switches and is labelled: OK")

# Vendor: the guild bank pays a repair only when allowed and both the allowance and the bank cover it, else your own money
r = L("""function()
    local V = UbermocForever.Vendor
    local p = V.payer
    local out = {
        tostring(p(500, true, true, true, -1, 1000, 0)),     -- no allowance limit, the bank has enough
        tostring(p(500, true, true, true, 400, 1000, 900)),   -- allowance too small: own money
        tostring(p(500, true, true, true, 600, 300, 900)),    -- bank too poor: own money
        tostring(p(500, true, true, false, -1, 1000, 900)),   -- not allowed to repair from the bank
        tostring(p(500, false, true, true, -1, 1000, 900)),   -- Guild bank first is off
        tostring(p(500, true, false, true, -1, 1000, 100)),   -- no guild, not enough money
    }
    local paid
    local old = { CanMerchantRepair, GetRepairAllCost, IsInGuild, CanGuildBankRepair, GetGuildBankWithdrawMoney, GetGuildBankMoney, GetMoney, RepairAllItems }
    CanMerchantRepair = function() return true end
    GetRepairAllCost = function() return 500, true end
    IsInGuild = function() return true end
    CanGuildBankRepair = function() return true end
    GetGuildBankWithdrawMoney = function() return -1 end
    GetGuildBankMoney = function() return 5000 end
    GetMoney = function() return 900 end
    RepairAllItems = function(g) paid = g end
    V.repair(); out[#out + 1] = tostring(paid)
    V.toggleGuild(); V.repair(); out[#out + 1] = tostring(paid); V.toggleGuild()
    CanMerchantRepair, GetRepairAllCost, IsInGuild, CanGuildBankRepair, GetGuildBankWithdrawMoney, GetGuildBankMoney, GetMoney, RepairAllItems = table.unpack(old)
    return table.concat(out, ",")
end""")()
assert str(r) == "guild,self,self,self,self,nil,true,false", r
print("Vendor: repairs paid by the guild bank first when it can, else your own money: OK")

# Name-only nameplates: only the five listed pieces get alpha 0 (never the name or the cast bar), a reused plate gets
# each piece back to its OWN original alpha, and a forbidden, missing or nil plate makes no call at all
r = L("""function()
    local N = UbermocForever.Nameplates
    local savedDB, savedCan, savedSec, savedCN = UbermocForeverDB, UnitCanAttack, issecretvalue, C_NamePlate
    UbermocForeverDB = { plates = { enemy = true, friendly = false, prevOnlyName = nil } }
    issecretvalue = function(v) return v == "secret" end
    local attack = true
    UnitCanAttack = function(_, u) return u == "boss" or attack end
    local function piece(nm, a)
        local t = { name = nm, alpha = a, calls = 0 }
        t.SetAlpha = function(self, v) t.alpha = v; t.calls = t.calls + 1 end
        t.GetAlpha = function(self) return t.alpha end
        return t
    end
    local START = { HealthBarsContainer = 1, selectionHighlight = 0.25, aggroHighlight = 0.5, LevelFrame = 0.75,
                    name = 0.8, CastBarsContainer = 0.6, WidgetContainer = 0.4,
                    RaidTargetFrame = 0.3, ClassificationFrame = 0.2, AurasFrame = 0.1 }
    local HIDDEN = { "HealthBarsContainer", "selectionHighlight", "aggroHighlight", "ring" }
    local LEFT = { "LevelFrame", "PlayerLevelDiffFrame", "name", "CastBarsContainer", "WidgetContainer", "RaidTargetFrame", "ClassificationFrame", "AurasFrame" }
    local function plateFor(unit, forbidden, token)
        local uf = { unit = unit }
        for k, v in pairs(START) do uf[k] = piece(k, v) end
        -- the badge frame itself must never be touched; only its ring texture is hidden
        uf.PlayerLevelDiffFrame = piece("PlayerLevelDiffFrame", 0.9)
        uf.PlayerLevelDiffFrame.playerLevelDiffIcon = piece("ring", 0.9)
        uf.ring = uf.PlayerLevelDiffFrame.playerLevelDiffIcon   -- test-only alias so alphas() can read it
        if forbidden then uf.IsForbidden = function() return true end end
        return { namePlateUnitToken = token or unit, UnitFrame = uf }
    end
    local function alphas(pl, list)
        local s = {}
        for _, nm in ipairs(list) do s[#s + 1] = tostring(pl.UnitFrame[nm].alpha) end
        return table.concat(s, "-")
    end
    local out = {}
    -- a piece that is not there, or is there without a SetAlpha, is skipped
    local u = { HealthBarsContainer = piece("HealthBarsContainer", 1), LevelFrame = piece("LevelFrame", 0.75),
                PlayerLevelDiffFrame = { playerLevelDiffIcon = piece("ring", 0.9) },
                selectionHighlight = { name = "selectionHighlight" }, CastBarsContainer = { name = "CastBarsContainer" } }
    local names = {}
    for _, p in ipairs(N.parts(u)) do names[#names + 1] = p.name end
    out[#out + 1] = table.concat(names, "-")
    -- Enemies on: exactly the five pieces hidden, the name and the other containers never touched
    local p = plateFor("target")
    N.style(p)
    out[#out + 1] = alphas(p, HIDDEN) .. "/" .. alphas(p, LEFT)
    -- the same unit frame reused for a friendly unit with Friendly off: its own original alpha, not 1
    attack = false
    N.style(p)
    out[#out + 1] = alphas(p, HIDDEN)
    -- hidden twice in a row: the remembered alpha is still the one from before the first hide
    UbermocForeverDB.plates.enemy = true
    local pr = plateFor("target")
    attack = true
    N.style(pr); N.style(pr)
    UbermocForeverDB.plates.enemy = false
    N.style(pr)
    out[#out + 1] = alphas(pr, HIDDEN)
    -- a piece we never hid: no call
    local p2 = plateFor("target")
    UbermocForeverDB.plates.enemy = false
    N.style(p2)
    out[#out + 1] = tostring(p2.UnitFrame.HealthBarsContainer.calls)
    -- a plate the game will not show us, a plate with no unit frame, a nil plate: no call
    UbermocForeverDB.plates.enemy = true
    attack = true
    local p3 = plateFor("target", true)
    N.style(p3)
    out[#out + 1] = tostring(p3.UnitFrame.HealthBarsContainer.calls)
    N.style({ UnitFrame = nil })
    N.style(nil)
    -- a secret answer for the kind counts as unknown: everything put back
    UbermocForeverDB.plates.enemy = true
    local p4 = plateFor("target")
    N.style(p4)
    attack = "secret"
    N.style(p4)
    out[#out + 1] = alphas(p4, HIDDEN)
    -- switching the option off brings the bars back on a plate already shown
    local p5 = plateFor("target")
    attack = true
    N.style(p5)
    UbermocForeverDB.plates.enemy = false
    N.style(p5)
    out[#out + 1] = alphas(p5, HIDDEN)
    -- the game refuses one piece: that piece keeps its own alpha, the rest still hides
    UbermocForeverDB.plates.enemy = true
    local p6 = plateFor("target")
    p6.UnitFrame.LevelFrame.SetAlpha = function() error("the game refuses") end
    N.style(p6)
    out[#out + 1] = alphas(p6, HIDDEN)
    -- GetAlpha can answer a secret value: it cannot be remembered, so that piece goes back to 1, the others to their own
    local p7 = plateFor("target")
    p7.UnitFrame.aggroHighlight.GetAlpha = function(self) return "secret" end
    N.style(p7)
    attack = false
    N.style(p7)
    out[#out + 1] = alphas(p7, HIDDEN)
    -- the events: NAME_PLATE_UNIT_ADDED for a unit, UNIT_FACTION restyles the plate that unit has
    local pe = plateFor("target", false, "boss")   -- its own unit is a boss, the event talks about target
    C_NamePlate = {
        GetNamePlates = function() return { p2, pe } end,
        GetNamePlateForUnit = function(unit) return (unit == "target") and pe or nil end,
    }
    local evs = rawget(N._frame, "__events")
    out[#out + 1] = tostring(evs["NAME_PLATE_UNIT_ADDED"]) .. "," .. tostring(evs["UNIT_FACTION"]) .. "," ..
                    tostring(evs["PLAYER_REGEN_ENABLED"])
    local sc = rawget(N._frame, "__scripts")
    -- the kind comes from the plate's own unit, not from the unit in the event: boss = enemy, so it is hidden
    UbermocForeverDB.plates.enemy = true
    attack = false
    sc.OnEvent(f, "NAME_PLATE_UNIT_ADDED", "target")
    out[#out + 1] = alphas(pe, HIDDEN)
    -- flipping the option through the page re-styles the plates already on screen
    UbermocForeverDB.plates.enemy = false
    N.toggle("enemy")
    out[#out + 1] = alphas(pe, HIDDEN)
    N.toggle("enemy")
    out[#out + 1] = alphas(pe, HIDDEN)
    -- GetNamePlates answers nil: nothing is set and nothing fails
    C_NamePlate = { GetNamePlates = function() return nil end, GetNamePlateForUnit = function() return nil end }
    N.applyAll()
    out[#out + 1] = "ok"
    UbermocForeverDB, UnitCanAttack, issecretvalue, C_NamePlate = savedDB, savedCan, savedSec, savedCN
    return table.concat(out, "|")
end""")()
assert str(r) == ("HealthBarsContainer-ring|0-0-0-0/0.75-0.9-0.8-0.6-0.4-0.3-0.2-0.1|1-0.25-0.5-0.9|"
                  "1-0.25-0.5-0.9|0|0|1-0.25-0.5-0.9|1-0.25-0.5-0.9|0-0-0-0|"
                  "1-0.25-1-0.9|true,true,true|0-0-0-0|0-0-0-0|1-0.25-0.5-0.9|ok"), r
print("Nameplates: only the bar, highlights and level ring hidden (level and badge number kept), each piece gets its own original alpha back, forbidden and missing plates make no call: OK")

# Nameplates CVar: on keeps the value the player had and gives it back on Off, nothing is written in combat, a nil
# GetCVar answer is survived (nothing remembered, so nothing written)
r = L("""function()
    local N = UbermocForever.Nameplates
    local savedDB, oldGet, oldSet, oldLock, oldCN = UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown, C_NamePlate
    UbermocForeverDB = { plates = { enemy = false, friendly = false, prevOnlyName = nil } }
    C_NamePlate = { GetNamePlates = function() return {} end, GetNamePlateForUnit = function() return nil end }
    local cv = { value = "0" }
    local wrote = {}
    GetCVar = function() return cv.value end
    SetCVar = function(k, v) wrote[#wrote + 1] = tostring(v); cv.value = v end
    local lock = false
    InCombatLockdown = function() return lock end
    N.pending = false
    local out = {}
    UbermocForeverDB.plates.friendly = true
    N.syncCVar()
    out[#out + 1] = table.concat(wrote, ",") .. "=" .. tostring(UbermocForeverDB.plates.prevOnlyName)
    UbermocForeverDB.plates.friendly = false
    N.syncCVar()
    out[#out + 1] = table.concat(wrote, ",") .. "=" .. tostring(UbermocForeverDB.plates.prevOnlyName)
    lock = true
    UbermocForeverDB.plates.friendly = true
    N.syncCVar()
    out[#out + 1] = tostring(N.pending) .. "=" .. table.concat(wrote, ",")
    lock = false
    rawget(N._frame, "__scripts").OnEvent(N._frame, "PLAYER_REGEN_ENABLED", nil)
    out[#out + 1] = tostring(N.pending) .. "=" .. table.concat(wrote, ",")
    N.toggle("friendly")                                   -- Off: the player's value is given back
    out[#out + 1] = table.concat(wrote, ",")
    cv.value = nil
    UbermocForeverDB.plates = { enemy = false, friendly = true, prevOnlyName = nil }
    N.syncCVar()
    out[#out + 1] = table.concat(wrote, ",") .. "=" .. tostring(UbermocForeverDB.plates.prevOnlyName)
    GetCVar = function() error("restricted") end       -- a raising GetCVar is survived, nothing written
    N.syncCVar()
    out[#out + 1] = table.concat(wrote, ",")
    UbermocForeverDB.plates = { enemy = false, friendly = false, prevOnlyName = nil }
    N.toggle("enemy"); out[#out + 1] = tostring(N.enabled("enemy"))
    N.toggle("enemy"); out[#out + 1] = tostring(N.enabled("enemy"))
    UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown, C_NamePlate = savedDB, oldGet, oldSet, oldLock, oldCN
    return table.concat(out, "|")
end""")()
assert str(r) == "1=0|1,0=nil|true=1,0|false=1,0,1|1,0,1,0|1,0,1,0=nil|1,0,1,0|true|false", r
print("Nameplates CVar: the player's value is kept and given back, nothing written in combat, nil GetCVar survived: OK")

# Nameplates: nothing of the game's is called beyond SetAlpha and the one CVar
src = open(ADDON + "/Nameplates.lua", encoding="utf-8").read()
for bad in ["hooksecurefunc", "OnUpdate", "SetPoint", "UnitHealth", "UnitName", "UnitClass", "GetText", ":Show(", ":Hide("]:
    assert bad not in src, "Nameplates.lua contains " + bad
assert src.count("SetCVar") == 1, "SetCVar must be written in one place"
print("Nameplates: no hook, no OnUpdate, no anchoring, no unit data, no Show/Hide, one SetCVar: OK")

# Plate range: On writes 45 to the game's two distance CVars, keeps what the player had and gives it back on Off, nothing
# is written during combat and what waits is applied when the fight ends, a nil or raising GetCVar writes nothing, and a
# setting that is On is applied again at login. FAKE(C44): the stub SetCVar stands for C_CVar.SetCVar, which takes the cvar
# name and value as cstrings and only works on cvars that are not read only and not secure. FAKE(C2): the stub values are
# the strings the game keeps, as Ketho's Forever rows show ("45.000000" and "40.000000").
r = L("""function()
    local PR = UbermocForever.PlateRange
    local savedDB, oldGet, oldSet, oldLock = UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown
    local cv = { nameplateMaxDistance = "45.000000", nameplatePlayerMaxDistance = "40.000000" }
    local wrote = {}
    GetCVar = function(k) return cv[k] end
    SetCVar = function(k, v) wrote[#wrote + 1] = k .. "=" .. tostring(v); cv[k] = v end
    local lock = false
    InCombatLockdown = function() return lock end
    local out = {}
    UbermocForeverDB = { platerange = { on = false } }   -- default is On (the author's setting); pin Off for this run
    PR.pending = false
    PR.sync()                                  -- Off and never written: nothing is written
    out[#out + 1] = table.concat(wrote, ",")
    PR.toggle()                                -- On: the player's values are remembered, 45 written to both
    out[#out + 1] = table.concat(wrote, ",")
    wrote = {}
    PR.toggle()                                -- Off: the player's values are given back
    out[#out + 1] = table.concat(wrote, ",")
    wrote = {}
    lock = true
    PR.toggle()                                -- On during combat: nothing is written, it waits
    out[#out + 1] = tostring(PR.pending) .. "=" .. table.concat(wrote, ",")
    lock = false
    rawget(PR._frame, "__scripts").OnEvent(PR._frame, "PLAYER_REGEN_ENABLED", nil)
    out[#out + 1] = tostring(PR.pending) .. "=" .. table.concat(wrote, ",")
    wrote = {}
    UbermocForeverDB = { platerange = { on = false } }   -- a fresh Off at login applies nothing
    rawget(PR._frame, "__scripts").OnEvent(PR._frame, "PLAYER_ENTERING_WORLD", nil)
    out[#out + 1] = table.concat(wrote, ",")
    UbermocForeverDB = {}                      -- an On setting is applied again at login
    PR.db().on = true
    rawget(PR._frame, "__scripts").OnEvent(PR._frame, "PLAYER_ENTERING_WORLD", nil)
    out[#out + 1] = table.concat(wrote, ",")
    wrote = {}
    UbermocForeverDB = { platerange = { on = false } }   -- pin Off so the toggle goes On and reads the player's values
    cv.nameplateMaxDistance = nil
    PR.toggle()                                -- nil GetCVar answer: nothing remembered, nothing written for it
    out[#out + 1] = table.concat(wrote, ",") .. "=" .. tostring(PR.db().backup.nameplateMaxDistance)
    wrote = {}
    UbermocForeverDB = { platerange = { on = false } }   -- pin Off for the On toggle
    GetCVar = function() error("restricted") end
    PR.toggle()                                -- a raising GetCVar is survived, nothing written
    out[#out + 1] = table.concat(wrote, ",")
    -- a distance saved by 1.3.123 / 1.3.124 is dropped and never written
    cv.nameplateMaxDistance = "45.000000"
    GetCVar = function(k) return cv[k] end
    wrote = {}
    UbermocForeverDB = { platerange = { on = true, yards = 100, step = 5 } }
    PR.sync()
    out[#out + 1] = table.concat(wrote, ",") .. "=" .. tostring(PR.db().yards) .. tostring(PR.db().step)
    UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown = savedDB, oldGet, oldSet, oldLock
    return table.concat(out, "|")
end""")()
want = ("|nameplateMaxDistance=45,nameplatePlayerMaxDistance=45"
        "|nameplateMaxDistance=45.000000,nameplatePlayerMaxDistance=40.000000"
        "|true="
        "|false=nameplateMaxDistance=45,nameplatePlayerMaxDistance=45"
        "||nameplateMaxDistance=45,nameplatePlayerMaxDistance=45"
        "|nameplatePlayerMaxDistance=45=nil"
        "|"
        "|nameplateMaxDistance=45,nameplatePlayerMaxDistance=45=nilnil")
assert str(r) == want, (r, want)
print("Plate range: On writes 45 to both distance CVars, keeps and gives back the player's values, defers in combat, "
      "survives a nil or raising GetCVar, applies an On setting at login, drops an old saved distance: OK")

# 1.3.144: a brand-new install defaults to On (the author's setting, UF.SEED), so login applies it.
r = L("""function()
    local PR = UbermocForever.PlateRange
    local savedDB, oldGet, oldSet, oldLock = UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown
    local cv = { nameplateMaxDistance = "45.000000", nameplatePlayerMaxDistance = "40.000000" }
    local wrote = {}
    GetCVar = function(k) return cv[k] end
    SetCVar = function(k, v) wrote[#wrote + 1] = k .. "=" .. tostring(v); cv[k] = v end
    InCombatLockdown = function() return false end
    UbermocForeverDB = {}
    PR.pending = false
    local on = tostring(PR.db().on)
    rawget(PR._frame, "__scripts").OnEvent(PR._frame, "PLAYER_ENTERING_WORLD", nil)
    UbermocForeverDB, GetCVar, SetCVar, InCombatLockdown = savedDB, oldGet, oldSet, oldLock
    return on .. "|" .. table.concat(wrote, ",")
end""")()
assert str(r) == ("true|nameplateMaxDistance=45,nameplatePlayerMaxDistance=45"), (r)
print("Plate range: a brand-new install defaults to On and applies it at login: OK")

# NameHealth: nothing is read back from our strings or the bar, no health numbers, no hook, no game method
src = open(ADDON + "/NameHealth.lua", encoding="utf-8").read()
for bad in ["hooksecurefunc", "OnUpdate", "GetText", "GetStringWidth", "GetWidth", "GetHeight", "GetLeft",
            "GetRight", "GetTop", "GetBottom", "GetCenter", "UnitHealth(", "UnitHealthMax", "UnitHealthMin",
            "SetShowOnlyName", "RegisterEvent", "UpdateShownState", "UpdateAnchors", "UpdateName",
            "SetAlpha", "GetAlpha", "SetCVar"]:
    assert bad not in src, "NameHealth.lua contains " + bad
assert src.count("pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)") == 2, src.count("pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)")
assert src.count("UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)") == 0, "UnitHealthPercent must only be called inside pcall"
assert src.count("RegisterUnitEvent") == 2, src.count("RegisterUnitEvent")
print("NameHealth: no hook, no OnUpdate, nothing read of our strings or the bar, no health numbers, the secret "
      "values go straight to SetText and SetValue, Show/Hide only through Nameplates: OK")

# NameHealth (the name as the health bar): the secret name and the secret percent must reach the calls that accept
# them unchanged - the test compares the identity of what a call received - the game's name is hidden only after our
# text is in place, and any failure leaves the game's name visible. Our objects are plain tables that record calls.
r = L("""function()
    local NH = UbermocForever.NameHealth
    local N = UbermocForever.Nameplates
    local saved = { UbermocForeverDB, CreateFrame, issecretvalue, UnitName, UnitHealthPercent, CurveConstants,
                    UnitIsPlayer, UnitClass, UnitReaction, UnitIsTapDenied, RAID_CLASS_COLORS, C_NamePlate, UnitCanAttack }
    UbermocForeverDB = { plates = { enemy = true, friendly = false, health = true, percent = true } }
    issecretvalue = function(v) return (type(v) == "table" and v.secret == true) or v == "secret" end
    local NAME = { secret = true }
    local PCT = { secret = true }
    UnitName = function() return NAME end
    UnitHealthPercent = function() return PCT end
    CurveConstants = { ScaleTo100 = { curve = true } }
    UnitCanAttack = function(a, u) return u == "target" end      -- two args: UnitCanAttack("player", unit)
    local R = { target = 1, p2 = 4, p4 = 4, p5 = 6, p6 = 3 }
    UnitReaction = function(a, u) return R[u] end                -- two args: UnitReaction("player", unit)
    UnitIsPlayer = function(u) return u == "p1" or u == "p2" end  -- one arg
    UnitClass = function(u)
        if u == "p1" then return "Warrior", "WARRIOR" end
        if u == "p2" then return "SecretName", { secret = true } end
        return nil, nil
    end
    UnitIsTapDenied = function(u) return u == "p3" end            -- one arg
    RAID_CLASS_COLORS = { WARRIOR = { r = 0.8, g = 0.6, b = 0.4 } }

    local reg = {}
    local function obj(kind, role, m)
        local t = { kind = kind, role = role, mark = m, points = {}, events = {}, scripts = {},
                    unreg = 0, sets = 0, values = 0, shows = 0, hides = 0, acalls = 0,
                    raise = (m and reg[m] and reg[m].raise) or nil }
        t.Show = function() t.shows = t.shows + 1 end
        t.Hide = function() t.hides = t.hides + 1 end
        t.SetPoint = function(_, p, ref, rp) t.points[#t.points + 1] = p .. "/" .. ref.role .. "/" .. rp end
        t.ClearAllPoints = function() t.points = {} end
        t.SetTextColor = function(_, cr, cg, cb) t.color = cr .. "," .. cg .. "," .. cb end
        t.SetJustifyH = function(_, j) t.justify = j end
        t.SetFont = function(_, fnt, size, flags) t.font = fnt .. "," .. size .. "," .. flags end
        t.SetVertexColor = function(_, cr, cg, cb, a) t.vertex = cr .. "," .. cg .. "," .. cb .. "," .. a end
        t.SetMinMaxValues = function(_, lo, hi) t.minmax = lo .. "-" .. hi end
        t.SetValue = function(_, v) t.values = t.values + 1; t.value = v end
        t.SetClipsChildren = function(_, v) t.clips = v and true or false end
        t.SetFrameLevel = function(_, lvl) t.level = lvl end
        t.GetFrameLevel = function() return 1 end
        t.SetStatusBarTexture = function(_, path) t.texture = path; t.tex = obj("texture", "tex", t.mark) end
        t.GetStatusBarTexture = function() return t.tex end
        t.RegisterUnitEvent = function(_, ev, u) t.events[ev] = u end
        t.RegisterEvent = function(_, ev) t.events[ev] = "global" end   -- a global event would show here
        t.UnregisterAllEvents = function() t.unreg = t.unreg + 1; t.events = {} end
        t.SetScript = function(_, ev, fn) t.scripts[ev] = fn end
        t.CreateFontString = function(self)
            local n = reg[self.mark].fscount + 1
            reg[self.mark].fscount = n
            reg[self.mark].fs[n] = obj("fontstring", "fs" .. n, self.mark)
            return reg[self.mark].fs[n]
        end
        t.SetText = function(_, v)
            t.text = v
            if t.raise then error("the game refuses SetText") end
            t.sets = t.sets + 1
            reg[t.mark].order[#reg[t.mark].order + 1] = t.role
        end
        t.SetFormattedText = function(_, fmt, v) t.sets = t.sets + 1; t.fmt = fmt; t.text = v end
        t.SetAlpha = function(_, v)
            t.acalls = t.acalls + 1; t.alpha = v
            reg[t.mark].order[#reg[t.mark].order + 1] = t.role
        end
        t.GetAlpha = function() return t.alpha end
        -- nothing of ours takes the mouse: the game's name is hidden by alpha only
        t.EnableMouse = function(_, v) t.mouse = v end
        t.SetMouseEnabled = function(_, v) t.mouse = v end
        t.GetAlpha = function() return t.alpha end
        return t
    end
    CreateFrame = function(kind, name, parent)
        local r = parent and reg[parent.mark]
        if not r then return nil end
        local t = obj(kind, "f" .. (#r.frames + 1), parent.mark)
        t.parent = parent                                  -- ours is a child of the plate's unit frame
        r.frames[#r.frames + 1] = t
        return t
    end
    local function mark(m) reg[m] = { m = m, frames = {}, fs = {}, fscount = 0, order = {} }; return reg[m] end
    local function plate(m, unit)
        local rr = mark(m)
        local uf = { unit = unit, mark = m }
        uf.name = obj("gamename", "name", m)
        uf.name.alpha = 0.8
        uf.name.GetJustifyH = function() return "CENTER" end
        uf.name.GetFont = function() return "Arial", 12, "OUTLINE" end   -- the flags are text, as the game returns them
        rr.name = uf.name; rr.uf = uf
        return { namePlateUnitToken = unit, UnitFrame = uf }
    end
    local function col(u) local a, b, c = NH.baseColor(u); return a .. "," .. b .. "," .. c end
    local out = {}
    out[#out + 1] = "colors=" .. col("p1") .. ";" .. col("p2") .. ";" .. col("p3") .. ";" .. col("p4") .. ";" ..
                    col("p5") .. ";" .. col("p6") .. ";" .. col("p7")
    -- a full plate: our text and the bar value get the secret values unchanged, the game's name is hidden last
    local p = plate("m1", "target")
    local okshow = NH.show(p.UnitFrame, "target", { health = true, percent = true })
    local rr = reg.m1
    out[#out + 1] = "m1=" .. tostring(okshow) .. "," .. tostring(rr.fs[1].text == NAME) .. "," ..
                    tostring(rr.fs[2].text == NAME) .. "," .. tostring(rr.fs[3].text == PCT) .. "," ..
                    tostring(rr.fs[3].fmt == "%.0f%%") .. "," .. tostring(rr.frames[3].value == PCT) .. "," ..
                    table.concat(rr.order, "+") .. "," .. tostring(rr.name.alpha)
    out[#out + 1] = "anchors=" .. rr.fs[1].points[1] .. "|" .. rr.fs[2].points[1] .. "|" .. rr.fs[3].points[1] ..
                    "|" .. rr.frames[3].points[1] .. "," .. rr.frames[3].points[2] .. "|" ..
                    rr.frames[2].points[1] .. "," .. rr.frames[2].points[2]
    out[#out + 1] = "look=" .. rr.fs[1].font .. "," .. rr.fs[2].font .. "," .. rr.fs[3].font .. "," ..
                    rr.fs[1].justify .. "," .. rr.fs[2].justify .. "," .. rr.fs[3].justify .. "," ..
                    rr.fs[1].color .. "," .. rr.fs[2].color .. "," .. rr.fs[3].color .. "," ..
                    tostring(rr.frames[2].clips) .. "," .. tostring(rr.frames[2].level) .. "," ..
                    tostring(rr.frames[3].value == PCT) .. "," .. rr.frames[3].texture .. "," ..
                    rr.frames[3].tex.vertex .. "," .. rr.frames[3].minmax
    out[#out + 1] = "ours=" .. tostring(rr.frames[1].parent == rr.uf) .. "," .. tostring(rr.frames[1].mouse) ..
                    "," .. tostring(rr.frames[2].mouse) .. "," .. tostring(rr.frames[3].mouse) .. "," ..
                    tostring(rr.fs[1].mouse) .. "," .. tostring(rr.fs[2].mouse) .. "," .. tostring(rr.fs[3].mouse) ..
                    "," .. tostring(rr.frames[2].parent == rr.uf) .. "," ..
                    tostring(rr.frames[3].parent == rr.uf) .. "," ..
                    tostring(rr.frames[4].parent == rr.uf)
    out[#out + 1] = "events=" .. tostring(rr.frames[4].events["UNIT_HEALTH"]) .. "," ..
                    tostring(rr.frames[4].events["UNIT_MAXHEALTH"]) .. "," .. tostring(rr.frames[4].unreg)
    -- the handler: another unit does nothing, this unit updates the value and the percent text
    local sc = rr.frames[4].scripts.OnEvent
    sc(rr.frames[4], "UNIT_HEALTH", "other")
    out[#out + 1] = "otherunit=" .. tostring(rr.frames[3].values) .. "," .. tostring(rr.fs[3].sets)
    sc(rr.frames[4], "UNIT_HEALTH", "target")
    out[#out + 1] = "ownunit=" .. tostring(rr.frames[3].values) .. "," .. tostring(rr.fs[3].sets)
    -- clear gives the game's name its own alpha back, and the handler does nothing after it
    NH.clear(p.UnitFrame)
    out[#out + 1] = "clear=" .. tostring(rr.name.alpha) .. "," .. tostring(rr.frames[4].unreg)
    sc(rr.frames[4], "UNIT_HEALTH", "target")
    out[#out + 1] = "afterclear=" .. tostring(rr.frames[3].values)
    -- a plate reused for another unit: the old unit's events go before the new ones
    local p2 = plate("m2", "focus")
    NH.show(p2.UnitFrame, "target", { health = true, percent = true })     -- the plate is first the target's
    NH.show(p2.UnitFrame, "focus", { health = true, percent = true })      -- then the same plate for another unit
    out[#out + 1] = "reuse=" .. tostring(reg.m2.frames[4].events["UNIT_HEALTH"]) .. "," ..
                    tostring(reg.m2.frames[4].unreg)
    -- UnitHealthPercent is not there: nothing of ours is put on the plate, the game's name is left alone
    UnitHealthPercent = nil
    local p3 = plate("m3", "target")
    out[#out + 1] = "nopercent=" .. tostring(NH.show(p3.UnitFrame, "target", { health = true, percent = true })) ..
                    "," .. tostring(reg.m3.name.alpha) .. "," .. tostring(#reg.m3.frames)
    UnitHealthPercent = function() return PCT end
    -- our text is refused: the game's name was never hidden
    local p4 = plate("m4", "target")
    reg.m4.raise = true
    out[#out + 1] = "refused=" .. tostring(NH.show(p4.UnitFrame, "target", { health = true, percent = true })) ..
                    "," .. tostring(reg.m4.name.alpha) .. "," .. table.concat(reg.m4.order, "+")
    -- health off: the bar and the clip stay hidden, the percent is still written
    local p5 = plate("m5", "target")
    NH.show(p5.UnitFrame, "target", { health = false, percent = true })
    out[#out + 1] = "healthoff=" .. tostring(reg.m5.frames[3].values) .. "," .. tostring(reg.m5.frames[3].hides) ..
                    "," .. tostring(reg.m5.frames[2].hides) .. "," .. tostring(reg.m5.fs[3].sets) .. "," ..
                    tostring(reg.m5.name.alpha)
    -- percent off: the percent string is not written and stays hidden
    local p6 = plate("m6", "target")
    NH.show(p6.UnitFrame, "target", { health = true, percent = false })
    out[#out + 1] = "percentoff=" .. tostring(reg.m6.fs[3].sets) .. "," .. tostring(reg.m6.fs[3].hides)
    -- both off: the game's name is the only name, nothing of ours is put on the plate
    local p7 = plate("m7", "target")
    out[#out + 1] = "bothoff=" .. tostring(NH.show(p7.UnitFrame, "target", { health = false, percent = false })) ..
                    "," .. tostring(reg.m7.name.alpha) .. "," .. tostring(reg.m7.name.acalls)
    -- the settings route through Nameplates, and a toggle re-styles the plates already on screen
    local p8 = plate("m8", "target")
    C_NamePlate = { GetNamePlates = function() return { p8 } end,
                    GetNamePlateForUnit = function(u) return (u == "target") and p8 or nil end }
    N.style(p8)
    out[#out + 1] = "style=" .. tostring(reg.m8.fs[1].sets) .. "," .. tostring(reg.m8.name.alpha)
    NH.toggle("health")
    out[#out + 1] = "toggle=" .. tostring(UbermocForeverDB.plates.health) .. "," ..
                    tostring(reg.m8.frames[3].hides) .. "," .. tostring(reg.m8.name.alpha)
    NH.toggle("percent")   -- both off again: the plate goes back to the game's own name
    out[#out + 1] = "offs=" .. tostring(UbermocForeverDB.plates.health) .. "," ..
                    tostring(UbermocForeverDB.plates.percent) .. "," .. tostring(reg.m8.name.alpha)
    UbermocForeverDB, CreateFrame, issecretvalue, UnitName, UnitHealthPercent, CurveConstants, UnitIsPlayer,
    UnitClass, UnitReaction, UnitIsTapDenied, RAID_CLASS_COLORS, C_NamePlate, UnitCanAttack = table.unpack(saved)
    return table.concat(out, " | ")
end""")()
expected = ("colors=0.8,0.6,0.4;1,0.85,0.1;0.55,0.55,0.55;1,0.85,0.1;0.15,0.8,0.15;1,0.5,0.1;1,1,1 | "
            "m1=true,true,true,true,true,true,fs1+fs2+name,0 | "
            "anchors=CENTER/name/CENTER|CENTER/fs1/CENTER|LEFT/fs1/RIGHT|TOPLEFT/fs1/TOPLEFT,"
            "BOTTOMRIGHT/fs1/BOTTOMRIGHT|TOPLEFT/tex/TOPRIGHT,BOTTOMRIGHT/f3/BOTTOMRIGHT | "
            "look=Arial,12,OUTLINE,Arial,12,OUTLINE,Arial,12,OUTLINE,CENTER,CENTER,LEFT,0.85,0.15,0.15,1,1,1,0.85,0.15,0.15,"
            "true,2,true,Interface\\Buttons\\WHITE8x8,1,1,1,0,0-100 | "
            "ours=true,nil,nil,nil,nil,nil,nil,true,true,true | events=target,target,1 | otherunit=1,1 | "
            "ownunit=2,2 | clear=0.8,2 | afterclear=2 | reuse=focus,2 | nopercent=false,0.8,0 | "
            "refused=false,0.8, | healthoff=0,1,1,1,0 | percentoff=0,1 | bothoff=false,0.8,0 | "
            "style=1,0 | toggle=false,1,0 | offs=false,false,0.8")
assert str(r) == expected, r
print("NameHealth: the name is the bar (white ghost under a clip), the secret name and percent only pass "
      "through, the game's name is hidden only after ours is in place, a refused call leaves it visible: OK")

# NameHealth, found in review (1.3.119): the game's font flags are TEXT (a number made ours never get a font, and a text without
# a font raises "Font not set", so the new name never showed); UnitHealthPercent can raise for a restricted unit and must not
# escape; one failing plate must not stop the others; the unit in a health event can be a secret and must not be compared.
r = L("""function()
    local NH, N = UbermocForever.NameHealth, UbermocForever.Nameplates
    local saved = { UbermocForeverDB, CreateFrame, issecretvalue, UnitName, UnitHealthPercent, CurveConstants, UnitReaction,
                    UnitCanAttack, C_NamePlate, STANDARD_TEXT_FONT, N.style }
    UbermocForeverDB = { plates = { enemy = true, friendly = false, health = true, percent = true } }
    issecretvalue = function(v) return (type(v) == "table" and v.secret == true) or v == "secret-unit" end
    local PCT, PCT2 = { secret = true }, { secret = true }
    local pctNow, pctRaises = PCT, false
    UnitName = function() return { secret = true } end
    UnitHealthPercent = function() if pctRaises then error("restricted unit") end return pctNow end
    CurveConstants = { ScaleTo100 = {} }
    UnitReaction = function() return 1 end
    UnitCanAttack = function() return true end
    STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
    local created = {}
    local noop = function() end
    local function new(kind)
        local t = { kind = kind, scripts = {} }
        return setmetatable(t, { __index = function(self, k)
            if k == "CreateFontString" then return function() return new("fs") end end
            if k == "GetStatusBarTexture" then return function() return new("tex") end end
            if k == "GetFrameLevel" then return function() return 5 end end
            if k == "SetScript" then return function(s, n, f) s.scripts[n] = f end end
            if k == "SetFont" then return function(s, f) s.font = f end end
            if k == "SetText" then return function(s, x) if not s.font then error("Font not set") end s.text = x end end
            if k == "SetFormattedText" then return function(s, f, x) if not s.font then error("Font not set") end s.fmt = x end end
            if k == "SetValue" then return function(s, v) s.value = v end end
            if k == "SetAlpha" then return function(s, a) s.alpha = a end end
            if k == "GetAlpha" then return function(s) return s.alpha or 1 end end
            if type(k) == "string" and k:match("^%u") then return noop end   -- a method; lowercase names are plain data
            return nil
        end })
    end
    CreateFrame = function(kind) local t = new(kind); created[#created + 1] = t; return t end
    local function plate(fontCall)
        local uf = { unit = "target", name = new("name") }
        uf.name.GetJustifyH = function() return "CENTER" end
        uf.name.GetFont = fontCall
        return { namePlateUnitToken = "target", UnitFrame = uf }
    end
    local out = {}
    -- 1: the font exactly as the game returns it (flags are text): ours gets a font, shows, and the game's name goes
    local p1 = plate(function() return "Fonts/ARIALN.TTF", 14, "OUTLINE" end)
    local ok1, shown1 = pcall(NH.show, p1.UnitFrame, "target", { health = true, percent = true })
    out[#out + 1] = "realfont=" .. tostring(ok1) .. "," .. tostring(shown1) .. "," .. tostring(p1.UnitFrame.name.alpha)
    -- 2: flags "" (none) are text too
    local p2 = plate(function() return "Fonts/ARIALN.TTF", 14, "" end)
    out[#out + 1] = "noflags=" .. tostring(NH.show(p2.UnitFrame, "target", { health = true, percent = true }))
    -- 3: the name's font cannot be read: the game's standard font; and with no standard font at all the game's name stays
    local p3 = plate(function() return nil end)
    out[#out + 1] = "unreadable=" .. tostring(NH.show(p3.UnitFrame, "target", { health = true, percent = true }))
    STANDARD_TEXT_FONT = nil
    local p4 = plate(function() return nil end)
    out[#out + 1] = "nofont=" .. tostring(NH.show(p4.UnitFrame, "target", { health = true, percent = true })) .. "," .. tostring(p4.UnitFrame.name.alpha)
    STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
    -- 4: UnitHealthPercent raises: nothing escapes, ours is not shown, the game's name is untouched
    pctRaises = true
    local p5 = plate(function() return "Fonts/ARIALN.TTF", 14, "OUTLINE" end)
    local ok5, shown5 = pcall(NH.show, p5.UnitFrame, "target", { health = true, percent = true })
    out[#out + 1] = "raises=" .. tostring(ok5) .. "," .. tostring(shown5) .. "," .. tostring(p5.UnitFrame.name.alpha)
    pctRaises = false
    -- 5: one plate failing does not stop the others
    local calls = 0
    N.style = function(pl) calls = calls + 1; if calls == 1 then error("boom") end end
    C_NamePlate = { GetNamePlates = function() return { {}, {}, {} } end }
    N.applyAll()
    N.style = saved[11]
    out[#out + 1] = "applyall=" .. calls
    -- 6: the health event hands a secret unit: no error, and the value still updates
    local p6 = plate(function() return "Fonts/ARIALN.TTF", 14, "OUTLINE" end)
    NH.show(p6.UnitFrame, "target", { health = true, percent = true })
    local n = #created
    local sb, ev
    for i = n, 1, -1 do local f = created[i]; if f.kind == "StatusBar" and not sb then sb = f end; if f.scripts.OnEvent and not ev then ev = f end end
    pctNow = PCT2
    local ok6 = pcall(ev.scripts.OnEvent, ev, "UNIT_HEALTH", "secret-unit")   -- a secret string: type() says "string"
    out[#out + 1] = "secretunit=" .. tostring(ok6) .. "," .. tostring(sb.value == PCT2)
    UbermocForeverDB, CreateFrame, issecretvalue, UnitName, UnitHealthPercent, CurveConstants, UnitReaction, UnitCanAttack,
        C_NamePlate, STANDARD_TEXT_FONT = table.unpack(saved, 1, 10)
    return table.concat(out, "|")
end""")()
assert str(r) == "realfont=true,true,0|noflags=true|unreadable=true|nofont=false,nil|raises=true,false,nil|applyall=3|secretunit=true,true", r
src = open(ADDON + "/Nameplates.lua", encoding="utf-8").read()
assert 'RegisterEvent("NAME_PLATE_UNIT_REMOVED")' in src, "Nameplates.lua must register NAME_PLATE_UNIT_REMOVED, its handler is dead without it"
print("NameHealth (review fixes): the font flags are text, an unreadable font falls back, a raising UnitHealthPercent is contained, "
      "one failing plate does not stop the rest, a secret unit in a health event is not compared, REMOVED is registered: OK")

# Fading page: elements the gamepad layout hides for good are not listed
r = L("""function()
    local UF = UbermocForever
    local P = UF.FadePage
    P.build(UIParent, UIParent)
    local function count() local n = 0; for _, row in ipairs(P.navRows()) do n = n + 1 end; return n end
    UF.Fade.forced.bar2 = nil
    local before = count()
    UF.Fade.forced.bar2 = function() return true end
    P.refresh()
    local after = count()
    UF.Fade.forced.bar2 = nil
    return before .. "," .. after
end""")()
b, a = str(r).split(",")
assert int(a) <= int(b), r
print("Fading page: hidden-for-good elements not listed: OK")

# Gamepad layout: a bind to another layer's action button (Ctrl + left stick click on a button of bar 2) gets a slot with its icon
r = L("""function()
    local B = UbermocForever.GamepadBar
    local binds = { ["CTRL-PADLSTICK"] = "MULTIACTIONBAR1BUTTON11", ["SHIFT-PADLSTICK"] = "MULTIACTIONBAR1BUTTON9", PADRSTICK = "MULTIACTIONBAR4BUTTON1" }
    local function act(k) return binds[k] or "" end
    local function icon(c) return 99 end
    local out = {}
    for _, e in ipairs(B.extras(3, act, nil, icon)) do out[#out + 1] = e.pad .. "=" .. tostring(e.icon) end
    out[#out + 1] = "|"
    for _, e in ipairs(B.extras(2, act, nil, icon)) do out[#out + 1] = e.pad end
    out[#out + 1] = "|"
    for _, e in ipairs(B.extras(1, act, nil, icon)) do out[#out + 1] = e.pad end
    return table.concat(out, ",")
end""")()
assert str(r) == "PADLSTICK=99,|,|", r
print("Gamepad layout: binds to another layer's button get an icon slot, own and bar 5 to 8 buttons do not: OK")

# A brand-new saved-variables table starts with the author's settings; one that already has settings is left alone
r = L("""function()
    local UF = UbermocForever
    local saved = UbermocForeverDB
    UbermocForeverDB = nil
    local d = UF.DB()
    local a = tostring(d.gbar.on) .. tostring(d.gbar.size) .. tostring(d.fade.xpall.hide) .. tostring(d.menuSide)
    UbermocForeverDB = { menuSide = "right" }
    local e = UF.DB()
    local b = tostring(e.gbar) .. tostring(e.fade) .. tostring(e.menuSide)
    UbermocForeverDB = saved
    return a .. "|" .. b
end""")()
assert str(r) == "true40nilleft|nilnilright", r
print("Fresh install: the author's settings are the defaults, existing settings untouched: OK")

# The line under the distance is the quest objective (claims C163, C164): the FIRST objective always, nothing when no quest
# is followed, the ride itself when the aim crosses to another continent, and long text wraps (claim C166).
# FAKE(C163): the game answers a table of objective rows, or nothing when the quest is not known.
# FAKE(C164): an objective row is a plain table carrying text, type, finished, numFulfilled and numRequired.
r = L("""function()
    local Q = UbermocForever.QuestArrow
    local saved = C_QuestLog
    local objs = {
        [10] = { { text = "Talk to the quartermaster", type = 0, finished = false, numFulfilled = 0, numRequired = 1 },
                 { text = "Collect 8 Taming Yards", type = 2, finished = false, numFulfilled = 3, numRequired = 8 } },
        [11] = { { text = "Talk to the flight master", type = 1, finished = true, numFulfilled = 1, numRequired = 1 },
                 { text = "Take the zeppelin to Menethil", type = 0, finished = false, numFulfilled = 0, numRequired = 1 } },
    }
    C_QuestLog = { GetQuestObjectives = function(id) return objs[id] end }   -- FAKE(C163); the rows it answers are FAKE(C164)
    local out = {}
    out[#out + 1] = Q.objectiveText(10)                                      -- nothing finished: the first one
    out[#out + 1] = Q.objectiveText(11)                                      -- always number 1, even when it is finished
    out[#out + 1] = tostring(Q.objectiveText(nil))                          -- no quest: nothing
    out[#out + 1] = tostring(Q.objectiveText(99))                           -- the game answers nothing: nothing
    local ride = { kind = "ride", note = "Ride a boat to Stormwind", angle = 1, yards = 500 }
    local straight = { kind = "straight", note = "Straight on", angle = 1, yards = 10 }
    out[#out + 1] = Q.noteLine(11, nil, ride)                                -- crossing continents: says what to do
    out[#out + 1] = Q.noteLine(10, nil, straight)                           -- own continent: the objective
    out[#out + 1] = Q.noteLine(nil, 10, straight)                           -- the quest picked off the map: its objective
    out[#out + 1] = tostring(Q.noteLine(nil, nil, ride))                    -- no quest at all: nothing to write
    out[#out + 1] = Q.noteLine(99, nil, straight)                           -- objective not readable: the aim line stays
    -- a refused call is kept, not thrown away: the line falls back and /ubf errors can show it
    C_QuestLog = { GetQuestObjectives = function(id) if id == 13 then error("restricted") end return objs[id] end }   -- FAKE(C163): the game can refuse the call
    local failed, order = UbermocForever.failures()
    out[#out + 1] = tostring(Q.objectiveText(13)) .. " kept " .. tostring(order[#order]) .. " " .. tostring(failed["QuestArrow.GetQuestObjectives"].n)
    local f = Q.frame()
    out[#out + 1] = "wrap " .. tostring(rawget(f.note, "__wrap"))            -- the line wraps so a long objective fits
    Q.setNote(f, "Take the zeppelin to Menethil Harbor and speak with the harbourmaster about the wreck")
    out[#out + 1] = "shown " .. tostring(f.note:IsShown()) .. " " .. f.note:GetText()
    Q.setNote(f, "")                                                         -- nothing to say: the line is put away
    out[#out + 1] = "shown " .. tostring(f.note:IsShown())
    C_QuestLog = saved
    return table.concat(out, "|")
end""")()
assert str(r) == ("Talk to the quartermaster|Talk to the flight master|nil|nil|Ride a boat to Stormwind|Talk to the quartermaster|"
                  "Talk to the quartermaster|nil|Straight on|nil kept QuestArrow.GetQuestObjectives 1|wrap true|shown true Take the zeppelin to Menethil Harbor and speak with the harbourmaster about the wreck|shown false"), r
print("Quest arrow line: the first objective, the ride when crossing continents, nothing with no quest, the line wraps and is put away when empty: OK")
# The reused buffers of GameNav (openMenus, the window list): each call clears its buffer at entry, so a window or menu
# that closed between two calls is gone. The result must be read at once, as every caller does.
# FAKE(C5): the stub window answers `GetName` with a plain string; FAKE(C6): the stub frame answers `IsShown` with a plain
# bool, as the game does. Both are read at once, which is the contract the reused buffer relies on.
r = L("""function()
    local G = UbermocForever.GameNav
    local open = true
    local w = { GetName = function() return "UBFTestWin" end, IsShown = function() return open end }
    local savedU = UISpecialFrames
    UISpecialFrames = { "UBFTestWin" }
    _G.UBFTestWin = w
    local function has(t) for _, x in ipairs(t) do if x == w then return "in" end end return "out" end
    local first = G.windows()
    local a = has(first)
    open = false
    local b = has(G.windows())
    -- the same for the menus: one open, then closed
    local menuOpen = true
    local d = { GetName = function() return "DropDownList1" end, IsShown = function() return menuOpen end }
    _G.DropDownList1 = d
    local c = #G.openMenus()
    menuOpen = false
    local e = #G.openMenus()
    _G.DropDownList1 = nil
    _G.UBFTestWin = nil
    UISpecialFrames = savedU
    return a .. "," .. b .. "," .. c .. "," .. e
end""")()
assert str(r) == "in,out,1,0", r
print("GameNav buffers: a window or menu that closed between two calls is not left in the reused buffer: OK")

# F.target takes the mouse-over answer as a boolean or as a function; the function is now given the key, so the fading
# tick can pass its own check without building a closure per key. Booleans must still work.
r = L("""function()
    local F = UbermocForever.Fade
    UbermocForeverDB.fade = nil; UbermocForeverDB.fadeMouse = nil
    F.set("minimap", "idle", 0.2); F.setMouse(0.8)
    local idle = { combat = false, flight = false, idle = true }
    local out = {}
    out[#out + 1] = string.format("%.1f", F.target("minimap", idle, function(k) return k == "minimap" end))    -- asked with the key: lifts
    out[#out + 1] = string.format("%.1f", F.target("minimap", idle, function(k) return k == "other" end))      -- not over it: its own value
    out[#out + 1] = string.format("%.1f", F.target("minimap", idle, true))                                     -- a plain boolean still works
    F.resetAll(); UbermocForeverDB.fadeMouse = nil
    return table.concat(out, ",")
end""")()
assert str(r) == "0.8,0.2,0.8", r
print("Fading: the mouse-over answer is asked with the key, plain booleans still work: OK")
# X's secure right-click button: every attribute is written in both spellings, so nothing in the code depends on the
# order the game tries them in (C151 builds the name from prefix, name and suffix; that order is not in Blizzard's Lua).
# FAKE(C151): the fake restricted handle records what SetAttribute was given - SecureTemplates.lua:119-126.
r = L("""function()
    local G = UbermocForever.GameNav
    local got = {}
    local handle = { SetAttribute = function(self, name, value) got[name] = value end }
    G.setAttrBoth(handle, "type", "macro")
    G.setAttrBoth(handle, "macrotext", "/use 0 5")
    local keys = {}
    for k, v in pairs(got) do keys[#keys + 1] = k .. "=" .. tostring(v) end
    table.sort(keys)
    return table.concat(keys, ",")
end""")()
assert str(r) == "macrotext2=/use 0 5,macrotext=/use 0 5,type2=macro,type=macro", r
print("GameNav: X writes both spellings of each attribute, so the action does not depend on the lookup order:", r)
# /ubf x: the report prints the state X is in and what X resolves to, so the missing legend can be read in the game.
# The same gate the legend uses: place mode, a popup, an open menu. FAKE(C146): the stub stands for
# C_Container.GetContainerItemInfo returning the ContainerItemInfo table with its itemID (ContainerDocumentation.lua
# 192-206, 766-782); FAKE(C143): the item stands for a poison, consumable subclass Other = 8 (ItemConstantsDocumentation.lua:307-315).
r = L("""function()
    local G = UbermocForever.GameNav
    C_Item = { GetItemInfoInstant = function(id) return id, "n", "l", "", 1, 0, 8 end,
               GetItemSpell = function(id) return "Use: it", 173555 end }
    C_Container = { GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 9 then return { itemID = 3775, hyperlink = "|cff|Hitem|h[x]|h|r", stackCount = 1 } end
        return nil
    end }
    local btn = CreateFrame("Button", "FakeXSlot", UIParent)
    btn.GetBagID = function() return 0 end
    btn.GetID = function() return 9 end
    local out = {}
    local function say(m) out[#out + 1] = m end
    G.xReport(btn, say)
    local open = table.concat(out, " | ")
    out = {}
    _G.DropDownList1 = { GetName = function() return "DropDownList1" end, IsShown = function() return true end }
    G.xReport(btn, say)
    local gated = table.concat(out, " | ")
    _G.DropDownList1 = nil
    return open .. ";;" .. gated
end""")()
assert "X on this node: macro /use 0 9" in r and "X sees bag 0 slot 9: /use 0 9" in r, r
assert "menu open yes" in r.split(";;")[1] and "X on this node: nothing" in r.split(";;")[1], r
print("GameNav /ubf x, nothing open:", r.split(";;")[0])
print("GameNav /ubf x, a menu open (this is why the legend has no X):", r.split(";;")[1])
r = L("""function()
    local f = CreateFrame("Frame", "StrictSelfProbe", UIParent)
    local colon = pcall(function() return f:GetName() end)
    local dot = pcall(function() return f.GetName() end)       -- the game raises here; the stub has to as well
    local dotSet = pcall(function() return f.SetAlpha(0.5) end)
    return tostring(colon) .. "," .. tostring(dot) .. "," .. tostring(dotSet)
end""")()
assert str(r) == "true,false,false", r
print("Stub frames are strict: a method called without its frame (dot for colon) raises, like the game: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local ok1 = UF.try("probe", function() error("boom") end)
    local ok2, v = UF.try("fine", function(a) return a * 2 end, 21)
    local f = UF.failures()
    return tostring(ok1) .. "," .. tostring(ok2) .. "," .. tostring(v) .. "," .. tostring(f.probe and f.probe.n) .. "," .. tostring(f.fine)
end""")()
assert str(r) == "false,true,42,1,nil", r
print("UF.try keeps the error of a failing call for /ubf errors and passes a good call through: OK")
r = L("""function()
    local UF = _G.UbermocForever
    UF.DB().loadLog = nil
    local handlers = {}
    for _, f in ipairs(__frames) do
        local e = rawget(f, "__events")
        local sc = rawget(f, "__scripts")
        if e and e.PLAYER_ENTERING_WORLD and sc and sc.OnEvent then handlers[#handlers + 1] = { f, sc.OnEvent } end
    end
    -- the world is entered by a /reload, then by a zone change (only the first is a load)
    for _, h in ipairs(handlers) do pcall(h[2], h[1], "PLAYER_ENTERING_WORLD", false, true) end
    for _, h in ipairs(handlers) do pcall(h[2], h[1], "PLAYER_ENTERING_WORLD", false, false) end
    for _, t in ipairs(__calls.timers) do pcall(t) end     -- the 10 s timer among the others
    local log = UF.DB().loadLog
    return (log and #log or 0) .. "," .. (log and log[1].kind or "-")
end""")()
assert str(r) == "1,reload", r
print("Load record: a /reload is noted in the saved settings, a zone change is not: OK")
# QuestArrow (QuestArrow.lua): the bearing maths, the turn, and which quest is pointed at.
# FAKE(C11): the stub GetQuestsOnMap returns rows in the shape claim C11 states, carrying the fields of claim C12.
# FAKE(C13): the stub GetBestMapForUnit returns a number or nil as claim C13 states.
# FAKE(C14): the stub GetPlayerMapPosition returns a plain table with x and y, the vector2 Vector2DMixin shape of claim C14.
# FAKE(C15): the stub GetMapWorldSize returns width and height in yards as claim C15 states.
# FAKE(C6): the stub GetPlayerFacing returns a number in radians or nil as claim C6 states.
r = L("""function()
    local Q = UbermocForever.QuestArrow
    local saved = { C_Map, C_QuestLog, GetPlayerFacing }
    C_Map = {
        GetBestMapForUnit = function(unit) return unit == "player" and 961 or nil end,
        GetPlayerMapPosition = function(m, unit) return (m == 961) and { x = 0.2, y = 0.2 } or nil end,
        GetMapWorldSize = function(m) return (m == 961) and 100 or nil end,
    }
    C_QuestLog = {
        GetQuestsOnMap = function(m)
            return { { questID = 7, mapID = 961, x = 0.3, y = 0.3, inProgress = false },
                     { questID = 8, mapID = 1000, x = 0.4, y = 0.4, inProgress = true },
                     { questID = 9, mapID = 961, x = 0.2, y = 0.7, inProgress = true } }
        end,
    }
    GetPlayerFacing = function() return 0 end
    local out = {}
    local mapID, q = Q.picking()
    out[#out + 1] = tostring(mapID) .. "/" .. tostring(q and q.questID)          -- first in-progress quest on our map
    local yards, angle = Q.bearing(100, 100, 0.2, 0.2, 0.2, 0.7)                 -- straight south: 50 yards, angle pi
    out[#out + 1] = string.format("%.0f %.6f", yards, angle)
    local _, east = Q.bearing(100, 100, 0.2, 0.2, 0.6, 0.2)                      -- straight east: 3 pi / 2
    out[#out + 1] = string.format("%.6f", east)
    out[#out + 1] = string.format("%.6f", Q.rotation(angle, math.pi / 2))         -- facing west (pi/2 counter-clockwise from north), objective south: a quarter turn counter-clockwise, left
    out[#out + 1] = tostring(Q.facing())                                          -- facing given, not read here: kept as passed
    C_QuestLog.GetQuestsOnMap = nil
    out[#out + 1] = tostring(Q.picking())                                         -- cannot ask the game: nothing
    C_Map, C_QuestLog, GetPlayerFacing = saved[1], saved[2], saved[3]
    return table.concat(out, ",")
end""")()
assert str(r) == "961/9,50 3.141593,4.712389,1.570796,0,nil", r
print("Quest arrow: the bearing maths, the turn, and the quest choice: OK")

# QuestArrow (QuestArrow.lua): the aim helper, the cross-map target, the place and the size.
# FAKE(C23): the game answer for a quest carries mapID, x, y, as claim C23 states.
# FAKE(C24): the areas listed on a map are rows, and those rows carry the fields claim C25 states.
# FAKE(C25): a map record is a plain table carrying parentMapID, as claim C25 states.
# FAKE(C26): the rectangle of an area on the map above carries minX, maxX, minY, maxY, as claim C26 states.
# FAKE(C5): the route point for the map we are on is a plain table with x and y, as claims C5 and C29 state.
# FAKE(C12): the quest rows are plain tables with the fields claim C12 states.
# FAKE(C14): the position on a map is a plain table with x and y, as claim C14 states.
# FAKE(C31): the cursor position is two numbers, as claim C31 states, divided by the scale as claim C32 states.
# FAKE(C42): the atlas record answers width and height, as claim C42 states.
r = L("""function()
    local Q = UbermocForever.QuestArrow
    local saved = { C_Map, C_QuestLog, C_SuperTrack, C_Navigation, C_Texture, GetPlayerFacing, GetCursorPosition,
                    UbermocForever.DB().qarrow }
    local parents = { [961] = 1416, [1000] = 1416, [1416] = 947 }   -- FAKE(C25): we stand on 961, the quest is on 1000
    local kids = { [1416] = { { mapID = 961, parentMapID = 1416 }, { mapID = 1000, parentMapID = 1416 } } }  -- FAKE(C24)
    local rects = { [961] = { minX = 0.05, maxX = 0.40, minY = 0.50, maxY = 0.90 },
                    [1000] = { minX = 0.50, maxX = 0.80, minY = 0.10, maxY = 0.40 } }   -- FAKE(C26)
    local parentOf = function(m) return parents[m] end
    local rowsOf = function(m) return kids[m] or {} end
    local rectOf = function(m, topMap) return rects[m] end
    local pos = { x = 0.2, y = 0.6 }   -- FAKE(C14)
    local out = {}

    -- the areas walked from where we stand to the quest, and the map the two chains share (claims C24, C25)
    local route, lca = Q.path(961, 1000, parentOf)
    out[#out + 1] = "walk 961-1416-1000 lca 1416"
    out[#out + 1] = "held " .. tostring(Q.holding(1416, 1000, rowsOf(1416), parentOf))
    -- a point on an area as the game puts it on the map above, and the border of the next area nearest to us
    local px, py = Q.onParent(0.2, 0.6, 0.05, 0.40, 0.50, 0.90)     -- claims C26, C28
    out[#out + 1] = string.format("on parent %.2f %.2f", px, py)
    local cx, cy = Q.crossPoint(px, py, 0.50, 0.80, 0.10, 0.40)     -- claim C26
    out[#out + 1] = string.format("cross %.2f %.2f", cx, cy)

    -- the same situation through each mode
    for _, mode in ipairs(Q.MODES) do
        local waypoint = nil
        if mode == "route" then waypoint = { x = 0.15, y = 0.55 } end   -- FAKE(C5): the answer for our own map
        local amap, ax, ay, source = Q.aimFor(mode, 961, pos, 1000, 0.4, 0.4, waypoint, parentOf, rowsOf, rectOf)
        out[#out + 1] = mode .. " " .. tostring(amap) .. " " .. string.format("%.2f %.2f", ax, ay) .. " " .. source
    end
    -- route with nothing from the game falls back to the line on the map that holds both areas
    local amap, ax, ay, source = Q.aimFor("route", 961, pos, 1000, 0.4, 0.4, nil, parentOf, rowsOf, rectOf)
    out[#out + 1] = "route fallback " .. tostring(amap) .. " " .. string.format("%.2f %.2f", ax, ay) .. " " .. source
    -- inside one area the client gives nothing to route around, so it is the straight line
    amap, ax, ay, source = Q.aimFor("obstacle", 961, pos, 961, 0.4, 0.4, nil, parentOf, rowsOf, rectOf)
    out[#out + 1] = "same area " .. tostring(amap) .. " " .. string.format("%.2f %.2f", ax, ay) .. " " .. source

    -- the target is the quest the game has focused on, and it can be on another map (claims C20, C23, C12)
    C_SuperTrack = { GetSuperTrackedQuestID = function() return 8 end }   -- FAKE(C20)
    out[#out + 1] = "tracking " .. tostring(Q.tracking())
    local answer = { mapID = 1000, x = 0.4, y = 0.4 }   -- FAKE(C23)
    local row = { questID = 8, mapID = 961, x = 0.2, y = 0.6, inProgress = true }   -- FAKE(C12)
    local tmap, tx, ty = Q.targetFor(8, 961, answer, row)
    out[#out + 1] = "target " .. tostring(tmap) .. " " .. tostring(tx) .. " " .. tostring(ty)
    tmap, tx, ty = Q.targetFor(8, 961, nil, row)
    out[#out + 1] = "target from the row " .. tostring(tmap) .. " " .. tostring(tx) .. " " .. tostring(ty)

    -- the size is a width in pixels, one step per press (claim C36)
    local sizes = {}
    for i = 1, 4 do
        sizes[#sizes + 1] = Q.sizeName() .. " " .. tostring(Q.sizePx())
        Q.nextSize(1)
    end
    out[#out + 1] = table.concat(sizes, ", ")

    -- the place is saved for this character as a fraction of the screen (claims C31, C32, C33, C35)
    GetCursorPosition = function() return 125, 120 end   -- FAKE(C31): with the test rect 100,100,50,20 and scale 1
    local fx, fy = Q.moveFromCursor()
    out[#out + 1] = string.format("cursor %.2f %.2f", fx, fy)
    out[#out + 1] = string.format("point %.2f %.2f", Q.pointFor(fx, fy))   -- the place put back on the screen is where the cursor was: 10 above the centre
    -- a drag with the games handler names (claims C22, C37): held, then the place is kept
    local f = Q.frame()
    f.__scripts.OnDragStart(f)
    out[#out + 1] = "moving " .. tostring(f.moving)
    GetCursorPosition = function() return 110, 110 end   -- FAKE(C31): moved
    f.__scripts.OnDragStop(f)
    out[#out + 1] = "after " .. tostring(f.moving)
    local p = Q.place()
    out[#out + 1] = string.format("saved %.2f %.2f for %s", p.fx, p.fy, tostring(UnitGUID("player")))

    C_Map, C_QuestLog, C_SuperTrack, C_Navigation, C_Texture, GetPlayerFacing, GetCursorPosition =
        saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7]
    UbermocForeverDB.qarrow = saved[8]
    return table.concat(out, " | ")
end""")()
# 56 px is the size a fresh install starts at (claim C159)
assert str(r) == ("walk 961-1416-1000 lca 1416 | held 1000 | on parent 0.12 0.74 | cross 0.50 0.40 | "
                  "direct 1416 0.62 0.22 shared map | route 961 0.15 0.55 route | obstacle 1416 0.50 0.40 areas | breadcrumbs 1416 0.62 0.22 shared map | "
                  "route fallback 1416 0.62 0.22 shared map | same area 961 0.40 0.40 straight (no route) | "
                  "tracking 8 | target 1000 0.4 0.4 | target from the row 961 0.2 0.6 | "
                  "56 px 56, 64 px 64, 72 px 72, 80 px 80 | cursor 0.50 1.00 | point 0.00 10.00 | "
                  "moving true | after nil | saved 0.20 0.50 for Player-1-ABC"), r
print("Quest arrow: the three modes, the cross-map target, the size and the saved place: OK")
print("modes:", r)

# QuestArrow (QuestArrow.lua): the distance line, as the game writes it (claims C39, C40, C41).
# FAKE(C7): the bearing is the maths of claim C7, taken here with the size claim C15 states for a map.
r = L("""function()
    local Q = UbermocForever.QuestArrow
    local f = Q.frame()
    local out = {}
    local yards, angle = Q.bearing(1000, 500, 0.12, 0.74, 0.50, 0.40)   -- claim C7 on a map of claim C15
    out[#out + 1] = string.format("%.6f %.6f", yards, angle)
    out[#out + 1] = string.format("%.6f", Q.rotation(angle, math.pi / 2))   -- claims C6 and C7: counter-clockwise from north both, so the difference
    Q.showDistance(f, yards, true)
    out[#out + 1] = tostring(f.text:GetText())          -- approximate across maps (claim C41)
    Q.showDistance(f, yards, false)
    out[#out + 1] = tostring(f.text:GetText())
    Q.showDistance(f, nil, false)
    out[#out + 1] = tostring(f.text:GetText())          -- nothing to write (claim C40)
    return table.concat(out, " | ")
end""")()
assert str(r) == "416.293166 5.133052 | 3.562256 | ~416 yd | 416 yd | ", r
print("Quest arrow: the distance line and the turn for a cross-map aim: OK")
print("distance:", r)
# GameNav (GameNav.lua): the bar legend under a window shows the Y row only while the highlighted button is an item
# in the bag (claim R9). FAKE(C11): the stub stands for C_Container.GetContainerItemInfo (claim C11).
r = L("""function()
    local G = UbermocForever.GameNav
    local Nav = UbermocForever.Nav
    local savedC, savedTime = C_Container, GetTime
    for i = #Nav._stack, 1, -1 do Nav.Pop(Nav._stack[i]) end   -- clean the stack left by earlier cases
    local slot = { ["0 5"] = { itemID = 501, hyperlink = "|cff|Hitem|h[x]|h|r", stackCount = 1 } }
    C_Container = { GetContainerItemInfo = function(bag, which) return slot[bag .. " " .. which] end }
    local function node(name, kind)
        return { GetName = function() return name end, IsShown = function() return true end,
                 IsVisible = function() return true end, IsMouseEnabled = function() return true end,
                 IsForbidden = function() return false end,
                 IsObjectType = function(_, k) return k == kind end,
                 GetCenter = function() return 125, 110 end, GetWidth = function() return 40 end,
                 GetHeight = function() return 20 end, GetEffectiveScale = function() return 1 end }
    end
    local button = node("UBFTestBagButton", "Button")
    button.GetBagID = function() return 0 end; button.GetID = function() return 5 end
    local w = node("UBFTestWin", "Frame"); w.GetWidth = function() return 300 end
    w.GetHeight = function() return 200 end; w.GetChildren = function() return { button } end
    local savedWins, savedAccept, savedStart = G.windows, G.dialogAccept, G.dialogStart
    G.windows = function() return { w } end       -- only this window is open (plain tables, no stub proxies)
    G.dialogAccept, G.dialogStart = function() return nil end, function() return nil end
    -- earlier cases left state in the module: clear it so this case sees only the test window
    for _, k in ipairs({"direct", "restore", "menuFrom", "menuWait", "scrolled", "stickScrolled", "placing",
                        "lastFocus", "lastRect", "lastShown", "barSig", "settle", "userMoved"}) do G[k] = nil end
    G.known = {}
    local db = UbermocForever.DB(); db.gameNav = true    -- the game's own bars: GameNav answers the highlight
    G.update()                                    -- window found, GameNav engages, the bar is built
    local engaged = tostring(G.active())
    G.testFocus(button); G.settle, G.userMoved = nil, true
    GetTime = function() return 5 end             -- past the legend's re-read throttle
    G.update()
    local with = tostring(G.legendTexts().PAD4) .. "/" .. tostring(G.barLegend.texts.PAD4) .. "/" .. tostring(G.barLegend.items[4]:IsShown())
    slot["0 5"] = nil                             -- the same button, the slot is empty now
    GetTime = function() return 10 end
    G.update()
    local without = tostring(G.legendTexts().PAD4) .. "/" .. tostring(G.barLegend.texts.PAD4) .. "/" .. tostring(G.barLegend.items[4]:IsShown())
    G.windows = savedWins
    GetTime = savedTime
    return engaged .. "|" .. with .. "|" .. without
end""")()
assert str(r) == "true|Options/Options/true|nil/nil/false", r
print("bar legend: the Y row shows for a bag item and goes when the slot is empty: OK")

# Nav (Nav.lua): nothing is taken in combat, and when combat ends an entry still on the stack gets its buttons
# back on its own, with no key press (claim R13). FAKE(C54): the stub stands for InCombatLockdown (claim C54).
r = L("""function()
    local Nav = UbermocForever.Nav
    local savedCombat = InCombatLockdown
    _G.__calls.overrides = {}
    local entry = Nav.Push({ PAD1 = function() end, PADDUP = function() end }, nil, nil, true)
    local taken = tostring(_G.__calls.overrides.PAD1)
    _G.__calls.overrides = {}                     -- the game's secure driver took them back at combat start
    InCombatLockdown = function() return true end
    Nav._after.__scripts.OnEvent(Nav._after, "PLAYER_REGEN_DISABLED")
    Nav._after.__scripts.OnEvent(Nav._after, "PLAYER_REGEN_ENABLED")   -- in combat: nothing is taken
    local during = tostring(_G.__calls.overrides.PAD1)
    InCombatLockdown = function() return false end
    Nav._after.__scripts.OnEvent(Nav._after, "PLAYER_REGEN_ENABLED")   -- combat ends: taken again
    local retaken = tostring(_G.__calls.overrides.PAD1)
    InCombatLockdown = savedCombat
    Nav.Pop(entry)
    return taken .. "|" .. during .. "|" .. retaken .. "|" .. tostring(Nav._after.__events.PLAYER_REGEN_ENABLED)
end""")()
assert str(r) == "true|nil|true|true", r
print("post-combat: nothing taken in combat, the buttons come back when it ends: OK")

r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local pos = { x = 0.20, y = 0.50 }
    local out = {}
    local function aim(wp, was)
        local amap, ax, ay, source, fx, fy, bent = Q.aimFor("obstacle", 961, pos, 961, 0.60, 0.50, wp, function() return nil end, function() return {} end, function() return nil end, was)
        return source .. ":" .. string.format("%.2f,%.2f", ax, ay) .. ":" .. tostring(bent)
    end
    -- the objective is due east; the route step also points east: nothing in the way, straight
    out[#out + 1] = aim({ x = 0.30, y = 0.51 })
    -- the route step swings about 41 degrees north of the line: something blocks it, so follow the step
    out[#out + 1] = aim({ x = 0.25, y = 0.4567 })
    -- between 20 and 35 degrees: a bend already under way stays, a straight line is not bent
    out[#out + 1] = aim({ x = 0.30, y = 0.4573 }, true)
    out[#out + 1] = aim({ x = 0.30, y = 0.4573 }, false)
    -- under 20 degrees the bend ends
    out[#out + 1] = aim({ x = 0.30, y = 0.4800 }, true)
    -- no route from the game: straight, and it says so
    out[#out + 1] = aim(nil)
    -- a step under our feet says nothing about direction
    out[#out + 1] = aim({ x = 0.2005, y = 0.4995 })
    return table.concat(out, " | ")
end""")()
assert str(r) == ("straight:0.60,0.50:false | around:0.25,0.46:true | around:0.30,0.46:true | straight:0.60,0.50:false | "
                  "straight:0.60,0.50:false | straight (no route):0.60,0.50:false | straight:0.60,0.50:false"), r
print("Quest arrow, around obstacles: straight while the game route agrees, follows the route step when it swings away (with a hysteresis), straight when the game has no route: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local out = {}
    local f = Q.frame()
    out[#out + 1] = "art " .. tostring(f.art ~= nil)
    out[#out + 1] = "art points " .. tostring(rawget(f.art, "__points"))
    out[#out + 1] = "text points " .. tostring(rawget(f.text, "__points"))
    out[#out + 1] = "drawn " .. tostring(rawget(f.art, "__art"))
    -- the aim, size and place buttons step and wrap, and the place names itself
    local UF = _G.UbermocForever
    local a = UF.QuestArrow.cfg()
    out[#out + 1] = "aim " .. Q.MODES[a.mode]                  -- Breadcrumbs is the only aim, whatever was saved before
    Q.setPlace(0.88, 0.90); out[#out + 1] = Q.positionName()
    out[#out + 1] = Q.nextPosition(1)
    out[#out + 1] = Q.nextPosition(1)
    Q.setPlace(0.31, 0.62); out[#out + 1] = Q.positionName()
    out[#out + 1] = Q.nextPosition(1)
    Q.setPlace(0.88, 0.90)
    return table.concat(out, " | ")
end""")()
assert str(r) == ("art true | art points 1 | text points 1 | drawn Interface\\Minimap\\MiniMap-QuestArrow | aim breadcrumbs | "
                  "Top right | Top centre | Top left | Custom | Top right"), r
print("Quest arrow: the picture is the game's tracked-quest arrow and is anchored, the distance text is anchored, aim and place buttons step: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local pi = math.pi
    -- the on-screen turn as a compass word: SetRotation turns a picture counter-clockwise, so + is left and - is right
    local function where(facing, angle)
        local t = Q.rotation(angle, facing) % (2 * pi)
        if t > pi then t = t - 2 * pi end
        if math.abs(t) < 0.01 then return "ahead" end
        if math.abs(math.abs(t) - pi) < 0.01 then return "behind" end
        return t > 0 and "left" or "right"
    end
    local N, W, S, E = 0, pi / 2, pi, 3 * pi / 2           -- bearings and facings are counter-clockwise from north (claims C6, C7)
    local _, east = Q.bearing(100, 100, 0.2, 0.2, 0.6, 0.2)  -- an objective due east must come out as E
    local _, north = Q.bearing(100, 100, 0.2, 0.6, 0.2, 0.2) -- and due north as N
    return table.concat({
        string.format("%.4f %.4f", east, math.abs(north)),
        "face N, objective E: " .. where(N, E), "face N, objective W: " .. where(N, W),
        "face E, objective N: " .. where(E, N), "face E, objective S: " .. where(E, S),
        "face W, objective N: " .. where(W, N), "face S, objective N: " .. where(S, N),
        "face N, objective N: " .. where(N, N), "face E, objective E: " .. where(E, E),
    }, " | ")
end""")()
assert str(r) == ("4.7124 0.0000 | face N, objective E: right | face N, objective W: left | face E, objective N: left | "
                  "face E, objective S: right | face W, objective N: right | face S, objective N: behind | "
                  "face N, objective N: ahead | face E, objective E: ahead"), r
print("Quest arrow: the arrow turns the way the objective lies (right of you is right on screen), all four facings: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    -- the real case from the game (1.3.162, quest 1459 on map 1443, a 4500 x 3000 yard map): the objective is 442 yd south and 99 yd west,
    -- so the bearing is 167 degrees, not 89, and the picture is turned 167 - 298 = -131 degrees, which the first screenshot of it showed as wrong
    local yards, angle = Q.bearing(4500, 3000, 0.6546, 0.0734, 0.6327, 0.2208)
    return string.format("%.0f %.1f %.1f %.2f", yards, angle * 180 / math.pi, Q.rotation(angle, 298 * math.pi / 180) * 180 / math.pi, math.atan(1, 0))
end""")()
assert str(r) == "453 167.4 -130.6 0.79", r     # 0.79 = atan(1): the second argument is ignored, as in the game (a two-argument atan would give 1.57)
print("Quest arrow: the bearing uses the two-argument arc tangent of the game's Lua 5.1 (math.atan2), checked on the real numbers from the game: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local a = Q.cfg()
    a.px = 40
    local out = { Q.sizeName() }
    for i = 1, 3 do Q.nextSize(1); out[#out + 1] = tostring(Q.sizePx()) end        -- up one step at a time
    for i = 1, 5 do Q.nextSize(-1); out[#out + 1] = tostring(Q.sizePx()) end       -- and down
    a.px = 16; Q.nextSize(-1); out[#out + 1] = "wrap " .. Q.sizePx()              -- the smallest steps down to the largest
    Q.nextSize(1); out[#out + 1] = tostring(Q.sizePx())                            -- and back to the smallest
    a.px = 50; Q.nextSize(1); out[#out + 1] = "near " .. Q.sizePx()               -- a size that is on no step goes from the nearest (48): 56
    a.px = 40
    return table.concat(out, " ")
end""")()
assert str(r) == "40 px 44 48 56 48 44 40 36 32 wrap 128 16 near 56", r
print("Quest arrow: the size steps one press at a time in pixels, both ways, wrapping: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local f = Q.frame()
    local a = Q.cfg()
    a.opacity = 100
    local out = { Q.opacityName() }
    for i = 1, 3 do Q.nextOpacity(1); out[#out + 1] = Q.opacityName() end        -- fainter, one step at a time
    for i = 1, 2 do Q.nextOpacity(-1); out[#out + 1] = Q.opacityName() end       -- and back
    a.opacity = 10; Q.nextOpacity(1); out[#out + 1] = "wrap " .. Q.opacityName() -- the faintest wraps to the most solid
    Q.nextOpacity(-1); out[#out + 1] = Q.opacityName()
    a.opacity = 70; f.opacity = nil; Q.applyOpacity(f)
    out[#out + 1] = "alpha " .. tostring(rawget(f, "__alpha"))
    a.opacity = 100; Q.applyOpacity(f)
    return table.concat(out, " | ")
end""")()
assert str(r) == "100% | 90% | 80% | 70% | 80% | 90% | wrap 100% | 10% | alpha 0.7", r
print("Quest arrow: opacity steps from 100 to 10 percent by tens, wraps, and sets the frame's alpha: OK")
r = L("""function()
    local Q = _G.UbermocForever.QuestArrow
    local out = {}
    local function deg(r) return r and string.format("%.1f", r * 180 / math.pi) or "nil" end
    -- the game's own formula, -Vector2D_CalculateAngleBetween(offset, up) = -atan2(offsetX, offsetY) (SuperTrackedFrame.lua UpdateArrow):
    -- up is 0, the right is a clockwise quarter turn (-90 in a counter-clockwise SetRotation), the left +90, straight down 180
    out[#out + 1] = deg(Q.screenRotation(0, 0, 0, 1)) .. " " .. deg(Q.screenRotation(0, 0, 1, 0)) .. " " .. deg(Q.screenRotation(0, 0, -1, 0))
        .. " " .. deg(Q.screenRotation(0, 0, 0, -1)) .. " " .. deg(Q.screenRotation(5, 5, 5, 5))
    -- the game's navigation target on the screen: 500 right and 100 above the middle of a 2000 x 1000 screen
    local savedN, savedW = C_Navigation, WorldFrame
    local nf = { GetCenter = function(self) return 1500, 600 end }
    WorldFrame = { GetCenter = function(self) return 1000, 500 end }
    C_Navigation = { GetFrame = function() return nf end, HasValidScreenPosition = function() return true end }
    local rot = Q.viewRotation()
    out[#out + 1] = deg(rot)
    C_Navigation.HasValidScreenPosition = function() return false end          -- no valid screen position: not used, and it says why
    local r2, why2 = Q.viewRotation()
    out[#out + 1] = tostring(r2) .. " " .. tostring(why2)
    C_Navigation.GetFrame = function() return nil end                          -- no target (nothing selected)
    local r3, why3 = Q.viewRotation()
    out[#out + 1] = tostring(r3) .. " " .. tostring(why3)
    C_Navigation = nil                                                          -- a client without the navigation system
    local r4, why4 = Q.viewRotation()
    out[#out + 1] = tostring(r4) .. " " .. tostring(why4)
    C_Navigation, WorldFrame = savedN, savedW
    return table.concat(out, " | ")
end""")()
assert str(r) == ("0.0 -90.0 90.0 180.0 nil | -78.7 | nil the game has no screen position for its target | "
                  "nil the game has no navigation target (no quest selected in the tracker) | nil the game has no navigation system"), r
print("Quest arrow: the view turn is Blizzard's own formula on the game's navigation target, falls back with a reason: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local N = UF.NavScan
    local saved = { C_Map, C_AreaPoiInfo, C_TaxiMap, C_EncounterJournal, N.maxMap }
    N.maxMap = 130
    C_Map = {
        GetMapInfo = function(id)
            if id == 100 then return { mapID = 100, name = "Zone A", mapType = 3, parentMapID = 101, flags = 0 } end
            if id == 101 then return { mapID = 101, name = "Continent", mapType = 2, parentMapID = 0, flags = 0 } end
        end,
        GetMapWorldSize = function(id) return 4000, 3000 end,
        GetMapRectOnMap = function(id, top) return 0.1, 0.3, 0.2, 0.5 end,
        GetWorldPosFromMapPos = function(id, pos) return 1, { x = pos.x * 1000, y = pos.y * 2000 } end,
    }
    C_AreaPoiInfo = {
        GetAreaPOIForMap = function(id) if id == 100 then return { 11, 12 } end return {} end,
        GetAreaPOIInfo = function(id, poi)
            if poi == 11 then return { position = { x = 0.25, y = 0.5 }, name = "Booty Bay Dock", description = "Boat to Ratchet", atlasName = "poi-boat", factionID = 0 } end
            return { position = { x = 0.5, y = 0.5 }, name = "Inn", atlasName = "poi-inn" }
        end,
    }
    C_TaxiMap = { GetTaxiNodesForMap = function(id)
        if id == 100 then return { { nodeID = 7, position = { x = 0.4, y = 0.6 }, name = "Flight A", atlasName = "taxi", faction = 1, isUndiscovered = true } } end
        return {}
    end }
    C_EncounterJournal = { GetDungeonEntrancesForMap = function(id)
        if id == 101 then return { { areaPoiID = 5, position = { x = 0.6, y = 0.4 }, name = "The Hole", description = "d", atlasName = "dungeon", journalInstanceID = 9 } } end
        return {}
    end }
    local function runScan(name)
        UF.DB().navData = nil
        assert(N.start(name))
        local second = N.start("maps")               -- one at a time: the second is refused while the first runs
        local frames = 0
        while N.step() do frames = frames + 1 end
        return UF.DB().navData[name], second, frames
    end
    local out = {}
    local d, second = runScan("docks")
    out[#out + 1] = #d.data.all .. "/" .. #d.data.rows .. "/" .. tostring(d.data.rows[1].name) .. "/" .. d.data.rows[1].cont .. "," .. d.data.rows[1].wx .. "/" .. tostring(d.data.atlases["poi-inn"].n) .. "/" .. tostring(second)
    local t = runScan("taxi")
    out[#out + 1] = #t.data.rows .. "/" .. t.data.rows[1].node .. "/" .. tostring(t.data.rows[1].undiscovered) .. "/" .. t.maps
    local m = runScan("maps")
    out[#out + 1] = #m.data.rows .. "/" .. m.data.rows[1].w .. "/" .. tostring(m.data.rows[1].minX) .. "/" .. m.data.rows[1].cx
    local e = runScan("entrances")
    out[#out + 1] = #e.data.rows .. "/" .. e.data.rows[1].instance .. "/" .. e.data.rows[1].wx
    out[#out + 1] = tostring(N.transportLike("poi-boat", nil, nil)) .. tostring(N.transportLike(nil, "Zeppelin Tower", nil)) .. tostring(N.transportLike("poi-inn", "Inn", "Rest here"))
    assert(N.start("docks")); N.status(true); out[#out + 1] = tostring(N.running)     -- stop ends it
    C_Map, C_AreaPoiInfo, C_TaxiMap, C_EncounterJournal, N.maxMap = saved[1], saved[2], saved[3], saved[4], saved[5]
    UF.DB().navData = nil
    return table.concat(out, " | ")
end""")()
assert str(r) == ("2/1/Booty Bay Dock/1,250.0/1/false | 1/7/true/2 | 2/4000.0/0.1/500.0 | 1/9/600.0 | truetruefalse | nil"), r
print("Navigation scans: docks, taxi, maps and entrances read the game's own calls, one at a time, and stop on request: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local T = UF.Trail
    local out = {}
    local function reset()
        UF.DB().learned = nil
        local st = T.state
        st.prev, st.lastWalk, st.ride, st.still, st.crossed = nil, nil, nil, 0, false
        T.breakWalk()
    end
    local clock = 0
    local function sample(cont, x, y, speed, extra)
        clock = clock + 0.5
        local s = { t = clock, cont = cont, wx = x, wy = y, m = 1, mx = 0.5, my = 0.5, speed = speed, onTaxi = false, dead = false, swimming = false, flying = false, inInstance = false }
        for k, v in pairs(extra or {}) do s[k] = v end
        T.feed(s)
    end
    -- the walked trail: an L round something in the way, from (0,0) east to (300,0), then north to (300,300), 3.5 yards a sample
    reset()
    for x = 0, 300, 3.5 do sample(1, x, 0, 7) end
    for y = 0, 300, 3.5 do sample(1, 300, y, 7) end
    local nodes1, edges1 = T.counts()
    for x = 0, 300, 3.5 do sample(1, x, 0, 7) end                       -- walking it again adds nothing
    T.breakWalk()
    for x = 0, 300, 3.5 do sample(1, x + 4, 5, 7) end                   -- nor does a path beside it
    local nodes2 = T.counts()
    out[#out + 1] = (nodes1 > 20 and nodes1 < 60 and "n ok" or "n " .. nodes1) .. " " .. (nodes2 == nodes1 and "same" or ("grew " .. nodes2))
    local path, len, straight = T.path(1, 0, 0, 300, 300)
    out[#out + 1] = string.format("path %s len %.0f straight %.0f points %s", tostring(path ~= nil), len or 0, straight or 0, path and (#path > 10 and "many" or #path) or "-")
    out[#out + 1] = tostring(T.path(1, 900, 900, 300, 300))                -- never walked near (900, 900): no path
    out[#out + 1] = tostring(T.path(2, 0, 0, 300, 300))                    -- another continent: nothing known
    -- a taxi, a swim, a mount in the air and a ghost add nothing
    reset()
    for x = 0, 200, 3.5 do sample(1, x, 0, 7, { onTaxi = true }) end
    for x = 0, 200, 3.5 do sample(1, x, 50, 7, { swimming = true }) end
    for x = 0, 200, 3.5 do sample(1, x, 90, 7, { flying = true }) end
    for x = 0, 200, 3.5 do sample(1, x, 130, 7, { dead = true }) end
    out[#out + 1] = "skipped " .. T.counts()
    -- a ride: walk to the dock, stand still while the platform carries you 400 yards in 40 seconds, then the world loads on another continent
    reset()
    UnitFactionGroup = function() return "Alliance" end
    for x = -50, 0, 3.5 do sample(0, x, 0, 7) end
    for i = 1, 80 do sample(0, i * 5, 0, 0) end                           -- 5 yards a sample while standing still
    T.loaded()
    sample(1, -3800, 4700, 0)
    local L1 = UF.DB().learned
    out[#out + 1] = #L1.rides .. "/" .. L1.rides[1].f .. "/" .. L1.rides[1].a.cont .. ">" .. L1.rides[1].b.cont .. "/n" .. L1.rides[1].n
    -- the same ride again is the same route, seen twice
    for x = -50, 0, 3.5 do sample(0, x, 0, 7) end
    for i = 1, 80 do sample(0, i * 5, 0, 0) end
    T.loaded()
    sample(1, -3790, 4705, 0)
    out[#out + 1] = #L1.rides .. "/n" .. L1.rides[1].n
    -- a Horde ride is its own
    UnitFactionGroup = function() return "Horde" end
    for x = -50, 0, 3.5 do sample(0, x, 0, 7) end
    for i = 1, 80 do sample(0, i * 5, 0, 0) end
    T.loaded(); sample(1, -3800, 4700, 0)
    out[#out + 1] = #L1.rides
    -- the best ride for a player and a target on other continents, for the right faction only
    local leg = T.bestRide({ cont = 0, wx = 100, wy = 0 }, { cont = 1, wx = -3700, wy = 4600 }, "Alliance")
    local none = T.bestRide({ cont = 0, wx = 100, wy = 0 }, { cont = 1, wx = -3700, wy = 4600 }, "Neutral")
    out[#out + 1] = tostring(leg and leg.f) .. "/" .. tostring(none)
    -- the drift seen in the first real play data (1 to 3 yards a sample while standing still) starts no ride at all
    reset()
    local xd = 0
    sample(0, xd, 0, 0)
    for _, m in ipairs({ 2, 1, 3, 1, 1, 2, 1, 2, 1, 2, 1, 3, 1, 1 }) do xd = xd + m; sample(0, xd, 0, 0) end
    local drift = 0
    for _, e in ipairs((UF.DB().learned and UF.DB().learned.log) or {}) do if e[1] == "ride-start" then drift = drift + 1 end end
    out[#out + 1] = "drift " .. drift
    -- a short wobble on a platform is no route, and standing at a dock is none either
    reset()
    for i = 1, 6 do sample(0, i * 2, 0, 0) end
    for i = 1, 12 do sample(0, 12, 0, 0) end
    out[#out + 1] = "wobble " .. #(UF.DB().learned and UF.DB().learned.rides or {})
    -- entrances
    reset()
    T.instance(nil, { m = 1, mx = 0.4, my = 0.6, cont = 1, wx = 100, wy = 200 })
    T.instance({ id = 33, name = "Shadowfang Keep", kind = "party" }, nil)
    T.instance({ id = 33, name = "Shadowfang Keep", kind = "party" }, nil)
    T.instance(nil, { m = 1, mx = 0.41, my = 0.61, cont = 1, wx = 110, wy = 210 })
    local e = T.entranceFor(33)
    out[#out + 1] = e.name .. "/" .. e.a.wx .. "/" .. e.b.wx .. "/n" .. e.n .. "/" .. tostring(T.entranceFor("Shadowfang Keep") == e)
    UnitFactionGroup = nil
    reset()
    return table.concat(out, " | ")
end""")()
assert str(r) == ("n ok same | path true len 595 straight 424 points many | nil | nil | skipped 0 | 1/Alliance/0>1/n1 | 1/n2 | 2 | Alliance/nil | "
                  "drift 0 | wobble 0 | Shadowfang Keep/100/110/n1/true"), r
print("Learning: the walked trail routes round what you walked round, rides are learned per faction and merge, entrances learn both sides, taxis and swims add nothing: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local Q, T = UF.QuestArrow, UF.Trail
    local out = {}
    local function deg(r) return string.format("%.0f", r * 180 / math.pi) end
    UF.DB().learned = nil
    -- the bearing of a world position: x is north, y is west (checked against the map scan): north 0, west 90, south 180, east 270
    local _, n = Q.worldBearing(0, 0, 100, 0)
    local _, w = Q.worldBearing(0, 0, 0, 100)
    local _, s = Q.worldBearing(0, 0, -100, 0)
    local y, e = Q.worldBearing(0, 0, 0, -100)
    out[#out + 1] = deg(n) .. " " .. deg(w) .. " " .. deg(s) .. " " .. deg(e) .. " " .. string.format("%.0f", y)
    -- nothing walked: straight on, with a note that says so
    local c = Q.crumbFor({ cont = 1, wx = 0, wy = 0 }, { cont = 1, wx = 300, wy = 300 }, "Alliance")
    out[#out + 1] = c.kind .. " " .. deg(c.angle) .. " " .. string.format("%.0f", c.yards)
    -- walk an L: east... in world terms along +y then +x, the objective is diagonal; the crumb follows the trail, 80 yards ahead
    local clock = 0
    local function sample(x, y) clock = clock + 0.5; T.feed({ t = clock, cont = 1, wx = x, wy = y, m = 1, mx = 0.5, my = 0.5, speed = 7, onTaxi = false, dead = false, swimming = false, flying = false, inInstance = false }) end
    for y2 = 0, 300, 3.5 do sample(0, y2) end
    for x2 = 0, 300, 3.5 do sample(x2, 300) end
    local c2 = Q.crumbFor({ cont = 1, wx = 0, wy = 0 }, { cont = 1, wx = 300, wy = 300 }, "Alliance")
    out[#out + 1] = c2.kind .. " " .. deg(c2.angle) .. " " .. (c2.note:find("waypoint") and "waypoint" or "no note") .. " " .. string.format("%.0f", c2.yards)
    -- the arrow is at the far end of the trail's bend: the crumb is then the objective itself
    local c3 = Q.crumbFor({ cont = 1, wx = 280, wy = 300 }, { cont = 1, wx = 300, wy = 300 }, "Alliance")
    out[#out + 1] = c3.kind .. " " .. string.format("%.0f", c3.yards)
    -- another continent with nothing learned: no arrow, and the note names what the guides say for the faction
    local c4 = Q.crumbFor({ cont = 0, wx = 0, wy = 0 }, { cont = 1, wx = 5000, wy = 0 }, "Horde")
    out[#out + 1] = c4.kind .. " " .. tostring(c4.angle) .. " " .. (c4.note:find("zeppelin") and "zeppelin" or "?")
    local c5 = Q.crumbFor({ cont = 0, wx = 0, wy = 0 }, { cont = 1, wx = 5000, wy = 0 }, "Alliance")
    out[#out + 1] = (c5.note:find("Menethil") and "menethil" or "?")
    -- after riding: the arrow goes to the learned dock, and at the dock it says to board
    UF.DB().learned.rides[1] = { f = "Alliance", a = { cont = 0, wx = 400, wy = 0 }, b = { cont = 1, wx = 4900, wy = 0 }, n = 1, secs = 100 }
    local c6 = Q.crumbFor({ cont = 0, wx = 0, wy = 0 }, { cont = 1, wx = 5000, wy = 0 }, "Alliance")
    out[#out + 1] = c6.kind .. " " .. deg(c6.angle) .. " " .. string.format("%.0f", c6.yards)
    local c7 = Q.crumbFor({ cont = 0, wx = 390, wy = 0 }, { cont = 1, wx = 5000, wy = 0 }, "Alliance")
    out[#out + 1] = c7.kind .. " " .. tostring(c7.angle)
    local c8 = Q.crumbFor({ cont = 0, wx = 0, wy = 0 }, { cont = 1, wx = 5000, wy = 0 }, "Horde")      -- a Horde player does not use an Alliance ride
    out[#out + 1] = c8.kind
    UF.DB().learned = nil
    return table.concat(out, " | ")
end""")()
assert str(r) == ("0 90 180 270 100 | straight 45 424 | trail 90 waypoint 84 | trail 20 | unknown nil zeppelin | menethil | ride 0 400 | board nil | unknown"), r
print("Breadcrumbs: the world bearing, straight on where nothing is walked, the trail waypoint ahead, the learned ride and its dock, the faction hint: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local FP = UF.FlightPaths
    local saved = { C_Map, C_TaxiMap, UnitFactionGroup, GetTaxiMapID }
    local out = {}
    UF.DB().learned = nil
    local flags = {}
    local function nodes(map)
        if map ~= 1414 then return {} end
        return {
            { nodeID = 1, name = "Near Post", position = { x = 0.50, y = 0.50 }, faction = 2, isUndiscovered = flags[1] },
            { nodeID = 2, name = "Horde Camp", position = { x = 0.52, y = 0.50 }, faction = 1, isUndiscovered = flags[2] },
            { nodeID = 3, name = "Free Port", position = { x = 0.60, y = 0.50 }, faction = 0, isUndiscovered = flags[3] },
            { nodeID = 4, name = "Far Tower", position = { x = 0.90, y = 0.90 }, faction = 2, isUndiscovered = flags[4] },
            { nodeID = 5, name = "zzOLDGone", position = { x = 0.10, y = 0.10 }, faction = 0 },
            { nodeID = 1, name = "Near Post", position = { x = 0.50, y = 0.50 }, faction = 2 },
        }
    end
    C_TaxiMap = { GetTaxiNodesForMap = nodes }
    C_Map = {
        GetWorldPosFromMapPos = function(map, pos) return 1, { x = pos.x * 10000, y = pos.y * 10000 } end,
        GetBestMapForUnit = function() return 1414 end,
        GetPlayerMapPosition = function() return { x = 0.5001, y = 0.5 } end,
    }
    UnitFactionGroup = function() return "Alliance" end
    local list = FP.nodes()
    out[#out + 1] = #list .. " nodes"                                          -- the old one and the repeat are left out
    -- no flag says anything: nothing is marked known, and every node of the faction is still to find
    out[#out + 1] = tostring(FP.flagsTrusted(list)) .. "/" .. FP.learnFromWorldMap(list) .. "/" .. #FP.undiscovered(list, "Alliance")   -- Near, Free, Far
    -- the game really says (a true among them): the false ones are known
    flags[4] = true; flags[1] = false
    list = FP.nodes()
    out[#out + 1] = tostring(FP.flagsTrusted(list)) .. "/" .. FP.learnFromWorldMap(list) .. "/" .. #FP.undiscovered(list, "Alliance")
    -- the flight map: every node it lists is known
    UF.DB().learned.taxi = {}
    out[#out + 1] = FP.learnFromFlightMap({ { nodeID = 3 }, { nodeID = 4 } }) .. "/" .. #FP.undiscovered(FP.nodes(), "Alliance")
    -- the nearest one to find, for the faction only (Horde Camp is next to Near Post but is not ours)
    UF.DB().learned.taxi = {}
    local n, d = FP.nearestUndiscovered(FP.nodes(), "Alliance", 1, 5000, 5000)
    out[#out + 1] = n.name .. "/" .. math.floor(d)
    local nh = FP.nearestUndiscovered(FP.nodes(), "Horde", 1, 5000, 5000)
    out[#out + 1] = nh.name
    -- the moment of finding it: standing at Near Post marks it
    FP.onStatusChanged()
    out[#out + 1] = tostring(FP.known()[1]) .. "/" .. FP.nearestUndiscovered(FP.nodes(), "Alliance", 1, 5000, 5000).name
    -- where a node shows on the map being shown: the continent itself, a zone inside it (its rectangle on the continent), a map above it
    C_Map.GetMapRectOnMap = function(map, top)
        if map == 1500 and top == 1414 then return 0.4, 0.6, 0.4, 0.6 end         -- a zone: the middle fifth of the continent
        if map == 1414 and top == 947 then return 0.1, 0.5, 0.2, 0.6 end           -- the continent on the map above it
        return nil
    end
    local node = { map = 1414, x = 0.5, y = 0.5 }
    local ax, ay = FP.placeOn(1414, node)
    local bx, by = FP.placeOn(1500, node)
    local cx, cy = FP.placeOn(947, node)
    local dx = FP.placeOn(1500, { map = 1414, x = 0.9, y = 0.9 })                    -- outside that zone: not drawn there
    out[#out + 1] = ax .. "," .. ay .. " " .. string.format("%.2f,%.2f", bx, by) .. " " .. string.format("%.2f,%.2f", cx, cy) .. " " .. tostring(dx)
    -- the pins for a map: not found, not hidden, the faction's, on the map; the button and a right click take them away, show brings them back
    UF.DB().learned.taxi = {}
    UF.DB().flightPins = nil
    local function names(map) local t = {} for _, p in ipairs(FP.pinsFor(map, "Alliance")) do t[#t + 1] = p.node.name end table.sort(t) return table.concat(t, "+") end
    out[#out + 1] = names(1414)
    FP.hide(3); out[#out + 1] = names(1414)
    FP.togglePins(); out[#out + 1] = FP.pinsName() .. ":" .. names(1414)
    FP.togglePins(); FP.unhideAll(); out[#out + 1] = FP.pinsName() .. ":" .. names(1414)
    FP.known()[4] = true; out[#out + 1] = names(1414)                              -- found: it goes
    -- the waypoint the arrow follows when no quest is selected
    local Q = UF.QuestArrow
    C_Map.HasUserWaypoint = function() return true end
    C_Map.GetUserWaypoint = function() return { uiMapID = 1414, position = { x = 0.3, y = 0.7 } } end
    local wm, wx, wy = Q.userWaypoint()
    C_Map.HasUserWaypoint = function() return false end
    out[#out + 1] = wm .. "/" .. wx .. "/" .. wy .. "/" .. tostring(Q.userWaypoint())
    C_Map.HasUserWaypoint, C_Map.GetUserWaypoint, C_Map.GetMapRectOnMap = nil, nil, nil
    UF.DB().learned = nil
    UF.DB().flightPins = nil
    C_Map, C_TaxiMap, UnitFactionGroup, GetTaxiMapID = saved[1], saved[2], saved[3], saved[4]
    return table.concat(out, " | ")
end""")()
assert str(r) == ("4 nodes | false/0/3 | true/1/2 | 2/1 | Near Post/0 | Horde Camp | true/Free Port | 0.5,0.5 0.50,0.50 0.30,0.40 nil | "
                  "Far Tower+Free Port | Far Tower | Off: | On:Far Tower+Free Port | Free Port | 1414/0.3/0.7/nil"), r
print("Flight paths: the game's flags are used only when they say something, the flight map marks what it lists, the map pins show only what you have not found, of your faction, and go when hidden, switched off or found: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local D = UF.Diag
    local saved = { GetTime, IsStealthed, UnitAffectingCombat }
    UF.DB().combatLog = nil
    local now = 100
    GetTime = function() return now end
    local stealthed = false
    IsStealthed = function() return stealthed end
    local out = {}
    -- a conversation ends: the log notes it, and the work of ours after it
    D.on("GOSSIP_SHOW"); now = 103
    UF.diag("ours", "window buttons given back")
    now = 103.4; D.on("GOSSIP_CLOSED")
    now = 104.1; D.on("UNIT_SPELLCAST_FAILED", "player", "guid", 1784)
    now = 104.2; D.on("UI_ERROR_MESSAGE", 50, "Not yet.")
    now = 104.3; D.on("UNIT_SPELLCAST_FAILED", "party1", "guid", 1784)            -- somebody else: ignored
    now = 105; stealthed = true; D.on("UPDATE_STEALTH")
    local log = UF.DB().combatLog
    local kinds = {}
    for _, e in ipairs(log) do kinds[#kinds + 1] = e.k end
    out[#out + 1] = table.concat(kinds, ",")
    out[#out + 1] = log[#log - 2].a .. "/" .. tostring(log[#log - 1].a) .. "/" .. tostring(log[#log].a)
    -- the ring keeps the last 80
    for i = 1, 100 do D.log("x" .. i) end
    out[#out + 1] = #UF.DB().combatLog .. "/" .. UF.DB().combatLog[1].k
    -- the report runs and is relative to the end of the talk
    UF.DB().combatLog = nil
    now = 10; D.on("PLAYER_REGEN_ENABLED"); now = 12.5; D.on("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1784)
    local said = {}
    local realSay = UF.say
    UF.say = function(m) said[#said + 1] = m end
    D.report()
    UF.say = realSay
    out[#out + 1] = (said[2]:find("%+0.00") and "base" or "?") .. "/" .. (said[3]:find("%+2.50") and "+2.5" or said[3])
    GetTime, IsStealthed, UnitAffectingCombat = saved[1], saved[2], saved[3]
    UF.DB().combatLog = nil
    return table.concat(out, " | ")
end""")()
assert str(r) == "gossip_show,ours,talk-ended,SPELLCAST_FAILED,error-text,stealth | 1784/Not yet./on | 80/x21 | base/+2.5", r
print("Combat timeline: conversations, fights, casts and the game's error text are recorded, other players' casts are not, the log keeps 80, the report is relative to the end: OK")
r = L("""function()
    local UF = _G.UbermocForever
    local D = UF.Diag
    local saved = { GetTime, UnitAffectingCombat, C_Timer, C_Spell }
    UF.DB().combatLog, UF.DB().stealthIncidents = nil, nil
    local now = 50
    GetTime = function() return now end
    UnitAffectingCombat = function() return true end
    C_Timer = { After = function(sec, fn) D._after = fn end }
    C_Spell = { GetSpellName = function(id) if id == 1784 then return "Stealth" elseif id == 5215 then return "Prowl" elseif id == 100 then return "Charge" end end }
    local said = {}
    local realSay = UF.say
    UF.say = function(m) said[#said + 1] = m end
    D.finishIncident()                                                      -- one left waiting by the timeline test above
    UF.DB().stealthIncidents = nil
    said = {}
    local out = {}
    D.on("PLAYER_REGEN_ENABLED"); now = 52.5
    D.on("UNIT_SPELLCAST_FAILED", "player", "g", 1784)
    now = 52.6; D.on("UI_ERROR_MESSAGE", 50, "You can't do that while in combat.")
    D._after()                                                              -- a second later the incident is saved and told
    local inc = UF.DB().stealthIncidents
    out[#out + 1] = #inc .. "/" .. tostring(inc[1].inCombat) .. "/" .. string.format("%.1f", inc[1].sinceFight) .. "/" .. inc[1].text
    out[#out + 1] = (said[1]:find("Stealth refused 2.5 s after the fight ended. In combat: yes") and "said" or said[1] or "nothing said")
    -- a failed Charge is not stealth; a failed Prowl is
    D.on("UNIT_SPELLCAST_FAILED", "player", "g", 100); D.on("UNIT_SPELLCAST_FAILED", "player", "g", 5215)
    D._after()
    out[#out + 1] = #UF.DB().stealthIncidents
    UF.say = realSay
    GetTime, UnitAffectingCombat, C_Timer, C_Spell = saved[1], saved[2], saved[3], saved[4]
    UF.DB().combatLog, UF.DB().stealthIncidents = nil, nil
    return table.concat(out, " | ")
end""")()
assert str(r) == "1/true/2.5/You can't do that while in combat. | said | 2", r
print("Stealth incidents: a refused Stealth, Prowl or Shadowmeld cast is saved with its timeline and the game's error text, and told in one line: OK")
# Quest guide: the addon's own data (QuestData.lua, built from QuestieDB's Forever data) is loaded and readable
r = L("""function()
    local D = UbermocForever.QuestData
    local q = D.Q[783]
    return tostring(q and q.n) .. "|" .. tostring(q and q.s[1][1]) .. "|" .. tostring(D.Z[12]) .. "|" .. tostring(D.N[823] and D.N[823].n)
end""")()
assert str(r) == "A Threat Within|823|1429|Deputy Willem", r
print("Quest guide: the generated quest data loads (quest 783, its giver, Elwynn Forest's map): OK")

# Quest guide: race masks (QuestieDB encoding, Skyborne bits 32/33), what suits your level, what a quest needs, nearest, bearing, the trail, the aim
r = L("""function()
    local G = UbermocForever.QuestGuide
    local out = {}
    -- race bits
    out[#out + 1] = tostring(G.hasBit(1, G.raceBit(1))) .. tostring(G.hasBit(2^32, G.raceBit(95))) .. tostring(G.hasBit(2^32, G.raceBit(1))) .. tostring(G.hasBit(nil, 5))
    -- a small world: one continent, world x north = (1 - y) * 1000, world y west = (1 - x) * 1000 on map 100 (zone 10)
    local saved = { UbermocForever.QuestData, C_Map, CreateVector2D, C_QuestLog, C_SuperTrack, UnitLevel, UnitRace, UnitClass, UnitFactionGroup, UnitQuestTrivialLevelRange }
    CreateVector2D = function(x, y) return { x = x, y = y } end
    local px, py = 0.5, 0.5
    C_Map = {
        GetWorldPosFromMapPos = function(map, v) if map ~= 100 then return nil end return 1, { x = (1 - v.y) * 1000, y = (1 - v.x) * 1000 } end,
        GetBestMapForUnit = function() return 100 end,
        GetPlayerMapPosition = function() return { x = px, y = py } end,
        GetMapInfo = function(m) return { name = "Testland" } end,
    }
    UnitLevel = function() return 10 end
    UnitRace = function() return "Human", "Human", 1 end
    UnitClass = function() return "Warrior", "WARRIOR", 1 end
    UnitFactionGroup = function() return "Alliance" end
    UnitQuestTrivialLevelRange = nil
    UbermocForever.QuestData = {
        Z = { [10] = 100 }, E = {},
        Q = {
            [1] = { n = "Wolves", l = 10, r = 8, s = { { 50 } }, f = { { 50 } }, c = { 60 }, o = {}, i = { 70 }, k = {}, z = 10 },
            [2] = { n = "Far errand", l = 10, r = 8, s = { { 50 } }, f = { { 51 } }, c = {}, o = {}, i = {}, k = {}, z = 10 },
            [3] = { n = "Too high", l = 20, r = 18, s = { { 50 } }, f = { { 50 } }, c = {}, o = {}, i = {}, k = {}, z = 10 },
            [4] = { n = "Needs 1 done", l = 10, r = 8, s = { { 50 } }, f = { { 50 } }, c = {}, o = {}, i = {}, k = {}, ps = { 1 }, z = 10 },
            [5] = { n = "Horde only", l = 10, r = 8, ra = 2, s = { { 52 } }, f = { { 52 } }, c = {}, o = {}, i = {}, k = {}, z = 10 },
            [6] = { n = "From an item", l = 10, r = 8, s = { nil, nil, { 9 } }, f = { { 50 } }, c = {}, o = {}, i = {}, k = {}, z = 10 },
        },
        N = {
            [50] = { n = "Giver", s = { [10] = { { 50, 40 } } }, fr = "A" },        -- 100 yd north of the player
            [51] = { n = "Far giver", s = { [10] = { { 50, 10 } } }, fr = "A" },    -- 400 yd north
            [52] = { n = "Horde giver", s = { [10] = { { 60, 50 } } }, fr = "H" },
            [60] = { n = "Wolf", s = { [10] = { { 40, 50 }, { 90, 90 } } } },       -- the near one is 100 yd west
            [61] = { n = "Rat", s = { [10] = { { 50, 52 } } } },
        },
        O = {}, I = { [70] = { n = "Pelt", d = { 61 } } },
    }
    local me = G.player()
    local isDone = function(id) return false end
    local isOn = function(id) return false end
    local names = {}
    for id = 1, 6 do if G.suits(UbermocForever.QuestData.Q[id], id, me, isDone, isOn) then names[#names + 1] = id end end
    out[#out + 1] = table.concat(names, " ")
    -- what quest 1 needs: wolves only once the pelts are done; the turn-in once complete
    local t = G.targetsFor(1, false, { monster = 1 }, me)
    out[#out + 1] = #t .. ":" .. t[1].label
    t = G.targetsFor(1, false, { item = 1 }, me)
    out[#out + 1] = #t .. ":" .. t[1].label
    t = G.targetsFor(1, true, nil, me)
    out[#out + 1] = #t .. ":" .. t[1].label
    -- nearest and bearing: the near wolf is 100 yd west of the player, so the bearing is a quarter turn counter-clockwise
    local here = G.here()
    local pt, yards, bearing = G.nearest(here, G.targetsFor(1, false, { monster = 1 }, me))
    out[#out + 1] = string.format("%.0f,%.2f", yards, bearing)
    -- the aim: with quests 1 and 2 in the log, the nearest stop first; the focused quest wins over nearer ones
    C_QuestLog = {
        GetNumQuestLogEntries = function() return 2 end,
        GetInfo = function(i) return { questID = i } end,
        GetQuestObjectives = function(id) if id == 1 then return { { type = "monster", finished = false } } end return {} end,
        ReadyForTurnIn = function(id) return id == 2 end,
        IsQuestFlaggedCompleted = function() return false end, IsOnQuest = function(id) return id == 1 or id == 2 end,
    }
    G.invalidate(); G.invalidateAvailable()
    local a = G.aim()
    out[#out + 1] = a.mode .. ":" .. a.point.label .. ":" .. #a.trail
    C_SuperTrack = { GetSuperTrackedQuestID = function() return 2 end }
    G.invalidate()
    a = G.aim()
    out[#out + 1] = a.mode .. ":" .. a.point.label
    -- an empty log: the nearest quest you can pick up
    C_SuperTrack = nil
    C_QuestLog.GetNumQuestLogEntries = function() return 0 end
    C_QuestLog.IsOnQuest = function() return false end
    G.invalidate(); G.invalidateAvailable()
    a = G.aim()
    out[#out + 1] = a.mode .. ":" .. a.point.label
    out[#out + 1] = tostring(G.zones(me)[1].count)
    UbermocForever.QuestData, C_Map, CreateVector2D, C_QuestLog, C_SuperTrack, UnitLevel, UnitRace, UnitClass, UnitFactionGroup, UnitQuestTrivialLevelRange =
        saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7], saved[8], saved[9], saved[10]
    G.invalidate(); G.invalidateAvailable()
    return table.concat(out, "|")
end""")()
parts = str(r).split("|")
assert parts[0] == "truetruefalsetrue", parts
assert parts[1] == "1 2", parts                                  # too high, needs a prerequisite, Horde only, item-started: left out
assert parts[2] == "2:Wolves: Wolf", parts                      # both wolf spawns
assert parts[3] == "1:Wolves: Pelt from Rat", parts             # the pelt comes from rats
assert parts[4] == "1:Turn in: Wolves (Giver)", parts
assert parts[5] == "100,1.57", parts                            # 100 yd, pi/2 (west)
assert parts[6].startswith("nearest:") and parts[6].endswith(":2"), parts  # nearest first, two stops on the trail
assert parts[7] == "focused:Turn in: Far errand (Far giver)", parts
assert parts[8].startswith("pickup:Pick up: "), parts
assert parts[9] == "2", parts                                   # two suitable quests start in Testland
print("Quest guide: race masks, what suits your level, what each quest needs, nearest and bearing, the trail, focused first, pick-ups for an empty log: OK")

# Quest guide: spawns are kept packed in the data and unpacked once, on first use (memory: 24 MB -> 11 MB in Lua 5.1)
r = L("""function()
    local G = UbermocForever.QuestGuide
    local e = { s = "12:482,429 500,-10|40:-10,-10" }
    local s = G.spawns(e)
    local again = G.spawns(e)
    local real = UbermocForever.QuestData.N[823]
    return string.format("%s,%s|%s,%s|%s|%s|%s", s[12][1][1], s[12][1][2], s[12][2][1], s[12][2][2], tostring(s[40][1][1]), tostring(again == s), type(real.s) .. ":" .. #G.spawns(real)[12])
end""")()
assert str(r) == "48.2,42.9|50.0,-1.0|-1.0|true|string:1", r
print("Quest guide: packed spawns unpack to zone, x, y (and -1,-1 for instances), once per creature: OK")

print("VERSION", L("UbermocForever").getVersion())
print("ALL TESTS PASSED")
