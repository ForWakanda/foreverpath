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
				if API.GetDungeonQuestState(id).onQuest == true then count = count + 1 end
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
-- The plan
-------------------------------------------------------------------------------
-- Where a quest is picked up: a live offer on this map first, then the nearest
-- known giver outside the dungeon, then "inside" when every known giver is.
local function pickupPlace(id, ctx, pos)
	local offer = ctx.offers[id]
	if offer and U.ValidMapPoint(offer.mapID, offer.x, offer.y) then return offer, nil, offer.name end
	local best, bestD, inside, giver
	for _, starter in ipairs(FP.QuestChains:Starters(id)) do
		for _, point in ipairs(starter.points) do
			if point.entrance then inside, giver = true, giver or starter.name
			elseif U.ValidMapPoint(point.mapID, point.x, point.y) then
				local c, wx, wy = FP.Pos:WorldOf(point)
				local d = (pos.valid and wx and c == pos.continent) and U.Distance(pos.wx, pos.wy, wx, wy) or math.huge
				if not best or d < bestD then best, bestD, giver = point, d, starter.name end
			end
		end
	end
	return best, (not best) and inside or false, giver
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
		pickups = 0, zones = 0, unplaced = 0, inside = 0, turnins = 0, later = 0, crossings = 0 }
	local turnins, placed, unplaced, inside, later = {}, {}, {}, {}, {}
	for _, r in ipairs(questRows) do
		local q = r.quest
		if r.code == "ready" then
			turnins[#turnins + 1] = { type = "turnin", key = "turnin:" .. r.id, quest = r, text = "Turn in: " .. q.name }
		elseif r.code == "active" then
			inside[#inside + 1] = { type = "active", key = "active:" .. r.id, quest = r, text = "In your log: " .. q.name }
		elseif r.code == "offer" or r.code == "pickup" then
			if q.pickupType == "drop" then
				inside[#inside + 1] = { type = "drop", key = "drop:" .. r.id, quest = r, text = "Starts from an item inside: " .. q.name }
			else
				local point, within, giver = pickupPlace(r.id, ctx, pos)
				giver = giver or (q.pickup and q.pickup.name)
				if point then
					placed[#placed + 1] = { type = "pickup", key = "pickup:" .. r.id, quest = r, point = point, giver = giver }
				elseif within then
					inside[#inside + 1] = { type = "pickup-inside", key = "pickup:" .. r.id, quest = r, text = "Pick up inside: " .. q.name .. (giver and (" (" .. giver .. ")") or "") }
				else
					local known = giver and not giver:lower():find("awaiting verification", 1, true)
					unplaced[#unplaced + 1] = { type = "pickup-unplaced", key = "pickup:" .. r.id, quest = r,
						text = "Pick up (place not in the reference): " .. q.name
							.. (known and (" — " .. giver .. ((q.pickup and q.pickup.zone) and (", " .. q.pickup.zone) or "")) or " — giver not recorded") }
				end
			end
		elseif r.code ~= "done" and r.code ~= "restricted" then
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
				item.text = plan.zones .. ". " .. best.zone .. " — pick up: " .. item.quest.quest.name .. (item.giver and (" (" .. item.giver .. ")") or "")
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
	section("Not available yet", later)
	local gear, gearNote = self:Gear(key)
	plan.gear, plan.gearNote = gear, gearNote
	for _, row in ipairs(gear) do
		local item = row.item
		row.text = (row.wished and "Wishlist: " or "Upgrade: ") .. item.name .. " · " .. row.slot[2] .. (row.boss and (" · " .. row.boss) or "")
			.. (row.delta and string.format(" · %+.1f", row.delta) or "") .. (row.later and (" · at level " .. row.later) or "")
	end
	section("Drops for your role" .. (gear.role and (" (" .. gear.role .. ")") or ""), gear)
	plan.turnins, plan.inside, plan.later = #turnins, #inside, #later
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
	return t == "pickup" or t == "pickup-inside" or t == "turnin" or t == "active" or (t == "entrance" and not API.InInstance())
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
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_LEVEL_UP" }) do FP:RegisterEvent(event, stale) end
	FP:On("QUESTLOG_SCANNED", function() self.memo = nil end)
end
