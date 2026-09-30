-- ForeverPath / Nav / Waypoints.lua
-- Waypoint list (per character), active waypoint selection, arrival handling.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local W = FP:NewModule("Waypoints")

function W:OnInit()
	self.list = FP.cdb.waypoints
	-- runtime-only fields must not leak into SavedVariables: strip stale ones
	for _, wp in ipairs(self.list) do
		wp._wx, wp._wy, wp._c, wp._m, wp._x, wp._y = nil, nil, nil, nil, nil, nil
	end
end

function W:OnEnable()
	FP:On("POSITION", function(pos) self:OnPosition(pos) end)
	if #self.list > 0 then FP.Pos:Acquire("waypoints") end
end

function W:Add(mapID, x, y, title, opts)
	if not U.ValidMapPoint(mapID, x, y) then return nil end
	opts = opts or {}
	local wp = {
		id = FP.cdb.nextId, mapID = mapID, x = x, y = y,
		title = title or ("Waypoint " .. FP.cdb.nextId),
		desc = opts.desc, source = opts.source, radius = opts.radius or FP.settings.arriveRadius,
		persistent = opts.persistent and true or false, t = U.Now(),
	}
	FP.cdb.nextId = FP.cdb.nextId + 1
	table.insert(self.list, wp)
	if opts.activate ~= false then FP.cdb.activeId = wp.id end
	FP.Pos:Acquire("waypoints")
	FP:Fire("WAYPOINTS_CHANGED")
	return wp
end

function W:Get(id)
	for i, wp in ipairs(self.list) do
		if wp.id == id then return wp, i end
	end
	return nil
end

function W:Remove(id, silent)
	local wp, i = self:Get(id)
	if not wp then return false end
	table.remove(self.list, i)
	if FP.cdb.activeId == id then FP.cdb.activeId = nil end
	if #self.list == 0 then FP.Pos:Release("waypoints") end
	if not silent then FP:Fire("WAYPOINTS_CHANGED") end
	return true
end

function W:RemoveBySource(kind, questID)
	local removed = 0
	for i = #self.list, 1, -1 do
		local s = self.list[i].source
		if s and s.type == kind and (questID == nil or s.questID == questID) then
			table.remove(self.list, i)
			removed = removed + 1
		end
	end
	if removed > 0 then
		local a = FP.cdb.activeId
		if a and not self:Get(a) then FP.cdb.activeId = nil end
		if #self.list == 0 then FP.Pos:Release("waypoints") end
		FP:Fire("WAYPOINTS_CHANGED")
	end
	return removed
end

function W:Clear()
	FP:Fire("NAV_CANCELLED")
	while #self.list > 0 do table.remove(self.list) end
	FP.cdb.activeId = nil
	FP.Pos:Release("waypoints")
	FP:Fire("WAYPOINTS_CHANGED")
end

function W:SetActive(id)
	if self:Get(id) then
		FP.cdb.activeId = id
		FP:Fire("WAYPOINTS_CHANGED")
		return true
	end
	return false
end

function W:Next()
	if #self.list == 0 then return nil end
	local _, i = self:Get(FP.cdb.activeId or -1)
	i = ((i or 0) % #self.list) + 1
	FP.cdb.activeId = self.list[i].id
	FP:Fire("WAYPOINTS_CHANGED")
	return self.list[i]
end

-- Active waypoint: the explicitly chosen one, else (nearestFirst) the nearest
-- reachable one, else the first.
function W:GetActive()
	if #self.list == 0 then return nil end
	local wp = self:Get(FP.cdb.activeId or -1)
	if wp then return wp end
	if FP.settings.nearestFirst then
		local best, bestD
		for _, w in ipairs(self.list) do
			local d = FP.Pos:DistanceTo(w)
			if d and (not bestD or d < bestD) then best, bestD = w, d end
		end
		if best then return best end
	end
	return self.list[1]
end

function W:OnPosition(pos)
	local wp = self:GetActive()
	if not wp then return end
	local d = FP.Pos:DistanceTo(wp)
	if d and d <= (wp.radius or FP.settings.arriveRadius) then
		local now = API.Time()
		if not wp._arrivedAt then
			wp._arrivedAt = now
			self:Arrived(wp)
		end
	else
		wp._arrivedAt = nil
	end
end

function W:Arrived(wp)
	FP:Print(FP.GREEN .. "Arrived:|r " .. tostring(wp.title))
	if wp.persistent then return end
	self:Remove(wp.id, true)
	FP:Fire("WAYPOINT_ARRIVED", wp)
	FP:Fire("WAYPOINTS_CHANGED")
end

function W:Describe(wp)
	local d = FP.Pos:DistanceTo(wp)
	return string.format("#%d %s  [%s %s]  %s", wp.id, tostring(wp.title), API.GetMapName(wp.mapID), U.FormatCoords(wp.x, wp.y), d and U.FormatDistance(d) or "")
end
