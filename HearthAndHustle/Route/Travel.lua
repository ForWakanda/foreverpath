-- HearthAndHustle / Route / Travel.lua
-- Long-distance help for the quest route: which zeppelin or ship crosses to the
-- continent of the next step, which flight point you know near it, and a
-- zone-by-zone order for the whole quest log.
-- Reference positions and straight lines only: no terrain, no ride times, no
-- timetable. It shows a way to travel; it never moves or chooses for you.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local T = FP:NewModule("Travel")

-- Crossings between the two continents. Each has two ends; either can be the
-- boarding side. Horde and neutral positions are where the zeppelin masters
-- and shipmasters stand in the QuestieDB Forever reference (read 2026-11-15).
-- The Alliance ships are the Classic routes with approximate docks: nobody has
-- confirmed them on Forever, so they are labelled as such wherever shown.
T.crossings = {
	{ kind = "Zeppelin", faction = "Horde",
		{ mapID = 1411, x = 0.5082, y = 0.1354, town = "Orgrimmar", place = "the zeppelin tower outside Orgrimmar" },
		{ mapID = 1420, x = 0.6074, y = 0.5887, town = "Undercity", place = "the zeppelin tower outside Undercity" } },
	{ kind = "Zeppelin", faction = "Horde",
		{ mapID = 1411, x = 0.5069, y = 0.1289, town = "Orgrimmar", place = "the zeppelin tower outside Orgrimmar" },
		{ mapID = 1434, x = 0.3143, y = 0.2991, town = "Grom'gol", place = "the zeppelin tower at Grom'gol Base Camp" } },
	{ kind = "Ship",
		{ mapID = 1413, x = 0.6354, y = 0.3861, town = "Ratchet", place = "the Ratchet dock" },
		{ mapID = 1434, x = 0.2608, y = 0.7335, town = "Booty Bay", place = "the Booty Bay dock" } },
	{ kind = "Ship", faction = "Alliance", approximate = true,
		{ mapID = 1437, x = 0.050, y = 0.635, town = "Menethil Harbor", place = "the Menethil Harbor docks" },
		{ mapID = 1445, x = 0.715, y = 0.563, town = "Theramore", place = "the Theramore dock" } },
	{ kind = "Ship", faction = "Alliance", approximate = true,
		{ mapID = 1437, x = 0.046, y = 0.571, town = "Menethil Harbor", place = "the Menethil Harbor docks" },
		{ mapID = 1439, x = 0.324, y = 0.438, town = "Auberdine", place = "the Auberdine dock" } },
}

local BOARD_RADIUS = 45      -- yards: close enough to say "board here"
local FLIGHT_MIN = 1500      -- yards: nearer than this a flight point is not worth naming
local TURNIN_PULL = 250      -- yards a ready turn-in is worth when ordering stops (same as the planner)
local MAX_FLIGHTS = 200

function T:Faction()
	if self.faction == nil then self.faction = API.GetCharInfo().faction or false end
	return self.faction or nil
end

-- Best crossing from a world position on one continent to a world position on
-- another: least straight-line travel to the boarding end plus from the far end.
function T:Crossing(fromCont, fx, fy, toCont, tx, ty)
	if fromCont == nil or toCont == nil or fromCont == toCont or not (fx and tx) then return nil end
	local faction, best = self:Faction(), nil
	for _, c in ipairs(self.crossings) do
		if not c.faction or c.faction == faction then
			for i = 1, 2 do
				local a, b = c[i], c[3 - i]
				local ac, ax, ay = FP.Pos:WorldOf(a)
				local bc, bx, by = FP.Pos:WorldOf(b)
				if ax and bx and ac == fromCont and bc == toCont then
					local d1, d2 = U.Distance(fx, fy, ax, ay), U.Distance(bx, by, tx, ty)
					if not best or d1 + d2 < best.cost then
						best = { crossing = c, from = a, to = b, dist = d1, after = d2, cost = d1 + d2 }
					end
				end
			end
		end
	end
	return best
end

-- The crossing to take now for a destination on another continent, with the
-- live distance and bearing to its boarding end. nil when the destination is on
-- this continent, the position is unknown or no crossing is known.
function T:Leg(target)
	local pos = FP.Pos.cache
	if not target or not pos.valid then return nil end
	local tc, tx, ty = FP.Pos:WorldOf(target)
	if not tx or tc == pos.continent then return nil end
	local now, memo = API.Time(), self.memo
	if not (memo and memo.target == target and memo.x == target.x and memo.y == target.y and memo.mapID == target.mapID
		and memo.continent == pos.continent and now - memo.t < 1) then
		memo = { target = target, x = target.x, y = target.y, mapID = target.mapID, continent = pos.continent, t = now,
			leg = self:Crossing(pos.continent, pos.wx, pos.wy, tc, tx, ty) }
		self.memo = memo
	end
	local leg = memo.leg
	if not leg then return nil end
	local _, ax, ay = FP.Pos:WorldOf(leg.from)
	leg.dist, leg.bearing = U.Distance(pos.wx, pos.wy, ax, ay), U.Bearing(pos.wx, pos.wy, ax, ay)
	leg.here = leg.dist <= BOARD_RADIUS
	return leg
end

function T:LegTitle(leg)
	return leg.crossing.kind .. " to " .. leg.to.town
end

-------------------------------------------------------------------------------
-- Flight points. Which ones this character knows comes from the flight maps it
-- has opened (kept whether or not the dataset recorder is on). Where each one
-- is comes from a fit: a flight map is the continent drawn to scale, so the
-- points where someone stood at the flight master tie map coordinates to world
-- coordinates, and the fit places every other point. The fit checks itself: a
-- poor one is not used, and the zone named in the point's name is used instead.
-------------------------------------------------------------------------------
local FIT_MAX_ERROR = 250    -- yards (root mean square) before a fit is distrusted

local function listed(name)
	return type(name) == "string" and name ~= "" and name:sub(1, 5) ~= "zzOLD"
end

function T:OnTaxiMap()
	local nodes, taxiMap = API.GetTaxiNodes()
	local store, now, here = FP.cdb.flights, U.Now(), nil
	for _, node in ipairs(nodes or {}) do
		if listed(node.name) and node.state ~= "Unreachable" then
			local rec = store[node.name] or {}
			store[node.name] = rec
			rec.t = now
			if U.Finite(node.x) and U.Finite(node.y) then rec.tm, rec.tx, rec.ty = taxiMap, U.Coord(node.x), U.Coord(node.y) end
			if node.state == "Current" then
				here = here or FP.Pos:Snapshot()
				if here then rec.m, rec.x, rec.y = here.m, here.x, here.y end
			end
		end
	end
	if U.Count(store) > MAX_FLIGHTS then
		local names = {}
		for name in pairs(store) do names[#names + 1] = name end
		table.sort(names, function(a, b) return (store[a].t or 0) > (store[b].t or 0) end)
		for i = MAX_FLIGHTS + 1, #names do store[names[i]] = nil end
	end
	self.fits, self.hintMemo = nil, nil
end

-- The recorder keeps flight points for the whole account. Its "known" marks are
-- this character's only when this is the one character it has ever seen.
function T:Seed()
	if FP.cdb.flightsSeeded then return end
	FP.cdb.flightsSeeded = true
	local chars = FP.data.chars or {}
	if U.Count(chars) ~= 1 or not chars[API.GetCharInfo().key] then return end
	local store = FP.cdb.flights
	for _, rec in pairs(FP.data.taxi.nodes or {}) do
		if rec.known and listed(rec.n) and not store[rec.n] then
			store[rec.n] = { t = 0, tm = rec.m, tx = rec.x, ty = rec.y, m = rec.pos and rec.pos.m, x = rec.pos and rec.pos.x, y = rec.pos and rec.pos.y }
		end
	end
end

-- Least-squares plane w = a*x + b*y + c through the samples; nil when they
-- are too few or lie on one line.
local function plane(samples, field)
	local sxx, sxy, sx, syy, sy, n, sxw, syw, sw = 0, 0, 0, 0, 0, 0, 0, 0, 0
	for _, s in ipairs(samples) do
		local x, y, w = s.tx, s.ty, s[field]
		sxx, sxy, sx, syy, sy, n = sxx + x * x, sxy + x * y, sx + x, syy + y * y, sy + y, n + 1
		sxw, syw, sw = sxw + x * w, syw + y * w, sw + w
	end
	local det = sxx * (syy * n - sy * sy) - sxy * (sxy * n - sy * sx) + sx * (sxy * sy - syy * sx)
	if n < 3 or math.abs(det) < 1e-9 then return nil end
	local a = (sxw * (syy * n - sy * sy) - sxy * (syw * n - sy * sw) + sx * (syw * sy - syy * sw)) / det
	local b = (sxx * (syw * n - sy * sw) - sxw * (sxy * n - sy * sx) + sx * (sxy * sw - syw * sx)) / det
	local c = (sxx * (syy * sw - sy * syw) - sxy * (sxy * sw - syw * sx) + sxw * (sxy * sy - syy * sx)) / det
	return a, b, c
end

-- One fit per flight map, from every point with both a map coordinate and a
-- place someone stood: this character's and the recorder's (geometry is the
-- same for every character).
function T:Fit(taxiMap)
	if not taxiMap then return nil end
	self.fits = self.fits or {}
	local fit = self.fits[taxiMap]
	if fit ~= nil then return fit or nil end
	local samples, seen = {}, {}
	local function add(name, tx, ty, m, x, y)
		if seen[name] or not (U.Finite(tx) and U.Finite(ty) and U.ValidMapPoint(m, x, y)) then return end
		local c, wx, wy = API.GetWorldPos(m, x, y)
		if not wx then return end
		seen[name] = true
		samples[#samples + 1] = { tx = tx, ty = ty, c = c, wx = wx, wy = wy }
	end
	for name, rec in pairs(FP.cdb.flights) do if rec.tm == taxiMap then add(name, rec.tx, rec.ty, rec.m, rec.x, rec.y) end end
	for _, rec in pairs(FP.data.taxi.nodes or {}) do
		if rec.m == taxiMap and rec.pos and listed(rec.n) then add(rec.n, rec.x, rec.y, rec.pos.m, rec.pos.x, rec.pos.y) end
	end
	-- A flight map covers one continent: keep the continent most samples are on
	-- (a point in an instanced or separate zone must not spoil the rest).
	local perContinent, continent = {}, nil
	for _, sample in ipairs(samples) do
		local key = tostring(sample.c)
		perContinent[key] = perContinent[key] or { c = sample.c }
		table.insert(perContinent[key], sample)
		if not continent or #perContinent[key] > #perContinent[continent] then continent = key end
	end
	samples = continent and perContinent[continent] or {}
	local result = { n = #samples, ok = false, continent = samples.c }
	local function solve(list)
		local ax, bx, cx = plane(list, "wx")
		local ay, by, cy = plane(list, "wy")
		if not (ax and ay) then return nil end
		local sum = 0
		for _, sample in ipairs(list) do
			local ex, ey = ax * sample.tx + bx * sample.ty + cx - sample.wx, ay * sample.tx + by * sample.ty + cy - sample.wy
			sum = sum + ex * ex + ey * ey
		end
		return math.sqrt(sum / #list), { ax, bx, cx }, { ay, by, cy }
	end
	result.rms, result.x, result.y = solve(samples)
	-- One wrongly recorded place pulls the whole fit, so its own error is not
	-- the largest. Leave each sample out in turn and keep the best remainder.
	if result.rms and result.rms > FIT_MAX_ERROR and #samples >= 6 then
		local bestRms, bestX, bestY, bestI
		for i = 1, #samples do
			local rest = {}
			for j, sample in ipairs(samples) do if j ~= i then rest[#rest + 1] = sample end end
			local rms, x, y = solve(rest)
			if rms and (not bestRms or rms < bestRms) then bestRms, bestX, bestY, bestI = rms, x, y, i end
		end
		if bestRms and bestRms <= FIT_MAX_ERROR then
			table.remove(samples, bestI)
			result.rms, result.x, result.y, result.dropped = bestRms, bestX, bestY, 1
		end
	end
	local solved = result.rms ~= nil
	-- Three samples always fit exactly, so they prove nothing: ask for four.
	result.n = #samples
	result.ok = solved and #samples >= 4 and result.continent ~= nil and result.rms <= FIT_MAX_ERROR or false
	self.fits[taxiMap] = result.ok and result or false
	-- Kept for the next data pull: whether the estimate can be trusted in the client.
	FP.db.travel = FP.db.travel or { fits = {} }
	FP.db.travel.fits[tostring(taxiMap)] = { n = result.n, rms = result.rms and math.floor(result.rms + 0.5) or nil, ok = result.ok,
		dropped = result.dropped, continent = result.continent, t = U.Now(), version = FP.version }
	return result.ok and result or nil
end

-- continent, worldX, worldY, exact for a flight point this character knows.
function T:FlightWorld(rec)
	if U.ValidMapPoint(rec.m, rec.x, rec.y) then
		local c, wx, wy = API.GetWorldPos(rec.m, rec.x, rec.y)
		if wx then return c, wx, wy, true end
	end
	local fit = U.Finite(rec.tx) and U.Finite(rec.ty) and self:Fit(rec.tm)
	if not fit then return nil end
	return fit.continent, fit.x[1] * rec.tx + fit.x[2] * rec.ty + fit.x[3], fit.y[1] * rec.tx + fit.y[2] * rec.ty + fit.y[3], false
end

local function sameArea(a, b)
	a, b = tostring(a or ""):lower(), tostring(b or ""):lower()
	if #a < 4 or #b < 4 then return a ~= "" and a == b end
	return a == b or a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

-- The flight point this character knows nearest a destination, and how far it
-- is from it: "Hammerfall, Arathi", 1900. Falls back to a known point named
-- after the destination's zone when no position can be worked out.
function T:FlightFor(target)
	if not target or not target.mapID then return nil end
	self:Seed()
	local tc, tx, ty = FP.Pos:WorldOf(target)
	local best, bestD, bestInZone, named = nil, nil, false, {}
	local zone = API.GetMapName(target.mapID)
	for name, rec in pairs(FP.cdb.flights) do
		if listed(name) then
			local place, area = name:match("^(.-),%s*(.+)$")
			local inZone = sameArea(area or name, zone) or sameArea(place or name, zone)
			local c, wx, wy = self:FlightWorld(rec)
			if wx and tx then
				if c == tc then
					local d = U.Distance(wx, wy, tx, ty)
					if not bestD or d < bestD or (d == bestD and name < best) then best, bestD, bestInZone = name, d, inZone end
				end
			elseif inZone then
				named[#named + 1] = place or name
			end
		end
	end
	-- A known point in the destination's own zone that cannot be placed still
	-- beats a placed one somewhere else.
	if best and (bestInZone or #named == 0) then return best, bestD end
	if #named == 0 then return nil end
	table.sort(named)
	if #named > 2 then return named[1] .. ", " .. named[2] .. " or " .. (#named - 2) .. " more" end
	return table.concat(named, " or ")
end

-- Whether naming a flight point helps: it must be nearer the destination than
-- the place the trip (or its sea crossing) starts from, by a real margin.
local function worthFlying(flightD, fromD)
	return flightD == nil or fromD == nil or (fromD >= FLIGHT_MIN and flightD < fromD * 0.6)
end

-- Second line for the arrow: what the trip involves beyond following the arrow.
-- nil when there is nothing useful to add.
function T:Hint(target, leg)
	local pos = FP.Pos.cache
	if not target or not pos.valid then return nil end
	local now, memo = API.Time(), self.hintMemo
	if memo and memo.target == target and memo.x == target.x and memo.y == target.y and memo.mapID == target.mapID
		and memo.playerMap == pos.mapID and now - memo.t < 2 then return memo.text end
	leg = leg or self:Leg(target)
	local text
	if leg then
		local flight, d = self:FlightFor(target)
		text = "then " .. API.GetMapName(target.mapID) .. ((flight and worthFlying(d, leg.after)) and (" · fly to " .. flight) or "")
	else
		local d = FP.Pos:DistanceTo(target)
		if d and d >= FLIGHT_MIN and target.mapID ~= pos.mapID then
			local flight, fd = self:FlightFor(target)
			if flight and worthFlying(fd, d) then text = "flight point: " .. flight end
		end
	end
	self.hintMemo = { target = target, x = target.x, y = target.y, mapID = target.mapID, playerMap = pos.mapID, t = now, text = text }
	return text
end

-- Full sentence for tooltips and the Navigation page.
function T:Describe(target)
	local leg = self:Leg(target)
	if not leg then
		local hint = self:Hint(target)
		return hint and ("Far away. Nearest " .. hint .. " (of the ones you know).") or nil
	end
	local text = self:LegTitle(leg) .. ": board at " .. leg.from.place
		.. (leg.crossing.approximate and " (Classic route, approximate dock, not confirmed on Forever)" or "") .. "."
	local flight, d = self:FlightFor(target)
	text = text .. " It lands at " .. leg.to.town .. "; " .. ((flight and worthFlying(d, leg.after)) and ("the nearest flight point you know is " .. flight .. ".")
		or ("continue to " .. API.GetMapName(target.mapID) .. "."))
	local bind = FP.cdb.bind
	if bind and bind.m and bind.x and API.HasHearthstone() then
		local bc = FP.Pos:WorldOf({ mapID = bind.m, x = bind.x, y = bind.y })
		local tc = FP.Pos:WorldOf(target)
		if bc ~= nil and bc == tc then
			local cd = API.GetHearthCooldown()
			text = text .. " Or use your Hearthstone to " .. tostring(bind.area or "your inn")
				.. (cd > 0 and (" (ready in " .. U.FormatTime(cd) .. ")") or " (ready)") .. "."
		end
	end
	return text
end

-------------------------------------------------------------------------------
-- Trip plan: the planner's steps grouped into one stop per zone and put in a
-- visiting order. Nearest zone first on the continent you are on (a ready
-- turn-in pulls its zone forward), then the crossing, then the other continent.
-- Reads the plan the planner already built; never rebuilds or changes it.
-------------------------------------------------------------------------------
function T:Plan()
	local pos = FP.Pos.cache
	local stops, byMap, unknown, deferred = {}, {}, {}, {}
	for _, s in ipairs(FP.Planner.steps or {}) do
		if s.kind ~= "hearth" then
			local key = s.questID or s.title
			if s.deferred then
				deferred[key] = true
			else
				local c, wx, wy
				if U.ValidMapPoint(s.mapID, s.x, s.y) then c, wx, wy = FP.Pos:WorldOf(s) end
				if not wx then
					unknown[key] = true
				else
					local stop = byMap[s.mapID]
					if not stop then
						stop = { mapID = s.mapID, zone = API.GetMapName(s.mapID), continent = c, steps = {}, quests = {},
							turnins = 0, pickups = 0, sx = 0, sy = 0 }
						byMap[s.mapID] = stop
						stops[#stops + 1] = stop
					end
					stop.steps[#stop.steps + 1] = s
					stop.quests[key] = true
					if s.kind == "turnin" then stop.turnins = stop.turnins + 1
					elseif s.kind == "pickup" then stop.pickups = stop.pickups + 1 end
					stop.sx, stop.sy = stop.sx + wx, stop.sy + wy
				end
			end
		end
	end
	for _, stop in ipairs(stops) do
		stop.wx, stop.wy = stop.sx / #stop.steps, stop.sy / #stop.steps
		stop.questCount = U.Count(stop.quests)
	end
	-- A quest with one mapped step and one unmapped step is not "unknown".
	for _, stop in ipairs(stops) do for key in pairs(stop.quests) do unknown[key] = nil end end

	local rows, n = {}, 0
	local function visit(continent, fx, fy)
		while true do
			local best, bestI, bestCost, bestD
			for i, stop in ipairs(stops) do
				if not stop.visited and stop.continent == continent then
					local d = fx and U.Distance(fx, fy, stop.wx, stop.wy) or nil
					local cost = (d or 0) - TURNIN_PULL * math.min(stop.turnins, 3)
					if not best or cost < bestCost or (cost == bestCost and stop.zone < best.zone) then
						best, bestI, bestCost, bestD = stop, i, cost, d
					end
				end
			end
			if not best then return fx, fy end
			best.visited = true
			n = n + 1
			rows[#rows + 1] = { type = "stop", key = "stop:" .. tostring(best.mapID), stop = best, n = n, dist = bestD, first = n == 1 }
			fx, fy = best.wx, best.wy
		end
	end
	local here, fx, fy = nil, nil, nil
	if pos.valid then here, fx, fy = pos.continent, pos.wx, pos.wy end
	if here ~= nil then fx, fy = visit(here, fx, fy) end
	-- Other continents, the one with most quests first.
	local others, seen = {}, {}
	for _, stop in ipairs(stops) do
		if not stop.visited and not seen[stop.continent] then
			seen[stop.continent] = true
			local count = 0
			for _, other in ipairs(stops) do if other.continent == stop.continent then count = count + other.questCount end end
			others[#others + 1] = { continent = stop.continent, count = count }
		end
	end
	table.sort(others, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return tostring(a.continent) < tostring(b.continent)
	end)
	for _, other in ipairs(others) do
		local leg
		if here ~= nil and fx then
			for _, stop in ipairs(stops) do
				if stop.continent == other.continent then
					local candidate = self:Crossing(here, fx, fy, stop.continent, stop.wx, stop.wy)
					if candidate and (not leg or candidate.cost < leg.cost) then leg = candidate end
				end
			end
		end
		if leg then
			rows[#rows + 1] = { type = "crossing", key = "crossing:" .. tostring(other.continent), leg = leg }
			local _, bx, by = FP.Pos:WorldOf(leg.to)
			here, fx, fy = other.continent, bx, by
		else
			if here ~= nil then rows[#rows + 1] = { type = "gap", key = "gap:" .. tostring(other.continent) } end
			here, fx, fy = other.continent, nil, nil
		end
		fx, fy = visit(other.continent, fx, fy)
	end

	local plan = { rows = rows, stops = n, unknown = U.Count(unknown), deferred = U.Count(deferred) }
	-- Hearthstone: say which stop it reaches, when that is not where you already are.
	local bind = FP.cdb.bind
	if bind and bind.m and bind.x and API.HasHearthstone() then
		local _, bx, by = FP.Pos:WorldOf({ mapID = bind.m, x = bind.x, y = bind.y })
		for _, row in ipairs(rows) do
			local stop = row.stop
			if stop and row.n > 1 and (stop.mapID == bind.m or (bx and U.Distance(bx, by, stop.wx, stop.wy) < 600)) then
				local cd = API.GetHearthCooldown()
				plan.hearth = "Hearthstone to " .. tostring(bind.area or "your inn") .. " reaches stop " .. row.n .. " ("
					.. stop.zone .. ")" .. (cd > 0 and (": ready in " .. U.FormatTime(cd)) or ": ready now") .. "."
				break
			end
		end
	end
	return plan
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- Plain text: these labels are truncated in lists, so no colour codes.
function T:RowLabel(row)
	if row.type == "crossing" then
		local leg = row.leg
		return "→ " .. self:LegTitle(leg) .. ", from " .. leg.from.town .. (leg.crossing.approximate and " (approximate)" or "")
	elseif row.type == "gap" then
		return "→ other continent: no crossing known for this character"
	end
	local stop = row.stop
	local bits = { plural(stop.questCount, "quest") }
	if stop.turnins > 0 then bits[#bits + 1] = stop.turnins .. " ready to turn in" end
	if stop.pickups > 0 then bits[#bits + 1] = plural(stop.pickups, "pickup") end
	if row.dist then bits[#bits + 1] = (row.first and "" or "+") .. U.FormatDistance(row.dist) end
	return row.n .. ". " .. stop.zone .. " — " .. table.concat(bits, " · ")
end

-- What is waiting at a stop, turn-ins first.
function T:RowDetails(row)
	if not row then return "Select a stop to see its quests, or guide to it." end
	if row.type == "crossing" then
		local leg = row.leg
		return self:LegTitle(leg) .. ". Board at " .. leg.from.place .. "; it lands at " .. leg.to.town .. "."
			.. (leg.crossing.approximate and "\nClassic route with an approximate dock: not confirmed on Forever." or "")
			.. "\nThe arrow leads to the boarding point when your next step is across the sea."
	elseif row.type == "gap" then
		return "These stops are on another continent and no zeppelin or ship is known for this character."
	end
	local lines, steps = {}, {}
	for _, s in ipairs(row.stop.steps) do steps[#steps + 1] = s end
	table.sort(steps, function(a, b)
		local ta, tb = a.kind == "turnin" and 0 or 1, b.kind == "turnin" and 0 or 1
		if ta ~= tb then return ta < tb end
		if a.score ~= b.score then return (a.score or 0) < (b.score or 0) end
		return tostring(a.title) < tostring(b.title)
	end)
	for i, s in ipairs(steps) do
		if i > 6 then lines[#lines + 1] = FP.GREY .. "+" .. (#steps - 6) .. " more|r"; break end
		lines[#lines + 1] = (s.kind == "turnin" and (FP.GREEN .. "Turn in:|r " .. tostring(s.text))
			or s.kind == "pickup" and ("Pick up: " .. tostring(s.text))
			or (tostring(s.title) .. FP.GREY .. " — " .. tostring(s.text) .. (s.progress and (" " .. s.progress) or "") .. "|r"))
			.. (s.entrance and FP.GREY .. " (dungeon)|r" or "")
	end
	return table.concat(lines, "\n")
end

-- The step to head for at a stop: a ready turn-in first, then the planner's best.
function T:StepFor(stop)
	local best
	for _, s in ipairs(stop.steps) do
		if not best then best = s
		else
			local a, b = s.kind == "turnin" and 0 or 1, best.kind == "turnin" and 0 or 1
			if a < b or (a == b and (s.score or 0) < (best.score or 0)) then best = s end
		end
	end
	return best
end

-- The player's click: head for this stop. Same path as choosing a quest step.
function T:Guide(row)
	if not row or row.type ~= "stop" then return false end
	local step = self:StepFor(row.stop)
	if not step or not FP.Planner:Go(step) then
		FP:Print("No usable location for " .. row.stop.zone .. " yet.")
		return false
	end
	FP:Print(FP.GOLD .. "Heading to " .. row.stop.zone .. ":|r " .. (step.kind ~= "objective" and step.title or (step.text .. " — " .. step.title)))
	return true
end

function T:Summary(plan)
	plan = plan or self:Plan()
	if plan.stops == 0 then
		return plan.unknown > 0 and (plural(plan.unknown, "quest") .. " without a known location. Check the quest text.")
			or "No quests with a known location."
	end
	local out = { plural(plan.stops, "stop") .. ", nearest first on this continent; a ready turn-in pulls its zone forward. Straight-line estimate, not travel time." }
	if plan.hearth then out[#out + 1] = plan.hearth end
	if plan.unknown > 0 then out[#out + 1] = plural(plan.unknown, "quest") .. " without a known location (not listed)." end
	if plan.deferred > 0 then out[#out + 1] = plural(plan.deferred, "deferred quest") .. " left out." end
	return table.concat(out, "\n")
end

function T:Lines()
	local plan = self:Plan()
	local out = { FP.GOLD .. "Trip plan|r" }
	for _, row in ipairs(plan.rows) do out[#out + 1] = "  " .. self:RowLabel(row) end
	out[#out + 1] = self:Summary(plan)
	return out
end

function T:OnEnable()
	FP:RegisterEvent("TAXIMAP_OPENED", function() FP.pcall("travel-taxi", T.OnTaxiMap, T) end)
end
