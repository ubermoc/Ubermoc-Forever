----------------------------------------------------------------------
-- Ubermoc Forever: the legend
-- A row of the game's own button pictures with what each does on the page you are on:
--   first button  = select / accept       second button = decline / back
--   third button  = clear (only on the key binds page)
--   fourth button = menus, and changes to fit the page.
--   left / right bumper = the previous / next hold on the key binds page.
-- The pictures follow the controller in use, so a Switch controller shows its own letters.
----------------------------------------------------------------------
local _, UF = ...

-- (the triggers and D-pad are used by the bar shown over the game's own windows, see GameNav.lua)
local ROLES = { "PAD1", "PAD2", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADDUP" }

-- How much a legend of this natural width is shrunk to fit the room it has: not at all when it fits, else down to a quarter smaller.
local MIN_SCALE = 0.75
function UF.legendScale(total, maxWidth, noWrap)
    if not maxWidth or total <= maxWidth then return 1 end
    return math.max(noWrap and 0.5 or MIN_SCALE, maxWidth / total)
end

-- Where each item of a legend goes. widths: the width of each item; limit: the room (nil = no limit); gap: space between items.
-- Fits on one row: they follow each other. Otherwise they go in a tidy grid of equal-width cells, evenly filled
-- (6 items in 3 + 3, not 4 + 2), so the rows line up instead of ending ragged. Returns { width, rows, items = { {x, row}, ... } }.
function UF.legendGrid(widths, limit, gap)
    gap = gap or 14
    local n = #widths
    local total = math.max(0, gap * (n - 1))
    local cell = 0
    for _, w in ipairs(widths) do total = total + w; cell = math.max(cell, w) end
    local items = {}
    if n == 0 then return { width = 1, rows = 1, items = items } end
    if not limit or total <= limit then
        local x = 0
        for i, w in ipairs(widths) do items[i] = { x = x, row = 0 }; x = x + w + gap end
        return { width = total, rows = 1, items = items }
    end
    local cols = math.max(1, math.min(n, math.floor((limit + gap) / (cell + gap))))
    local rows = math.ceil(n / cols)
    cols = math.ceil(n / rows)
    for i = 1, n do items[i] = { x = ((i - 1) % cols) * (cell + gap), row = math.floor((i - 1) / cols) } end
    return { width = cols * cell + (cols - 1) * gap, rows = rows, items = items }
end

function UF.CreateLegend(parent)
    local legend = CreateFrame("Frame", nil, parent)
    legend:SetHeight(22)
    legend.items = {}
    for i, pad in ipairs(ROLES) do
        local fs = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
        legend.items[i] = fs
    end
    legend.texts = {}

    function legend:Set(texts)
        self.texts = texts or {}
        self:Refresh()
    end

    -- With a maximum width (the bar under a game window) the items wrap onto more rows instead of running wider than the window.
    -- noWrap: one row only (a bar that has no room for a second): it shrinks further instead of wrapping.
    function legend:SetMaxWidth(w, noWrap)
        if self.maxWidth ~= w or self.noWrap ~= noWrap then
            self.maxWidth, self.noWrap = w, noWrap
            self:Refresh()
        end
    end

    function legend:Refresh()
        -- First the natural width of everything on one row; with a limit it is shrunk to fit, and only wraps when that is not enough.
        local total, n = 0, 0
        for i, pad in ipairs(ROLES) do
            local t = self.texts[pad]
            if t then
                self.items[i]:SetText(UF.glyph(pad) .. " " .. t)
                total = total + (self.items[i]:GetStringWidth() or 0) + 14
                n = n + 1
            end
        end
        total = math.max(0, total - 14)
        local scale = UF.legendScale(total, self.maxWidth, self.noWrap)
        self:SetScale(scale)
        local limit = (self.maxWidth and not self.noWrap) and (self.maxWidth / scale) or nil
        local shown, widths = {}, {}
        for i, pad in ipairs(ROLES) do
            local fs = self.items[i]
            local t = self.texts[pad]
            if t then
                fs:SetText(UF.glyph(pad) .. " " .. t)
                shown[#shown + 1] = fs
                widths[#widths + 1] = fs:GetStringWidth() or 0
            else
                fs:Hide()
            end
        end
        local grid = UF.legendGrid(widths, limit, 14)
        for k, fs in ipairs(shown) do
            local at = grid.items[k]
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", self, "TOPLEFT", at.x, -12 - at.row * 24)
            fs:Show()
        end
        self:SetWidth(math.max(grid.width, 1))
        self:SetHeight(24 * grid.rows)
    end

    UF.OnDetect(function() if legend:IsVisible() then legend:Refresh() end end)
    return legend
end
