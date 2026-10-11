-- ForeverPath / Modules / RareWatch.lua
-- Dungeon rare-spawn watch. Tells you whether a watched rare (default: the
-- Scarlet Monastery Graveyard trio — Azshir the Sleepless, Ironspine, Fallen
-- Champion) is up in the instance you are in, shares a sighting with your
-- party, and counts runs vs sightings so the spawn rate gets measured.
--
-- Forever facts this is built on (probe evidence 2026-10-09, build 70291):
--  * inside a dungeon the "Map" restriction is active even out of combat and
--    NPC UnitName/UnitGUID come back SECRET. Names cannot be compared there.
--  * UnitClassification ("rare"/"rareelite"), UnitLevel, UnitReaction and
--    UnitCreatureType carry no secret gate in Blizzard's docs and read as plain
--    values in the same samples — a rare is recognised by its classification.
--  * loot-source GUIDs are not guarded (boss loot recorded in City of Dalaran
--    2026-10-08): the GUID of anything you loot carries the creature id (which
--    rare you killed) and the zoneUID (which instance you are in = run key).
--  * addon messages work in a dungeon outside boss encounters (chatLock=0).
--
-- Information only. The one input is the Scan button: a SecureActionButton
-- whose macro is "/targetexact <name>" — identical to a player macro, one
-- click = one targeting attempt. Nothing targets, moves or acts on its own.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local RW = FP:NewModule("RareWatch")

local WIDTH, MAX_RUNS, REALERT, STALE = 300, 400, 600, 2 * 3600   -- a run idle for 2 h is over
RW.DEFAULT_WATCH = {
	instance = "Scarlet Monastery",
	rares = {
		-- vanilla creature ids; unverified on Forever until a loot window confirms them
		{ id = 6490, name = "Azshir the Sleepless" },
		{ id = 6489, name = "Ironspine" },
		{ id = 6488, name = "Fallen Champion" },
	},
}
RW.SWEEP = { "target", "mouseover", "focus", "pettarget",
	"party1target", "party2target", "party3target", "party4target",
	"partypet1target", "partypet2target", "partypet3target", "partypet4target" }

local function settings() return FP.settings.rare end
local function db() return FP.db.rare end
function RW:Watch() return FP.db.rareWatch end

-------------------------------------------------------------------------------
-- Runs. A run is one instance (one reset). Keyed by the zoneUID from the first
-- loot-source GUID seen; provisional "visit-<t>" until a loot window proves it.
-------------------------------------------------------------------------------
local function newRun(inst, how)
	local now = U.Now()
	return { key = "visit-" .. now, t = now, last = now, instance = inst and inst.name, mapID = inst and inst.mapID,
		how = how, scans = 0, kills = {}, sightings = {} }
end

function RW:Current()
	local d = db()
	return d.current and d.runs[d.current] or nil
end

function RW:OpenRun(inst, how)
	local d = db()
	local run = newRun(inst, how)
	d.runs[run.key] = run
	d.order[#d.order + 1] = run.key
	d.current = run.key
	while #d.order > MAX_RUNS do
		local old = table.remove(d.order, 1)
		d.runs[old] = nil
	end
	self.alerted = nil
	FP:Fire("RARE_CHANGED")
	return run
end

function RW:CloseRun(why)
	local run = self:Current()
	if run then run.closed, run.closedWhy = U.Now(), why end
	db().current = nil
	self.alerted = nil
	FP:Fire("RARE_CHANGED")
end

local function merge(into, from)
	into.scans = (into.scans or 0) + (from.scans or 0)
	for id, n in pairs(from.kills or {}) do into.kills[id] = (into.kills[id] or 0) + n end
	for _, s in ipairs(from.sightings or {}) do into.sightings[#into.sightings + 1] = s end
	into.seen = into.seen or from.seen
	into.seenName = into.seenName or from.seenName
	into.absent = into.absent or from.absent
	into.last = math.max(into.last or 0, from.last or 0)
	into.visits = (into.visits or 1) + 1
end

-- Called with the zoneUID of any creature GUID observed inside the instance.
function RW:LearnZoneUID(uid, source)
	if not uid or uid == "0" then return end
	local d = db()
	local run = self:Current()
	if not run then return end
	if run.zoneUID == uid then return end
	if run.zoneUID then
		-- the instance changed under us (reset by the group while we were out): new run
		run.closed, run.closedWhy = U.Now(), "superseded"
		run = self:OpenRun({ name = run.instance, mapID = run.mapID }, "zone-changed")
	end
	local existing = d.runs[uid]
	if existing and existing ~= run then
		-- re-entered an instance we already know: fold the provisional visit into it
		merge(existing, run)
		d.runs[run.key] = nil
		for i = #d.order, 1, -1 do if d.order[i] == run.key then table.remove(d.order, i) end end
		d.current = uid
		run = existing
	else
		d.runs[run.key] = nil
		for i, k in ipairs(d.order) do if k == run.key then d.order[i] = uid end end
		run.key, run.zoneUID, run.uidSource = uid, uid, source
		d.runs[uid] = run
		d.current = uid
	end
	run.last = U.Now()
	FP:Fire("RARE_CHANGED")
end

function RW:Stats()
	local d = db()
	local s = { runs = 0, seen = 0, killed = 0, checked = 0, scans = 0 }
	for _, key in ipairs(d.order) do
		local run = d.runs[key]
		if run then
			s.runs = s.runs + 1
			s.scans = s.scans + (run.scans or 0)
			if run.seen then s.seen = s.seen + 1 end
			if next(run.kills) then s.killed = s.killed + 1 end
			if run.seen or run.absent or (run.scans or 0) > 0 then s.checked = s.checked + 1 end
		end
	end
	s.rate = s.checked > 0 and (s.seen / s.checked) or nil
	return s
end

-------------------------------------------------------------------------------
-- Instance context
-------------------------------------------------------------------------------
function RW:InWatchedInstance()
	local inst = API.GetInstance()
	local watch = self:Watch()
	if not inst.inInstance or type(inst.name) ~= "string" or not watch or type(watch.instance) ~= "string" or watch.instance == "" then
		return false, inst
	end
	return inst.name:lower():find(watch.instance:lower(), 1, true) ~= nil, inst
end

function RW:OnEnterWorld()
	local inside, inst = self:InWatchedInstance()
	self.inside = inside
	if inside then
		local run = self:Current()
		if run and not run.closed and (U.Now() - (run.last or 0)) > STALE then self:CloseRun("stale"); run = nil end
		if not run or run.closed then self:OpenRun(inst, "enter") else run.last = U.Now() end
		-- hunter pets are player-controlled: their GUID stays readable and may carry the instance id
		local pet = API.UnitGUID("pet") or API.UnitGUID("partypet1") or API.UnitGUID("partypet2")
		if pet then
			local _, _, zone = U.ParseGUIDFull(pet)
			local cur = self:Current()
			if cur and zone then cur.petZone = zone end
		end
		self:ProbeVignettes("enter")
	end
	self:Refresh()
end

function RW:ProbeVignettes(trigger)
	if not self.inside then return end
	local list = API.GetVignettes()
	local d = db()
	d.vignettes = d.vignettes or { probes = 0, seen = {} }
	d.vignettes.probes = d.vignettes.probes + 1
	d.vignettes.supported = list ~= nil
	if not list then return end
	for _, v in ipairs(list) do
		local key = tostring(v.name or v.vignetteID or v.atlas or "?")
		local rec = d.vignettes.seen[key] or { n = 0 }
		d.vignettes.seen[key] = rec
		rec.n, rec.atlas, rec.type, rec.minimap, rec.last, rec.trig = rec.n + 1, v.atlas, v.type, v.onMinimap, U.Now(), trigger
		if v.name and self:MatchName(v.name) then self:Sighting({ how = "vignette", name = v.name }, "vignette") end
	end
end

function RW:MatchName(name)
	if type(name) ~= "string" then return nil end
	for _, r in ipairs(self:Watch().rares or {}) do
		if r.name and r.name:lower() == name:lower() then return r end
	end
	return nil
end

function RW:MatchID(id)
	for _, r in ipairs(self:Watch().rares or {}) do if r.id and r.id == id then return r end end
	return nil
end

-------------------------------------------------------------------------------
-- Sightings
-------------------------------------------------------------------------------
-- info: { how, level, creatureType, classification, nameSecret, name, id, dead, unit }
function RW:Sighting(info, how)
	if not settings().enabled or not self.inside then return false end
	local run = self:Current()
	if not run then return false end
	local now = U.Now()
	local rec = { t = now, how = how or info.how, lvl = info.level, ct = info.creatureType, cls = info.classification,
		secret = info.nameSecret and 1 or nil, name = info.name, id = info.id, dead = info.dead and 1 or nil, by = info.by }
	U.Push(run.sightings, rec, 20)
	run.seen = run.seen or now
	run.lastSeen = now
	if info.name and not run.seenName then run.seenName = info.name end
	if info.id and not run.seenID then run.seenID = info.id end
	if info.dead then run.deadSeen = now end
	run.last = now
	local fresh = not self.alerted or (now - self.alerted) > REALERT
	if fresh then
		self.alerted = now
		self:Alert(run, info)
		if not info.by then self:Broadcast("up", info) end
	end
	-- display-only: a secret name may be shown but never compared or stored
	if info.unit and self.nameText then
		local shown = API.ShowUnitName(self.nameText, info.unit)
		self.nameShown = shown
	end
	self:Refresh()
	FP:Fire("RARE_CHANGED")
	return true
end

function RW:Describe(info)
	local who = info.name or "a rare"
	local bits = {}
	if info.level then bits[#bits + 1] = "lvl " .. tostring(info.level) end
	if info.creatureType then bits[#bits + 1] = tostring(info.creatureType) end
	if info.classification == "rareelite" then bits[#bits + 1] = "rare elite" elseif info.classification == "rare" then bits[#bits + 1] = "rare" end
	local text = who .. (#bits > 0 and (" (" .. table.concat(bits, ", ") .. ")") or "")
	if info.by then text = text .. " — seen by " .. tostring(info.by) end
	if info.dead then text = text .. " — dead" end
	return text
end

function RW:Alert(run, info)
	local text = "RARE UP: " .. self:Describe(info)
	FP:Print(FP.GOLD .. text .. "|r")
	if settings().sound then API.PlayAlert() end
	if type(RaidNotice_AddMessage) == "function" and RaidWarningFrame and ChatTypeInfo then
		pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.8, b = 0 })
	end
end

function RW:OnUnit(unit, how)
	if not settings().enabled or not self.inside then return nil end
	local info = API.UnitRare(unit)
	if not info or info.isPlayer then return nil end
	local byName = (not info.nameSecret) and self:MatchName(info.name) or nil
	local byID = info.id and self:MatchID(info.id) or nil
	if byName or byID or (info.rare and (info.reaction or 0) <= 4) then
		info.unit, info.how = unit, how
		if byID and not info.name then info.name = byID.name end
		return self:Sighting(info, how)
	end
	return false
end

function RW:Sweep(how)
	for _, unit in ipairs(RW.SWEEP) do
		if self:OnUnit(unit, how) then return unit end
	end
	return nil
end

-- After a Scan click (PostClick fires once the secure macro has run).
function RW:AfterScan()
	if not self.inside then FP:Print("rare watch: not inside " .. tostring(self:Watch().instance)); return end
	local run = self:Current()
	if not run then return end
	run.scans = (run.scans or 0) + 1
	run.last = U.Now()
	local found = self:Sweep("scan")
	if not found then
		run.lastMiss = U.Now()
		FP.Throttle("rare-miss", 2, function() FP:Print(FP.GREY .. "scan: no watched rare targetable from here (/targetexact reaches only what the client has loaded)|r") end)
	end
	FP:Fire("RARE_CHANGED")
end

function RW:MarkAbsent(by)
	local run = self:Current()
	if not run then FP:Print("rare watch: no current run"); return end
	run.absent = U.Now()
	run.absentBy = by
	run.last = run.absent
	if not by then self:Broadcast("no") end
	FP:Print("rare watch: this run marked " .. FP.RED .. "not up|r" .. (by and (" by " .. by) or ""))
	FP:Fire("RARE_CHANGED")
end

-------------------------------------------------------------------------------
-- Loot: identity + instance key come from loot-source GUIDs (not secret)
-------------------------------------------------------------------------------
function RW:OnLoot()
	if not settings().enabled or not self.inside then return end
	self.lootGUIDs = self.lootGUIDs or {}
	for _, slot in ipairs(API.GetLootSlots()) do
		for _, source in ipairs(slot.sources or {}) do
			local kind, id, zone = U.ParseGUIDFull(source.guid)
			if kind == "Creature" and id then
				self:LearnZoneUID(zone, "loot")
				local rare = self:MatchID(id)
				if rare and not self.lootGUIDs[source.guid] then
					self.lootGUIDs[source.guid] = true
					local run = self:Current()
					if run then
						run.kills[id] = (run.kills[id] or 0) + 1
						run.seen = run.seen or U.Now()
						run.seenName = run.seenName or rare.name
						run.seenID = run.seenID or id
						run.last = U.Now()
						FP:Print(FP.GREEN .. "rare watch: " .. rare.name .. " looted — run marked killed|r")
						self:Broadcast("kill", { id = id, name = rare.name })
						FP:Fire("RARE_CHANGED")
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Party share: "RW;up;<level>;<creatureType>;<name>" | "RW;no" | "RW;kill;<id>;<name>"
-------------------------------------------------------------------------------
function RW:Encode(kind, info)
	info = info or {}
	local function clean(v, n) v = tostring(v or ""):gsub("[;|]", ""); return v:sub(1, n) end
	if kind == "up" then return table.concat({ "RW", "up", clean(info.level, 4), clean(info.creatureType, 24), clean(info.name, 48) }, ";") end
	if kind == "kill" then return table.concat({ "RW", "kill", clean(info.id, 10), clean(info.name, 48) }, ";") end
	return "RW;no"
end

function RW:Decode(msg)
	if type(msg) ~= "string" or #msg > 120 then return nil end
	local kind, rest = msg:match("^RW;([a-z]+);?(.*)$")
	if kind == "no" and rest == "" then return { kind = "no" } end
	if kind == "up" then
		local level, ct, name = rest:match("^([^;]*);([^;]*);([^;]*)$")
		if not level then return nil end
		return { kind = "up", level = tonumber(level), creatureType = ct ~= "" and ct or nil, name = name ~= "" and name or nil }
	end
	if kind == "kill" then
		local id, name = rest:match("^([^;]*);([^;]*)$")
		if not id then return nil end
		return { kind = "kill", id = tonumber(id), name = name ~= "" and name or nil }
	end
	return nil
end

function RW:Broadcast(kind, info)
	if not settings().share or not API.InGroup() then return false end
	if API.IsChatLocked() then self.lockedSends = (self.lockedSends or 0) + 1; return false end
	local ok = API.SendPartyMessage(self:Encode(kind, info))
	if ok then self.sent = (self.sent or 0) + 1 end
	return ok
end

function RW:Receive(msg, sender)
	local p = self:Decode(msg)
	if not p then return false end
	self.received = (self.received or 0) + 1
	if p.kind == "up" then
		p.by = sender
		return self:Sighting(p, "party")
	elseif p.kind == "no" then
		self:MarkAbsent(sender)
	elseif p.kind == "kill" then
		local run = self:Current()
		if run and p.id then
			run.kills[p.id] = (run.kills[p.id] or 0) + 1
			run.seen = run.seen or U.Now()
			run.seenName = run.seenName or p.name
			FP:Print(FP.GREEN .. "rare watch: " .. tostring(p.name or p.id) .. " looted by " .. tostring(sender) .. "|r")
			FP:Fire("RARE_CHANGED")
		end
	end
	return true
end

-------------------------------------------------------------------------------
-- HUD
-------------------------------------------------------------------------------
local function savePosition(frame)
	local s = settings()
	local point, _, _, x, y = frame:GetPoint(1)
	if point then s.point, s.x, s.y = point, x, y end
end

function RW:MacroText()
	local lines = {}
	for _, r in ipairs(self:Watch().rares or {}) do
		if r.name and r.name ~= "" then lines[#lines + 1] = "/targetexact " .. r.name end
	end
	return table.concat(lines, "\n")
end

-- Secure attributes may only change out of combat; retry after combat.
function RW:ApplyMacro()
	if not self.scan then return end
	if API.InCombat() then self.macroPending = true; return end
	self.macroPending = nil
	self.scan:SetAttribute("type", "macro")
	self.scan:SetAttribute("macrotext", self:MacroText())
end

function RW:OnInit()
	FP.db.rare = FP.db.rare or {}
	local d = FP.db.rare
	d.runs, d.order = d.runs or {}, d.order or {}
	if type(FP.db.rareWatch) ~= "table" then
		FP.db.rareWatch = { instance = RW.DEFAULT_WATCH.instance, rares = {} }
		for i, r in ipairs(RW.DEFAULT_WATCH.rares) do FP.db.rareWatch.rares[i] = { id = r.id, name = r.name } end
	end
	for _, key in ipairs(d.order) do local run = d.runs[key]; if run then run.kills = run.kills or {}; run.sightings = run.sightings or {} end end

	local f = CreateFrame("Frame", "ForeverPathRareHUD", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(WIDTH, 96)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame) if not settings().locked then frame:StartMoving() end end)
	f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing(); savePosition(frame) end)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
		f:SetBackdropBorderColor(1, 0.82, 0, 0.8)
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.title = title
	title:SetPoint("TOPLEFT", 8, -6)
	title:SetText(FP.COLOR .. "ForeverPath|r " .. FP.GOLD .. "rare watch|r")
	local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.status = status
	status:SetPoint("TOPLEFT", 8, -22)
	status:SetWidth(WIDTH - 16)
	status:SetJustifyH("LEFT")
	local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	self.nameText = nameText
	nameText:SetPoint("TOPLEFT", 8, -40)
	nameText:SetWidth(WIDTH - 16)
	nameText:SetJustifyH("LEFT")
	local detail = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.detail = detail
	detail:SetPoint("TOPLEFT", 8, -56)
	detail:SetWidth(WIDTH - 16)
	detail:SetJustifyH("LEFT")
	local stats = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.stats = stats
	stats:SetPoint("BOTTOMLEFT", 8, 8)
	stats:SetWidth(WIDTH - 110)
	stats:SetJustifyH("LEFT")

	-- The Scan button is a protected frame: it lives on UIParent (never shown or
	-- hidden by the HUD in combat) and is anchored to the HUD.
	local scan = CreateFrame("Button", "ForeverPathRareScan", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
	self.scan = scan
	scan:SetSize(60, 20)
	scan:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
	scan:SetText("Scan")
	scan:RegisterForClicks("AnyUp", "AnyDown")
	scan:SetScript("PostClick", function() FP.Throttle("rare-scan", 0.3, function() RW:AfterScan() end) end)
	scan:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:AddLine("Scan for the watched rares", 1, 0.82, 0)
		GameTooltip:AddLine("Runs the macro below once per click (same as a /targetexact macro). Finds a rare only if the client has it loaded — walk toward its lair and press again.", 1, 1, 1, true)
		GameTooltip:AddLine(RW:MacroText(), 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	scan:SetScript("OnLeave", function() GameTooltip:Hide() end)
	scan:Hide()
	local absent = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	self.absentButton = absent
	absent:SetSize(56, 20)
	absent:SetPoint("RIGHT", scan, "LEFT", -4, 0)
	absent:SetText("Not up")
	absent:SetScript("OnClick", function() RW:MarkAbsent() end)
	absent:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:AddLine("Mark this run: checked the lair, rare not up", 1, 0.82, 0)
		GameTooltip:Show()
	end)
	absent:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self:ApplySettings()
	self:ApplyMacro()
	f:Hide()
end

function RW:ApplySettings()
	local s = settings()
	local f = self.frame
	f:ClearAllPoints()
	f:SetPoint(s.point or "TOP", UIParent, s.point or "TOP", s.x or 0, s.y or -200)
	f:SetScale(s.scale or 1)
end

function RW:ResetPosition()
	local s = settings()
	s.point, s.x, s.y, s.scale = "TOP", 0, -200, 1
	self:ApplySettings()
end

function RW:ShouldShow()
	local s = settings()
	if not s.enabled or s.manual == "hide" then return false end
	if s.manual == "show" then return true end
	return self.inside and true or false
end

function RW:StatusLines()
	local run = self:Current()
	local watch = self:Watch()
	local primary = watch.rares and watch.rares[1] and watch.rares[1].name or "rare"
	if not self.inside then
		return FP.GREY .. "Not in " .. tostring(watch.instance) .. "|r", "", ""
	end
	if not run then return FP.GREY .. "No run open|r", "", "" end
	local status, detail
	if next(run.kills) then
		local names = {}
		for id, n in pairs(run.kills) do local r = self:MatchID(id); names[#names + 1] = (r and r.name or ("#" .. id)) .. (n > 1 and (" x" .. n) or "") end
		table.sort(names)
		status = FP.GREEN .. "KILLED: " .. table.concat(names, ", ") .. "|r"
		detail = "This run is done. Reset for the next roll."
	elseif run.seen then
		local last = run.sightings[#run.sightings]
		status = FP.GOLD .. "RARE UP" .. (run.seenName and (": " .. run.seenName) or "") .. "|r"
		detail = (last and self:Describe({ level = last.lvl, creatureType = last.ct, classification = last.cls, by = last.by, dead = last.dead }) or "") .. " · " .. U.FormatTime(U.Now() - run.lastSeen) .. " ago"
	elseif run.absent then
		status = FP.RED .. primary .. ": not up this run|r"
		detail = "Marked " .. U.FormatTime(U.Now() - run.absent) .. " ago" .. (run.absentBy and (" by " .. run.absentBy) or "") .. ". Reset and try again."
	else
		status = FP.GREY .. primary .. ": unknown|r"
		detail = (run.scans or 0) > 0 and (run.scans .. " scan" .. (run.scans > 1 and "s" or "") .. " with no hit — walk toward the lair and scan again") or "Press Scan while walking in, or target/mouse over anything rare."
	end
	local st = self:Stats()
	local stats = string.format("Runs %d · seen %d · killed %d%s · ~5%% expected", st.runs, st.seen, st.killed,
		st.rate and string.format(" · %.0f%% of %d checked", st.rate * 100, st.checked) or "")
	return status, detail, stats
end

function RW:Refresh()
	local f = self.frame
	local show = self:ShouldShow()
	if show then
		local status, detail, stats = self:StatusLines()
		self.status:SetText(status)
		self.detail:SetText(detail)
		self.stats:SetText(stats)
		local run = self:Current()
		if not (run and run.seen and self.nameShown) then self.nameText:SetText(""); self.nameShown = nil end
		if self.inside then self.absentButton:Show() else self.absentButton:Hide() end
		f:Show()
	else
		f:Hide()
	end
	-- protected frame: only touch it out of combat
	if not API.InCombat() then
		if show and self.inside then self.scan:Show() else self.scan:Hide() end
		self.scanPending = nil
	else
		self.scanPending = true
	end
end

function RW:RequestRefresh()
	FP.Throttle("rare-refresh", 0.2, function() RW:Refresh() end)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local resetPattern
local function isResetMessage(text)
	if type(text) ~= "string" then return nil end
	if not resetPattern then
		local fmt = type(INSTANCE_RESET_SUCCESS) == "string" and INSTANCE_RESET_SUCCESS or "%s has been reset."
		resetPattern = "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
	end
	return text:match(resetPattern)
end
RW.IsResetMessage = isResetMessage

function RW:OnEnable()
	local E = FP.RegisterEvent
	E(FP, "PLAYER_ENTERING_WORLD", function() FP.After(1, function() RW:OnEnterWorld() end) end)
	E(FP, "ZONE_CHANGED_NEW_AREA", function() FP.After(1, function() RW:OnEnterWorld() end) end)
	E(FP, "PLAYER_TARGET_CHANGED", function() RW:OnUnit("target", "target"); RW:RequestRefresh() end)
	E(FP, "UPDATE_MOUSEOVER_UNIT", function() RW:OnUnit("mouseover", "mouseover") end)
	E(FP, "PLAYER_FOCUS_CHANGED", function() RW:OnUnit("focus", "focus") end)
	E(FP, "NAME_PLATE_UNIT_ADDED", function(_, unit) if type(unit) == "string" then RW:OnUnit(unit, "nameplate") end end)
	E(FP, "UNIT_TARGET", function(_, unit)
		if type(unit) == "string" and (unit:match("^party%d$") or unit:match("^partypet%d$") or unit == "pet") then RW:OnUnit(unit .. "target", unit .. "-target") end
	end)
	E(FP, "LOOT_OPENED", function() RW:OnLoot() end)
	E(FP, "CHAT_MSG_SYSTEM", function(_, text)
		text = FP.safe(text)
		local which = isResetMessage(text)
		if which then
			local run = RW:Current()
			if run then RW:CloseRun("reset:" .. tostring(which)) end
			RW.lastReset = U.Now()
			FP:Print(FP.GREY .. "rare watch: instance reset — next entry starts a new run|r")
		end
	end)
	E(FP, "CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
		prefix, msg, channel, sender = FP.safe(prefix), FP.safe(msg), FP.safe(channel), FP.safe(sender)
		if prefix ~= API.PREFIX or channel ~= "PARTY" or type(msg) ~= "string" or msg:sub(1, 3) ~= "RW;" or not API.IsPartySender(sender) then return end
		RW:Receive(msg, sender)
	end)
	E(FP, "VIGNETTE_MINIMAP_UPDATED", function() FP.Throttle("rare-vignette", 1, function() RW:ProbeVignettes("minimap") end) end)
	E(FP, "VIGNETTES_UPDATED", function() FP.Throttle("rare-vignette", 1, function() RW:ProbeVignettes("updated") end) end)
	E(FP, "PLAYER_REGEN_ENABLED", function()
		if RW.macroPending then RW:ApplyMacro() end
		if RW.scanPending then RW:Refresh() end
	end)
	FP:On("RARE_CHANGED", function() RW:RequestRefresh() end)
	self.ticker = C_Timer.NewTicker(30, function() if RW.frame:IsShown() then RW:Refresh() end end)
	FP.After(2, function() RW:OnEnterWorld() end)
end

-------------------------------------------------------------------------------
-- /fp rare ...
-------------------------------------------------------------------------------
function RW:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub = (args[1] or ""):lower()
	local s, watch = settings(), self:Watch()
	local p = function(...) FP:Print(...) end
	if sub == "" or sub == "status" then
		local status, detail, stats = self:StatusLines()
		p("rare watch " .. (s.enabled and "on" or "off") .. " · watching " .. tostring(watch.instance) .. " · share " .. (s.share and "on" or "off") .. " · sound " .. (s.sound and "on" or "off"))
		p(status .. (detail ~= "" and ("  " .. detail) or ""))
		p(stats)
		local run = self:Current()
		if run then p(string.format("current run: key %s · scans %d · opened %s ago%s", tostring(run.key), run.scans or 0, U.FormatTime(U.Now() - run.t), run.zoneUID and "" or " (instance id unknown until you loot something)")) end
	elseif sub == "show" then s.manual = "show"; self:Refresh(); p("rare hud shown")
	elseif sub == "hide" then s.manual = "hide"; self:Refresh(); p("rare hud hidden")
	elseif sub == "auto" then s.manual = nil; self:Refresh(); p("rare hud automatic (shows inside " .. tostring(watch.instance) .. ")")
	elseif sub == "on" then s.enabled = true; self:Refresh(); p("rare watch on")
	elseif sub == "off" then s.enabled = false; self:Refresh(); p("rare watch off")
	elseif sub == "share" then s.share = args[2] ~= "off"; p("rare share " .. (s.share and "on" or "off"))
	elseif sub == "sound" then s.sound = args[2] ~= "off"; p("rare sound " .. (s.sound and "on" or "off"))
	elseif sub == "lock" then s.locked = true; p("rare hud locked")
	elseif sub == "unlock" then s.locked = false; p("rare hud unlocked")
	elseif sub == "reset" then self:ResetPosition(); p("rare hud position reset")
	elseif sub == "scale" then s.scale = math.max(0.5, math.min(2, tonumber(args[2] or "") or 1)); self:ApplySettings(); p("rare hud scale " .. s.scale)
	elseif sub == "scan" then
		p("the Scan button runs this macro (paste it into your own macro if you prefer a keybind):")
		for _, line in ipairs(U.Split(self:MacroText(), "\n")) do p("  " .. line) end
		p("it only finds a rare the client has loaded: press it while walking toward the lair.")
	elseif sub == "notup" or sub == "absent" then self:MarkAbsent()
	elseif sub == "newrun" then
		local inside, inst = self:InWatchedInstance()
		if not inside then p("not inside " .. tostring(watch.instance)); return end
		self:CloseRun("manual")
		self:OpenRun(inst, "manual")
		p("new run opened")
	elseif sub == "runs" then
		local d = db()
		local from = math.max(1, #d.order - 9)
		for i = from, #d.order do
			local run = d.runs[d.order[i]]
			if run then
				local outcome = next(run.kills) and "killed" or (run.seen and "seen") or (run.absent and "not up") or ((run.scans or 0) > 0 and "scanned, no hit") or "unchecked"
				p(string.format("  #%d %s · %s · scans %d · %s%s", i, tostring(run.instance), outcome, run.scans or 0, run.zoneUID and ("id " .. run.zoneUID) or "no id", run.closed and (" · " .. tostring(run.closedWhy)) or ""))
			end
		end
		if #d.order == 0 then p("  no runs yet") end
	elseif sub == "instance" then
		local name = table.concat(args, " ", 2)
		if name == "" then p("usage: /fp rare instance <part of the instance name>"); return end
		watch.instance = name
		p("watching instance: " .. name)
		self:OnEnterWorld()
	elseif sub == "add" then
		local id = tonumber(args[2])
		local name = table.concat(args, " ", id and 3 or 2)
		if name == "" then p("usage: /fp rare add [creature id] <exact rare name>"); return end
		watch.rares[#watch.rares + 1] = { id = id, name = name }
		self:ApplyMacro()
		p("watching " .. name .. (id and (" (id " .. id .. ")") or ""))
	elseif sub == "rm" or sub == "remove" then
		local name = table.concat(args, " ", 2):lower()
		for i = #watch.rares, 1, -1 do if (watch.rares[i].name or ""):lower() == name then table.remove(watch.rares, i) end end
		self:ApplyMacro()
		p("watch list: " .. #watch.rares .. " rares")
	elseif sub == "list" then
		p("instance: " .. tostring(watch.instance))
		for _, r in ipairs(watch.rares) do p("  " .. tostring(r.name) .. (r.id and (" (id " .. r.id .. ")") or "")) end
	elseif sub == "clear" and args[2] == "confirm" then
		FP.db.rare = { runs = {}, order = {} }
		self:OnEnterWorld()
		p("rare watch runs cleared")
	else
		p("rare: status | show | hide | auto | on | off | scan | notup | newrun | runs | list | add [id] <name> | rm <name> | instance <name> | share on|off | sound on|off | lock | unlock | reset | scale <n> | clear confirm")
	end
	FP:Fire("RARE_CHANGED")
end
