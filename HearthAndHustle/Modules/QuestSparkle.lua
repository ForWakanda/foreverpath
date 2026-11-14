-- HearthAndHustle / Modules / QuestSparkle.lua
-- Quest item sparkles (v0.20.0). The client can draw its own sparkle on quest
-- items lying in the world. One console variable switches it, and a graphics
-- preset switches it back off. This module keeps that one setting on:
--   * it writes outlineModeShowLootEffectWhenDisabled and nothing else,
--   * it never writes in combat,
--   * it never touches Outline Mode or any other setting of the player's,
--   * switched off, it puts back a setting that it switched on itself.
-- The game decides what sparkles; the addon cannot pick objects.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local Q = FP:NewModule("QuestSparkle")

local LOGIN_DELAY  = 5    -- settings synced from the account can arrive after PLAYER_LOGIN
local SETTLE       = 1    -- a graphics preset changes many settings in one go
local FIGHT_WINDOW = 60   -- seconds
local FIGHT_MAX    = 4    -- this many re-applies inside the window: something else wants it off

local OUTLINE_HINT = "Outline Mode is on in your graphics options. If items show an outline and no sparkle, set Options > Graphics > Outline Mode to Disabled."

local function s() return FP.settings.questSparkle end
local function store() return FP.db.questSparkle end

-- What the last look did, kept for the next data pull.
function Q:Note(reason, was, failed)
	store().last = { t = API.Now(), build = FP.clientBuild, version = FP.version, reason = reason, was = was,
		outline = API.OutlineModeOn(), failed = failed }
end

-- One live timer; requests that arrive while it runs are covered by it.
function Q:Schedule(delay, reason)
	if self.timer or not FP.dbReady then return end
	if s().enabled then if self.stopped then return end
	elseif not self.pendingOff then return end
	self.timer = true
	FP.After(delay, function()
		Q.timer = nil
		if s().enabled then Q:Apply(reason) elseif Q.pendingOff then Q:Restore() end
	end)
end

function Q:Apply(reason)
	if not FP.dbReady or not s().enabled or self.stopped then return end
	local was = API.GetLootSparkle()
	if was == nil or was == "1" then return end   -- no such setting on this client, or already on
	if API.InCombat() then self.deferred = true; return end
	local now = API.Time()
	local recent = {}
	for _, t in ipairs(self.writes) do
		if now - t <= FIGHT_WINDOW then recent[#recent + 1] = t end
	end
	self.writes = recent
	if #recent >= FIGHT_MAX then
		-- Another addon or a console alias keeps switching it off. It wins.
		self.stopped = "contested"
		self:Note(reason, was, "contested")
		FP:Print("Something else keeps switching the quest item sparkle off. Hearth & Hustle leaves the setting alone until the next login." .. FP.GREY .. " /hh sparkle|r")
		return
	end
	self.writing = true
	local ok, why = API.SetLootSparkle(true)
	self.writing = nil
	if self.blocked then ok, why = false, "blocked" end
	if not ok then
		if why == "combat" then self.deferred = true; return end
		self.stopped = why
		self:Note(reason, was, why)
		FP:Print(FP.RED .. "The client did not accept the quest item sparkle setting.|r Hearth & Hustle leaves it alone until the next login.")
		return
	end
	self.writes[#self.writes + 1] = now
	local st = store()
	st.ours = true
	st.count = (st.count or 0) + 1
	self:Note(reason, was)
	if not st.introduced then
		st.introduced = true
		FP:Print("Quest items you can pick up now sparkle: the game's own effect, kept switched on."
			.. (API.OutlineModeOn() and (" " .. OUTLINE_HINT) or "") .. FP.GREY .. " /hh sparkle|r")
	end
end

-- Switching the feature off: a setting this addon switched on goes back to off.
-- One that was already on before the addon came is the player's and stays.
function Q:Restore()
	local st = store()
	if not st.ours then self.pendingOff = nil; return "kept" end
	local now = API.GetLootSparkle()
	if now == nil then self.pendingOff = true; return "unavailable" end
	if now ~= "1" then st.ours = nil; self.pendingOff = nil; return "off" end
	if API.InCombat() then self.pendingOff = true; return "combat" end
	self.writing = true
	local ok, why = API.SetLootSparkle(false)
	self.writing = nil
	if self.blocked then ok, why = false, "blocked" end
	if ok then
		st.ours = nil
		self.pendingOff = nil
		self:Note("off", now)
		return "restored"
	end
	if why == "combat" then self.pendingOff = true; return "combat" end
	self.pendingOff = nil
	self:Note("off", now, why)
	return "failed"
end

function Q:OnEnable()
	self.writes = {}
	local E = function(ev, fn) FP:RegisterEvent(ev, fn) end
	-- Any setting change can be a graphics preset; the look itself is one read.
	E("CVAR_UPDATE", function() Q:Schedule(SETTLE, "setting") end)
	E("PLAYER_ENTERING_WORLD", function() Q:Schedule(SETTLE, "world") end)
	E("PLAYER_REGEN_ENABLED", function()
		if Q.pendingOff then
			if FP.dbReady and not s().enabled then Q:Restore() end
		end
		if Q.deferred then
			Q.deferred = nil
			Q:Apply("combat end")
		end
	end)
	for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
		E(event, function(_, addon)
			if Q.writing and FP.safe(addon) == ADDON then Q.blocked = true end
		end)
	end
	-- Disabled + owned is the persisted form of an unfinished off request.
	if not s().enabled and store().ours then self:Restore() else self:Apply("login") end
	self:Schedule(LOGIN_DELAY, "login")
end

function Q:Lines()
	local out = {}
	local state = API.GetLootSparkle()
	if state == nil then
		out[1] = "Quest item sparkles: this client has no such setting."
		return out
	end
	local paused = ""
	if self.stopped == "contested" then paused = " (paused until the next login: something else keeps switching it off)"
	elseif self.stopped then paused = " (paused until the next login: the client did not accept the setting)" end
	out[1] = "Quest item sparkles " .. (s().enabled and "on" or "off") .. paused
	out[2] = "  game setting: " .. (state == "1" and "on" or "off")
		.. ((state == "1" and not s().enabled) and " (the game keeps it until you switch it off there)" or "")
		.. ((self.deferred or self.pendingOff) and " (change pending: combat or setting unavailable)" or "")
	if s().enabled and API.OutlineModeOn() then out[#out + 1] = "  " .. OUTLINE_HINT end
	return out
end

function Q:Command(rest)
	local sub = (U.Split(rest or "", " ")[1] or ""):lower()
	if sub == "on" then
		s().enabled = true
		self.pendingOff = nil
		if self.stopped == "contested" then self.stopped, self.writes = nil, {} end   -- asked for again
		self:Apply("on")
		local state = API.GetLootSparkle()
		if state == nil then FP:Print("quest item sparkles: this client has no such setting")
		elseif state == "1" then FP:Print("quest item sparkles on" .. (API.OutlineModeOn() and (". " .. OUTLINE_HINT) or ""))
		elseif self.deferred then FP:Print("quest item sparkles on; the game setting is switched after combat")
		else FP:Print("quest item sparkles on, but the game setting is still off" .. FP.GREY .. " /hh sparkle|r") end
	elseif sub == "off" then
		s().enabled = false
		self.deferred = nil
		local result = self:Restore()
		if result == "restored" then
			FP:Print("quest item sparkles off. The game keeps drawing them until you fully exit and restart it; /reload is not enough.")
		elseif result == "combat" then
			FP:Print("quest item sparkles off; the game setting is switched back after combat")
		elseif result == "unavailable" then
			FP:Print("quest item sparkles off; restoring the previous setting when the client makes it available")
		elseif result == "failed" then
			FP:Print("quest item sparkles off, but the client did not accept the change" .. FP.GREY .. " /hh sparkle|r")
		elseif API.GetLootSparkle() == "1" then
			FP:Print("quest item sparkles off: Hearth & Hustle no longer keeps the setting on. It was on before this addon switched anything, so it stays as it is.")
		else
			FP:Print("quest item sparkles off")
		end
	else
		for _, line in ipairs(self:Lines()) do FP:Print(line) end
		FP:Print("/hh sparkle on|off")
	end
end
