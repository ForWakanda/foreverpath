-- HearthAndHustle / Modules / Trainer.lua
-- "What's Training?"-style notes (v0.8.0), built on the trainer services the
-- recorder already stores. At a trainer: what you can learn now and what it
-- costs against your gold, and the next level that unlocks something. On a
-- level-up: which recorded trainer teaches something at the new level.
-- Reads and prints only; the player trains.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local T = FP:NewModule("Trainer")

local function s() return FP.settings.trainer end

local function myClass() return API.GetCharInfo().class end

-- Available services at the open trainer, sorted by level then name.
function T:Summary()
	local services, tradeskill = API.GetTrainerServices()
	local level = API.PlayerLevel()
	local now, soon, total = {}, {}, 0
	local nextLevel
	for _, sv in ipairs(services) do
		if sv.type == "available" then
			now[#now + 1] = sv
			if U.Finite(sv.cost) then total = total + sv.cost end
		elseif sv.type == "unavailable" and U.Finite(sv.level) and U.Finite(level) and sv.level > level then
			if not nextLevel or sv.level < nextLevel then nextLevel = sv.level end
		end
	end
	for _, sv in ipairs(services) do
		if sv.type == "unavailable" and nextLevel and sv.level == nextLevel then soon[#soon + 1] = sv end
	end
	table.sort(now, function(a, b) if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end return tostring(a.name) < tostring(b.name) end)
	table.sort(soon, function(a, b) return tostring(a.name) < tostring(b.name) end)
	return { now = now, soon = soon, total = total, nextLevel = nextLevel, tradeskill = tradeskill, money = API.GetMoney() }
end

local function names(list, max)
	local out = {}
	for i = 1, math.min(#list, max) do
		local sv = list[i]
		out[#out + 1] = tostring(sv.name) .. (sv.sub and sv.sub ~= "" and (" (" .. tostring(sv.sub) .. ")") or "") .. (U.Finite(sv.cost) and sv.cost > 0 and (" " .. U.MoneyString(sv.cost)) or "")
	end
	if #list > max then out[#out + 1] = "… +" .. (#list - max) end
	return table.concat(out, ", ")
end

function T:OnTrainer()
	if not s().enabled then return end
	local sum = self:Summary()
	self.last = sum
	local key = tostring(#sum.now) .. ":" .. tostring(sum.total) .. ":" .. tostring(sum.nextLevel)
	if self.printedKey == key then return sum end       -- TRAINER_UPDATE repeats
	self.printedKey = key
	if #sum.now == 0 then
		FP:Print("Trainer: nothing new to learn here" .. (sum.nextLevel and (" — next at level " .. sum.nextLevel .. ": " .. names(sum.soon, 4)) or "") .. ".")
	else
		local afford = sum.money and (sum.money >= sum.total and FP.GREEN .. "you can afford all|r" or FP.GOLD .. "you have " .. U.MoneyString(sum.money) .. "|r") or ""
		FP:Print(string.format("Trainer: %d available now for %s%s — %s", #sum.now, U.MoneyString(sum.total), afford ~= "" and (" (" .. afford .. ")") or "", names(sum.now, 8)))
		if sum.nextLevel then FP:Print(FP.GREY .. "Next at level " .. sum.nextLevel .. ": " .. names(sum.soon, 4) .. "|r") end
	end
	return sum
end

-- Recorded class trainers (this class) teaching something exactly at `level`.
function T:NotesForLevel(level)
	local out = {}
	local class = myClass()
	for id, t in pairs(FP.data.trainers or {}) do
		if not t.tradeskill and (t.class == class) then
			local list, total = {}, 0
			for name, sv in pairs(t.services or {}) do
				if U.Finite(sv.lvl) and sv.lvl == level then
					list[#list + 1] = { name = name, cost = sv.cost, sub = sv.sub }
					if U.Finite(sv.cost) then total = total + sv.cost end
				end
			end
			if #list > 0 then
				table.sort(list, function(a, b) return a.name < b.name end)
				out[#out + 1] = { npc = id, trainer = t.n, list = list, total = total }
			end
		end
	end
	table.sort(out, function(a, b) return tostring(a.trainer) < tostring(b.trainer) end)
	return out
end

function T:OnLevelUp(level)
	if not s().enabled or not U.Finite(level) then return end
	local notes = self:NotesForLevel(level)
	if #notes == 0 then return 0 end
	-- Several recorded trainers of the same class teach the same list: print once.
	local n = notes[1]
	FP:Print(string.format("%sLevel %d:|r %d new spell%s at your class trainer (recorded at %s) — %s%s", FP.GOLD, level, #n.list, #n.list == 1 and "" or "s", tostring(n.trainer or "trainer"), names(n.list, 6), n.total > 0 and (" · total " .. U.MoneyString(n.total)) or ""))
	return #n.list
end

function T:OnEnable()
	FP:RegisterEvent("TRAINER_SHOW", function() FP.After(0.6, function() T:OnTrainer() end) end)
	FP:RegisterEvent("TRAINER_UPDATE", function() FP.Throttle("trainer-notes", 1, function() T:OnTrainer() end) end)
	FP:RegisterEvent("TRAINER_CLOSED", function() T.printedKey = nil end)
	FP:On("LEVEL_UP", function(level) FP.After(1, function() T:OnLevelUp(level) end) end)
end

function T:Command(rest)
	local sub = (rest or ""):lower()
	if sub == "on" then s().enabled = true; FP:Print("trainer notes on")
	elseif sub == "off" then s().enabled = false; FP:Print("trainer notes off")
	else
		local level = API.PlayerLevel()
		local n = tonumber(sub) or (U.Finite(level) and level + 1) or nil
		if not n then FP:Print("/hh trainer [level|on|off]"); return end
		local notes = self:NotesForLevel(n)
		if #notes == 0 then FP:Print("No recorded " .. tostring(myClass()) .. " trainer teaches anything at level " .. n .. " yet (visit a class trainer once with recording on).")
		else
			for _, note in ipairs(notes) do FP:Print(string.format("Level %d at %s: %s%s", n, tostring(note.trainer), names(note.list, 10), note.total > 0 and (" · total " .. U.MoneyString(note.total)) or "")) end
		end
	end
end
