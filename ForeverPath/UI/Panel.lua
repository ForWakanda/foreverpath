-- ForeverPath / UI / Panel.lua
-- "Next steps" window: the planner's ordered list, click a row to send the arrow there.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Panel = FP:NewModule("Panel")

local ROW_HEIGHT = 16
local WIDTH = 360

local function savePosition(frame)
	local s = FP.settings.panel
	local point, _, _, x, y = frame:GetPoint(1)
	if point then s.point, s.x, s.y = point, x, y end
end

function Panel:OnInit()
	local f = CreateFrame("Frame", "ForeverPathPanel", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(WIDTH, 120)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame) if not FP.settings.panel.locked then frame:StartMoving() end end)
	f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing(); savePosition(frame) end)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
		f:SetBackdropBorderColor(0.37, 0.84, 1, 0.8)
	end

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.title = title
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(FP.COLOR .. "ForeverPath|r " .. FP.GREY .. "next steps|r")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() Panel:Toggle(false) end)

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.status = status
	status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
	status:SetWidth(WIDTH - 20)
	status:SetJustifyH("LEFT")

	self.rows = {}
	for i = 1, FP.settings.panel.maxSteps or 10 do
		local row = CreateFrame("Button", nil, f)
		row:SetSize(WIDTH - 20, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 10, -40 - (i - 1) * ROW_HEIGHT)
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		local dist = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		dist:SetPoint("LEFT", 0, 0)
		dist:SetWidth(52)
		dist:SetJustifyH("RIGHT")
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", dist, "RIGHT", 6, 0)
		label:SetWidth(WIDTH - 20 - 62)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		row.dist, row.label = dist, label
		row:SetScript("OnClick", function(btn)
			if btn.step then
				if btn.step.kind == "hearth" then
					FP:Print("Use your Hearthstone: " .. tostring(btn.step.title))
					return
				end
				if FP.Planner:Go(btn.step) then FP:Print(FP.GOLD .. "Go:|r " .. btn.step.title) end
			end
		end)
		row:SetScript("OnEnter", function(btn)
			if not btn.step then return end
			GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
			GameTooltip:AddLine(tostring(btn.step.title), 1, 0.82, 0)
			if btn.step.text and btn.step.kind ~= "turnin" then GameTooltip:AddLine(tostring(btn.step.text), 1, 1, 1, true) end
			if btn.step.mapID then GameTooltip:AddLine(API.GetMapName(btn.step.mapID) .. "  " .. U.FormatCoords(btn.step.x, btn.step.y) .. "  " .. FP.GREY .. "(" .. tostring(btn.step.how) .. ")|r", 0.7, 0.7, 0.7)
			else GameTooltip:AddLine("Location unknown yet: talk to the quest giver again or make progress and ForeverPath will learn it.", 0.9, 0.5, 0.5, true) end
			GameTooltip:AddLine("Click to send the arrow here.", 0.5, 0.8, 1)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.rows[i] = row
	end

	local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.footer = footer
	footer:SetPoint("BOTTOMLEFT", 10, 8)
	footer:SetWidth(WIDTH - 20)
	footer:SetJustifyH("LEFT")

	self:ApplySettings()
	f:Hide()
end

function Panel:ApplySettings()
	local s = FP.settings.panel
	local f = self.frame
	f:ClearAllPoints()
	f:SetPoint(s.point or "TOPRIGHT", UIParent, s.point or "TOPRIGHT", s.x or -20, s.y or -160)
	f:SetScale(s.scale or 1)
end

function Panel:ResetPosition()
	local s = FP.settings.panel
	s.point, s.x, s.y, s.scale = "TOPRIGHT", -20, -160, 1
	self:ApplySettings()
end

function Panel:OnEnable()
	FP:On("PLAN_UPDATED", function() self:Refresh() end)
	FP:On("WAYPOINTS_CHANGED", function() self:Refresh() end)
	FP:On("PROFESSIONS_CHANGED", function() self:Refresh() end)
	FP:On("RECIPES_SCANNED", function() self:Refresh() end)
	FP:On("POSITION", function() FP.Throttle("panel-pos", 2, function() if Panel.frame:IsShown() then Panel:Refresh(true) end end) end)
	FP:On("QUESTLOG_SCANNED", function() FP.Throttle("panel-plan", 1, function() if Panel.frame:IsShown() then FP.Planner:Build() end end) end)
	if FP.settings.panel.shown then self:Toggle(true) end
end

function Panel:Toggle(show)
	if show == nil then show = not self.frame:IsShown() end
	FP.settings.panel.shown = show
	if show then
		self.frame:Show()
		FP.Pos:Acquire("panel")
		FP.Planner:Build()
		self:Refresh()
	else
		self.frame:Hide()
		FP.Pos:Release("panel")
	end
end

function Panel:Refresh(positionOnly)
	if not self.frame:IsShown() then return end
	local steps = FP.Planner.steps or {}
	if positionOnly then
		-- refresh distances cheaply without rebuilding
		for _, s in ipairs(steps) do
			if s.mapID and s.x then s.dist = FP.Pos:DistanceTo(s) end
		end
	end
	local xp, max, level, rested = API.GetXP()
	local pct = (xp and max and max > 0) and math.floor(xp / max * 100 + 0.5) or 0
	local active = FP.Waypoints:GetActive()
	self.status:SetText(string.format("Lvl %s · %d%% xp%s · %s", tostring(level or "?"), pct, rested and (" · rested " .. math.floor(rested / (max or 1) * 100 + 0.5) .. "%") or "",
		active and (FP.GOLD .. "→ " .. U.Truncate(active.title, 30) .. "|r") or FP.GREY .. (FP.Planner.waiting and ("Working here: " .. U.Truncate(FP.Planner.waiting.title or "quest", 24)) or (FP.Planner.paused and "route paused — /fp auto on" or "finding next quest")) .. "|r"))
	local n = 0
	for i, row in ipairs(self.rows) do
		local step = steps[i]
		row.step = step
		if step then
			local d, label = FP.Planner:Describe(step)
			row.dist:SetText(d)
			row.label:SetText(label)
			row:Show()
			n = n + 1
		else
			row:Hide()
		end
	end
	if n == 0 then
		self.rows[1].dist:SetText("")
		self.rows[1].label:SetText(FP.GREY .. "No quests in the log. Go pick some up.|r")
		self.rows[1]:Show()
		n = 1
	end
	local cd = API.GetHearthCooldown()
	local bind = FP.cdb.bind and FP.cdb.bind.area or API.GetBindLocation()
	local hearth = bind and ("Hearth: " .. tostring(bind) .. (cd > 0 and (" (" .. U.FormatTime(cd) .. ")") or " (ready)")) or ""
	self.footer:SetText(FP.Prof:Summary() .. "\n" .. table.concat(FP.Prof:Guidance(3), "\n") .. (hearth ~= "" and ("\n" .. hearth) or ""))
	self.frame:SetHeight(40 + n * ROW_HEIGHT + self.footer:GetStringHeight() + 20)
end
