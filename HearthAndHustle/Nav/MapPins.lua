-- HearthAndHustle / Nav / MapPins.lua
-- World map pins (Blizzard data-provider API) and a minimap pin for the
-- active waypoint and database-backed quest source locations.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Pins = FP:NewModule("Pins")

local PIN_TEMPLATE = "HearthAndHustleMapPinTemplate"
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
HearthAndHustleMapPinMixin = {}

local function checkPassthrough(self,...)
 if API.InCombat() then return end
 if MapCanvasPinMixin and MapCanvasPinMixin.CheckMouseButtonPassthrough then
  return MapCanvasPinMixin.CheckMouseButtonPassthrough(self,...)
 end
end
HearthAndHustleMapPinMixin.CheckMouseButtonPassthrough=checkPassthrough

function HearthAndHustleMapPinMixin:ShouldMouseButtonBePassthrough(button)
	return self.passive == true -- only manual pins own activation/removal
end

function HearthAndHustleMapPinMixin:OnLoad()
	-- Native quest markers must win both drawing and hit testing on overlap.
	if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_DEFAULT") end
	if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
end

function HearthAndHustleMapPinMixin:OnAcquired(wp, isActive)
	self.wp = wp
	-- Planner pins are refreshed/recreated automatically. They are guidance,
	-- not removable manual waypoints: let native quest hover/clicks through.
	-- Reset on every acquisition because Blizzard pools these frames.
	self.passive = wp.source ~= nil and wp.source.type == "plan"
	self:EnableMouse(not self.passive)
	if isActive and atlasExists(PIN_ATLAS_ACTIVE) then
		self.Icon:SetAtlas(PIN_ATLAS_ACTIVE, false)
	elseif atlasExists(PIN_ATLAS) then
		self.Icon:SetAtlas(PIN_ATLAS, false)
	else
		self.Icon:SetTexture("Interface\\AddOns\\HearthAndHustle\\Media\\pin")
	end
	self.Icon:SetSize(isActive and 30 or 22, isActive and 30 or 22)
	self:SetPosition(wp.x, wp.y)
end

function HearthAndHustleMapPinMixin:OnMouseEnter()
	if self.passive or not self.wp then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Hearth & Hustle: " .. tostring(self.wp.title), 1, 0.82, 0)
	if self.wp.desc then GameTooltip:AddLine(tostring(self.wp.desc), 1, 1, 1, true) end
	local d = FP.Pos:DistanceTo(self.wp)
	GameTooltip:AddLine(U.FormatCoords(self.wp.x, self.wp.y) .. (d and ("  " .. U.FormatDistance(d)) or ""), 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Click: set as active.  Right-click: remove.", 0.5, 0.8, 1)
	GameTooltip:Show()
end

function HearthAndHustleMapPinMixin:OnMouseLeave()
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- MapCanvasMixin routes OnMouseUp(button, upInside) -> OnClick(button) for us.
function HearthAndHustleMapPinMixin:OnClick(button)
	if self.passive or not self.wp then return end
	if button == "RightButton" then
		FP.Waypoints:Remove(self.wp.id)
	else
		FP.Waypoints:SetActive(self.wp.id)
	end
end

-- Small source markers sit below Blizzard quest markers, with their own pool.
HearthAndHustleObjectivePinMixin = {CheckMouseButtonPassthrough=checkPassthrough}
function HearthAndHustleObjectivePinMixin:OnLoad()
	if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_DEFAULT") end
	if self.SetScalingLimits then self:SetScalingLimits(1, 1, 1.3) end
end
function HearthAndHustleObjectivePinMixin:OnAcquired(point)
	self.point = point
	self:EnableMouse(true)
	-- Reuse the shipped pin asset; no new media dependency.
	self.Icon:SetTexture("Interface\\AddOns\\HearthAndHustle\\Media\\pin")
	self.Icon:SetVertexColor(1,.65,.15)
	self.Icon:SetSize(12,12)
	self:SetPosition(point.x, point.y)
end
function HearthAndHustleObjectivePinMixin:ShouldMouseButtonBePassthrough(button) return button ~= "LeftButton" end
function HearthAndHustleObjectivePinMixin:OnMouseEnter() if self.point then FP.QuestObjectives:Tooltip(self.point,self) end end
function HearthAndHustleObjectivePinMixin:OnMouseLeave() if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end
function HearthAndHustleObjectivePinMixin:OnClick(button)
	if button == "LeftButton" and self.point then FP.QuestObjectives:Guide(self.point) end
end

HearthAndHustleMapDataProviderMixin = {}

function HearthAndHustleMapDataProviderMixin:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
	self:GetMap():RemoveAllPinsByTemplate("HearthAndHustleObjectivePinTemplate")
end

function HearthAndHustleMapDataProviderMixin:RefreshAllData(fromOnShow)
	self:RemoveAllData()
	local mapID = self:GetMap():GetMapID()
	if FP.settings.questWorldPins and FP.settings.worldMapPins then
		for _,point in ipairs(FP.QuestObjectives:WorldPins(mapID)) do
			self:GetMap():AcquirePin("HearthAndHustleObjectivePinTemplate",point)
		end
	end
	if not FP.settings.worldMapPins then return end
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
	local m = CreateFrame("Frame", "HearthAndHustleMinimapPin", Minimap)
	self.mini = m
	m:SetSize(16, 16)
	m:SetFrameStrata("MEDIUM")
	m:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
	local tex = m:CreateTexture(nil, "OVERLAY")
	m.tex = tex
	tex:SetAllPoints()
	if atlasExists(PIN_ATLAS) then tex:SetAtlas(PIN_ATLAS, false) else tex:SetTexture("Interface\\AddOns\\HearthAndHustle\\Media\\pin") end
	m:EnableMouse(true)
	m:SetScript("OnEnter", function(frame)
		local wp = FP.Waypoints:GetActive()
		if not wp then return end
		GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
		GameTooltip:AddLine("Hearth & Hustle: " .. tostring(wp.title), 1, 0.82, 0)
		local d = FP.Pos:DistanceTo(wp)
		if d then GameTooltip:AddLine(U.FormatDistance(d), 0.7, 0.7, 0.7) end
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m:Hide()
end

function Pins:OnEnable()
 FP:RegisterEvent("PLAYER_REGEN_ENABLED",function() self:OnWaypointsChanged() end)
	FP:On("POSITION", function(pos) self:UpdateMinimap(pos); self:UpdateObjectiveMinimap(pos) end)
	FP:On("QUEST_LOCATIONS_CHANGED", function()
		if FP.settings.questMinimapPins and FP.settings.minimapPin and #FP.QuestObjectives.groups > 0 then
			FP.Pos:Acquire("quest-objective-minimap")
		else FP.Pos:Release("quest-objective-minimap") end
		self:OnWaypointsChanged()
		self.lastObjectiveMini = nil
		self:UpdateObjectiveMinimap(FP.Pos:Refresh(true))
	end)
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
		if HearthAndHustleMapPinMixin[k] == nil then HearthAndHustleMapPinMixin[k] = v end
		if HearthAndHustleObjectivePinMixin[k] == nil then HearthAndHustleObjectivePinMixin[k] = v end
	end
	for k, v in pairs(MapCanvasDataProviderMixin) do
		if HearthAndHustleMapDataProviderMixin[k] == nil then HearthAndHustleMapDataProviderMixin[k] = v end
	end
	self.provider = CreateFromMixins(HearthAndHustleMapDataProviderMixin)
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

-- Pool only nearby points (no clamping distant sources onto the minimap rim).
-- Map-space prefilter avoids world conversions for every distant spawn.
function Pins:UpdateObjectiveMinimap(pos)
	self.objectiveMini = self.objectiveMini or {}
	local function hideAll() for _,frame in ipairs(self.objectiveMini) do frame:Hide() end end
	if not FP.settings.questMinimapPins or not FP.settings.minimapPin or not pos.valid then hideAll(); return end
	local now = API.Time()
	if self.lastObjectiveMini and now-self.lastObjectiveMini < .25 then return end
	self.lastObjectiveMini = now
	local radius, nearby, seen = API.GetMinimapViewRadius(), {}, {}
	local w,h = API.GetMapWorldSize(pos.mapID)
	if not w or not h or not radius or radius <= 0 then hideAll(); return end
	for _,group in ipairs(FP.QuestObjectives:VisibleGroups()) do
		for _,p in ipairs(group.points) do
			if p.mapID == pos.mapID then
				local dx,dy=(p.x-pos.x)*w,(p.y-pos.y)*h
				if dx*dx+dy*dy <= radius*radius then
					local key=math.floor(p.x*w/12)..":"..math.floor(p.y*h/12)
					local pin=seen[key]
					if not pin then
						local d,bearing=FP.Pos:VectorTo(p)
						if d and d <= radius then
							pin={mapID=p.mapID,x=p.x,y=p.y,d=d,bearing=bearing,entries={}}
							seen[key],nearby[#nearby+1]=pin,pin
						end
					end
					if pin then pin.entries[#pin.entries+1]={point=p,group=group} end
				end
			end
		end
	end
	table.sort(nearby,function(a,b) return a.d < b.d end)
	local half=(Minimap:GetWidth() or 140)/2
	local rotating=API.IsMinimapRotating()
	for i=1,math.min(40,#nearby) do
		local pin,frame=nearby[i],self.objectiveMini[i]
		if not frame then
			frame=CreateFrame("Button",nil,Minimap)
			frame:SetSize(10,10); frame:SetFrameStrata("MEDIUM")
			frame:SetFrameLevel((Minimap:GetFrameLevel() or 1)+3)
			local tex=frame:CreateTexture(nil,"OVERLAY"); tex:SetAllPoints()
			tex:SetTexture("Interface\\AddOns\\HearthAndHustle\\Media\\pin"); tex:SetVertexColor(1,.65,.15)
			frame:SetScript("OnEnter",function(f) if f.point then FP.QuestObjectives:Tooltip(f.point,f) end end)
			frame:SetScript("OnLeave",function(f) if GameTooltip:IsOwned(f) then GameTooltip:Hide() end end)
			frame:SetScript("OnClick",function(f) if f.point then FP.QuestObjectives:Guide(f.point) end end)
			self.objectiveMini[i]=frame
		end
		frame.point=pin
		local rel=pin.bearing-(rotating and pos.facing or 0)
		local x,y=U.RadialOffset(rel,pin.d*half/radius)
		frame:ClearAllPoints(); frame:SetPoint("CENTER",Minimap,"CENTER",x,y); frame:Show()
	end
	for i=math.min(40,#nearby)+1,#self.objectiveMini do self.objectiveMini[i]:Hide() end
end
