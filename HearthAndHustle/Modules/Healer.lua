-- HearthAndHustle / Modules / Healer.lua
-- Two aids for a healer, both read-only:
--   * a table of the healing spell ranks you know: mana, cast time, the amount
--     in the spell's own tooltip, and what that works out to per mana;
--   * a between-pull check for a five-player party: who is dead, offline or out
--     of heal range, and whether you have drinks and your own essentials.
-- Forever hides health, mana, debuffs, threat and cooldowns from addons, so
-- nothing here warns about them, nothing runs in combat, and nothing is cast
-- or targeted. The check only says what it could read.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Heal = FP:NewModule("Healer")

-- Spell ids by rank, the Classic ones. An id is used only when the client gives
-- it the same name as rank 1 of its family, so a wrong id drops a row instead
-- of mislabelling one.
--   cast  = base cast seconds by rank (the last value repeats)
--   learn = level each rank is learned at, where that is below 20
--   kind  = direct | chain (first target) | hot | mixed | aoe
Heal.SPELLS = {
	SHAMAN = {
		{ short = "HW", kind = "direct", ids = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357 }, cast = { 1.5, 2, 2.5, 3 }, learn = { 1, 6, 12, 18 } },
		{ short = "LHW", kind = "direct", ids = { 8004, 8008, 8010, 10466, 10467, 10468 }, cast = { 1.5 } },
		{ short = "CH", kind = "chain", ids = { 1064, 10622, 10623 }, cast = { 2.5 } },
	},
	PRIEST = {
		{ short = "LH", kind = "direct", ids = { 2050, 2052, 2053 }, cast = { 1.5, 2, 2.5 }, learn = { 1, 4, 10 } },
		{ short = "Heal", kind = "direct", ids = { 2054, 2055, 6063, 6064 }, cast = { 3 }, learn = { 16 } },
		{ short = "GH", kind = "direct", ids = { 2060, 10963, 10964, 10965, 25314 }, cast = { 3 } },
		{ short = "FH", kind = "direct", ids = { 2061, 9472, 9473, 9474, 10915, 10916, 10917 }, cast = { 1.5 } },
		{ short = "Renew", kind = "hot", duration = 15, ids = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315 }, learn = { 8, 14 } },
		{ short = "PoH", kind = "aoe", ids = { 596, 996, 10960, 10961, 25316 } },
	},
	DRUID = {
		{ short = "HT", kind = "direct", ids = { 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297 }, cast = { 1.5, 2, 2.5, 3, 3.5 }, learn = { 1, 8, 14 } },
		{ short = "Regrowth", kind = "mixed", ids = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 } },
		{ short = "Rejuv", kind = "hot", duration = 12, ids = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 }, learn = { 4, 10, 16 } },
	},
	PALADIN = {
		{ short = "HL", kind = "direct", ids = { 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292 }, cast = { 2.5 }, learn = { 1, 6, 14 } },
		{ short = "FoL", kind = "direct", ids = { 19750, 19939, 19940, 19941, 19942, 19943 }, cast = { 1.5 } },
	},
}
-- What a class needs in its bags to bring itself back.
local SELF_RES = { SHAMAN = { spell = 20608, item = 17030, item_name = "Ankh", spell_name = "Reincarnation" } }

local GCD = 1.5              -- seconds: an instant still costs this much time
local IMBUE_SOON = 300       -- seconds left before the imbue is worth a line
local SORTS = { "rank", "mana", "speed" }
local SORT_NAMES = { rank = "by spell and rank", mana = "most healing per mana first", speed = "most healing per second first" }

local function s() return FP.settings.healer end
local function nth(list, i) return list and (list[i] or list[#list]) or nil end
local function num(text) return tonumber((text:gsub(",", ""))) end

function Heal:Class() return API.GetCharInfo().class end
function Heal:CanHeal() return self.SPELLS[self:Class() or ""] ~= nil end
-- The role comes from the choice already made on the Best in slot page.
function Heal:IsHealer()
	if not self:CanHeal() then return false end
	local key = FP.Gear:Profile()
	return key == "healer"
end

-------------------------------------------------------------------------------
-- Rank table
-------------------------------------------------------------------------------
-- "…for 1017 to 1167." -> 1092 ; "…of 45 damage over 15 sec." -> hot 45 ;
-- "…for 84 to 99 and another 98 over 21 sec." -> 91.5 + hot 98.
function Heal.Parse(desc)
	if type(desc) ~= "string" then return nil end
	local lo, hi = desc:match("(%d[%d,]*) to (%d[%d,]*)")
	local direct = lo and hi and (num(lo) + num(hi)) / 2 or nil
	local over = desc:match("(%d[%d,]*)[^%d]- over %d+ sec")
	local hot = over and num(over) or nil
	if not direct and not hot then
		local single = desc:match("for (%d[%d,]*)")
		direct = single and num(single) or nil
	end
	return direct, hot
end

-- The Classic rule for how much of your bonus healing a spell uses: cast time
-- over 3.5 seconds (a heal over time: duration over 15), less for a rank
-- learned before level 20. Not confirmed on Forever; shown as an estimate.
function Heal:Coefficient(family, rank)
	local c
	if family.kind == "hot" then
		c = math.min(1, (family.duration or 15) / 15)
	elseif family.kind == "direct" or family.kind == "chain" then
		local cast = nth(family.cast, rank)
		if not cast then return nil end
		c = math.min(1, cast / 3.5)
	else
		return nil
	end
	local learned = family.learn and family.learn[rank]
	if learned and learned < 20 then c = c * (1 - (20 - learned) * 0.0375) end
	return c
end

-- Spells on the remembered action bars are known even if the spellbook lookup
-- only answers for the highest rank.
function Heal:BarSpells()
	local out = {}
	local specs = FP.cdb.barGuard and FP.cdb.barGuard.specs
	for _, spec in pairs(type(specs) == "table" and specs or {}) do
		for _, entry in pairs(type(spec) == "table" and type(spec.slots) == "table" and spec.slots or {}) do
			if type(entry) == "table" and entry.k == "spell" and type(entry.id) == "number" then out[entry.id] = true end
		end
	end
	return out
end

function Heal:Rows(all)
	local now, memo = API.Time(), self.memo
	if memo and memo.all == all and now - memo.t < 2 then return memo.rows, memo.bonus end
	local rows, bonus, onBars = {}, API.GetHealingBonus(), self:BarSpells()
	for order, family in ipairs(self.SPELLS[self:Class() or ""] or {}) do
		local base = API.GetSpellName(family.ids[1])
		for rank, id in ipairs(base and family.ids or {}) do
			local spell = API.GetHealSpell(id)
			if spell and spell.name == base then
				local known = API.KnowsSpell(id)
				local learned = known == true or onBars[id] == true
				if all or learned then
					local direct, hot = Heal.Parse(spell.desc)
					local heal = (direct or 0) + (hot or 0)
					local row = { key = id, id = id, family = family, order = order, index = rank, name = spell.name,
						rank = tonumber((spell.subtext or ""):match("%d+")) or rank, subtext = spell.subtext,
						learned = learned, cost = spell.cost, cast = spell.cast, direct = direct, hot = hot, heal = heal > 0 and heal or nil }
					if row.heal then
						row.coeff = bonus and self:Coefficient(family, rank) or nil
						row.est = row.coeff and (row.heal + bonus * row.coeff) or nil
						local value = row.est or row.heal
						if row.cost then row.perMana = value / row.cost end
						if row.cast and family.kind ~= "hot" then row.perSecond = value / math.max(row.cast, GCD) end
					end
					rows[#rows + 1] = row
				end
			end
		end
	end
	local best
	for _, row in ipairs(rows) do
		if row.learned and row.perMana and (not best or row.perMana > best.perMana) then best = row end
	end
	if best then best.best = true end
	self.memo = { all = all, t = now, rows = rows, bonus = bonus }
	self:NoteTooltip(rows, bonus)
	return rows, bonus
end

function Heal:Sorted(all, mode)
	local rows = self:Rows(all)
	local field = mode == "mana" and "perMana" or mode == "speed" and "perSecond" or nil
	table.sort(rows, function(a, b)
		if field and (a[field] or -1) ~= (b[field] or -1) then return (a[field] or -1) > (b[field] or -1) end
		if a.order ~= b.order then return a.order < b.order end
		return a.index > b.index
	end)
	return rows
end

function Heal:NextSort(mode)
	for i, name in ipairs(SORTS) do if name == mode then return SORTS[i % #SORTS + 1] end end
	return SORTS[1]
end
function Heal:SortName(mode) return SORT_NAMES[mode] or SORT_NAMES.rank end

local function amount(n) return n and string.format("%d", math.floor(n + 0.5)) or "?" end

-- Plain text: list rows are truncated, so no colour codes.
function Heal:RowLabel(row)
	local bits = { row.family.short .. " r" .. row.rank }
	bits[#bits + 1] = row.cost and (amount(row.cost) .. " mana") or "mana ?"
	if row.cast then bits[#bits + 1] = row.cast > 0 and string.format("%.1fs", row.cast) or "instant" end
	if row.heal then
		bits[#bits + 1] = "heals " .. amount(row.heal) .. (row.est and (" (est. " .. amount(row.est) .. ")") or "")
	else
		bits[#bits + 1] = "amount: see tooltip"
	end
	if row.perMana then bits[#bits + 1] = string.format("%.2f per mana", row.perMana) .. (row.best and " *" or "") end
	if not row.learned then bits[#bits + 1] = "not learned" end
	return table.concat(bits, " · ")
end

function Heal:RowDetails(row)
	if not row then return "Select a rank to see its numbers and a mouseover macro for it." end
	local lines = { FP.GOLD .. row.name .. (row.subtext and (" (" .. row.subtext .. ")") or (" rank " .. row.rank)) .. "|r"
		.. (row.learned and "" or FP.GREY .. "  not learned|r") }
	lines[#lines + 1] = "Mana " .. amount(row.cost) .. " · cast " .. (row.cast and (row.cast > 0 and string.format("%.1f sec", row.cast) or "instant") or "?")
	if row.heal then
		local parts = {}
		if row.direct then parts[#parts + 1] = amount(row.direct) .. (row.family.kind == "chain" and " on the first target" or row.family.kind == "aoe" and " on each target" or "") end
		if row.hot then parts[#parts + 1] = amount(row.hot) .. " over time" end
		lines[#lines + 1] = "Tooltip amount: " .. table.concat(parts, " + ")
		if row.est then
			lines[#lines + 1] = string.format("With your bonus healing: about %s (uses %d%% of it)", amount(row.est), math.floor(row.coeff * 100 + 0.5))
		elseif row.family.kind == "mixed" or row.family.kind == "aoe" then
			lines[#lines + 1] = FP.GREY .. "No bonus-healing estimate for this kind of spell.|r"
		end
		if row.perMana then lines[#lines + 1] = string.format("%.2f healing per mana", row.perMana) .. (row.best and FP.GREEN .. "  — the most per mana of the ranks you know|r" or "") end
		if row.perSecond then lines[#lines + 1] = string.format("%.0f healing per second of casting", row.perSecond) end
	else
		lines[#lines + 1] = "The amount could not be read from the tooltip text."
	end
	return table.concat(lines, "\n")
end

function Heal:BonusText()
	local _, bonus = self:Rows(false)
	return (bonus and ("Bonus healing from your gear: +" .. amount(bonus) .. ". ") or "Bonus healing could not be read right now. ")
		.. "Amounts are the spell tooltips' own numbers; \"est.\" adds your bonus healing by the Classic rule (cast time ÷ 3.5), which is not confirmed on Forever. * marks the most healing per mana."
end

-- One line to paste into a macro: heals what the mouse is over, else your
-- target, else you. The addon never creates or runs it.
function Heal:Macro(row)
	if not row then return "" end
	return "/cast [@mouseover,help,nodead][help,nodead][@player] " .. row.name .. (row.subtext and ("(" .. row.subtext .. ")") or "")
end

-------------------------------------------------------------------------------
-- Between-pull check
-------------------------------------------------------------------------------
function Heal:Applies()
	if not s().enabled then return false, "Healer tools are switched off." end
	if not self:CanHeal() then return false, "This character's class has no healing spells." end
	if not self:IsHealer() then return false, "Your gear role is not Healing. Choose it with Role on the Best in slot page to get the between-pull check." end
	return true
end

-- The highest learned rank of the class's main heal: its range is "heal range".
function Heal:RangeSpell()
	local now = API.Time()
	if self.range and now - self.range.t < 10 then return self.range.id end
	local found
	local family = (self.SPELLS[self:Class() or ""] or {})[1]
	local base = family and API.GetSpellName(family.ids[1])
	local onBars = base and self:BarSpells() or {}
	for i = base and #family.ids or 0, 1, -1 do
		local id = family.ids[i]
		if (API.KnowsSpell(id) == true or onBars[id]) and API.GetSpellName(id) == base then found = id; break end
	end
	self.range = { t = now, id = found }
	return found
end

local function kind(v) if v == nil then return "nil" end return type(v) end

-- Which reads answered, and where: read from the saved file after a session.
function Heal:NoteCheck(member, inRange)
	local store = FP.db.healer.seen
	local inside, instance = API.InInstance()
	local sig = "inst=" .. (inside and tostring(instance or "?") or "none") .. " dead=" .. kind(member.dead) .. " online=" .. kind(member.online)
		.. " visible=" .. kind(member.visible) .. " combat=" .. kind(member.combat) .. " range=" .. kind(inRange)
	local now = API.Time()
	self.noted = self.noted or {}
	if self.noted[sig] and now - self.noted[sig] < 30 then return end
	self.noted[sig] = now
	local rec = store[sig]
	if not rec then
		if U.Count(store) >= 30 then return end
		rec = { n = 0 }
		store[sig] = rec
	end
	rec.n, rec.t, rec.v = rec.n + 1, U.Now(), FP.version
end

-- Whether the tooltip amount moves with gear is unknown: keep a few samples.
function Heal:NoteTooltip(rows, bonus)
	local list, top = FP.db.healer.tooltip, nil
	-- the highest learned rank of the class's main heal
	for _, row in ipairs(rows) do
		if row.order == 1 and row.learned and row.heal and (not top or row.index > top.index) then top = row end
	end
	if not top then return end
	local last
	for i = #list, 1, -1 do if list[i].id == top.id then last = list[i]; break end end
	if not last or last.heal ~= top.heal or last.bonus ~= bonus then
		U.Push(list, { id = top.id, heal = top.heal, bonus = bonus, cost = top.cost, cast = top.cast, t = U.Now(), v = FP.version }, 12)
	end
end

-- { rows = HUD rows, problems = n } or nil plus the reason there is no check.
function Heal:Check()
	local ok, why = self:Applies()
	if not ok then return nil, why end
	if self.combat or API.InCombat() then return nil, "In combat: the check waits until the pull is over." end
	if API.InRaid() then return nil, "In a raid group: the check covers five-player parties." end
	local party = API.InGroup() and API.GetPartyStatus() or {}
	if #party == 0 then return nil, "Not in a party." end
	local rows, problems, alive, ranged = {}, 0, 0, true
	local function add(text) problems = problems + 1; rows[#rows + 1] = { text = text } end
	local spell = self:RangeSpell()
	for i, m in ipairs(party) do
		local inRange
		if m.online ~= false and m.dead ~= true then
			if spell then inRange = API.SpellInRange(spell, m.unit) end
			if inRange == nil then ranged = false end
		end
		if i == 1 then self:NoteCheck(m, inRange) end
		local name = U.Truncate(m.name, 24)
		if m.online == false then add(FP.GREY .. name .. ": offline|r")
		elseif m.dead == true then add(FP.RED .. name .. ": dead|r")
		else
			alive = alive + 1
			if m.visible == false or inRange == false then add(FP.GOLD .. name .. ": out of heal range|r")
			elseif m.combat == true then add(FP.GOLD .. name .. ": still in combat|r") end
		end
	end
	-- Your own essentials.
	local mine, group = FP.cdb.healer.specGroup, API.ActiveSpecGroup()
	if mine and group and group ~= mine then add(FP.RED .. "Not your healing spec (spec " .. group .. " is active)|r") end
	local extras = {}
	local inv = FP.ClassPrep and FP.ClassPrep.inventory
	if inv and inv.waterKnown then
		if inv.water <= (s().water or 4) then add(FP.GOLD .. "Drinks: " .. inv.water .. " left|r")
		else extras[#extras + 1] = inv.water .. " drinks" end
	end
	local res = SELF_RES[self:Class() or ""]
	if res and API.KnowsSpell(res.spell) == true then
		local count = API.GetBagItemCount(res.item)
		if count == 0 then add(FP.GOLD .. "No " .. res.item_name .. ": " .. res.spell_name .. " needs one|r")
		elseif count then extras[#extras + 1] = count .. " " .. res.item_name end
	end
	local imbues = FP.InfoBar and FP.InfoBar.IMBUES and FP.InfoBar.IMBUES[self:Class() or ""]
	if imbues then
		local knows = false
		for _, id in ipairs(imbues) do if API.KnowsSpell(id) == true then knows = true; break end end
		local imb = knows and API.GetWeaponImbues() or nil
		if imb and imb.has_main then
			if not imb.main then add(FP.GOLD .. "Weapon imbue: none|r")
			elseif imb.main.remaining and imb.main.remaining < IMBUE_SOON then add(FP.GOLD .. "Weapon imbue: " .. U.FormatTime(imb.main.remaining) .. " left|r") end
		end
	end
	-- Inside a dungeon an all-clear is worth a line; in the open world silence is.
	if problems == 0 and API.InInstance() then
		rows[1] = { text = FP.GREEN .. "Party ready: " .. alive .. " of " .. #party .. " alive" .. (ranged and spell and ", in heal range" or "")
			.. (#extras > 0 and (" · " .. table.concat(extras, " · ")) or "") .. "|r" }
	end
	return { rows = rows, problems = problems, alive = alive, size = #party }
end

function Heal:Lines()
	if not s().strip then return {} end
	local check = self:Check()
	return check and check.rows or {}
end

-- What the page says above the table.
function Heal:StatusText()
	local lines = {}
	local check, why = self:Check()
	if check then
		lines[#lines + 1] = FP.GREEN .. "Between-pull check: " .. (check.problems == 0 and "nothing to report" or (check.problems .. " thing" .. (check.problems == 1 and "" or "s") .. " to look at")) .. "|r"
		for i, row in ipairs(check.rows) do if i <= 5 then lines[#lines + 1] = "  " .. row.text end end
	else
		lines[#lines + 1] = "Between-pull check: " .. tostring(why)
	end
	local mine, group = FP.cdb.healer.specGroup, API.ActiveSpecGroup()
	lines[#lines + 1] = mine and ("Healing spec: spec " .. mine .. (group == mine and " (active now)" or (group and (", but spec " .. group .. " is active") or "")))
		or "Healing spec: not marked. Click \"This spec is my healing spec\" while you are in it to be told when you join a party in the other one."
	local hud = FP.settings.pvp
	if s().strip and (not hud.enabled or hud.manual == "hide") then
		lines[#lines + 1] = FP.GOLD .. "The HUD is hidden, so the check shows only on this page. PvP page: Show HUD or Automatic.|r"
	end
	return table.concat(lines, "\n")
end

function Heal:MarkSpec(clear)
	if clear then FP.cdb.healer.specGroup = nil; FP:Print("Healing spec forgotten."); return end
	local group = API.ActiveSpecGroup()
	if not group then FP:Print("The active spec could not be read. Try again out of combat."); return end
	FP.cdb.healer.specGroup = group
	FP:Print("Spec " .. group .. " marked as your healing spec for this character.")
end

function Heal:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	if sub == "on" or sub == "off" then
		s().enabled = sub == "on"
		FP:Print("Healer tools " .. sub .. ".")
	elseif sub == "strip" or sub == "check" then
		if val == "on" or val == "off" then s().strip = val == "on" else s().strip = not s().strip end
		FP:Print("Between-pull check on the HUD: " .. (s().strip and "on" or "off") .. ".")
	elseif sub == "spec" then
		self:MarkSpec(val == "clear" or val == "off")
	elseif sub == "ranks" then
		if not self:CanHeal() then FP:Print("This character's class has no healing spells."); return end
		local rows = self:Sorted(val == "all", "rank")
		FP:Print(FP.GOLD .. "Heal ranks|r" .. (val == "all" and " (every rank)" or " (ranks you know)"))
		for _, row in ipairs(rows) do FP:Print("  " .. self:RowLabel(row)) end
		if #rows == 0 then FP:Print("  No healing spell could be read yet.") end
		FP:Print(self:BonusText())
	elseif sub == "" then
		local check, why = self:Check()
		if not check then FP:Print("Between-pull check: " .. tostring(why))
		elseif #check.rows == 0 then FP:Print("Between-pull check: nothing to report (" .. check.alive .. " of " .. check.size .. " alive).")
		else for _, row in ipairs(check.rows) do FP:Print(row.text) end end
	else
		FP:Print("/hh heal | on | off | strip on|off | spec | spec clear | ranks [all]")
		return
	end
	self.memo = nil
	FP:Fire("PVP_CHANGED")
end

function Heal:OnEnable()
	self.combat = API.InCombat()
	FP.PvP:RegisterSection("Healer check (between pulls)", 4, function() return Heal:Lines() end)
	local function changed() FP:Fire("PVP_CHANGED") end
	FP:RegisterEvent("PLAYER_REGEN_DISABLED", function() self.combat = true; changed() end)
	FP:RegisterEvent("PLAYER_REGEN_ENABLED", function() self.combat = false; FP.After(0.5, changed) end)
	FP:RegisterEvent("GROUP_ROSTER_UPDATE", changed)
	FP:RegisterEvent("SPELLS_CHANGED", function() self.memo, self.range = nil, nil end)
	-- The HUD's own ticker stops while it is hidden: look every few seconds so a
	-- death or a straggler brings the check up without waiting for an event.
	if C_Timer and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(3, function()
			local ok, err = pcall(function()
				if not s().strip or self.combat or not API.InGroup() or not self:Applies() then return end
				local check = self:Check()
				local sig = check and (check.problems .. ":" .. #check.rows) or ""
				if sig ~= self.lastSig then self.lastSig = sig; changed() end
			end)
			if not ok then FP:ReportError("healer-tick", err) end
		end)
	end
end
