----------------------------------------------------------------------
-- Ubermoc Forever: "are you sure?" before something replaces what a worn piece already carries (UF.ApplyConfirm), 1.3.130.
-- In the middle of the screen: what the piece already has, what will replace it, A for yes and B for no, their pictures inside the buttons.
--   * Yes is a SECURE button of ours (type "macro", the same two lines the menu entry would have run: "/use <bag> <slot>" then
--     "/use <inventory slot>"), because using an item has to come from a real secure press. Its macro is set when the question is
--     opened, which the game only allows out of combat; in combat the question is not asked (the caller applies at once).
--   * While it is up it takes the controller (Nav.Push on top of the stack): A presses Yes through a secure key, B (and Escape)
--     says no, and the other buttons do nothing, so the highlight behind it cannot move. Nothing is applied by a no.
-- What the piece carries comes from Applied.lua.
----------------------------------------------------------------------
local _, UF = ...
local AC = {}
UF.ApplyConfirm = AC

local YES_NAME = "UbermocForeverApplyYes"
local frame, titleFS, textFS, continueFS, yesBtn, noBtn
local entry

local DEAD_KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }

local function close()
    if entry and UF.Nav then UF.Nav.Pop(entry) end
    entry = nil
    if frame and frame:IsShown() then frame:Hide() end
end
AC.close = close

local function build()
    if frame then return end
    local okF, f = pcall(CreateFrame, "Frame", "UbermocForeverApplyConfirm", UIParent, "BackdropTemplate")
    frame = okF and f or CreateFrame("Frame", "UbermocForeverApplyConfirm", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetSize(480, 210)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame:EnableMouse(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", frame, "TOP", 0, -20)
    -- the question (what it has, what replaces it), then "Continue?" just above the buttons so the two never overlap
    textFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    textFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 88)
    textFS:SetJustifyH("CENTER")
    textFS:SetJustifyV("TOP")
    if textFS.SetWordWrap then textFS:SetWordWrap(true) end
    continueFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    continueFS:SetPoint("BOTTOM", frame, "BOTTOM", 0, 62)

    -- Yes and No, each with the controller's own picture inside the button ([A] Yes, [B] No). The picture is part of the label, so
    -- it follows the controller in use (set every time the question opens) and a larger button font makes it large enough to read.
    local function bigFont(b)
        if b.SetNormalFontObject and _G.GameFontNormalLarge then b:SetNormalFontObject("GameFontNormalLarge") end
        if b.SetHighlightFontObject and _G.GameFontHighlightLarge then b:SetHighlightFontObject("GameFontHighlightLarge") end
    end
    yesBtn = CreateFrame("Button", YES_NAME, frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    yesBtn:RegisterForClicks("AnyUp")
    yesBtn:SetAttribute("useOnKeyDown", false)
    yesBtn:SetAttribute("type", "macro")
    yesBtn:SetSize(160, 34)
    yesBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 70, 22)
    bigFont(yesBtn)
    yesBtn:HookScript("PostClick", function() close() end)   -- after the macro ran
    noBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    noBtn:SetSize(160, 34)
    noBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -70, 22)
    bigFont(noBtn)
    noBtn:SetScript("OnClick", close)
    frame:SetScript("OnHide", function() if entry and UF.Nav then UF.Nav.Pop(entry); entry = nil end end)
    if UISpecialFrames then table.insert(UISpecialFrames, "UbermocForeverApplyConfirm") end   -- Escape says no
    frame:Hide()
end

-- Ask. info = { title = "...", text = "...", macro = "/use ...\n/use ..." }. Returns true when the question is up, false when it
-- cannot be asked (in combat: a secure button's macro cannot be changed then), so the caller can go ahead without it.
function AC.ask(info)
    if type(info) ~= "table" or type(info.macro) ~= "string" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    build()
    AC.last = info   -- for the offline test
    titleFS:SetText(info.title or "Are you sure?")
    textFS:SetText(info.text or "")
    continueFS:SetText(info.question or "Continue?")
    yesBtn:SetText((UF.glyph and UF.glyph("PAD1") or "A") .. " " .. (YES or "Yes"))   -- follows the controller in use
    noBtn:SetText((UF.glyph and UF.glyph("PAD2") or "B") .. " " .. (NO or "No"))
    yesBtn:SetAttribute("macrotext", info.macro)
    frame:Show()
    if UF.Nav and not entry then
        local map = { PAD2 = close }
        for _, k in ipairs(DEAD_KEYS) do map[k] = function() end end
        entry = UF.Nav.Push(map, { PAD1 = { YES_NAME, "LeftButton" } })
    end
    return true
end

function AC.isShown() return frame ~= nil and frame:IsShown() end
AC._yes = function() return yesBtn end   -- for the offline test
