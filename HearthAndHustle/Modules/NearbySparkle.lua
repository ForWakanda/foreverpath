-- HearthAndHustle / Modules / NearbySparkle.lua
-- Nearby-object sparkles: retired in v0.27.1 (owner's report, 2026-11-16).
-- v0.27.0 offered an extra sparkle on the one object the game's Interact Key
-- selects. It needed the Interact Key mode switched on, reached about 15 yards,
-- and that mode also changes who an untargeted heal or buff lands on. The
-- display, its setup button and every read of the interact object are gone.
--
-- What is left is the undo. A character that switched the mode on still has the
-- game settings it changed, because the game saves those itself. Setup wrote
-- down each one it changed and its earlier value. This file puts those back and
-- then forgets the list:
--   * never in combat,
--   * only a setting that is still at the value setup gave it; one that was
--     changed since belongs to the player and stays,
--   * it can only write a remembered value, never the setup values.
-- Nothing here can switch the mode on.
local ADDON, FP = ...
local API = FP.API
local N = FP:NewModule("NearbySparkle")

local LOGIN_DELAY = 5    -- settings synced from the account can arrive after PLAYER_LOGIN
local RECHECK     = 10   -- seconds between looks while something is still owed
local SETTLE      = 30   -- a setting that differs must still differ this long after it was first seen to count as the player's
local MAX_REFUSED = 3    -- looks per session at a setting the client will not give back

local function store()
	local q = FP.db.questSparkle
	return type(q.nearby) == "table" and q.nearby or nil
end
local function ledger()
	local st = store()
	return st and type(st.restore) == "table" and st.restore or nil
end
local function receipt()
	local st = store()
	if type(st.retired) ~= "table" then st.retired = {} end
	local r = st.retired
	if type(r.restored) ~= "table" then r.restored = {} end
	if type(r.kept) ~= "table" then r.kept = {} end
	return r
end

-- Settings still waiting to be put back.
function N:Pending()
	local rows = ledger()
	return rows and #rows or 0
end

-- One live timer; a request that arrives while it runs is covered by it.
function N:Schedule(delay, reason)
	if self.timer or self.stopped or self:Pending() == 0 then return end
	self.timer = true
	FP.After(delay, function()
		N.timer = nil
		N:Pass(reason)
	end)
end

function N:Pass(reason)
	local rows = ledger()
	if not rows or #rows == 0 then return self:Finish() end
	if self.stopped then return end
	if API.InCombat() then self.deferred = true; return end
	local r, now = receipt(), API.Time()
	local refused, recheck = 0, false
	-- Newest first: the Interact Key mode itself goes back before its display settings.
	for i = #rows, 1, -1 do
		local row = type(rows[i]) == "table" and rows[i] or {}
		local name, before, applied = row.name, row.before, row.applied
		if type(name) ~= "string" or type(before) ~= "string" or tonumber(before) == nil
			or tonumber(applied) == nil or tonumber(before) == tonumber(applied) then
			table.remove(rows, i)   -- nothing here that could be put back
		else
			local value, why = API.RetiredNearbySetting(name)
			if why == "unknown" then
				table.remove(rows, i)   -- not a setting the mode ever wrote: not ours to touch or to mention
			elseif value == nil or tonumber(value) == nil then
				refused = refused + 1; r.failed = "unreadable"
			elseif tonumber(value) ~= tonumber(applied) then
				-- Not what setup wrote. Either the player changed it, or the account's
				-- settings have not arrived yet: keep looking for a while before letting go.
				self.differs[name] = self.differs[name] or now
				if now - self.differs[name] >= SETTLE then
					table.remove(rows, i)
					r.kept[#r.kept + 1] = { name = name, value = value, before = before, applied = tostring(applied) }
				else
					recheck = true
				end
			else
				self.differs[name] = nil
				self.writing = true
				local ok, why = API.RestoreRetiredNearbySetting(name, before)
				self.writing = nil
				if self.blocked then ok, why, self.blocked = false, "blocked", nil end
				if ok then
					table.remove(rows, i)
					r.restored[#r.restored + 1] = { name = name, from = value, to = before }
				elseif why == "combat" then
					self.deferred = true
					return
				else
					refused = refused + 1; r.failed = why
				end
			end
		end
	end
	r.t, r.version, r.build, r.reason, r.pending = API.Now(), FP.version, FP.clientBuild, reason, #rows
	if #rows == 0 then return self:Finish() end
	if refused > 0 then
		self.refusals = (self.refusals or 0) + 1
		if self.refusals >= MAX_REFUSED then
			self.stopped = true
			self:TellRefused()
			return
		end
	elseif not recheck then
		return
	end
	self:Schedule(RECHECK, "recheck")
end

-- The list is empty: forget the mode and say once what happened.
function N:Finish()
	local wasOn = FP.settings.questSparkle.nearby == true
	FP.settings.questSparkle.nearby = nil   -- the retired switch must not come back from a saved profile
	local st = store()
	if not st then return end
	st.restore = {}
	local r = receipt()
	r.failed, r.pending = nil, 0
	if r.told or (not wasOn and #r.restored == 0 and #r.kept == 0) then return end
	r.told, r.done = true, API.Now()
	local line = "The nearby sparkle mode has been removed: it needed the game's Interact Key mode, which also changes who an untargeted heal or buff lands on."
	if #r.restored > 0 then
		line = line .. " Put back " .. #r.restored .. " game setting" .. (#r.restored == 1 and "" or "s") .. " it had changed."
	end
	if #r.kept > 0 then
		line = line .. " Left " .. #r.kept .. " alone that " .. (#r.kept == 1 and "was" or "were") .. " changed since."
	end
	if #r.restored == 0 and #r.kept == 0 then line = line .. " It had changed no game setting." end
	FP:Print(line .. " The game's own quest sparkle is untouched.")
end

-- The client would not take a value back: stop for this session and hand over
-- the exact commands. The list is kept, so the next login tries again.
function N:TellRefused()
	local rows = ledger()
	if not rows or #rows == 0 or self.toldRefused then return end
	self.toldRefused = true
	local commands = {}
	for i = #rows, 1, -1 do
		local row = rows[i]
		if type(row) == "table" and type(row.name) == "string" and type(row.before) == "string" then
			commands[#commands + 1] = "/console " .. row.name .. " " .. row.before
		end
	end
	FP:Print(FP.RED .. "Could not put back " .. #rows .. " game setting" .. (#rows == 1 and "" or "s")
		.. " the removed nearby sparkle mode had changed.|r Hearth & Hustle tries again at the next login. By hand, one line each: "
		.. table.concat(commands, "   "))
end

-- For /hh sparkle: says something only while an undo is still owed.
function N:Lines()
	local n = self:Pending()
	if n == 0 then return {} end
	return { "Removed nearby sparkle mode: " .. n .. " game setting" .. (n == 1 and "" or "s") .. " still to put back"
		.. (self.stopped and " (the client refused; trying again at the next login)" or " (after combat, within seconds otherwise)") }
end

function N:OnEnable()
	self.differs = {}
	if self:Pending() == 0 then self:Finish(); return end   -- nothing owed: no events, no timers
	local E = function(ev, fn) FP:RegisterEvent(ev, fn) end
	E("PLAYER_ENTERING_WORLD", function() N:Schedule(LOGIN_DELAY, "world") end)
	-- A setting changed (the account's settings arriving, or the player): look
	-- soon, whatever the slower timer is doing.
	E("CVAR_UPDATE", function()
		if N.stopped or N:Pending() == 0 then return end
		FP.Throttle("nearby-retired", 1, function() N:Pass("setting") end)
	end)
	E("PLAYER_REGEN_ENABLED", function()
		if N.deferred then
			N.deferred = nil
			N:Pass("combat end")
		end
	end)
	for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
		E(event, function(_, addon)
			if N.writing and FP.safe(addon) == ADDON then N.blocked = true end
		end)
	end
	self:Schedule(LOGIN_DELAY, "login")
end
