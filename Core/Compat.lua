local _, ns = ...

-- GetBuildInfo returns version, build, date, tocversion. Forever ships TOC 16001
-- (1.60.x); Midnight retail ships 12xxxx.
local _, _, _, toc = GetBuildInfo()

ns.toc = toc
ns.isForever = toc == 16001
ns.gameType = ns.isForever and "Forever" or "Midnight"

-- True when the game's own gamepad interface is running (Forever loads
-- Blizzard_Gamepad, Midnight does not). It handles menus itself, so features
-- that take over buttons for menus start switched off while it is there.
function ns.HasNativeGamepad()
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return check("Blizzard_Gamepad") and true or false
end
