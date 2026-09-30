-- ForeverPath / Data / Recorder.lua
-- Telemetry: records what the Forever client tells the addon while you play.
-- Read-only observation of permitted API data; nothing here performs actions.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local safe = FP.safe
local R = FP:NewModule("Recorder")

local MAX_POS_PER_NPC = 3
local MAX_POS_PER_CREATURE = 40
local MAX_POS_PER_OBJECT = 60
local MAX_PROGRESS = 4000
local MAX_DEATHS = 200
local MAX_XP_SAMPLES = 2000
local DEDUP_YARDS = 25

local data           -- FP.data
local counters       -- FP.db.meta.counters
local char           -- character key
local lastNPC        -- { id, name, guid, pos, t }
local lastKills = {} -- ring of { id, name, guid, pos, t }
local lastLoot       -- { sources = candidate identities, items = {itemID -> qty}, pos, t }
local objectiveSnapshot = {}  -- questID -> { [i] = numFulfilled }
local recentTurnIn   -- { questID, npcID, t }
local seenLootGUID -- persisted per character so /reload does not recount a corpse
local lastXPSample = 0

local function bump(k)
	counters[k] = (counters[k] or 0) + 1
end

local function recording()
	return FP.settings.record and data ~= nil
end

local function pos(source)
	local p = FP.Pos:Snapshot()
	if p then p.observer, p.source = true, source or "player" end
	return p
end

local function samePlace(a, b)
	if not a or not b or a.m ~= b.m then return false end
	local d = FP.Pos:MapDistance(a.m, a.x, a.y, b.x, b.y)
	if d then return d <= DEDUP_YARDS end
	return math.abs(a.x - b.x) < 0.003 and math.abs(a.y - b.y) < 0.003
end

local function addPos(list, p, max)
	if not p then return end
	for _, q in ipairs(list) do
		if samePlace(p, q) then return end
	end
	U.Push(list, U.Copy(p), max)
end

-------------------------------------------------------------------------------
-- Entities
-------------------------------------------------------------------------------
local function npc(id, name, p, flag)
	if not id then return nil end
	local n = data.npcs[id]
	if not n then
		n = { pos = {}, flags = {}, first = U.Now() }
		data.npcs[id] = n
		bump("npcs")
	end
	if name and not FP.issecret(name) then n.n = name end
	if p then
		addPos(n.pos, p, MAX_POS_PER_NPC)
		if p.z then n.zone = p.z end
	end
	if flag then n.flags[flag] = true end
	n.last = U.Now()
	return n
end

local function creature(id, info, p)
	if not id then return nil end
	local c = data.creatures[id]
	if not c then
		c = { pos = {}, kills = 0, loot = {}, first = U.Now() }
		data.creatures[id] = c
		bump("creatures")
	end
	if info then
		if info.name and not FP.issecret(info.name) then c.n = info.name end
		if type(info.level) == "number" and info.level > 0 then
			c.lmin = math.min(c.lmin or info.level, info.level)
			c.lmax = math.max(c.lmax or info.level, info.level)
		end
		if info.classification and info.classification ~= "normal" then c.cls = info.classification end
		if info.creatureType then c.type = info.creatureType end
		if info.reaction then c.react = info.reaction end
	end
	if p then
		addPos(c.pos, p, MAX_POS_PER_CREATURE)
		if p.z then c.zone = p.z end
	end
	return c
end

local function gameobject(id, p)
	if not id then return nil end
	local o = data.objects[id]
	if not o then
		o = { pos = {}, loot = {}, count = 0, first = U.Now() }
		data.objects[id] = o
		bump("objects")
	end
	if p then
		addPos(o.pos, p, MAX_POS_PER_OBJECT)
		if p.z then o.zone = p.z end
	end
	return o
end

local function item(itemID, name, quality)
	if not itemID then return end
	local it = data.items[itemID]
	if not it then
		it = {}
		data.items[itemID] = it
		bump("items")
	end
	if name and not FP.issecret(name) then it.n = name end
	if quality then it.q = quality end
	if not it.n then
		local n = API.GetItemName(itemID)
		if n then it.n = n end
	end
end

local function quest(questID, title)
	if not questID then return nil end
	local q = data.quests[questID]
	if not q then
		q = { givers = {}, enders = {}, xp = {}, first = U.Now() }
		data.quests[questID] = q
		bump("quests")
	end
	if title and not FP.issecret(title) then q.t = title end
	return q
end
R.quest, R.npc, R.creature = quest, npc, creature

-- Capture the NPC we are talking to ("npc" unit is valid during dialogs).
local function captureNPC(flag)
	local info = API.UnitInfo("npc") or API.UnitInfo("questnpc") or API.UnitInfo("target")
	if not info or info.isPlayer or info.kind ~= "Creature" or not info.id then
		lastNPC = nil
		return nil
	end
	local p = pos("npc-interaction")
	local n = npc(info.id, info.name, p, flag)
	if n and info.level then n.lvl = info.level end
	lastNPC = { id = info.id, name = info.name, guid = info.guid, pos = p, t = API.Time() }
	return lastNPC
end

-------------------------------------------------------------------------------
-- Quest log snapshots & objective diffing
-------------------------------------------------------------------------------
local function snapshotQuest(info)
	local q = quest(info.questID, info.title)
	if info.level and info.level > 0 then q.l = info.level end
	if info.difficultyLevel and info.difficultyLevel > 0 then q.dl = info.difficultyLevel end
	if info.suggestedGroup and info.suggestedGroup > 0 then q.sg = info.suggestedGroup end
	if info.header then q.h = info.header end
	if info.isTask then q.task = true end
	local objs = API.GetQuestObjectives(info.questID)
	if #objs > 0 then
		q.obj = q.obj or {}
		for i, o in ipairs(objs) do
			q.obj[i] = q.obj[i] or {}
			if o.text and not FP.issecret(o.text) then
				-- store the text without the progress numbers: "Quilboar slain: 3/8" -> "Quilboar slain"
				q.obj[i].text = (o.text:gsub(":%s*%d+%s*/%s*%d+%s*$", ""))
			end
			q.obj[i].type = o.type
			q.obj[i].req = o.numRequired
		end
	end
	return q
end

local function objectiveSnapshotFor(questID)
	local snap = {}
	for i, o in ipairs(API.GetQuestObjectives(questID)) do
		snap[i] = { n = o.numFulfilled or 0, done = o.finished and true or false }
	end
	return snap
end

local function recordProgress(questID, i, from, to, o)
	local p = pos()
	local ev = { q = questID, o = i, from = from, to = to, t = U.Now(), c = char, type = o and o.type or nil }
	if p then ev.m, ev.x, ev.y = p.m, p.x, p.y end
	local now = API.Time()
	-- Time proximity is a candidate observation, never proof of objective identity.
	if o and o.type == "monster" then
		ev.killCandidates = {}
		local seen = {}
		for _, k in ipairs(lastKills) do
			if now - k.t < 4 and not seen[k.id] then
				ev.killCandidates[#ev.killCandidates + 1] = k.id
				seen[k.id] = true
			end
		end
	end
	if o and o.type == "item" and lastLoot and now - lastLoot.t < 4 then
		ev.lootCandidates = lastLoot.sources
		ev.lootItems = lastLoot.items
	end
	ev.attribution = "unconfirmed"
	ev.observer = true
	U.Push(data.progress, ev, MAX_PROGRESS)
	bump("progress")
	-- Fold the observed progress area into the quest record; identity stays uncertain.
	local q = data.quests[questID]
	if q then
		q.obj = q.obj or {}
		q.obj[i] = q.obj[i] or {}
		local ob = q.obj[i]
		-- Preserve objective-progress locations as approximate areas, not mob positions.
		if p then ob.pos = ob.pos or {}; addPos(ob.pos, p, 30) end
	end
end

local function diffObjectives(questID)
	local old = objectiveSnapshot[questID]
	local objs = API.GetQuestObjectives(questID)
	local new = {}
	for i, o in ipairs(objs) do
		new[i] = { n = o.numFulfilled or 0, done = o.finished and true or false }
		if recording() and old and old[i] and (new[i].n > old[i].n or (new[i].done and not old[i].done and new[i].n == old[i].n)) then
			recordProgress(questID, i, old[i].n, new[i].n, o)
		end
	end
	objectiveSnapshot[questID] = new
end

local function rescanLog(reason)
	local log = API.GetQuestLog()
	local seen = {}
	for _, info in ipairs(log) do
		seen[info.questID] = true
		if not objectiveSnapshot[info.questID] then
			if recording() then snapshotQuest(info) end
			objectiveSnapshot[info.questID] = objectiveSnapshotFor(info.questID)
		else
			diffObjectives(info.questID)
		end
	end
	for questID in pairs(objectiveSnapshot) do
		if not seen[questID] then objectiveSnapshot[questID] = nil end
	end
	FP:Fire("QUESTLOG_SCANNED", log)
end
R.RescanLog = rescanLog

-------------------------------------------------------------------------------
-- Event handlers
-------------------------------------------------------------------------------
function R:OnInit()
	data = FP.data
	counters = FP.db.meta.counters
	FP.cdb.lootSeen = FP.cdb.lootSeen or {}
	seenLootGUID = FP.cdb.lootSeen
end

function R:OnEnable()
	local c = API.GetCharInfo()
	char = c.key
	R.char = char
	if recording() then
		local rec = data.chars[char] or { first = U.Now() }
		data.chars[char] = rec
		rec.class, rec.race, rec.faction, rec.level, rec.last = c.class, c.race, c.faction, c.level, U.Now()
		local done = API.GetCompletedQuests()
		FP.cdb.completed = {}
		for _, id in ipairs(done) do FP.cdb.completed[id] = true end
		rec.completed = #done
	end
	local bind = API.GetBindLocation()
	if bind then FP.cdb.bind.area = bind end

	FP.After(3, function() rescanLog("login") end)

	-- store the API check once per build (positive control for the recorder)
	local buildKey = tostring(FP.clientBuild)
	if not FP.db.apicheck[buildKey] then
		FP.After(6, function()
			local rows = API.Check()
			local out = API.StoreCheck(rows, false)
			FP:Print(string.format("API check stored for build %s: %d ok, %d missing. /fp apicheck to view.", buildKey, out.ok, out.fail))
		end)
	end

	FP:On("RECORDING_CHANGED", function()
		objectiveSnapshot, lastKills, lastLoot = {}, {}, nil
		rescanLog("recording-toggle")
		if recording() then
			local c = API.GetCharInfo()
			data.chars[char] = data.chars[char] or { first = U.Now(), class = c.class, race = c.race, faction = c.faction, level = c.level }
		end
	end)
	local E = FP.RegisterEvent
	-- quests
	E(FP, "QUEST_LOG_UPDATE", function() FP.Throttle("rescan", 0.3, function() rescanLog("update") end) end)
	E(FP, "QUEST_WATCH_UPDATE", function(_, questID) if questID then FP.Throttle("rescan", 0.3, function() rescanLog("watch") end) end end)
	E(FP, "UNIT_QUEST_LOG_CHANGED", function(_, unit) if unit == "player" then FP.Throttle("rescan", 0.3, function() rescanLog("unit") end) end end)
	E(FP, "GOSSIP_SHOW", function() if recording() then R:OnGossip() end end)
	E(FP, "QUEST_GREETING", function() if recording() then R:OnGossip() end end)
	E(FP, "QUEST_DETAIL", function(_, startItemID) if recording() then R:OnQuestDetail(startItemID) end end)
	E(FP, "QUEST_PROGRESS", function() if recording() then captureNPC("quest") end end)
	E(FP, "QUEST_COMPLETE", function() if recording() then R:OnQuestComplete() end end)
	E(FP, "QUEST_ACCEPTED", function(_, a, b)
		local id = type(b) == "number" and b or a
		R:OnQuestAccepted(id)
		FP:Fire("QUEST_ACCEPTED", id)
	end)
	E(FP, "QUEST_TURNED_IN", function(_, questID, xp, money)
		R:OnQuestTurnedIn(questID, xp, money)
		FP:Fire("QUEST_TURNED_IN", questID, xp)
	end)
	E(FP, "QUEST_REMOVED", function(_, questID)
		R:OnQuestRemoved(questID)
		FP:Fire("QUEST_REMOVED", questID)
	end)
	E(FP, "UI_INFO_MESSAGE", function(_, _, msg) if recording() then R:OnInfoMessage(msg) end end)
	-- units
	E(FP, "PLAYER_TARGET_CHANGED", function() if recording() then R:OnUnit("target") end end)
	E(FP, "UPDATE_MOUSEOVER_UNIT", function() if recording() then R:OnUnit("mouseover") end end)
	E(FP, "PLAYER_TARGET_DIED", function() if recording() then R:OnTargetDied() end end)
	E(FP, "UNIT_DIED", function(_, guid) if recording() then R:OnUnitDied(guid) end end)
	E(FP, "PARTY_KILL", function(_, attacker, target) if recording() then R:OnUnitDied(target) end end)
	-- loot / vendors / trainers / taxi / inn
	E(FP, "LOOT_OPENED", function() if recording() then R:OnLoot() end end)
	E(FP, "MERCHANT_SHOW", function() if recording() then R:OnMerchant() end end)
	E(FP, "TRAINER_SHOW", function() if recording() then FP.After(0.5, function() R:OnTrainer() end) end end)
	E(FP, "TRAINER_UPDATE", function() if recording() then FP.Throttle("trainer", 1, function() R:OnTrainer() end) end end)
	E(FP, "TAXIMAP_OPENED", function() if recording() then R:OnTaxi() end end)
	E(FP, "CONFIRM_BINDER", function(_, area) if recording() then R:OnBinder(area) end end)
	E(FP, "HEARTHSTONE_BOUND", function() R:OnBound() end)
	-- character
	E(FP, "PLAYER_XP_UPDATE", function() if recording() then R:OnXP() end end)
	E(FP, "CHAT_MSG_COMBAT_XP_GAIN", function(_, text) if recording() then R:OnXPMessage(text) end end)
	E(FP, "PLAYER_LEVEL_UP", function(_, level) R:OnLevelUp(level); FP:Fire("LEVEL_UP", level) end)
	E(FP, "PLAYER_DEAD", function() if recording() then R:OnDeath() end end)
	E(FP, "ZONE_CHANGED_NEW_AREA", function() if recording() then R:OnZone() end end)
	E(FP, "PLAYER_ENTERING_WORLD", function() if recording() then FP.After(2, function() R:OnZone() end) end end)
end

function R:OnGossip()
	local n = captureNPC("quest")
	local available, active = API.GetNPCQuests()
	local p = n and n.pos or pos()
	for _, q in ipairs(available) do
		if q.questID then
			local rec = quest(q.questID, q.title)
			if q.level then rec.l = q.level end
			if q.repeatable then rec.rep = true end
			if n then
				rec.givers[n.id] = true
				if p then rec.gpos = { m = p.m, x = p.x, y = p.y } end
			end
			bump("offers")
		end
	end
	for _, q in ipairs(active) do
		if q.questID then
			local rec = quest(q.questID, q.title)
			if n then
				rec.enders[n.id] = true
				if p then rec.epos = { m = p.m, x = p.x, y = p.y } end
			end
		end
	end
	if n then
		local opts = API.GetGossipOptions()
		if #opts > 0 then
			local rec = data.npcs[n.id]
			rec.gossip = rec.gossip or {}
			for _, o in ipairs(opts) do
				if type(o) == "string" and #rec.gossip < 8 then
					local dup = false
					for _, e in ipairs(rec.gossip) do if e == o then dup = true end end
					if not dup then rec.gossip[#rec.gossip + 1] = o end
				end
			end
		end
	end
end

function R:OnQuestDetail(startItemID)
	local questID = API.GetDialogQuestID()
	if not questID or questID == 0 then return end
	local n = captureNPC("quest")
	local d = API.GetOfferDetails()
	local q = quest(questID, d.title)
	if d.objectives and d.objectives ~= "" then q.otext = d.objectives end
	if FP.settings.recordQuestText and d.text then q.text = U.Truncate(d.text, 600) end
	if type(d.xp) == "number" and d.xp > 0 then
		local lvl = API.PlayerLevel()
		q.xp[tostring(lvl)] = d.xp
	end
	if type(d.money) == "number" and d.money > 0 then q.money = d.money end
	if type(d.group) == "number" and d.group > 0 then q.sg = d.group end
	if #d.rewards > 0 then
		q.rew = {}
		for _, r in ipairs(d.rewards) do if r.itemID then q.rew[#q.rew + 1] = r.itemID; item(r.itemID, r.name, r.quality) end end
	end
	if #d.choices > 0 then
		q.choice = {}
		for _, r in ipairs(d.choices) do if r.itemID then q.choice[#q.choice + 1] = r.itemID; item(r.itemID, r.name, r.quality) end end
	end
	if startItemID and startItemID ~= 0 then q.startItem = startItemID; item(startItemID) end
	if n then
		q.givers[n.id] = true
		if n.pos then q.gpos = { m = n.pos.m, x = n.pos.x, y = n.pos.y } end
		-- chain hint: offered right after a turn-in at the same NPC
		if recentTurnIn and recentTurnIn.npcID == n.id and (API.Time() - recentTurnIn.t) < 90 and recentTurnIn.questID ~= questID then
			q.after = q.after or {}
			q.after[recentTurnIn.questID] = true
		end
	elseif not q.gpos then
		local p = pos()
		if p then q.gpos = { m = p.m, x = p.x, y = p.y, item = true } end
	end
	bump("details")
end

function R:OnQuestAccepted(questID)
	if not questID then return end
	local info = API.GetQuestInfoByID(questID)
	local q = info and snapshotQuest(info) or quest(questID, API.GetQuestTitle(questID))
	objectiveSnapshot[questID] = objectiveSnapshotFor(questID)
	local p = pos()
	q.log = q.log or {}
	U.Push(q.log, { c = char, acc = U.Now(), lvl = API.PlayerLevel(), m = p and p.m, x = p and p.x, y = p and p.y }, 10)
	if not q.gpos and p then q.gpos = { m = p.m, x = p.x, y = p.y } end
	bump("accepted")
end

function R:OnQuestComplete()
	local questID = API.GetDialogQuestID()
	if not questID or questID == 0 then return end
	local n = captureNPC("quest")
	local q = quest(questID, API.GetQuestTitle(questID))
	if n then
		q.enders[n.id] = true
		if n.pos then q.epos = { m = n.pos.m, x = n.pos.x, y = n.pos.y } end
	end
	q._pendingEnder = n and n.id or nil
end

function R:OnQuestTurnedIn(questID, xp, money)
	if not questID then return end
	local q = quest(questID, API.GetQuestTitle(questID))
	local lvl = API.PlayerLevel()
	if type(xp) == "number" and xp > 0 then q.xp[tostring(lvl)] = xp end
	if type(money) == "number" and money > 0 then q.money = money end
	local p = pos()
	if not q.epos and p then q.epos = { m = p.m, x = p.x, y = p.y } end
	q.log = q.log or {}
	local entry = q.log[#q.log]
	if entry and entry.c == char and not entry.done then
		entry.done = U.Now()
		entry.dlvl = lvl
	else
		U.Push(q.log, { c = char, done = U.Now(), dlvl = lvl }, 10)
	end
	local npcID = q._pendingEnder or (lastNPC and (API.Time() - lastNPC.t) < 30 and lastNPC.id) or nil
	q._pendingEnder = nil
	if npcID then q.enders[npcID] = true end
	recentTurnIn = { questID = questID, npcID = npcID, t = API.Time() }
	FP.cdb.completed[questID] = true
	objectiveSnapshot[questID] = nil
	bump("turnins")
end

function R:OnQuestRemoved(questID)
	if not questID then return end
	if recentTurnIn and recentTurnIn.questID == questID then return end
	local q = data.quests[questID]
	if q and q.log then
		local entry = q.log[#q.log]
		if entry and entry.c == char and not entry.done then entry.abandoned = U.Now() end
	end
	objectiveSnapshot[questID] = nil
end

function R:OnInfoMessage(msg)
	msg = safe(msg)
	if type(msg) ~= "string" then return end
	local label, n, m = msg:match("^(.-):%s*(%d+)%s*/%s*(%d+)$")
	if not label then return end
	R.lastInfo = { label = label, n = tonumber(n), m = tonumber(m), t = API.Time() }
end

function R:OnUnit(unit)
	local info = API.UnitInfo(unit)
	if not info or info.isPlayer or info.kind ~= "Creature" or not info.id then return end
	if API.InCombat() then return end   -- unit identity may be secret; positions are enough later
	local p = pos(unit .. "-sighting")
	local c = creature(info.id, info, p)
	if info.reaction and info.reaction >= 4 and info.name then
		-- friendly/neutral NPC: also keep it in the NPC table (vendors, trainers get flags later)
		local n = npc(info.id, info.name, p)
		if n and info.level then n.lvl = info.level end
	end
end

local function recordKill(guid, unitForName)
	local kind, id = U.ParseGUID(guid)
	if kind ~= "Creature" or not id then return end
	local now = API.Time()
	for _, k in ipairs(lastKills) do
		if k.guid == guid then return end
	end
	local info = unitForName and API.UnitInfo(unitForName) or nil
	local p = pos("kill-observer")
	local c = creature(id, info, p)
	c.kills = (c.kills or 0) + 1
	U.Push(lastKills, { id = id, guid = guid, name = info and info.name, pos = p, t = now }, 12)
	bump("kills")
end

function R:OnTargetDied()
	local guid = API.UnitGUID("target")
	if guid then recordKill(guid, "target") end
end

function R:OnUnitDied(guid)
	guid = safe(guid)
	if type(guid) == "string" then recordKill(guid, nil) end
end

function R:OnLoot()
	local slots = API.GetLootSlots()
	if #slots == 0 then return end
	local p, now = pos("loot-observer"), U.Now()
	local byGUID, items, unknown, sourceCandidates = {}, {}, {}, {}
	for _, slot in ipairs(slots) do
		if slot.itemID then
			item(slot.itemID, slot.name, slot.quality)
			items[slot.itemID] = (items[slot.itemID] or 0) + slot.quantity
			local total, supported = 0, true
			for _, source in ipairs(slot.sources or {}) do
				total = total + source.quantity
				local kind, id = U.ParseGUID(source.guid)
				if not id or (kind ~= "Creature" and kind ~= "GameObject") then supported = false end
			end
			-- Incomplete/malformed source accounting cannot be allocated safely.
			if supported and total == slot.quantity and total > 0 then
				for _, source in ipairs(slot.sources) do
					local rec = byGUID[source.guid] or { items = {}, quests = {} }
					byGUID[source.guid] = rec
					rec.items[slot.itemID] = (rec.items[slot.itemID] or 0) + source.quantity
					if slot.questID and slot.questID > 0 then
						rec.quests[slot.itemID] = rec.quests[slot.itemID] or {}
						rec.quests[slot.itemID][slot.questID] = true
					end
				end
			else
				unknown[slot.itemID] = (unknown[slot.itemID] or 0) + slot.quantity
			end
			if slot.isQuestItem or (slot.questID and slot.questID > 0) then
				data.items[slot.itemID].quest = (slot.questID and slot.questID > 0 and slot.questID) or true
			end
		end
	end
	for guid, observation in pairs(byGUID) do
		local kind, id = U.ParseGUID(guid)
		local holder
		if kind == "Creature" and id then holder = creature(id, nil, p)
		elseif kind == "GameObject" and id then holder = gameobject(id, p) end
		if holder then
			sourceCandidates[#sourceCandidates + 1] = { kind = kind, id = id }
			local seen = seenLootGUID[guid]
			if not seen then
				seen = { t = now, items = {}, quests = {} }
				seenLootGUID[guid] = seen
				local field = kind == "Creature" and "looted" or "count"
				holder[field] = (holder[field] or 0) + 1
			end
			seen.t = now
			for itemID, qty in pairs(observation.items) do
				local previous = seen.items[itemID] or 0
				-- Loot offered/observed, not items picked up. Lower counts after partial
				-- looting and repeated opens cannot increase this per-corpse maximum.
				if qty > previous then
					holder.loot[itemID] = (holder.loot[itemID] or 0) + qty - previous
					seen.items[itemID] = qty
				end
				for questID in pairs(observation.quests[itemID] or {}) do
					local key = questID .. ":" .. itemID
					local q = data.quests[questID]
					if q and not seen.quests[key] then
						q.items = q.items or {}
						q.items[itemID] = q.items[itemID] or {}
						local sourceKey = kind == "Creature" and id or (kind .. ":" .. id)
						q.items[itemID][sourceKey] = (q.items[itemID][sourceKey] or 0) + 1
						seen.quests[key] = true
					end
				end
			end
		end
	end
	if next(unknown) then
		local target = API.UnitInfo("target")
		U.Push(data.lootObservations, { t = now, c = char, items = unknown, pos = p,
			attribution = "unknown", targetCandidate = target and target.dead and target.guid or nil }, 200)
	end
	lastLoot = { sources = sourceCandidates, items = items, pos = p, t = API.Time() }
	bump("loots")
	local retained = {}
	for guid, seen in pairs(seenLootGUID) do
		if now - seen.t > 86400 then seenLootGUID[guid] = nil
		else retained[#retained + 1] = { guid = guid, t = seen.t } end
	end
	if #retained > 2048 then
		table.sort(retained, function(a, b) return a.t < b.t end)
		for i = 1, #retained - 2048 do seenLootGUID[retained[i].guid] = nil end
	end
end

function R:OnMerchant()
	local n = captureNPC("vendor")
	if not n then return end
	local items = API.GetMerchantItems()
	if #items == 0 then return end
	local v = data.vendors[n.id] or { items = {} }
	data.vendors[n.id] = v
	v.t = U.Now()
	v.n = n.name
	for _, it in ipairs(items) do
		v.items[it.itemID] = { p = it.price, s = it.stack, lim = it.limited, ext = it.extended or nil }
		item(it.itemID, it.name)
	end
	bump("vendors")
end

function R:OnTrainer()
	local n = captureNPC("trainer")
	if not n then return end
	local services, isTradeskill = API.GetTrainerServices()
	if #services == 0 then return end
	local t = data.trainers[n.id] or { services = {} }
	data.trainers[n.id] = t
	t.t = U.Now()
	t.n = n.name
	t.tradeskill = isTradeskill or nil
	for _, s in ipairs(services) do
		if s.name then
			t.services[s.name] = { type = s.type, lvl = s.level, skill = s.skill, rank = s.skillRank, cost = s.cost, line = s.skillLine, item = s.itemID, sub = s.sub }
		end
	end
	bump("trainers")
end

function R:OnTaxi()
	local n = captureNPC("taxi")
	local nodes, mapID = API.GetTaxiNodes()
	if #nodes == 0 then return end
	local current
	for _, nd in ipairs(nodes) do
		if nd.state == "Current" then current = nd end
	end
	for _, nd in ipairs(nodes) do
		local key = nd.nodeID or nd.name
		if key then
			local rec = data.taxi.nodes[key] or {}
			data.taxi.nodes[key] = rec
			rec.n = nd.name
			rec.m = mapID
			rec.x, rec.y = nd.x and U.Coord(nd.x) or nil, nd.y and U.Coord(nd.y) or nil
			if nd.state == "Current" and n then rec.npc = n.id; rec.pos = n.pos and { m = n.pos.m, x = n.pos.x, y = n.pos.y } or rec.pos end
			if nd.state ~= "Unreachable" then rec.known = true end
			if current and nd.state == "Reachable" then
				local ekey = tostring(current.nodeID or current.name) .. ">" .. tostring(key)
				data.taxi.edges[ekey] = { cost = nd.cost, t = U.Now() }
			end
		end
	end
	if n then data.npcs[n.id].flags.taxi = true end
	bump("taxi")
end

function R:OnBinder(area)
	local n = captureNPC("inn")
	if n then
		data.binds[n.id] = { area = safe(area), pos = n.pos and { m = n.pos.m, x = n.pos.x, y = n.pos.y } or nil, t = U.Now() }
	end
end

function R:OnBound()
	local p = pos()
	FP.cdb.bind = { area = API.GetBindLocation(), m = p and p.m, x = p and p.x, y = p and p.y, t = U.Now() }
	if recording() and lastNPC then data.binds[lastNPC.id] = { area = FP.cdb.bind.area, pos = p and { m = p.m, x = p.x, y = p.y }, t = U.Now() } end
	FP:Fire("BIND_CHANGED")
end

function R:OnXP()
	local now = U.Now()
	if now - lastXPSample < 60 then return end
	lastXPSample = now
	local xp, max, level = API.GetXP()
	if not xp then return end
	local p = pos()
	data.xp[char] = data.xp[char] or {}
	U.Push(data.xp[char], { t = now, xp = xp, max = max, l = level, z = p and p.z or nil }, MAX_XP_SAMPLES)
end

function R:OnXPMessage(text)
	text = safe(text)
	if type(text) ~= "string" then return end
	local name, xp = text:match("^(.-) dies, you gain (%d+) experience")
	if not name then return end
	xp = tonumber(xp)
	local k = lastKills[#lastKills]
	if k and k.name == name and (API.Time() - k.t) < 5 then
		local c = data.creatures[k.id]
		if c then
			c.xp = c.xp or {}
			c.xp[tostring(API.PlayerLevel())] = xp
		end
	end
end

function R:OnLevelUp(level)
	local p = pos()
	FP.cdb.levels[tostring(level)] = { t = U.Now(), m = p and p.m, x = p and p.x, y = p and p.y, z = p and p.z }
	data.chars[char].level = level
	lastXPSample = 0
	R:OnXP()
end

function R:OnDeath()
	local p = pos()
	local k = lastKills[#lastKills]
	U.Push(data.deaths, { t = U.Now(), c = char, l = API.PlayerLevel(), m = p and p.m, x = p and p.x, y = p and p.y, z = p and p.z }, MAX_DEATHS)
	bump("deaths")
end

function R:OnZone()
	local zone, sub = API.GetZoneText()
	local mapID = API.GetBestMap()
	if zone and mapID then
		local z = data.zones[zone] or { first = U.Now() }
		data.zones[zone] = z
		z.m = mapID
		z.last = U.Now()
		local lvl = API.PlayerLevel()
		if lvl then z.lmin = math.min(z.lmin or lvl, lvl); z.lmax = math.max(z.lmax or lvl, lvl) end
	end
end

-- Dataset writes are optional; live quest notifications, bind/settings, and
-- API/error diagnostics remain available while recording is off.
for _, method in ipairs({ "OnGossip", "OnQuestDetail", "OnQuestAccepted", "OnQuestComplete",
	"OnQuestTurnedIn", "OnQuestRemoved", "OnInfoMessage", "OnUnit", "OnTargetDied", "OnUnitDied",
	"OnLoot", "OnMerchant", "OnTrainer", "OnTaxi", "OnBinder", "OnXP", "OnXPMessage",
	"OnLevelUp", "OnDeath", "OnZone" }) do
	local fn = R[method]
	R[method] = function(self, ...)
		if recording() then return fn(self, ...) end
	end
end

-------------------------------------------------------------------------------
-- Summary for /fp status
-------------------------------------------------------------------------------
function R:Summary()
	local d = data
	return string.format("quests %d · npcs %d · creatures %d · objects %d · items %d · vendors %d · trainers %d · taxi %d · progress %d · deaths %d",
		U.Count(d.quests), U.Count(d.npcs), U.Count(d.creatures), U.Count(d.objects), U.Count(d.items),
		U.Count(d.vendors), U.Count(d.trainers), U.Count(d.taxi.nodes), #d.progress, #d.deaths)
end
