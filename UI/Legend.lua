local _, ns = ...

-- A button legend: the control prompts the game's own controller screens show along the bottom,
-- a button picture and its action in the standard gold text. Two picture styles exist. The
-- Midnight style uses the lettered button art that is in both game builds; the Forever style
-- uses the art Forever's own screens use, which Midnight does not have. By default each game
-- uses its own style, and the choice can be changed in the options.
local Legend = {}
ns.Legend = Legend

local ICON = 20
local GAP = "     "

-- The lettered art, named as Blizzard's own binding text names it (Gamepad_<name>_64).
local MIDNIGHT = {
    PAD1 = "Ltr_A", PAD2 = "Ltr_B", PAD3 = "Ltr_X", PAD4 = "Ltr_Y",
    PADLSHOULDER = "Ltr_LShoulder", PADRSHOULDER = "Ltr_RShoulder",
    PADLTRIGGER = "Ltr_LTrigger", PADRTRIGGER = "Ltr_RTrigger",
    PADFORWARD = "Ltr_Menu", PADBACK = "Ltr_View",
    PADDUP = "Ltr_Up", PADDDOWN = "Ltr_Down", PADDLEFT = "Ltr_Left", PADDRIGHT = "Ltr_Right",
}
-- The art Forever's screens use, from its own input icon list.
local FOREVER = {
    PAD1 = "gamepad-xbox1-buttona-normal", PAD2 = "gamepad-xbox1-buttonb-normal",
    PAD3 = "gamepad-xbox1-buttonx-normal", PAD4 = "gamepad-xbox1-buttony-normal",
    PADLSHOULDER = "gamepad-xbox1-trigger-lb-normal", PADRSHOULDER = "gamepad-xbox1-trigger-rb-normal",
    PADLTRIGGER = "gamepad-xbox1-trigger-lt-normal", PADRTRIGGER = "gamepad-xbox1-trigger-rt-normal",
    PADFORWARD = "gamepad-xbox1-menu-normal", PADBACK = "gamepad-xbox1-view-normal",
    DPAD = "gamepad-xbox1-dpadall-normal",
}
local FOREVER_BACKGROUND = "gamepad-footer-slot-bg"

Legend.STYLES = { "Midnight", "Forever" }

local function atlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function Legend.Choice()
    return ns.db.legendStyle or "Auto"
end

function Legend.SetChoice(choice)
    ns.db.legendStyle = choice ~= "Auto" and choice or nil
    Legend.RefreshAll()
end

-- The style in use: the choice, or this game's own style when the choice is Auto.
function Legend.Style()
    local choice = Legend.Choice()
    if choice == "Auto" then
        return ns.isForever and "Forever" or "Midnight"
    end
    return choice
end

-- False when a style's art is not in this game build, so the legend falls back to the other.
function Legend.Available(style)
    return style ~= "Forever" or atlasExists(FOREVER.PAD1)
end

local function glyph(key, style)
    if style == "Forever" and Legend.Available("Forever") then
        local atlas = FOREVER[key]
        if atlas then
            return ("|A:%s:%d:%d|a"):format(atlas, ICON, ICON)
        end
    end
    local name = MIDNIGHT[key]
    if name and atlasExists("Gamepad_" .. name .. "_64") then
        return ("|A:Gamepad_%s_64:%d:%d|a"):format(name, ICON, ICON)
    end
    return "[" .. key:gsub("^PAD", "") .. "]"
end

-- An entry's keys may be several buttons ("PADLTRIGGER", "PADRTRIGGER"), or "DPAD" for all four.
local function entryText(entry, style)
    local pieces = {}
    for _, key in ipairs(entry.keys) do
        if key == "DPAD" and not (style == "Forever" and Legend.Available("Forever")) then
            pieces[#pieces + 1] = glyph("PADDUP", style) .. glyph("PADDDOWN", style)
                .. glyph("PADDLEFT", style) .. glyph("PADDRIGHT", style)
        else
            pieces[#pieces + 1] = glyph(key, style)
        end
    end
    return table.concat(pieces) .. " " .. entry.text
end

local legends = {}

local function render(legend)
    local style = Legend.Style()
    local parts = {}
    for _, entry in ipairs(legend.entries) do
        parts[#parts + 1] = entryText(entry, style)
    end
    legend.text:SetText(table.concat(parts, GAP))
    if legend.background then
        local usable = style == "Forever" and Legend.Available("Forever") and atlasExists(FOREVER_BACKGROUND)
        if usable then
            legend.background:SetAtlas(FOREVER_BACKGROUND)
        else
            legend.background:SetColorTexture(0, 0, 0, 0.6)
        end
        legend:SetWidth(legend.text:GetStringWidth() + 30)
    end
end

-- options.background: draw a backing panel (for the free-standing legend). The parent decides
-- where it sits; text only otherwise.
function Legend.Create(parent, options)
    local legend = CreateFrame("Frame", nil, parent)
    legend:SetHeight(ICON + 12)
    legend:EnableMouse(false)
    legend.entries = {}
    if options and options.background then
        legend.background = legend:CreateTexture(nil, "BACKGROUND")
        legend.background:SetAllPoints()
    end
    legend.text = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    legend.text:SetPoint("CENTER")
    legends[#legends + 1] = legend
    function legend:Set(entries)
        self.entries = entries
        render(self)
    end
    return legend
end

function Legend.RefreshAll()
    for _, legend in ipairs(legends) do
        render(legend)
    end
end

-- The free-standing legend shown while a window is open and the buttons are taken.
local shownLegend
local lastKey

function Legend.Show(tabs)
    if not shownLegend then
        shownLegend = Legend.Create(UIParent, { background = true })
        shownLegend:SetFrameStrata("TOOLTIP")
        shownLegend:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 90)
    end
    local L = ns.L
    local entries = {
        { keys = { "DPAD" }, text = L.LEGEND_MOVE },
        { keys = { "PAD1" }, text = L.LEGEND_SELECT },
        { keys = { "PAD3" }, text = L.LEGEND_USE },
        { keys = { "PADLTRIGGER", "PADRTRIGGER" }, text = L.LEGEND_SCROLL },
    }
    if tabs then
        entries[#entries + 1] = { keys = { "PADLSHOULDER", "PADRSHOULDER" }, text = L.LEGEND_TABS }
    end
    entries[#entries + 1] = { keys = { "PAD2" }, text = L.LEGEND_BACK }
    local key = (tabs and "t" or "n") .. Legend.Style()
    if key ~= lastKey or not shownLegend:IsShown() then
        lastKey = key
        shownLegend:Set(entries)
    end
    shownLegend:Show()
end

-- One line for /ubf legend: whether the free-standing legend exists, is shown, and what it says.
function Legend.Status()
    if not shownLegend then
        return "legend: never shown" .. (Legend.lastError and (", last error " .. tostring(Legend.lastError)) or "")
    end
    return ("legend: %s, style %s, width %.0f, text %q%s"):format(shownLegend:IsShown() and "shown" or "hidden",
        Legend.Style(), tonumber(shownLegend:GetWidth()) or 0, tostring(shownLegend.text:GetText()),
        Legend.lastError and (", last error " .. tostring(Legend.lastError)) or "")
end

function Legend.Hide()
    if shownLegend then
        shownLegend:Hide()
    end
    lastKey = nil
end
