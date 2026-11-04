local _, ns = ...

-- A button legend: the control prompts the game's own controller screens show along the bottom,
-- a button picture and its action in the standard gold text. Two picture styles exist. The
-- Midnight style uses the lettered button art that is in both game builds; the Forever style
-- uses the art Forever's own screens use, which Midnight does not have. By default each game
-- uses its own style, and the choice can be changed in the options.
local Legend = {}
ns.Legend = Legend

local ICON = 18
local GAP = "   "
local NBSP = "\194\160"

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
            -- Midnight has no single picture for the whole D-pad; one direction stands for it.
            pieces[#pieces + 1] = glyph("PADDUP", style)
        else
            pieces[#pieces + 1] = glyph(key, style)
        end
    end
    return table.concat(pieces) .. NBSP .. entry.text
end

local legends = {}

local PAD_X, PAD_Y = 10, 8

local function render(legend)
    local style = Legend.Style()
    local parts = {}
    for _, entry in ipairs(legend.entries) do
        parts[#parts + 1] = entryText(entry, style)
    end
    legend.text:SetText(table.concat(parts, GAP))
    if legend.footer then
        -- The height follows the wrapped text, so a narrow window gets a second line at the same
        -- text size instead of a smaller legend.
        legend:SetHeight(legend.text:GetStringHeight() + 2 * PAD_Y)
    end
end

-- options.footer: a bar that belongs to a window (see Legend.Show): the game's own tooltip panel
-- look, as wide as the window, text wrapping inside it. Otherwise plain text that the parent places.
function Legend.Create(parent, options)
    local footer = options and options.footer
    local legend
    if footer then
        local ok, made = pcall(CreateFrame, "Frame", nil, parent, "TooltipBackdropTemplate")
        if ok then
            legend = made
        else
            ns.Log("tooltip panel failed for the legend: " .. tostring(made))
            legend = CreateFrame("Frame", nil, parent)
            legend.fallback = legend:CreateTexture(nil, "BACKGROUND")
            legend.fallback:SetAllPoints()
            legend.fallback:SetColorTexture(0, 0, 0, 0.7)
        end
    else
        legend = CreateFrame("Frame", nil, parent)
    end
    legend:SetHeight(ICON + 2 * PAD_Y)
    legend:EnableMouse(false)
    legend.entries = {}
    legend.footer = footer and true or nil
    legend.text = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if footer then
        legend.text:SetPoint("TOPLEFT", legend, "TOPLEFT", PAD_X, -PAD_Y)
        legend.text:SetJustifyH("LEFT")
        legend.text:SetJustifyV("TOP")
        legend.text:SetWordWrap(true)
    else
        legend.text:SetPoint("CENTER")
    end
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

-- Below the window and its tabs when there is room (tabs hang below the frame), above the window
-- when there is not. roomBelow is the space under the lowest tab in screen units, tabDrop how far
-- the tabs hang below the window in the window's own units. Returns "below" or "above", and the
-- gap from the window's edge.
local GAP_TO_WINDOW = 2
function Legend.ComputePlacement(roomBelow, height, tabDrop)
    if roomBelow >= height + 10 then
        return "below", math.max(0, tabDrop or 0) + GAP_TO_WINDOW
    end
    return "above", GAP_TO_WINDOW
end

-- The legend is part of the window it describes: a child of it, as wide as it, along its bottom
-- edge, so it moves, scales and hides with the window and is the same size on every tab.

local function attach(legend, root, tabButtons)
    local ui = UIParent:GetEffectiveScale()
    local scale = root:GetEffectiveScale()
    if legend:GetParent() ~= root then
        legend:SetParent(root)
        lastKey = nil
    end
    legend:SetFrameLevel(root:GetFrameLevel() + 1)
    local rootBottom = root:GetBottom() or 0
    local tabDrop = 0
    local lowestTab = rootBottom * scale / ui
    for _, tab in ipairs(tabButtons or {}) do
        local tabBottom = tab.GetBottom and tab:GetBottom()
        if tabBottom then
            local inRoot = tabBottom * tab:GetEffectiveScale() / scale
            tabDrop = math.max(tabDrop, rootBottom - inRoot)
            lowestTab = math.min(lowestTab, tabBottom * tab:GetEffectiveScale() / ui)
        end
    end
    -- the text wraps at the window's width, which is known before the frame has been laid out
    legend.text:SetWidth(math.max(50, root:GetWidth() - 2 * PAD_X))
    render(legend)
    local where, gap = Legend.ComputePlacement(lowestTab, legend:GetHeight() * scale / ui, tabDrop)
    legend:ClearAllPoints()
    if where == "below" then
        legend:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -gap)
        legend:SetPoint("TOPRIGHT", root, "BOTTOMRIGHT", 0, -gap)
    else
        legend:SetPoint("BOTTOMLEFT", root, "TOPLEFT", 0, gap)
        legend:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", 0, gap)
    end
end

function Legend.Show(tabs, root, tabButtons)
    if not root then
        Legend.Hide()
        return
    end
    if not shownLegend then
        shownLegend = Legend.Create(root, { footer = true })
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
    if key ~= lastKey then
        lastKey = key
        shownLegend:Set(entries)
    end
    attach(shownLegend, root, tabButtons)
    shownLegend:Show()
end

-- One line for /ubf legend: whether the free-standing legend exists, is shown, and what it says.
function Legend.Status()
    if not shownLegend then
        return "legend: never shown" .. (Legend.lastError and (", last error " .. tostring(Legend.lastError)) or "")
    end
    return ("legend: %s, style %s, width %.0f, height %.0f, text %q%s"):format(shownLegend:IsShown() and "shown" or "hidden",
        Legend.Style(), tonumber(shownLegend:GetWidth()) or 0, tonumber(shownLegend:GetHeight()) or 0, tostring(shownLegend.text:GetText()),
        Legend.lastError and (", last error " .. tostring(Legend.lastError)) or "")
end

function Legend.Hide()
    if shownLegend then
        shownLegend:Hide()
    end
    lastKey = nil
end
