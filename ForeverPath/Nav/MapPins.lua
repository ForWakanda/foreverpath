-- ForeverPath / Nav / MapPins.lua
-- World map pins (Blizzard data-provider API) and a minimap pin for the
-- active waypoint. Quest POIs themselves are drawn by Blizzard; we only add
-- our waypoints.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Pins = FP:NewModule("Pins")

local PIN_TEMPLATE = "ForeverPathMapPinTemplate"
local PIN_ATLAS = "Waypoint-MapPin-Untracked"
local PIN_ATLAS_ACTIVE = "Waypoint-MapPin-Tracked"

local function atlasExists(name)
	return API.AtlasExists(name)
end

-------------------------------------------------------------------------------
-- World map pin mixin + data provider (globals: referenced by MapPins.xml)
-------------------------------------------------------------------------------
-- Plain table at load time (the XML template names it); Blizzard's MapCanvasPinMixin
-- methods are merged in by Pins:HookWorldMap once the map system exists.
ForeverPathMapPinMixin = {}

function ForeverPathMapPinMixin:ShouldMouseButtonBePassthrough(button)
	return false -- both left activation and right removal belong to this pin
end

function ForeverPathMapPinMixin:OnLoad()
	if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST") end
	if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
end

function ForeverPathMapPinMixin:OnAcquired(wp, isActive)
	self.wp = wp
	if isActive and atlasExists(PIN_ATLAS_ACTIVE) then
		self.Icon:SetAtlas(PIN_ATLAS_ACTIVE, false)
	elseif atlasExists(PIN_ATLAS) then
		self.Icon:SetAtlas(PIN_ATLAS, false)
	else
		self.Icon:SetTexture("Interface\\AddOns\\ForeverPath\\Media\\pin")
	end
	self.Icon:SetSize(isActive and 30 or 22, isActive and 30 or 22)
	self:SetPosition(wp.x, wp.y)
end

function ForeverPathMapPinMixin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("ForeverPath: " .. tostring(self.wp.title), 1, 0.82, 0)
	if self.wp.desc then GameTooltip:AddLine(tostring(self.wp.desc), 1, 1, 1, true) end
	local d = FP.Pos:DistanceTo(self.wp)
	GameTooltip:AddLine(U.FormatCoords(self.wp.x, self.wp.y) .. (d and ("  " .. U.FormatDistance(d)) or ""), 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Click: set as active.  Right-click: remove.", 0.5, 0.8, 1)
	GameTooltip:Show()
end

function ForeverPathMapPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end

-- MapCanvasMixin routes OnMouseUp(button, upInside) -> OnClick(button) for us.
function ForeverPathMapPinMixin:OnClick(button)
	if button == "RightButton" then
		FP.Waypoints:Remove(self.wp.id)
	else
		FP.Waypoints:SetActive(self.wp.id)
	end
end

ForeverPathMapDataProviderMixin = {}

function ForeverPathMapDataProviderMixin:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
end

function ForeverPathMapDataProviderMixin:RefreshAllData(fromOnShow)
	self:RemoveAllData()
	if not FP.settings.worldMapPins then return end
	local mapID = self:GetMap():GetMapID()
	local active = FP.Waypoints:GetActive()
	for _, wp in ipairs(FP.Waypoints.list) do
		if wp.mapID == mapID then
			self:GetMap():AcquirePin(PIN_TEMPLATE, wp, active and active.id == wp.id)
		end
	end
end

-------------------------------------------------------------------------------
-- Minimap pin
-------------------------------------------------------------------------------
function Pins:OnInit()
	local m = CreateFrame("Frame", "ForeverPathMinimapPin", Minimap)
	self.mini = m
	m:SetSize(16, 16)
	m:SetFrameStrata("MEDIUM")
	m:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
	local tex = m:CreateTexture(nil, "OVERLAY")
	m.tex = tex
	tex:SetAllPoints()
	if atlasExists(PIN_ATLAS) then tex:SetAtlas(PIN_ATLAS, false) else tex:SetTexture("Interface\\AddOns\\ForeverPath\\Media\\pin") end
	m:EnableMouse(true)
	m:SetScript("OnEnter", function(frame)
		local wp = FP.Waypoints:GetActive()
		if not wp then return end
		GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
		GameTooltip:AddLine("ForeverPath: " .. tostring(wp.title), 1, 0.82, 0)
		local d = FP.Pos:DistanceTo(wp)
		if d then GameTooltip:AddLine(U.FormatDistance(d), 0.7, 0.7, 0.7) end
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m:Hide()
end

function Pins:OnEnable()
	FP:On("POSITION", function(pos) self:UpdateMinimap(pos) end)
	FP:On("WAYPOINTS_CHANGED", function() self:OnWaypointsChanged() end)
	self:HookWorldMap()
end

function Pins:HookWorldMap()
	if self.provider then return end
	if not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin and MapCanvasPinMixin) then
		FP:Debug("WorldMapFrame not ready; retrying")
		FP.After(2, function() self:HookWorldMap() end)
		return
	end
	for k, v in pairs(MapCanvasPinMixin) do
		if ForeverPathMapPinMixin[k] == nil then ForeverPathMapPinMixin[k] = v end
	end
	for k, v in pairs(MapCanvasDataProviderMixin) do
		if ForeverPathMapDataProviderMixin[k] == nil then ForeverPathMapDataProviderMixin[k] = v end
	end
	self.provider = CreateFromMixins(ForeverPathMapDataProviderMixin)
	local ok, err = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, self.provider)
	if not ok then
		self.provider = nil
		FP:ReportError("worldmap-provider", err)
	end
end

function Pins:OnWaypointsChanged()
	if self.provider and WorldMapFrame and WorldMapFrame:IsShown() then
		FP.pcall("worldmap-refresh", self.provider.RefreshAllData, self.provider)
	end
	if #FP.Waypoints.list == 0 then self.mini:Hide() end
end

function Pins:UpdateMinimap(pos)
	local m = self.mini
	if not FP.settings.minimapPin then m:Hide(); return end
	local wp = FP.Waypoints:GetActive()
	if not wp or not pos.valid then m:Hide(); return end
	local d, bearing = FP.Pos:VectorTo(wp)
	if not d then m:Hide(); return end
	local radiusYards = API.GetMinimapViewRadius()
	local half = (Minimap:GetWidth() or 140) / 2
	local px = d * half / radiusYards
	local rel = bearing
	if API.IsMinimapRotating() and pos.facing then rel = bearing - pos.facing end
	local edge = false
	local maxPx = half - 6
	if px > maxPx then px, edge = maxPx, true end
	local x, y = U.RadialOffset(rel, px)
	m:ClearAllPoints()
	m:SetPoint("CENTER", Minimap, "CENTER", x, y)
	m:SetAlpha(edge and 0.55 or 1)
	m:Show()
end
