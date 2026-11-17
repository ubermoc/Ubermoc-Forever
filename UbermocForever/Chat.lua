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
function Ch.visibleName() return cfg().visible .. " s" end
function Ch.fadeName() return cfg().fade .. " s" end

-- The game builds and restyles its chat windows around login, so apply again a little later (as Ubermoc UI does).
UF.OnLogin(function()
    Ch.apply()
    if C_Timer and C_Timer.After then C_Timer.After(1, Ch.apply); C_Timer.After(4, Ch.apply) end
end)
