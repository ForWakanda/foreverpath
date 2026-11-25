-- HearthAndHustle / Modules / DungeonPlan.lua
-- A dungeon run as an itinerary: what to turn in first, which quests to pick
-- up before you enter and in what order (zone by zone, with the sea crossing),
-- the entrance, what waits inside, what is not available yet, and which drops
-- would improve your gear for the role chosen on the Best in slot page.
-- It reads the dungeon checklist, the quest database and the gear reference.
-- Reference data, not a live offer list; nothing changes until a click.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local DP = FP:NewModule("DungeonPlan")
local catalog = FP.DungeonCatalog

local GEAR_ROWS = 8          -- possible upgrades listed (wishlist items always are)
local LEVEL_AHEAD = 2        -- list a drop this many levels before you can wear it

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

function DP:Levels(dungeon)
	local lo, hi = tostring(dungeon.recommendedLevel or ""):match("(%d+)%D+(%d+)")
	return tonumber(lo), tonumber(hi)
end

function DP:Fits(dungeon, level)
	local lo, hi = self:Levels(dungeon)
	return lo ~= nil and U.Finite(level) and level >= lo and level <= hi
end

function DP:List()
	local level, out = API.PlayerLevel(), {}
	for _, row in ipairs(FP.Dungeons:List()) do
		out[#out + 1] = { key = row.key, data = row.data, fits = self:Fits(row.data, level) }
	end
	return out
end

function DP:ListLabel(row)
	return row.data.name .. " · " .. tostring(row.data.recommendedLevel or "level unknown")
		.. (row.fits and " · your level" or "") .. (#row.data.quests == 0 and " · no quest list" or "")
end

-- The dungeon to open on: of those for your level, the one with most quests in
-- your log; else the one last opened in the checklist, when it has a quest
-- list; else the one whose level range you sit nearest the middle of.
function DP:Default()
	local level = API.PlayerLevel()
	local list, best, bestCount, first, firstGap = self:List(), nil, 0, nil, nil
	for _, row in ipairs(list) do
		if row.fits then
			if #row.data.quests > 0 then
				local lo, hi = self:Levels(row.data)
				local gap = math.abs(level - (lo + hi) / 2)
				if not first or gap < firstGap then first, firstGap = row.key, gap end
			end
			local count = 0
			for _, id in ipairs(row.data.quests) do
				if FP.Dungeons:LogID(id) then count = count + 1 end
			end
			if count > bestCount then best, bestCount = row.key, count end
		end
	end
	local saved = FP.cdb.dungeonChecklist and FP.cdb.dungeonChecklist.selected
	if best then return best end
	if saved and catalog.dungeons[saved] and #catalog.dungeons[saved].quests > 0 then return saved end
	return first or saved or (list[1] and list[1].key)
end

function DP:Find(query)
	query = U.Trim(query or ""):lower()
	if query == "" then return self:Default() end
	local found
	for _, row in ipairs(self:List()) do
		local name = row.data.name:lower()
		if row.key == query or name == query then return row.key end
		if name:find(query, 1, true) then
			if found then return nil, "Several dungeons match. Use more of the name." end
			found = row.key
		end
	end
	if not found then return nil, "No matching dungeon." end
	return found
end

-------------------------------------------------------------------------------
-- Gear from this dungeon for the chosen role
-------------------------------------------------------------------------------
function DP:Gear(key)
	local dungeon = catalog.dungeons[key]
	if not dungeon then return {} end
	if API.InCombat() then return {}, "Gear comparison resumes after combat." end
	if not API.EnsureGearCatalog() then return {}, "Gear data unavailable: install both Hearth & Hustle folders." end
	local G, char = FP.Gear, API.GetCharInfo()
	if not U.Finite(char.level) then return {}, "Character information unavailable." end
	local role = G:Profile()
	local stamp = key .. ":" .. tostring(role) .. ":" .. char.level .. ":" .. (self.gearStamp or 0) .. ":" .. U.Count(FP.cdb.gear.wishlist)
	if self.gearMemo and self.gearMemo.stamp == stamp then return self.gearMemo.rows end
	local weights, wishlist = G:Weights(), FP.cdb.gear.wishlist
	-- what is worn now, per slot group: the weaker piece is the one a drop replaces
	local worn = {}
	local function wornScore(slot)
		if worn[slot[1]] == nil then
			local low
			for i = 3, #slot do
				local gear = API.GetRewardEquipment(slot[i])
				local score = gear.status == "empty" and 0 or G:Score(gear.stats, weights, slot[1])
				if not score then low = false; break end
				if low == nil or score < low then low = score end
			end
			worn[slot[1]] = low == nil and false or low
		end
		return worn[slot[1]] or nil
	end
	local wished, upgrades = {}, {}
	for _, item in ipairs(FP.GearCatalog.items) do
		local boss = G:DropsIn(item, dungeon.name)
		if boss and G:ClassMatches(item, char) then
			local known = U.Finite(item.minLevel)
			local soon = (known and item.minLevel <= char.level + LEVEL_AHEAD)
				or (not known and U.Finite(item.level) and item.level <= char.level + G.PROXY_MARGIN)
			local slot
			for _, candidate in ipairs(G.slots) do if G:SlotMatches(item, candidate[1]) then slot = candidate; break end end
			if slot and (soon or wishlist[item.id]) then
				local score = G:Score(item.stats, weights, slot[1])
				local current = wornScore(slot)
				local row = { type = "gear", key = "gear:" .. item.id, item = item, slot = slot, boss = boss ~= true and boss or nil,
					score = score, delta = score and current and (score - current) or nil, wished = wishlist[item.id] == true,
					later = known and item.minLevel > char.level and item.minLevel or nil }
				if row.wished then wished[#wished + 1] = row
				elseif row.delta and row.delta > 0 then upgrades[#upgrades + 1] = row end
			end
		end
	end
	local function better(a, b)
		if (a.delta or -1e9) ~= (b.delta or -1e9) then return (a.delta or -1e9) > (b.delta or -1e9) end
		return a.item.id < b.item.id
	end
	table.sort(wished, better); table.sort(upgrades, better)
	local rows = wished
	for i = 1, math.min(#upgrades, GEAR_ROWS) do rows[#rows + 1] = upgrades[i] end
	rows.more = math.max(0, #upgrades - GEAR_ROWS)
	rows.role = select(2, G:Profile()).name
	self.gearMemo = { stamp = stamp, rows = rows }
	return rows
end

-------------------------------------------------------------------------------
-- Which dungeon next: the dungeons around your level ranked by what their
-- drops would add to your gear, for your own role and for a second spec.
--
-- Per role, a dungeon's value is the score its best drop per slot adds over the
-- best you carry for that role (worn or in your bags; the bank is not seen),
-- as a share of that role's whole set. Roles are added up as shares, since
-- their scores use different weights. The item reference lists drops per
-- dungeon, not per wing, so wings share one row; a dungeon it has no drops for
-- is named as not rankable, never ranked as worthless. Reference data and
-- estimates: nothing here says a drop exists on Forever or will drop for you.
--
-- "Around your level" has two ends. A dungeon that starts more than
-- LEVEL_AHEAD levels above the character is not listed yet. A dungeon whose
-- level range ends below the character's level is left out as well, and
-- counted: a second spec with little gear carried makes nearly every drop of a
-- dungeon thirty levels down "better than what you carry", and four wings of
-- such drops added up outranked the dungeons of the character's own level.
-- Whatever such a dungeon would add, a dungeon in range adds more.
-------------------------------------------------------------------------------
local NEXT_ITEMS = 4          -- upgrades named per role in the details

-- reference source name -> the catalogue dungeons it means (several for wings)
function DP:Sources()
	local gear = FP.GearCatalog
	if self.sources and self.sourcesFor == gear then return self.sources, self.unlisted end
	local G, names = FP.Gear, {}
	for _, item in ipairs(gear.items) do
		for i, kind in ipairs(item.sourceTypes) do
			if kind == "Dungeon" and type(item.sources[i]) == "string" then names[item.sources[i]] = true end
		end
	end
	local sources, covered = {}, {}
	for name in pairs(names) do
		local group = { source = name, dungeons = {} }
		for _, row in ipairs(FP.Dungeons:List()) do
			if G:SourceIsDungeon(name, row.data.name) then group.dungeons[#group.dungeons + 1] = row; covered[row.key] = true end
		end
		if #group.dungeons > 0 then sources[#sources + 1] = group end
	end
	table.sort(sources, function(a, b) return a.source < b.source end)
	local unlisted = {}
	for _, row in ipairs(FP.Dungeons:List()) do if not covered[row.key] then unlisted[#unlisted + 1] = row end end
	self.sources, self.unlisted, self.sourcesFor = sources, unlisted, gear
	return sources, unlisted
end

function DP:Next()
	if API.InCombat() then return {}, { note = "The ranking resumes after combat." } end
	if not API.EnsureGearCatalog() then return {}, { note = "Gear data unavailable: install both Hearth & Hustle folders." } end
	local G, char = FP.Gear, API.GetCharInfo()
	local level = char.level
	if not U.Finite(level) then return {}, { note = "Character information unavailable." } end
	local own, ownProfile = G:Profile()
	local second, secondProfile = G:Second()
	local roles = { { key = own, name = ownProfile.name } }
	if second then roles[2] = { key = second, name = secondProfile.name } end
	-- one answer until the gear, the level, the roles or their weights change
	local stamp = { level, self.gearStamp or 0 }
	for _, role in ipairs(roles) do
		stamp[#stamp + 1] = role.key
		local weights = G:Weights(role.key)
		for _, stat in ipairs(G.stats) do stamp[#stamp + 1] = weights[stat[1]] end
	end
	stamp = table.concat(stamp, ":")
	if self.nextMemo and self.nextMemo.stamp == stamp then return self.nextMemo.rows, self.nextMemo.info end
	local info = { roles = roles, tooHigh = 0, below = 0, nothing = 0, unlisted = {}, unread = 0, loading = 0, bags = true }
	for _, role in ipairs(roles) do
		role.owned = G:Owned(role.key)
		if not role.owned then return {}, { note = "The ranking resumes after combat." } end
		info.unread = math.max(info.unread, role.owned.unread)
		info.loading = math.max(info.loading, role.owned.loading)
		info.bags = info.bags and role.owned.bagsRead
	end
	local sources, unlisted = self:Sources()
	for _, row in ipairs(unlisted) do
		if self:Fits(row.data, level) then info.unlisted[#info.unlisted + 1] = row.data.name end
	end
	-- the reference's drops, by source name
	local drops = {}
	for _, item in ipairs(FP.GearCatalog.items) do
		for i, kind in ipairs(item.sourceTypes) do
			if kind == "Dungeon" and G:ClassMatches(item, char) then
				local known = U.Finite(item.minLevel)
				local soon = (known and item.minLevel <= level + LEVEL_AHEAD)
					or (not known and U.Finite(item.level) and item.level <= level + G.PROXY_MARGIN)
				local slot
				for _, candidate in ipairs(G.slots) do if G:SlotMatches(item, candidate[1]) then slot = candidate; break end end
				if soon and slot then
					local name = item.sources[i]
					drops[name] = drops[name] or {}
					table.insert(drops[name], { item = item, slot = slot, boss = item.bosses[1],
						later = known and item.minLevel > level and item.minLevel or nil })
				end
			end
		end
	end
	local rows = {}
	for _, group in ipairs(sources) do
		local lo, hi, open, inLog = nil, nil, nil, 0
		for _, row in ipairs(group.dungeons) do
			local a, b = self:Levels(row.data)
			if a then lo, hi = math.min(lo or a, a), math.max(hi or b, b) end
			if not open or (self:Fits(row.data, level) and not self:Fits(open.data, level)) then open = row end
			for _, id in ipairs(row.data.quests) do
				if FP.Dungeons:LogID(id) then inLog = inLog + 1 end
			end
		end
		if lo and lo > level + LEVEL_AHEAD then
			info.tooHigh = info.tooHigh + 1
		elseif lo and hi < level then
			-- outgrown: every wing's range ends below the character's level
			info.below = info.below + 1
		elseif lo then
			local out = { key = open.key, source = group.source, wings = #group.dungeons, lo = lo, hi = hi, inLog = inLog,
				fits = level >= lo and level <= hi, name = #group.dungeons == 1 and open.data.name or (group.source:gsub("^The ", "")),
				roles = {}, total = 0, gain = 0 }
			for i, role in ipairs(roles) do
				local result = G:Gain(role.owned, role.key, drops[group.source] or {})
				result.name, result.key = role.name, role.key
				out.roles[i] = result
				out.total = out.total + (result.pct or 0)
				out.gain = out.gain + result.gain
			end
			if out.gain > 0 then rows[#rows + 1] = out else info.nothing = info.nothing + 1 end
		end
	end
	table.sort(rows, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		if a.gain ~= b.gain then return a.gain > b.gain end
		if a.inLog ~= b.inLog then return a.inLog > b.inLog end
		return a.name < b.name
	end)
	for i, row in ipairs(rows) do row.rank = i end
	self.nextMemo = { stamp = stamp, rows = rows, info = info }
	-- kept for the next data pull: what the ranking could read, and what it put first
	if FP.db then
		FP.db.dungeonNext = { t = U.Now(), version = FP.version, level = level, own = own, second = second or false,
			bagsRead = info.bags, unread = info.unread, loading = info.loading, rows = #rows, first = rows[1] and rows[1].name or nil,
			below = info.below, tooHigh = info.tooHigh }
	end
	return rows, info
end

-- "+6%": the share of the role's whole set; a plain score when the set has none to compare with
local function share(result)
	if result.gain <= 0 then return "nothing better" end
	return result.pct and string.format("+%.0f%%", math.max(1, result.pct)) or string.format("+%.0f score", result.gain)
end

-- "1. Maraudon · 46-55 · Healing +6% · Strength melee +11% · 2 in your log" (kept short: the list cuts a row at 82 characters)
function DP:NextLabel(row)
	local parts = { row.rank .. ". " .. row.name, row.lo .. "-" .. row.hi }
	for _, result in ipairs(row.roles) do parts[#parts + 1] = result.name .. " " .. share(result) end
	if row.inLog > 0 then parts[#parts + 1] = row.inLog .. " in your log" end
	return table.concat(parts, " · ")
end

function DP:NextSummary(rows, info)
	if info.note then return info.note end
	local names = {}
	for i, role in ipairs(info.roles) do names[i] = FP.GOLD .. role.name .. "|r" .. (i == 2 and " (second spec)" or "") end
	local lines = { "Ranked for " .. table.concat(names, " and ") .. ": " .. (#rows == 0 and "no listed dungeon drop beats what you carry."
		or (plural(#rows, "dungeon") .. " with drops better than what you carry, most to gain first.")) }
	local notes = {}
	if #info.unlisted > 0 then notes[#notes + 1] = "No drops in the item reference, so not ranked: " .. table.concat(info.unlisted, ", ") .. "." end
	-- both ends of "around your level", in one sentence when both apply
	if info.tooHigh > 0 and info.below > 0 then
		notes[#notes + 1] = plural(info.tooHigh, "higher-level dungeon") .. " not listed yet, " .. info.below .. " below your level left out."
	elseif info.tooHigh > 0 then notes[#notes + 1] = plural(info.tooHigh, "higher-level dungeon") .. " not listed yet."
	elseif info.below > 0 then notes[#notes + 1] = plural(info.below, "dungeon") .. " below your level left out." end
	if info.unread > 0 then notes[#notes + 1] = FP.RED .. plural(info.unread, "worn piece") .. " could not be read; " .. (info.unread == 1 and "its slot is" or "their slots are") .. " left out.|r" end
	if not info.bags then notes[#notes + 1] = "Your bags could not be read: compared with what you wear only."
	elseif info.loading > 0 then notes[#notes + 1] = plural(info.loading, "bag item") .. " still loading." end
	if #notes > 0 then lines[#lines + 1] = FP.GREY .. table.concat(notes, " ") .. "|r" end
	return table.concat(lines, "\n")
end

function DP:NextDetails(row, info)
	if not row then
		return "Select a dungeon to see which drops it is ranked for. Each role is compared with the best you carry for it, worn or in your bags; gear in the bank is not seen."
	end
	local lines = { FP.GOLD .. row.name .. "|r  (" .. row.lo .. "-" .. row.hi .. ")"
		.. (row.wings > 1 and ("  ·  " .. row.wings .. " wings; the reference does not say which wing a drop is in") or "")
		.. (row.inLog > 0 and ("  ·  " .. plural(row.inLog, "quest") .. " in your log") or "") }
	for _, result in ipairs(row.roles) do
		if result.gain <= 0 then
			lines[#lines + 1] = result.name .. ": nothing listed here beats what you carry."
		else
			lines[#lines + 1] = result.name .. ": " .. share(result) .. " from " .. plural(#result.items, "slot") .. string.format(" (score +%.1f%s)", result.gain,
				result.pct and string.format(" on %.0f", result.gain / result.pct * 100) or "")
			for i = 1, math.min(NEXT_ITEMS, #result.items) do
				local c = result.items[i]
				lines[#lines + 1] = "  " .. (FP.Gear:HandOf(c.item.equipLoc) == "two" and "Two-hand" or c.slot[2]) .. ": " .. c.item.name
					.. (c.boss and (" (" .. c.boss .. ")") or "") .. string.format(" %+.1f", c.delta) .. (c.later and (", at level " .. c.later) or "")
			end
			if #result.items > NEXT_ITEMS then lines[#lines + 1] = "  and " .. (#result.items - NEXT_ITEMS) .. " more" end
		end
		if result.skipped > 0 then lines[#lines + 1] = FP.GREY .. "  " .. plural(result.skipped, "drop") .. " left out: the piece you wear in that slot could not be read.|r" end
	end
	lines[#lines + 1] = FP.GREY .. "Estimate from your stat weights and a reference item list; it does not confirm a drop exists on Forever. Gear in the bank is not seen.|r"
	return table.concat(lines, "\n")
end

function DP:NextLines(limit)
	local rows, info = self:Next()
	local out = { self:NextSummary(rows, info) }
	for i = 1, math.min(limit or 5, #rows) do out[#out + 1] = "  " .. self:NextLabel(rows[i]) end
	return out
end

-------------------------------------------------------------------------------
-- The plan
-------------------------------------------------------------------------------
-- Where a quest is picked up: a live offer on this map first, then the nearest
-- known giver outside the dungeon, then "inside" when every known giver is.
local function pickupPlace(id, ctx, pos)
	local offer = ctx.offers[id]
	if offer and U.ValidMapPoint(offer.mapID, offer.x, offer.y) then return offer, nil, offer.name end
	local best, bestD, inside, giver
	local function consider(points, name)
		for _, point in ipairs(points or {}) do
			if point.entrance then inside, giver = true, giver or name
			elseif U.ValidMapPoint(point.mapID, point.x, point.y) then
				local c, wx, wy = FP.Pos:WorldOf(point)
				local d = (pos.valid and wx and c == pos.continent) and U.Distance(pos.wx, pos.wy, wx, wy) or math.huge
				if not best or d < bestD then best, bestD, giver = point, d, name end
			end
		end
	end
	for _, starter in ipairs(FP.QuestChains:Starters(id)) do
		consider(starter.points, starter.name)
		-- a starting item is picked up where it drops
		for _, source in ipairs(starter.sources or {}) do consider(source.points, starter.name .. ", from " .. source.name) end
	end
	return best, (not best) and inside or false, giver
end

-- who gives it inside: "Shade of Eranikus" / "Malfurion Stormrage" (the list cuts a row at 82 characters)
local function insideFrom(o)
	local list, out = o.kind == "item" and o.sources or o.givers, {}
	for i = 1, math.min(2, #list) do out[i] = list[i].name end
	local rest = #list - #out + (o.more or 0)
	local text = table.concat(out, ", ") .. (rest > 0 and (" and " .. rest .. " more") or "")
	return text
end

function DP:Build(key)
	local dungeon = catalog.dungeons[key]
	if not dungeon then return nil end
	local now = API.Time()
	if self.memo and self.memo.key == key and now - self.memo.t < 1 then return self.memo.plan end
	FP.Pos:Refresh(true)
	local pos = FP.Pos.cache
	local questRows, counts, ctx = FP.Dungeons:Rows(key, false)
	local plan = { key = key, dungeon = dungeon, ctx = ctx, rows = {}, done = counts.done, hidden = counts.hidden,
		pickups = 0, zones = 0, unplaced = 0, inside = 0, turnins = 0, chain = 0, later = 0, crossings = 0 }
	local turnins, placed, unplaced, inside, chain, later = {}, {}, {}, {}, {}, {}
	local D = FP.Dungeons
	for _, r in ipairs(questRows) do
		local q = r.quest
		if r.code == "ready" then
			turnins[#turnins + 1] = { type = "turnin", key = "turnin:" .. r.id, quest = r, text = "Turn in: " .. q.name }
		elseif r.code == "active" then
			inside[#inside + 1] = { type = "active", key = "active:" .. r.id, quest = r, text = "In your log: " .. q.name }
		elseif r.code == "inside" then
			-- every known way to start it is inside a dungeon: nothing to fetch beforehand
			local o = D:Origin(r.id)
			local other = o.dungeonArea ~= D:Area(key) and (" (" .. tostring(o.dungeon) .. ")") or ""
			if o.kind == "item" then
				inside[#inside + 1] = { type = "drop", key = "drop:" .. r.id, quest = r, text = "Drops inside: " .. q.name .. " — from " .. insideFrom(o) .. other }
			else
				inside[#inside + 1] = { type = "pickup-inside", key = "pickup:" .. r.id, quest = r, text = "Pick up inside: " .. q.name .. " (" .. insideFrom(o) .. ")" .. other }
			end
		elseif r.code == "offer" or r.code == "pickup" then
			local o = D:Origin(r.id)
			local point, within, giver = pickupPlace(r.id, ctx, pos)
			giver = giver or o.name or (o.givers[1] and o.givers[1].name) or (o.items[1] and o.items[1].name)
			if point then
				placed[#placed + 1] = { type = "pickup", key = "pickup:" .. r.id, quest = r, point = point, giver = giver, item = o.kind == "item" }
			elseif within then
				inside[#inside + 1] = { type = "pickup-inside", key = "pickup:" .. r.id, quest = r, text = "Pick up inside: " .. q.name .. (giver and (" (" .. giver .. ")") or "") }
			elseif o.kind == "item" then
				unplaced[#unplaced + 1] = { type = "pickup-unplaced", key = "pickup:" .. r.id, quest = r,
					text = "Starts from an item (where it drops is not in the reference): " .. q.name .. (giver and (" — " .. giver) or "") }
			else
				unplaced[#unplaced + 1] = { type = "pickup-unplaced", key = "pickup:" .. r.id, quest = r,
					text = "Pick up (place not in the reference): " .. q.name
						.. (giver and (" — " .. giver .. (o.zone and (", " .. o.zone) or "")) or " — giver not recorded") }
			end
		elseif r.code == "prereq" then
			-- kept short for the list; the place of the next step is in the details
			local path = D:Path(r.id, ctx)
			-- a chain too long to follow back names no first quest
			local first = not path.cut and path.steps[1] or nil
			chain[#chain + 1] = { type = "chain", key = "chain:" .. r.id, quest = r, steps = #path.steps, first = first,
				text = path.cut and (q.name .. " — a very long chain; its first quest is not worked out")
					or (q.name .. " — first: " .. (first and (D:QuestName(first) .. (ctx:State(first).onQuest == true and " (in your log)" or "")
					.. (#path.steps > 1 and (" + " .. (#path.steps - 1) .. " more") or "")) or "a step you cannot take")) }
		elseif r.code ~= "done" and r.code ~= "restricted" and r.code ~= "closed" then
			later[#later + 1] = { type = "later", key = "later:" .. r.id, quest = r, text = r.label .. ": " .. q.name }
		end
	end

	-- Pickups: one stop per zone, nearest first on this continent, then across the sea.
	local stops, byMap = {}, {}
	for _, item in ipairs(placed) do
		local c, wx, wy = FP.Pos:WorldOf(item.point)
		local stop = byMap[item.point.mapID]
		if not stop then
			stop = { mapID = item.point.mapID, zone = API.GetMapName(item.point.mapID), continent = c, items = {}, sx = 0, sy = 0, n = 0 }
			byMap[item.point.mapID] = stop
			stops[#stops + 1] = stop
		end
		stop.items[#stop.items + 1] = item
		if wx then stop.sx, stop.sy, stop.n = stop.sx + wx, stop.sy + wy, stop.n + 1 end
	end
	for _, stop in ipairs(stops) do
		if stop.n > 0 then stop.wx, stop.wy = stop.sx / stop.n, stop.sy / stop.n end
	end
	local before = {}
	local here, fx, fy
	if pos.valid then here, fx, fy = pos.continent, pos.wx, pos.wy end
	local function cross(continent, tx, ty)
		-- a row for the sea crossing, when one is known for this character
		if here == nil or continent == nil or continent == here then return end
		local leg = fx and tx and FP.Travel:Crossing(here, fx, fy, continent, tx, ty) or nil
		plan.crossings = plan.crossings + 1
		if leg then
			before[#before + 1] = { type = "crossing", key = "crossing:" .. plan.crossings, leg = leg,
				text = "→ " .. FP.Travel:LegTitle(leg) .. ", from " .. leg.from.town .. (leg.crossing.approximate and " (approximate)" or "") }
			local _, bx, by = FP.Pos:WorldOf(leg.to)
			fx, fy = bx, by
		else
			before[#before + 1] = { type = "gap", key = "gap:" .. plan.crossings, text = "→ other continent: no crossing known for this character" }
			fx, fy = nil, nil
		end
		here = continent
	end
	local function visit(continent)
		while true do
			local best, bestD
			for _, stop in ipairs(stops) do
				if not stop.visited and stop.continent == continent then
					local d = (fx and stop.wx) and U.Distance(fx, fy, stop.wx, stop.wy) or math.huge
					if not best or d < bestD or (d == bestD and stop.zone < best.zone) then best, bestD = stop, d end
				end
			end
			if not best then return end
			best.visited = true
			plan.zones = plan.zones + 1
			table.sort(best.items, function(a, b) return a.quest.quest.name < b.quest.quest.name end)
			for i, item in ipairs(best.items) do
				plan.pickups = plan.pickups + 1
				item.stop, item.dist = plan.zones, (i == 1 and bestD ~= math.huge) and bestD or nil
				item.text = plan.zones .. ". " .. best.zone .. (item.item and " — get the starting item: " or " — pick up: ") .. item.quest.quest.name .. (item.giver and (" (" .. item.giver .. ")") or "")
					.. (item.dist and (" · " .. (plan.zones == 1 and "" or "+") .. U.FormatDistance(item.dist)) or "")
				before[#before + 1] = item
			end
			if best.wx then fx, fy = best.wx, best.wy end
		end
	end
	if here ~= nil then visit(here) end
	for _, stop in ipairs(stops) do
		if not stop.visited then
			cross(stop.continent, stop.wx, stop.wy)
			if here == nil then here = stop.continent end
			visit(stop.continent)
		end
	end
	for _, item in ipairs(unplaced) do before[#before + 1] = item end
	plan.unplaced = #unplaced

	-- The entrance comes last: the one nearest to where the pickups end.
	local entrances = FP.Dungeons:Entrances(key)
	local entrance, entranceD, entranceIndex
	for i, p in ipairs(entrances) do
		local c, wx, wy = FP.Pos:WorldOf(p)
		local d = (fx and wx and c == here) and U.Distance(fx, fy, wx, wy) or math.huge
		if not entrance or d < entranceD then entrance, entranceD, entranceIndex = p, d, i end
	end
	if entrance then
		local c, wx, wy = FP.Pos:WorldOf(entrance)
		cross(c, wx, wy)
		if fx and wx and c == here then entranceD = U.Distance(fx, fy, wx, wy) end
		plan.entrance = entrance
		before[#before + 1] = { type = "entrance", key = "entrance", point = entrance, index = entranceIndex,
			text = "Entrance: " .. API.GetMapName(entrance.mapID) .. " " .. U.FormatCoords(entrance.x, entrance.y)
				.. ((entranceD and entranceD ~= math.huge) and (" · " .. (#before > 0 and "+" or "") .. U.FormatDistance(entranceD)) or "") }
	end

	-- inside: what is already in the log first
	local rank = { active = 1, ["pickup-inside"] = 2, drop = 3 }
	for i, item in ipairs(inside) do item.i = i end
	table.sort(inside, function(a, b)
		if rank[a.type] ~= rank[b.type] then return rank[a.type] < rank[b.type] end
		return a.i < b.i
	end)
	local rows = plan.rows
	local function section(title, items)
		if #items == 0 then return end
		rows[#rows + 1] = { type = "header", key = "header:" .. title, text = "— " .. title .. " —", count = #items }
		for _, item in ipairs(items) do rows[#rows + 1] = item end
	end
	section("Turn in first", turnins)
	section("Before you enter", before)
	section("Inside", inside)
	section("Behind a quest chain", chain)
	section("Not available yet", later)
	local gear, gearNote = self:Gear(key)
	plan.gear, plan.gearNote = gear, gearNote
	for _, row in ipairs(gear) do
		local item = row.item
		row.text = (row.wished and "Wishlist: " or "Upgrade: ") .. item.name .. " · " .. row.slot[2] .. (row.boss and (" · " .. row.boss) or "")
			.. (row.delta and string.format(" · %+.1f", row.delta) or "") .. (row.later and (" · at level " .. row.later) or "")
	end
	section("Drops for your role" .. (gear.role and (" (" .. gear.role .. ")") or ""), gear)
	plan.turnins, plan.inside, plan.chain, plan.later = #turnins, #inside, #chain, #later
	self.memo = { key = key, t = now, plan = plan }
	return plan
end

function DP:RowLabel(row) return row.text end

function DP:Summary(plan)
	if not plan then return "Choose a dungeon above to see its itinerary." end
	local d = plan.dungeon
	local lines = { FP.GOLD .. d.name .. "|r  (" .. tostring(d.recommendedLevel or "level range unknown") .. ")" }
	if #d.quests == 0 then
		lines[#lines + 1] = "Quest coverage is not catalogued for this dungeon. That does not mean it has no quests."
	else
		local bits = {}
		if plan.turnins > 0 then bits[#bits + 1] = plan.turnins .. " ready to turn in" end
		bits[#bits + 1] = plural(plan.pickups + plan.unplaced, "pickup") .. " before you enter"
			.. (plan.pickups > 0 and (" in " .. plural(plan.zones, "zone")) or "")
		if plan.inside > 0 then bits[#bits + 1] = plan.inside .. " inside" end
		if plan.chain > 0 then bits[#bits + 1] = plan.chain .. " behind a quest chain" end
		if plan.later > 0 then bits[#bits + 1] = plan.later .. " not available yet" end
		if plan.done > 0 then bits[#bits + 1] = plan.done .. " completed" end
		lines[#lines + 1] = table.concat(bits, " · ") .. "."
	end
	if not plan.entrance then
		local ready = API.QuestDatabaseStatus()
		lines[#lines + 1] = FP.GREY .. (ready and "Entrance not in the reference for this dungeon." or "Pickup places and the entrance need QuestieDB (Forever) enabled.") .. "|r"
	end
	if plan.gearNote then
		lines[#lines + 1] = FP.GREY .. plan.gearNote .. "|r"
	else
		local wished, up = 0, 0
		for _, row in ipairs(plan.gear) do if row.wished then wished = wished + 1 else up = up + 1 end end
		lines[#lines + 1] = (wished + up == 0) and ("No listed drop here beats what you wear for " .. tostring(plan.gear.role) .. ".")
			or ("Drops for " .. tostring(plan.gear.role) .. ": " .. (wished > 0 and (wished .. " on your wishlist, ") or "")
				.. plural(up, "possible upgrade") .. (plan.gear.more > 0 and (" (+" .. plan.gear.more .. " more on Best in slot)") or "") .. ".")
	end
	return table.concat(lines, "\n")
end

function DP:RowDetails(plan, row)
	if not plan then return "" end
	if not row then return "Select a step for its details. Pickups are ordered nearest zone first; distances are straight lines, not travel time." end
	if row.type == "header" then
		return row.text .. "\n" .. plural(row.count, "line") .. " below. Select one for details."
	elseif row.type == "crossing" or row.type == "gap" then
		return FP.Travel:RowDetails(row)
	elseif row.type == "entrance" then
		return "Entrance " .. row.index .. ": " .. API.GetMapName(row.point.mapID) .. " " .. U.FormatCoords(row.point.x, row.point.y)
			.. "\n" .. FP.Dungeons:RouteNote(plan.key)
	elseif row.type == "gear" then
		local item = row.item
		local lines = { FP.GOLD .. item.name .. "|r  ·  " .. row.slot[2] .. " · " .. tostring(item.subtype or "") }
		lines[#lines + 1] = "Drops from: " .. (row.boss or "not recorded") .. " (" .. plan.dungeon.name .. ")"
		lines[#lines + 1] = "Requires level: " .. tostring(item.minLevel or "unknown") .. " · item level " .. tostring(item.level or "?")
		if row.delta then lines[#lines + 1] = string.format("Reference score %.1f, %+.1f against what you wear in that slot (the weaker piece of two).", row.score or 0, row.delta)
		else lines[#lines + 1] = "Your worn item could not be read yet; compare on Best in slot." end
		if row.slot[1] == "MAIN" or row.slot[1] == "OFF" then lines[#lines + 1] = "Hand scores are individual: a two-hander replaces both hands." end
		lines[#lines + 1] = FP.GREY .. "Estimate from your stat weights. A listed source does not confirm the drop exists on Forever.|r"
		return table.concat(lines, "\n")
	end
	local text = FP.Dungeons:Details(row.quest, plan.ctx)
	if row.type == "pickup" then
		text = "Known pickup place: " .. API.GetMapName(row.point.mapID) .. " " .. U.FormatCoords(row.point.x, row.point.y) .. "\n\n" .. text
	end
	return text
end

function DP:CanGuide(row)
	if not row then return false end
	local t = row.type
	return t == "pickup" or t == "pickup-inside" or t == "drop" or t == "chain" or t == "turnin" or t == "active" or (t == "entrance" and not API.InInstance())
end

-- The player's click on one step. Same guarded paths as the quest checklist.
function DP:Guide(plan, row)
	if not plan or not self:CanGuide(row) then return false end
	local ok, message
	if row.type == "entrance" then ok, message = FP.Dungeons:GuideEntrance(plan.key, row.index)
	else ok, message = FP.Dungeons:GuideQuest(row.quest.id) end
	FP:Print(message)
	return ok == true
end

function DP:ToggleWish(row)
	if not row or row.type ~= "gear" or API.InCombat() then return false end
	local id = row.item.id
	FP.cdb.gear.wishlist[id] = not FP.cdb.gear.wishlist[id] or nil
	self.memo = nil
	FP:Print(row.item.name .. (FP.cdb.gear.wishlist[id] and " saved to your wishlist." or " removed from your wishlist."))
	return true
end

function DP:Lines(key)
	local plan = self:Build(key)
	if not plan then return { "No such dungeon." } end
	local out = { self:Summary(plan) }
	for _, row in ipairs(plan.rows) do out[#out + 1] = (row.type == "header" and FP.GOLD or "  ") .. row.text .. (row.type == "header" and "|r" or "") end
	return out
end

function DP:OnEnable()
	local function stale() self.gearStamp = (self.gearStamp or 0) + 1; self.memo = nil end
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED" }) do FP:RegisterEvent(event, stale) end
	FP:On("QUESTLOG_SCANNED", function() self.memo, self.nextMemo = nil, nil end)
end
