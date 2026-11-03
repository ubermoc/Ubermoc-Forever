local _, ns = ...

-- GetBuildInfo returns version, build, date, tocversion. Forever ships TOC 16001
-- (1.60.x); Midnight retail ships 12xxxx.
local _, _, _, toc = GetBuildInfo()

ns.toc = toc
ns.isForever = toc == 16001
ns.gameType = ns.isForever and "Forever" or "Midnight"
