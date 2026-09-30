-- ForeverPath / Core / Util.lua
local ADDON, FP = ...
local U = {}
FP.Util = U

local floor, sqrt, atan2, pi = math.floor, math.sqrt, math.atan2, math.pi

function U.Now()
	return FP.API.Now()
end

function U.Round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return floor(n * m + 0.5) / m
end

-- Map coordinates are stored with 4 decimals (0.0001 of a map ~ 0.5 yd in a zone).
function U.Coord(v)
	return floor(v * 10000 + 0.5) / 10000
end

function U.FormatCoords(x, y)
	if not x or not y then return "?" end
	return string.format("%.1f, %.1f", x * 100, y * 100)
end

function U.FormatDistance(yards)
	if not yards then return "?" end
	if yards >= 10000 then return string.format("%.1fk yd", yards / 1000) end
	if yards >= 1000 then return string.format("%.2fk yd", yards / 1000) end
	return string.format("%d yd", floor(yards + 0.5))
end

function U.FormatTime(seconds)
	if not seconds or seconds < 0 then return "?" end
	seconds = floor(seconds + 0.5)
	if seconds < 60 then return seconds .. "s" end
	local m = floor(seconds / 60)
	local s = seconds % 60
	if m < 60 then return string.format("%dm%02ds", m, s) end
	return string.format("%dh%02dm", floor(m / 60), m % 60)
end

function U.MoneyString(copper)
	copper = tonumber(copper) or 0
	local g = floor(copper / 10000)
	local s = floor((copper % 10000) / 100)
	local c = copper % 100
	if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
	if s > 0 then return string.format("%ds %dc", s, c) end
	return string.format("%dc", c)
end

function U.Trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function U.Split(s, sep)
	local out = {}
	sep = sep or "%s"
	for piece in tostring(s or ""):gmatch("([^" .. sep .. "]+)") do out[#out + 1] = piece end
	return out
end

function U.Count(t)
	local n = 0
	if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
	return n
end

function U.Copy(t)
	local o = {}
	for k, v in pairs(t) do o[k] = v end
	return o
end

function U.Finite(n)
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function U.ValidMapPoint(mapID, x, y)
	return U.Finite(mapID) and mapID > 0 and mapID == floor(mapID)
		and U.Finite(x) and x >= 0 and x <= 1 and U.Finite(y) and y >= 0 and y <= 1
end

-- Push onto a bounded list (ring semantics: oldest dropped).
function U.Push(list, value, max)
	list[#list + 1] = value
	if max then
		while #list > max do table.remove(list, 1) end
	end
	return value
end

-- GUID: "Creature-0-4379-0-13-3131-00003BB8D2" -> "Creature", 3131
-- Player GUIDs ("Player-<server>-<hex>") return "Player", nil.
function U.ParseGUID(guid)
	if type(guid) ~= "string" then return nil end
	local kind, rest = guid:match("^([A-Za-z]+)%-(.+)$")
	if not kind then return nil end
	if kind == "Creature" or kind == "Vehicle" or kind == "Pet" or kind == "GameObject" then
		local parts = U.Split(rest, "-")
		-- 0-serverID-instanceID-zoneUID-ID-spawnUID
		local id = tonumber(parts[5])
		return kind, id
	end
	return kind, nil
end

-------------------------------------------------------------------------------
-- Geometry. World coordinates from C_Map.GetWorldPosFromMapPos are
-- (x = north, y = west). GetPlayerFacing is radians counter-clockwise from
-- north (pi/2 = west). Bearing uses the same convention so arrow = bearing - facing.
-------------------------------------------------------------------------------
function U.Distance(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	return sqrt(dx * dx + dy * dy)
end

function U.Bearing(px, py, tx, ty)
	return atan2(ty - py, tx - px)
end

function U.NormalizeAngle(a)
	while a > pi do a = a - 2 * pi end
	while a <= -pi do a = a + 2 * pi end
	return a
end

function U.Centroid(points)
	local n, sx, sy = 0, 0, 0
	for _, p in ipairs(points) do
		if p.x and p.y then
			n = n + 1
			sx, sy = sx + p.x, sy + p.y
		end
	end
	if n == 0 then return nil end
	return sx / n, sy / n, n
end

-- Screen offset of a target on a north-up (or facing-up) circular minimap.
-- rel = angle counter-clockwise from "up"; returns x (right), y (up).
function U.RadialOffset(rel, pixels)
	return -math.sin(rel) * pixels, math.cos(rel) * pixels
end

function U.Plural(n, word)
	return n .. " " .. word .. ((n == 1) and "" or "s")
end

function U.Truncate(s, n)
	s = tostring(s or "")
	if #s <= n then return s end
	return s:sub(1, n - 1) .. "…"
end
