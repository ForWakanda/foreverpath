-- HearthAndHustle / Modules / BarGuard.lua
-- Action bar guard (v0.19.0). On Forever build 70938 a character with dual
-- specialization can log in, change spec or level up and find action bars
-- emptied by the server (bug-report forum, 2026-11-10 onward; no addon involved).
-- This module remembers what is on the bars while you play and puts missing
-- buttons back on their slots. It is bar layout only:
--   * it fills EMPTY slots; it never replaces or removes a button,
--   * it never acts in combat or while you hold something on the cursor,
--   * it never uses, casts or targets anything.
-- A hand edit is one slot at a time and is simply remembered. A wipe is a button
-- that is gone at login or after a spec change, or several gone in one instant.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local B = FP:NewModule("BarGuard")

local LOGIN_DELAY   = 5     -- seconds after PLAYER_LOGIN before the first comparison
local SETTLE        = 1.5   -- quiet time after the last slot change
local SPEC_DELAY    = 3     -- a spec change rewrites every bar; let it finish
local CONFIRM       = 2     -- second look before acting on a burst
local STRICT_WINDOW = 6     -- how long "any missing button is a wipe" stays armed
local BURST_WINDOW  = 0.3   -- slots emptied within this many seconds count as one burst
local BURST_MIN     = 3     -- a person cannot empty this many slots in one burst
local MAX_FAILS     = 3     -- attempts before a button that cannot be placed is forgotten
local MAX_RECHECKS  = 2     -- extra strict passes per login/spec change for late data
local RECHECK_DELAY = 10
local MAX_LOG       = 20

local function s() return FP.settings.barGuard end
local function store() return FP.cdb.barGuard end

local function validSlot(slot)
	if not U.Finite(slot) or slot ~= math.floor(slot) then return false end
	for _, range in ipairs(API.BAR_SLOT_RANGES) do
		if slot >= range[1] and slot <= range[2] then return true end
	end
	return false
end

-- The remembered bars of one spec group, with anything malformed dropped.
function B:Stored(group)
	local bars = store()
	if type(bars.specs) ~= "table" then bars.specs = {} end
	local saved = bars.specs[group]
	if type(saved) ~= "table" or type(saved.slots) ~= "table" then return nil end
	for slot, entry in pairs(saved.slots) do
		if not validSlot(slot) or type(entry) ~= "table" or type(entry.k) ~= "string" then saved.slots[slot] = nil end
	end
	return saved
end

-- The live bars become the memory. Buttons that could not be put back yet are
-- carried until they succeed, the slot is filled, or they have failed MAX_FAILS times.
function B:Save(group, live, old)
	local slots, n = {}, 0
	for slot, entry in pairs(live) do slots[slot] = entry; n = n + 1 end
	local carried = 0
	if old then
		for slot, entry in pairs(old.slots) do
			local fails = entry.fails or 0
			if not slots[slot] and fails > 0 and fails < MAX_FAILS then slots[slot] = entry; carried = carried + 1 end
		end
	end
	store().specs[group] = { slots = slots, n = n, t = API.Now(), build = FP.clientBuild }
	return carried
end

function B:Log(row)
	local bars = store()
	if type(bars.log) ~= "table" then bars.log = {} end
	row.t, row.build, row.version = API.Now(), FP.clientBuild, FP.version
	table.insert(bars.log, row)
	while #bars.log > MAX_LOG do table.remove(bars.log, 1) end
end

-- One live timer; later requests only move the due time.
function B:Schedule(delay)
	local now = API.Time()
	self.dueAt = math.max(now + delay, self.notBefore or 0)
	if self.timer then return end
	self.timer = true
	local function fire()
		local left = (B.dueAt or 0) - API.Time()
		if left > 0.01 then FP.After(left, fire); return end
		B.timer = nil
		B:Reconcile()
	end
	FP.After(math.max(self.dueAt - now, 0.01), fire)
end

-- Largest number of the given slots that changed within one BURST_WINDOW.
function B:Burst(slots)
	local times = {}
	for _, slot in ipairs(slots) do
		local t = self.changed[slot] or self.allChanged
		if t then times[#times + 1] = t end
	end
	table.sort(times)
	local best, first = 0, 1
	for i = 1, #times do
		while times[i] - times[first] > BURST_WINDOW do first = first + 1 end
		if i - first + 1 > best then best = i - first + 1 end
	end
	return best
end

function B:Done(carried)
	local strict = self.strictPending or self.mode ~= "track"
	self.mode = "track"
	self.strictPending = nil
	self.changed, self.allChanged = {}, nil
	-- Spell, item or macro data can arrive late after a login or spec change:
	-- look again, strictly, a bounded number of times.
	if strict and (carried or 0) > 0 and (self.rechecks or 0) < MAX_RECHECKS then
		self.rechecks = (self.rechecks or 0) + 1
		self.mode = "recheck"
		self:Schedule(RECHECK_DELAY)
	end
end

function B:Reconcile()
	if not FP.dbReady or not s().enabled or self.blocked or not API.ActionBarsAvailable() then return end
	if API.InCombat() then self.deferred = true; return end
	self.deferred = nil
	local group = API.ActiveSpecGroup()
	local live = group and API.ReadActionBars()
	if not live then
		-- Unreadable is not empty: change nothing, look again a few times.
		self.unreadable = (self.unreadable or 0) + 1
		if self.unreadable <= 5 then self:Schedule(5) end
		return
	end
	self.unreadable = 0
	local saved = self:Stored(group)
	if not saved then
		self:Save(group, live)
		self:Done()
		local bars = store()
		if not bars.introduced and s().announce then
			bars.introduced = true
			FP:Print("Action bar guard is watching your bars. Buttons that vanish at login, on a spec change or on a level-up are put back." .. FP.GREY .. " /hh bars|r")
		end
		return
	end

	local now = API.Time()
	local strict = self.strictPending or self.mode ~= "track" or now < (self.strictUntil or 0)
	local lost = {}
	for slot, entry in pairs(saved.slots) do
		if not live[slot] and (strict or not entry.fails) then lost[#lost + 1] = slot end
	end
	table.sort(lost)
	if #lost == 0 then
		self:Done(self:Save(group, live, saved))
		return
	end
	if not strict then
		if self:Burst(lost) >= BURST_MIN then
			-- Several buttons vanished in one instant. Look once more before acting:
			-- a spec change announces itself in between and gets its own comparison.
			self.strictUntil = now + STRICT_WINDOW
			self.strictPending = true
			self:Schedule(CONFIRM)
			return
		end
		self:Done(self:Save(group, live, saved))   -- an ordinary edit
		return
	end
	-- Recovery intent survives combat, cursor and late-data delays.
	self.strictPending = true
	if API.CursorBusy() then
		-- The player is dragging something: wait, and keep the memory untouched.
		self.strictUntil = now + STRICT_WINDOW
		self:Schedule(CONFIRM)
		return
	end

	local restored, failed, stopped = 0, 0, nil
	self.restoring = true
	for _, slot in ipairs(lost) do
		if self.blocked then stopped = "blocked"; break end
		local entry = saved.slots[slot]
		local ok, why = API.PlaceOnBar(slot, entry)
		if ok and API.GetActionSlot(slot) then
			restored = restored + 1
			entry.fails, entry.why = nil, nil
		elseif why == "combat" or why == "cursor" then
			stopped = why
			break
		else
			failed = failed + 1
			entry.fails, entry.why = (entry.fails or 0) + 1, ok and "empty" or why
		end
	end
	self.restoring = nil

	self:Log({ group = group, mode = self.mode, lost = #lost, restored = restored, failed = failed, stopped = stopped })
	if restored > 0 and s().announce then
		FP:Print(string.format("Put %d action button%s back on your bars%s.", restored, restored == 1 and "" or "s",
			failed > 0 and string.format(" (%d could not be restored)", failed) or "")
			.. FP.GREY .. " They went missing since they were last seen there. /hh bars|r")
	end
	if stopped == "blocked" then
		FP:Print(FP.RED .. "The client refused an action bar change.|r Bar guard is paused until the next login.")
		return
	end
	if stopped then
		-- Combat or a drag began mid-way: finish later, memory untouched.
		self.deferred = stopped == "combat" or nil
		self.strictUntil = API.Time() + STRICT_WINDOW
		if stopped == "cursor" then self:Schedule(CONFIRM) end
		return
	end
	local after = API.ReadActionBars()
	if after then self:Done(self:Save(group, after, saved)) else self:Schedule(5) end
end

function B:OnSlotChanged(slot)
	if self.restoring or not FP.dbReady or not s().enabled then return end
	slot = FP.safe(slot)
	local now = API.Time()
	if U.Finite(slot) and slot > 0 then self.changed[slot] = now else self.allChanged = now end
	self:Schedule(SETTLE)
end

function B:OnSpecChanged()
	if not FP.dbReady or not s().enabled then return end
	self.mode = "spec"
	self.rechecks = 0
	self.changed, self.allChanged = {}, nil
	self.notBefore = API.Time() + SPEC_DELAY
	self:Schedule(SPEC_DELAY)
end

function B:OnEnable()
	self.mode = "boot"
	self.changed = {}
	self.rechecks = 0
	local E = function(ev, fn) FP:RegisterEvent(ev, fn) end
	E("ACTIONBAR_SLOT_CHANGED", function(_, slot) B:OnSlotChanged(slot) end)
	E("ACTIVE_TALENT_GROUP_CHANGED", function() B:OnSpecChanged() end)
	E("PLAYER_LEVEL_UP", function()
		-- Reported wipe moment. Look even if the client sends no slot event.
		if not FP.dbReady or not s().enabled then return end
		B.strictUntil = API.Time() + STRICT_WINDOW
		B.strictPending = true
		B.rechecks = 0
		B:Schedule(SPEC_DELAY)
	end)
	E("PLAYER_REGEN_ENABLED", function()
		if B.deferred then B:Schedule(1) end
	end)
	for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
		E(event, function(_, addon)
			if B.restoring and FP.safe(addon) == ADDON then B.blocked = true end
		end)
	end
	self:Schedule(LOGIN_DELAY)
end

function B:Lines()
	local out = {}
	if not API.ActionBarsAvailable() then
		out[1] = "Action bar guard: unavailable on this client."
		return out
	end
	out[1] = "Action bar guard " .. (s().enabled and "on" or "off") .. (self.blocked and " (paused: the client refused a bar change)" or "")
		.. " · chat notice " .. (s().announce and "on" or "off")
	local bars = store()
	local groups = {}
	for group in pairs(type(bars.specs) == "table" and bars.specs or {}) do
		if U.Finite(group) then groups[#groups + 1] = group end
	end
	table.sort(groups)
	local active = API.ActiveSpecGroup()
	for _, group in ipairs(groups) do
		local saved = self:Stored(group)
		if saved then
			local n = 0
			for _ in pairs(saved.slots) do n = n + 1 end
			out[#out + 1] = string.format("  spec %d%s: %d button%s remembered", group, group == active and " (active)" or "", n, n == 1 and "" or "s")
		end
	end
	if #groups == 0 then out[#out + 1] = "  nothing remembered yet (the first look happens a few seconds after login, out of combat)" end
	local last
	for i = #(type(bars.log) == "table" and bars.log or {}), 1, -1 do
		if (bars.log[i].restored or 0) > 0 then last = bars.log[i]; break end
	end
	if last then
		out[#out + 1] = string.format("  last restore: %d of %d missing button%s put back on spec %s", last.restored or 0, last.lost or 0,
			(last.lost or 0) == 1 and "" or "s", tostring(last.group))
	end
	return out
end

function B:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	if sub == "on" then
		s().enabled = true
		self.mode, self.rechecks = "track", 0
		self.strictPending, self.strictUntil, self.deferred = nil, nil, nil
		self.changed, self.allChanged = {}, nil
		self:Schedule(SETTLE)
		FP:Print("action bar guard on")
	elseif sub == "off" then
		s().enabled = false
		FP:Print("action bar guard off; your bars are no longer watched or restored")
	elseif sub == "notice" or sub == "announce" then
		if val == "on" then s().announce = true elseif val == "off" then s().announce = false else s().announce = not s().announce end
		FP:Print("action bar guard chat notice " .. (s().announce and "on" or "off"))
	else
		for _, line in ipairs(self:Lines()) do FP:Print(line) end
		FP:Print("/hh bars on|off | notice on|off")
	end
end
