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
--     MENU        – GameMenuFrame / SettingsPanel (not addon menus)
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
    if shown(BookPane) then return true end          -- retail (Midnight)
    local sb = SpellBookFrame                         -- legacy
    if sb and sb:IsShown() then return true end      -- Forever
    return false
end

local function inBags()
    for i = 1, MAX_BAG_FRAMES or 20 do
        if shown(_G["ContainerFrame" .. i]) then return true end
    end
    return shown(ContainerFrameCombinedBags)         -- retail single-bag
end

local function inProfessions()
    if shown(ProfessionFrame) then return true end
    if shown(ProfessionFrameContainer) then return true end
end

local function nearNPC()
    return shown(QuestgiverFrame) or shown(GossipFrame)
end

local function inMenu()
    return shown(GameMenuFrame) or (shown(SettingsPanel))
end

-- ─── Classification logic ──────────────────────────────────────────────────

-- Priority order matters: SpellBook and Profession may overlap, but each player
-- sees only one at a time.  Combat is always highest priority.
local function classify()
    if UnitAffectingCombat("player")      then return "COMBAT"         end
    if inSpellBook()                      then return "SPELLBOOK"     end
    if nearNPC()                          then return "NPC"           end
    if inProfessions()                    then return "PROFESSIONS"   end
    if inBags()                           then return "BAGS"          end
    if inMenu()                           then return "MENU"          end
    return "NONE"
end

-- ─── Listener management ──────────────────────────────────────────────────

function Context.Register(fn)
    listenerId = listenerId + 1
    listeners[#listeners + 1] = { id = listenerId, fn = fn }
    return listenerId
end

function Context.Unregister(id)
    for i = #listeners, 1, -1 do
        if listeners[i].id == id then
            table.remove(listeners, i)
            return true
        end
    end
    return false
end

-- ─── Context dispatch ──────────────────────────────────────────────────────
-- Called when the player enters or leaves a context.  Listeners run first; if
-- any of them signals an error it is logged but does not stop the others.

local function onContextChange(oldCtx, newCtx)
    if oldCtx == newCtx then return end
    for _, l in ipairs(listeners) do
        local ok, err = pcall(l.fn, newCtx, oldCtx)
        if not ok and ns.Log then
            ns.Log("context listener error: " .. tostring(err))
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
        onContextChange("COMBAT", "NONE")
        currentContext = "NONE"
        ns.Log("combat ended, context reset for classification")
    end
end)

-- ─── Public query API ──────────────────────────────────────────────────────

function Context.Current()  return currentContext end
function Context.Is(name)   return name and currentContext == name end

function Context.InCombat()         return currentContext == "COMBAT"        end
function Context.IsSpellBook()      return currentContext == "SPELLBOOK"     end
function Context.IsBags()           return currentContext == "BAGS"          end
function Context.IsProfessions()    return currentContext == "PROFESSIONS"   end
function Context.NearNPC()          return currentContext == "NPC"           end

-- ─── Slash command: /ubf context ──────────────────────────────────────────

function Context.PrintState()
    local label = currentContext
    if currentContext == "NONE" then
        label = "Normal gameplay"
      elseif currentContext == "COMBAT" then
        label = "Combat"
      end
    print(("Context: %s"):format(label))
    print("Listeners registered: %d", #listeners)
end

-- ─── Auto-enable Layout on PLAYER_LOGIN (integration hook for Init.lua) ────

function Context.OnPlayerLogin()
    ns.Log("context engine init: auto-enabling layout")
    if type(ns.Layout.SetEnabled) == "function" then
        pcall(ns.Layout.SetEnabled, true)  -- will handle pending in combat
    end
end

return Context
