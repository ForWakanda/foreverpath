-- ForeverPath / Nav / Arrow.lua
-- TomTom-style arrow: rotation = bearing(target) - facing(player).
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Arrow = FP:NewModule("Arrow")

local ARROW_TEXTURE = "Interface\\AddOns\\ForeverPath\\Media\\arrow"
local FALLBACK_TEXTURE = "Interface\\Minimap\\MinimapArrow"

local function savePosition(frame)
	local s = FP.settings.arrow
	local point, _, _, x, y = frame:GetPoint(1)
	if point then s.point, s.x, s.y = point, x, y end
end

function Arrow:OnInit()
	local f = CreateFrame("Frame", "ForeverPathArrow", UIParent)
	self.frame = f
	f:SetSize(96, 72)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame)
		if not FP.settings.arrow.locked then frame:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		savePosition(frame)
	end)
	f:SetScript("OnMouseUp", function(frame, button)
		if button == "RightButton" then
			if API.IsShiftDown() then FP.Waypoints:Clear() else FP.Waypoints:Next() end
		end
	end)
	f:SetScript("OnEnter", function(frame)
		local wp = FP.Waypoints:GetActive()
		if not wp then return end
		GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(tostring(wp.title), 1, 0.82, 0)
		if wp.desc then GameTooltip:AddLine(tostring(wp.desc), 1, 1, 1, true) end
		GameTooltip:AddLine(API.GetMapName(wp.mapID) .. "  " .. U.FormatCoords(wp.x, wp.y), 0.7, 0.7, 0.7)
		GameTooltip:AddLine("Drag to move. Right-click: next waypoint. Shift-right-click: clear all.", 0.5, 0.8, 1, true)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local tex = f:CreateTexture(nil, "ARTWORK")
	self.tex = tex
	tex:SetSize(44, 44)
	tex:SetPoint("TOP", f, "TOP", 0, -2)
	local ok = tex:SetTexture(ARROW_TEXTURE)
	if ok == false or (tex.GetTexture and not tex:GetTexture()) then
		tex:SetTexture(FALLBACK_TEXTURE)
		self.usingFallback = true
	end

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.title = title
	title:SetPoint("TOP", tex, "BOTTOM", 0, -1)
	title:SetWidth(180)
	title:SetJustifyH("CENTER")

	local dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.dist = dist
	dist:SetPoint("TOP", title, "BOTTOM", 0, -1)

	self:ApplySettings()
	f:Hide()
	f:SetScript("OnUpdate", function(frame, elapsed) self:OnUpdate(elapsed) end)
end

function Arrow:ApplySettings()
	local s = FP.settings.arrow
	local f = self.frame
	f:ClearAllPoints()
	f:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or 180)
	f:SetScale(s.scale or 1)
end

function Arrow:ResetPosition()
	local s = FP.settings.arrow
	s.point, s.x, s.y, s.scale = "CENTER", 0, 180, 1
	self:ApplySettings()
end

function Arrow:OnEnable()
	FP:On("WAYPOINTS_CHANGED", function() self:Refresh() end)
	self:Refresh()
end

function Arrow:Refresh()
	local wp = FP.Waypoints:GetActive()
	if wp and FP.settings.arrow.shown then
		self.frame:Show()
		FP.Pos:Acquire("arrow")
	else
		self.frame:Hide()
		FP.Pos:Release("arrow")
	end
end

local elapsedAcc = 0
function Arrow:OnUpdate(elapsed)
	elapsedAcc = elapsedAcc + elapsed
	if elapsedAcc < 0.05 then return end
	elapsedAcc = 0
	local wp = FP.Waypoints:GetActive()
	if not wp then self.frame:Hide(); return end
	local pos = FP.Pos.cache
	local d, bearing, sameContinent = FP.Pos:VectorTo(wp)
	self.title:SetText(U.Truncate(wp.title, 40))
	if not d then
		self.tex:SetRotation(0)
		self.tex:SetVertexColor(0.5, 0.5, 0.5)
		if sameContinent == false then
			self.dist:SetText(FP.GREY .. "other continent: " .. API.GetMapName(wp.mapID) .. "|r")
		elseif not pos.valid then
			self.dist:SetText(FP.GREY .. "no position (instance?)|r")
		else
			self.dist:SetText(FP.GREY .. "?|r")
		end
		return
	end
	local facing = pos.facing
	local text = U.FormatDistance(d)
	if pos.speed and pos.speed > 1 and d > 20 then
		text = text .. FP.GREY .. "  " .. U.FormatTime(d / pos.speed) .. "|r"
	end
	self.dist:SetText(text)
	if facing then
		local rel = U.NormalizeAngle(bearing - facing)
		if FP.settings.arrow.flip then rel = -rel end
		self.tex:SetRotation(rel)
		-- green when on target, red when facing away
		local a = math.abs(rel) / math.pi
		if a < 0.12 then self.tex:SetVertexColor(0.2, 1, 0.2)
		else self.tex:SetVertexColor(1, 1 - a * 0.9, 0.2 * (1 - a)) end
	else
		self.tex:SetRotation(0)
		self.tex:SetVertexColor(0.6, 0.6, 0.6)
	end
end
