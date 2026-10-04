-- ForeverPath / PvP / Coordination.lua
-- Party coordination: each ForeverPath user broadcasts their OWN control casts
-- (spell, target, estimated duration) over addon messages; partners see them
-- as timers in the HUD with a "window" flag as the effect ends. Addon
-- messaging is locked by Blizzard inside battlegrounds and arenas; this works
-- in open-world PvP and duels. Nothing here reads enemy data.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local C = FP:NewModule("Coordination")

C.sent, C.received = 0, 0

function C:Encode(entry)
	return table.concat({ "PT", tostring(entry.spellID or 0), entry.spell or "?", string.format("%.1f", entry.duration or 0), entry.target or "", entry.drText or "", entry.kind or "cc" }, ";")
end

function C:Decode(msg)
	local tag, spellID, spell, duration, target, drText, kind = msg:match("^(PT);([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);([^;]*)$")
	if tag ~= "PT" then return nil end
	local seconds, id = tonumber(duration), tonumber(spellID)
	local kinds = { cc = true, root = true, lockout = true, trap = true }
	if not U.Finite(seconds) or seconds <= 0 or seconds > 120 or not U.Finite(id) or id < 1 or id > 2147483647 or id ~= math.floor(id)
		or #spell == 0 or #spell > 80 or #target > 80 or #drText > 32 or not kinds[kind] then return nil end
	return { spellID = tonumber(spellID), spell = spell, duration = tonumber(duration) or 0, target = target ~= "" and target or nil, drText = drText ~= "" and drText or nil, kind = kind }
end

function C:Broadcast(entry)
	if not FP.settings.pvp.enabled or not FP.settings.pvp.share then return false end
	if not API.InGroup() then return false end
	if API.IsChatLocked() then self.lockedSends = (self.lockedSends or 0) + 1; return false end
	if entry.owner ~= "me" or entry.kind == "buff" then return false end
	local ok = API.SendPartyMessage(self:Encode(entry))
	if ok then self.sent = self.sent + 1 end
	return ok
end

function C:OnMessage(prefix, msg, channel, sender)
	prefix, msg, channel, sender = FP.safe(prefix), FP.safe(msg), FP.safe(channel), FP.safe(sender)
	if prefix ~= API.PREFIX or channel ~= "PARTY" or type(msg) ~= "string" or #msg > 255 or not API.IsPartySender(sender) then return end
	if not FP.settings.pvp.enabled or API.IsChatLocked() then return end
	local d = self:Decode(msg)
	if not d then return end
	self.received = self.received + 1
	local short = type(sender) == "string" and (sender:match("^([^%-]+)") or sender) or "partner"
	local icon = API.GetSpellTexture(d.spellID)
	FP.CastTimers:Start({ spell = d.spell, spellID = d.spellID, icon = icon, target = d.target, owner = short, duration = d.duration, kind = d.kind, drText = d.drText })
	FP.Roster:Note(d.target, short .. ": " .. d.spell, d.drText)
end

function C:Summary()
	return string.format("share %s · sent %d · received %d · blocked by lockdown %d%s", FP.settings.pvp.share and "on" or "off", self.sent, self.received, self.lockedSends or 0, API.IsChatLocked() and " · LOCKDOWN NOW" or "")
end

function C:OnEnable()
	FP:On("PVP_TIMER_STARTED", function(entry) if entry.owner == "me" then C:Broadcast(entry) end end)
	FP:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender) C:OnMessage(prefix, msg, channel, sender) end)
end
