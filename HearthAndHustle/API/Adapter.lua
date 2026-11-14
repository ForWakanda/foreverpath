-- HearthAndHustle / API / Adapter.lua
-- The ONLY file that talks to the WoW API. Everything is feature-detected so a
-- renamed or removed function on the next build degrades one feature instead
-- of breaking the addon. Verified against Blizzard's Forever UI source
-- (release source 1.60.1.70790, interface 16001; checked 2026-11-04).
local ADDON, FP = ...
local U = FP.Util
local safe = FP.safe
local API = {}
FP.API = API

local function has(tbl, fn)
	return type(tbl) == "table" and type(tbl[fn]) == "function"
end
local function hasg(name)
	return type(_G[name]) == "function"
end
API.has, API.hasg = has, hasg

function API.Now()
	if hasg("GetServerTime") then
		local ok, value = pcall(GetServerTime)
		if ok and type(value) == "number" then return value end
	end
	return hasg("time") and time() or 0
end
function API.Time() return hasg("GetTime") and GetTime() or 0 end
function API.IsAddOnLoaded(name)
	if not has(C_AddOns, "IsAddOnLoaded") then return false end
	local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
	return ok and loaded and true or false
end
function API.AtlasExists(name) return has(C_Texture, "GetAtlasInfo") and C_Texture.GetAtlasInfo(name) ~= nil end
function API.IsShiftDown() return hasg("IsShiftKeyDown") and IsShiftKeyDown() or false end

do
	if has(C_AddOns, "GetAddOnMetadata") then
		local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON, "Version")
		if ok and version then FP.version = version end
	end
	if hasg("GetBuildInfo") then
		local ok, version, build, date, toc = pcall(GetBuildInfo)
		if ok then FP.clientVersion, FP.clientBuild, FP.clientDate, FP.clientToc = version, build, date, toc end
	end
end

-------------------------------------------------------------------------------
-- Player / character
-------------------------------------------------------------------------------
function API.GetCharInfo()
	local name = safe(UnitName("player")) or "?"
	local realm = (hasg("GetRealmName") and GetRealmName()) or "?"
	local _, classFile = UnitClass("player")
	local _, raceFile = UnitRace("player")
	local faction = hasg("UnitFactionGroup") and UnitFactionGroup("player") or nil
	return {
		name = name, realm = realm, key = name .. "-" .. realm,
		class = safe(classFile), race = safe(raceFile), faction = safe(faction),
		level = safe(UnitLevel("player")),
	}
end

function API.GetXP()
	local xp = safe(UnitXP("player"))
	local max = safe(UnitXPMax("player"))
	local level = safe(UnitLevel("player"))
	local rested = hasg("GetXPExhaustion") and safe(GetXPExhaustion()) or nil
	return xp, max, level, rested
end

function API.IsDead()
	return hasg("UnitIsDeadOrGhost") and safe(UnitIsDeadOrGhost("player")) or false
end

function API.InInstance()
	if not hasg("IsInInstance") then return false end
	local inInstance, kind = IsInInstance()
	return inInstance, kind
end

function API.InCombat()
	return hasg("InCombatLockdown") and InCombatLockdown() or false
end

function API.GetZoneText()
	local zone = hasg("GetRealZoneText") and GetRealZoneText() or (hasg("GetZoneText") and GetZoneText()) or nil
	local sub = hasg("GetSubZoneText") and GetSubZoneText() or nil
	return safe(zone), safe(sub)
end

-------------------------------------------------------------------------------
-- Units (all secret-guarded)
-------------------------------------------------------------------------------
function API.UnitInfo(unit)
	-- every return here can be a secret in restricted combat; a secret boolean
	-- throws even in an `if`, so each value passes through safe() first.
	if not safe(UnitExists(unit)) then return nil end
	local guid = safe(UnitGUID(unit))
	if type(guid) ~= "string" then return nil end
	local kind, id = U.ParseGUID(guid)
	local info = {
		guid = guid, kind = kind, id = id,
		name = safe(UnitName(unit)),
		level = safe(UnitLevel(unit)),
		isPlayer = safe(UnitIsPlayer(unit)) and true or false,
		dead = (hasg("UnitIsDead") and safe(UnitIsDead(unit))) and true or false,
	}
	if hasg("UnitClassification") then info.classification = safe(UnitClassification(unit)) end
	if hasg("UnitCreatureType") then info.creatureType = safe(UnitCreatureType(unit)) end
	if hasg("UnitReaction") then info.reaction = safe(UnitReaction("player", unit)) end
	return info
end

-- Identity is captured at cast-send time; a later selected target may differ.
function API.CastTargetIsPlayer(target)
	if type(target) ~= "string" or target == "" or not hasg("UnitName") or not hasg("UnitIsPlayer") then return nil end
	for _, unit in ipairs({ "target", "focus", "mouseover" }) do
		local ok, name, realm = pcall(UnitName, unit)
		name, realm = safe(name), safe(realm)
		if ok and type(name) == "string" then
			local full = realm and realm ~= "" and (name .. "-" .. realm:gsub("%s+", "")) or nil
			if target == name or target == full then
				local good, player = pcall(UnitIsPlayer, unit)
				if good then return safe(player) end
			end
		end
	end
	return nil
end

function API.InBattleground()
	if not has(C_PvP, "IsBattleground") then return false end
	local ok, value = pcall(C_PvP.IsBattleground)
	return ok and safe(value) or false
end

function API.MatchState()
	if not has(C_PvP, "GetActiveMatchState") then return nil end
	local ok, value = pcall(C_PvP.GetActiveMatchState)
	return ok and safe(value) or nil
end

function API.IsChatLocked()
	if not has(C_ChatInfo, "InChatMessagingLockdown") then return false end
	local ok, value = pcall(C_ChatInfo.InChatMessagingLockdown)
	return not ok or safe(value) ~= false
end

function API.GetSpellDescription(spellID)
	if not has(C_Spell, "GetSpellDescription") then return nil end
	local ok, value = pcall(C_Spell.GetSpellDescription, spellID)
	return ok and safe(value) or nil
end

function API.GetSpellTexture(spellID)
	if not has(C_Spell, "GetSpellTexture") then return nil end
	local ok, value = pcall(C_Spell.GetSpellTexture, spellID)
	return ok and safe(value) or nil
end

-- Only readable map data is returned. Unknown/secret coordinates stay absent.
function API.GetBattlegroundObjectives(mapID)
	local out = {}
	if not has(C_AreaPoiInfo, "GetAreaPOIForMap") or not has(C_AreaPoiInfo, "GetAreaPOIInfo") then return out end
	local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
	if not ok or type(ids) ~= "table" then return out end
	for _, id in ipairs(ids) do
		local good, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, id)
		if good and type(info) == "table" then
			local x, y
			if info.position and info.position.GetXY then x, y = info.position:GetXY(); x, y = safe(x), safe(y) end
			local secs
			if has(C_AreaPoiInfo, "IsAreaPOITimed") and has(C_AreaPoiInfo, "GetAreaPOISecondsLeft") then
				local okt, timed = pcall(C_AreaPoiInfo.IsAreaPOITimed, id)
				if okt and safe(timed) then
					local oks, value = pcall(C_AreaPoiInfo.GetAreaPOISecondsLeft, id)
					secs = oks and safe(value) or nil
				end
			end
			out[#out + 1] = { id = id, name = safe(info.name), desc = safe(info.description), atlas = safe(info.atlasName), tex = safe(info.textureIndex), x = x, y = y, secs = secs }
		end
	end
	return out
end

function API.GetBattlegroundFlags(mapID)
	local out = {}
	if not hasg("GetNumBattlefieldFlagPositions") or not has(C_PvP, "GetBattlefieldFlagPosition") then return out end
	local okn, n = pcall(GetNumBattlefieldFlagPositions)
	n = okn and safe(n) or nil
	if not U.Finite(n) then return out end
	for i = 1, math.min(10, n) do
		local ok, x, y, tex = pcall(C_PvP.GetBattlefieldFlagPosition, i, mapID)
		x, y, tex = safe(x), safe(y), safe(tex)
		if ok and U.ValidMapPoint(mapID, x, y) then out[#out + 1] = { index = i, x = x, y = y, tex = tex } end
	end
	return out
end

-------------------------------------------------------------------------------
-- Map & position
-------------------------------------------------------------------------------
function API.GetBestMap()
	if not has(C_Map, "GetBestMapForUnit") then return nil end
	return C_Map.GetBestMapForUnit("player")
end

function API.GetPlayerMapPosition(mapID)
	if not mapID or not has(C_Map, "GetPlayerMapPosition") then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or not y or (x == 0 and y == 0) then return nil end
	return x, y
end

function API.GetFacing()
	if not hasg("GetPlayerFacing") then return nil end
	local f = GetPlayerFacing()
	if type(f) ~= "number" then return nil end
	return f
end

-- Returns continentID, worldX (north), worldY (west)
function API.GetWorldPos(mapID, x, y)
	if not (mapID and x and y and has(C_Map, "GetWorldPosFromMapPos") and hasg("CreateVector2D")) then return nil end
	local continent, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
	if not continent or not pos then return nil end
	local wx, wy = pos:GetXY()
	return continent, wx, wy
end

function API.GetMapPosFromWorld(continent, wx, wy, mapID)
	if not has(C_Map, "GetMapPosFromWorldPos") then return nil end
	local id, pos = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(wx, wy), mapID)
	if not pos then return nil end
	local x, y = pos:GetXY()
	return id, x, y
end

local mapInfoCache = {}
function API.GetMapInfo(mapID)
	if not mapID then return nil end
	local c = mapInfoCache[mapID]
	if c then return c end
	if not has(C_Map, "GetMapInfo") then return nil end
	local info = C_Map.GetMapInfo(mapID)
	if info then mapInfoCache[mapID] = info end
	return info
end

function API.GetMapName(mapID)
	local info = API.GetMapInfo(mapID)
	return info and info.name or ("map " .. tostring(mapID))
end

local mapSizeCache = {}
function API.GetMapWorldSize(mapID)
	if not mapID then return nil end
	local c = mapSizeCache[mapID]
	if c then return c.w, c.h end
	if not has(C_Map, "GetMapWorldSize") then return nil end
	local w, h = C_Map.GetMapWorldSize(mapID)
	if w and h and w > 0 then
		mapSizeCache[mapID] = { w = w, h = h }
		return w, h
	end
	return nil
end

function API.CanSetUserWaypoint(mapID)
	return mapID and has(C_Map, "CanSetUserWaypointOnMap") and C_Map.CanSetUserWaypointOnMap(mapID) or false
end

-- Blizzard's own map pin. We never call C_SuperTrack.SetSuperTrackedUserWaypoint
-- (protected for addons on Forever); the pin still shows on the map/minimap.
function API.SetUserWaypoint(mapID, x, y)
	if not API.CanSetUserWaypoint(mapID) then return false end
	if not (UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
	local ok, res = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
	return ok and res or false
end

function API.ClearUserWaypoint()
	if has(C_Map, "ClearUserWaypoint") then pcall(C_Map.ClearUserWaypoint) end
end

function API.GetMinimapViewRadius()
	if has(C_Minimap, "GetViewRadius") then
		local r = C_Minimap.GetViewRadius()
		if type(r) == "number" and r > 0 then return r end
	end
	-- fallback table (outdoor) by zoom level
	local zoom = (Minimap and Minimap.GetZoom and Minimap:GetZoom()) or 0
	local radii = { [0] = 233.3, 200, 166.7, 133.3, 100, 66.7 }
	return radii[zoom] or 233.3
end

function API.IsMinimapRotating()
	if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool("rotateMinimap") end
	if hasg("GetCVarBool") then return GetCVarBool("rotateMinimap") end
	return false
end

-------------------------------------------------------------------------------
-- Quest log
-------------------------------------------------------------------------------
function API.GetQuestLog()
	local out = {}
	if not has(C_QuestLog, "GetNumQuestLogEntries") or not has(C_QuestLog, "GetInfo") then return out end
	local n = C_QuestLog.GetNumQuestLogEntries() or 0
	local header
	for i = 1, n do
		local info = C_QuestLog.GetInfo(i)
		if info then
			if info.isHeader then
				header = info.title
			elseif info.questID and not info.isHidden then
				info.header = header
				info.isComplete = API.IsQuestComplete(info.questID)
				out[#out + 1] = info
			end
		end
	end
	return out
end

function API.IsQuestComplete(questID)
	if has(C_QuestLog, "ReadyForTurnIn") then
		local ok, r = pcall(C_QuestLog.ReadyForTurnIn, questID)
		if ok and r ~= nil then return r and true or false end
	end
	if has(C_QuestLog, "IsComplete") then return C_QuestLog.IsComplete(questID) and true or false end
	return false
end

function API.IsOnQuest(questID)
	-- Live 70790 error: C_QuestLog.IsOnQuest(nil) throws (Usage) -> guard the argument.
	if not U.Finite(questID) or not has(C_QuestLog, "IsOnQuest") then return false end
	local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
	return ok and safe(on) == true or false
end

-- Checklist reads must distinguish false from an unavailable / secret result.
-- Verified signatures in Forever's 70790 QuestLogDocumentation.lua.
function API.GetDungeonQuestState(questID)
	local function flag(name)
		if not has(C_QuestLog, name) then return nil end
		local ok, value = pcall(C_QuestLog[name], questID)
		if not ok then return nil end
		value = safe(value)
		if type(value) == "boolean" then return value end
		return nil
	end
	return { onQuest = flag("IsOnQuest"), completed = flag("IsQuestFlaggedCompleted"), ready = flag("IsComplete") }
end

function API.GetQuestObjectives(questID)
	if not has(C_QuestLog, "GetQuestObjectives") then return {} end
	local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
	if ok and type(objs) == "table" then return objs end
	return {}
end

-- QuestieDB is a separately installed data provider; no Questie UI is required.
-- Use only its public reads. Never load Classic coordinates as Forever data.
local referenceZones
function API.QuestDatabaseStatus()
	local db = LibQuestieDB
	if type(db) ~= "table" then return false, "Quest locations: install/enable QuestieDB (Forever), then restart WoW." end
	if type(db.RequireContract) ~= "function" then return false, "Quest locations: update QuestieDB." end
	local ok, supported = pcall(db.RequireContract, 1)
	if not ok or not supported then return false, "Quest locations: incompatible QuestieDB; update it." end
	if not db.flavor or db.flavor.expansion ~= "Forever" then return false, "Quest locations: QuestieDB must use its Forever database." end
	for _, kind in ipairs({"Quest", "Npc", "Object", "Item"}) do
		if not db[kind] or type(db[kind].Get) ~= "function" then return false, "Quest locations: database not ready." end
	end
	local mapsOK,maps=pcall(referenceZones,db)
	if not mapsOK or not maps then return false,"Quest locations: incompatible zone mapping; update QuestieDB." end
	return true, "QuestieDB Forever (" .. tostring(db.readMode or "unknown mode") .. "): known locations, not live spawns."
end

local zoneProvider, zoneMap, zoneRaw
referenceZones=function(db)
	local support = db.Support and db.Support.Get and db.Support.Get("ZoneDB")
	local raw = support and support.private and support.private.areaIdToUiMapId
	if type(raw) ~= "string" then return nil end
	if zoneProvider==db and zoneRaw==raw and zoneMap then return zoneMap end
	-- Public support payload is a Lua table expression; an empty environment
	-- prevents it accessing client globals. Do not use legacy instance overrides.
	local chunk = loadstring(raw, "QuestieDB zone mapping")
	if not chunk then return nil end
	setfenv(chunk, {})
	local ok, maps = pcall(chunk)
	if not ok or type(maps) ~= "table" then return nil end
	local valid=false
	for area,map in pairs(maps) do if U.Finite(area) and U.Finite(map) and map>0 and map==math.floor(map) then valid=true;break end end
	if not valid then return nil end
	zoneProvider, zoneMap, zoneRaw = db, maps, raw
	return maps
end


-- Provider dungeon AreaIDs (including synthetic aliases) describe instance
-- membership, not native floor maps. Only authored outdoor entrance triples
-- may turn their {-1,-1} markers into navigable points.
local function referenceDungeon(db, area)
	local support = db.Support and db.Support.Get and db.Support.Get("ZoneDB")
	local entries = support and support.private and support.private.dungeons
	if type(entries) ~= "table" then return nil end
	if type(entries[area]) == "table" then return entries[area], area end
	local count=0
	for id,entry in pairs(entries) do
		count=count+1; if count>512 then break end
		if type(entry)=="table" and type(entry[2])=="table" then
			for i,alias in ipairs(entry[2]) do
				if i>64 then break end
				if alias==area then return entry,id end
			end
		end
	end
end

local function referenceEntrances(db, maps, area)
	local entry,id=referenceDungeon(db,area)
	local out={}
	if not entry or type(entry[1])~="string" or type(entry[4])~="table" then return out end
	for i,tuple in ipairs(entry[4]) do
		if i>16 then break end
		if type(tuple)=="table" then
			local mapID,x,y=maps[tuple[1]],tuple[2],tuple[3]
			local info=mapID and API.GetMapInfo(mapID)
			if info and info.mapType==3 and U.Finite(x) and U.Finite(y) and U.ValidMapPoint(mapID,x/100,y/100) then
				out[#out+1]={mapID=mapID,x=x/100,y=y/100,name=entry[1],dungeonName=entry[1],
					areaID=id,entrance=true,entranceIndex=i,role="entrance"}
			end
		end
	end
	return out
end

function API.GetDungeonEntrances(area)
	if not U.Finite(area) or area<=0 or not API.QuestDatabaseStatus() then return {} end
	local ok,out=pcall(function() return referenceEntrances(LibQuestieDB,referenceZones(LibQuestieDB) or {},area) end)
	return ok and out or {}
end

local function referencePoints(db,maps,spawns,name,id,role)
	local out={}
	if type(spawns)~="table" then return out end
	local count=0
	for area,coords in pairs(spawns) do
		count=count+1; if count>512 then break end
		local dungeon=referenceDungeon(db,area)
		local mapID=maps[area]
		local info=not dungeon and mapID and API.GetMapInfo(mapID)
		if type(coords)=="table" then
			local routed=false
			for i,xy in ipairs(coords) do
				if i>4096 or #out>=4096 then break end
				local x,y=type(xy)=="table" and xy[1],type(xy)=="table" and xy[2]
				if dungeon and x==-1 and y==-1 and not routed then
					routed=true
					for _,p in ipairs(referenceEntrances(db,maps,area)) do
						if #out>=4096 then break end
						p.name,p.entityID=name,id; out[#out+1]=p
					end
				elseif info and (info.mapType==3 or info.mapType==2) and U.Finite(x) and U.Finite(y) and U.ValidMapPoint(mapID,x/100,y/100) then
					out[#out+1]={mapID=mapID,x=x/100,y=y/100,name=name,entityID=id,role=role}
				end
			end
		end
	end
	return out
end

local function buildQuestReference(questID, entityKind, entityID)
	if not API.QuestDatabaseStatus() then return nil end
	local ok, result = pcall(function()
		local db, groups = LibQuestieDB, {}
		local maps = referenceZones(db)
		if not maps then return nil end
		local function get(kind, id, field) return db[kind].Get(id, field) end
		local function questField(field) if questID then return get("Quest", questID, field) end end
		local objectives = questField("objectives")
		if entityKind then objectives = { [({Npc=1,Object=2,Item=3})[entityKind]] = {{entityID}} } end
		if objectives==nil then objectives={} end
		if type(objectives) ~= "table" then return nil end
		local function validID(id) return U.Finite(id) and id>0 and id==math.floor(id) end
		local function coordinates(group, spawns, name, id, role)
			for _,p in ipairs(referencePoints(db,maps,spawns,name,id,role)) do
				if #group.points>=4096 then break end
				group.points[#group.points+1]=p
			end
		end
		local function source(group,kind,id,role)
			if not validID(id) then return end
			local name=get(kind,id,"name")
			if type(name)=="string" then coordinates(group,get(kind,id,"spawns"),name,id,role) end
		end
		local function itemSources(group,id,visited,depth)
			if not validID(id) or visited[id] or depth>3 then return end
			visited[id]=true
			for _,spec in ipairs({{"npcDrops","Npc","drop"},{"objectDrops","Object","object"},{"vendors","Npc","vendor"}}) do
				local ids=get("Item",id,spec[1])
				if type(ids)=="table" then for i,entityID in ipairs(ids) do
					if i>256 then break end;source(group,spec[2],entityID,spec[3])
				end end
			end
			local containers=get("Item",id,"itemDrops")
			if type(containers)=="table" then for i,container in ipairs(containers) do
				if i>256 then break end;itemSources(group,container,visited,depth+1)
			end end
		end
		local function append(group)
			table.sort(group.points,function(a,b)
				if a.mapID~=b.mapID then return a.mapID<b.mapID end
				if a.x~=b.x then return a.x<b.x end
				if a.y~=b.y then return a.y<b.y end
				if a.entityID~=b.entityID then return a.entityID<b.entityID end
				return a.role<b.role
			end)
			groups[#groups+1]=group
		end
		for index,kind in ipairs({"Npc","Object","Item"}) do
			if type(objectives[index])=="table" then for i,row in ipairs(objectives[index]) do
				if i>64 then break end
				if type(row)=="table" and validID(row[1]) then
					local name=get(kind,row[1],"name")
					if type(name)=="string" then
						local group={kind=kind,id=row[1],key=kind..":"..i..":"..row[1],name=name,text=type(row[2])=="string" and row[2] or nil,points={}}
						if kind=="Item" then itemSources(group,row[1],{},0)
						else source(group,kind,row[1],kind=="Npc" and "kill" or "object") end
						append(group)
					end
				end
			end end
		end
		-- Multiple creatures can grant one shared quest credit. Root IDs are
		-- labels, sometimes invisible credit dummies, not additional spawn lists.
		if type(objectives[5])=="table" then for i,row in ipairs(objectives[5]) do
			if i>64 then break end
			if type(row)=="table" and type(row[1])=="table" and validID(row[2]) then
				local name=get("Npc",row[2],"name")
				if type(name)~="string" then name=nil end
				local text=type(row[3])=="string" and row[3]~="" and row[3] or nil
				local group={kind="Credit",id=row[2],key="Credit:"..i..":"..row[2],name=text or name or "Quest-credit targets",text=text,points={}}
				for j,id in ipairs(row[1]) do if j>256 then break end;source(group,"Npc",id,"credit") end
				append(group)
			end
		end end
		-- triggerEnd is a completion area, not an escort starting point or path.
		local trigger=questField("triggerEnd")
		if type(trigger)=="table" and type(trigger[1])=="string" and trigger[1]~="" then
			local group={kind="Event",id=questID,key="Event",name=trigger[1],text=trigger[1],points={}}
			coordinates(group,trigger[2],trigger[1],questID,"event")
			append(group)
		end
		-- Only unbound extra notes (index 0) can be shown without assuming the
		-- provider's ordering matches the client's objective ordering. They are
		-- quest-level hints, never completed-objective counts or auto-route inputs.
		local extras=questField("extraObjectives")
		if type(extras)=="table" then for i,row in ipairs(extras) do
			if i>64 then break end
			if type(row)=="table" and row[4]==0 and type(row[3])=="string" and row[3]~="" then
				local group={kind="Hint",id=questID,key="Hint:"..i,name=row[3],text=row[3],points={}}
				if row[5]==nil then coordinates(group,row[1],row[3],questID,"hint")
				elseif type(row[5])=="table" then
					-- Provider references supersede custom coordinates when present.
					for j,ref in ipairs(row[5]) do
						if j>256 then break end
						if type(ref)=="table" then
							if ref[1]=="monster" then source(group,"Npc",ref[2],"hint")
							elseif ref[1]=="object" then source(group,"Object",ref[2],"hint")
							elseif ref[1]=="item" then itemSources(group,ref[2],{},0) end
						end
					end
				end
				append(group)
			end
		end end
		return groups
	end)
	if ok then return result end
	-- Missing/broken providers degrade this feature, not the route or other tools.
	return nil
end

function API.GetQuestReference(questID)
	if not U.Finite(questID) or questID<=0 or questID~=math.floor(questID) then return nil end
	return buildQuestReference(questID)
end

-- Missing/new quest IDs can still have known item/creature sources. Only use a
-- unique exact localized entity name; never fuzzy-match or choose one duplicate.
-- Warm the provider's shared index incrementally, outside combat, on demand.
local objectiveIndexes, objectiveProvider = {}, nil
function API.GetObjectiveNameReference(objective)
	local kind = ({item="Item",monster="Npc",object="Object"})[objective.type]
	local name = U.ObjectiveText(objective.text)
	if not kind or not name or API.InCombat() or not API.QuestDatabaseStatus() then return nil end
	if kind=="Npc" then name=name:gsub(" slain$", ""):gsub(" killed$", ""):gsub(" defeated$", "") end
	local provider = LibQuestieDB
	if objectiveProvider ~= provider then objectiveProvider,objectiveIndexes=provider,{} end
	local entity = provider[kind]
	if not has(entity,"IdsByName") or not has(entity,"BuildNameIndexAsync") then return nil end
	local state = objectiveIndexes[kind]
	if not state then
		state={}; objectiveIndexes[kind]=state
		local co=coroutine.create(function() entity.BuildNameIndexAsync(150) end)
		local function batch()
			if objectiveProvider~=provider then return end
			if API.InCombat() then FP.After(.5,batch); return end
			local ok=coroutine.resume(co)
			if not ok then state.failed=true; return end
			if coroutine.status(co)=="dead" then
				state.ready=true; FP:Fire("QUEST_SOURCE_INDEX_READY")
			else FP.After(.01,batch) end
		end
		FP.After(.01,batch)
	end
	if not state.ready then return nil end
	local ok,ids=pcall(entity.IdsByName,name)
	if not ok or type(ids)~="table" or #ids~=1 or not U.Finite(ids[1]) or ids[1]<=0 or ids[1]~=math.floor(ids[1]) then return nil end
	local refs=buildQuestReference(nil,kind,ids[1])
	local ref=refs and refs[1]
	if ref then ref.fallback=true; ref.key="Name:"..kind..":"..ids[1] end
	return ref
end

-- Quest chain reads are separate from objective/source decoding: opening the
-- browser never loads every quest's spawn list.
function API.GetQuestChainIDs()
	if not API.QuestDatabaseStatus() then return nil end
	local db = LibQuestieDB.Quest
	if type(db.GetAllIds) ~= "function" then return nil end
	local ok, ids = pcall(db.GetAllIds)
	if not ok or type(ids) ~= "table" then return nil end
	local out = {}
	for _, id in ipairs(ids) do
		if U.Finite(id) and id > 0 and id == math.floor(id) then out[#out+1] = id end
	end
	return out -- owned copy; the provider's ID table is shared
end

function API.GetQuestChainRecord(id)
	if not U.Finite(id) or id <= 0 or id ~= math.floor(id) or not API.QuestDatabaseStatus() then return nil end
	local ok, q = pcall(function()
		local get, out = LibQuestieDB.Quest.Get, {id=id}
		out.name = get(id, "name")
		if type(out.name) ~= "string" or out.name == "" then return nil end
		for _, key in ipairs({"requiredLevel","questLevel","requiredMaxLevel","requiredRaces","requiredClasses",
			"parentQuest","availableStartingWith","availableUntilCompleted","disabledByQuest","nextQuestInChain",
			"breadcrumbForQuestId","requiredSpell","requiredSpecialization","specialFlags"}) do
			local value = get(id,key)
			if U.Finite(value) then out[key] = value elseif value ~= nil then out.incomplete = true end
		end
		for _, key in ipairs({"parentQuest","availableStartingWith","availableUntilCompleted","disabledByQuest","nextQuestInChain","breadcrumbForQuestId"}) do
			local value=out[key]
			if value and (value<0 or value~=math.floor(value)) then out.incomplete=true;out[key]=nil end
		end
		for _, key in ipairs({"preQuestGroup","preQuestSingle","childQuests","inGroupWith","exclusiveTo","breadcrumbs"}) do
			local value, ids = get(id,key), {}
			if value ~= nil and type(value) ~= "table" then out.incomplete = true end
			for _, link in ipairs(type(value) == "table" and value or {}) do
				if U.Finite(link) and link ~= 0 and link == math.floor(link) then ids[#ids+1] = link
				else out.incomplete = true end
			end
			out[key] = ids
		end
		for _, key in ipairs({"requiredSkill","requiredRanks","requiredMinRep","requiredMaxRep"}) do
			out[key] = get(id,key) -- detail labels only; these are not eligibility checks
		end
		return out
	end)
	return ok and q or nil
end

-- Reference contacts are informational, not live offers/turn-in confirmation.
local function questContacts(id,field)
	if not U.Finite(id) or id<=0 or not API.QuestDatabaseStatus() then return {} end
	local ok, result = pcall(function()
		local db, out = LibQuestieDB, {}
		local maps = referenceZones(db) or {}
		local contacts = db.Quest.Get(id,field) or {}
		for i,kind in ipairs({"Npc","Object","Item"}) do
			for n, entityID in ipairs(contacts[i] or {}) do
				if n>256 then break end
				local name = db[kind].Get(entityID,"name")
				if type(name) == "string" then
					local entry = {name=name,kind=kind,id=entityID,points={}}
					if kind ~= "Item" then entry.points=referencePoints(db,maps,db[kind].Get(entityID,"spawns"),name,entityID,field) end
					out[#out+1] = entry
				end
			end
		end
		return out
	end)
	return ok and result or {}
end
function API.GetQuestChainStarters(id) return questContacts(id,"startedBy") end
function API.GetQuestEnders(id) return questContacts(id,"finishedBy") end

function API.GetQuestTitle(questID)
	if has(C_QuestLog, "GetTitleForQuestID") then
		local t = C_QuestLog.GetTitleForQuestID(questID)
		if t then return t end
	end
	return nil
end

function API.GetQuestLogIndex(questID)
	return has(C_QuestLog, "GetLogIndexForQuestID") and C_QuestLog.GetLogIndexForQuestID(questID) or nil
end

function API.GetQuestInfoByID(questID)
	local idx = API.GetQuestLogIndex(questID)
	if idx and has(C_QuestLog, "GetInfo") then return C_QuestLog.GetInfo(idx) end
	return nil
end

function API.GetCompletedQuests()
	if has(C_QuestLog, "GetAllCompletedQuestIDs") then
		local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
		if ok and type(list) == "table" then return list end
	end
	return {}
end

function API.IsQuestFlaggedCompleted(questID)
	return has(C_QuestLog, "IsQuestFlaggedCompleted") and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

function API.GetQuestRewardXP(questID)
	if not hasg("GetQuestLogRewardXP") then return nil end
	if hasg("HaveQuestRewardData") and not HaveQuestRewardData(questID) then
		if has(C_QuestLog, "RequestLoadQuestByID") then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
		return nil
	end
	local ok, xp = pcall(GetQuestLogRewardXP, questID)
	if ok and type(xp) == "number" then return xp end
	return nil
end

function API.GetQuestRewardMoney(questID)
	if not hasg("GetQuestLogRewardMoney") then return nil end
	local ok, m = pcall(GetQuestLogRewardMoney, questID)
	if ok and type(m) == "number" then return m end
	return nil
end

-- Blizzard's own "where next" for a quest (may be nil on Forever data).
function API.GetQuestNextWaypoint(questID)
	if not has(C_QuestLog, "GetNextWaypoint") then return nil end
	local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, questID)
	if ok and U.ValidMapPoint(mapID, x, y) then return mapID, x, y end
	return nil
end

function API.GetQuestNextWaypointForMap(questID, mapID)
	if not mapID then return nil end
	if not has(C_QuestLog, "GetNextWaypointForMap") then return nil end
	local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, questID, mapID)
	if ok and U.ValidMapPoint(mapID, x, y) then return x, y end
	return nil
end

function API.GetSelectedQuest()
	if has(C_SuperTrack, "GetSuperTrackedQuestID") then
		local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
		id = ok and safe(id) or nil
		if U.Finite(id) and id > 0 then return id end
	end
end

-- Quest POIs on a map: { questID, x, y, isQuestStart, inProgress, numObjectives, ... }
function API.GetQuestsOnMap(mapID)
	if not mapID or not has(C_QuestLog, "GetQuestsOnMap") then return {} end
	local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
	if ok and type(list) == "table" then return list end
	return {}
end

function API.GetDistanceSqToQuest(questID)
	if not has(C_QuestLog, "GetDistanceSqToQuest") then return nil end
	local ok, d, onContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
	if ok and type(d) == "number" then return d, onContinent end
	return nil
end

-- Current client offers, not historical giver sightings (which cannot establish
-- prerequisites, class eligibility, or whether a quest is still available).
-- NPC conversations supplement incomplete map listings. These observations are
-- session-only, expire after five minutes, and use the interaction position.
local npcOffers = {}
local function pruneNPCOffers()
	local now, mapID = API.Time(), API.GetBestMap()
	for id, q in pairs(npcOffers) do
		if q.mapID ~= mapID or now - q.observedAt >= 300 or now < q.observedAt
			or API.IsOnQuest(id) or (not q.completedAtObservation and API.IsQuestFlaggedCompleted(id)) then npcOffers[id] = nil end
	end
end

function API.GetQuestOffers(mapID)
	local out, seen = {}, {}
	local counts = { map = 0, npc = 0 }
	if not mapID then return out, counts end
	local function add(q, isLine)
		if type(q) ~= "table" then return end
		local id, x, y = safe(q.questID), safe(q.x), safe(q.y)
		if not U.Finite(id) or id <= 0 or seen[id] or not U.ValidMapPoint(mapID, x, y) then return end
		if safe(q.isHidden) or safe(q.inProgress) or (not isLine and not safe(q.isQuestStart)) then return end
		if API.IsOnQuest(id) or API.IsQuestFlaggedCompleted(id) then return end
		seen[id] = true
		out[#out + 1] = { questID = id, title = safe(q.questName) or API.GetQuestTitle(id) or ("Quest " .. id),
			mapID = mapID, x = x, y = y, level = API.GetQuestDifficultyLevel(id), how = "available on current map" }
	end
	if has(C_QuestLine, "GetAvailableQuestLines") then
		local ok, list = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
		if ok and type(list) == "table" then for _, q in ipairs(list) do add(q, true) end end
	end
	for _, q in ipairs(API.GetQuestsOnMap(mapID)) do add(q, false) end
	counts.map = #out
	pruneNPCOffers()
	for id, q in pairs(npcOffers) do
		if q.mapID == mapID then
			counts.npc = counts.npc + 1
			if not seen[id] then out[#out + 1] = U.Copy(q); seen[id] = true end
		end
	end
	return out, counts
end

local requestedQuestMap, requestedQuestAt
function API.RequestQuestOffers(mapID)
	if not mapID or not has(C_QuestLine, "RequestQuestLinesForMap") then return end
	local now = API.Time()
	if mapID == requestedQuestMap and requestedQuestAt and now - requestedQuestAt < 10 then return end
	requestedQuestMap, requestedQuestAt = mapID, now
	pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
end

function API.GetQuestDifficultyLevel(questID)
	if has(C_QuestLog, "GetQuestDifficultyLevel") then
		local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
		if ok then return safe(level) end
	end
	return nil
end

-------------------------------------------------------------------------------
-- Quest dialog (QUEST_DETAIL / QUEST_PROGRESS / QUEST_COMPLETE)
-------------------------------------------------------------------------------
function API.GetDialogQuestID()
	return hasg("GetQuestID") and GetQuestID() or nil
end

function API.GetOfferDetails()
	local d = {}
	if hasg("GetTitleText") then d.title = safe(GetTitleText()) end
	if hasg("GetObjectiveText") then d.objectives = safe(GetObjectiveText()) end
	if hasg("GetQuestText") then d.text = safe(GetQuestText()) end
	if hasg("GetRewardXP") then d.xp = safe(GetRewardXP()) end
	if hasg("GetRewardMoney") then d.money = safe(GetRewardMoney()) end
	if hasg("GetSuggestedGroupSize") then d.group = safe(GetSuggestedGroupSize()) end
	if hasg("QuestGetAutoAccept") then d.autoAccept = QuestGetAutoAccept() and true or false end
	d.rewards, d.choices = {}, {}
	if hasg("GetNumQuestRewards") and hasg("GetQuestItemInfo") then
		for i = 1, (GetNumQuestRewards() or 0) do
			local name, _, num, quality, _, itemID = GetQuestItemInfo("reward", i)
			local link = hasg("GetQuestItemLink") and GetQuestItemLink("reward", i) or nil
			d.rewards[#d.rewards + 1] = { name = safe(name), num = num, quality = quality, itemID = itemID or API.ItemIDFromLink(link) }
		end
	end
	if hasg("GetNumQuestChoices") and hasg("GetQuestItemInfo") then
		for i = 1, (GetNumQuestChoices() or 0) do
			local name, _, num, quality, _, itemID = GetQuestItemInfo("choice", i)
			local link = hasg("GetQuestItemLink") and GetQuestItemLink("choice", i) or nil
			d.choices[#d.choices + 1] = { name = safe(name), num = num, quality = quality, itemID = itemID or API.ItemIDFromLink(link) }
		end
	end
	return d
end

-- Available / active quests at the current NPC (gossip or greeting panel).
function API.GetNPCQuests()
	local available, active = {}, {}
	if has(C_GossipInfo, "GetAvailableQuests") then
		local ok, list = pcall(C_GossipInfo.GetAvailableQuests)
		if ok and type(list) == "table" then
			for _, q in ipairs(list) do
				available[#available + 1] = { questID = q.questID, title = safe(q.title), level = q.questLevel, trivial = q.isTrivial, repeatable = q.repeatable }
			end
		end
	end
	if has(C_GossipInfo, "GetActiveQuests") then
		local ok, list = pcall(C_GossipInfo.GetActiveQuests)
		if ok and type(list) == "table" then
			for _, q in ipairs(list) do
				active[#active + 1] = { questID = q.questID, title = safe(q.title), level = q.questLevel, complete = q.isComplete }
			end
		end
	end
	if #available == 0 and hasg("GetNumAvailableQuests") and hasg("GetAvailableQuestInfo") then
		for i = 1, (GetNumAvailableQuests() or 0) do
			local isTrivial, frequency, isRepeatable, _, questID = GetAvailableQuestInfo(i)
			local title = hasg("GetAvailableTitle") and GetAvailableTitle(i) or nil
			available[#available + 1] = { questID = questID, title = safe(title), trivial = isTrivial, repeatable = isRepeatable, frequency = frequency }
		end
	end
	if #active == 0 and hasg("GetNumActiveQuests") and hasg("GetActiveQuestID") then
		for i = 1, (GetNumActiveQuests() or 0) do
			local questID = GetActiveQuestID(i)
			local title = hasg("GetActiveTitle") and GetActiveTitle(i) or nil
			active[#active + 1] = { questID = questID, title = safe(title) }
		end
	end
	return available, active
end

function API.ObserveNPCQuestOffers(event, questStartItemID)
	if not FP.enabled or API.InCombat() then return end
	if event == "QUEST_DETAIL" then
		questStartItemID = safe(questStartItemID)
		if U.Finite(questStartItemID) and questStartItemID > 0 then return end
		for _, name in ipairs({"QuestIsFromAdventureMap", "QuestIsFromAreaTrigger"}) do
			if hasg(name) then
				local ok, remote = pcall(_G[name])
				if ok and safe(remote) then return end
			end
		end
	end
	-- Never substitute the selected target: remote/item dialogs may leave an
	-- unrelated creature targeted. Only the actual dialog unit is evidence.
	local npc = API.UnitInfo("npc") or API.UnitInfo("questnpc")
	if not npc or npc.kind ~= "Creature" or npc.isPlayer then return end
	pruneNPCOffers()
	local list
	if event == "QUEST_DETAIL" then
		list = {{ questID = API.GetDialogQuestID(), title = hasg("GetTitleText") and safe(GetTitleText()) }}
	else
		list = API.GetNPCQuests()
		-- A new greeting replaces this giver's previous list, including zero.
		for id, q in pairs(npcOffers) do if q.giverGUID == npc.guid then npcOffers[id] = nil end end
	end
	local mapID = API.GetBestMap()
	local x, y = API.GetPlayerMapPosition(mapID)
	if not U.ValidMapPoint(mapID, x, y) then return end
	for _, q in ipairs(list) do
		local id, title, level = safe(q.questID), safe(q.title), safe(q.level)
		if U.Finite(id) and id > 0 and id == math.floor(id) and not API.IsOnQuest(id) then
			npcOffers[id] = { questID = id, title = type(title) == "string" and title or ("Quest " .. id),
				level = U.Finite(level) and level or nil, mapID = mapID, x = x, y = y,
				giverGUID = npc.guid, observedAt = API.Time(), completedAtObservation = API.IsQuestFlaggedCompleted(id),
				how = "recent NPC offer; near " .. (npc.name or "quest giver") .. " (interaction position)" }
		end
	end
	-- Bound transient state even if a client/provider returns an oversized list.
	local ids = {}; for id in pairs(npcOffers) do ids[#ids + 1] = id end
	table.sort(ids, function(a,b) return npcOffers[a].observedAt > npcOffers[b].observedAt end)
	for i = 101, #ids do npcOffers[ids[i]] = nil end
	FP:Fire("QUEST_OFFERS_CHANGED")
end

for _, event in ipairs({"GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL"}) do
	FP:RegisterEvent(event, API.ObserveNPCQuestOffers)
end
for _, event in ipairs({"QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN"}) do
	FP:RegisterEvent(event, function(_, questID) npcOffers[questID] = nil end)
end
FP:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() npcOffers = {} end)

function API.GetGossipOptions()
	local out = {}
	if not has(C_GossipInfo, "GetOptions") then return out end
	local ok, list = pcall(C_GossipInfo.GetOptions)
	if ok and type(list) == "table" then
		for _, o in ipairs(list) do out[#out + 1] = safe(o.name) end
	end
	return out
end

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------
function API.ItemIDFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

function API.GetItemName(itemID)
	if not itemID then return nil end
	if has(C_Item, "GetItemInfo") then
		local name = C_Item.GetItemInfo(itemID)
		if name then return name end
		if has(C_Item, "RequestLoadItemDataByID") then pcall(C_Item.RequestLoadItemDataByID, itemID) end
		return nil
	end
	if hasg("GetItemInfo") then return (GetItemInfo(itemID)) end
	return nil
end

function API.GetItemCount(itemID, includeBank)
	if not itemID then return 0 end
	if has(C_Item, "GetItemCount") then
		local ok, n = pcall(C_Item.GetItemCount, itemID, includeBank and true or false)
		if ok and type(n) == "number" then return n end
		return 0
	end
	if hasg("GetItemCount") then return GetItemCount(itemID, includeBank) or 0 end
	return 0
end

-- Strict count for crafting advice: unavailable is not zero materials.
function API.GetBagItemCount(itemID)
	local fn = has(C_Item, "GetItemCount") and C_Item.GetItemCount or (hasg("GetItemCount") and GetItemCount)
	if not fn or API.InCombat() then return nil end
	local ok, n = pcall(fn, itemID, false)
	n = safe(n)
	if ok and U.Finite(n) and n >= 0 then return n end
	return nil
end

-- Only general-purpose bags count; herb bags/quivers cannot hold arbitrary loot.
function API.GetFreeBagSlots()
	if API.InCombat() or not has(C_Container, "GetContainerNumFreeSlots") then return nil end
	local total, last = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	if not U.Finite(last) or last < 0 or last > 10 then return nil end
	for bag = 0, last do
		local ok, n, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
		n, family = safe(n), safe(family)
		if not ok or not U.Finite(n) or n < 0 or not U.Finite(family) then return nil end
		if family == 0 then total = total + n end
	end
	return total
end

local HEARTHSTONE = 6948
-- Preparation reads are out-of-combat inventory/spellbook snapshots only.
-- nil means unavailable, never "zero supplies" or "spell not learned".
function API.KnowsSpell(spellID)
	local fn = has(C_SpellBook, "IsSpellKnown") and C_SpellBook.IsSpellKnown or (hasg("IsSpellKnown") and IsSpellKnown)
	if not fn then return nil end
	local ok, known = pcall(fn, spellID)
	if not ok then return nil end
	known = safe(known)
	if type(known) == "boolean" then return known end
	return nil
end

local prepItemRequests = {}
local function requestPrepItem(id)
	if prepItemRequests[id] or not has(C_Item, "RequestLoadItemDataByID") then return end
	prepItemRequests[id] = true
	pcall(C_Item.RequestLoadItemDataByID, id)
end

function API.GetPrepItemName(id)
	if API.InCombat() or not U.Finite(id) or id<=0 then return nil end
	local fn=has(C_Item,"GetItemInfo") and C_Item.GetItemInfo or (hasg("GetItemInfo") and GetItemInfo)
	if not fn then return nil end
	local ok,name=pcall(fn,id)
	name=ok and safe(name) or nil
	if type(name)=="string" then return name end
	requestPrepItem(id) -- one request; a failed item load must not retrigger forever
	return nil
end

function API.GetPrepInventory()
	if API.InCombat() then return nil, "Refresh after combat" end
	if not has(C_Container, "GetContainerNumSlots") or not has(C_Container, "GetContainerItemInfo") then return nil, "Bag counts unavailable" end
	local out = { counts = {}, names = {}, water = 0, food = 0, bandages = 0, waterKnown = true, foodKnown = true, bandagesKnown = true }
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	if not U.Finite(lastBag) or lastBag < 0 or lastBag > 10 then return nil, "Bag layout unavailable" end
	for bag = 0, lastBag do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		slots = safe(slots)
		if not ok or not U.Finite(slots) or slots < 0 or slots > 200 then return nil, "Bag counts unavailable" end
		for slot = 1, slots do
			local good, item = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if not good then return nil, "Bag counts unavailable" end
			if item ~= nil then
				if type(item) ~= "table" then return nil, "Bag counts unavailable" end
				local id, count = safe(item.itemID), safe(item.stackCount)
				if not U.Finite(id) or id < 1 or not U.Finite(count) or count < 0 then return nil, "Bag counts unavailable" end
				out.counts[id] = (out.counts[id] or 0) + count
			end
		end
	end
	local itemInfo = has(C_Item, "GetItemInfo") and C_Item.GetItemInfo or (hasg("GetItemInfo") and GetItemInfo)
	local itemSpell = has(C_Item, "GetItemSpell") and C_Item.GetItemSpell or (hasg("GetItemSpell") and GetItemSpell)
	local drinkName,foodName
	if itemSpell then
		local ok, name = pcall(itemSpell, 159) -- Refreshing Spring Water: localized Drink effect
		drinkName = ok and safe(name) or nil
		ok,name=pcall(itemSpell,4540) -- Tough Hunk of Bread: localized Food effect
		foodName=ok and safe(name) or nil
	end
	if type(drinkName) ~= "string" then out.waterKnown = false; requestPrepItem(159) end
	if type(foodName) ~= "string" then out.foodKnown = false; requestPrepItem(4540) end
	local level = API.PlayerLevel()
	for id, count in pairs(out.counts) do
		local v = itemInfo and { pcall(itemInfo, id) } or {}
		local name, minLevel, class, subclass = safe(v[2]), safe(v[6]), safe(v[13]), safe(v[14])
		if type(name)=="string" then out.names[id]=name end
		if not v[1] or type(name) ~= "string" or not U.Finite(class) or not U.Finite(subclass) then
			out.waterKnown, out.foodKnown, out.bandagesKnown = false, false, false
			requestPrepItem(id)
		elseif class == 0 and subclass == 7 then -- ItemClass.Consumable / ItemConsumableSubclass.Bandage
			out.bandages = out.bandages + count -- carried stock, not a First Aid/cooldown usability claim
		elseif class == 0 and subclass == 5 then -- Fooddrink: food and mana potions must not count as water
			local ok, effect
			if itemSpell then ok, effect = pcall(itemSpell, id); effect = safe(effect) end
			if not ok or type(effect) ~= "string" then out.waterKnown,out.foodKnown = false,false; requestPrepItem(id)
			elseif effect == drinkName then
				if not U.Finite(level) or not U.Finite(minLevel) then out.waterKnown = false
				elseif minLevel <= level then out.water = out.water + count end
			elseif effect == foodName then
				if not U.Finite(level) or not U.Finite(minLevel) then out.foodKnown=false
				elseif minLevel<=level then out.food=out.food+count end
			end
		end
	end
	return out
end

function API.GetHearthCooldown()
	local start, duration
	if has(C_Container, "GetItemCooldown") then
		local ok, s, d = pcall(C_Container.GetItemCooldown, HEARTHSTONE)
		if ok then start, duration = safe(s), safe(d) end
	elseif has(C_Item, "GetItemCooldown") then
		local ok, s, d = pcall(C_Item.GetItemCooldown, HEARTHSTONE)
		if ok then start, duration = safe(s), safe(d) end
	elseif has(C_Spell, "GetItemCooldown") then
		-- Added in build 70170: returns a SpellCooldownInfo table (startTime,
		-- duration, isEnabled, modRate) or nothing when the item is unknown.
		local ok, info = pcall(C_Spell.GetItemCooldown, HEARTHSTONE)
		if ok and type(info) == "table" then start, duration = safe(info.startTime), safe(info.duration) end
	end
	if not start or not duration or duration == 0 then return 0 end
	local remaining = (start + duration) - GetTime()
	if remaining < 0 then remaining = 0 end
	return remaining
end

function API.HasHearthstone()
	return API.GetItemCount(HEARTHSTONE) > 0
end

function API.GetBindLocation()
	return hasg("GetBindLocation") and safe(GetBindLocation()) or nil
end

-------------------------------------------------------------------------------
-- Vendor, inventory and status reads (v0.8.0). Information first. The only
-- actions are player-clicked at an open merchant: sell the gray items, repair.
-- Nothing here runs without a click; nothing runs in combat.
-- Source facts (Forever 70862 Blizzard_APIDocumentationGenerated + FrameXML):
-- C_Item.GetItemInfo 11th return = sellPrice; ContainerItemInfo has quality /
-- hasNoValue / isLocked / hyperlink; GetRepairAllCost -> cost, canRepair;
-- GetInventoryItemDurability(slot) -> cur, max; UnitUsesAmmo("player");
-- GetNetStats -> in, out, latencyHome, latencyWorld; C_UnitAuras.
-- GetPlayerAuraBySpellID; C_Secrets.ShouldAurasBeSecret; C_PaperDollInfo.
-- GetTemporaryEnchantmentInfo(slot) -> { remainingTimeMs, chargesRemaining }.
-------------------------------------------------------------------------------
function API.GetMoney()
	if not hasg("GetMoney") then return nil end
	local ok, m = pcall(GetMoney)
	m = ok and safe(m) or nil
	if U.Finite(m) and m >= 0 then return m end
	return nil
end

-- sellPrice (copper per unit), max stack, name, quality. nil = not cached yet.
function API.GetItemValue(itemOrLink)
	local fn = has(C_Item, "GetItemInfo") and C_Item.GetItemInfo or (hasg("GetItemInfo") and GetItemInfo)
	if not fn or itemOrLink == nil then return nil end
	local v = { pcall(fn, itemOrLink) }
	if not v[1] then return nil end
	local name, quality, stack, price = safe(v[2]), safe(v[4]), safe(v[9]), safe(v[12])
	if type(name) ~= "string" or not U.Finite(price) or price < 0 then return nil end
	return price, (U.Finite(stack) and stack > 0) and stack or 1, name, U.Finite(quality) and quality or nil
end

function API.MerchantOpen()
	local f = _G.MerchantFrame
	return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() and true or false
end

-- Blizzard's own "Sell All Junk" button (Mainline MerchantFrame) when Forever enables it.
function API.BlizzardSellsJunk()
	local b = _G.MerchantSellAllJunkButton
	return type(b) == "table" and type(b.IsShown) == "function" and b:IsShown() and true or false
end

-- Gray (poor-quality) items in the bags that a vendor buys, best value first.
-- nil = unavailable (combat, missing API); unpriced = uncached items, never "no junk".
function API.GetJunk()
	if API.InCombat() then return nil, "Refresh after combat" end
	if not has(C_Container, "GetContainerNumSlots") or not has(C_Container, "GetContainerItemInfo") then return nil, "Bag reads unavailable" end
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	if not U.Finite(lastBag) or lastBag < 0 or lastBag > 10 then return nil, "Bag layout unavailable" end
	local poor = (type(Enum) == "table" and type(Enum.ItemQuality) == "table" and Enum.ItemQuality.Poor) or 0
	local out = { items = {}, total = 0, unpriced = 0 }
	for bag = 0, lastBag do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		slots = safe(slots)
		if not ok or not U.Finite(slots) or slots < 0 or slots > 200 then return nil, "Bag reads unavailable" end
		for slot = 1, slots do
			local good, item = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if not good then return nil, "Bag reads unavailable" end
			if type(item) == "table" then
				local quality, noValue, id, count, link, locked = safe(item.quality), safe(item.hasNoValue), safe(item.itemID), safe(item.stackCount), safe(item.hyperlink), safe(item.isLocked)
				if quality == poor and noValue ~= true and U.Finite(id) and locked ~= true then
					local price, _, name = API.GetItemValue(link or id)
					count = (U.Finite(count) and count > 0) and count or 1
					if price and price > 0 then
						out.items[#out.items + 1] = { bag = bag, slot = slot, itemID = id, name = name, count = count, value = price * count, link = link }
						out.total = out.total + price * count
					elseif not price then
						out.unpriced = out.unpriced + 1
						requestPrepItem(id)
					end
				end
			end
		end
	end
	table.sort(out.items, function(a, b) return a.value > b.value end)
	return out
end

-- Player-clicked only: sell one bag slot to the open merchant.
function API.SellSlot(bag, slot)
	if not API.MerchantOpen() or API.InCombat() or not has(C_Container, "UseContainerItem") then return false end
	return pcall(C_Container.UseContainerItem, bag, slot) and true or false
end

-- cost = copper for a full repair, needed = something is damaged, merchantRepairs = this vendor can.
function API.GetRepairInfo()
	if not hasg("GetRepairAllCost") then return nil end
	local ok, cost, needed = pcall(GetRepairAllCost)
	cost, needed = ok and safe(cost) or nil, ok and safe(needed) or nil
	if not U.Finite(cost) or cost < 0 then return nil end
	local can = false
	if hasg("CanMerchantRepair") and API.MerchantOpen() then
		local good, c = pcall(CanMerchantRepair)
		can = good and safe(c) == true
	end
	return { cost = cost, needed = needed == true, merchantRepairs = can }
end

-- Player-clicked only: repair everything at the open merchant with your own money.
function API.RepairAll()
	if not hasg("RepairAllItems") or not API.MerchantOpen() or API.InCombat() then return false end
	return pcall(RepairAllItems, false) and true or false
end

-- worst = lowest slot fraction, pct = overall fraction, broken = slots at 0. nil = unavailable.
function API.GetDurability()
	if not hasg("GetInventoryItemDurability") then return nil end
	local worst, cur, max, broken, n
	cur, max, broken, n = 0, 0, 0, 0
	for slot = 1, 18 do
		local ok, c, m = pcall(GetInventoryItemDurability, slot)
		c, m = ok and safe(c) or nil, ok and safe(m) or nil
		if U.Finite(c) and U.Finite(m) and m > 0 then
			n, cur, max = n + 1, cur + c, max + m
			local pct = c / m
			if not worst or pct < worst then worst = pct end
			if c == 0 then broken = broken + 1 end
		end
	end
	if n == 0 then return nil end
	return { worst = worst, pct = cur / max, broken = broken, slots = n }
end

-- nil = this character does not use ammo (or the API is missing); count nil = unreadable.
function API.GetAmmo()
	if not hasg("UnitUsesAmmo") then return nil end
	local ok, uses = pcall(UnitUsesAmmo, "player")
	if not ok or safe(uses) ~= true then return nil end
	local slot = INVSLOT_AMMO or 0
	local count, id
	if hasg("GetInventoryItemCount") then local good, c = pcall(GetInventoryItemCount, "player", slot); count = good and safe(c) or nil end
	if hasg("GetInventoryItemID") then local good, i = pcall(GetInventoryItemID, "player", slot); id = good and safe(i) or nil end
	return { count = U.Finite(count) and count or nil, itemID = U.Finite(id) and id or nil, name = U.Finite(id) and API.GetItemName(id) or nil }
end

function API.GetPerformance()
	local fps, home, world
	if hasg("GetFramerate") then local ok, f = pcall(GetFramerate); fps = ok and safe(f) or nil end
	if hasg("GetNetStats") then local ok, _, _, h, w = pcall(GetNetStats); if ok then home, world = safe(h), safe(w) end end
	return { fps = U.Finite(fps) and fps or nil, home = U.Finite(home) and home or nil, world = U.Finite(world) and world or nil }
end

-- Own buffs are readable only while Blizzard's predicate says auras are not
-- secret (out of combat on Forever). true/false, or nil = cannot tell.
function API.HasPlayerAura(spellIDs)
	if API.InCombat() or not has(C_UnitAuras, "GetPlayerAuraBySpellID") then return nil end
	if has(C_Secrets, "ShouldAurasBeSecret") then
		local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
		if not ok or secret ~= false then return nil end
	end
	for _, id in ipairs(spellIDs) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if not ok or FP.issecret(aura) then return nil end
		if aura ~= nil then return true end
	end
	return false
end

-- Temporary weapon enchants (Shaman imbues, oils, poisons). nil = unavailable.
function API.GetWeaponImbues()
	if API.InCombat() or not has(C_PaperDollInfo, "GetTemporaryEnchantmentInfo") then return nil end
	local out = {}
	for key, slot in pairs({ main = INVSLOT_MAINHAND or 16, off = INVSLOT_OFFHAND or 17 }) do
		local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
		if not ok or FP.issecret(info) then return nil end
		if type(info) == "table" then
			local ms = safe(info.remainingTimeMs)
			out[key] = { remaining = U.Finite(ms) and ms / 1000 or nil }
		end
		if hasg("GetInventoryItemID") then
			local good, id = pcall(GetInventoryItemID, "player", slot)
			out["has_" .. key] = good and U.Finite(safe(id)) or false
		end
	end
	return out
end

-- Vendor value of the rewards on the open quest dialog (choice and fixed rewards).
function API.GetQuestRewardValues()
	local out = { countsKnown = true }
	if not hasg("GetQuestItemLink") then out.countsKnown = false; return out end
	for _, kind in ipairs({ { "choice", "GetNumQuestChoices" }, { "reward", "GetNumQuestRewards" } }) do
		local n
		if hasg(kind[2]) then local ok, c = pcall(_G[kind[2]]); n = ok and safe(c) or nil end
		if not U.Finite(n) or n < 0 or n > 64 or n ~= math.floor(n) then
			out.countsKnown = false
			n = 0
		end
		for i = 1, n do
			local ok, link = pcall(GetQuestItemLink, kind[1], i)
			link = ok and safe(link) or nil
			local price = type(link) == "string" and API.GetItemValue(link) or nil
			local qty
			if hasg("GetQuestItemInfo") then
				local good, _, _, q = pcall(GetQuestItemInfo, kind[1], i)
				q = good and safe(q) or nil
				if U.Finite(q) and q > 0 and q == math.floor(q) then qty = q end
			end
			local value = U.Finite(price) and price >= 0 and qty and price * qty or nil
			out[#out + 1] = { type = kind[1], kind = kind[1], index = i, link = link, price = price, count = qty,
				value = U.Finite(value) and value or nil }
		end
	end
	return out
end

-- Tooltip plumbing (Mainline TooltipDataProcessor / TooltipUtil, present on Forever).
function API.GetTooltipItem(tooltip)
	if type(TooltipUtil) == "table" and type(TooltipUtil.GetDisplayedItem) == "function" then
		local ok, _, link, id = pcall(TooltipUtil.GetDisplayedItem, tooltip)
		if ok then return safe(link), safe(id) end
	end
	return nil
end

function API.AddTooltipItemHook(fn)
	if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
		and type(Enum) == "table" and type(Enum.TooltipDataType) == "table" and Enum.TooltipDataType.Item ~= nil then
		return pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, fn) and true or false
	end
	return false
end

-------------------------------------------------------------------------------
-- Loot
-------------------------------------------------------------------------------
function API.GetLootSlots()
	local out = {}
	if not hasg("GetNumLootItems") or not hasg("GetLootSlotInfo") then return out end
	for slot = 1, (GetNumLootItems() or 0) do
		local slotType = hasg("GetLootSlotType") and GetLootSlotType(slot) or 1
		local _, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
		local link = hasg("GetLootSlotLink") and GetLootSlotLink(slot) or nil
		local entry = {
			slot = slot, slotType = slotType, name = safe(name), quantity = safe(quantity) or 1,
			quality = safe(quality), isQuestItem = isQuestItem and true or false, questID = safe(questID),
			itemID = API.ItemIDFromLink(link), currencyID = safe(currencyID),
		}
		if hasg("GetLootSourceInfo") then
			local values = { pcall(GetLootSourceInfo, slot) }
			if values[1] then
				entry.sources = {}
				for i = 2, #values, 2 do
					local guid, qty = safe(values[i]), safe(values[i + 1])
					if type(guid) == "string" and U.Finite(qty) and qty > 0 then
						entry.sources[#entry.sources + 1] = { guid = guid, quantity = qty }
					end
				end
			end
		end
		out[#out + 1] = entry
	end
	return out
end

-------------------------------------------------------------------------------
-- Merchant / trainer / taxi
-------------------------------------------------------------------------------
function API.GetMerchantItems()
	local out = {}
	if not hasg("GetMerchantNumItems") then return out end
	local n = GetMerchantNumItems() or 0
	for i = 1, n do
		local name, price, stack, numAvailable, extended
		if has(C_MerchantFrame, "GetItemInfo") then
			local info = C_MerchantFrame.GetItemInfo(i)
			if info then
				name, price, stack, numAvailable, extended = info.name, info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
			end
		elseif hasg("GetMerchantItemInfo") then
			local n1, _, p, s, a, _, _, ext = GetMerchantItemInfo(i)
			name, price, stack, numAvailable, extended = n1, p, s, a, ext
		end
		local link = hasg("GetMerchantItemLink") and GetMerchantItemLink(i) or nil
		local itemID = API.ItemIDFromLink(link)
		if itemID then
			out[#out + 1] = { itemID = itemID, name = safe(name), price = safe(price) or 0, stack = safe(stack) or 1, limited = (safe(numAvailable) or -1), extended = extended and true or false }
		end
	end
	return out
end

function API.GetTrainerServices()
	local out = {}
	if not hasg("GetNumTrainerServices") or not hasg("GetTrainerServiceInfo") then return out end
	local n = GetNumTrainerServices() or 0
	for i = 1, n do
		local name, serviceType, _, reqLevel, subText = GetTrainerServiceInfo(i)
		if name and serviceType ~= "header" then
			local skill, rank, hasReq
			if hasg("GetTrainerServiceSkillReq") then skill, rank, hasReq = GetTrainerServiceSkillReq(i) end
			local cost, isProfession
			if hasg("GetTrainerServiceCost") then cost, isProfession = GetTrainerServiceCost(i) end
			local skillLine = hasg("GetTrainerServiceSkillLine") and GetTrainerServiceSkillLine(i) or nil
			local link = hasg("GetTrainerServiceItemLink") and GetTrainerServiceItemLink(i) or nil
			out[#out + 1] = {
				name = safe(name), type = serviceType, level = safe(reqLevel), sub = safe(subText),
				skill = hasReq and safe(skill) or nil, skillRank = hasReq and safe(rank) or nil,
				cost = safe(cost), profession = isProfession and true or false,
				skillLine = safe(skillLine), itemID = API.ItemIDFromLink(link),
			}
		end
	end
	return out, (hasg("IsTradeskillTrainer") and IsTradeskillTrainer() or false)
end

function API.GetTaxiMapID()
	if hasg("GetTaxiMapID") then
		local id = GetTaxiMapID()
		if id and id > 0 then return id end
	end
	return API.GetBestMap()
end

-- Returns nodes = { {nodeID, name, x, y, state="Current"/"Reachable"/"Unreachable", slot, cost} }
function API.GetTaxiNodes()
	local mapID = API.GetTaxiMapID()
	local out = {}
	if has(C_TaxiMap, "GetAllTaxiNodes") and mapID then
		local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
		if ok and type(list) == "table" then
			local stateNames = { [0] = "Current", [1] = "Reachable", [2] = "Unreachable" }
			for _, n in ipairs(list) do
				local x, y
				if n.position and n.position.GetXY then x, y = n.position:GetXY() end
				local cost
				if n.slotIndex and hasg("TaxiNodeCost") then
					local okc, c = pcall(TaxiNodeCost, n.slotIndex)
					if okc then cost = safe(c) end
				end
				out[#out + 1] = { nodeID = n.nodeID, name = safe(n.name), x = x, y = y, state = stateNames[n.state] or tostring(n.state), slot = n.slotIndex, cost = cost, textureKit = n.textureKit }
			end
		end
	end
	if #out == 0 and hasg("NumTaxiNodes") and hasg("TaxiNodeName") then
		local typeNames = { CURRENT = "Current", REACHABLE = "Reachable", DISTANT = "Unreachable" }
		for i = 1, (NumTaxiNodes() or 0) do
			local x, y = TaxiNodePosition(i)
			local t = hasg("TaxiNodeGetType") and TaxiNodeGetType(i) or nil
			local cost = hasg("TaxiNodeCost") and safe(TaxiNodeCost(i)) or nil
			out[#out + 1] = { nodeID = nil, name = safe(TaxiNodeName(i)), x = x, y = y, state = typeNames[t] or t, slot = i, cost = cost }
		end
	end
	return out, mapID
end

-------------------------------------------------------------------------------
-- Professions & skills
-------------------------------------------------------------------------------
function API.GetProfessions()
	local out = {}
	if hasg("GetProfessions") and hasg("GetProfessionInfo") then
		local ids = { GetProfessions() }
		for _, idx in pairs(ids) do
			if type(idx) == "number" then
				local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
				if name then
					out[#out + 1] = { name = safe(name), rank = safe(rank), maxRank = safe(maxRank), skillLine = safe(skillLine), icon = icon }
				end
			end
		end
	end
	if #out == 0 and has(C_SkillInfo, "GetNumSkillLines") and has(C_SkillInfo, "GetSkillLineInfo") then
		for i = 1, (C_SkillInfo.GetNumSkillLines() or 0) do
			local info = C_SkillInfo.GetSkillLineInfo(i)
			if info and not info.isHeader and info.maxRank and info.maxRank > 0 then
				out[#out + 1] = { name = safe(info.name), rank = safe(info.rank), maxRank = safe(info.maxRank), skillLine = info.skillID, category = info.skillLineCategoryID }
			end
		end
	end
	return out
end

function API.GetOpenTradeSkill()
	-- A linked/guild/NPC recipe view is not evidence of this character's recipes.
	for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
		if has(C_TradeSkillUI, name) then
			local ok, foreign = pcall(C_TradeSkillUI[name])
			if not ok or safe(foreign) then return nil end
		end
	end
	-- Forever has base professions, unlike retail expansion skill lines.
	for _, name in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
		if has(C_TradeSkillUI, name) then
			local ok, info = pcall(C_TradeSkillUI[name])
			if ok and type(info) == "table" and type(info.professionID) == "number" and info.professionID > 0 then return info, name end
		end
	end
	return nil
end

function API.GetTradeSkillRecipeIDs()
	if has(C_TradeSkillUI, "GetAllRecipeIDs") then
		local ok, l = pcall(C_TradeSkillUI.GetAllRecipeIDs)
		if ok and type(l) == "table" and #l > 0 then return l end
	end
	if has(C_TradeSkillUI, "GetFilteredRecipeIDs") then
		local ok, l = pcall(C_TradeSkillUI.GetFilteredRecipeIDs)
		if ok and type(l) == "table" then return l end
	end
	return {}
end

function API.GetRecipeInfo(recipeID)
	if not has(C_TradeSkillUI, "GetRecipeInfo") then return nil end
	local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
	if ok then return info end
	return nil
end

-- Returns { reagents = { [itemID] = qty }, outputItemID, qtyMin, qtyMax }
function API.GetRecipeReagents(recipeID)
	if not has(C_TradeSkillUI, "GetRecipeSchematic") then return nil end
	local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or type(s) ~= "table" or type(s.reagentSlotSchematics) ~= "table" then return nil end
	local out = { reagents = {}, outputItemID = s.outputItemID, qtyMin = s.quantityMin, qtyMax = s.quantityMax }
	for _, slot in ipairs(s.reagentSlotSchematics) do
		if slot.required ~= false then
			-- Unknown/currency/alternative-choice slots need a richer cost model.
			-- Do not silently omit them and report a recipe as affordable.
			if not slot.reagents or #slot.reagents ~= 1 or not slot.reagents[1].itemID
				or not FP.Util.Finite(slot.quantityRequired) or slot.quantityRequired <= 0 then return nil end
			local id = slot.reagents[1].itemID
			out.reagents[id] = (out.reagents[id] or 0) + slot.quantityRequired
		end
	end
	return out
end

-------------------------------------------------------------------------------
-- Spells (name lookup only; no cooldown/aura reads)
-------------------------------------------------------------------------------
function API.GetSpellName(spellID)
	if type(spellID) ~= "number" then return nil end
	if has(C_Spell, "GetSpellName") then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(name) == "string" then return name end
	end
	if has(C_Spell, "GetSpellInfo") then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
	end
	if hasg("GetSpellInfo") then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and type(name) == "string" then return name end
	end
	return nil
end

-------------------------------------------------------------------------------
-- Addon comms (Phase 5)
-------------------------------------------------------------------------------
API.PREFIX = "HHUSTLE"
function API.RegisterPrefix()
	if has(C_ChatInfo, "RegisterAddonMessagePrefix") then pcall(C_ChatInfo.RegisterAddonMessagePrefix, API.PREFIX) end
end
function API.InGroup()
	return hasg("IsInGroup") and IsInGroup() or false
end

function API.IsPartySender(sender)
 if not API.InGroup() or type(sender)~="string" then return false end
 local function canonical(name)
  if type(name)~="string" then return nil end
  if has(C_NameUtil,"ReplaceSurnameSeparatorWithLinkSeparator") then
   local ok,value=pcall(C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator,name)
   if ok and type(safe(value))=="string" then return value end
  end
  return name
 end
 sender=canonical(sender)
 for i=1,4 do
  local read=hasg("UnitFullName") and UnitFullName or _G.UnitName
  if type(read)=="function" then
   local ok,name,realm=pcall(read,"party"..i)
   name,realm=safe(name),safe(realm)
   if ok and type(name)=="string" then
    local ownRealm=hasg("GetRealmName") and safe(GetRealmName()) or nil
    local server=type(realm)=="string" and realm~="" and realm or ownRealm
    local full=type(server)=="string" and canonical(name.."-"..server:gsub("%s+",""))
    if sender==full or (sender==canonical(name) and (not realm or realm=="" or realm==ownRealm)) then return true end
   end
  end
 end
 return false
end

function API.SendPartyMessage(msg)
	if not API.InGroup() then return false, "not in a party" end
	if type(msg) ~= "string" or #msg > 255 then return false, "message too long" end
	if not has(C_ChatInfo, "SendAddonMessage") then return false, "addon messaging unavailable" end
	if has(C_ChatInfo, "InChatMessagingLockdown") and C_ChatInfo.InChatMessagingLockdown() then return false, "addon messaging locked" end
	local ok, res = pcall(C_ChatInfo.SendAddonMessage, API.PREFIX, msg, "PARTY")
	if not ok then return false, "send failed: " .. tostring(res) end
	local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
	if res == success then return true end
	local label = "result " .. tostring(res)
	for name, value in pairs(Enum and Enum.SendAddonMessageResult or {}) do
		if res == value then label = name; break end
	end
	return false, label
end

function API.PlayerLevel() return hasg("UnitLevel") and safe(UnitLevel("player")) or nil end
function API.UnitGUID(unit) return hasg("UnitGUID") and safe(UnitGUID(unit)) or nil end

-------------------------------------------------------------------------------
-- Rare watch (dungeon rare spawns). Probe evidence 2026-10-09 (build 70291):
-- inside a dungeon the Map restriction makes NPC UnitName/UnitGUID secret even
-- out of combat, while UnitClassification/UnitLevel/UnitReaction/UnitIsPlayer
-- read as plain values (no secret gate in Blizzard's docs). Loot-source GUIDs
-- are not guarded (boss loot recorded in City of Dalaran 2026-10-08).
-------------------------------------------------------------------------------
local issecrettable = (type(_G.issecrettable) == "function") and _G.issecrettable or function() return false end

function API.UnitRare(unit)
	if not hasg("UnitExists") or not safe(UnitExists(unit)) then return nil end
	local info = { unit = unit }
	info.isPlayer = safe(UnitIsPlayer(unit)) and true or false
	if hasg("UnitClassification") then info.classification = safe(UnitClassification(unit)) end
	info.level = safe(UnitLevel(unit))
	if hasg("UnitReaction") then info.reaction = safe(UnitReaction("player", unit)) end
	if hasg("UnitCreatureType") then info.creatureType = safe(UnitCreatureType(unit)) end
	if hasg("UnitIsDead") then info.dead = safe(UnitIsDead(unit)) and true or false end
	local name = UnitName(unit)
	info.nameSecret = FP.issecret(name) and true or false
	info.name = safe(name)
	local guid = hasg("UnitGUID") and UnitGUID(unit) or nil
	info.guid = safe(guid)
	if type(info.guid) == "string" then info.kind, info.id = U.ParseGUID(info.guid) end
	info.rare = (info.classification == "rare" or info.classification == "rareelite") and true or false
	return info
end

-- Display only: hands the (possibly secret) unit name straight to a FontString.
-- The value is never compared, stored or concatenated. Returns true if shown.
function API.ShowUnitName(fontString, unit)
	if not fontString or not hasg("UnitName") then return false end
	local ok, name = pcall(UnitName, unit)
	if not ok or name == nil then return false end
	local shown = pcall(fontString.SetText, fontString, name)
	if not shown then pcall(fontString.SetText, fontString, "") end
	return shown
end

function API.GetInstance()
	local inInstance, kind = API.InInstance()
	local out = { inInstance = inInstance and true or false, kind = kind }
	if not hasg("GetInstanceInfo") then return out end
	local ok, name, itype, diffID, diffName, maxPlayers, dyn, isDyn, mapID = pcall(GetInstanceInfo)
	if not ok then return out end
	out.name, out.type, out.difficulty, out.mapID = safe(name), safe(itype), safe(diffID), safe(mapID)
	return out
end

-- nil = API absent; {} = none. Vignettes are Mainline's minimap rare/treasure
-- markers; whether Forever flags vanilla rares with them is unverified.
function API.GetVignettes()
	if not has(C_VignetteInfo, "GetVignettes") then return nil end
	local out = {}
	local ok, guids = pcall(C_VignetteInfo.GetVignettes)
	if not ok or type(guids) ~= "table" or issecrettable(guids) then return out end
	for _, guid in ipairs(guids) do
		local g = safe(guid)
		if type(g) == "string" then
			local entry = { guid = g }
			if has(C_VignetteInfo, "GetVignetteInfo") then
				local good, info = pcall(C_VignetteInfo.GetVignetteInfo, g)
				if good and type(info) == "table" and not issecrettable(info) then
					entry.name, entry.atlas, entry.type, entry.onMinimap = safe(info.name), safe(info.atlasName), safe(info.type), safe(info.onMinimap)
					entry.dead, entry.objectGUID, entry.vignetteID = safe(info.isDead), safe(info.objectGUID), safe(info.vignetteID)
				end
			end
			out[#out + 1] = entry
		end
	end
	return out
end

function API.PlayAlert()
	if not hasg("PlaySound") then return false end
	local kit = (type(SOUNDKIT) == "table" and SOUNDKIT.RAID_WARNING) or 8959
	local ok, played = pcall(PlaySound, kit, "Master")
	return (ok and played) and true or false
end

-------------------------------------------------------------------------------
-- Positive control: which APIs exist and which live probes work RIGHT NOW.
-------------------------------------------------------------------------------
function API.Check()
	local rows = {}
	local function row(name, ok, note) rows[#rows + 1] = { name = name, ok = ok and true or false, note = note } end
	local function g(name) row(name, hasg(name)) end
	local function c(tbl, name, fn) row(name .. "." .. fn, has(_G[name], fn)) end

	for _, n in ipairs({ "GetPlayerFacing", "GetQuestID", "GetTitleText", "GetObjectiveText", "GetRewardXP", "GetQuestLogRewardXP",
		"GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "GetLootSourceInfo", "GetMerchantNumItems", "GetMerchantItemLink",
		"GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq", "GetTrainerServiceCost",
		"NumTaxiNodes", "TaxiNodeName", "TaxiNodePosition", "TaxiNodeCost", "GetTaxiMapID", "GetBindLocation",
		"GetProfessions", "GetProfessionInfo", "UnitXP", "UnitXPMax", "GetXPExhaustion", "GetServerTime", "CreateVector2D",
		"GetNumAvailableQuests", "GetAvailableQuestInfo", "GetNumActiveQuests", "GetActiveQuestID", "issecretvalue",
		"UnitUsesAmmo", "UnitClassification", "GetInstanceInfo", "PlaySound" }) do g(n) end -- UnitUsesAmmo: new in 70170
	for _, pair in ipairs({
		{ "C_Map", "GetBestMapForUnit" }, { "C_Map", "GetPlayerMapPosition" }, { "C_Map", "GetWorldPosFromMapPos" }, { "C_Map", "GetMapInfo" },
		{ "C_Map", "GetMapWorldSize" }, { "C_Map", "CanSetUserWaypointOnMap" }, { "C_Map", "SetUserWaypoint" },
		{ "C_QuestLog", "GetNumQuestLogEntries" }, { "C_QuestLog", "GetInfo" }, { "C_QuestLog", "GetQuestObjectives" },
		{ "C_QuestLog", "ReadyForTurnIn" }, { "C_QuestLog", "IsComplete" }, { "C_QuestLog", "GetQuestsOnMap" },
		{ "C_QuestLog", "GetNextWaypoint" }, { "C_QuestLog", "GetDistanceSqToQuest" }, { "C_QuestLog", "GetAllCompletedQuestIDs" },
		{ "C_QuestLog", "GetLogIndexForQuestID" }, { "C_QuestLog", "GetTitleForQuestID" },
		{ "C_GossipInfo", "GetAvailableQuests" }, { "C_GossipInfo", "GetActiveQuests" }, { "C_GossipInfo", "GetOptions" },
		{ "C_Item", "GetItemInfo" }, { "C_Item", "GetItemCount" }, { "C_Item", "GetItemSpell" },
		{ "C_Container", "GetContainerNumSlots" }, { "C_Container", "GetContainerItemInfo" }, { "C_SpellBook", "IsSpellKnown" }, { "C_Container", "GetItemCooldown" }, { "C_Spell", "GetItemCooldown" },
		{ "C_MerchantFrame", "GetItemInfo" }, { "C_TaxiMap", "GetAllTaxiNodes" }, { "C_Minimap", "GetViewRadius" },
		{ "C_TradeSkillUI", "GetBaseProfessionInfo" }, { "C_TradeSkillUI", "GetChildProfessionInfo" }, { "C_TradeSkillUI", "GetAllRecipeIDs" }, { "C_TradeSkillUI", "GetFilteredRecipeIDs" },
		{ "C_TradeSkillUI", "GetRecipeInfo" }, { "C_TradeSkillUI", "GetRecipeSchematic" }, { "C_SkillInfo", "GetSkillLineInfo" },
		{ "C_ChatInfo", "SendAddonMessage" }, { "C_Spell", "GetSpellName" }, { "C_VignetteInfo", "GetVignettes" }, { "C_Timer", "After" }, { "C_Timer", "NewTicker" }, { "C_Texture", "GetAtlasInfo" },
	}) do c(_G[pair[1]], pair[1], pair[2]) end

	-- Each probe is independent; a throwing API must not erase other evidence.
	local function probe(name, fn)
		local success, ok, note = pcall(fn)
		row("probe:" .. name, success and ok, success and note or tostring(ok))
		rows[#rows].status = not success and "error" or (ok and "ok" or "inconclusive")
	end
	local mapID, x, y, log
	probe("bestMap", function()
		mapID = API.GetBestMap()
		return mapID ~= nil, mapID and (API.GetMapName(mapID) .. " (" .. mapID .. ")") or "no current map"
	end)
	probe("playerPos", function()
		x, y = API.GetPlayerMapPosition(mapID)
		return x ~= nil, x and U.FormatCoords(x, y) or "no position in this context"
	end)
	probe("worldPos", function()
		local c, wx, wy = API.GetWorldPos(mapID, x or 0.5, y or 0.5)
		return wx ~= nil, wx and string.format("continent %s %.0f, %.0f%s", tostring(c), wx, wy, x and "" or " (map-center fallback)") or "no world conversion"
	end)
	probe("facing", function()
		local f = API.GetFacing()
		return f ~= nil, f and string.format("%.2f rad", f) or "facing unavailable here"
	end)
	probe("mapSize", function()
		local w, h = API.GetMapWorldSize(mapID)
		return w ~= nil, w and string.format("%.0f x %.0f yd", w, h) or "no map dimensions"
	end)
	probe("minimapRadius", function() return true, tostring(API.GetMinimapViewRadius()) .. " yd (adapter, may use fallback)" end)
	probe("userWaypointOK", function() local allowed = API.CanSetUserWaypoint(mapID); return allowed, allowed and "allowed on current map" or "not allowed on current map" end)
	probe("questLog", function() log = API.GetQuestLog(); return true, #log .. " quests" end)
	probe("questLogCap", function()
		-- 70170 moved MAX_QUESTS onto this constant (40 in the source); the planner never hardcodes it.
		local cap = Constants and Constants.QuestLogConsts and Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT
		return cap ~= nil, cap and ("log holds " .. tostring(cap) .. " quests") or "constant missing"
	end)
	probe("questsOnMap", function()
		local pois = API.GetQuestsOnMap(mapID)
		return #pois > 0, #pois .. " POIs on this map; zero alone does not prove unsupported API"
	end)
	probe("questOffers", function()
		API.RequestQuestOffers(mapID)
		local offers, counts = API.GetQuestOffers(mapID)
		return #offers > 0, string.format("%d map-listed; %d recent NPC-confirmed; %d known pickups. Map listings may be incomplete; talk to a quest giver to confirm offers.", counts.map, counts.npc, #offers)
	end)
	probe("navigationUI", function()
		local active = FP.Waypoints and FP.Waypoints:GetActive()
		local waiting = FP.Planner and FP.Planner.waiting
		local arrow = FP.Arrow
		return arrow and arrow.frame and arrow.frame:IsShown(), string.format("auto=%s arrowEnabled=%s arrowShown=%s active=%s waiting=%s texture=%s",
			tostring(FP.settings.autoNext), tostring(FP.settings.arrow.shown), tostring(arrow and arrow.frame and arrow.frame:IsShown()),
			tostring(active and active.title), tostring(waiting and waiting.title), tostring(arrow and arrow.tex and arrow.tex:GetTexture()))
	end)
	local first = log and log[1]
	probe("nextWaypoint", function()
		if not first then return false, "no quest to probe" end
		local m, qx, qy = API.GetQuestNextWaypoint(first.questID)
		return m ~= nil, m and (API.GetMapName(m) .. " " .. U.FormatCoords(qx, qy)) or ("no waypoint for " .. first.questID)
	end)
	probe("distSqToQuest", function()
		if not first then return false, "no quest to probe" end
		local d = API.GetDistanceSqToQuest(first.questID)
		return d ~= nil, d and U.FormatDistance(math.sqrt(d)) or "no distance"
	end)
	probe("questRewardXP", function()
		if not first then return false, "no quest to probe" end
		local xp = API.GetQuestRewardXP(first.questID)
		return xp ~= nil, xp and (xp .. " xp for " .. first.questID) or "reward data not loaded"
	end)
	probe("completedQuests", function() local done = API.GetCompletedQuests(); return true, #done .. " completed quest ids" end)
	probe("professions", function()
		local profs, parts = API.GetProfessions(), {}
		for _, p in ipairs(profs) do parts[#parts + 1] = tostring(p.name) .. " " .. tostring(p.rank) .. "/" .. tostring(p.maxRank) end
		return #profs > 0, #profs > 0 and table.concat(parts, ", ") or "no professions available in this context"
	end)
	probe("openProfession", function()
		local info, source = API.GetOpenTradeSkill()
		return info ~= nil, info and (tostring(info.professionName) .. " via " .. tostring(source) .. "; " .. #API.GetTradeSkillRecipeIDs() .. " recipe IDs") or "open your own profession window to verify recipe access"
	end)
	probe("magePrep", function()
		local inv, reason = API.GetPrepInventory()
		if not inv then return false, reason end
		return inv.waterKnown and inv.bandagesKnown, string.format("drink count %s; bandages %s; learned spell lookup %s",
			inv.waterKnown and tostring(inv.water) or "loading/unknown", inv.bandagesKnown and tostring(inv.bandages) or "loading/unknown", tostring(API.KnowsSpell(759)))
	end)
	probe("actionBars", function()
		local bars, count = API.ReadActionBars()
		return API.ActionBarsAvailable() and bars ~= nil, string.format("slot API %s; spec group %s; %s",
			API.ActionBarsAvailable() and "present" or "missing", tostring(API.ActiveSpecGroup()),
			bars and (count .. " buttons readable") or "bars not readable now (combat or secret)")
	end)
	probe("lootSparkle", function()
		local state, outline = API.GetLootSparkle(), API.OutlineModeOn()
		return state ~= nil, string.format("loot sparkle setting %s; outline mode %s",
			state == nil and "missing" or (state == "1" and "on" or "off"),
			outline == nil and "unreadable" or (outline and "on" or "off"))
	end)
	probe("enemyWatch", function()
		local shown, always = API.EnemyNameplates()
		local function word(v) return v == nil and "unreadable" or (v and "on" or "off") end
		local missing = {}
		for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_SPELLCAST_SUCCEEDED", "PARTY_KILL", "PLAYER_DEAD", "PLAYER_FOCUS_CHANGED" }) do
			if FP.unavailableEvents[event] then missing[#missing + 1] = event end
		end
		return API.EnemyWatchAvailable() and #missing == 0, string.format("unit API %s; enemy nameplates %s, outside combat %s; zone %s; death recap %s%s",
			API.EnemyWatchAvailable() and "present" or "missing", word(shown), word(always), tostring(API.ZonePvPType()),
			has(C_DeathRecap, "GetRecapEvents") and "present" or "missing", #missing > 0 and ("; events missing: " .. table.concat(missing, ", ")) or "")
	end)
	probe("classPrep", function()
		local free = API.GetFreeBagSlots()
		return free ~= nil, tostring(API.GetCharInfo().class) .. "; general bag slots " .. tostring(free or "unavailable")
	end)
	probe("hearth", function() return API.HasHearthstone(), "bind: " .. tostring(API.GetBindLocation()) end)
	probe("secretUnitName", function() return true, FP.issecret(UnitName("player")) and "player name is secret" or "player name readable" end)
	probe("instance", function()
		local inst = API.GetInstance()
		return inst.inInstance, inst.inInstance and string.format("%s (%s, map %s)", tostring(inst.name), tostring(inst.type), tostring(inst.mapID)) or "not in an instance"
	end)
	probe("vignettes", function()
		local list = API.GetVignettes()
		if not list then return false, "C_VignetteInfo absent" end
		local names = {}
		for _, v in ipairs(list) do names[#names + 1] = tostring(v.name or v.atlas or "?") end
		return true, #list .. " vignettes" .. (#list > 0 and (": " .. table.concat(names, ", ")) or "")
	end)
	probe("targetClassification", function()
		-- rare watch depends on this staying readable where names are secret
		if not safe(UnitExists("target")) then return false, "no target to probe" end
		local cls = hasg("UnitClassification") and UnitClassification("target") or nil
		local secretCls, secretName = FP.issecret(cls), FP.issecret(UnitName("target"))
		return not secretCls, string.format("classification %s%s · name %s", secretCls and "SECRET" or tostring(cls), (not secretCls and (" lvl " .. tostring(safe(UnitLevel("target"))))) or "", secretName and "secret" or "readable")
	end)
	local unavailable = {}
	for ev in pairs(FP.unavailableEvents) do unavailable[#unavailable + 1] = ev end
	row("probe:unavailableEvents", #unavailable == 0, table.concat(unavailable, ", "))
	return rows
end

function API.CaptureNavigation()
	-- Bounded diagnostic snapshot, including the exact data used to route.
	local snapshotOK, navigation = pcall(function()
		local mapID = API.GetBestMap()
		local arrow = FP.Arrow
		return { t = U.Now(), version = FP.version, build = FP.clientBuild,
			arrowShown = arrow.frame:IsShown(), arrowEnabled = FP.settings.arrow.shown,
			arrowTitle = arrow.title:GetText(), arrowText = arrow.dist:GetText(), texture = arrow.tex:GetTexture(),
			mapID = mapID, quests = API.GetQuestLog(), pois = API.GetQuestsOnMap(mapID), selected = API.GetSelectedQuest(),
			offers = API.GetQuestOffers(mapID), active = U.Copy(FP.Waypoints:GetActive() or {}),
			waiting = U.Copy(FP.Planner.waiting or {}), paused = FP.Planner.paused }
	end)
	return snapshotOK and navigation or { t = U.Now(), error = tostring(navigation) }
end

function API.StoreCheck(rows, manual)
	local result = { t = U.Now(), build = FP.clientBuild, version = FP.version, ok = 0, fail = 0, rows = {} }
	result.navigation = API.CaptureNavigation()
	for _, r in ipairs(rows) do
		result.rows[r.name] = { ok = r.ok, note = r.note, status = r.status or (r.ok and "ok" or "unavailable") }
		if r.ok then result.ok = result.ok + 1 else result.fail = result.fail + 1 end
	end
	FP.db.apicheck[tostring(FP.clientBuild) .. (manual and "-manual" or "")] = result
	FP.db.apicheckHistory = FP.db.apicheckHistory or {}
	U.Push(FP.db.apicheckHistory, result, 10)
	return result
end

-------------------------------------------------------------------------------
-- Quest reward comparison: read the native selected log quest or open dialog.
-- Verified source 1.60.1.70888: QuestInfo.lua uses these context-bound queries.
-- No selection changes: browsing must not disturb quest tracking/navigation.
-------------------------------------------------------------------------------
local function rewardCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local v = {pcall(fn, ...)}
	if not v[1] then return nil end
	for i = 2, 20 do v[i] = safe(v[i]) end
	return v
end
local function rewardNumber(v)
	return U.Finite(v) and v >= 0 and v or nil
end
local function rewardString(v) return type(v)=="string" and v~="" and v or nil end
local function rewardFirst(fn, ...)
	local v=rewardCall(fn,...);return v and v[2]
end

local rewardItemRequests={}
local rewardItemRequestCount=0
local function requestRewardItem(link)
	local id=tonumber(link:match("item:(%d+)"))
	if id and id>0 and not rewardItemRequests[id] and rewardItemRequestCount<128 and has(C_Item,"RequestLoadItemDataByID") then
		rewardItemRequests[id]=true;rewardItemRequestCount=rewardItemRequestCount+1
		pcall(C_Item.RequestLoadItemDataByID,id)
	end
end

function API.GetRewardItem(link)
	link=rewardString(safe(link))
	if not link then return nil end
	local fn=has(C_Item,"GetItemInfo") and C_Item.GetItemInfo or _G.GetItemInfo
	local v=rewardCall(fn,link)
	if not v or not rewardString(v[2]) then requestRewardItem(link);return nil end
	local item={link=link,name=v[2],level=rewardNumber(v[5]),minLevel=rewardNumber(v[6]),
		subtype=rewardString(v[8]),equipLoc=rewardString(v[10]),price=rewardNumber(v[12])}
	local stats=rewardFirst(has(C_Item,"GetItemStats") and C_Item.GetItemStats or _G.GetItemStats,link)
	if type(stats)=="table" then
		-- A partially unreadable table cannot safely supply zero for omitted stats.
		local clean,valid={},true
		local ok=pcall(function()
			for k,value in pairs(stats) do
				k,value=safe(k),safe(value)
				if type(k)~="string" or not U.Finite(value) then valid=false else clean[k]=value end
			end
		end)
		if ok and valid then item.stats=clean end
	end
	return item
end

function API.GetRewardEquipment(slot)
	if not U.Finite(slot) or slot<1 or slot>19 then return {status="unknown"} end
	if not hasg("GetInventoryItemID") then return {status="unknown"} end
	local ok,raw=pcall(GetInventoryItemID,"player",slot)
	if not ok or FP.issecret(raw) then return {status="unknown"} end
	if raw==nil then return {status="empty",stats={}} end
	local id=rewardNumber(safe(raw))
	if not id or id==0 then return {status="unknown"} end
	local link=rewardString(rewardFirst(_G.GetInventoryItemLink,"player",slot))
	if not link then return {status="unknown"} end
	local item=API.GetRewardItem(link)
	if not item then return {status="loading",link=link} end
	item.status="equipped";return item
end

function API.GetRewardStatLabel(key)
	local label=safe(_G[key])
	return rewardString(label) or key:gsub("_", " ")
end

function API.GetRewardContext(mode)
	local out={items={},mode=mode=="dialog" and "dialog" or "log"}
	if API.InCombat() then out.message="Reward comparisons resume after combat.";return out end
	local dialog=out.mode=="dialog"
	if dialog then
		local f=_G.QuestFrame
		if not f or not f.IsShown or not f:IsShown() then out.message="Open a quest offer or turn-in to compare its rewards.";return out end
	end
	local function contextFn(dialogFn,logFn)
		if dialog then return dialogFn else return logFn end
	end
	local function identity()
		return rewardNumber(rewardFirst(contextFn(_G.GetQuestID,has(C_QuestLog,"GetSelectedQuest") and C_QuestLog.GetSelectedQuest)))
	end
	local id=identity()
	if not id or id==0 then out.message="Select a quest in Blizzard's quest log, then return here.";return out end
	out.questID=id
	local title
	if dialog then title=rewardFirst(_G.GetTitleText)
	else title=rewardFirst(has(C_QuestLog,"GetTitleForQuestID") and C_QuestLog.GetTitleForQuestID,id) end
	out.title=rewardString(title) or ("Quest #"..id)
	if not dialog and hasg("HaveQuestRewardData") and rewardFirst(HaveQuestRewardData,id)~=true then
		out.message="Reward data is loading or unavailable. Open this quest in the quest log and refresh."
		return out
	end
	out.xp=rewardNumber(rewardFirst(contextFn(_G.GetRewardXP,_G.GetQuestLogRewardXP)))
	out.money=rewardNumber(rewardFirst(contextFn(_G.GetRewardMoney,_G.GetQuestLogRewardMoney)))
	out.countsKnown=true
	for _,kind in ipairs({"choice","reward"}) do
		local countFn
		if dialog then
			if kind=="choice" then countFn=_G.GetNumQuestChoices else countFn=_G.GetNumQuestRewards end
		else
			if kind=="choice" then countFn=_G.GetNumQuestLogChoices else countFn=_G.GetNumQuestLogRewards end
		end
		local count
		if not dialog and kind=="choice" then count=rewardNumber(rewardFirst(countFn,id,true))
		else count=rewardNumber(rewardFirst(countFn)) end
		if not count or count>64 or count~=math.floor(count) then
			out.countsKnown=false
		else
			for i=1,count do
				local info
				if dialog then info=rewardCall(_G.GetQuestItemInfo,kind,i)
				elseif kind=="choice" then info=rewardCall(_G.GetQuestLogChoiceInfo,i)
				else info=rewardCall(_G.GetQuestLogRewardInfo,i) end
				local link=rewardString(rewardFirst(contextFn(_G.GetQuestItemLink,_G.GetQuestLogItemLink),kind,i))
				local item=link and API.GetRewardItem(link) or nil
				local qty=info and rewardNumber(info[4])
				if qty and (qty==0 or qty~=math.floor(qty)) then qty=nil end
				local row={key=kind..":"..i,kind=kind,index=i,link=link,item=item,count=qty,
					name=info and rewardString(info[2]) or (item and item.name) or "Item data loading",
					usable=info and type(info[6])=="boolean" and info[6] or nil}
				-- Preserve an explicit false from Blizzard's usability read.
				if info and info[6]==false then row.usable=false end
				row.value=rewardNumber(item and item.price and qty and item.price*qty or nil)
				out.items[#out.items+1]=row
			end
		end
	end
	if identity()~=id then return {items={},mode=out.mode,message="Quest changed; refresh to view its rewards."} end
	if not out.countsKnown then out.message="Some reward lists are unavailable; vendor ranking is incomplete."
	elseif #out.items==0 then out.message="No item rewards listed for this quest." end
	return out
end

-- Optional provider links; reading a gear source does not alter selected quests.
function API.EnsureGearCatalog()
 if FP.GearCatalog then return true end
 if API.InCombat() then return false end
 local loader=has(C_AddOns,"LoadAddOn") and C_AddOns.LoadAddOn or _G.LoadAddOn
 if type(loader)~="function" then return false end
 pcall(loader,"HearthAndHustle_GearData")
 return type(FP.GearCatalog)=="table" and type(FP.GearCatalog.items)=="table"
end

function API.CanDualWield()
 if API.InCombat() or not hasg("CanDualWield") then return false end
 local ok,value=pcall(CanDualWield)
 return ok and safe(value)==true
end

function API.GetGearQuestSources(itemID)
 if API.InCombat() or not U.Finite(itemID) or itemID<=0 or not API.QuestDatabaseStatus() then return {} end
 local db=LibQuestieDB.Item
 if type(db)~="table" or type(db.Get)~="function" then return {} end
 local ok,ids=pcall(db.Get,itemID,"questRewards")
 if not ok or type(ids)~="table" then return {} end
 local out,seen={},{}
 for i,id in ipairs(ids) do
  if i>64 then break end
  if U.Finite(id) and id>0 and id==math.floor(id) and not seen[id] then
   seen[id]=true
   local q=API.GetQuestChainRecord(id)
   if q then out[#out+1]=q end
  end
 end
 table.sort(out,function(a,b) return a.id<b.id end)
 return out
end

-------------------------------------------------------------------------------
-- Action bars (Modules/BarGuard.lua). Checked against Blizzard's Forever source
-- 1.60.1.70938: GetActionInfo / PlaceAction / PickupMacro are the globals
-- Blizzard's own action buttons call; C_Spell.PickupSpell, C_Item.PickupItem and
-- C_SpecializationInfo.GetActiveSpecGroup are documented. Reads never run in
-- combat (the values may be secret there) and every write refuses combat.
-------------------------------------------------------------------------------
-- Player-placed slots: pages 1-10 (main bar, the four extra bars, stance pages)
-- and pages 13-15 (bars 6-8). Pages 11-12 are possess/vehicle and totem slots.
API.BAR_SLOT_RANGES = { { 1, 120 }, { 145, 180 } }
local RANDOM_MOUNT = 268435455

function API.ActionBarsAvailable()
	return hasg("GetActionInfo") and hasg("PlaceAction") and hasg("ClearCursor") and hasg("GetCursorInfo")
		and has(C_Spell, "PickupSpell")
end

function API.ActiveSpecGroup()
	local fn = has(C_SpecializationInfo, "GetActiveSpecGroup") and C_SpecializationInfo.GetActiveSpecGroup
		or (hasg("GetActiveTalentGroup") and GetActiveTalentGroup)
	if not fn then return 1 end
	local ok, group = pcall(fn)
	group = ok and safe(group) or nil
	if U.Finite(group) and group >= 1 and group <= 8 and group == math.floor(group) then return group end
	return nil
end

-- One slot: nil = empty, a table = what is on it, false = could not be read.
-- "Could not be read" must never be mistaken for "empty".
function API.GetActionSlot(slot)
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or FP.issecret(kind) or FP.issecret(id) or FP.issecret(sub) then return false end
	if kind == nil then return nil end
	if type(kind) ~= "string" then return false end
	local entry = { k = kind }
	if type(id) == "number" or type(id) == "string" then entry.id = id end
	if type(sub) == "string" then entry.sub = sub end
	if kind == "macro" then
		-- The id of a macro slot is not a stable macro index on this client; the name is.
		local text = has(C_ActionBar, "GetActionText") and C_ActionBar.GetActionText or (hasg("GetActionText") and GetActionText)
		if text then
			local okText, name = pcall(text, slot)
			if okText and FP.issecret(name) then return false end
			if okText and type(name) == "string" and name ~= "" then entry.n = name end
		end
	end
	return entry
end

-- Every player-placed slot, or nil when any slot is unreadable or in combat.
function API.ReadActionBars()
	if not API.ActionBarsAvailable() or API.InCombat() then return nil end
	local out, count = {}, 0
	for _, range in ipairs(API.BAR_SLOT_RANGES) do
		for slot = range[1], range[2] do
			local entry = API.GetActionSlot(slot)
			if entry == false then return nil end
			if entry then out[slot] = entry; count = count + 1 end
		end
	end
	return out, count
end

function API.CursorBusy()
	if not hasg("GetCursorInfo") then return true end
	local ok, kind = pcall(GetCursorInfo)
	if not ok then return true end
	return kind ~= nil
end

local function pickUp(entry)
	local kind, id = entry.k, entry.id
	if kind == "spell" and U.Finite(id) then
		C_Spell.PickupSpell(id)
	elseif kind == "item" and U.Finite(id) then
		if has(C_Item, "PickupItem") then C_Item.PickupItem(id) elseif hasg("PickupItem") then PickupItem(id) end
	elseif kind == "macro" and hasg("PickupMacro") then
		local target = entry.n
		if target and hasg("GetMacroIndexByName") then
			local index = GetMacroIndexByName(target)
			target = U.Finite(index) and index > 0 and index or nil
		end
		if target then PickupMacro(target) end
	elseif kind == "summonmount" and U.Finite(id) then
		if id == RANDOM_MOUNT then
			if has(C_MountJournal, "Pickup") then C_MountJournal.Pickup(0) end
		elseif has(C_MountJournal, "GetMountInfoByID") then
			local _, spellID = C_MountJournal.GetMountInfoByID(id)
			spellID = safe(spellID)
			if U.Finite(spellID) then C_Spell.PickupSpell(spellID) end
		end
	end
end

-- Put a remembered button back on an EMPTY slot. Never in combat, never while the
-- player holds something on the cursor, never on top of an existing button.
-- Returns true, or false and why.
function API.PlaceOnBar(slot, entry)
	if not API.ActionBarsAvailable() then return false, "unavailable" end
	if API.InCombat() then return false, "combat" end
	if API.CursorBusy() then return false, "cursor" end
	local current = API.GetActionSlot(slot)
	if current == false then return false, "unreadable" end
	if current ~= nil then return false, "occupied" end
	local ok, err = pcall(pickUp, entry)
	if not ok then pcall(ClearCursor); return false, tostring(err) end
	if not API.CursorBusy() then return false, "pickup" end
	local placed = pcall(PlaceAction, slot)
	pcall(ClearCursor)
	if not placed then return false, "place" end
	return true
end

-------------------------------------------------------------------------------
-- Quest item sparkle (Modules/QuestSparkle.lua). The client's own loot sparkle
-- is one console variable, and it is the only one this addon writes: the name
-- is fixed here, there is no general "set a console variable" function. Outline
-- Mode is read, never written. C_CVar.GetCVar / SetCVar and CVAR_UPDATE are
-- documented in Blizzard's Forever source (1.60.1.70938); the variable itself
-- belongs to the engine and is not listed there, so a client without it reads
-- nil and the feature stays inert.
-------------------------------------------------------------------------------
local LOOT_SPARKLE_CVAR = "outlineModeShowLootEffectWhenDisabled"
local OUTLINE_MODE_CVAR = "graphicsOutlineMode"

local function readCVar(name)
	if not has(C_CVar, "GetCVar") then return nil end
	local ok, value = pcall(C_CVar.GetCVar, name)
	value = ok and safe(value) or nil
	if type(value) == "number" then value = tostring(value) end
	return type(value) == "string" and value or nil
end

-- "1" (on), another string (off), or nil when the client has no such setting.
function API.GetLootSparkle()
	if not has(C_CVar, "SetCVar") then return nil end
	return readCVar(LOOT_SPARKLE_CVAR)
end

-- true / false, or nil when it cannot be read. Read only.
function API.OutlineModeOn()
	local value = readCVar(OUTLINE_MODE_CVAR)
	if value == nil then return nil end
	return value ~= "0"
end

-- Switch the loot sparkle setting. Never in combat; writes only when the value
-- differs. Returns true, or false and why.
function API.SetLootSparkle(on)
	local want = on and "1" or "0"
	local current = API.GetLootSparkle()
	if current == nil then return false, "unavailable" end
	if current == want or (not on and current ~= "1") then return true end
	if API.InCombat() then return false, "combat" end
	if not pcall(C_CVar.SetCVar, LOOT_SPARKLE_CVAR, want) then return false, "error" end
	if API.GetLootSparkle() ~= want then return false, "refused" end
	return true
end

-------------------------------------------------------------------------------
-- Enemy watch (PvP/EnemyWatch.lua): hostile players the client already shows.
-- Checked against Blizzard's Forever source 1.60.1.70938: on this client
-- UnitName(unit) returns the first name and the surname, and Blizzard's own
-- NameUtil joins them with CHARACTERNAME_SURNAME_SEPARATOR. NAME_PLATE_UNIT_ADDED
-- / _REMOVED carry a unit token. UnitGUID and PARTY_KILL are secret while unit
-- identity is restricted, UNIT_SPELLCAST_SUCCEEDED while casts are restricted;
-- every value is checked before use. GetGuildInfo is an undocumented global the
-- Blizzard UI still calls. Nothing here targets, and nothing reads auras.
-------------------------------------------------------------------------------
local function surnameSeparator()
	local consts = type(Constants) == "table" and Constants.CharacterNameSeparatorConsts
	local sep = type(consts) == "table" and consts.CHARACTERNAME_SURNAME_SEPARATOR
	return (type(sep) == "string" and sep ~= "") and sep or " "
end

-- "First Last" for a player unit, or nil when the client withholds the name.
function API.PlayerFullName(unit)
	if not hasg("UnitName") then return nil end
	local ok, name, surname = pcall(UnitName, unit)
	if not ok then return nil end
	name, surname = safe(name), safe(surname)
	if type(name) ~= "string" or name == "" or name == _G.UNKNOWNOBJECT then return nil end
	if type(surname) == "string" and surname ~= "" then return name .. surnameSeparator() .. surname end
	return name
end

function API.EnemyWatchAvailable()
	return hasg("UnitIsEnemy") and hasg("UnitIsPlayer") and hasg("UnitExists") and hasg("UnitName")
end

function API.IsNameplateUnit(unit)
	return type(unit) == "string" and unit:find("^nameplate%d+$") ~= nil
end

-- A player of the other side behind a unit token:
-- { name, class, race, level, guild, guid, attackable, targetsMe, dead }.
-- nil when the unit is anything else; nil, "secret" when it is such a player
-- whose name the client withholds.
function API.EnemyPlayer(unit)
	if type(unit) ~= "string" or not API.EnemyWatchAvailable() then return nil end
	local ok, exists = pcall(UnitExists, unit)
	if not ok or not safe(exists) then return nil end
	if not safe(UnitIsPlayer(unit)) then return nil end
	local good, enemy = pcall(UnitIsEnemy, "player", unit)
	if not good or not safe(enemy) then return nil end
	local name = API.PlayerFullName(unit)
	if not name then return nil, "secret" end
	local info = { name = name }
	if hasg("UnitClass") then
		local _, class = UnitClass(unit)
		class = safe(class)
		if type(class) == "string" then info.class = class end
	end
	if hasg("UnitRace") then
		local race = safe((UnitRace(unit)))
		if type(race) == "string" then info.race = race end
	end
	if hasg("UnitLevel") then
		local level = safe(UnitLevel(unit))
		if U.Finite(level) then info.level = level end
	end
	if hasg("GetGuildInfo") then
		local okGuild, guild = pcall(GetGuildInfo, unit)
		guild = okGuild and safe(guild) or nil
		if type(guild) == "string" and guild ~= "" then info.guild = guild end
	end
	if hasg("UnitGUID") then
		local guid = safe(UnitGUID(unit))
		if type(guid) == "string" then info.guid = guid end
	end
	if hasg("UnitCanAttack") then
		local can = safe(UnitCanAttack("player", unit))
		if can ~= nil then info.attackable = can and true or false end
	end
	if hasg("UnitIsUnit") then
		local okTarget, same = pcall(UnitIsUnit, unit .. "target", "player")
		info.targetsMe = (okTarget and safe(same)) and true or false
	end
	if hasg("UnitIsDeadOrGhost") then info.dead = safe(UnitIsDeadOrGhost(unit)) and true or false end
	return info
end

-- "sanctuary", "contested", "friendly", "hostile", "combat", "arena", or nil.
function API.ZonePvPType()
	local fn = (has(C_PvP, "GetZonePVPInfo") and C_PvP.GetZonePVPInfo) or (hasg("GetZonePVPInfo") and GetZonePVPInfo)
	if not fn then return nil end
	local ok, kind = pcall(fn)
	kind = ok and safe(kind) or nil
	return type(kind) == "string" and kind or nil
end

function API.IsOwnGUID(guid)
	if type(guid) ~= "string" or not hasg("UnitGUID") then return false end
	return guid == safe(UnitGUID("player")) or guid == safe(UnitGUID("pet"))
end

-- Who struck the killing blow in the client's death recap: { guid, name }, or
-- nil and why. `seen` is the id of a recap already counted for an earlier death.
-- Third value: this recap's id, when the client gives one.
function API.DeathRecapKiller(seen)
	if not has(C_DeathRecap, "GetRecapEvents") then return nil, "unavailable" end
	local id
	if has(C_DeathRecap, "GetRecapLink") then
		local ok, link = pcall(C_DeathRecap.GetRecapLink)
		link = ok and safe(link) or nil
		if type(link) == "string" then id = tonumber(link:match("death:(%d+)")) end
	end
	if id and id == seen then return nil, "stale", id end
	local ok, events = pcall(C_DeathRecap.GetRecapEvents)
	if not ok or type(events) ~= "table" or issecrettable(events) then return nil, "unreadable", id end
	local event = events[1]   -- the killing blow, as Blizzard's own recap reads it
	if type(event) ~= "table" or issecrettable(event) then return nil, "empty", id end
	if safe(event.hideCaster) then return nil, "hidden", id end
	local guid, name = safe(event.sourceGUID), safe(event.sourceName)
	return { guid = type(guid) == "string" and guid or nil, name = (type(name) == "string" and name ~= "") and name or nil }, nil, id
end

local function cvarOn(name)
	local value = readCVar(name)
	if value == nil then return nil end
	return value == "1"
end

-- Enemy nameplates shown at all, and shown outside combat. nil = not readable.
function API.EnemyNameplates()
	return cvarOn("nameplateShowEnemies"), cvarOn("nameplateShowAll")
end

-- Switches both on. Only ever called from the player's click or typed command
-- (/hh enemies nameplates), never on the addon's own initiative, never in combat.
function API.EnableEnemyNameplates()
	if not has(C_CVar, "SetCVar") then return false, "unavailable" end
	if API.InCombat() then return false, "combat" end
	for _, name in ipairs({ "nameplateShowEnemies", "nameplateShowAll" }) do
		local current = readCVar(name)
		if current ~= nil and current ~= "1" then pcall(C_CVar.SetCVar, name, "1") end
	end
	local shown, always = API.EnemyNameplates()
	if shown ~= false and always ~= false then return true end
	return false, "refused"
end

local ENEMY_SOUNDS = { new = { "PVP_ENTER_QUEUE", 8458 }, kos = { "RAID_WARNING", 8959 }, stealth = { "RAID_BOSS_EMOTE_WARNING", 12197 } }
function API.PlayEnemyAlert(kind)
	local def = ENEMY_SOUNDS[kind]
	if not def or not hasg("PlaySound") then return false end
	local kit = (type(SOUNDKIT) == "table" and SOUNDKIT[def[1]]) or def[2]
	local ok, played = pcall(PlaySound, kit, "Master")
	return (ok and played) and true or false
end

function API.ScreenNotice(text)
	if type(RaidNotice_AddMessage) ~= "function" or not RaidWarningFrame or not ChatTypeInfo then return false end
	return (pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.8, b = 0 }))
end
