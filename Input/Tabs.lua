local _, ns = ...

-- Finds the tabs of an open window and steps between them with the shoulder buttons, the way
-- Blizzard's own controller screens do. Two kinds of tabs exist on both game builds:
--   tab systems:    window.tabs (a list of tab buttons with GetTabID) and window.selectedTabID
--   panel tabs:     window.numTabs and window.selectedTab, the buttons in window.Tabs[i]
--                   or in a global named <window>Tab<i>
local Tabs = {}
ns.Tabs = Tabs

local MAX_DEPTH = 6

-- A tab can be gone to when it is shown and enabled. The tab you are on is the exception: the game
-- disables the selected tab, so it has to count anyway or the current position would be lost.
local function usable(button, isSelected)
    return type(button) == "table" and button.IsShown and button:IsShown() and button.Click
        and (isSelected or (button.IsEnabled and button:IsEnabled()))
end

-- Returns the usable tab buttons in order and the position of the selected one (or nil).
local function fromFrame(frame)
    if type(frame.tabs) == "table" and frame.selectedTabID ~= nil then
        local list, selected = {}, nil
        for _, button in ipairs(frame.tabs) do
            local isSelected = button.GetTabID and button:GetTabID() == frame.selectedTabID
            if usable(button, isSelected) then
                list[#list + 1] = button
                if isSelected then
                    selected = #list
                end
            end
        end
        if #list > 1 then
            return list, selected
        end
    end
    if type(frame.numTabs) == "number" and frame.selectedTab ~= nil and frame.GetName then
        local name = frame:GetName()
        local list, selected = {}, nil
        for i = 1, frame.numTabs do
            local button = (type(frame.Tabs) == "table" and frame.Tabs[i]) or (name and _G[name .. "Tab" .. i])
            local isSelected = i == frame.selectedTab
            if usable(button, isSelected) then
                list[#list + 1] = button
                if isSelected then
                    selected = #list
                end
            end
        end
        if #list > 1 then
            return list, selected
        end
    end
end

local function search(frame, depth)
    if frame.IsForbidden and frame:IsForbidden() then
        return
    end
    local list, selected = fromFrame(frame)
    if list then
        return list, selected
    end
    if depth < MAX_DEPTH and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local found, at = search(child, depth + 1)
            if found then
                return found, at
            end
        end
    end
end

-- The tabs of the first open window that has any.
function Tabs.Find()
    for _, root in ipairs(ns.Cursor.OpenWindows()) do
        local ok, list, selected = pcall(search, root, 0)
        if ok and list then
            return list, selected
        end
    end
end

function Tabs.Available()
    return Tabs.Find() ~= nil
end

-- direction is -1 or 1; goes round at the ends. Returns the tab button to go to, or nil.
-- The tab is not clicked from here: a click made by addon code runs the tab's handler as addon
-- code, and handlers that use protected functions (the Encounter Journal's, for one) are blocked.
-- The cursor goes to the tab instead and a real click is sent (see Cursor.TabStep).
function Tabs.Target(direction)
    local list, selected = Tabs.Find()
    if not list then
        return nil
    end
    local target = ((selected or (direction > 0 and 0 or 1)) - 1 + direction) % #list + 1
    ns.Log(("tab target %d: %d of %d"):format(direction, target, #list))
    return list[target]
end
