-- ForeverPath / Route / Planner.lua
-- Phase 1 planner: turns the live quest log into an ordered "next steps" list
-- using Blizzard's quest POIs/waypoints first and our recorded data second.
-- Phase 4 replaces the scoring with the quest graph + XP/time model.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local P = FP:NewModule("Planner")

P.steps = {}
-- Arrival is a navigation state, independent of the displayed waypoint.
local function sameStep(a, b)
	return a and b and a.questID == b.questID and a.kind == b.kind and a.objIndex == b.objIndex
end

function P:WaitingValid()
	local s = self.waiting
	if not s or not API.IsOnQuest(s.questID) then return false end
	-- Stay put while working in the area, but recover if the player walks away.
	local d = s.mapID and FP.Pos:DistanceTo(s)
	if d and d > math.max(100, (s.radius or 35) * 3) then return false end
	if s.kind == "turnin" then return API.IsQuestComplete(s.questID) end
	if API.IsQuestComplete(s.questID) then return false end
	local o = API.GetQuestObjectives(s.questID)[s.objIndex or 1]
	return o == nil or not o.finished
end

local function centroidOnMap(points)
	if not points or #points == 0 then return nil end
	local byMap = {}
	for _, p in ipairs(points) do
		byMap[p.m] = byMap[p.m] or {}
		table.insert(byMap[p.m], p)
	end
	local bestMap, bestList
	for m, list in pairs(byMap) do
		if not bestList or #list > #bestList then bestMap, bestList = m, list end
	end
	local x, y = U.Centroid(bestList)
	return bestMap, x, y
end

local function poiFor(questID, mapID, wantStart)
	if not mapID then return nil end
	for _, poi in ipairs(API.GetQuestsOnMap(mapID)) do
		if poi.questID == questID and ((wantStart and poi.isQuestStart) or (not wantStart and not poi.isQuestStart)) then
			return mapID, poi.x, poi.y
		end
	end
	return nil
end

function P:ResolveTurnIn(questID)
	local q = FP.data.quests[questID]
	if q and q.epos then return q.epos.m, q.epos.x, q.epos.y, "recorded" end
	if q then
		for npcID in pairs(q.enders) do
			local n = FP.data.npcs[npcID]
			if n and n.pos[1] then return n.pos[1].m, n.pos[1].x, n.pos[1].y, "npc" end
		end
	end
	local m, x, y = poiFor(questID, API.GetBestMap(), false)
	if m then return m, x, y, "poi" end
	m, x, y = API.GetQuestNextWaypoint(questID)
	if m then return m, x, y, "waypoint" end
	if q and q.gpos then return q.gpos.m, q.gpos.x, q.gpos.y, "giver" end
	if q then
		for npcID in pairs(q.givers) do
			local n = FP.data.npcs[npcID]
			if n and n.pos[1] then return n.pos[1].m, n.pos[1].x, n.pos[1].y, "giver-npc" end
		end
	end
	return nil
end

function P:ResolveObjective(questID, i)
	local m, x, y = API.GetQuestNextWaypoint(questID)
	if m then return m, x, y, "waypoint" end
	m, x, y = poiFor(questID, API.GetBestMap(), false)
	if m then return m, x, y, "poi" end
	local q = FP.data.quests[questID]
	local ob = q and q.obj and q.obj[i]
	if ob and ob.pos and #ob.pos > 0 then
		local cm, cx, cy = centroidOnMap(ob.pos)
		if cm then return cm, cx, cy, "observed area (approximate)" end
	end
	if ob and ob.mobs then
		local pts = {}
		for mobID in pairs(ob.mobs) do
			local c = FP.data.creatures[mobID]
			if c then for _, p in ipairs(c.pos) do pts[#pts + 1] = p end end
		end
		local cm, cx, cy = centroidOnMap(pts)
		if cm then return cm, cx, cy, "mobs" end
	end
	return nil
end

-- "Quilboar slain: 3/8" -> "Quilboar slain" (progress is shown separately)
local function cleanObjectiveText(text)
	if type(text) ~= "string" or text == "" then return "objective" end
	return (text:gsub(":%s*%d+%s*/%s*%d+%s*$", ""))
end

function P:Build()
	local steps = {}
	local log = API.GetQuestLog()
	local party = FP.cdb.party and FP.cdb.party.quests or nil
	local now = API.Time()
	for _, info in ipairs(log) do
		local qid = info.questID
		local shared = party and party[qid] and true or false
		if info.isComplete then
			local m, x, y, how = self:ResolveTurnIn(qid)
			steps[#steps + 1] = { kind = "turnin", questID = qid, title = "Turn in: " .. tostring(info.title), text = info.title, mapID = m, x = x, y = y, how = how, shared = shared, radius = 12 }
		else
			local objs = API.GetQuestObjectives(qid)
			local added = false
			for i, o in ipairs(objs) do
				if not o.finished then
					local m, x, y, how = self:ResolveObjective(qid, i)
					steps[#steps + 1] = { kind = "objective", questID = qid, objIndex = i, title = tostring(info.title), text = cleanObjectiveText(o.text), mapID = m, x = x, y = y, how = how, shared = shared, radius = 35, progress = (o.numRequired and o.numRequired > 0) and (tostring(o.numFulfilled or 0) .. "/" .. o.numRequired) or nil }
					added = true
				end
			end
			if not added and #objs == 0 then
				local m, x, y, how = self:ResolveObjective(qid, 1)
				steps[#steps + 1] = { kind = "objective", questID = qid, objIndex = 1, title = tostring(info.title), text = "go there", mapID = m, x = x, y = y, how = how, shared = shared, radius = 35 }
			end
		end
	end
	-- distance + score
	for _, s in ipairs(steps) do
		if s.mapID and s.x then
			local d, _, sameCont = FP.Pos:VectorTo(s)
			s.dist = d
			if d then
				s.score = d
			elseif sameCont == false then
				s.score = 5e8
			else
				s.score = 8e8
			end
		else
			s.score = 1e9
		end
		if s.kind == "turnin" then s.score = s.score - 250 end
		if s.shared then s.score = s.score - 150 end
	end
	table.sort(steps, function(a, b)
		if a.score ~= b.score then return a.score < b.score end
		return tostring(a.title) < tostring(b.title)
	end)
	-- hearth hint: several turn-ins near the bind point and hearth ready
	local bind = FP.cdb.bind
	if bind and bind.m and bind.x and API.HasHearthstone() then
		local near = 0
		for _, s in ipairs(steps) do
			if s.kind == "turnin" and s.mapID == bind.m and s.x then
				local d = FP.Pos:MapDistance(bind.m, bind.x, bind.y, s.x, s.y)
				if d and d < 400 then near = near + 1 end
			end
		end
		local hereD = FP.Pos:DistanceTo({ mapID = bind.m, x = bind.x, y = bind.y })
		if near >= 2 and (not hereD or hereD > 1500) then
			local cd = API.GetHearthCooldown()
			table.insert(steps, 1, { kind = "hearth", title = "Hearth to " .. tostring(bind.area or "bind point"), text = near .. " turn-ins near your inn" .. (cd > 0 and (" (ready in " .. U.FormatTime(cd) .. ")") or ""), mapID = bind.m, x = bind.x, y = bind.y, score = -1e6, radius = 30 })
		end
	end
	self.steps = steps
	self.builtAt = now
	FP:Fire("PLAN_UPDATED", steps)
	return steps
end

function P:NextStep()
	for _, s in ipairs(self.steps) do
		if s.kind ~= "hearth" and not sameStep(s, self.waiting) and s.mapID and s.x and s.dist then return s end
	end
	for _, s in ipairs(self.steps) do
		if s.kind ~= "hearth" and not sameStep(s, self.waiting) and s.mapID and s.x then return s end
	end
	return nil
end

function P:Go(step, automatic)
	if not step or not U.ValidMapPoint(step.mapID, step.x, step.y) then return nil end
	self.waiting, self.paused = nil, nil
	self.pinned = not automatic
	FP.Waypoints:RemoveBySource("plan")
	local title = step.kind == "turnin" and step.title or (step.text .. (step.progress and (" " .. step.progress) or ""))
	local wp = FP.Waypoints:Add(step.mapID, step.x, step.y, title, {
		source = { type = "plan", kind = step.kind, questID = step.questID, objIndex = step.objIndex },
		radius = step.radius, desc = step.kind == "turnin" and ("Quest: " .. tostring(step.text)) or ("Quest: " .. tostring(step.title) .. "  (" .. tostring(step.how) .. ")"),
	})
	self.current = step
	return wp
end

function P:Auto(reason)
	if API.InBattleground() then
		FP.Waypoints:RemoveBySource("plan")
		self.waiting = nil
		return
	end
	if not FP.settings.autoNext or self.paused then return end
	FP.Pos:Refresh(true)
	self:Build()
	local active = FP.Waypoints:GetActive()
	if active and (not active.source or active.source.type ~= "plan") then return end
	if self:WaitingValid() then return end
	self.waiting = nil
	local s = self:NextStep()
	local current
	if active then
		for _, step in ipairs(self.steps) do
			if sameStep(step, active.source) then current = step; break end
		end
	end
	-- Keep explicit selections until completed; automatic choices need a meaningful
	-- improvement before switching, so neighboring POIs do not make the arrow flap.
	if current and current.mapID and current.x then
		if self.pinned or (s and current.dist and s.dist and current.score <= s.score + 75) then s = current end
	end
	if s then
		if active and sameStep(active.source, s) then
			-- POIs can move and objective counts change without a new quest ID.
			active.mapID, active.x, active.y = s.mapID, s.x, s.y
			active.title = s.kind == "turnin" and s.title or (s.text .. (s.progress and (" " .. s.progress) or ""))
			self.current = s
			FP:Fire("WAYPOINTS_CHANGED")
			return
		end
		self:Go(s, true)
		FP:Print(FP.GOLD .. "Next:|r " .. (s.kind == "turnin" and s.title or (s.text .. " — " .. s.title)) .. (s.dist and (" " .. FP.GREY .. U.FormatDistance(s.dist) .. "|r") or ""))
	elseif active and active.source and active.source.type == "plan" then
		FP.Waypoints:RemoveBySource("plan")
	end
end

function P:OnEnable()
	FP:On("QUESTLOG_SCANNED", function() FP.Throttle("plan-check", 1, function() P:CheckActive() end) end)
	FP:On("QUEST_TURNED_IN", function() FP.After(1.5, function() P:Auto("turnin") end) end)
	FP:On("QUEST_ACCEPTED", function() FP.After(1.5, function() P:Auto("accept") end) end)
	FP:On("QUEST_REMOVED", function() FP.After(1, function() P:Auto("removed") end) end)
	FP:On("PARTY_UPDATED", function() P:Build() end)
	FP:On("NAV_CANCELLED", function() self.waiting, self.pinned, self.paused = nil, nil, true end)
	FP:On("WAYPOINT_ARRIVED", function(wp)
		if wp.source and wp.source.type == "plan" then
			self.waiting = U.Copy(wp.source)
			self.waiting.mapID, self.waiting.x, self.waiting.y, self.waiting.radius = wp.mapID, wp.x, wp.y, wp.radius
			self.waiting.title = wp.title
			self.pinned = nil
			if wp.source.kind == "objective" then
				FP:Print(FP.GREY .. "You're in the objective area. The arrow resumes when you finish or leave the area; /fp next to skip.|r")
			end
		end
	end)
	FP.After(8, function() P:Auto("login") end)
	-- Independent of the arrow/panel position ticker: arrival removes the last
	-- waypoint, and a hidden panel must not stop automatic navigation.
	if C_Timer and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(3, function() FP.pcall("auto-route", P.Auto, P, "position") end)
	end
	FP:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() FP.After(1, function() P:Auto("zone") end) end)
end

-- Re-plan when the active planned waypoint no longer makes sense.
function P:CheckActive()
	if self.waiting then
		if self:WaitingValid() then return end
		self.waiting = nil
		self:Auto("completed-after-arrival")
		return
	end
	local active = FP.Waypoints:GetActive()
	if not active then self:Auto("idle"); return end
	if not active.source or active.source.type ~= "plan" then return end
	local s = active.source
	local invalid = false
	if not API.IsOnQuest(s.questID) then
		invalid = true
	elseif s.kind == "objective" then
		if API.IsQuestComplete(s.questID) then
			invalid = true
		else
			local objs = API.GetQuestObjectives(s.questID)
			local o = objs[s.objIndex or 1]
			if o and o.finished then invalid = true end
		end
	elseif s.kind == "turnin" then
		invalid = not API.IsQuestComplete(s.questID)
	end
	if invalid then
		FP.Waypoints:RemoveBySource("plan")
		self:Auto("check")
	end
end

function P:Describe(step)
	local d = step.dist and U.FormatDistance(step.dist) or (step.mapID and FP.GREY .. "far|r" or FP.GREY .. "?|r")
	local label
	if step.kind == "turnin" then label = FP.GOLD .. step.title .. "|r"
	elseif step.kind == "hearth" then label = FP.GREEN .. step.title .. "|r " .. FP.GREY .. step.text .. "|r"
	else label = step.text .. (step.progress and (" " .. FP.GREY .. step.progress .. "|r") or "") .. FP.GREY .. " — " .. U.Truncate(step.title, 28) .. "|r" end
	if step.shared then label = "★ " .. label end
	return d, label
end
