-- HearthAndHustle / PvP / EnemyWatch.lua
-- Enemy watch (v0.21.0): hostile players near you in the open world, with
-- alerts, a Kill On Sight list, an ignore list and a win/loss record.
-- Forever closes the combat log to addons, so this only knows what the client
-- already shows you: a player whose nameplate is on screen, or one you target,
-- focus or mouse over. It cannot see a stealthed player, a player without a
-- nameplate, or anyone out of nameplate range. It never targets or acts for you.
-- Off in dungeons, raids and battlegrounds (the scoreboard covers those).
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local W = FP:NewModule("EnemyWatch")

local SCAN         = 1     -- seconds between looks at the units still on screen
local NEARBY       = 60    -- an enemy stays on the list this long after the last look
local REALERT      = 120   -- seen again after this long counts as a new encounter
local FORGET       = 600   -- a session entry is dropped after this long
local BURST_WINDOW = 10    -- seconds
local BURST_MAX    = 5     -- more new enemies than this inside the window: one summary line
local NOTICE_GAP   = 4     -- seconds between on-screen notices for ordinary enemies
local STEALTH_GAP  = 8     -- one stealth alert per player in this many seconds
local TARGETING    = 10    -- "had you targeted" window for the loss guess
local MAX_LINES    = 10
local MAX_PLAYERS  = 2000
local MAX_GUIDS    = 2000
local SHARE_GAP    = 2

-- Stealth, Vanish, Prowl, Shadowmeld. Ranks or ids this client changed are
-- caught by comparing the spell's own (localized) name.
local STEALTH = { [1784] = "Stealth", [1785] = "Stealth", [1786] = "Stealth", [1787] = "Stealth",
	[1856] = "Vanish", [1857] = "Vanish", [5215] = "Prowl", [6783] = "Prowl", [9913] = "Prowl", [20580] = "Shadowmeld" }
local STEALTH_BASE = { 1784, 1856, 5215, 20580 }
local WATCHED = { target = true, focus = true, mouseover = true }

W.nearby, W.plates, W.guids, W.guidCount, W.targetingMe, W.burst = {}, {}, {}, 0, {}, {}

local function s() return FP.settings.enemyWatch end
local function store() return FP.db.enemyWatch end

local function firstName(name) return (name:match("^(%S+)")) or name end
local function clean(text, max)
	if type(text) ~= "string" then return nil end
	text = U.Trim((text:gsub("[%c|;]", ""))):sub(1, max or 48)
	return text ~= "" and text or nil
end
local function prettyClass(class)
	if not class then return nil end
	return class:sub(1, 1) .. class:sub(2):lower()
end
local function classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and c.colorStr then return "|c" .. c.colorStr end
	return "|cffffffff"
end
local function bump(key)
	local counts = store().counts
	counts[key] = (counts[key] or 0) + 1
end

-------------------------------------------------------------------------------
-- Lists
-------------------------------------------------------------------------------
function W:KOS(name)
	local kos = store().kos
	return kos[name]
end

function W:Ignored(name)
	local ignore = store().ignore
	return ignore[name] and true or false
end

-- A typed name becomes the spelling already known for that player; a first name
-- alone matches when exactly one known player has it. Ambiguity is shown to
-- the player; unknown first names never become wildcards for future sightings.
function W:TypedName(text)
	text = clean((tostring(text or ""):gsub("%s+", " ")), 48)
	if not text then return nil end
	local lower, st = text:lower(), store()
	local single = not lower:find(" ", 1, true)
	local found, count, match = {}, 0, nil
	for _, list in ipairs({ self.nearby, st.players, st.kos, st.ignore }) do
		for name in pairs(list) do
			local known = name:lower()
			if known == lower then return name end
			if single and firstName(known) == lower and not found[name] then
				found[name] = true
				count, match = count + 1, name
			end
		end
	end
	if count == 1 then return match end
	if single then
		local names = self:SortedNames(found)
		return nil, count > 1 and ("Name is ambiguous. Use a full name: " .. table.concat(names, ", ") .. ".")
			or "Use the player's full name, or target them and leave the name blank."
	end
	return (lower:gsub("(%S)(%S*)", function(a, b) return a:upper() .. b end))
end

-- A name from the death recap: exact, "First-Last" for "First Last", or a first
-- name that exactly one enemy seen this session has.
function W:Known(name)
	if type(name) ~= "string" then return nil end
	local st = store()
	if st.players[name] and self.nearby[name] and not self.nearby[name].by then return name end
	local spaced = name:gsub("%-", " ")
	if st.players[spaced] and self.nearby[spaced] and not self.nearby[spaced].by then return spaced end
	local match, count = nil, 0
	for known, e in pairs(self.nearby) do
		if not e.by and firstName(known) == name then match, count = known, count + 1 end
	end
	return count == 1 and st.players[match] and match or nil
end

-------------------------------------------------------------------------------
-- Detection
-------------------------------------------------------------------------------
function W:Active()
	if not FP.dbReady or not s().enabled or not API.EnemyWatchAvailable() then return false end
	return not API.InInstance()
end

function W:RememberGUID(guid, name)
	if self.guids[guid] == name then return end
	if self.guidCount >= MAX_GUIDS then self.guids, self.guidCount = {}, 0 end
	if not self.guids[guid] then self.guidCount = self.guidCount + 1 end
	self.guids[guid] = name
end

-- Everyone met, kept between sessions (bounded).
function W:Record(e, encounter)
	local st, now = store(), API.Now()
	local p = st.players[e.name]
	if not p then
		p = { first = now, seen = 0 }
		st.players[e.name] = p
		U.TrimRecords(st.players, MAX_PLAYERS)
	end
	p.class, p.race, p.guild = e.class or p.class, e.race or p.race, e.guild or p.guild
	if e.level then p.level = e.level end
	p.last = now
	if encounter then
		p.seen = (p.seen or 0) + 1
		p.zone = API.GetZoneText()
	end
	return p
end

function W:See(unit, how)
	if not self:Active() then return nil end
	local info, why = API.EnemyPlayer(unit)
	if not info then
		if why == "secret" then bump("secret") end
		return nil
	end
	if self:Ignored(info.name) then return nil end
	local now = API.Time()
	if info.guid then self:RememberGUID(info.guid, info.name) end
	if info.targetsMe then self.targetingMe[info.name] = now end
	local e = self.nearby[info.name]
	if info.dead then
		if e then e.dead = true end   -- a corpse is not a sighting
		return e
	end
	local fresh = not e or (now - e.last) > REALERT
	-- Told about by a party member, now seen here: met, but already announced.
	local met = fresh or e.by ~= nil
	if not e then e = { name = info.name }; self.nearby[info.name] = e end
	if fresh then e.first, e.note, e.noteAt = now, nil, nil end
	e.class, e.race, e.guild = info.class or e.class, info.race or e.race, info.guild or e.guild
	if info.level and info.level > 0 then e.level, e.skull = info.level, nil
	elseif info.level == -1 then e.skull = true end
	e.attackable = info.attackable
	e.last, e.how, e.by, e.dead = now, how, nil, nil
	self:Record(e, met)
	if met then bump(how) end
	if fresh then
		self:Alert(e)
		self:Share(e)
		FP:Fire("PVP_CHANGED")
	end
	return e
end

function W:Scan()
	if not self:Active() then return end
	for unit in pairs(self.plates) do self:See(unit, "nameplate") end
	self:See("target", "target")
	self:See("focus", "focus")
	local now = API.Time()
	for name, e in pairs(self.nearby) do
		if now - e.last > FORGET then self.nearby[name] = nil end
	end
	for name, t in pairs(self.targetingMe) do
		if now - t > 60 then self.targetingMe[name] = nil end
	end
end

-------------------------------------------------------------------------------
-- Alerts
-------------------------------------------------------------------------------
function W:Describe(e)
	local bits = {}
	if e.level then bits[#bits + 1] = tostring(e.level) elseif e.skull then bits[#bits + 1] = "??" end
	if e.class then bits[#bits + 1] = prettyClass(e.class) end
	return e.name .. (#bits > 0 and (" (" .. table.concat(bits, " ") .. ")") or "") .. (e.guild and (" <" .. e.guild .. ">") or "")
end

function W:Notice(text, kind)
	API.ScreenNotice(text)
	if s().sound then store().sound = { kind = kind, played = API.PlayEnemyAlert(kind), t = API.Now() } end
end

-- An ordinary enemy alerts only when one of you can attack the other: on a PvE
-- realm an unflagged player of the other faction is listed, quietly.
function W:Alert(e)
	if not s().alerts or API.ZonePvPType() == "sanctuary" then return end
	local kos = self:KOS(e.name)
	local who = self:Describe(e) .. (e.by and (" — seen by " .. e.by) or "")
	if kos then
		local text = "KILL ON SIGHT: " .. who .. (kos.reason and (" — " .. kos.reason) or "")
		FP:Print(FP.RED .. text .. "|r")
		self:Notice(text, "kos")
		return
	end
	if e.attackable == false then return end
	local now, recent = API.Time(), {}
	for _, t in ipairs(self.burst) do
		if now - t <= BURST_WINDOW then recent[#recent + 1] = t end
	end
	recent[#recent + 1] = now
	self.burst = recent
	if #recent > BURST_MAX then
		-- A raid on a town must not flood chat: one line, then the HUD carries the list.
		if not self.flooded then
			self.flooded = true
			FP:Print(FP.GOLD .. "Many enemy players nearby.|r The list is on the PvP HUD." .. FP.GREY .. " /hh enemies|r")
		end
		return
	end
	self.flooded = nil
	local text = "Enemy nearby: " .. who
	FP:Print(FP.GOLD .. text .. "|r")
	if now - (self.noticeAt or -1000) >= NOTICE_GAP then
		self.noticeAt = now
		self:Notice(text, "new")
	end
end

function W:StealthKind(spellID)
	if STEALTH[spellID] then return STEALTH[spellID] end
	local name = API.GetSpellName(spellID)
	if not name then return nil end
	if not self.stealthNames then
		self.stealthNames = {}
		for _, id in ipairs(STEALTH_BASE) do
			local known = API.GetSpellName(id)
			if known then self.stealthNames[known] = STEALTH[id] end
		end
	end
	return self.stealthNames[name]
end

-- A visible enemy player's finished cast, when the client lets the spell be
-- read. Only the four stealth abilities are looked for; nothing is timed.
function W:OnCast(unit, spellID)
	if not FP.dbReady or not s().stealth then return end
	unit = FP.safe(unit)
	if type(unit) ~= "string" or not (WATCHED[unit] or API.IsNameplateUnit(unit)) then return end
	local e = self:See(unit, "cast")
	if not e then return end
	if FP.issecret(spellID) then bump("castSecret"); return end
	if not U.Finite(spellID) then return end
	bump("castRead")
	local kind = self:StealthKind(spellID)
	if not kind then return end
	local now = API.Time()
	if e.stealthAt and now - e.stealthAt < STEALTH_GAP then return end
	e.stealthAt, e.note, e.noteAt = now, kind:lower(), now
	bump("stealth")
	if s().alerts and API.ZonePvPType() ~= "sanctuary" and (e.attackable ~= false or self:KOS(e.name)) then
		local text = e.name .. " used " .. kind .. " near you"
		FP:Print(FP.GOLD .. text .. "|r")
		self:Notice(text, "stealth")
	end
	FP:Fire("PVP_CHANGED")
end

-------------------------------------------------------------------------------
-- Wins and losses
-------------------------------------------------------------------------------
function W:Score(p)
	local wins, losses = p.wins or 0, p.losses or 0
	return string.format("Record against them: %d win%s, %d loss%s.", wins, wins == 1 and "" or "s", losses, losses == 1 and "" or "es")
end

-- A win is your killing blow or your pet's.
function W:OnPartyKill(attacker, target)
	if not self:Active() then return end
	attacker, target = FP.safe(attacker), FP.safe(target)
	if type(target) ~= "string" or target:sub(1, 7) ~= "Player-" then return end
	local st = store()
	local kill = { t = API.Now(), version = FP.version }
	st.lastKill = kill
	if type(attacker) ~= "string" then kill.result = "killer hidden"; return end
	if not API.IsOwnGUID(attacker) then kill.result = "not yours"; return end
	local name = self.guids[target]
	local p = name and st.players[name]
	if not p then kill.result = "victim never seen"; return end
	p.wins = (p.wins or 0) + 1
	kill.name, kill.result = name, "win"
	local e = self.nearby[name]
	if e then e.note, e.noteAt, e.dead = "killed", API.Time(), true end
	FP:Print(FP.GREEN .. "You killed " .. name .. ".|r " .. self:Score(p))
	FP:Fire("PVP_CHANGED")
end

-- A loss: the killing blow in the client's death recap, when it names an enemy
-- player seen this session. Targeting alone is a separate, uncertain hint;
-- it never changes the confirmed record.
function W:OnDead()
	if not self:Active() then return end
	self.deathGeneration = (self.deathGeneration or 0) + 1
	local generation = self.deathGeneration
	local deathMap = API.GetBestMap()
	local now, suspects = API.Time(), {}
	for name, t in pairs(self.targetingMe) do
		if now - t <= TARGETING then suspects[#suspects + 1] = name end
	end
	local function resolve(attempt)
		if not W:Active() or W.deathGeneration ~= generation or API.GetBestMap() ~= deathMap then return end
		local src, why, id = API.DeathRecapKiller(W.lastRecap)
		if not src and why == "stale" and attempt < 2 then
			FP.After(3, function() resolve(attempt + 1) end)
			return
		end
		if id then W.lastRecap = id end
		local st = store()
		local name, how, possible
		if src then
			-- An explicit GUID outranks a matching name, including NPC names.
			if src.guid then
				if src.guid:sub(1, 7) == "Player-" then name = W.guids[src.guid] end
			else name = W:Known(src.name) end
			how = name and "recap" or "recap: not an enemy player seen this session"
		elseif #suspects == 1 then
			possible, how = suspects[1], "targeting (recap " .. tostring(why) .. ")"
		else
			how = "recap " .. tostring(why) .. "; " .. #suspects .. " had you targeted"
		end
		st.lastDeath = { t = API.Now(), name = name, possible = possible, confirmed = name ~= nil, how = how, version = FP.version }
		if possible then FP:Print("Killer unconfirmed. " .. possible .. " had you targeted; your win/loss record is unchanged.") end
		local p = name and st.players[name]
		if not p then return end
		p.losses = (p.losses or 0) + 1
		FP:Print(FP.RED .. name .. " killed you.|r " .. W:Score(p) .. FP.GREY .. " /hh kos " .. name .. "|r")
	end
	FP.After(1.5, function() resolve(1) end)
end

-------------------------------------------------------------------------------
-- Party share: "EW;1;<name>;<CLASS>;<level>;<guild>". Only what this client
-- saw itself is sent (W:See); a sighting received from the party never is.
-------------------------------------------------------------------------------
function W:Share(e)
	if not s().share or not API.InGroup() then return end
	local now = API.Time()
	if not self:KOS(e.name) and now - (self.sharedAt or -1000) < SHARE_GAP then return end
	self.sharedAt = now
	API.SendPartyMessage(table.concat({ "EW", "1", clean(e.name, 48) or "?", e.class or "",
		tostring(e.level or (e.skull and -1) or 0), clean(e.guild, 40) or "" }, ";"))
end

function W:Receive(msg, sender)
	if not self:Active() or not s().share then return end
	local version, name, class, level, guild = msg:match("^EW;(%d+);([^;]*);([^;]*);(%-?%d+);([^;]*)$")
	if version ~= "1" then return end
	name = clean(name, 48)
	if not name or name == "?" or self:Ignored(name) then return end
	local now = API.Time()
	local e = self.nearby[name]
	if e and now - e.last <= REALERT then return end   -- already known here
	level = tonumber(level)
	e = e or { name = name }
	e.first, e.last, e.how, e.dead, e.note, e.noteAt = now, now, "party", nil, nil, nil
	e.by = clean((tostring(sender):match("^[^-]+")), 30) or "party"
	if class:match("^%u+$") and #class <= 20 then e.class = class end
	if level and level > 0 and level <= 100 then e.level, e.skull = level, nil elseif level == -1 then e.skull = true end
	e.guild = clean(guild, 40) or e.guild
	e.attackable = nil
	self.nearby[name] = e
	bump("party")
	self:Alert(e)
	FP:Fire("PVP_CHANGED")
end

-------------------------------------------------------------------------------
-- HUD rows, status, commands
-------------------------------------------------------------------------------
function W:Rows()
	if not self:Active() then return {} end
	local now, list = API.Time(), {}
	for _, e in pairs(self.nearby) do
		if now - e.last <= NEARBY and not self:Ignored(e.name) then list[#list + 1] = e end
	end
	for _, e in ipairs(list) do e.kosNow = self:KOS(e.name) and 1 or 0 end
	table.sort(list, function(a, b)
		if a.kosNow ~= b.kosNow then return a.kosNow > b.kosNow end
		if a.first ~= b.first then return a.first > b.first end
		return a.name < b.name
	end)
	local rows = {}
	for i = 1, math.min(MAX_LINES, #list) do
		local e = list[i]
		local ago = now - e.last
		local bits = {}
		if e.level then bits[#bits + 1] = tostring(e.level) elseif e.skull then bits[#bits + 1] = "??" end
		if e.class then bits[#bits + 1] = prettyClass(e.class) end
		if e.guild then bits[#bits + 1] = "<" .. e.guild .. ">" end
		bits[#bits + 1] = ago < 3 and "now" or (math.floor(ago) .. "s")
		local note = e.note and e.noteAt and now - e.noteAt < 30 and e.note or nil
		if not note and FP.Roster then
			-- First-name roster notes are unsafe when multiple full identities match.
			local short = firstName(e.name)
			local r = self:Known(short) == e.name and FP.Roster.session[short] or nil
			if r and r.note and r.noteT and U.Now() - r.noteT < 60 then note = r.note end
		end
		if e.dead and note ~= "killed" then note = "dead" end
		if e.by then note = (note and (note .. ", ") or "") .. "seen by " .. e.by end
		if e.attackable == false then note = (note and (note .. ", ") or "") .. "not flagged" end
		rows[#rows + 1] = { text = (e.kosNow == 1 and (FP.RED .. "KOS|r ") or "") .. classColor(e.class) .. e.name .. "|r "
			.. FP.GREY .. table.concat(bits, " ") .. (note and ("  " .. note) or "") .. "|r" }
	end
	if #list > MAX_LINES then rows[#rows + 1] = { text = FP.GREY .. "+" .. (#list - MAX_LINES) .. " more|r" } end
	return rows
end

function W:NameplateLine()
	local shown, always = API.EnemyNameplates()
	if shown == false then return "enemy nameplates are OFF: only players you target or mouse over are seen", false end
	if always == false then return "nameplates only show in combat: outside combat only players you target or mouse over are seen", false end
	if shown == nil then return "enemy nameplate setting not readable", true end
	return "enemy nameplates on", true
end

function W:Status()
	local st, out = store(), {}
	if not API.EnemyWatchAvailable() then
		out[1] = "Enemy watch: unavailable on this client."
		return out
	end
	local set = s()
	local where = ""
	if set.enabled and API.InInstance() then where = " (paused: off in dungeons, raids and battlegrounds)" end
	out[1] = "Enemy watch " .. (set.enabled and "on" or "off") .. where .. " · alerts " .. (set.alerts and "on" or "off")
		.. " · sound " .. (set.sound and "on" or "off") .. " · stealth alerts " .. (set.stealth and "on" or "off")
		.. " · party share " .. (set.share and "on" or "off")
	out[2] = "  " .. (self:NameplateLine())
	local near, now = 0, API.Time()
	for _, e in pairs(self.nearby) do
		if now - e.last <= NEARBY then near = near + 1 end
	end
	local wins, losses = 0, 0
	for _, p in pairs(st.players) do wins, losses = wins + (p.wins or 0), losses + (p.losses or 0) end
	out[3] = string.format("  nearby now %d · met overall %d · Kill On Sight %d · ignored %d · wins %d, losses %d",
		near, U.Count(st.players), U.Count(st.kos), U.Count(st.ignore), wins, losses)
	return out
end

-- Recent enemies with their record, newest first.
function W:StatLines(limit)
	local st, list = store(), {}
	for name, p in pairs(st.players) do list[#list + 1] = { name = name, p = p } end
	table.sort(list, function(a, b)
		if (a.p.last or 0) ~= (b.p.last or 0) then return (a.p.last or 0) > (b.p.last or 0) end
		return a.name < b.name
	end)
	local out = {}
	for i = 1, math.min(limit or 10, #list) do
		local name, p = list[i].name, list[i].p
		out[#out + 1] = string.format("%s%s%s|r %s%s · met %d · %d-%d%s", self:KOS(name) and (FP.RED .. "KOS|r ") or "", classColor(p.class), name,
			p.level and (p.level .. " ") or "", prettyClass(p.class) or "?", p.seen or 0, p.wins or 0, p.losses or 0,
			p.guild and (" · <" .. p.guild .. ">") or "")
	end
	if #out == 0 then out[1] = "No enemy players met yet." end
	return out
end

local function toggle(set, key, value, label)
	if value == "on" then set[key] = true elseif value == "off" then set[key] = false else set[key] = not set[key] end
	FP:Print("enemy watch " .. label .. " " .. (set[key] and "on" or "off"))
end

function W:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	local set = s()
	if sub == "on" then set.enabled = true; FP:Print("enemy watch on"); self:Scan()
	elseif sub == "off" then set.enabled = false; self.deathGeneration = (self.deathGeneration or 0) + 1; FP:Print("enemy watch off")
	elseif sub == "alerts" then toggle(set, "alerts", val, "alerts")
	elseif sub == "sound" then toggle(set, "sound", val, "sound")
	elseif sub == "stealth" then toggle(set, "stealth", val, "stealth alerts")
	elseif sub == "share" then toggle(set, "share", val, "party share")
	elseif sub == "nameplates" then
		local ok, why = API.EnableEnemyNameplates()
		if ok then FP:Print("Enemy nameplates are on and shown outside combat.")
		elseif why == "combat" then FP:Print("Nameplate settings cannot be changed in combat. Try again after the fight.")
		else FP:Print("The client did not accept the nameplate settings. Switch them on under Options > Nameplates (enemy nameplates, always show).") end
	elseif sub == "list" then
		local rows = self:Rows()
		if #rows == 0 then FP:Print("No enemy players nearby.") end
		for _, row in ipairs(rows) do FP:Print(row.text) end
	elseif sub == "stats" then
		for _, line in ipairs(self:StatLines(tonumber(val) or 10)) do FP:Print(line) end
	elseif sub == "clear" then
		self.nearby, self.targetingMe, self.burst, self.flooded = {}, {}, {}, nil
		FP:Print("nearby enemy list cleared")
	else
		for _, line in ipairs(self:Status()) do FP:Print(line) end
		FP:Print("/hh enemies on|off | alerts|sound|stealth|share on|off | nameplates | list | stats [n] | clear")
		FP:Print("/hh kos [name][: reason] | /hh kos list   ·   /hh ignore [name] | /hh ignore list   (no name = your target; +name adds, -name removes)")
	end
	FP:Fire("PVP_CHANGED")
end

local function targetName()
	local info = API.EnemyPlayer("target")
	return info and info.name or nil
end

function W:SortedNames(list)
	local names = {}
	for name in pairs(list) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function W:KosCommand(rest)
	local st = store()
	rest = U.Trim(rest or "")
	if rest:lower() == "list" then
		local names = self:SortedNames(st.kos)
		if #names == 0 then FP:Print("Kill On Sight list is empty. /hh kos <name>: <reason>, or /hh kos with an enemy player targeted.") end
		for _, name in ipairs(names) do FP:Print(FP.RED .. "KOS|r " .. name .. (st.kos[name].reason and (" — " .. st.kos[name].reason) or "")) end
		return
	end
	-- "+name" only adds, "-name" only removes, a bare name switches.
	local mode = rest:match("^([%+%-])")
	if mode then rest = U.Trim(rest:sub(2)) end
	local typed, reason = rest:match("^([^:]*):%s*(.*)$")
	typed = U.Trim(typed or rest)
	reason = clean(reason, 80)
	local name, why
	if typed ~= "" then name, why = self:TypedName(typed) else name = targetName() end
	if not name then FP:Print(why or "Target an enemy player, or type /hh kos <name>: <reason>."); return end
	if mode == "-" and not st.kos[name] then
		FP:Print(name .. " is not on Kill On Sight.")
	elseif mode == "+" and st.kos[name] and not reason then
		FP:Print(name .. " is already on Kill On Sight.")
	elseif mode == "-" or (not mode and st.kos[name] and not reason) then
		st.kos[name] = nil
		FP:Print(name .. " removed from Kill On Sight.")
	else
		local known = st.kos[name] ~= nil
		st.kos[name] = { t = (known and st.kos[name].t) or API.Now(), reason = reason }
		st.ignore[name] = nil
		FP:Print(FP.RED .. name .. "|r " .. (known and "Kill On Sight reason updated" or "added to Kill On Sight") .. (reason and (": " .. reason) or "") .. ".")
	end
	FP:Fire("PVP_CHANGED")
end

function W:IgnoreCommand(rest)
	local st = store()
	rest = U.Trim(rest or "")
	if rest:lower() == "list" then
		local names = self:SortedNames(st.ignore)
		if #names == 0 then FP:Print("Enemy ignore list is empty. /hh ignore <name>, or /hh ignore with an enemy player targeted.") end
		for _, name in ipairs(names) do FP:Print("ignored: " .. name) end
		return
	end
	local mode = rest:match("^([%+%-])")
	if mode then rest = U.Trim(rest:sub(2)) end
	local name, why
	if rest ~= "" then name, why = self:TypedName(rest) else name = targetName() end
	if not name then FP:Print(why or "Target an enemy player, or type /hh ignore <name>."); return end
	if mode == "-" and not st.ignore[name] then
		FP:Print(name .. " is not ignored.")
	elseif mode == "+" and st.ignore[name] then
		FP:Print(name .. " is already ignored.")
	elseif st.ignore[name] then
		st.ignore[name] = nil
		FP:Print(name .. " is no longer ignored by enemy watch.")
	else
		st.ignore[name] = API.Now()
		st.kos[name] = nil
		self.nearby[name] = nil
		FP:Print(name .. " ignored: no alerts and not listed.")
	end
	FP:Fire("PVP_CHANGED")
end

function W:OnEnable()
	local E = function(ev, fn) FP:RegisterEvent(ev, fn) end
	E("NAME_PLATE_UNIT_ADDED", function(_, unit)
		unit = FP.safe(unit)
		if type(unit) ~= "string" then return end
		W.plates[unit] = true
		W:See(unit, "nameplate")
	end)
	E("NAME_PLATE_UNIT_REMOVED", function(_, unit)
		unit = FP.safe(unit)
		if type(unit) == "string" then W.plates[unit] = nil end
	end)
	E("PLAYER_ENTERING_WORLD", function() W.plates = {}; W.deathGeneration = (W.deathGeneration or 0) + 1 end)
	E("PLAYER_TARGET_CHANGED", function() W:See("target", "target") end)
	E("PLAYER_FOCUS_CHANGED", function() W:See("focus", "focus") end)
	E("UPDATE_MOUSEOVER_UNIT", function() W:See("mouseover", "mouseover") end)
	E("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) W:OnCast(unit, spellID) end)
	E("PARTY_KILL", function(_, attacker, target) W:OnPartyKill(attacker, target) end)
	E("PLAYER_DEAD", function() W:OnDead() end)
	E("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
		prefix, msg, channel, sender = FP.safe(prefix), FP.safe(msg), FP.safe(channel), FP.safe(sender)
		if prefix ~= API.PREFIX or channel ~= "PARTY" or type(msg) ~= "string" or msg:sub(1, 3) ~= "EW;" or not API.IsPartySender(sender) then return end
		W:Receive(msg, sender)
	end)
	FP.PvP:RegisterSection("Enemies nearby", 29, function() return W:Rows() end)
	if C_Timer and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(SCAN, function() FP.pcall("enemy-scan", W.Scan, W) end)
	end
	-- Without nameplates outside combat almost nobody is seen: say so once.
	FP.After(8, function()
		local st = store()
		if st.nameplateHint or not W:Active() then return end
		local line, ok = W:NameplateLine()
		if ok then return end
		st.nameplateHint = true
		FP:Print("Enemy watch: " .. line .. "." .. FP.GREY .. " /hh enemies nameplates switches them on.|r")
	end)
end
