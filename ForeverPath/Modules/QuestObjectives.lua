-- Known quest sources, matched to live objectives by localized text, never by
-- database row order. The client exposes no entity ID on QuestObjectiveInfo.
local _, FP = ...
local U, API = FP.Util, FP.API
local Q = FP:NewModule("QuestObjectives")
Q.groups, Q.references = {}, {}

local function clean(text)
	return U.Trim((tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(":%s*%d+%s*/%s*%d+%s*$", ""))):lower()
end

local kinds = { monster="Npc", item="Item", object="Object" }
function Q:Match(objective, references)
	local kind, text = kinds[objective.type], clean(objective.text)
	if not kind or text == "" then return nil end
	local match
	for _, ref in ipairs(references or {}) do
		if ref.kind == kind then
			local name, alias = clean(ref.name), clean(ref.text)
			-- Exact localized names/custom labels, plus the common English kill
			-- suffixes. Unknown wording stays unmapped rather than guessing IDs.
			local namedKill = kind == "Npc" and (text == name.." slain" or text == name.." killed" or text == name.." defeated")
			if text == name or (alias ~= "" and text == alias) or namedKill then
				if match then return nil end
				match = ref
			end
		end
	end
	return match
end

function Q:Refresh(force)
	local ready, status = API.QuestDatabaseStatus()
	self.status = status
	local log, signature = API.GetQuestLog(), {tostring(ready), status}
	local live = {}
	for _, quest in ipairs(log) do
		local objs = API.GetQuestObjectives(quest.questID)
		live[quest.questID] = {info=quest, objectives=objs}
		signature[#signature+1] = tostring(quest.questID)..":"..tostring(quest.isComplete)
		for i,o in ipairs(objs) do
			signature[#signature+1] = tostring(i)..":"..tostring(o.text)..":"..tostring(o.type)..":"..tostring(o.finished)..":"..tostring(o.numFulfilled)..":"..tostring(o.numRequired)
		end
	end
	local key, now = table.concat(signature,"|"), API.Time()
	if not force and key == self.signature and now < (self.expires or 0) then return end
	self.signature, self.expires = key, now + 30
	self.groups, self.references = {}, {} -- only current log; bounded session cache
	self.matched, self.missing = 0, 0
	for _, quest in ipairs(log) do
		if not quest.isComplete then
			local refs = ready and API.GetQuestReference(quest.questID) or nil
			self.references[quest.questID] = refs
			for i,o in ipairs(live[quest.questID].objectives) do
				if not o.finished then
					local ref = self:Match(o, refs)
					if ref and #ref.points > 0 then
						self.matched = self.matched + 1
						self.groups[#self.groups+1] = {questID=quest.questID, objIndex=i, title=quest.title,
							text=o.text, name=ref.name, kind=ref.kind, points=ref.points}
					else self.missing = self.missing + 1 end
				end
			end
		end
	end
	-- A clicked source is a manual destination until its objective ends.
	for i=#FP.Waypoints.list,1,-1 do
		local wp = FP.Waypoints.list[i]
		local s = wp.source
		if s and s.type == "quest-location" then
			local q = live[s.questID]
			local o = q and q.objectives[s.objIndex]
			if not q or q.info.isComplete or (o and o.finished) then FP.Waypoints:Remove(wp.id) end
		end
	end
	self.worldCache = {}
	FP.db.questLocations = {at=now, version=FP.version, status=status, matched=self.matched, missing=self.missing}
	FP:Fire("QUEST_LOCATIONS_CHANGED")
end

function Q:VisibleGroups()
	local selected = API.GetSelectedQuest()
	local out = {}
	for _, group in ipairs(self.groups) do
		if not FP.settings.questSelectedOnly or group.questID == selected then out[#out+1] = group end
	end
	return out
end

function Q:Summary()
	return (self.status or "Quest locations: waiting for login.") .. "\n" .. tostring(self.matched or 0) ..
		" unfinished objectives mapped; " .. tostring(self.missing or 0) .. " without matched locations."
end

function Q:Nearest(questID, index)
	local best, distance
	for _, group in ipairs(self.groups) do
		if group.questID == questID and group.objIndex == index then
			for _, p in ipairs(group.points) do
				local d = FP.Pos:DistanceTo(p)
				if d and (not distance or d < distance) then best, distance = p, d end
			end
		end
	end
	return best
end

function Q:Guide(pin)
	local entry = pin.entries[1]
	if not entry then return end
	FP.Waypoints:RemoveBySource("quest-location")
	FP.Waypoints:Add(pin.mapID, pin.x, pin.y, entry.point.name .. " — " .. entry.group.name, {
		source={type="quest-location", questID=entry.group.questID, objIndex=entry.group.objIndex},
		desc=entry.group.title .. ": known location; search nearby. Spawns and drops are not guaranteed.", radius=20})
end

function Q:Tooltip(pin, owner)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine("ForeverPath: quest locations", 1, .82, 0)
	for i,entry in ipairs(pin.entries) do
		if i > 8 then GameTooltip:AddLine("More objectives share this area…", .7,.7,.7); break end
		local p,g = entry.point,entry.group
		GameTooltip:AddLine(p.name .. (p.role == "vendor" and " (vendor)" or ""), 1,1,1)
		GameTooltip:AddLine(tostring(g.title) .. " — " .. tostring(g.text), .8,.8,.8,true)
	end
	GameTooltip:AddLine("Known locations; not a live creature scan. Drops are not guaranteed.", .6,.8,1,true)
	GameTooltip:AddLine(U.FormatCoords(pin.x,pin.y) .. " · Click: guide here", .6,.8,1)
	GameTooltip:Show()
end

-- Merge close source points into small area markers. Round-robin through each
-- objective before applying the frame budget so a large spawn list cannot starve
-- other quests. Keep all source points for nearest guidance/minimap distance.
function Q:WorldPins(mapID)
	local selected = API.GetSelectedQuest()
	local cacheKey = tostring(mapID)..":"..tostring(FP.settings.questSelectedOnly)..":"..tostring(selected)
	self.worldCache = self.worldCache or {}
	if self.worldCache[cacheKey] then return self.worldCache[cacheKey] end
	local queues = {}
	for _,g in ipairs(self:VisibleGroups()) do
		local points, seen = {}, {}
		for _,p in ipairs(g.points) do
			if p.mapID == mapID then
				local key = math.floor(p.x*125)..":"..math.floor(p.y*125)..":"..p.entityID..":"..p.role
				if not seen[key] then points[#points+1] = p; seen[key] = true end
			end
		end
		queues[#queues+1] = {group=g, points=points}
	end
	local out, cells, index, more = {}, {}, 1, true
	while more do
		more = false
		for _,queue in ipairs(queues) do
			local p = queue.points[index]
			if p then
				more = true
				local key = math.floor(p.x*125)..":"..math.floor(p.y*125)
				local pin = cells[key]
				if not pin and #out < 350 then
					pin={mapID=mapID,x=p.x,y=p.y,entries={}}
					out[#out+1], cells[key] = pin, pin
				end
				if pin then pin.entries[#pin.entries+1] = {point=p,group=queue.group} end
			end
		end
		index = index+1
	end
	self.worldCache[cacheKey] = out
	return out
end

function Q:OnEnable()
	FP:On("QUESTLOG_SCANNED", function() FP.Throttle("quest-locations", .3, function() self:Refresh() end) end)
	FP:RegisterEvent("SUPER_TRACKING_CHANGED", function() FP:Fire("QUEST_LOCATIONS_CHANGED") end)
	FP:On("DISPLAY_SETTINGS_CHANGED", function() FP:Fire("QUEST_LOCATIONS_CHANGED") end)
	FP.After(2, function() self:Refresh(true) end)
	if C_Timer and C_Timer.NewTicker then
		self.ticker=C_Timer.NewTicker(3, function() FP.pcall("quest-locations", self.Refresh, self) end)
	end
end
