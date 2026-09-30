-- ForeverPath / PvP / Battleground.lua
-- Battleground objectives HUD: base states and capture timers from area POIs,
-- flag carriers from C_PvP.GetBattlefieldFlagPosition (both never-secret),
-- described relative to landmarks. Records raw POI/flag observations so the
-- first real battleground teaches us the exact texture/atlas meanings.
-- Player map position is expected to be unavailable inside instances, so the
-- arrow may not point; the optional flag waypoint exists in case it does.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local BG = FP:NewModule("Battleground")

local function has(tbl, fn) return type(tbl) == "table" and type(tbl[fn]) == "function" end
local ticker

BG.active = false
BG.mapID = nil
BG.pois = {}     -- runtime list
BG.flags = {}    -- runtime list

-- poi = our own record { atlas, desc, name }
local function stateFromInfo(poi)
	local hay = (tostring(poi.atlas or "") .. " " .. tostring(poi.desc or "") .. " " .. tostring(poi.name or "")):lower()
	if hay:find("contested") or hay:find("assault") then return "contested" end
	if hay:find("alliance") then return "Alliance" end
	if hay:find("horde") then return "Horde" end
	return nil
end

function BG:Detect()
	local was = self.active
	self.active = FP.PvP:InBattleground()
	self.mapID = self.active and API.GetBestMap() or nil
	if self.active and not was then
		local rec = self:Record()
		rec.matches = (rec.matches or 0) + 1
		self:StartTicker()
		FP:Print(FP.RED .. "Battleground mode|r on: " .. tostring(API.GetZoneText()) .. ". /fp pvp track follows the flag carrier.")
	elseif not self.active and was then
		self:StopTicker()
		FP.Waypoints:RemoveBySource("bg")
	end
	self:Scan()
end

function BG:Record()
	local key = tostring(self.mapID or "unknown")
	local rec = FP.data.bg[key]
	if not rec then rec = { pois = {}, flags = {} }; FP.data.bg[key] = rec end
	rec.name = rec.name or (API.GetZoneText())
	return rec
end

function BG:Scan()
	if not self.active or not self.mapID then self.pois, self.flags = {}, {}; return end
	local rec = self:Record()
	-- objectives
	local pois = {}
	if has(C_AreaPoiInfo, "GetAreaPOIForMap") and has(C_AreaPoiInfo, "GetAreaPOIInfo") then
		local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, self.mapID)
		if ok and type(ids) == "table" then
			for _, id in ipairs(ids) do
				local ok2, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, self.mapID, id)
				if ok2 and type(info) == "table" then
					local x, y
					if info.position and info.position.GetXY then x, y = info.position:GetXY() end
					local secs
					if has(C_AreaPoiInfo, "IsAreaPOITimed") and has(C_AreaPoiInfo, "GetAreaPOISecondsLeft") then
						local okt, timed = pcall(C_AreaPoiInfo.IsAreaPOITimed, id)
						if okt and timed then local oks, s = pcall(C_AreaPoiInfo.GetAreaPOISecondsLeft, id); if oks then secs = FP.safe(s) end end
					end
					local poi = { id = id, name = FP.safe(info.name), desc = FP.safe(info.description), atlas = FP.safe(info.atlasName), tex = FP.safe(info.textureIndex), x = x, y = y, secs = secs }
					poi.state = stateFromInfo(poi)
					pois[#pois + 1] = poi
					-- dataset: remember every distinct (atlas, texture, description) seen per POI
					local r = rec.pois[id] or { n = poi.name, x = x and U.Coord(x), y = y and U.Coord(y), seen = {} }
					rec.pois[id] = r
					local sig = tostring(poi.atlas) .. "|" .. tostring(poi.tex) .. "|" .. tostring(poi.desc)
					r.seen[sig] = (r.seen[sig] or 0) + 1
				end
			end
		end
	end
	table.sort(pois, function(a, b) return tostring(a.name) < tostring(b.name) end)
	self.pois = pois
	-- flags
	local flags = {}
	if type(GetNumBattlefieldFlagPositions) == "function" and has(C_PvP, "GetBattlefieldFlagPosition") then
		local okn, n = pcall(GetNumBattlefieldFlagPositions)
		for i = 1, (okn and n or 0) do
			local ok, x, y, tex = pcall(C_PvP.GetBattlefieldFlagPosition, i, self.mapID)
			x, y, tex = ok and FP.safe(x), ok and FP.safe(y), ok and FP.safe(tex)
			if x and y then
				flags[#flags + 1] = { index = i, x = x, y = y, tex = tex, near = self:Landmark(x, y) }
				rec.flags[tostring(tex)] = (rec.flags[tostring(tex)] or 0) + 1
			end
		end
	end
	self.flags = flags
	self:UpdateFlagWaypoint()
end

-- Nearest named POI, else a quadrant description.
function BG:Landmark(x, y)
	local best, bestD
	for _, p in ipairs(self.pois) do
		if p.x and p.name then
			local d = FP.Pos:MapDistance(self.mapID, x, y, p.x, p.y) or ((p.x - x) ^ 2 + (p.y - y) ^ 2) ^ 0.5 * 1000
			if not bestD or d < bestD then best, bestD = p, d end
		end
	end
	if best and bestD and bestD < 250 then return "near " .. best.name end
	local ns = y < 0.33 and "north" or (y > 0.66 and "south" or "mid")
	local ew = x < 0.33 and " west" or (x > 0.66 and " east" or "")
	return ns .. ew .. string.format(" (%s)", U.FormatCoords(x, y))
end

function BG:UpdateFlagWaypoint()
	if not FP.settings.pvp.trackFlag or not self.active then FP.Waypoints:RemoveBySource("bg"); return end
	local flag = self.flags[1]
	if not flag then FP.Waypoints:RemoveBySource("bg"); return end
	local existing
	for _, wp in ipairs(FP.Waypoints.list) do
		if wp.source and wp.source.type == "bg" then existing = wp end
	end
	if existing then
		existing.mapID, existing.x, existing.y = self.mapID, flag.x, flag.y
		existing.title = "Flag carrier " .. flag.near
	else
		FP.Waypoints:Add(self.mapID, flag.x, flag.y, "Flag carrier " .. flag.near, { source = { type = "bg" }, persistent = true, radius = 10, activate = true })
	end
	FP:Fire("WAYPOINTS_CHANGED")
end

function BG:Lines()
	if not self.active then return {} end
	local lines = {}
	for _, p in ipairs(self.pois) do
		local state = p.state or (p.atlas and ("[" .. p.atlas .. "]")) or (p.tex and ("[tex " .. p.tex .. "]")) or "?"
		local color = p.state == "Horde" and "|cffff4040" or (p.state == "Alliance" and "|cff4080ff" or (p.state == "contested" and "|cffffd100" or FP.GREY))
		local timer = p.secs and p.secs > 0 and (" " .. U.FormatTime(p.secs)) or ""
		lines[#lines + 1] = { text = string.format("%s: %s%s|r%s", tostring(p.name), color, state, timer) }
	end
	for _, f in ipairs(self.flags) do
		lines[#lines + 1] = { text = "flag " .. f.near, icon = f.tex }
	end
	local ms = FP.PvP:MatchState()
	if ms then lines[#lines + 1] = { text = FP.GREY .. "match state " .. tostring(ms) .. (FP.settings.pvp.trackFlag and " · tracking flag" or "") .. "|r" } end
	return lines
end

function BG:StartTicker()
	if ticker or not (C_Timer and C_Timer.NewTicker) then return end
	ticker = C_Timer.NewTicker(1, function()
		local ok, err = pcall(BG.Scan, BG)
		if not ok then FP:ReportError("bg-scan", err) end
	end)
end

function BG:StopTicker()
	if ticker then ticker:Cancel(); ticker = nil end
end

function BG:Summary()
	return self.active and string.format("active on %s: %d objectives, %d flags", tostring(API.GetZoneText()), #self.pois, #self.flags) or ("not in a battleground · " .. U.Count(FP.data.bg) .. " map(s) recorded")
end

function BG:OnEnable()
	FP:RegisterEvent("PLAYER_ENTERING_WORLD", function() FP.After(2, function() BG:Detect() end) end)
	FP:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", function() FP.After(1, function() BG:Detect() end) end)
	FP:RegisterEvent("PVP_MATCH_STATE_CHANGED", function() FP.After(1, function() BG:Detect() end) end)
	FP:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() FP.After(1, function() BG:Detect() end) end)
	FP:RegisterEvent("AREA_POIS_UPDATED", function() if BG.active then FP.Throttle("bg-scan", 0.5, function() BG:Scan(); FP:Fire("PVP_CHANGED") end) end end)
	FP:RegisterEvent("BATTLEGROUND_OBJECTIVES_UPDATE", function() if BG.active then FP.Throttle("bg-scan", 0.5, function() BG:Scan(); FP:Fire("PVP_CHANGED") end) end end)
	FP:On("PVP_CHANGED", function() if BG.active then BG:UpdateFlagWaypoint() end end)
	FP.PvP:RegisterSection("Battleground", 20, function() return BG:Lines() end)
end
