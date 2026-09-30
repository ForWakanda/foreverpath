-- ForeverPath / Nav / Position.lua
-- Cached player position in map + world space, refreshed by a ticker only while
-- something (arrow, minimap pin, panel) needs it.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Pos = FP:NewModule("Pos")

local cache = { t = 0, valid = false }
Pos.cache = cache
local demand = {}
local ticker

function Pos:Refresh(force)
	local now = API.Time()
	if not force and (now - cache.t) < 0.05 then return cache end
	cache.t = now
	local mapID = API.GetBestMap()
	cache.mapID = mapID
	local x, y = API.GetPlayerMapPosition(mapID)
	if not x then
		cache.valid = false
		cache.x, cache.y, cache.wx, cache.wy = nil, nil, nil, nil
		cache.facing = API.GetFacing()
		cache.lastT, cache.speed = nil, nil
		return cache
	end
	local cont, wx, wy = API.GetWorldPos(mapID, x, y)
	if cont ~= cache.continent then cache.lastT, cache.speed = nil, nil end
	cache.x, cache.y = x, y
	cache.continent, cache.wx, cache.wy = cont, wx, wy
	cache.valid = wx ~= nil
	cache.facing = API.GetFacing()
	-- speed (yards/second), smoothed, for ETA
	if cache.valid then
		if cache.lastT then
			local dt = now - cache.lastT
			if dt >= 0.5 then
				local d = U.Distance(cache.lwx, cache.lwy, wx, wy)
				local v = d / dt
				if v <= 80 then
					cache.speed = cache.speed and (cache.speed * 0.7 + v * 0.3) or v
				end
				cache.lastT, cache.lwx, cache.lwy = now, wx, wy
			end
		else
			cache.lastT, cache.lwx, cache.lwy = now, wx, wy
		end
	end
	return cache
end

-- Position snapshot for the recorder: { m, x, y, z = zone }
function Pos:Snapshot()
	local c = self:Refresh()
	if not c.mapID or not c.x then return nil end
	local zone, sub = API.GetZoneText()
	return { m = c.mapID, x = U.Coord(c.x), y = U.Coord(c.y), z = zone, s = sub }
end

-- World coords for an arbitrary map point (cached per waypoint-like table).
function Pos:WorldOf(point)
	if not U.ValidMapPoint(point.mapID, point.x, point.y) then return nil end
	if point._wx and point._m == point.mapID and point._x == point.x and point._y == point.y then
		return point._c, point._wx, point._wy
	end
	local c, wx, wy = API.GetWorldPos(point.mapID, point.x, point.y)
	point._c, point._wx, point._wy = c, wx, wy
	point._m, point._x, point._y = point.mapID, point.x, point.y
	return c, wx, wy
end

-- Returns distance (yards), bearing (radians CCW from north), sameContinent.
-- Distance is nil when it cannot be computed (instance, other continent).
function Pos:VectorTo(point)
	local c = cache
	if not c.valid then return nil end
	local pc, wx, wy = self:WorldOf(point)
	if not wx then return nil end
	if pc ~= c.continent then return nil, nil, false end
	local d = U.Distance(c.wx, c.wy, wx, wy)
	local b = U.Bearing(c.wx, c.wy, wx, wy)
	return d, b, true
end

function Pos:DistanceTo(point)
	local d = self:VectorTo(point)
	return d
end

-- Distance between two stored map points using map yard sizes (cheap, no API
-- world conversion). Different maps -> nil.
function Pos:MapDistance(mapID, x1, y1, x2, y2)
	local w, h = API.GetMapWorldSize(mapID)
	if not w then return nil end
	local dx, dy = (x1 - x2) * w, (y1 - y2) * h
	return math.sqrt(dx * dx + dy * dy)
end

local function tick()
	Pos:Refresh(true)
	FP:Fire("POSITION", cache)
end

function Pos:Acquire(key)
	demand[key] = true
	if not ticker and C_Timer and C_Timer.NewTicker then
		ticker = C_Timer.NewTicker(0.1, function()
			local ok, err = pcall(tick)
			if not ok then FP:ReportError("position-tick", err) end
		end)
	end
end

function Pos:Release(key)
	demand[key] = nil
	if next(demand) == nil and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

function Pos:IsTicking() return ticker ~= nil end
