-- ForeverPath / Modules / HunterAudioFeedback.lua
-- Hunter combat audio feedback: an occasional audio cue when selected Hunter
-- abilities succeed (Multi-Shot, Mend Pet). Cosmetic only: it listens to the
-- player's own spell-cast events and plays a bundled sound through the SFX
-- channel. It never casts, targets, or generates input. Hunters only; other
-- classes never register the events.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local H = FP:NewModule("HunterAudio")

local SOUND_DIR = "Interface\\AddOns\\ForeverPath\\Sounds\\Hunter\\"

-- short cues pair with the attack; longer cues with the channel
H.POOLS = {
	short = { "hunter_feedback_01.ogg", "hunter_feedback_02.ogg", "hunter_feedback_03.ogg", "hunter_feedback_04.ogg", "hunter_feedback_05.ogg" },
	long  = { "hunter_feedback_06.ogg", "hunter_feedback_07.ogg", "hunter_feedback_08.ogg", "hunter_feedback_09.ogg", "hunter_feedback_10.ogg" },
}

-- matched by spell name so every rank of the ability qualifies
H.TRIGGERS = {
	["Multi-Shot"] = { chance = 0.20, pool = "short" },
	["Mend Pet"]   = { chance = 0.30, pool = "long" },
}

H.active = false
H.plays = 0
H.lastPlayed = -1e9
H.seen = 0

local function settings()
	return FP.settings.hunterAudio
end

function H:IsHunter()
	local _, classFile = UnitClass("player")
	return FP.safe(classFile) == "HUNTER"
end

function H:OnEnable()
	if self:IsHunter() then self:Activate() end
end

-- Registers the player-only spell-cast events. Idempotent.
function H:Activate()
	if self.frame then return true end
	local f = CreateFrame("Frame", "ForeverPathHunterAudio")
	self.frame = f
	local function register(event)
		local ok = pcall(f.RegisterUnitEvent, f, event, "player")
		if not ok then ok = pcall(f.RegisterEvent, f, event) end
		return ok
	end
	self.registered = {}
	for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" }) do
		self.registered[ev] = register(ev) and true or false
	end
	f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
		local ok, err = pcall(H.OnCast, H, event, unit, castGUID, spellID)
		if not ok then FP:ReportError("hunter-audio", err) end
	end)
	self.active = true
	return true
end

function H:OnCast(event, unit, castGUID, spellID)
	if unit ~= "player" then return end
	spellID = FP.safe(spellID)
	if type(spellID) ~= "number" then
		FP:Debug("HunterAudio: spellID unavailable for", event)
		return
	end
	local name = API.GetSpellName(spellID)
	local trigger = name and self.TRIGGERS[name]
	if not trigger then return end
	-- a channel reports CHANNEL_START and SUCCEEDED for the same cast
	castGUID = FP.safe(castGUID)
	if castGUID and castGUID == self.lastCastGUID then return end
	self.lastCastGUID = castGUID
	self.seen = self.seen + 1
	self.lastSeen = { name = name, spellID = spellID, event = event, t = GetTime() }
	FP:Debug("HunterAudio:", event, name, spellID)
	local s = settings()
	if not s or not s.enabled then return end
	local now = GetTime()
	if (now - self.lastPlayed) < (s.cooldown or 30) then
		FP:Debug("HunterAudio: on cooldown")
		return
	end
	if math.random() > trigger.chance then
		FP:Debug("HunterAudio: roll failed")
		return
	end
	self:Play(trigger.pool)
end

function H:Play(pool)
	local list = self.POOLS[pool] or self.POOLS.short
	local file = list[math.random(#list)]
	local path = SOUND_DIR .. file
	local willPlay, handle
	if type(PlaySoundFile) == "function" then
		local ok, a, b = pcall(PlaySoundFile, path, "SFX")
		if ok then willPlay, handle = a, b else FP:Debug("HunterAudio: PlaySoundFile error", a) end
	end
	self.lastPlayed = GetTime()
	self.plays = self.plays + 1
	self.lastFile = file
	self.lastWillPlay = willPlay and true or false
	FP:Debug("HunterAudio: play", file, "willPlay", tostring(willPlay))
	return file, willPlay
end

function H:Status()
	local s = settings() or {}
	local files = #self.POOLS.short + #self.POOLS.long
	return string.format("Hunter combat audio feedback: %s · %s · %d cue files · cooldown %ds · seen %d · played %d%s",
		s.enabled and "enabled" or "disabled", self.active and "active (Hunter)" or "inactive (Hunters only)",
		files, s.cooldown or 30, self.seen, self.plays,
		self.lastFile and (" · last " .. self.lastFile .. (self.lastWillPlay and "" or " (did not play)")) or "")
end
