----------------------------------------------------------------------
-- Ubermoc Forever: chat lines fade out by themselves.
-- Every line in every chat window fades a few seconds after it appears (the game's own per-line timers: SetFading,
-- SetTimeVisible, SetFadeDuration, see Blizzard_APIDocumentationGenerated/SimpleMessageFrameAPIDocumentation.lua; the game's own
-- value is 120 s, ChatFrameOverrides.lua). Starting values are the ones Ubermoc UI uses: 5 s visible, 3 s fade-out.
-- The player's own values are saved the first time and put back when this is turned off.
----------------------------------------------------------------------
local ADDON, UF = ...
local Ch = {}
UF.Chat = Ch

Ch.VISIBLE = { 5, 10, 20, 30, 60, 120 }   -- seconds a line stays before it starts to fade
Ch.FADE = { 1, 2, 3, 5, 10 }              -- seconds the fade-out takes

local function cfg()
    local d = UF.DB()
    d.chat = d.chat or {}
    local c = d.chat
    if c.on == nil then c.on = true end
    c.visible = c.visible or 5
    c.fade = c.fade or 3
    if c.reveal == nil then c.reveal = true end
    if c.editFade == nil then c.editFade = true end
    return c
end
Ch.cfg = cfg

local function frames()
    local out = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.SetTimeVisible then out[#out + 1] = f end
    end
    return out
end

function Ch.apply()
    local c = cfg()
    local d = UF.DB()
    d.chatBackup = d.chatBackup or {}
    for i, f in ipairs(frames()) do
        local key = f:GetName() or tostring(i)
        pcall(function()
            if c.on then
                if not d.chatBackup[key] then d.chatBackup[key] = { f:GetFading() and true or false, f:GetTimeVisible(), f:GetFadeDuration() } end
                f:SetFading(true)
                f:SetTimeVisible(c.visible)
                f:SetFadeDuration(c.fade)
            elseif d.chatBackup[key] then
                local o = d.chatBackup[key]
                f:SetFading(o[1]); f:SetTimeVisible(o[2]); f:SetFadeDuration(o[3])
                d.chatBackup[key] = nil
            end
        end)
    end
    if not c.on and next(d.chatBackup) == nil then d.chatBackup = nil end
end

local function stepOf(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
    return 1
end
function Ch.toggle() local c = cfg(); c.on = not c.on; Ch.apply() end
function Ch.nextVisible() local c = cfg(); c.visible = Ch.VISIBLE[(stepOf(Ch.VISIBLE, c.visible) % #Ch.VISIBLE) + 1]; Ch.apply() end
function Ch.nextFade() local c = cfg(); c.fade = Ch.FADE[(stepOf(Ch.FADE, c.fade) % #Ch.FADE) + 1]; Ch.apply() end
function Ch.toggleEdit() local c = cfg(); c.editFade = not c.editFade; if UF.Fade then UF.Fade.evaluate() end end
function Ch.toggleReveal() local c = cfg(); c.reveal = not c.reveal end
function Ch.visibleName() return cfg().visible .. " s" end
function Ch.fadeName() return cfg().fade .. " s" end

-- A new line reveals a chat window that is faded on the Fading page; the edit box in use keeps the chat and itself shown until the
-- message is sent (or given up), then they wait the same "visible" time and fade over the same fade-out time. Elements with no fading
-- setting are left alone. Source: ChatFrameUtil.ActivateChat/DeactivateChat set ACTIVE_CHAT_EDIT_BOX (Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua).
local SHOWN = { "chat" }   -- the tabs are not touched: they follow only their own setting on the Chat page
local function onLine()
    local c = cfg()
    local F = UF.Fade
    if not (c.on and c.reveal and F) then return end
    for _, k in ipairs(SHOWN) do F.reveal(k, c.visible, c.fade) end
end
Ch.onLine = onLine
local hooked = {}
local function hookLines()
    for _, f in ipairs(frames()) do
        if f.AddMessage and not hooked[f] then
            hooked[f] = true
            hooksecurefunc(f, "AddMessage", onLine)
        end
    end
end
Ch.hookLines = hookLines

local typing = false
function Ch.pollTyping()
    local F = UF.Fade
    if not F then return end
    local c = cfg()
    local now = ((c.on or c.editFade) and _G.ACTIVE_CHAT_EDIT_BOX ~= nil) and true or false
    if now == typing then return end
    typing = now
    for _, k in ipairs({ "chat", "chatedit" }) do
        F.hold(k, now)
        if not now then F.reveal(k, c.visible, c.fade) end   -- done typing: wait, then fade
    end
end
local acc = 0
local drv = CreateFrame("Frame")
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    Ch.pollTyping()
end)

-- (the Chat page of the options window sets all of this: ChatPage.lua)
-- The edit box fades by itself when this is on and the Fading-style setting of "chatedit" is not set: hidden (0) until it is used.
function Ch.registerEdit() UF.Fade.implicit.chatedit = function() return cfg().editFade and 0 or nil end end   -- Fade.lua loads after this file: called at login
-- The game builds and restyles its chat windows around login, so apply again a little later (as Ubermoc UI does).
UF.OnLogin(function()
    Ch.registerEdit()
    Ch.apply()
    hookLines()
    if C_Timer and C_Timer.After then C_Timer.After(1, function() Ch.apply(); hookLines() end); C_Timer.After(4, Ch.apply) end
end)
