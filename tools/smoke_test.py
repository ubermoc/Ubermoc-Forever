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
    press("PADDDOWN"); press("PADDDOWN"); press("PADDDOWN")      -- header, layers, first row ... settle on a list row
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
print("VERSION", L("UbermocForever").getVersion())
print("ALL TESTS PASSED")
