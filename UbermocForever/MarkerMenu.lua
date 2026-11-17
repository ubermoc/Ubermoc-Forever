----------------------------------------------------------------------
-- Ubermoc Forever: our own target marker menu, built with the game's own menu code.
--
-- A on the game's "Target Marker Icon" entry (GameNav PostClick) calls M.open here instead of running the entry's
-- mouse-down: the game's marker submenu was built from our hook, so the build ran tainted and raised the warnings
-- (docs/RESEARCH-NAVIGATION.md, "The marker submenu built with the game's own menu code", 1.3.71).
-- The menu is made with the game's own menu code (MenuUtil.CreateContextMenu), with the game's own marker names
-- (RAID_TARGET_1..8, RAID_TARGET_NONE) and marker pictures, in the game's order: 8 down to 1, then None. The entries
-- have no callback (the game allows a nil responder, Menu.lua), so a mouse click on one does nothing: the marker is
-- still set by the secure raidtarget button UbermocForeverMarkBtn through GameNav's G.markerOf, as in 1.3.67.
-- No check mark for the current marker: the game's read of it (GetRaidTargetIndex) is the secret value that raised
-- the warning, so we never call it.
-- The owner region cannot be the entry we were called from: opening closes every other menu first (so the entry
-- hides) and a menu closes when its owner is not visible, and ignoreOwner is not on the proxy API. The owner is
-- TargetFrame, as in the game's own TargetFrame_OpenMenu, and the menu is anchored to its right. If the target frame
-- is hidden, open returns false and GameNav keeps its old submenu path.
----------------------------------------------------------------------
local ADDON, UF = ...
local M = {}
UF.MarkerMenu = M

-- The nine entry texts in the game's order: markers 8 down to 1, then None.
function M.order()
    local out = {}
    for i = 8, 1, -1 do
        local name = _G["RAID_TARGET_" .. i]
        if name then out[#out + 1] = name end
    end
    if _G.RAID_TARGET_NONE then out[#out + 1] = _G.RAID_TARGET_NONE end
    return out
end

-- An entry's text -> its marker number (None is 0), or nil for anything else.
function M.markerNumber(text)
    if type(text) ~= "string" then return nil end
    if _G.RAID_TARGET_NONE and text == _G.RAID_TARGET_NONE then return 0 end
    for i = 1, 8 do
        local name = _G["RAID_TARGET_" .. i]
        if name and name == text then return i end
    end
    return nil
end

M.menu = nil   -- the menu frame of the last open

-- The marker's picture, the same calls the game's marker entry uses (UnitPopupSharedButtonMixins.lua, the 1.3.71 notes).
local function icon(marker)
    return function(frame)
        local ok, tex = pcall(function() return frame:AttachTexture() end)
        if not ok or not tex then return nil end
        tex:SetSize(16, 16)
        tex:SetPoint("RIGHT")
        if marker and marker > 0 then
            tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            tex:SetSpriteSheetCell(marker, _G.RAID_TARGET_TEXTURE_ROWS or 4, _G.RAID_TARGET_TEXTURE_COLUMNS or 4)
        else
            tex:SetTexture("")
        end
        local fs = frame.fontString
        if not fs then return nil end
        fs:SetPoint("RIGHT", tex, "LEFT")
        -- the size is given because the icon is right-justified, as the game's entry does
        local w = fs.GetUnboundedStringWidth and select(2, pcall(fs.GetUnboundedStringWidth, fs)) or 40
        return w + 60, 20
    end
end

-- The title: the target's name, or the game's entry name when the name cannot be read for us (it can be a secret value).
local function titleText()
    if not UnitName then return _G.RAID_TARGET_ICON end
    local ok, name = pcall(UnitName, "target")
    if ok and type(name) == "string" then
        local okS, secret = true, false
        if issecretvalue then okS, secret = pcall(issecretvalue, name) end   -- pcall's first result is always true: the second is the answer
        if okS and not secret then return name end
    end
    return _G.RAID_TARGET_ICON
end

local function generator(_, root)
    root:CreateTitle(titleText())
    for _, text in ipairs(M.order()) do
        local marker = M.markerNumber(text)
        local d = root:CreateButton(text, nil, marker)
        d:AddInitializer(icon(marker))
    end
end

-- Open our menu to the right of the target frame. True when the menu is up; false leaves the caller to its old path.
function M.open(anchorFrame)
    if not (MenuUtil and MenuUtil.CreateContextMenu and Menu and Menu.GetManager) then return false end
    local owner = _G.TargetFrame
    if not (owner and owner.IsVisible and owner:IsVisible()) then return false end
    local ok, menu = pcall(MenuUtil.CreateContextMenu, owner, generator)
    if not ok or not menu then return false end
    M.menu = menu
    if menu.ClearAllPoints and menu.SetPoint then
        pcall(menu.ClearAllPoints, menu)
        pcall(menu.SetPoint, menu, "LEFT", owner, "RIGHT")
    end
    return true
end
