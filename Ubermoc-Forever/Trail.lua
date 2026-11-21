----------------------------------------------------------------------
-- Ubermoc Forever: learned navigation. The game gives addons no roads, no terrain and no boat or zeppelin docks (checked with the scans in
-- NavScans.lua: 16 map points of interest, none a dock; the Encounter Journal that lists entrances is switched off in Forever), so this learns
-- them from play, quietly, and keeps what it learns in the saved settings (DB.learned), growing a little every time you play:
--   the walked trail   where you walk on foot, as a graph of points joined by the steps you took; a route is found along it, so a trip
--                      goes round the lake or the cliff you once walked round (and nothing is known where you have not walked)
--   rides              a boat, zeppelin or tram: where you boarded and where you got off, seen when the ground moves under you while
--                      you stand still, or when the world loads while you are on one; remembered per faction
--   entrances          the spot outside each dungeon or raid, noted when you walk in and again when you come out
-- All positions are the game's world positions (C_Map.GetWorldPosFromMapPos): yards, x to the north and y to the west on a continent
-- (checked against the map scan: Orgrimmar to Durotar's middle comes out at 1775 yd and Mulgore west-south-west of Durotar).
-- What is learned never expires and is only ever added to; /ubf learned says how much there is.
----------------------------------------------------------------------
local _, UF = ...

local T = { SAMPLE = 0.5 }
UF.Trail = T

-- tuning (yards, seconds)
T.NODE_GAP = 15          -- a new trail point only when this far from the last one
T.MERGE = 20             -- a point this close to a known one is that one
T.EDGE_MAX = 70          -- the longest step between two joined points
T.MAX_NODES = 8000       -- per continent: more would make the saved settings too big
T.PLATFORM_MIN = 1.5     -- yards moved in one sample while standing still, once a ride has started
T.PLATFORM_SUM = 8       -- a ride starts when the last 4 samples (2 seconds) at rest add up to this many yards: from the first real play data (2026-11-21)
                         -- the 1.5-yard rule alone started 27 false rides on 1 to 3 yards of drift while walking about and talking; none was long
                         -- enough to be learned, but a boat or a zeppelin moves 4 yards a second or more
T.RIDE_MIN = 150         -- a ride shorter than this is not a route
T.RIDE_SECONDS = 8       -- nor one shorter than this
T.RIDE_MERGE = 120       -- two rides whose ends are this close together are the same route
T.STILL_SAMPLES = 8      -- samples at rest before a ride is over (4 seconds)
T.LOG_MAX = 120

----------------------------------------------------------------------
-- Saved data
----------------------------------------------------------------------
local function store()
    local d = UF.DB()
    d.learned = d.learned or {}
    local L = d.learned
    L.v = L.v or 1
    L.trail = L.trail or {}
    L.rides = L.rides or {}
    L.entrances = L.entrances or {}
    L.log = L.log or {}
    return L
end
T.store = store

local function log(kind, a, b, c)
    local L = store()
    local t = GetTime and GetTime() or 0
    L.log[#L.log + 1] = { kind, math.floor(t), a, b, c }
    if #L.log > T.LOG_MAX then table.remove(L.log, 1) end
end

local function dist(a, b)
    if not (a and b and a.cont and a.cont == b.cont and a.wx and b.wx) then return nil end
    local dx, dy = a.wx - b.wx, a.wy - b.wy
    return math.sqrt(dx * dx + dy * dy)
end
T.dist = dist

local function copyPos(s)
    return { m = s.m, mx = s.mx, my = s.my, cont = s.cont, wx = s.wx, wy = s.wy }
end

----------------------------------------------------------------------
-- The walked trail: a graph per continent, kept in the saved settings as flat lists (x, y, and edges as pairs of point numbers), with an
-- index (cells and neighbour lists) built in memory the first time a continent is used
----------------------------------------------------------------------
local mem = {}    -- cont -> { cell = {}, adj = {}, ekey = {} }
local CELL = 40

local function cellKey(x, y) return math.floor(x / CELL) .. ":" .. math.floor(y / CELL) end

local function graph(cont, create)
    local L = store()
    local g = L.trail[cont]
    if not g then
        if not create then return nil end
        g = { x = {}, y = {}, e = {} }
        L.trail[cont] = g
    end
    local m = mem[cont]
    if not m or m.g ~= g then
        m = { g = g, cell = {}, adj = {}, ekey = {} }
        for i = 1, #g.x do
            local k = cellKey(g.x[i], g.y[i])
            m.cell[k] = m.cell[k] or {}
            m.cell[k][#m.cell[k] + 1] = i
            m.adj[i] = m.adj[i] or {}
        end
        for k = 1, #g.e - 1, 2 do
            local i, j = g.e[k], g.e[k + 1]
            m.adj[i] = m.adj[i] or {}; m.adj[j] = m.adj[j] or {}
            m.adj[i][#m.adj[i] + 1] = j; m.adj[j][#m.adj[j] + 1] = i
            m.ekey[math.min(i, j) * 100000 + math.max(i, j)] = true
        end
        mem[cont] = m
    end
    return g, m
end

-- the nearest known point within radius, as its number
local function nearest(cont, x, y, radius)
    local g, m = graph(cont, false)
    if not g then return nil end
    local best, bd = nil, radius * radius
    local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
    local reach = math.ceil(radius / CELL)
    for ix = cx - reach, cx + reach do
        for iy = cy - reach, cy + reach do
            local list = m.cell[ix .. ":" .. iy]
            if list then
                for _, i in ipairs(list) do
                    local dx, dy = g.x[i] - x, g.y[i] - y
                    local d = dx * dx + dy * dy
                    if d <= bd then best, bd = i, d end
                end
            end
        end
    end
    return best, best and math.sqrt(bd)
end
T.nearest = nearest

local function addPoint(g, m, cont, x, y)
    local i = #g.x + 1
    g.x[i], g.y[i] = math.floor(x + 0.5), math.floor(y + 0.5)
    local k = cellKey(x, y)
    m.cell[k] = m.cell[k] or {}
    m.cell[k][#m.cell[k] + 1] = i
    m.adj[i] = {}
    return i
end

local function addEdge(g, m, i, j)
    if i == j then return end
    local key = math.min(i, j) * 100000 + math.max(i, j)
    if m.ekey[key] then return end
    m.ekey[key] = true
    g.e[#g.e + 1], g.e[#g.e + 2] = i, j
    m.adj[i][#m.adj[i] + 1] = j
    m.adj[j][#m.adj[j] + 1] = i
end

local lastNode        -- { cont, i }: the point the last step ended on

-- a step on foot at a world position
function T.walk(cont, x, y)
    if not (cont and x and y) then return end
    local g, m = graph(cont, true)
    local i = nearest(cont, x, y, T.MERGE)
    if not i then
        if #g.x >= T.MAX_NODES then lastNode = nil; return end
        if lastNode and lastNode.cont == cont then
            local dx, dy = g.x[lastNode.i] - x, g.y[lastNode.i] - y
            if dx * dx + dy * dy < T.NODE_GAP * T.NODE_GAP then return end   -- not far enough for a new point
        end
        i = addPoint(g, m, cont, x, y)
    end
    if lastNode and lastNode.cont == cont and lastNode.i ~= i then
        local dx, dy = g.x[lastNode.i] - g.x[i], g.y[lastNode.i] - g.y[i]
        if dx * dx + dy * dy <= T.EDGE_MAX * T.EDGE_MAX then addEdge(g, m, lastNode.i, i) end
    end
    lastNode = { cont = cont, i = i }
end

-- the walk is broken: nothing joins across a ride, a loading screen or a mount in the air
function T.breakWalk() lastNode = nil end

-- A* over the trail from (ax, ay) to (bx, by) on a continent. Returns the list of points { x, y } including the two ends, and its length in
-- yards, or nil when you have not walked near both ends (within `reach` yards of each).
function T.path(cont, ax, ay, bx, by, reach)
    reach = reach or 120
    local g, m = graph(cont, false)
    if not g then return nil end
    local s = nearest(cont, ax, ay, reach)
    local t = nearest(cont, bx, by, reach)
    if not (s and t) then return nil end
    local function h(i) local dx, dy = g.x[i] - g.x[t], g.y[i] - g.y[t] return math.sqrt(dx * dx + dy * dy) end
    local open, gs, from, closed = { s }, { [s] = 0 }, {}, {}
    local fs = { [s] = h(s) }
    local expansions = 0
    while #open > 0 and expansions < 6000 do
        local bi, bf = 1, fs[open[1]]
        for k = 2, #open do if fs[open[k]] < bf then bi, bf = k, fs[open[k]] end end
        local cur = open[bi]
        open[bi] = open[#open]; open[#open] = nil
        if cur == t then
            local list, node = {}, t
            while node do table.insert(list, 1, { x = g.x[node], y = g.y[node] }); node = from[node] end
            local len = gs[t]
            table.insert(list, 1, { x = ax, y = ay })
            list[#list + 1] = { x = bx, y = by }
            local straight = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
            len = len + math.sqrt((ax - g.x[s]) ^ 2 + (ay - g.y[s]) ^ 2) + math.sqrt((bx - g.x[t]) ^ 2 + (by - g.y[t]) ^ 2)
            return list, len, straight
        end
        closed[cur] = true
        expansions = expansions + 1
        for _, nb in ipairs(m.adj[cur] or {}) do
            if not closed[nb] then
                local dx, dy = g.x[cur] - g.x[nb], g.y[cur] - g.y[nb]
                local cand = gs[cur] + math.sqrt(dx * dx + dy * dy)
                if not gs[nb] or cand < gs[nb] then
                    if not gs[nb] then open[#open + 1] = nb end
                    gs[nb], from[nb] = cand, cur
                    fs[nb] = cand + h(nb)
                end
            end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Rides: a moving platform under a player who is not moving (boat, zeppelin, tram), or the world loading during one
----------------------------------------------------------------------
local st = { prev = nil, lastWalk = nil, ride = nil, still = 0, crossed = false, win = {} }
T.state = st

local function faction()
    return (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
end

local function endRide(s, why)
    local r = st.ride
    st.ride, st.still = nil, 0
    if not r then return end
    local dur = (s.t or 0) - (r.t0 or 0)
    local far = r.from and s.cont and r.from.cont and (r.from.cont ~= s.cont or (dist(r.from, s) or 0) >= T.RIDE_MIN)
    log("ride-end", why, math.floor(r.len), math.floor(dur))
    if not (far and (r.len >= T.RIDE_MIN or r.from.cont ~= s.cont) and dur >= T.RIDE_SECONDS) then return end
    local L = store()
    local a, b, f = r.from, copyPos(s), faction()
    for _, leg in ipairs(L.rides) do
        if leg.f == f and leg.a.cont == a.cont and leg.b.cont == b.cont and (dist(leg.a, a) or 1e9) <= T.RIDE_MERGE and (dist(leg.b, b) or 1e9) <= T.RIDE_MERGE then
            leg.n = (leg.n or 1) + 1
            leg.secs = math.floor(dur)
            return
        end
    end
    L.rides[#L.rides + 1] = { f = f, a = a, b = b, n = 1, secs = math.floor(dur), len = math.floor(r.len) }
    log("ride-learned", f, #L.rides)
    if UF.say then UF.say("Learned a ride (" .. #L.rides .. " known): " .. math.floor(dur) .. " s.") end
end

-- one sample of the player: { t, cont, wx, wy, m, mx, my, speed, onTaxi, dead, swimming, flying, inInstance }
function T.feed(s)
    local prev = st.prev
    st.prev = s
    if not s then T.breakWalk(); return end
    if st.crossed then
        st.crossed = false
        if st.ride then endRide(s, "loading") end
        T.breakWalk()
        prev = nil
        st.win = {}
    end
    if s.onTaxi or s.dead then
        st.ride, st.lastWalk, st.win = nil, nil, {}
        T.breakWalk()
        return
    end
    local moved = prev and dist(prev, s) or nil
    local selfMove = (s.speed or 0) > 0.5
    if selfMove then
        st.win = {}
        if st.ride then endRide(s, "stepped off") end
        st.lastWalk = copyPos(s)
        -- the trail grows only from steps on foot on open ground
        if not (s.swimming or s.flying or s.inInstance or (s.speed or 0) > 20) then T.walk(s.cont, s.wx, s.wy) else T.breakWalk() end
    else
        local w = st.win
        w[#w + 1] = moved or 0
        if #w > 4 then table.remove(w, 1) end
        local sum, least = 0, 1e9
        for _, v in ipairs(w) do sum = sum + v; if v < least then least = v end end
        local sustained = #w == 4 and sum >= T.PLATFORM_SUM and least >= 1
        if moved and moved >= T.PLATFORM_MIN and (st.ride or sustained) then
            if not st.ride then
                st.ride = { from = st.lastWalk or (prev and copyPos(prev)) or copyPos(s), t0 = s.t, len = 0 }
                T.breakWalk()
                log("ride-start", math.floor(s.wx or 0), math.floor(s.wy or 0), math.floor(moved))
            end
            st.ride.len = st.ride.len + moved
            st.still = 0
        elseif st.ride then
            st.still = st.still + 1
            if st.still >= T.STILL_SAMPLES then endRide(s, "docked") end
        end
    end
end

-- the world loaded (PLAYER_ENTERING_WORLD): a ride in progress ends at the first sample after it
function T.loaded() st.crossed = true end

----------------------------------------------------------------------
-- Entrances: the spot outside, noted when you walk into an instance and when you come back out
----------------------------------------------------------------------
local outdoors, wasIn          -- the last position outside an instance; whether the last sample was inside one

-- instance: { id, name, kind } while inside one, else nil; s: the position sample
function T.instance(inst, s)
    local L = store()
    if inst and not wasIn and outdoors then
        local e = L.entrances[inst.id]
        if not e then e = { name = inst.name, kind = inst.kind, n = 0 }; L.entrances[inst.id] = e end
        e.name, e.kind, e.n = inst.name, inst.kind, (e.n or 0) + 1
        e.a = outdoors
        log("entrance-in", inst.id, inst.name)
    elseif not inst and wasIn and s and wasIn.id then
        local e = L.entrances[wasIn.id]
        if e then e.b = copyPos(s); log("entrance-out", wasIn.id, wasIn.name) end
    end
    wasIn = inst
    if not inst and s then outdoors = copyPos(s) end
end

----------------------------------------------------------------------
-- Reading the player and running
----------------------------------------------------------------------
local function plain(v)
    if type(v) ~= "number" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function T.read()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos) then return nil end
    local okM, m = pcall(C_Map.GetBestMapForUnit, "player")
    if not okM or not m then return nil end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if not okP or type(pos) ~= "table" then return nil end
    local mx, my = plain(pos.x), plain(pos.y)
    if not (mx and my) or (mx == 0 and my == 0) then return nil end
    local okW, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, m, { x = mx, y = my })
    if not okW or type(wp) ~= "table" then return nil end
    local wx, wy = plain(wp.x), plain(wp.y)
    if not (wx and wy and plain(cont)) then return nil end
    local speed = GetUnitSpeed and plain((GetUnitSpeed("player"))) or 0
    local inInst = IsInInstance and select(1, IsInInstance()) and true or false
    return {
        t = GetTime and GetTime() or 0, m = m, mx = mx, my = my, cont = cont, wx = wx, wy = wy, speed = speed or 0,
        onTaxi = UnitOnTaxi and UnitOnTaxi("player") and true or false,
        dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and true or false,
        swimming = IsSwimming and IsSwimming() and true or false,
        flying = IsFlying and IsFlying() and true or false,
        inInstance = inInst,
    }
end

local function instanceNow()
    if not (IsInInstance and GetInstanceInfo) then return nil end
    local inI, kind = IsInInstance()
    if not inI then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if not id then return nil end
    return { id = id, name = name, kind = kind }
end

function T.tick()
    local s = T.read()
    T.instance(instanceNow(), s)
    T.feed(s)
end

local started = false
function T.start()
    if started then return end
    started = true
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(T.SAMPLE, function() UF.try("Trail.tick", T.tick) end) end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function() T.loaded() end)
end
if UF.OnLogin then UF.OnLogin(T.start) end

----------------------------------------------------------------------
-- What the routing asks for
----------------------------------------------------------------------
-- the learned ride that gets from one continent to another fastest from a position to a target (walking at 7 yd/s, a ride at its learned time)
function T.bestRide(player, target, f)
    local L = store()
    local best, bc
    for _, leg in ipairs(L.rides) do
        if leg.f == f and leg.a.cont == player.cont and leg.b.cont == target.cont then
            local w1 = dist(player, leg.a) or 1e9
            local w2 = dist(leg.b, target) or 1e9
            local cost = w1 / 7 + (leg.secs or 120) + w2 / 7
            if not bc or cost < bc then best, bc = leg, cost end
        end
    end
    return best, bc
end

-- the way to the learned entrance of an instance, by id or by name
function T.entranceFor(idOrName)
    local L = store()
    local e = L.entrances[idOrName]
    if e then return e end
    for _, v in pairs(L.entrances) do
        if v.name == idOrName then return v end
    end
end

function T.counts()
    local L = store()
    local nodes, edges = 0, 0
    for _, g in pairs(L.trail) do nodes = nodes + #g.x; edges = edges + #g.e / 2 end
    local entrances = 0
    for _ in pairs(L.entrances) do entrances = entrances + 1 end
    return nodes, math.floor(edges), #L.rides, entrances
end

function T.report()
    local n, e, r, en = T.counts()
    UF.say(string.format("Learned so far: a trail of %d points and %d steps, %d rides, %d entrances. It only grows; play on foot, ride the boats and zeppelins, walk into the dungeons.", n, e, r, en))
    local L = store()
    for _, leg in ipairs(L.rides) do
        UF.say(string.format("  ride (%s): continent %s -> %s, %d s, seen %dx", tostring(leg.f), tostring(leg.a.cont), tostring(leg.b.cont), leg.secs or 0, leg.n or 1))
    end
    for id, v in pairs(L.entrances) do
        UF.say(string.format("  entrance: %s (%s), seen %dx%s", tostring(v.name), tostring(v.kind), v.n or 0, v.b and ", exit known" or ""))
    end
end
