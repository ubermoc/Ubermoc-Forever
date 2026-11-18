----------------------------------------------------------------------
-- Ubermoc Forever: what a setting does, in words (UF.Describe), 1.3.126.
-- Every button of the options window carries a title and a description. Two places show them:
--   * the game's tooltip while the MOUSE is over the button (as before), and
--   * a panel at the bottom of the options window that follows the controller HIGHLIGHT (Nav.focus), so a player on a
--     controller reads what the highlighted setting does without a mouse.
-- A description can be fixed (Describe.set) or worked out when it is asked (Describe.fn), for rows whose meaning depends
-- on what is selected (a situation row of the Fading page, a bind row of the main page).
-- Only our own buttons and our own fonts are touched; nothing of the game's.
----------------------------------------------------------------------
local _, UF = ...
local D = {}
UF.Describe = D

D.DEFAULT_TITLE = "Ubermoc Forever"
D.DEFAULT_TEXT = "Move the highlight over a setting to read here what it does."

local function showTooltip(self)
    local title, text = D.of(self)
    if not title then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
end
local function hideTooltip() GameTooltip:Hide() end

local function wire(b)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", hideTooltip)
end

-- a fixed title and text
function D.set(b, title, text)
    if not b then return end
    b.ufTitle, b.ufDesc = title, text
    wire(b)
end

-- a title and text worked out when asked: fn(button) returns title, text
function D.fn(b, fn)
    if not b then return end
    b.ufDescFn = fn
    wire(b)
end

-- title, text of a button, or nil when it has none
function D.of(b)
    if not b then return nil end
    if b.ufDescFn then
        local ok, title, text = pcall(b.ufDescFn, b)
        if ok and title then return title, text end
    end
    return b.ufTitle, b.ufDesc
end

-- The panel: two font strings (title, text) that always show the highlighted button's description.
local panelTitle, panelText
function D.bind(titleFS, textFS)
    panelTitle, panelText = titleFS, textFS
    if UF.Nav then UF.Nav.onFocus = D.refresh end
    D.refresh()
end

function D.refresh()
    if not (panelTitle and panelText) then return end
    local focus = UF.Nav and UF.Nav.focus
    local title, text
    if focus and (not focus.IsVisible or focus:IsVisible()) then title, text = D.of(focus) end
    if not title then title, text = D.DEFAULT_TITLE, D.DEFAULT_TEXT end
    panelTitle:SetText(title)
    panelText:SetText(text or "")
end

-- The four buttons of a situation row (Normal, 0, -, +) used on the Fading, Bars and Chat pages. nameFn() is the name of the part
-- that is selected right now; stateLabel is the situation ("In combat", "On a flight path", "Out of combat").
function D.situation(r, stateLabel, nameFn)
    local function head(self) return (nameFn() or "This part") .. ": " .. stateLabel end
    D.fn(r.normal, function(self) return head(self), "Normal: leaves the game's own opacity for this situation. Nothing of ours is applied." end)
    D.fn(r.zero, function(self) return head(self), "0: makes the part completely see-through (invisible) for this situation." end)
    D.fn(r.minus, function(self) return head(self), "Less visible: lowers the opacity by one step (10 %) for this situation." end)
    D.fn(r.plus, function(self) return head(self), "More visible: raises the opacity by one step (10 %) for this situation." end)
end

-- "Hide for good" and "Reset this part" under a situation block.
function D.hideReset(hideBtn, resetBtn, nameFn)
    D.fn(hideBtn, function() return "Hide for good: " .. (nameFn() or "this part"), "Keeps this part invisible all the time, whatever the situation or the mouse does. A switches it on or off." end)
    D.fn(resetBtn, function() return "Reset: " .. (nameFn() or "this part"), "Removes every opacity setting of this part (all three situations and its own mouse-over value) so it goes back to the game's own." end)
end
