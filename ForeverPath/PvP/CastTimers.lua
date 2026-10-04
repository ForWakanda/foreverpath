-- ForeverPath / PvP / CastTimers.lua
-- Timers driven ONLY by your own successful casts (own casts are never secret):
-- crowd control durations with a diminishing-returns estimate per target,
-- interrupt lockouts, roots. Durations come from the spell's own tooltip text
-- when available, else from the table. Whether a CC actually landed, resisted
-- or broke early is unknown to addons on Forever, so these are estimates.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local CT = FP:NewModule("CastTimers")

-- kind: cc (DR-eligible control), root, lockout (school lock after an interrupt), buff (self)
-- dr: vanilla-style diminishing category. base: fallback seconds.
CT.SPELLS = {
	-- Mage
	["Polymorph"]          = { kind = "cc",      dr = "polymorph",  base = 20 },
	["Frost Nova"]         = { kind = "root",    area = true,       base = 8 },
	["Counterspell"]       = { kind = "lockout", base = 10 },
	["Ice Block"]          = { kind = "buff",    base = 10 },
	["Blink"]              = { kind = "note",    base = 0 },
	-- Hunter
	["Scatter Shot"]       = { kind = "cc",      dr = "disorient",  base = 4 },
	["Wyvern Sting"]       = { kind = "cc",      dr = "sleep",      base = 12 },
	["Intimidation"]       = { kind = "cc",      dr = "stun",       base = 3 },
	["Concussive Shot"]    = { kind = "note",    base = 4 },
	["Freezing Trap"]      = { kind = "trap",    base = 60 },
	["Feign Death"]        = { kind = "note",    base = 0 },
	-- Rogue
	["Kidney Shot"]        = { kind = "cc",      dr = "stun",       base = 6 },
	["Cheap Shot"]         = { kind = "cc",      dr = "stun",       base = 4 },
	["Gouge"]              = { kind = "cc",      dr = "disorient",  base = 4 },
	["Blind"]              = { kind = "cc",      dr = "blind",      base = 10 },
	["Sap"]                = { kind = "cc",      dr = "sap",        base = 25 },
	["Kick"]               = { kind = "lockout", base = 5 },
	-- Warrior
	["Pummel"]             = { kind = "lockout", base = 4 },
	["Shield Bash"]        = { kind = "lockout", base = 6 },
	["Intimidating Shout"] = { kind = "cc",      dr = "fear",       base = 8 },
	["Charge"]             = { kind = "cc",      dr = "stun",       base = 1 },
	["Hamstring"]          = { kind = "note",    base = 15 },
	-- Priest / Warlock / Druid / Paladin / Shaman
	["Psychic Scream"]     = { kind = "cc",      dr = "fear",       base = 8 },
	["Mind Control"]       = { kind = "cc",      dr = "charm",      base = 60 },
	["Silence"]            = { kind = "lockout", base = 5 },
	["Fear"]               = { kind = "cc",      dr = "fear",       base = 10 },
	["Howl of Terror"]     = { kind = "cc",      dr = "fear",       base = 10 },
	["Death Coil"]         = { kind = "cc",      dr = "horror",     base = 3 },
	["Seduction"]          = { kind = "cc",      dr = "fear",       base = 15 },
	["Spell Lock"]         = { kind = "lockout", base = 6 },
	["Entangling Roots"]   = { kind = "root",    dr = "root",       base = 12 },
	["Hibernate"]          = { kind = "cc",      dr = "sleep",      base = 20 },
	["Bash"]               = { kind = "cc",      dr = "stun",       base = 4 },
	["Cyclone"]            = { kind = "cc",      dr = "cyclone",    base = 6 },
	["Hammer of Justice"]  = { kind = "cc",      dr = "stun",       base = 6 },
	["Repentance"]         = { kind = "cc",      dr = "disorient",  base = 6 },
	["Earth Shock"]        = { kind = "lockout", base = 2 },
}

local DR_FACTORS = { 1, 0.5, 0.25 }
local DR_RESET = 15
local MAX_TIMERS = 14

CT.active = {}       -- { spell, spellID, icon, target, owner, start, duration, kind, drText, castGUID }
CT.dr = {}           -- [targetName][category] = { n, resetAt }
CT.parsed = {}       -- spellID -> seconds parsed from the tooltip (or false if not parseable)
local sent = {}      -- castGUID -> { spellID, target, t }

local function spellDef(name)
	return name and CT.SPELLS[name] or nil
end

-- "…forcing it to wander around for up to 20 sec." -> 20 ; "…cannot be cast for 10 sec." -> 10
function CT:ParseDuration(spellID)
	if self.parsed[spellID] ~= nil then return self.parsed[spellID] or nil end
	local desc = API.GetSpellDescription(spellID)
	if type(desc) ~= "string" or desc == "" then return nil end   -- not loaded yet; try again next cast
	local secs = desc:match("for up to (%d+%.?%d*) sec") or desc:match("for (%d+%.?%d*) sec") or desc:match("lasting (%d+%.?%d*) sec") or desc:match("(%d+%.?%d*) sec")
	secs = tonumber(secs)
	self.parsed[spellID] = secs or false
	return secs
end

function CT:DRApply(target, category, base)
	if not target or not category then return base, nil end
	local byTarget = self.dr[target]
	if not byTarget then byTarget = {}; self.dr[target] = byTarget end
	local st = byTarget[category]
	local now = GetTime()
	if not st or now > st.resetAt then st = { n = 0, resetAt = 0 }; byTarget[category] = st end
	local factor = DR_FACTORS[st.n + 1] or 0
	local duration = base * factor
	st.n = st.n + 1
	st.resetAt = now + duration + DR_RESET
	local text
	if factor == 1 then text = "DR full" elseif factor == 0.5 then text = "DR ½" elseif factor == 0.25 then text = "DR ¼" else text = "IMMUNE" end
	return duration, text, factor
end

function CT:DRState(target, category)
	local st = self.dr[target] and self.dr[target][category]
	if not st or GetTime() > st.resetAt then return "full" end
	return ({ [1] = "½ next", [2] = "¼ next", [3] = "immune" })[st.n] or "immune"
end

function CT:Start(entry)
	entry.start = entry.start or GetTime()
	U.Push(self.active, entry, MAX_TIMERS)
	FP:Fire("PVP_TIMER_STARTED", entry)
	FP:Fire("PVP_CHANGED")
	return entry
end

function CT:OnSent(unit, target, castGUID, spellID)
	if unit ~= "player" then return end
	castGUID, spellID = FP.safe(castGUID), FP.safe(spellID)
	if not castGUID or not spellID then return end
	target = FP.safe(target)
	if target == "" then target = nil end
	sent[castGUID] = { spellID = spellID, target = target, isPlayer = API.CastTargetIsPlayer(target), t = GetTime() }
	-- keep the map tiny
	local n = 0
	for g, s in pairs(sent) do n = n + 1; if GetTime() - s.t > 30 then sent[g] = nil end end
end

function CT:OnSucceeded(unit, castGUID, spellID)
	if unit ~= "player" then return end
	spellID = FP.safe(spellID)
	if type(spellID) ~= "number" then return end
	local name = API.GetSpellName(spellID)
	local def = spellDef(name)
	if not def then return end
	castGUID = FP.safe(castGUID)
	local s = castGUID and sent[castGUID] or nil
	if castGUID then sent[castGUID] = nil end
	local target = s and s.target or nil
	-- AoE casts do not identify who was hit. Missing SENT evidence must not
	-- be replaced with whichever unit happens to be selected now.
	if def.area or def.kind == "buff" or def.kind == "trap" then target = nil end
	if def.kind == "note" then
		FP:Debug("CastTimers: noted", name, target)
		return
	end
	local base = self:ParseDuration(spellID) or def.base
	local duration, drText, factor = base, nil, 1
	if def.dr and target and s and s.isPlayer then
		duration, drText, factor = self:DRApply(target, def.dr, base)
	end
	local icon = API.GetSpellTexture(spellID)
	if factor == 0 then
		FP:Print(FP.GOLD .. "DR estimate:|r " .. tostring(target) .. " may be immune to " .. name .. "; hits and breaks are unconfirmed")
		FP.Roster:Note(target, name, "immune")
		FP:Fire("PVP_CHANGED")
		return
	end
	local entry = self:Start({ spell = name, spellID = spellID, icon = icon, target = target, owner = "me", duration = duration, kind = def.kind, drText = drText, castGUID = castGUID })
	FP.Roster:Note(target, name, drText)
	return entry
end

function CT:Prune()
	local now = GetTime()
	for i = #self.active, 1, -1 do
		local e = self.active[i]
		if now - e.start > e.duration + 1 then table.remove(self.active, i) end
	end
end

local KIND_COLORS = { cc = { 0.8, 0.3, 1 }, root = { 0.3, 0.8, 1 }, lockout = { 1, 0.6, 0.2 }, buff = { 0.3, 1, 0.4 }, trap = { 0.9, 0.9, 0.3 }, partner = { 0.4, 1, 0.8 } }

function CT:Lines()
	self:Prune()
	local now = GetTime()
	local lines = {}
	table.sort(self.active, function(a, b) return (a.start + a.duration) < (b.start + b.duration) end)
	for _, e in ipairs(self.active) do
		local remaining = e.duration - (now - e.start)
		if remaining > -1 then
			local who = e.owner == "me" and "" or (FP.GREEN .. e.owner .. "|r ")
			local target = e.target and (" → " .. U.Truncate(e.target, 14)) or ""
			local dr = e.drText and (FP.GREY .. "  " .. e.drText .. "|r") or ""
			local window = (e.owner ~= "me" and remaining <= 1.5 and remaining > 0) and (FP.GOLD .. "  window|r") or ""
			lines[#lines + 1] = {
				text = string.format("%s%s%s %s%s%s", who, e.spell, target, remaining > 0 and string.format("est. %.1fs", remaining) or "estimate ended", dr, window),
				icon = e.icon, frac = math.max(0, remaining / math.max(0.1, e.duration)), color = KIND_COLORS[e.owner == "me" and e.kind or "partner"],
			}
		end
	end
	return lines
end

function CT:Clear()
	while #self.active > 0 do table.remove(self.active) end
	self.dr = {}
	FP:Fire("PVP_CHANGED")
end

function CT:Summary()
	self:Prune()
	return string.format("%d active timer(s), DR tracked on %d target(s)", #self.active, U.Count(self.dr))
end

function CT:OnEnable()
	local f = CreateFrame("Frame", "ForeverPathCastTimers")
	self.frame = f
	local function reg(ev)
		local ok = pcall(f.RegisterUnitEvent, f, ev, "player")
		if not ok then pcall(f.RegisterEvent, f, ev) end
	end
	reg("UNIT_SPELLCAST_SENT")
	reg("UNIT_SPELLCAST_SUCCEEDED")
	f:SetScript("OnEvent", function(_, event, unit, a, b, c)
		local ok, err
		if event == "UNIT_SPELLCAST_SENT" then ok, err = pcall(CT.OnSent, CT, unit, a, b, c)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then ok, err = pcall(CT.OnSucceeded, CT, unit, a, b) end
		if ok == false then FP:ReportError("cast-timers", err) end
	end)
	FP.PvP:RegisterSection("Cast estimates (hits / breaks unknown)", 10, function() return CT:Lines() end)
end
