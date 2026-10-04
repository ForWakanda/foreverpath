-- ForeverPath / PvP / Roster.lua
-- Enemy players you have seen: name, class, race, level, last seen, what you
-- used on them. Identity of enemy PLAYERS is readable in PvP on Forever; NPC
-- identity in combat is not, so every read is secret-guarded and NPCs are
-- skipped. In a battleground the scoreboard adds the enemy team composition.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local R = FP:NewModule("Roster")

local MAX_LINES = 8
local RECENT = 120
R.session = {}   -- [name] = { class, race, level, last, first, seen, note, noteT }

local function classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and c.colorStr then return "|c" .. c.colorStr end
	return "|cffffffff"
end

local function prettyClass(class)
	if not class then return "?" end
	return class:sub(1, 1) .. class:sub(2):lower()
end

function R:Observe(unit)
	if not FP.PvP:IsHostilePlayer(unit) then return nil end
	local name = FP.safe(UnitName(unit))
	if type(name) ~= "string" then return nil end
	local _, class = UnitClass(unit)
	local _, race = UnitRace(unit)
	class, race = FP.safe(class), FP.safe(race)
	local level = FP.safe(UnitLevel(unit))
	local now = U.Now()
	local e = self.session[name]
	if not e then e = { first = now, seen = 0 }; self.session[name] = e end
	e.class, e.race = class or e.class, race or e.race
	if type(level) == "number" and level > 0 then e.level = level end
	e.last, e.seen = now, e.seen + 1
	-- persistent dataset
	if FP.settings.record then
		local d = FP.data.pvp.players
		local p = d[name]
		if not p then p = { first = now, seen = 0 }; d[name] = p end
		p.class, p.race, p.level, p.last, p.seen = e.class, e.race, e.level, now, p.seen + 1
	end
	FP:Fire("PVP_CHANGED")
	return e
end

function R:Note(target, spell, text)
	if not target then return end
	local e = self.session[target]
	if not e then return end
	e.note, e.noteT = spell .. (text and (" " .. text) or ""), U.Now()
end

function R:OnTargetDied()
	if not FP.PvP:IsHostilePlayer("target") then return end
	local name = FP.safe(UnitName("target"))
	if type(name) ~= "string" then return end
	local p = FP.data.pvp.players[name]
	if p and FP.settings.record then p.diedTargeted = (p.diedTargeted or 0) + 1 end
	local e = self.session[name]
	if e then e.note, e.noteT = "died", U.Now() end
	FP:Fire("PVP_CHANGED")
end

-- Battleground scoreboard: names/classes/factions are never-secret fields.
function R:Scoreboard()
	if type(GetNumBattlefieldScores) ~= "function" or not (C_PvP and C_PvP.GetScoreInfo) then return end
	local myFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
	local comp, count = {}, 0
	for i = 1, (GetNumBattlefieldScores() or 0) do
		local ok, info = pcall(C_PvP.GetScoreInfo, i)
		if ok and type(info) == "table" then
			local faction = FP.safe(info.faction)
			local factionName = (PLAYER_FACTION_GROUP and faction ~= nil) and PLAYER_FACTION_GROUP[faction] or nil
			local class = FP.safe(info.classToken)
			local name = FP.safe(info.name)
			if factionName and myFaction and factionName ~= myFaction then
				comp[class or "?"] = (comp[class or "?"] or 0) + 1
				count = count + 1
				if type(name) == "string" then
					local e = self.session[name]
					if not e then e = { first = U.Now(), seen = 0 }; self.session[name] = e end
					e.class = class or e.class
					e.race = FP.safe(info.raceName) or e.race
					e.fromScore = true
				end
			end
		end
	end
	if count > 0 then self.enemyComp = comp; self.enemyCount = count; FP:Fire("PVP_CHANGED") end
end

function R:Lines()
	local lines = {}
	local now = U.Now()
	local list = {}
	for name, e in pairs(self.session) do
		if e.last and now - e.last <= RECENT then list[#list + 1] = { name = name, e = e } end
	end
	table.sort(list, function(a, b) return (a.e.last or 0) > (b.e.last or 0) end)
	for i = 1, math.min(MAX_LINES, #list) do
		local e = list[i].e
		local ago = now - (e.last or now)
		local note = (e.note and e.noteT and now - e.noteT < 60) and (FP.GREY .. "  " .. e.note .. "|r") or ""
		lines[#lines + 1] = { text = string.format("%s%s|r %s%s %s%s", classColor(e.class), list[i].name, FP.GREY .. prettyClass(e.class), e.level and (" " .. e.level) or "", ago < 5 and "now" or (math.floor(ago) .. "s"), note) }
	end
	if self.enemyComp and FP.PvP:InBattleground() then
		local parts = {}
		for class, n in pairs(self.enemyComp) do parts[#parts + 1] = n .. " " .. prettyClass(class) end
		table.sort(parts)
		lines[#lines + 1] = { text = FP.GREY .. "enemy team: " .. table.concat(parts, ", ") .. "|r" }
	end
	return lines
end

function R:ClearSession()
	self.session = {}
	self.enemyComp, self.enemyCount = nil, nil
end

function R:Summary()
	return string.format("%d enemy players this session, %d recorded overall", U.Count(self.session), U.Count(FP.data.pvp.players))
end

function R:OnEnable()
	FP:RegisterEvent("PLAYER_TARGET_CHANGED", function() R:Observe("target") end)
	FP:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() FP.Throttle("roster-mouseover", 0.5, function() R:Observe("mouseover") end) end)
	FP:RegisterEvent("PLAYER_TARGET_DIED", function() R:OnTargetDied() end)
	FP:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", function() FP.Throttle("roster-score", 3, function() R:Scoreboard() end) end)
	FP.PvP:RegisterSection("Enemies seen", 30, function() return R:Lines() end)
end
