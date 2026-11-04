local _, ns = ...

-- Finds the tabs of an open window and steps between them with the shoulder buttons, the way
-- Blizzard's own controller screens do. Two kinds of tabs exist on both game builds:
--   tab systems:    window.tabs (a list of tab buttons with GetTabID) and window.selectedTabID
--   panel tabs:     window.numTabs and window.selectedTab, the buttons in window.Tabs[i]
--                   or in a global named <window>Tab<i>
local Tabs = {}
ns.Tabs = Tabs

local MAX_DEPTH = 6

local function usable(button)
    return type(button) == "table" and button.IsShown and button:IsShown() and button.IsEnabled and button:IsEnabled() and button.Click
end

-- Returns the usable tab buttons in order and the position of the selected one (or nil).
local function fromFrame(frame)
    if type(frame.tabs) == "table" and frame.selectedTabID ~= nil then
        local list, selected = {}, nil
        for _, button in ipairs(frame.tabs) do
            if usable(button) then
                list[#list + 1] = button
                if button.GetTabID and button:GetTabID() == frame.selectedTabID then
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
            if usable(button) then
                list[#list + 1] = button
                if i == frame.selectedTab then
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

-- direction is -1 or 1; goes round at the ends. Returns true if a tab was clicked.
function Tabs.Step(direction)
    local list, selected = Tabs.Find()
    if not list then
        return false
    end
    local target = ((selected or (direction > 0 and 0 or 1)) - 1 + direction) % #list + 1
    local ok = pcall(list[target].Click, list[target])
    ns.Log(("tab step %d: %d of %d %s"):format(direction, target, #list, ok and "ok" or "failed"))
    return ok
end
