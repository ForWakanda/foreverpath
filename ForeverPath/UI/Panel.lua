-- ForeverPath / UI / Panel.lua
-- "Next steps" window: the planner's ordered list, click a row to send the arrow there.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Panel = FP:NewModule("Panel")

local ROW_HEIGHT = 16
local WIDTH = 360
local CONTENT_TOP = 72

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

	local dungeons = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	self.dungeons = dungeons
	dungeons:SetSize(78, 20)
	dungeons:SetPoint("TOPLEFT", 10, -27)
	dungeons:SetText("Dungeons")
	dungeons:SetScript("OnClick", function() FP.DungeonPanel:Open() end)

	local settings = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	self.settingsButton = settings
	settings:SetSize(78, 20)
	settings:SetPoint("LEFT", dungeons, "RIGHT", 6, 0)
	settings:SetText("Settings")
	settings:SetScript("OnClick", function() self:OpenSettings() end)

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.status = status
	status:SetPoint("TOPLEFT", 10, -53)
	status:SetWidth(WIDTH - 20)
	status:SetJustifyH("LEFT")

	self.rows = {}
	for i = 1, FP.settings.panel.maxSteps or 10 do
		local row = CreateFrame("Button", nil, f)
		row:SetSize(WIDTH - 20, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 10, -CONTENT_TOP - (i - 1) * ROW_HEIGHT)
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
				if FP.Planner:Go(btn.step) then FP:Print(FP.GOLD .. "Go:|r " .. btn.step.title)
				else FP:Print("No coordinates available for " .. btn.step.title .. ". Check the quest's directions in your log.") end
			end
		end)
		row:SetScript("OnEnter", function(btn)
			if not btn.step then return end
			GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
			GameTooltip:AddLine(tostring(btn.step.title), 1, 0.82, 0)
			if btn.step.text and btn.step.kind ~= "turnin" then GameTooltip:AddLine(tostring(btn.step.text), 1, 1, 1, true) end
			if btn.step.cluster and btn.step.cluster > 0 then GameTooltip:AddLine(btn.step.cluster .. " other quests within about 200 yd (straight-line).", 0.5, 0.8, 1, true) end
			if btn.step.partnerPending then GameTooltip:AddLine("Partner's last shared snapshot: still working on this quest. Check before leaving.", 1, 0.82, 0, true) end
			if btn.step.deferred then GameTooltip:AddLine("Deferred for this session. Click to resume now.", 1, 0.82, 0, true) end
			if btn.step.highLevel then GameTooltip:AddLine("Quest is more than 3 levels above you; easier nearby work is favored.", 1, 0.5, 0.3, true) end
			if U.Finite(btn.step.groupSize) and btn.step.groupSize > 1 then GameTooltip:AddLine("Client suggests a group of " .. btn.step.groupSize .. ".", 1, 0.82, 0, true) end
			if btn.step.mapID then GameTooltip:AddLine(API.GetMapName(btn.step.mapID) .. "  " .. U.FormatCoords(btn.step.x, btn.step.y) .. "  " .. FP.GREY .. "(" .. tostring(btn.step.how) .. ")|r", 0.7, 0.7, 0.7)
			else GameTooltip:AddLine("The client has supplied no coordinates for this objective. Check the quest directions in your log.", 0.9, 0.5, 0.5, true) end
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
		active and (FP.GOLD .. "→ " .. U.Truncate(active.title, 30) .. "|r") or FP.GREY .. (FP.Planner.waiting and ("Working here: " .. U.Truncate(FP.Planner.waiting.title or "quest", 24)) or (FP.Planner.paused and "route paused — /fp auto on" or (#steps > 0 and "No route coordinates available" or "No available quest locations reported"))) .. "|r"))
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
		self.rows[1].label:SetText(FP.GREY .. "No known steps or available pickups on this map.|r")
		self.rows[1]:Show()
		n = 1
	end
	local cd = API.GetHearthCooldown()
	local bind = FP.cdb.bind and FP.cdb.bind.area or API.GetBindLocation()
	local hearth = bind and ("Hearth: " .. tostring(bind) .. (cd > 0 and (" (" .. U.FormatTime(cd) .. ")") or " (ready)")) or ""
	local batch = FP.Prof:PlanLines()
	self.footer:SetText(FP.Prof:Summary() .. "\n" .. table.concat(FP.Prof:Guidance(3), "\n") .. (#batch > 0 and ("\n" .. table.concat(batch, "\n")) or "") .. (hearth ~= "" and ("\n" .. hearth) or ""))
	self.frame:SetHeight(CONTENT_TOP + n * ROW_HEIGHT + self.footer:GetStringHeight() + 20)
end

-------------------------------------------------------------------------------
-- Display preferences. Built on first open; writes the existing account settings.
-------------------------------------------------------------------------------
function Panel:OpenSettings()
	if not self.displayFrame then self:CreateSettings() end
	self:RefreshSettings()
	self.displayFrame:Show()
end

function Panel:RefreshSettings()
	if not self.displayFrame then return end
	for _, check in ipairs(self.displayChecks) do
		local settings = check.arrow and FP.settings.arrow or FP.settings
		check:SetChecked(settings[check.key] == true)
	end
	local scale = FP.settings.arrow.scale or 1
	self.arrowSize:SetText(string.format("Arrow size: %d%%", math.floor(scale * 100 + 0.5)))
	if scale <= 0.4 then self.smaller:Disable() else self.smaller:Enable() end
	if scale >= 3 then self.larger:Disable() else self.larger:Enable() end
end

function Panel:ApplyDisplaySettings()
	FP.Arrow:ApplySettings()
	FP.Arrow:Refresh()
	FP.Pins:OnWaypointsChanged()
	FP.Pins:UpdateMinimap(FP.Pos:Refresh(true))
	self:RefreshSettings()
end

function Panel:ResizeArrow(delta)
	local scale = FP.settings.arrow.scale
	if not U.Finite(scale) then scale = 1 end
	FP.settings.arrow.scale = math.max(0.4, math.min(3, math.floor((scale + delta) * 10 + 0.5) / 10))
	self:ApplyDisplaySettings()
end

function Panel:CreateSettings()
	local f = CreateFrame("Frame", "ForeverPathDisplaySettings", UIParent, "BackdropTemplate")
	self.displayFrame = f
	f:SetSize(400, 410)
	f:SetPoint("CENTER", UIParent, "CENTER", -250, -20)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
	f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
	f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	f:SetBackdropBorderColor(0.37, 0.84, 1, 0.8)
	if UISpecialFrames then table.insert(UISpecialFrames, "ForeverPathDisplaySettings") end
	local function label(text, y, font)
		local l = f:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
		l:SetPoint("TOPLEFT", 16, y)
		l:SetWidth(368)
		l:SetJustifyH("LEFT")
		l:SetText(text)
		return l
	end
	local function button(text, x, y, width, fn)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(width, 22)
		b:SetPoint("TOPLEFT", x, y)
		b:SetText(text)
		b:SetScript("OnClick", fn)
		return b
	end
	label("ForeverPath - Display settings", -14, "GameFontNormalLarge")
	label("Changes apply immediately and save for all characters.", -40)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() f:Hide() end)
	self.displayChecks = {}
	local function check(text, key, arrow, y)
		local b = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		b:SetSize(24, 24)
		b:SetPoint("TOPLEFT", 16, y)
		b:SetHitRectInsets(0, -336, 0, 0) -- the label is clickable too
		b.key, b.arrow = key, arrow
		local l = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		l:SetPoint("LEFT", b, "RIGHT", 4, 0)
		l:SetText(text)
		b:SetScript("OnClick", function(btn)
			local settings = btn.arrow and FP.settings.arrow or FP.settings
			settings[btn.key] = btn:GetChecked() == true
			self:ApplyDisplaySettings()
		end)
		table.insert(self.displayChecks, b)
	end
	label("Map pins", -68, "GameFontNormal")
	check("Show ForeverPath world-map pins", "worldMapPins", false, -86)
	check("Show ForeverPath minimap pin", "minimapPin", false, -113)
	label("WoW's quest markers stay visible and interactive.", -143)
	label("Navigation arrow", -174, "GameFontNormal")
	check("Show arrow", "shown", true, -192)
	check("Lock arrow position", "locked", true, -219)
	check("Reverse arrow rotation", "flip", true, -246)
	label("Unlock to drag the arrow. Reverse only if it points the wrong way.", -276)
	self.arrowSize = label("", -312, "GameFontHighlight")
	self.arrowSize:SetWidth(230)
	self.smaller = button("-", 284, -306, 42, function() self:ResizeArrow(-0.1) end)
	self.larger = button("+", 332, -306, 42, function() self:ResizeArrow(0.1) end)
	self.resetArrow = button("Reset arrow position & size", 16, -345, 238, function()
		FP.Arrow:ResetPosition()
		self:ApplyDisplaySettings()
	end)
	button("Done", 284, -345, 90, function() f:Hide() end)
	label("Hiding pins or the arrow keeps your route active.", -382)
	f:Hide()
end
