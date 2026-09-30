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

local function myName()
	return FP.safe(UnitName("player")) or "?"
end

local function inLockdown()
	return C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" and C_ChatInfo.InChatMessagingLockdown() or false
end

function C:Encode(entry)
	return table.concat({ "PT", tostring(entry.spellID or 0), entry.spell or "?", string.format("%.1f", entry.duration or 0), entry.target or "", entry.drText or "", entry.kind or "cc" }, ";")
end

function C:Decode(msg)
	local tag, spellID, spell, duration, target, drText, kind = msg:match("^(PT);([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);([^;]*)$")
	if tag ~= "PT" then return nil end
	return { spellID = tonumber(spellID), spell = spell, duration = tonumber(duration) or 0, target = target ~= "" and target or nil, drText = drText ~= "" and drText or nil, kind = kind }
end

function C:Broadcast(entry)
	if not FP.settings.pvp.share then return false end
	if not (IsInGroup and IsInGroup()) then return false end
	if inLockdown() then self.lockedSends = (self.lockedSends or 0) + 1; return false end
	if entry.owner ~= "me" or entry.kind == "buff" then return false end
	local ok = API.SendPartyMessage(self:Encode(entry))
	if ok then self.sent = self.sent + 1 end
	return ok
end

function C:OnMessage(prefix, msg, channel, sender)
	if prefix ~= API.PREFIX then return end
	msg, sender = FP.safe(msg), FP.safe(sender)
	if type(msg) ~= "string" or msg:sub(1, 3) ~= "PT;" then return end
	local me = myName()
	if type(sender) == "string" and (sender == me or sender:match("^" .. me:gsub("%p", "%%%0") .. "%-")) then return end
	local d = self:Decode(msg)
	if not d then return end
	self.received = self.received + 1
	local short = type(sender) == "string" and (sender:match("^([^%-]+)") or sender) or "partner"
	local icon = (d.spellID and C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(d.spellID) or nil
	FP.CastTimers:Start({ spell = d.spell, spellID = d.spellID, icon = icon, target = d.target, owner = short, duration = d.duration, kind = d.kind, drText = d.drText })
	FP.Roster:Note(d.target, short .. ": " .. d.spell, d.drText)
end

function C:Summary()
	return string.format("share %s · sent %d · received %d · blocked by lockdown %d%s", FP.settings.pvp.share and "on" or "off", self.sent, self.received, self.lockedSends or 0, inLockdown() and " · LOCKDOWN NOW" or "")
end

function C:OnEnable()
	FP:On("PVP_TIMER_STARTED", function(entry) if entry.owner == "me" then C:Broadcast(entry) end end)
	FP:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender) C:OnMessage(prefix, msg, channel, sender) end)
end
