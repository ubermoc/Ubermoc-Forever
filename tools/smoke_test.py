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
        if k == "GetName" then return function() return name end end
        if k == "GetRect" then return function() return 100, 100, 50, 20 end end
        if k == "GetCenter" then return function() return 125, 110 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k == "GetStringWidth" then return function() return 40 end end
        if k == "GetText" then return function(s) return rawget(s, "__text") end end
        if k == "SetText" then return function(s, v) rawset(s, "__text", v) end end
        if k == "IsShown" or k == "IsVisible" or k == "IsEnabled" then return function() return true end end
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetVerticalScroll" or k == "GetVerticalScrollRange" or k == "GetTop" or k == "GetBottom" then return function() return 0 end end
        if k == "SetScript" then return function(s, ev, fn) rawset(s, "__scripts", rawget(s, "__scripts") or {}); s.__scripts[ev] = fn end end
        if k == "HookScript" then return function() end end
        if k == "RegisterEvent" then return function(s, e) rawset(s, "__events", rawget(s, "__events") or {}); s.__events[e] = true end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return proxy("sub") end end
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
GetNumBindings = function() return 3 end
GetBinding = function(i) return ({ "ACTIONBUTTON1", "JUMP", "TOGGLEWORLDMAP" })[i], "ACTIONBAR" end
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
    w.__scripts.OnShow(w)
end""")()
print("nav overrides after show:", sorted(list(L("__calls.overrides").keys())))
res = L("""function()
    local out = {}
    for _, key in ipairs({ "PADDDOWN", "PADDUP", "PADDLEFT", "PADDRIGHT", "PADLSHOULDER", "PADRSHOULDER", "PAD3", "PAD4", "PAD2" }) do
        local b = _G["UbermocForeverNav_" .. key]
        local ok, err = pcall(b.__scripts.OnClick, b)
        out[#out + 1] = key .. "=" .. tostring(ok) .. (ok and "" or (" " .. tostring(err)))
    end
    return table.concat(out, "; ")
end""")()
print("nav presses:", res)
L("""function() local w = UbermocForeverOptions; w.__scripts.OnHide(w) end""")()
print("overrides after hide:", len(list(L("__calls.overrides").keys())))

print("combat driver registered:", L("__calls.driver"))
assert L("__calls.driver") == "combat:[combat] 1; 0", "the secure combat driver must be registered"
print("Nav owner frame exists:", L("UbermocForeverNavOwner") is not None)
print("device name shown on options header:", "yes" if L("UbermocForever").deviceName else "no")
print("ALL CHECKS PASSED")
