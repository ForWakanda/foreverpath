-- Known quest sources, matched to live objectives by localized text, never by
-- database row order. The client exposes no entity ID on QuestObjectiveInfo.
local _, FP = ...
local U, API = FP.Util, FP.API
local Q = FP:NewModule("QuestObjectives")
Q.groups, Q.references = {}, {}

local function clean(text)
	return (U.ObjectiveText(text) or ""):lower()
end

local kinds = { monster="Npc", item="Item", object="Object", event="Event" }
local function compatible(kind,ref)
	return ref.kind==kind or (kind=="Npc" and ref.kind=="Credit")
end
local function objectiveKey(o) return tostring(o.type)..":"..clean(o.text) end
function Q:Match(objective, references, liveObjectives)
	local kind, text = kinds[objective.type], clean(objective.text)
	if not kind or text == "" then return nil end
	local match, candidates, sole = nil,0,nil
	for _,ref in ipairs(references or {}) do
		if compatible(kind,ref) then
			candidates,sole=candidates+1,ref
			local name,alias=clean(ref.name),clean(ref.text)
			local namedKill=kind=="Npc" and (text==name.." slain" or text==name.." killed" or text==name.." defeated")
			if text==name or (alias~="" and text==alias) or namedKill then
				if match then return nil end -- ambiguous labels do not assign progress
				match=ref
			end
		end
	end
	if match then
		if liveObjectives and (match.kind=="Event" or match.kind=="Credit") then
			local duplicates=0
			for _,o in ipairs(liveObjectives) do if objectiveKey(o)==objectiveKey(objective) then duplicates=duplicates+1 end end
			if duplicates~=1 then return nil end
		end
		return match
	end
	-- Event text and credit-dummy labels can differ from the live text. Bind by
	-- type only when BOTH complete lists have exactly one candidate, including
	-- finished rows. Never pick the sole *unfinished* row or rely on row order.
	if candidates==1 and (sole.kind=="Event" or sole.kind=="Credit") and liveObjectives then
		local count=0
		for _,o in ipairs(liveObjectives) do if kinds[o.type]==kind then count=count+1 end end
		if count==1 then return sole end
	end
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
	local previous=self.references
 self.groups,self.references={},{} -- only current log; bounded session cache
	self.matched, self.missing, self.events, self.hints = 0, 0, 0, 0
	for _, quest in ipairs(log) do
		if not quest.isComplete then
			local refs = ready and ((not force and previous[quest.questID]) or API.GetQuestReference(quest.questID)) or nil
			self.references[quest.questID] = refs
			for i,o in ipairs(live[quest.questID].objectives) do
				if not o.finished then
					local ref = self:Match(o, refs, live[quest.questID].objectives)
					if ref and (ref.kind=="Event" or ref.kind=="Credit") and o.finished~=false then ref=nil end
					if ref and #ref.points > 0 then
						self.matched = self.matched + 1
						if ref.kind=="Event" or ref.kind=="Credit" then self.events=self.events+1 end
						self.groups[#self.groups+1] = {questID=quest.questID, objIndex=i, title=quest.title,
							text=o.text, name=ref.name, kind=ref.kind, points=ref.points, refKey=ref.key, objectiveKey=objectiveKey(o)}
					else self.missing = self.missing + 1 end
				end
			end
			for _,ref in ipairs(refs or {}) do
				if ref.kind=="Hint" and #ref.points>0 then
					self.hints=self.hints+1
					self.groups[#self.groups+1]={questID=quest.questID,title=quest.title,text=ref.text,
						name=ref.name,kind="Hint",points=ref.points,refKey=ref.key}
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
			if s.refKey then
				local current
				for _,g in ipairs(self.groups) do
					if g.questID==s.questID and g.refKey==s.refKey and g.objectiveKey==s.objectiveKey then current=g;break end
				end
				if current then s.objIndex=current.objIndex
    elseif not q or q.info.isComplete then FP.Waypoints:Remove(wp.id)
    else
     local o=q.objectives[s.objIndex or 1]
     -- Uncached accept/login labels cannot disprove a persisted destination.
     if o and (o.finished or (ready and U.ObjectiveText(o.text))) then FP.Waypoints:Remove(wp.id) end
    end
			else
				local o=q and q.objectives[s.objIndex]
				if not q or q.info.isComplete or not o or o.finished then FP.Waypoints:Remove(wp.id) end
			end
		end
	end
	self.worldCache = {}
	FP.db.questLocations = {at=now, version=FP.version, status=status, matched=self.matched, missing=self.missing, events=self.events, hints=self.hints}
	FP:Fire("QUEST_LOCATIONS_CHANGED")
end

function Q:VisibleGroups()
	local selected = API.GetSelectedQuest()
	local out = {}
	for _, group in ipairs(self.groups) do
		if (not FP.settings.questSelectedOnly or group.questID==selected) and (group.kind~="Hint" or FP.settings.questEventHints~=false) then out[#out+1]=group end
	end
	return out
end

function Q:Summary()
	return (self.status or "Quest locations: waiting for login.") .. "\n" .. tostring(self.matched or 0) ..
		" unfinished objectives mapped; " .. tostring(self.missing or 0) .. " without matched locations.\n" .. tostring(self.events or 0) .. " event/credit objectives; " .. tostring(self.hints or 0) .. " quest hints (separate from progress)."
end

function Q:Nearest(questID, index)
	local best, distance
	for _, group in ipairs(self.groups) do
		if group.kind~="Hint" and group.questID == questID and group.objIndex == index then
			for _, p in ipairs(group.points) do
				local d = FP.Pos:DistanceTo(p) or math.huge
				if (not p.entrance or not API.InInstance()) and d and (not distance or d < distance) then best, distance = p, d end
			end
		end
	end
	return best
end

function Q:Guide(pin)
	-- A pooled pin can outlive a quest update; revalidate before making a route.
	self:Refresh()
	local entry
	for _,candidate in ipairs(pin.entries or {}) do
		for _,g in ipairs(self:VisibleGroups()) do
			local old=candidate.group
			if g.questID==old.questID and g.refKey==old.refKey and g.objectiveKey==old.objectiveKey then
				for _,p in ipairs(g.points) do
					local oldPoint=candidate.point.original or candidate.point
					if p.mapID==oldPoint.mapID and p.x==oldPoint.x and p.y==oldPoint.y and p.entityID==oldPoint.entityID and p.role==oldPoint.role then
						entry={group=g,point=p};break
					end
				end
			end
			if entry then break end
		end
		if entry then break end
	end
	if not entry then return false end
	local g,p=entry.group,entry.point
	if p.entrance and API.InInstance() then return false end
	local note="Known location; search nearby. Spawns and drops are not guaranteed."
	if g.kind=="Event" then note="Event completion area; follow the quest instructions. Arrival alone does not complete an event or escort."
	elseif g.kind=="Credit" then note="Possible quest-credit targets; follow the quest instructions for the required action."
	elseif g.kind=="Hint" then note="Quest-level hint; individual objective progress is not tracked for this marker." end
	if p.entrance then note="Outdoor entrance to "..p.dungeonName.."; continue inside following the quest instructions. Interior paths are not mapped." end
	FP.Waypoints:RemoveBySource("quest-location")
	local title=g.kind=="Event" and ("Event: "..g.name) or ((g.kind=="Hint" and "Hint: " or "")..p.name.." — "..g.name)
	if p.entrance then title="Entrance: "..p.dungeonName.." — "..g.name end
	FP.Waypoints:Add(p.mapID,p.x,p.y,title,{
		source={type="quest-location",questID=g.questID,objIndex=g.objIndex,refKey=g.refKey,objectiveKey=g.objectiveKey,entrance=p.entrance},
		desc=g.title..": "..note,radius=20})
	return true
end

function Q:Tooltip(pin, owner)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Hearth & Hustle: quest locations", 1, .82, 0)
	for i,entry in ipairs(pin.entries) do
		if i > 8 then GameTooltip:AddLine("More objectives share this area…", .7,.7,.7); break end
		local p,g = entry.point,entry.group
		local label=g.kind=="Event" and "Event completion area" or g.kind=="Hint" and "Quest hint" or g.kind=="Credit" and "Possible quest-credit target" or nil
		if p.entrance then label="Dungeon entrance: "..p.dungeonName end
		GameTooltip:AddLine((label and (label..": ") or "")..p.name..(p.role=="vendor" and " (vendor)" or ""),1,1,1)
		if p.entrance then GameTooltip:AddLine("Outdoor approach; the quest target is inside. Interior paths are not mapped.",.7,.8,1,true) end
		if g.kind=="Hint" then GameTooltip:AddLine("Not tied to individual progress; remains until the quest is complete.",.7,.8,1,true)
		elseif g.kind=="Event" then GameTooltip:AddLine("Follow the quest instructions; this is not an escort route or proof of completion.",.7,.8,1,true) end
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
	local cacheKey = tostring(mapID)..":"..tostring(FP.settings.questSelectedOnly)..":"..tostring(selected)..":"..tostring(FP.settings.questEventHints)
	self.worldCache = self.worldCache or {}
	if self.worldCache[cacheKey] then return self.worldCache[cacheKey] end
	local queues = {}
	for _,g in ipairs(self:VisibleGroups()) do
		local points, seen = {}, {}
		for _,p in ipairs(g.points) do
			local shown=p
   local targetInfo,sourceInfo=API.GetMapInfo(mapID),API.GetMapInfo(p.mapID)
   if p.mapID~=mapID and ((targetInfo and targetInfo.parentMapID==p.mapID) or (sourceInfo and sourceInfo.parentMapID==mapID)) then
    local cont,wx,wy=FP.Pos:WorldOf(p)
    local id,x,y
    if cont and wx and wy then id,x,y=API.GetMapPosFromWorld(cont,wx,wy,mapID) end
    if id==mapID and U.ValidMapPoint(id,x,y) then shown=U.Copy(p);shown.mapID,shown.x,shown.y=mapID,x,y;shown.original=p end
   end
   if shown.mapID == mapID then
    local p=shown
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
