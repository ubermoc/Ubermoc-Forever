local _, ns = ...

if not ns.BindingHint then ns.BindingHint = {} end

-- Checkpont 3: Native Binding Hints
-- Shows gamepad key names on Blizzard UI elements using WoW's own binding text system.
-- No custom art — every overlay uses FontString with native font objects, so hints inherit
-- whatever font family, color palette, scaling (90%–150%), and shadow the player set.
--
-- Core design:
--   - Context listener fires on every context change via OnUpdate poll / combat events
--   - HookActionBars() forces Blizzard's HotKey FontString to re-read SetOverrideBinding chain
--   - SpellBookFrame overlays are lightweight FontStrings anchored to each visible spell slot
--   - NPC/Bags/Menus show one hint overlay near the active frame

-- ─── Private state ──────────────────────────────────────────────────────────

local hintOverlays = {}   -- entries: { frame, anchor }
local hintIdCounter  = 0
local listenerId     = nil   -- Context.Register return value

-- ─── Utility: show or update one overlay hint (FontString-based) ─────────────
-- Reuses cached FontStrings keyed by anchor frame to avoid leak on context switches.
local function showHint(anchorFrame, text, fontStr, colorR, colorG, colorB, colorA, offsetX, offsetY)
    hintIdCounter = hintIdCounter + 1

    local existing = nil
    for i, o in ipairs(hintOverlays) do
        if o.anchor == anchorFrame then
            existing = o
            table.remove(hintOverlays, i)
            break
        end
    end

    local fs
    if existing then
        fs = existing.frame
    else
        fs = anchorFrame:CreateFontString(anchorFrame:GetName() .. "UbFHint", "OVERLAY", "NumberFontNormalSmall")
        if not fs then return end
        hintOverlays[#hintOverlays + 1] = { frame = fs, anchor = anchorFrame }
    end

    fs:SetText(text or "")
    local fo = fontStr and _G[fontStr]
    if fo then
        fs:SetFontObject(fo)
    end
    fs:SetTextColor(colorR or 1, colorG or 1, colorB or 0.8, colorA or 0.9)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", anchorFrame, "RIGHT", offsetX or -2, offsetY or 0)
    fs:Show()
    -- Phase 06: fade in with the game's own animation API when available.
    if ns.Transitions and ns.Transitions.FadeIn then
        pcall(ns.Transitions.FadeIn, fs)
    end
end

-- Hide and remove one overlay by its FontString object.
local function hideHint(frameToHide)
    for i, o in ipairs(hintOverlays) do
        if o.frame == frameToHide then
            o.frame:SetText("")
            o.frame:Hide()
            table.remove(hintOverlays, i)
            return true
        end
    end
end

-- Hide every overlay (no cleanup — objects will be GC'd or reused next call).
local function hideAllHints()
    for _, o in ipairs(hintOverlays) do
        if o.frame then
            o.frame:SetText("")
            o.frame:Hide()
        end
    end
    hintOverlays = {}
    hintIdCounter = 0
end

-- ─── Action bar HotKey refresh ──────────────────────────────────────────────
-- Forces every visible action button's $parentHotKey to re-read the SetOverrideBinding chain.
function ns.BindingHint.HookActionBars()
    if InCombatLockdown() then return end

    -- ns.Layout (this addon's module table) — the global name was never defined.
    local BAR_COUNT = (ns.Layout and ns.Layout.SETS and #ns.Layout.SETS) or 2
    local SLOT_COUNT = 12

    for bar = 1, BAR_COUNT do
        local prefix = (bar == 1) and "ActionButton" or ("MultiActionButton%d"):format(bar)

        for slot = 1, SLOT_COUNT do
            local btn = _G[prefix .. slot]
            if not btn or not btn:IsShown() then break end

            -- If the button has a mixin Update(), call it — Blizzard refreshes HotKey.
            pcall(function()
                if type(btn.Update) == "function" then
                    btn:Update()
                end
            end)

            -- Fallback: directly update HotKey from override bindings.
            if btn.HotKey then
                local bindingAction
                if bar == 1 then
                    bindingAction = ("ACTIONBUTTON%d"):format(slot)
                else
                    bindingAction = ("MULTIACTIONBAR%dBUTTON%d"):format(bar - 1, slot)
                end

                local key = GetBindingKeyForAction(bindingAction)
                if key and key ~= "" then
                    btn.HotKey:SetText(GetBindingText(key, 1))
                else
                    btn.HotKey:SetText("")
                end
            end
        end
    end
end

-- ─── SpellBookFrame hint overlays ───────────────────────────────────────────

local function showSpellBookHints()
    if InCombatLockdown() then return end

    -- Blizzard spellbook: SpellButton1 through SpellButton8 are visible per page.
    for i = 1, 8 do
        local btnNm = ("SpellButton%d"):format(i)
        local btn   = _G[btnNm]
        if not btn or not btn:IsShown() then break end

        hideHint(btn)

        -- ACTIONBUTTON1 maps directly to ActionBar1 Slot 1 etc.
        local actionNm = ("ACTIONBUTTON%d"):format(i)
        local key      = GetBindingKeyForAction(actionNm)

        if key and key ~= "" then
            showHint(btn, GetBindingText(key, 1), "NumberFontNormalSmall", 0.8, 1, 1, 0.9, -2, -20)
        end
    end
end

-- ─── NPC / Quest interaction hint ───────────────────────────────────────────

local function showInteractionHint()
    if InCombatLockdown() then return end

    local targetFrame = nil

    if GossipFrame and GossipFrame:IsShown() then
        targetFrame = GossipFrame
    elseif QuestgiverFrame and QuestgiverFrame:IsShown() then
        targetFrame = QuestgiverFrame
    end

    if not targetFrame or not targetFrame:IsVisible() then return end

    hideHint(targetFrame)

    local interactKey = GetBindingKey("INTERACTTARGET")
    if not interactKey or interactKey == "" then
        interactKey = GetBindingKeyForAction("TALKTOCLIENT")
    end

    if interactKey and interactKey ~= "" then
        local fs = targetFrame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
        if not fs then return end
        fs:SetPoint("CENTER", targetFrame, "BOTTOM", 0, -15)
        fs:SetText(GetBindingText(interactKey, 1))
        fs:SetTextColor(1, 1, 0.8, 1)
        fs:Show()
        -- Phase 06: fade in with the game's own animation API when available.
        if ns.Transitions and ns.Transitions.FadeIn then
            pcall(ns.Transitions.FadeIn, fs)
        end
    end
end

-- ─── Bag hint overlay ───────────────────────────────────────────────────────

local function showBagHints()
    if InCombatLockdown() then return end

    -- Bag frame names verified in the forever branch
    -- (Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml):
    -- ContainerFrameCombinedBags plus ContainerFrame1 and up.
    local targetFrame
    local candidates = { ContainerFrameCombinedBags }
    for i = 1, 7 do
        candidates[#candidates + 1] = _G["ContainerFrame" .. i]
    end
    for _, f in ipairs(candidates) do
        if type(f) == "table" and f.IsShown and f:IsShown() then
            targetFrame = f
            break
        end
    end
    if not targetFrame then return end

    hideHint(targetFrame)

    -- Picking an item up is a cursor click; the cursor's left-click button is the
    -- game's own cvar (see Input/Cursor.lua). Fall back to A when it is unbound.
    local key = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("GamePadCursorLeftClick")
    if not key or key == "NONE" then key = "PAD1" end
    local ok, text = pcall(GetBindingText, key, 1)
    showHint(targetFrame, (ok and text) or "", "NumberFontNormalSmall", 0.7, 0.9, 1, 0.8, -2, -20)
end

-- ─── Game Menu hint ─────────────────────────────────────────────────────────

local function showMenuHint()
    if InCombatLockdown() then return end

    hideHint(UIParent)

    local menuKey = GetBindingKey("TOGGLEGAMEMENU")
    if not menuKey or menuKey == "" then menuKey = "ESCAPE" end

    local fs = UIParent:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large2")
    if not fs then return end
    fs:SetPoint("BOTTOMCENTER", UIParent, "BOTTOMCENTER", 0, 60)
    fs:SetText(GetBindingText(menuKey, 1))
    fs:SetTextColor(1, 1, 0.6, 1)
    fs:Show()
    -- Phase 06: fade in with the game's own animation API when available.
    if ns.Transitions and ns.Transitions.FadeIn then
        pcall(ns.Transitions.FadeIn, fs)
    end
end

-- ─── Context listener (registered with ns.Context) ──────────────────────────

local function onContextChange(newCtx, _oldCtx)
    if newCtx == "NONE" then
        hideAllHints()
        return
    end

    if newCtx == "SPELLBOOK" then showSpellBookHints()
    elseif newCtx == "NPC"      then showInteractionHint()
    elseif newCtx == "BAGS"     then showBagHints()
    elseif newCtx == "MENU"     then showMenuHint()
    end
end

-- ─── Public API ─────────────────────────────────────────────────────────────

function ns.BindingHint.Start(_context)
    hideAllHints()

    if listenerId ~= nil then ns.Context.Unregister(listenerId) end
    listenerId = nil

    -- Register context-change listener. Fires immediately on first register too.
    listenerId = ns.Context.Register(onContextChange)

    -- Also fire once now, in case the current context is already set (ADDON_LOADED timing).
    local curCtx = ns.Context.Current()
    if curCtx ~= "NONE" and curCtx ~= "NONE" then   -- guard: only show on hintable contexts
        if      curCtx == "SPELLBOOK" then showSpellBookHints()
        elseif curCtx == "NPC"        then showInteractionHint()
        elseif curCtx == "BAGS"       then showBagHints()
        elseif curCtx == "MENU"       then showMenuHint()
        end
    end

    -- Refresh action bar hotkeys on every Start.
    ns.BindingHint.HookActionBars()
end

function ns.BindingHint.Stop()
    if listenerId ~= nil then
        ns.Context.Unregister(listenerId)
        listenerId = nil
    end
    hideAllHints()
    ns.BindingHint.HookActionBars()
end

function ns.BindingHint.Refresh()
    hideAllHints()
    local curCtx = ns.Context.Current()
    if curCtx ~= "NONE" then
        if      curCtx == "SPELLBOOK" then showSpellBookHints()
        elseif curCtx == "NPC"        then showInteractionHint()
        elseif curCtx == "BAGS"       then showBagHints()
        elseif curCtx == "MENU"       then showMenuHint()
        end
    end
    ns.BindingHint.HookActionBars()
end

-- ─── Slash command helper: /ubf bindings (debug) ────────────────────────────

local function printBindings()
    local barCount = (ns.Layout and ns.Layout.SETS and #ns.Layout.SETS) or 2
    for bar = 1, barCount do
        -- No prefix needed — we build action names directly below.
        print(("=== ActionBar %d ==="):format(bar))
        for slot = 1, 12 do
            local actionNm = (bar == 1) and ("ACTIONBUTTON%d"):format(slot)
                              or ("MULTIACTIONBAR%dBUTTON%d"):format(bar - 1, slot)
            local key = GetBindingKeyForAction(actionNm)
            if key and key ~= "" then
                print(("  %s → %s (text: %s)"):format(
                    actionNm, key, GetBindingText(key, 1)))
            end
        end
    end
end

-- Debug helper for slash commands — registered at line 5 of this module.
ns.PrintBindings = printBindings     -- callable from /ubf bindings via Init.lua

