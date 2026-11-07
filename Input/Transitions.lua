local _, ns = ...

-- Phase 06 — Context-aware transitions.
--
-- What this module does:
--   1. Bar-profile switching. While a game frame is open (spellbook, bags,
--      professions, menu, NPC dialog) the plain paddle press reaches the
--      secondary bar first — the bar you placed your utility/spells on —
--      and the paddles return to your normal (combat) bars the moment the
--      frame closes. Combat always wins: entering or leaving combat is
--      applied immediately, never debounced.
--   2. Rapid-toggle safety. Frame-context switches are debounced 200 ms so
--      fast open/close never rebinds the bars mid-way; each apply is one
--      atomic Layout.Apply() call (clear + rebind), so there is no
--      half-applied state. A switch requested during combat is impossible
--      by construction: the Context engine classifies COMBAT first, and
--      Layout.Apply() itself refuses to rebind under InCombatLockdown and
--      re-applies on PLAYER_REGEN_ENABLED (existing mechanism in Layout).
--   3. Fade-in for the context hint overlays, using the game's own
--      animation API (see FadeIn).
--
-- API verification (Gethe/wow-ui-source, branch `forever`, one grep each):
--   * TweenFrame: NOT present on this build. Do not call it.
--   * frame:CreateAnimationGroup() + group:CreateAnimation("Alpha")
--     (SetFromAlpha/SetToAlpha/SetDuration, group:Play): present and used
--     by Blizzard itself (Blizzard_HelpPlate.lua:52-64,
--     Blizzard_Menu/Compositor.lua). Used below for the 0.1 s fade-in.
--   * Steam Overlay: no reporting API found — no BigPicture or overlay
--     state API anywhere in the branch (every "overlay" hit is spell
--     activation, portraits or minimap insets). So this module does NOT
--     hide itself on an overlay: the question is recorded in TEST.md and
--     we do not guess Steam APIs (main spec §4).
--
-- Extends, never rewrites: uses the existing Context listener registry
-- (Core/Context.lua), the existing Layout binding engine (Input/Layout.lua)
-- and the existing BindingHint overlays (Input/BindingHint.lua).

local Transitions = {}
ns.Transitions = Transitions

-- Settings key (SavedVariables), default ON — the phase feature is the
-- point of this build; toggle off with `/ubf transitions off`.
local ENABLED_KEY = "transitionsOn"
local DEBOUNCE = 0.2   -- seconds; 200 ms per the phase brief

-- Contexts that get the rotated profile (a game frame is open).
-- COMBAT and NONE always use the base (user-configured) profile.
local ROTATED_CONTEXTS = {
    SPELLBOOK = true,
    BAGS = true,
    PROFESSIONS = true,
    MENU = true,
    NPC = true,
}

local state = {
    started = false,
    listenerId = nil,
    appliedBars = nil,    -- the profile currently live in the bindings
    lastReason = nil,     -- last apply failure reason, if any
}

local scheduledCtx = nil  -- debounced target context
local scheduleTime = 0

-- ─── Profiles ───────────────────────────────────────────────────────────────

-- The user's own bar sets, straight from the Layout config. This is always
-- the "combat" profile: it is what `/ubf layout bar` and the options window
-- configure, and it is what gets saved.
local function baseProfile()
    local bars = {}
    local c = ns.Layout and ns.Layout.Config and ns.Layout.Config()
    for i = 1, 4 do
        bars[i] = (c and c.bars and c.bars[i]) or i
    end
    return bars
end

-- Rotated profile for frame contexts: the plain press (set 1) reaches the
-- secondary bar (the spell/utility bar of the three-bar template), set 2 the
-- tertiary bar, set 3 the fourth configured bar, set 4 the primary bar.
-- Same bars the user configured — only the paddle order changes, so nothing
-- is guessed and reverting is exact.
local function rotatedProfile(base)
    return { base[2], base[3], base[4], base[1] }
end

local function sameProfile(a, b)
    if not a then return false end
    for i = 1, 4 do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Apply a bar profile to the live bindings without touching the user's
-- saved config: swap c.bars in, let Layout.Apply() rebind (which also
-- repaints bar labels and guards combat itself), then restore c.bars so
-- SavedVariables and the options window always show the user's own sets.
local function applyProfile(profile)
    if not (ns.Layout and ns.Layout.Config and ns.Layout.Apply) then
        return false, "layout module not ready"
    end
    -- Layout.Config() returns the LIVE SavedVariables reference (db.layout),
    -- so the user's bar sets must be restored even if Apply() throws.
    local c = ns.Layout.Config()
    local saved = {}
    for i = 1, 4 do saved[i] = c.bars[i] end
    for i, bar in ipairs(profile) do c.bars[i] = bar end
    local callOk, ok, reason = pcall(ns.Layout.Apply)
    for i = 1, 4 do c.bars[i] = saved[i] end
    if not callOk then
        ok, reason = false, tostring(reason)
    end
    if ok then
        state.appliedBars = { profile[1], profile[2], profile[3], profile[4] }
        state.lastReason = nil
    else
        state.lastReason = reason
    end
    if ns.Log then
        ns.Log(("transitions: profile %s %s"):format(ok and "applied" or "not applied",
            ok and "" or ("(" .. tostring(reason) .. ")")))
    end
    return ok, reason
end

local function profileFor(ctx)
    local base = baseProfile()
    if ROTATED_CONTEXTS[ctx] then
        return rotatedProfile(base)
    end
    return base
end

-- ─── Context listener ───────────────────────────────────────────────────────

local function needsApply(ctx)
    if not state.appliedBars then return true end
    return not sameProfile(state.appliedBars, profileFor(ctx))
end

-- Context.Register calling convention (Core/Context.lua): listeners receive
-- fn(context, "enter") and fn(context, "exit"), and Context also fires a
-- backward-compat call fn(newCtx, oldCtx) where arg2 is a context name.
-- Only the "enter" signal drives a switch: every transition ends in exactly
-- one context entering, so "exit" needs no action and the compat call
-- (signal is a context name, not "enter"/"exit") is ignored.
local function onContextChange(ctx, signal)
    if signal ~= "enter" then
        return
    end
    if not ns.db or ns.db[ENABLED_KEY] == false then
        return
    end
    if ctx == "COMBAT" or ctx == "NONE" then
        -- Gameplay states are final and time-critical: apply now, cancel any
        -- pending frame-context swap. Never debounced.
        scheduledCtx = nil
        if needsApply(ctx) then
            applyProfile(profileFor(ctx))
        end
        return
    end
    if ROTATED_CONTEXTS[ctx] then
        -- Debounce: latest frame-context wins; the swap only lands after the
        -- context has been stable for DEBOUNCE seconds (see OnUpdate below).
        scheduledCtx = ctx
        scheduleTime = GetTime()
    end
end

-- Debounce pump. Runs every tick while a swap is pending; applies exactly
-- one atomic rebind once the context has settled for 200 ms.
local debounceFrame = CreateFrame("Frame")
debounceFrame:SetScript("OnUpdate", function()
    if not scheduledCtx then return end
    local ctx = scheduledCtx
    if GetTime() - scheduleTime < DEBOUNCE then return end
    scheduledCtx = nil
    if needsApply(ctx) then
        applyProfile(profileFor(ctx))
    end
end)

-- ─── Fade-in (task 2) ───────────────────────────────────────────────────────
-- One-shot 0.1 s alpha fade for frames we own (the context hint overlays).
-- Uses the native animation API verified above; falls back to an instant
-- show if the API is unavailable on this build. Called by BindingHint.
function Transitions.FadeIn(frame)
    if type(frame) ~= "table" or type(frame.CreateAnimationGroup) ~= "function" then
        return
    end
    local ok = pcall(function()
        if not frame.ubfFadeGroup then
            local group = frame:CreateAnimationGroup()
            local anim = group:CreateAnimation("Alpha")
            anim:SetFromAlpha(0)
            anim:SetToAlpha(1)
            anim:SetDuration(0.1)
            frame.ubfFadeGroup = group
        end
        frame:SetAlpha(0)
        frame.ubfFadeGroup:Play()
    end)
    if not ok then
        frame:SetAlpha(1)
    end
end

-- ─── Public API ─────────────────────────────────────────────────────────────

function Transitions.Start()
    if state.started then return end
    state.started = true
    if ns.db and ns.db[ENABLED_KEY] == nil then
        ns.db[ENABLED_KEY] = true
    end
    state.listenerId = ns.Context.Register(onContextChange)
    if ns.Log then
        ns.Log("transitions: started (200 ms debounce, fade-in on)")
    end
end

function Transitions.Stop()
    if not state.started then return end
    state.started = false
    if state.listenerId and ns.Context then
        ns.Context.Unregister(state.listenerId)
        state.listenerId = nil
    end
    scheduledCtx = nil
    applyProfile(baseProfile())
    state.appliedBars = nil
end

function Transitions.SetEnabled(on)
    if ns.db then
        ns.db[ENABLED_KEY] = on and true or false
    end
    if on then
        -- Re-sync live bindings to the current context's profile.
        local ctx = ns.Context and ns.Context.Current() or "NONE"
        scheduledCtx = nil
        applyProfile(profileFor(ctx))
    else
        scheduledCtx = nil
        state.appliedBars = nil
        applyProfile(baseProfile())
    end
end

function Transitions.Enabled()
    if not ns.db then return true end
    return ns.db[ENABLED_KEY] ~= false
end

-- /ubf transitions [on|off|status]
function Transitions.Command(args)
    local word = (args or ""):match("^(%S*)"):lower()
    if word == "on" then
        Transitions.SetEnabled(true)
        print("context transitions: on")
    elseif word == "off" then
        Transitions.SetEnabled(false)
        print("context transitions: off")
    elseif word == "status" or word == "" then
        local ctx = ns.Context and ns.Context.Current() or "?"
        local live = state.appliedBars and table.concat(state.appliedBars, ", ") or "not applied"
        print(("transitions: %s, context %s, live bars %s%s"):format(
            Transitions.Enabled() and "on" or "off", ctx, live,
            state.lastReason and (" (last: " .. state.lastReason .. ")") or ""))
    else
        print("usage: /ubf transitions [on|off|status]")
    end
end

return Transitions
