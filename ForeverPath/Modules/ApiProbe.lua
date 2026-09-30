-- ForeverPath / Modules / ApiProbe.lua
-- Development diagnostic: records WHICH values the Forever client hands addons
-- as secrets, and under which restriction state, whenever the situation
-- changes (combat in/out, target change, zone, PvP match state). It only asks
-- "is this value secret?" and never operates on secret values. Findings land
-- in ForeverPathDB.probe so they can be read from the SavedVariables file.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local P = FP:NewModule("Probe")

local issecret = FP.issecret
local issecrettable = (type(_G.issecrettable) == "function") and _G.issecrettable or function() return false end
local MAX_SAMPLES = 200

local RESTRICTIONS = { [0] = "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

local function has(tbl, fn) return type(tbl) == "table" and type(tbl[fn]) == "function" end

-- Returns "secret" | "nil" | type name; never branches on the value itself.
local function classify(...)
	local n = select("#", ...)
	if n == 0 then return "none" end
	local v = (...)
	if v == nil then return "nil" end
	if issecret(v) then return "secret" end
	if type(v) == "table" and issecrettable(v) then return "secrettable" end
	return type(v)
end

local function try(fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return "error" end
	return classify(a, b, c)
end

local function tableField(t, key)
	if type(t) ~= "table" then return classify(t) end
	if issecrettable(t) then return "secrettable" end
	return classify(rawget(t, key))
end

function P:Context()
	local ctx = {}
	ctx.combat = (InCombatLockdown and InCombatLockdown()) and 1 or 0
	if UnitAffectingCombat then ctx.affecting = try(UnitAffectingCombat, "player") end
	local inInst, kind = API.InInstance()
	ctx.inst = inInst and (kind or "?") or "none"
	if has(C_PvP, "IsBattleground") then ctx.bg = C_PvP.IsBattleground() and 1 or 0 end
	if has(C_PvP, "GetActiveMatchState") then ctx.match = C_PvP.GetActiveMatchState() end
	if has(C_PvP, "GetZonePVPInfo") then local t = C_PvP.GetZonePVPInfo(); ctx.pvp = FP.safe(t) end
	ctx.zone = (API.GetZoneText())
	if has(C_Secrets, "HasSecretRestrictions") then ctx.hasSecrets = C_Secrets.HasSecretRestrictions() and 1 or 0 end
	if has(C_RestrictedActions, "IsAddOnRestrictionActive") then
		local active = {}
		for i = 0, 5 do
			local ok, r = pcall(C_RestrictedActions.IsAddOnRestrictionActive, i)
			if ok and r then active[#active + 1] = RESTRICTIONS[i] end
		end
		ctx.active = table.concat(active, ",")
	end
	if has(C_ChatInfo, "InChatMessagingLockdown") then ctx.chatLock = C_ChatInfo.InChatMessagingLockdown() and 1 or 0 end
	if C_Secrets then
		if has(C_Secrets, "ShouldAurasBeSecret") then ctx.pAuras = C_Secrets.ShouldAurasBeSecret() and 1 or 0 end
		if has(C_Secrets, "ShouldCooldownsBeSecret") then ctx.pCooldowns = C_Secrets.ShouldCooldownsBeSecret() and 1 or 0 end
	end
	return ctx
end

function P:UnitProbe(unit)
	if not FP.safe(UnitExists(unit)) then return nil end
	local u = { unit = unit }
	u.isPlayer = try(UnitIsPlayer, unit)
	if u.isPlayer == "boolean" then u.isPlayer = UnitIsPlayer(unit) and "player" or "npc" end
	u.reaction = try(UnitReaction, "player", unit)
	if u.reaction == "number" then u.reaction = UnitReaction("player", unit) end
	u.name = try(UnitName, unit)
	u.guid = try(UnitGUID, unit)
	u.class = try(UnitClass, unit)
	u.level = try(UnitLevel, unit)
	u.health = try(UnitHealth, unit)
	u.healthMax = try(UnitHealthMax, unit)
	u.power = try(UnitPower, unit)
	if UnitCastingInfo then u.casting = try(UnitCastingInfo, unit) end
	if has(C_UnitAuras, "GetAuraDataByIndex") then
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL")
		u.aura = ok and (a == nil and "nil" or tableField(a, "name")) or "error"
	end
	if C_Secrets then
		if has(C_Secrets, "ShouldUnitIdentityBeSecret") then u.pIdentity = C_Secrets.ShouldUnitIdentityBeSecret(unit) and 1 or 0 end
		if has(C_Secrets, "ShouldUnitSpellCastingBeSecret") then u.pCast = C_Secrets.ShouldUnitSpellCastingBeSecret(unit) and 1 or 0 end
	end
	return u
end

function P:Signature(sample)
	local parts = {}
	local function add(prefix, t)
		if not t then parts[#parts + 1] = prefix .. "=-"; return end
		local keys = {}
		for k in pairs(t) do if k ~= "unit" and k ~= "zone" then keys[#keys + 1] = k end end
		table.sort(keys)
		for _, k in ipairs(keys) do parts[#parts + 1] = prefix .. k .. "=" .. tostring(t[k]) end
	end
	add("c.", sample.ctx)
	add("p.", sample.player)
	add("t.", sample.target)
	return table.concat(parts, " ")
end

function P:Sample(trigger)
	if not (FP.settings.probe and FP.settings.probe.enabled) then return end
	local db = FP.db.probe
	local sample = { t = U.Now(), trig = trigger, ctx = self:Context(), player = self:UnitProbe("player"), target = self:UnitProbe("target") }
	local sig = self:Signature(sample)
	if sig == db.lastSig then
		db.repeats = (db.repeats or 0) + 1
		return
	end
	db.lastSig = sig
	sample.sig = sig
	U.Push(db.samples, sample, MAX_SAMPLES)
	db.count = (db.count or 0) + 1
	FP:Debug("probe:", trigger, sig)
end

function P:OnInit()
	FP.db.probe = FP.db.probe or { samples = {}, events = {}, registration = {} }
	FP.db.probe.samples = FP.db.probe.samples or {}
	FP.db.probe.events = FP.db.probe.events or {}
	FP.db.probe.registration = FP.db.probe.registration or {}
end

function P:OnEnable()
	local db = FP.db.probe
	-- Do NOT probe combat-log event registration: on build 70124 registering
	-- COMBAT_LOG_EVENT(_UNFILTERED)/COMBAT_LOG_MESSAGE/ENCOUNTER_TIMELINE_EVENT_ADDED
	-- succeeds in Lua (no error for pcall to catch) but the client raises the
	-- "blocked from an action only available to the Blizzard UI" popup.
	-- Observed 2026-09-30 in game; the answer is already known from the docs.
	db.registration = { note = "combat-log events are Blizzard-only on Forever; not probed (blocked-action popup observed 2026-09-30)" }
	-- state transitions
	local E = FP.RegisterEvent
	E(FP, "PLAYER_REGEN_DISABLED", function() P:Sample("combat-start"); FP.After(2, function() P:Sample("combat+2s") end) end)
	E(FP, "PLAYER_REGEN_ENABLED", function() P:Sample("combat-end") end)
	E(FP, "ADDON_RESTRICTION_STATE_CHANGED", function(_, kind, state)
		FP.After(0, function() P:Sample("restriction:" .. tostring(RESTRICTIONS[kind] or kind) .. "=" .. tostring(state)) end)
	end)
	E(FP, "PLAYER_TARGET_CHANGED", function() FP.Throttle("probe-target", 1, function() P:Sample("target") end) end)
	E(FP, "ZONE_CHANGED_NEW_AREA", function() FP.After(1, function() P:Sample("zone") end) end)
	E(FP, "PVP_MATCH_STATE_CHANGED", function() FP.After(1, function() P:Sample("pvp-match") end) end)
	E(FP, "PLAYER_ENTERING_WORLD", function() FP.After(5, function() P:Sample("enter-world") end) end)
	E(FP, "DUEL_REQUESTED", function() P:Sample("duel-requested") end)
	E(FP, "DUEL_FINISHED", function() P:Sample("duel-finished") end)
	-- event payload secrecy counters (own casts vs target casts, target auras)
	local uf = CreateFrame("Frame")
	local function count(key) db.events[key] = (db.events[key] or 0) + 1 end
	uf:SetScript("OnEvent", function(_, event, unit, a, b)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			count(event .. ":" .. tostring(unit) .. ":" .. classify(b))
		elseif event == "UNIT_AURA" then
			count(event .. ":" .. tostring(unit) .. ":" .. (type(a) == "table" and (issecrettable(a) and "secrettable" or "table") or classify(a)))
		end
	end)
	pcall(uf.RegisterUnitEvent, uf, "UNIT_SPELLCAST_SUCCEEDED", "player", "target")
	pcall(uf.RegisterUnitEvent, uf, "UNIT_AURA", "player", "target")
	FP.After(8, function() P:Sample("login") end)
end

function P:Status()
	local db = FP.db.probe
	local s = FP.settings.probe or {}
	local lines = { string.format("probe %s · %d distinct states recorded (%d repeats)", s.enabled and "on" or "off", db.count or 0, db.repeats or 0) }
	local last = db.samples[#db.samples]
	if last then lines[#lines + 1] = "last (" .. tostring(last.trig) .. "): " .. last.sig end
	local reg = {}
	for ev, r in pairs(db.registration) do reg[#reg + 1] = ev .. "=" .. r end
	table.sort(reg)
	lines[#lines + 1] = "registration: " .. table.concat(reg, "  ")
	local ev = {}
	for k, n in pairs(db.events) do ev[#ev + 1] = k .. "×" .. n end
	table.sort(ev)
	if #ev > 0 then lines[#lines + 1] = "events: " .. table.concat(ev, "  ") end
	return lines
end
