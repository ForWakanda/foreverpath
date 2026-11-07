-- ForeverPath / Modules / InfoBar.lua
-- One thin status line (v0.8.0), the part of ForeverPlus/Titan-style info bars
-- that matters while leveling: level and xp, xp per hour and time to level,
-- gold, free bag slots, durability, hearth, ammo (ammo users), fps and latency.
-- Out of combat it also carries reminders: low durability, low ammo, bags
-- nearly full, a missing self-buff, a missing weapon imbue. Reminders read
-- your own buffs only while Blizzard's predicate says auras are not secret;
-- in combat the reminder segment hides instead of guessing. Nothing is cast.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local Bar = FP:NewModule("InfoBar")

local TICK = 2                      -- seconds between repaints
local RATE_WINDOW = 3600            -- xp/h over the last hour
local REMIND_REPEAT = 600           -- a chat reminder per key at most every 10 min

-- Vanilla spell ids by rank; a reminder fires only when a rank is KNOWN and
-- no rank is ACTIVE. Ids are the Classic ones; Forever may differ: unverified.
local BUFFS = {
	SHAMAN = { { key = "ls", label = "Lightning Shield", ids = { 324, 325, 905, 945, 8134, 10431, 10432 } } },
	MAGE = {
		{ key = "ai", label = "Arcane Intellect", ids = { 1459, 1460, 1461, 10156, 10157 } },
		{ key = "armor", label = "Frost/Ice Armor", ids = { 168, 7300, 7301, 7302, 7320, 10219, 10220 } },
	},
	HUNTER = { { key = "aspect", label = "an Aspect", ids = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 13163, 5118, 13159, 13161, 20043, 20190 } } },
}
local IMBUES = { SHAMAN = { 8017, 8018, 8019, 10399, 8024, 8027, 8030, 16339, 16341, 16342, 8033, 8038, 10456, 16355, 16356, 8232, 8235, 10486, 16362 } }

local function s() return FP.settings.bar end
local function r() return FP.settings.reminders end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
local function savePosition(frame)
	local point, _, _, x, y = frame:GetPoint(1)
	if point then s().point, s().x, s().y = point, x, y end
end

function Bar:OnInit()
	local f = CreateFrame("Frame", "ForeverPathInfoBar", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(760, 18)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame) if not s().locked then frame:StartMoving() end end)
	f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing(); savePosition(frame) end)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
		f:SetBackdropColor(0.03, 0.03, 0.05, 0.6)
	end
	local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.text = text
	text:SetPoint("CENTER", 0, 0)
	text:SetJustifyH("CENTER")
	local remind = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.remind = remind
	remind:SetPoint("TOP", f, "BOTTOM", 0, -1)
	remind:SetJustifyH("CENTER")
	f:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("ForeverPath status", 1, 0.82, 0)
		for _, line in ipairs(Bar:TooltipLines()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
		GameTooltip:AddLine("Drag to move (/fp bar lock). /fp bar hide removes it.", 0.5, 0.8, 1, true)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self:ApplySettings()
	f:Hide()
end

function Bar:ApplySettings()
	local f = self.frame
	f:ClearAllPoints()
	f:SetPoint(s().point or "TOP", UIParent, s().point or "TOP", s().x or 0, s().y or -4)
	f:SetScale(s().scale or 1)
end

function Bar:ResetPosition()
	s().point, s().x, s().y, s().scale = "TOP", 0, -4, 1
	self:ApplySettings()
end

-------------------------------------------------------------------------------
-- XP rate: cumulative session xp gained, timestamped; seeded from the
-- recorder's per-minute samples so a /reload does not reset the hour.
-------------------------------------------------------------------------------
function Bar:SeedRate()
	self.gained, self.samples = 0, {}
	local xp, max, level = API.GetXP()
	if not U.Finite(xp) then return end
	self.lastXP, self.lastMax, self.lastLevel = xp, max, level
	local key = API.GetCharInfo().key
	local hist = FP.data and FP.data.xp and FP.data.xp[key]
	local now = U.Now()
	if type(hist) == "table" then
		local prev
		for _, smp in ipairs(hist) do
			if U.Finite(smp.t) and U.Finite(smp.xp) and smp.t >= now - RATE_WINDOW then
				if prev then
					local d
					if smp.l == prev.l then d = smp.xp - prev.xp
					elseif U.Finite(prev.max) then d = (prev.max - prev.xp) + smp.xp end
					if U.Finite(d) and d > 0 then
						self.gained = self.gained + d
						self.samples[#self.samples + 1] = { t = smp.t, total = self.gained }
					end
				elseif #self.samples == 0 then
					self.samples[1] = { t = smp.t, total = 0 }
				end
				prev = smp
			end
		end
		-- bridge the last recorded sample to the live value
		if prev and prev.l == level and U.Finite(prev.xp) and xp > prev.xp then
			self.gained = self.gained + (xp - prev.xp)
			self.samples[#self.samples + 1] = { t = now, total = self.gained }
		end
	end
	if #self.samples == 0 then self.samples[1] = { t = now, total = 0 } end
end

function Bar:OnXP()
	local xp, max, level = API.GetXP()
	if not U.Finite(xp) or not self.samples then return end
	local d
	if level == self.lastLevel then d = xp - (self.lastXP or xp)
	elseif U.Finite(self.lastMax) and U.Finite(self.lastXP) then d = (self.lastMax - self.lastXP) + xp end
	self.lastXP, self.lastMax, self.lastLevel = xp, max, level
	if U.Finite(d) and d > 0 then
		self.gained = self.gained + d
		self.samples[#self.samples + 1] = { t = U.Now(), total = self.gained }
		while #self.samples > 400 do table.remove(self.samples, 1) end
	end
end

-- xp per hour over the window; nil until there is at least 2 min and some xp.
function Bar:Rate()
	if not self.samples or #self.samples == 0 then return nil end
	local now = U.Now()
	local first = self.samples[1]
	for _, smp in ipairs(self.samples) do
		if smp.t >= now - RATE_WINDOW then first = smp; break end
	end
	local elapsed = now - first.t
	local gained = self.gained - first.total
	if elapsed < 120 or gained <= 0 then return nil end
	return gained / elapsed * 3600, gained, elapsed
end

-------------------------------------------------------------------------------
-- Reminders (out of combat)
-------------------------------------------------------------------------------
local function knowsAny(ids)
	local unknown = false
	for _, id in ipairs(ids) do
		local known = API.KnowsSpell(id)
		if known == true then return true end
		if known == nil then unknown = true end
	end
	if unknown then return nil end
	return false
end

function Bar:Reminders(st)
	local out = {}
	if not r().enabled then return out end
	local dura = st.dura
	if dura and r().durability > 0 then
		if dura.broken > 0 then out[#out + 1] = { key = "broken", text = dura.broken .. " item" .. (dura.broken == 1 and "" or "s") .. " broken — repair" }
		elseif dura.worst * 100 <= r().durability then out[#out + 1] = { key = "dura", text = "Repair soon: " .. math.floor(dura.worst * 100 + 0.5) .. "%" } end
	end
	if st.ammo and st.ammo.count and r().ammo > 0 and st.ammo.count <= r().ammo then
		out[#out + 1] = { key = "ammo", text = "Ammo low: " .. st.ammo.count }
	end
	if st.bags and st.bags <= 2 then out[#out + 1] = { key = "bags", text = "Bags nearly full: " .. st.bags .. " free" } end
	if r().buffs and not API.InCombat() then
		local class = API.GetCharInfo().class
		for _, b in ipairs(BUFFS[class] or {}) do
			if knowsAny(b.ids) == true and API.HasPlayerAura(b.ids) == false then
				out[#out + 1] = { key = "buff:" .. b.key, text = "Buff: " .. b.label }
			end
		end
		if IMBUES[class] and knowsAny(IMBUES[class]) == true then
			local imb = API.GetWeaponImbues()
			if imb and imb.has_main and not imb.main then out[#out + 1] = { key = "imbue", text = "Imbue weapon" } end
		end
	end
	return out
end

function Bar:Announce(reminders)
	local now = U.Now()
	self.announced = self.announced or {}
	for _, rem in ipairs(reminders) do
		local last = self.announced[rem.key]
		if not last or now - last >= REMIND_REPEAT then
			self.announced[rem.key] = now
			FP:Print(FP.GOLD .. rem.text .. "|r")
		end
	end
end

-------------------------------------------------------------------------------
-- Paint
-------------------------------------------------------------------------------
function Bar:Snapshot()
	local st = self.state or {}
	self.state = st
	st.xp, st.max, st.level, st.rested = API.GetXP()
	st.money = API.GetMoney() or st.money
	st.hearth = API.GetHearthCooldown()
	st.bind = (FP.cdb.bind and FP.cdb.bind.area) or API.GetBindLocation()
	st.perf = API.GetPerformance()
	st.combat = API.InCombat()
	if not st.combat then
		st.bags = API.GetFreeBagSlots() or st.bags
		st.dura = API.GetDurability() or st.dura
		st.ammo = API.GetAmmo()
	end
	return st
end

local function seg(text, warn) return (warn and FP.GOLD or "") .. text .. (warn and "|r" or "") end

function Bar:Compose(st)
	local parts = {}
	local pct = (U.Finite(st.xp) and U.Finite(st.max) and st.max > 0) and math.floor(st.xp / st.max * 100 + 0.5) or nil
	parts[#parts + 1] = "Lvl " .. tostring(st.level or "?") .. (pct and (" · " .. pct .. "%") or "") .. ((U.Finite(st.rested) and st.rested > 0 and U.Finite(st.max) and st.max > 0) and (FP.GREY .. " (+" .. math.floor(st.rested / st.max * 100 + 0.5) .. "% rested)|r") or "")
	local rate = self:Rate()
	if rate then
		local line = string.format("%s xp/h", U.Round(rate, 0))
		if U.Finite(st.xp) and U.Finite(st.max) and st.max > st.xp then line = line .. " · " .. U.FormatTime((st.max - st.xp) / rate * 3600) .. " to level" end
		parts[#parts + 1] = line
	else
		parts[#parts + 1] = FP.GREY .. "xp/h —|r"
	end
	if st.money then parts[#parts + 1] = U.MoneyString(st.money) end
	if st.bags then parts[#parts + 1] = seg("bags " .. st.bags .. " free", st.bags <= 2) end
	if st.dura then parts[#parts + 1] = seg("dura " .. math.floor(st.dura.worst * 100 + 0.5) .. "%", st.dura.broken > 0 or st.dura.worst * 100 <= (r().durability or 20)) end
	if st.bind then parts[#parts + 1] = "hearth " .. (st.hearth > 0 and U.FormatTime(st.hearth) or "ready") end
	if st.ammo then parts[#parts + 1] = seg("ammo " .. tostring(st.ammo.count or "?"), st.ammo.count and st.ammo.count <= (r().ammo or 0)) end
	if s().fps and st.perf and (st.perf.fps or st.perf.world) then
		parts[#parts + 1] = FP.GREY .. (st.perf.fps and (math.floor(st.perf.fps + 0.5) .. " fps") or "") .. (st.perf.world and ((st.perf.fps and " " or "") .. math.floor(st.perf.world + 0.5) .. " ms") or "") .. "|r"
	end
	return table.concat(parts, FP.GREY .. "  ·  |r")
end

function Bar:TooltipLines()
	local st = self.state or self:Snapshot()
	local out = {}
	local rate, gained, elapsed = self:Rate()
	if rate then out[#out + 1] = string.format("%d xp in %s this session window → %d xp/h", gained, U.FormatTime(elapsed), U.Round(rate, 0))
	else out[#out + 1] = "XP rate appears after 2 minutes with some xp gained." end
	if st.dura then out[#out + 1] = string.format("Durability: worst slot %d%%, overall %d%%, %d broken.", math.floor(st.dura.worst * 100 + 0.5), math.floor(st.dura.pct * 100 + 0.5), st.dura.broken) end
	if st.ammo then out[#out + 1] = "Ammo: " .. tostring(st.ammo.count or "?") .. (st.ammo.name and (" " .. st.ammo.name) or "") end
	if st.perf and st.perf.home then out[#out + 1] = "Latency home " .. st.perf.home .. " ms, world " .. tostring(st.perf.world or "?") .. " ms" end
	return out
end

function Bar:Paint()
	if not self.frame:IsShown() then return end
	local st = self:Snapshot()
	self.text:SetText(self:Compose(st))
	local reminders = self:Reminders(st)
	self.reminders = reminders
	if #reminders > 0 and not st.combat then
		local texts = {}
		for _, rem in ipairs(reminders) do texts[#texts + 1] = rem.text end
		self.remind:SetText(FP.GOLD .. table.concat(texts, "  ·  ") .. "|r")
		self.remind:Show()
		self:Announce(reminders)
	else
		self.remind:SetText("")
		self.remind:Hide()
	end
	local w = self.text.GetStringWidth and self.text:GetStringWidth() or 700
	if U.Finite(w) and not FP.issecret(w) and w > 0 then self.frame:SetWidth(math.max(200, w + 24)) end
end

function Bar:Tick()
	FP.pcall("infobar", function() Bar:Paint() end)
	FP.After(TICK, function() Bar:Tick() end)
end

function Bar:OnEnable()
	self:SeedRate()
	FP:RegisterEvent("PLAYER_XP_UPDATE", function() Bar:OnXP() end)
	FP:RegisterEvent("PLAYER_LEVEL_UP", function() FP.After(0.5, function() Bar:OnXP() end) end)
	FP:RegisterEvent("PLAYER_REGEN_ENABLED", function() FP.After(0.5, function() Bar:Paint() end) end)
	if s().shown then self:Toggle(true) end
	self:Tick()
end

function Bar:Toggle(show)
	if show == nil then show = not self.frame:IsShown() end
	s().shown = show
	if show then self.frame:Show(); self:Paint() else self.frame:Hide() end
end

-------------------------------------------------------------------------------
-- /fp bar, /fp remind
-------------------------------------------------------------------------------
function Bar:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	if sub == "show" or sub == "on" then self:Toggle(true)
	elseif sub == "hide" or sub == "off" then self:Toggle(false)
	elseif sub == "lock" then s().locked = true; FP:Print("info bar locked")
	elseif sub == "unlock" then s().locked = false; FP:Print("info bar unlocked")
	elseif sub == "reset" then self:ResetPosition(); self:Toggle(true)
	elseif sub == "scale" then
		local n = tonumber(val)
		if n and n >= 0.5 and n <= 2 then s().scale = n; self:ApplySettings() else FP:Print("scale 0.5–2") end
	elseif sub == "fps" then s().fps = (val == "on") or (val ~= "off" and not s().fps); self:Paint(); FP:Print("fps/latency " .. (s().fps and "on" or "off"))
	elseif sub == "" then self:Toggle()
	else FP:Print("/fp bar show|hide|lock|unlock|reset|scale <n>|fps on|off") end
end

function Bar:RemindCommand(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	if sub == "on" then r().enabled = true
	elseif sub == "off" then r().enabled = false
	elseif sub == "buffs" then r().buffs = (val == "on") or (val ~= "off" and not r().buffs)
	elseif sub == "durability" or sub == "dura" then
		local n = tonumber(val)
		if n and n >= 0 and n <= 90 then r().durability = n else FP:Print("durability threshold 0–90 (0 = off)"); return end
	elseif sub == "ammo" then
		local n = tonumber(val)
		if n and n >= 0 and n <= 5000 then r().ammo = n else FP:Print("ammo threshold 0–5000 (0 = off)"); return end
	elseif sub ~= "" then FP:Print("/fp remind on|off | buffs on|off | durability <pct> | ammo <count>"); return end
	self:Paint()
	FP:Print(string.format("reminders %s · buffs %s · durability ≤ %d%% · ammo ≤ %d", r().enabled and "on" or "off", r().buffs and "on" or "off", r().durability, r().ammo))
end
