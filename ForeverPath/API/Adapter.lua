-- ForeverPath / API / Adapter.lua
-- The ONLY file that talks to the WoW API. Everything is feature-detected so a
-- renamed or removed function on the next build degrades one feature instead
-- of breaking the addon. Verified against Blizzard's Forever UI source
-- (build 1.60.1.70170, interface 16001, Mainline 12.1.5 API family;
-- re-verified against the 70124 -> 70170 source diff on 2026-10-01).
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
	return has(C_QuestLog, "IsOnQuest") and C_QuestLog.IsOnQuest(questID) or false
end

function API.GetQuestObjectives(questID)
	if not has(C_QuestLog, "GetQuestObjectives") then return {} end
	local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
	if ok and type(objs) == "table" then return objs end
	return {}
end

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
	if ok and mapID and x and y then return mapID, x, y end
	return nil
end

function API.GetQuestNextWaypointForMap(questID, mapID)
	if not has(C_QuestLog, "GetNextWaypointForMap") then return nil end
	local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, questID, mapID)
	if ok and x and y then return x, y end
	return nil
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

function API.GetQuestDifficultyLevel(questID)
	return has(C_QuestLog, "GetQuestDifficultyLevel") and C_QuestLog.GetQuestDifficultyLevel(questID) or nil
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

local HEARTHSTONE = 6948
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
	if not has(C_TradeSkillUI, "GetChildProfessionInfo") then return nil end
	local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
	if ok and type(info) == "table" and info.professionID and info.professionID ~= 0 then return info end
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
	if not ok or type(s) ~= "table" then return nil end
	local out = { reagents = {}, outputItemID = s.outputItemID, qtyMin = s.quantityMin, qtyMax = s.quantityMax }
	for _, slot in ipairs(s.reagentSlotSchematics or {}) do
		if slot.reagents and slot.reagents[1] and slot.reagents[1].itemID and (slot.required ~= false) then
			out.reagents[slot.reagents[1].itemID] = (out.reagents[slot.reagents[1].itemID] or 0) + (slot.quantityRequired or 1)
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
API.PREFIX = "FPATH"
function API.RegisterPrefix()
	if has(C_ChatInfo, "RegisterAddonMessagePrefix") then pcall(C_ChatInfo.RegisterAddonMessagePrefix, API.PREFIX) end
end
function API.InGroup()
	return hasg("IsInGroup") and IsInGroup() or false
end

function API.IsPartySender(sender)
	if not API.InGroup() or type(sender) ~= "string" then return false end
	for i = 1, 4 do
		local name, realm = UnitName("party" .. i)
		name, realm = safe(name), safe(realm)
		if name then
			local full = name .. "-" .. ((realm and realm ~= "" and realm) or GetRealmName()):gsub("%s+", "")
			if sender == full or (sender == name and (not realm or realm == "")) then return true end
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
		"GetNumAvailableQuests", "GetAvailableQuestInfo", "GetNumActiveQuests", "GetActiveQuestID", "issecretvalue", "PlaySoundFile",
		"UnitUsesAmmo" }) do g(n) end -- UnitUsesAmmo: new in 70170
	for _, pair in ipairs({
		{ "C_Map", "GetBestMapForUnit" }, { "C_Map", "GetPlayerMapPosition" }, { "C_Map", "GetWorldPosFromMapPos" }, { "C_Map", "GetMapInfo" },
		{ "C_Map", "GetMapWorldSize" }, { "C_Map", "CanSetUserWaypointOnMap" }, { "C_Map", "SetUserWaypoint" },
		{ "C_QuestLog", "GetNumQuestLogEntries" }, { "C_QuestLog", "GetInfo" }, { "C_QuestLog", "GetQuestObjectives" },
		{ "C_QuestLog", "ReadyForTurnIn" }, { "C_QuestLog", "IsComplete" }, { "C_QuestLog", "GetQuestsOnMap" },
		{ "C_QuestLog", "GetNextWaypoint" }, { "C_QuestLog", "GetDistanceSqToQuest" }, { "C_QuestLog", "GetAllCompletedQuestIDs" },
		{ "C_QuestLog", "GetLogIndexForQuestID" }, { "C_QuestLog", "GetTitleForQuestID" },
		{ "C_GossipInfo", "GetAvailableQuests" }, { "C_GossipInfo", "GetActiveQuests" }, { "C_GossipInfo", "GetOptions" },
		{ "C_Item", "GetItemInfo" }, { "C_Item", "GetItemCount" }, { "C_Container", "GetItemCooldown" }, { "C_Spell", "GetItemCooldown" },
		{ "C_MerchantFrame", "GetItemInfo" }, { "C_TaxiMap", "GetAllTaxiNodes" }, { "C_Minimap", "GetViewRadius" },
		{ "C_TradeSkillUI", "GetChildProfessionInfo" }, { "C_TradeSkillUI", "GetAllRecipeIDs" }, { "C_TradeSkillUI", "GetFilteredRecipeIDs" },
		{ "C_TradeSkillUI", "GetRecipeInfo" }, { "C_TradeSkillUI", "GetRecipeSchematic" }, { "C_SkillInfo", "GetSkillLineInfo" },
		{ "C_ChatInfo", "SendAddonMessage" }, { "C_Spell", "GetSpellName" }, { "C_Timer", "After" }, { "C_Timer", "NewTicker" }, { "C_Texture", "GetAtlasInfo" },
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
	probe("hearth", function() return API.HasHearthstone(), "bind: " .. tostring(API.GetBindLocation()) end)
	probe("secretUnitName", function() return true, FP.issecret(UnitName("player")) and "player name is secret" or "player name readable" end)
	local unavailable = {}
	for ev in pairs(FP.unavailableEvents) do unavailable[#unavailable + 1] = ev end
	row("probe:unavailableEvents", #unavailable == 0, table.concat(unavailable, ", "))
	return rows
end

function API.StoreCheck(rows, manual)
	local result = { t = U.Now(), build = FP.clientBuild, version = FP.version, ok = 0, fail = 0, rows = {} }
	for _, r in ipairs(rows) do
		result.rows[r.name] = { ok = r.ok, note = r.note, status = r.status or (r.ok and "ok" or "unavailable") }
		if r.ok then result.ok = result.ok + 1 else result.fail = result.fail + 1 end
	end
	FP.db.apicheck[tostring(FP.clientBuild) .. (manual and "-manual" or "")] = result
	FP.db.apicheckHistory = FP.db.apicheckHistory or {}
	U.Push(FP.db.apicheckHistory, result, 10)
	return result
end
