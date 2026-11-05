local _, ns = ...

-- GetBuildInfo returns version, build, date, tocversion. This addon ships
-- TOC 16001 (1.60.x) for World of Warcraft: Forever.
local _, _, _, toc = GetBuildInfo()

ns.toc = toc
ns.gameType = "Forever"

-- True when the game's own gamepad interface is running (Blizzard_Gamepad loaded).
-- When it's active, menu-capturing features start off so they don't conflict.
function ns.HasNativeGamepad()
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return check("Blizzard_Gamepad") and true or false
end
