-- ForeverPath / Prof / Tracker.lua
-- Profession skill tracking + recipe/reagent snapshots (Phase 3 seed).
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local T = FP:NewModule("Prof")

local DIFF_NAMES = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "gray" }
local DIFF_COLORS = { [0] = "|cffff8040", [1] = "|cffffff00", [2] = "|cff40bf40", [3] = "|cff808080" }
T.DIFF_NAMES, T.DIFF_COLORS = DIFF_NAMES, DIFF_COLORS

local queue = {}
local queueRunning = false
local generation = 0

function T:OnEnable()
	self:Snapshot()
	local function refresh()
		FP.Throttle("prof-scan", 0.5, function() T:ScanRecipes() end)
	end
	local function skillChanged()
		FP.Throttle("prof-snap", 1, function() T:Snapshot(); if not T.windowClosed then T:ScanRecipes() end end)
	end
	FP:RegisterEvent("TRADE_SKILL_CLOSE", function() generation = generation + 1; queue = {}; self.windowClosed = true end)
	FP:On("RECORDING_CHANGED", function() generation = generation + 1; queue = {}; self:Snapshot(); self:ScanRecipes() end)
	FP:RegisterEvent("SKILL_LINES_CHANGED", skillChanged)
	FP:RegisterEvent("CHAT_MSG_SKILL", skillChanged)
	FP:RegisterEvent("TRADE_SKILL_SHOW", function() self.windowClosed = false; refresh() end)
	FP:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGING", function() generation = generation + 1; queue = {}; self.open = nil end)
	for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_NAME_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
		FP:RegisterEvent(event, refresh)
	end
	FP:RegisterEvent("BAG_UPDATE_DELAYED", function() FP:Fire("PROFESSIONS_CHANGED") end)
end

function T:Snapshot()
	local profs = API.GetProfessions()
	local changed = false
	for _, p in ipairs(profs) do
		if p.name and p.rank then
			local old = FP.cdb.professions[p.name]
			if not old or old.rank ~= p.rank or old.max ~= p.maxRank then changed = true end
			if FP.settings.record then FP.cdb.professions[p.name] = { rank = p.rank, max = p.maxRank, line = p.skillLine, t = U.Now() } end
		end
	end
	self.list = profs
	if self.open then
		for _, p in ipairs(profs) do
			if (p.skillLine == self.open.id or p.name == self.open.name) and p.rank ~= self.open.skill then self.open.stale = true end
		end
	end
	if changed then FP:Fire("PROFESSIONS_CHANGED", profs) end
	return profs
end

function T:Summary()
	local parts = {}
	for _, p in ipairs(self.list or {}) do
		if p.name and p.rank then parts[#parts + 1] = string.format("%s %d/%d", p.name, p.rank, p.maxRank or 0) end
	end
	if #parts == 0 then return FP.GREY .. "no professions|r" end
	return table.concat(parts, " · ")
end

local function saveRecipe(job)
	if not FP.settings.record or job.epoch ~= FP.recordEpoch then return end
	local info, r = job.info, job.rec
	local saved = FP.data.recipes[info.professionID] or { r = {} }
	FP.data.recipes[info.professionID] = saved
	saved.n, saved.parent, saved.pn = info.professionName, info.parentProfessionID, info.parentProfessionName
	saved.skill, saved.max, saved.t = info.skillLevel, info.maxSkillLevel, U.Now()
	local old = saved.r[job.id]
	local entry = U.Copy(r)
	-- Preserve previous evidence if a later schema lookup is temporarily unavailable.
	if not r.reag and old then entry.reag, entry.out, entry.qmin, entry.qmax = old.reag, old.out, old.qmin, old.qmax end
	entry.diff = old and U.Copy(old.diff or {}) or {}
	if r.cur ~= nil then entry.diff[tostring(info.skillLevel or 0)] = r.cur end
	entry.learned = nil -- learned state is character-specific, never an account-wide claim
	saved.r[job.id] = entry
	for itemID in pairs(r.reag or {}) do
		FP.data.items[itemID] = FP.data.items[itemID] or {}
		FP.data.items[itemID].n = FP.data.items[itemID].n or API.GetItemName(itemID)
	end
	if r.out then
		FP.data.items[r.out] = FP.data.items[r.out] or {}
		FP.data.items[r.out].n = FP.data.items[r.out].n or API.GetItemName(r.out)
	end
	FP.db.meta.counters.recipes = (FP.db.meta.counters.recipes or 0) + 1
end

local function pumpQueue()
	if queueRunning then return end
	queueRunning = true
	local function step()
		local open = API.GetOpenTradeSkill()
		local n = 0
		while #queue > 0 and n < 20 do
			local job = table.remove(queue, 1)
			n = n + 1
			if job.generation == generation and open and open.professionID == job.info.professionID then
				local schematic = API.GetRecipeReagents(job.id)
				if schematic then
					job.rec.reag, job.rec.out = schematic.reagents, schematic.outputItemID
					job.rec.qmin, job.rec.qmax = schematic.qtyMin, schematic.qtyMax
				end
				saveRecipe(job)
			end
		end
		if #queue > 0 then FP.After(0.05, function()
			local ok, err = pcall(step)
			if not ok then queueRunning = false; FP:ReportError("prof-queue", err) end
		end)
		else queueRunning = false; FP:Fire("RECIPES_SCANNED") end
	end
	local ok, err = pcall(step)
	if not ok then queueRunning = false; FP:ReportError("prof-queue", err) end
end

function T:ScanRecipes(attempt)
	if self.windowClosed then return end
	generation = generation + 1
	queue = {}
	local scanGeneration = generation
	local function retry()
		if (attempt or 0) >= 3 then return end
		FP.After(1, function()
			if generation == scanGeneration and not T.windowClosed then T:ScanRecipes((attempt or 0) + 1) end
		end)
	end
	local info = API.GetOpenTradeSkill()
	if not info then self.open = nil; retry(); FP:Fire("RECIPES_SCANNED"); return end
	self.open = { id = info.professionID, name = info.professionName, skill = info.skillLevel, max = info.maxSkillLevel, recipes = {} }
	for _, id in ipairs(API.GetTradeSkillRecipeIDs()) do
		local ri = API.GetRecipeInfo(id)
		if ri and ri.recipeID and ri.learned then
			local r = { n = ri.name, ups = ri.numSkillUps, cat = ri.categoryID, icon = ri.icon, cur = ri.relativeDifficulty, disabled = ri.disabled, canSkillUp = ri.canSkillUp }
			self.open.recipes[#self.open.recipes + 1] = { id = id, rec = r, diff = ri.relativeDifficulty, name = ri.name }
			queue[#queue + 1] = { id = id, rec = r, info = info, epoch = FP.recordEpoch, generation = generation }
		end
	end
	if #queue > 0 then pumpQueue() else retry(); FP:Fire("RECIPES_SCANNED") end
end

-- Craftable count from bags for a recipe record with reagents.
function T:Craftable(r)
	if not r.reag then return nil end
	local best
	for itemID, need in pairs(r.reag) do
		if not U.Finite(need) or need <= 0 then return nil end
		local have = API.GetItemCount(itemID, false)
		local n = math.floor(have / need)
		if not best or n < best then best = n end
	end
	return best or 0
end

-- Recipes worth crafting for skill-ups, best first. Requires the trade skill window to have been opened this session.
function T:BestCrafts(limit)
	local open = self.open
	if not open then return nil end
	local list = {}
	if open.stale or (open.max and open.max > 0 and open.skill and open.skill >= open.max) then return list, open end
	for _, e in ipairs(open.recipes) do
		if e.diff ~= nil and e.diff >= 0 and e.diff <= 2 and not e.rec.disabled and e.rec.canSkillUp ~= false then
			local craftable = self:Craftable(e.rec)
			list[#list + 1] = { name = e.name, diff = e.diff, craftable = craftable, rec = e.rec, id = e.id }
		end
	end
	table.sort(list, function(a, b)
		local ac, bc = (a.craftable or 0) > 0, (b.craftable or 0) > 0
		if ac ~= bc then return ac end
		if a.diff ~= b.diff then return a.diff < b.diff end
		if (a.craftable or 0) ~= (b.craftable or 0) then return (a.craftable or 0) > (b.craftable or 0) end
		return tostring(a.name) < tostring(b.name)
	end)
	local out = {}
	for i = 1, math.min(limit or 12, #list) do out[i] = list[i] end
	return out, open
end

function T:MissingFor(r, crafts)
	local parts = {}
	if not r.reag then return "" end
	for itemID, need in pairs(r.reag) do
		local have = API.GetItemCount(itemID, false)
		local want = need * crafts
		if have < want then
			local name = (FP.data.items[itemID] and FP.data.items[itemID].n) or API.GetItemName(itemID) or ("item " .. itemID)
			parts[#parts + 1] = string.format("%d× %s", want - have, name)
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- Visible guidance for the most recently opened profession; quantities mean
-- crafts supported by bag materials, not guaranteed skill points or profit.
function T:Guidance(limit)
	local list, open = self:BestCrafts(limit or 3)
	if not list then return { "Open Tailoring or Enchanting (or another profession) for craft suggestions." } end
	if open.stale then return { tostring(open.name) .. ": skill changed; reopen the profession to refresh." } end
	if open.max and open.max > 0 and open.skill and open.skill >= open.max then
		return { tostring(open.name) .. ": at the current skill cap. Check your trainer before crafting for skill." }
	end
	if #open.recipes == 0 then return { tostring(open.name) .. ": recipes not loaded; keep your profession window open." } end
	if #list == 0 then return { tostring(open.name) .. ": no usable skill-up recipes found. Check your trainer." } end
	local lines = { tostring(open.name) .. " — skill-up suggestions (bag materials):" }
	for _, e in ipairs(list) do
		local color = DIFF_COLORS[e.diff] or ""
		lines[#lines + 1] = color .. U.Truncate(e.name, 35) .. "|r" .. (e.craftable and (" ×" .. e.craftable .. " crafts") or " — materials unknown")
		if e.craftable == 0 then lines[#lines + 1] = "Need: " .. self:MissingFor(e.rec, 1) end
	end
	return lines
end
