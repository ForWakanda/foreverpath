-- ForeverPath / PvP / PvPCore.lua
-- PvP HUD container + mode detection. Sub-modules (CastTimers, Battleground,
-- Roster, Coordination) register sections that return display rows; this file
-- only draws them. Everything shown here comes from your own actions, from
-- Blizzard's non-secret battleground data, or from what a party member chose
-- to broadcast about their own casts. Nothing reads enemy casts or auras.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local PvP = FP:NewModule("PvP")

local WIDTH, ROW_H, MAX_ROWS = 280, 18, 26
local sections = {}      -- { name, order, fn }
local ticker

local function has(tbl, fn) return type(tbl) == "table" and type(tbl[fn]) == "function" end

function PvP:RegisterSection(name, order, fn)
	sections[#sections + 1] = { name = name, order = order, fn = fn }
	table.sort(sections, function(a, b) return a.order < b.order end)
end

function PvP:InBattleground()
	return has(C_PvP, "IsBattleground") and C_PvP.IsBattleground() or false
end

function PvP:MatchState()
	return has(C_PvP, "GetActiveMatchState") and C_PvP.GetActiveMatchState() or nil
end

-- Hostile player check with every value secret-guarded.
function PvP:IsHostilePlayer(unit)
	if not FP.safe(UnitExists(unit)) then return false end
	if not FP.safe(UnitIsPlayer(unit)) then return false end
	if type(UnitCanAttack) == "function" then
		local can = FP.safe(UnitCanAttack("player", unit))
		if can == nil then return false end
		return can and true or false
	end
	return false
end

-------------------------------------------------------------------------------
-- HUD
-------------------------------------------------------------------------------
local function savePosition(frame)
	local s = FP.settings.pvp
	local point, _, _, x, y = frame:GetPoint(1)
	if point then s.point, s.x, s.y = point, x, y end
end

function PvP:OnInit()
	local f = CreateFrame("Frame", "ForeverPathPvPHUD", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(WIDTH, 60)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame) if not FP.settings.pvp.locked then frame:StartMoving() end end)
	f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing(); savePosition(frame) end)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.8)
		f:SetBackdropBorderColor(1, 0.35, 0.35, 0.8)
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.title = title
	title:SetPoint("TOPLEFT", 8, -6)
	title:SetText(FP.COLOR .. "ForeverPath|r " .. FP.RED .. "PvP|r")
	self.rows = {}
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, f)
		row:SetSize(WIDTH - 16, ROW_H)
		row:SetPoint("TOPLEFT", 8, -22 - (i - 1) * ROW_H)
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(1, 1, 1, 0.05)
		local bar = row:CreateTexture(nil, "BORDER")
		bar:SetPoint("TOPLEFT")
		bar:SetPoint("BOTTOMLEFT")
		bar:SetWidth(1)
		bar:SetColorTexture(0.3, 0.6, 1, 0.35)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetPoint("LEFT", 2, 0)
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		text:SetPoint("RIGHT", -4, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		row.bg, row.bar, row.icon, row.text = bg, bar, icon, text
		row:Hide()
		self.rows[i] = row
	end
	self:ApplySettings()
	f:Hide()
end

function PvP:ApplySettings()
	local s = FP.settings.pvp
	local f = self.frame
	f:ClearAllPoints()
	f:SetPoint(s.point or "LEFT", UIParent, s.point or "LEFT", s.x or 30, s.y or 120)
	f:SetScale(s.scale or 1)
end

function PvP:ResetPosition()
	local s = FP.settings.pvp
	s.point, s.x, s.y, s.scale = "LEFT", 30, 120, 1
	self:ApplySettings()
end

-- Collect rows from every section. Row = { text, icon, frac (0..1), color = {r,g,b}, header = bool }
function PvP:Collect()
	local rows = {}
	for _, sec in ipairs(sections) do
		local ok, lines = pcall(sec.fn)
		if ok and type(lines) == "table" and #lines > 0 then
			rows[#rows + 1] = { text = FP.GOLD .. sec.name .. "|r", header = true }
			for _, l in ipairs(lines) do rows[#rows + 1] = l end
		elseif not ok then
			FP:ReportError("pvp-section:" .. sec.name, lines)
		end
	end
	return rows
end

function PvP:Refresh()
	local s = FP.settings.pvp
	if not s.enabled or s.manual == "hide" then self:Hide(); return end
	local rows = self:Collect()
	if #rows == 0 and s.manual ~= "show" then self:Hide(); return end
	local f = self.frame
	local n = 0
	for i, row in ipairs(self.rows) do
		local r = rows[i]
		if r then
			n = n + 1
			row.text:SetText(r.text or "")
			if r.icon then row.icon:SetTexture(r.icon); row.icon:Show() else row.icon:Hide() end
			if r.frac and r.frac > 0 then
				local c = r.color or { 0.3, 0.6, 1 }
				row.bar:SetColorTexture(c[1], c[2], c[3], 0.35)
				row.bar:SetWidth(math.max(1, (WIDTH - 16) * math.min(1, r.frac)))
				row.bar:Show()
			else
				row.bar:Hide()
			end
			row.bg:SetAlpha(r.header and 0 or 1)
			row:Show()
		else
			row:Hide()
		end
	end
	if n == 0 then
		self.rows[1].text:SetText(FP.GREY .. "nothing to show yet|r")
		self.rows[1].icon:Hide(); self.rows[1].bar:Hide(); self.rows[1]:Show()
		n = 1
	end
	f:SetHeight(26 + n * ROW_H + 6)
	if not f:IsShown() then f:Show() end
	self:EnsureTicker()
end

function PvP:Hide()
	self.frame:Hide()
	if ticker then ticker:Cancel(); ticker = nil end
end

function PvP:EnsureTicker()
	if ticker or not (C_Timer and C_Timer.NewTicker) then return end
	ticker = C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(PvP.Refresh, PvP)
		if not ok then FP:ReportError("pvp-tick", err) end
	end)
end

function PvP:OnEnable()
	FP:On("PVP_CHANGED", function() FP.Throttle("pvp-refresh", 0.2, function() PvP:Refresh() end) end)
	FP:RegisterEvent("PLAYER_ENTERING_WORLD", function() FP.After(3, function() FP:Fire("PVP_CHANGED") end) end)
	FP:RegisterEvent("PVP_MATCH_STATE_CHANGED", function() FP.After(1, function() FP:Fire("PVP_CHANGED") end) end)
	FP:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", function() FP.After(1, function() FP:Fire("PVP_CHANGED") end) end)
end

-------------------------------------------------------------------------------
-- /fp pvp ...
-------------------------------------------------------------------------------
function PvP:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub = args[1] and args[1]:lower() or ""
	local s = FP.settings.pvp
	local p = function(...) FP:Print(...) end
	if sub == "" or sub == "toggle" then
		s.manual = (self.frame:IsShown() and "hide" or "show")
		self:Refresh()
		p("pvp hud " .. (self.frame:IsShown() and "shown" or "hidden") .. " (manual; /fp pvp auto to let it decide)")
	elseif sub == "show" then s.manual = "show"; self:Refresh(); p("pvp hud shown")
	elseif sub == "hide" then s.manual = "hide"; self:Refresh(); p("pvp hud hidden")
	elseif sub == "auto" then s.manual = nil; self:Refresh(); p("pvp hud automatic")
	elseif sub == "on" then s.enabled = true; self:Refresh(); p("pvp module on")
	elseif sub == "off" then s.enabled = false; self:Refresh(); p("pvp module off")
	elseif sub == "lock" then s.locked = true; p("pvp hud locked")
	elseif sub == "unlock" then s.locked = false; p("pvp hud unlocked")
	elseif sub == "reset" then self:ResetPosition(); p("pvp hud position reset")
	elseif sub == "scale" then s.scale = math.max(0.5, math.min(2, tonumber(args[2] or "") or 1)); self:ApplySettings(); p("pvp hud scale " .. s.scale)
	elseif sub == "track" then
		s.trackFlag = not s.trackFlag
		p("enemy flag carrier tracking " .. (s.trackFlag and "on (waypoint follows the flag while in a battleground)" or "off"))
		FP:Fire("PVP_CHANGED")
	elseif sub == "status" then
		p(string.format("pvp: module %s · hud %s · in battleground %s · match state %s · chat lockdown %s",
			s.enabled and "on" or "off", s.manual or "auto", tostring(self:InBattleground()), tostring(self:MatchState()),
			tostring(has(C_ChatInfo, "InChatMessagingLockdown") and C_ChatInfo.InChatMessagingLockdown())))
		p("timers: " .. FP.CastTimers:Summary())
		p("roster: " .. FP.Roster:Summary())
		p("battleground: " .. FP.Battleground:Summary())
		p("coordination: " .. FP.Coordination:Summary())
	elseif sub == "clear" then FP.CastTimers:Clear(); FP.Roster:ClearSession(); self:Refresh(); p("pvp timers + session roster cleared")
	elseif sub == "spells" then
		for name, def in pairs(FP.CastTimers.SPELLS) do p(string.format("  %s: %s %ss%s", name, def.kind, tostring(def.base), def.dr and (" dr=" .. def.dr) or "")) end
	else
		p("pvp: toggle | show | hide | auto | on | off | lock | unlock | reset | scale <n> | track | status | clear | spells")
	end
end
