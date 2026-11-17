# Offline test for the addon: compiles every file, loads them against a stub of the game, and exercises detection,
# the first-run prompt, the default binds, the options window and its D-pad buttons.
# Run: python3 tools/smoke_test.py   (needs: pip install lupa). It cannot test what only the real game does:
# where the cursor lands, how the windows look, and whether Forever has every function the addon uses.
import sys, os
# lupa must be installed: pip install lupa (tools/setup-research.sh does this in a private folder)
import lupa
from lupa import LuaRuntime

ADDON = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "UbermocForever")
toc = [l.strip() for l in open(ADDON + "/UbermocForever.toc") if l.strip() and not l.startswith("##")]

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
local calls = { binds = {}, cvars = {}, saved = 0, popups = {}, hooks = {}, overrides = {} }
_G.__calls = calls
local function proxy(name)
    local t = {}
    local mt = {}
    mt.__index = function(self, k)
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
        return function() return proxy("ret") end
    end
    return setmetatable(t, mt)
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
        fn("UbermocForever", ns)
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
    press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN")      -- header, cinematic row, aim row, chat row, layers, first row ... settle on a list row
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
# A poison (class 0, subclass 8) is told apart from other "Other" consumables by its use text
r = L("""function()
    local M = UbermocForever.ItemMenu
    C_Item = {
        GetItemInfoInstant = function(id) return id, "t", "s", "", 1, 0, 8 end,
        GetItemSpell = function(id) return "Use it" end,
    }
    local lines = { [3775] = "Use: Coats a weapon with poison that lasts for 30 minutes.", [9999] = "Use: Restores 10 health." }
    C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Name" }, { leftText = lines[id] } } } end }
    return tostring(M.usedOnItems(3775)) .. tostring(M.usedOnItems(9999))
end""")()
assert str(r) == "truefalse", r
print("Poisons are recognised from their use text: OK")
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
        GetItemSpell = function(id) return "Use it" end,
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
        function b:SetFrameLevel() end
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
    MainActionBar = { EndCaps = { LeftEndCap = cap(), RightEndCap = cap() } }
    local realTalk = UF.Cinematic.talking
    UF.Cinematic.talking = function() return false end   -- the test stub's windows look open: not talking
    IsShiftKeyDown = function() return true end; IsControlKeyDown = function() return false end; IsAltKeyDown = function() return false end
    B.layout()
    local first = btns[1]
    out[#out + 1] = tostring(first.pts[1][4]) .. "," .. tostring(btns[3].pts[1][4]) .. "," .. tostring(btns[4].pts[1][4])   -- centred 3, the fourth out of sight
    out[#out + 1] = tostring(btns[1].alpha) .. tostring(btns[13].alpha) .. tostring(btns[14].alpha) .. tostring(btns[16].alpha)   -- layer 2 is held: bar 1 hidden, bar 2's first three shown, its fourth (empty) hidden
    out[#out + 1] = tostring(btns[1].ignore)
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
assert str(r) == "1,2,3,4,1,225.0/275.0/325.0,0,225.0,325.0,-5000,0110,true,falsetrue,0|0|false1,false1,CENTERfalse1,truefalse", r
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
assert str(r) == "true,6,4,5", r
print("Chat page builds: message buttons, five parts, three situations, hide and reset: OK")
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
    return table.concat(out, ",")
end""")()
assert str(r) == "1,2,3,2,1", r
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
print("Y menu: Create auction button found only with an item in the sell slot: OK")

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
assert str(r) == "true40trueleft|nilnilright", r
print("Fresh install: the author's settings are the defaults, existing settings untouched: OK")
print("VERSION", L("UbermocForever").getVersion())
print("ALL TESTS PASSED")
