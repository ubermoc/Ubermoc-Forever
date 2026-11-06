local _, ns = ...

-- The Context engine polls game-frame visibility to classify what the player
-- is looking at.  Each context change fires OnEnter / OnExit callbacks so
-- modules like Layout can react automatically (disable on combat, etc.).
--
--   CURRENT CONTEXTS:
--     NONE        – nothing relevant open, normal gameplay
--     COMBAT      – UnitAffectingCombat("player") == true
--     SPELLBOOK   – BookPane or SpellBookFrame is shown
--     BAGS        – any bag frame visible
--     PROFESSIONS – profession window (Trainer, Blacksmithing…) is shown
--     NPC         – Questgiver or Gossip dialog active
--     MENU        – GameMenuFrame / SettingsPanel / addon menus
--
-- Listeners: Context.Register(fn) calls fn(contextEntered, contextLeft)

local Context = {}
ns.Context = Context

-- ─── State ──────────────────────────────────────────────────────────────────

local currentContext = "NONE"  -- highest-priority context at the moment
local listeners = {}           -- array of { id, fn }
local listenerId = 0

-- ─── Polling helpers ────────────────────────────────────────────────────────

local function shown(frame)
    return type(frame) == "table"
        and frame.IsShown ~= nil
        and pcall(frame.IsShown, frame) ~= false
end

local function inSpellBook()
    local sb = SpellBookFrame                        -- spell book frame on screen
    if sb and sb:IsShown() then return true end
    return false
end

local function inBags()
    for i = 1, MAX_BAG_FRAMES or 20 do
        if shown(_G["ContainerFrame" .. i]) then return true end
    end
    return shown(ContainerFrameCombinedBags)         -- retail single-bag
end

-- ─── Task 3: PROFESSIONS – all profession window types ──────────────────────

-- Full list of Blizzard profession frames across expansions.
-- luacheck: ignore
local _PROF_FRAMES = {
    ProfessionFrame,        -- general profession frame (Forever/retail)
    ProfessionFrameContainer,  -- universal container wrapper
    ProfessionMacroFrame,   -- Legion+ macro-tabbed professions
    ProfessionSkillFrame,   -- profession skill-tree / talent panel
    TradeSkillFrame,        -- legacy trade-skill tab
    EngineerBox,            -- engineering crafting box (bottom-right)
    EnchantingWindow,       -- enchanting window variant
    CookingFrame,           -- cooking frame
}

function inProfessions()
-- luacheck: ignore
    if shown(ProfessionFrame)               then return true end -- general profession frame
    if shown(ProfessionFrameContainer)      then return true end -- universal container wrapper
    if shown(ProfessionMacroFrame)          then return true end -- Legion+ macro-tabbed professions
    if shown(ProfessionSkillFrame)          then return true end -- skill-tree / talent panel
    if shown(TradeSkillFrame)               then return true end -- legacy trade-skill tab
    if shown(EngineerBox)                   then return true end -- engineering crafting box
    if shown(EnchantingWindow)              then return true end -- enchanting frame variant
    if shown(CookingFrame)                  then return true end -- cooking window
    return false
end

-- ─── Task 1: NPC – Questgiver + Gossip + QuestFrame ────────────────────────

-- All Blizzard frames that indicate an active NPC dialog.
function nearNPC()
-- luacheck: ignore
    if shown(QuestgiverFrame)  then return true end  -- quest-giving NPC dialog
    if shown(GossipFrame)      then return true end  -- general gossip (non-quest) NPC popup
    -- Task 1: QuestFrame is the standalone quest-frame used by some UIs
    local qf = QuestFrame
    if qf and qf:IsShown() then return true end
    return false
end

-- ─── Task 2: MENU – GameMenuFrame + SettingsPanel + addon menus ─────────────

function inMenu()
-- luacheck: ignore
    local frames = {GameMenuFrame, -- ESC menu / game pause (task 2)
                    SettingsPanel, -- Blizzard settings panel overlay  (task 2)
                    }
    for _, f in ipairs(frames) do
        if shown(f) then return true end
    end

    -- Check addon menus by inspecting UIParent children for modal popups.
    local count = UIParent and UIParent:GetNumChildren()
    if not count or count == 0 then return false end
    for i = 1, count do
        local child = select(i, UIParent:GetChildren())
        if type(child) == "table" and type(child.IsShown) == "function" and pcall(child.IsShown, child) then
            local name = type(child.GetName) == "function" and child:GetName()
            if name and _MENU_EXCLUDE[name] == nil then
                -- Known non-menu frames are in the exclusion list above.
                -- Any remaining popup with title text is an addon menu context.
                local title = type(child.GetTitle) == "function" and child:GetTitle()
                if title and #title > 0 then return true end
            end
        end
    end
    return false
end

-- Exclusions list: frames that match by pattern but are NOT menu contexts.
local _MENU_EXCLUDE = {
-- luacheck: ignore
    ["ContainerFrameCombinedBags"]      = true,
}

-- ─── Classification logic ──────────────────────────────────────────────────

-- Priority order matters: SpellBook and Profession may overlap, but each player
-- sees only one at a time.  Combat is always highest priority.
local function classify()
    if UnitAffectingCombat("player")         then return "COMBAT"       end
    if inSpellBook()                         then return "SPELLBOOK"    end
    if nearNPC()                             then return "NPC"          end
    if inProfessions()                       then return "PROFESSIONS"  end
    if inBags()                              then return "BAGS"         end
    if inMenu()                              then return "MENU"         end
    return "NONE"
end

-- ─── Task 5: Listener registry (expanded) ──────────────────────────────────

--- Register a listener that receives OnEnter/OnExit notifications.
-- @param fn Function called as fn(context, signal) where signal is "enter"/"exit"
-- @return numeric id to pass to Context.Unregister()
function Context.Register(fn)
    listenerId = listenerId + 1
    listeners[#listeners + 1] = { id = listenerId, fn = fn }
    return listenerId
end

--- Unregister a listener by its id. Returns true on success.
function Context.Unregister(id)
    for i = #listeners, 1, -1 do
        if listeners[i].id == id then
            table.remove(listeners, i)
            return true
        end
    end
    return false
end

--- Return count of registered listeners (for debugging).
function Context.ListenerCount()
    return #listeners
end

--- Return an array of listener identifiers for debugging.
function Context.ListenerNames()
    local out = {}
    for i, l in ipairs(listeners) do
        out[i] = ("listener-%d"):format(l.id)
    end
    return out
end

-- ─── Task 4: OnEnter / OnExit callbacks ─────────────────────────────────────

local function fireOnEnter(ctx)
    for _, l in ipairs(listeners) do
        local ok, err = pcall(l.fn, ctx, "enter")
        if not ok and ns.Log then
            ns.Log("context onenter error: " .. tostring(err))
        end
    end
end

local function fireOnExit(ctx)
    for _, l in ipairs(listeners) do
        local ok, err = pcall(l.fn, ctx, "exit")
        if not ok and ns.Log then
            ns.Log("context onexit error: " .. tostring(err))
        end
    end
end

local function onContextChange(oldCtx, newCtx)
    if oldCtx == newCtx then return end
    fireOnExit(oldCtx)
    fireOnEnter(newCtx)
    -- backward-compat: also call the original transition-style callback
    for _, l in ipairs(listeners) do
        local ok2, err = pcall(l.fn, newCtx, oldCtx)
        if not ok2 and ns.Log then
            ns.Log("context ontransition error: " .. tostring(err))
        end
    end
end

-- ─── OnUpdate poll frame ──────────────────────────────────────────────────
-- Polls every tick and fires context changes.  Combat is skipped here because
-- InCombatLockdown blocks the frame checks; combat events fire separately.

local pollFrame = CreateFrame("Frame")
pollFrame:SetScript("OnUpdate", function()
    if currentContext == "COMBAT" then return end

    local newCtx = classify()
    if newCtx ~= currentContext then
        onContextChange(currentContext, newCtx)
        currentContext = newCtx
        ns.Log("context -> " .. newCtx)
    end
end)

-- ─── Combat event frame ───────────────────────────────────────────────────
-- Combat transitions are time-critical: the addon must react before the first
-- action-lock frame fires.  We handle them directly here instead of polling.

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")   -- combat starts (instant)
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")     -- combat ends (after lock lifts)
combatFrame:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_REGEN_DISABLED" then
        onContextChange(currentContext, "COMBAT")
        currentContext = "COMBAT"
        ns.Log("combat started")

        -- Auto-close any open addon windows and release cursor input (Cursor module).
        if type(ns.Cursor.OnCombatStart) == "function" then
            pcall(ns.Cursor.OnCombatStart)
        end
    else
        -- Left combat; let OnUpdate classify normally on the next tick.
        onContextChange(currentContext, "NONE")
        currentContext = "NONE"
        ns.Log("combat ended, context reset for classification")
    end
end)

-- ─── Public query API ──────────────────────────────────────────────────────

function Context.Current()  return currentContext end
function Context.Is(name)   
    return name       and currentContext == name         end

function Context.InCombat()         return currentContext == "COMBAT"        end
function Context.IsSpellBook()      return currentContext == "SPELLBOOK"     end
function Context.IsInBags()         return currentContext == "BAGS"          end
function Context.IsProfessions()    return currentContext == "PROFESSIONS"   end
function Context.IsNearNPC()        return currentContext == "NPC"           end
function Context.IsMenu()           return currentContext == "MENU"          end

-- ─── Slash command: /ubf context ──────────────────────────────────────────

function Context.PrintState()
    local label = currentContext
    if currentContext == "NONE"      then label = "Normal gameplay"          end
    if currentContext == "COMBAT"    then label = "Combat"                   end
    print(("Context: %s"):format(label))
    print(("Listeners registered: %d"):format(#listeners))
end

-- ─── Auto-enable Layout on PLAYER_LOGIN (integration hook for Init.lua) ────

function Context.OnPlayerLogin()
   ns.Log("context engine init: auto-enabling layout")
    if type(ns.Layout.SetEnabled) == "function"  then
        pcall(ns.Layout.SetEnabled, true)  -- will handle in-combat pending
    end
end

return Context
