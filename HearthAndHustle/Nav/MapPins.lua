-- HearthAndHustle / Nav / MapPins.lua
-- World map pins (Blizzard data-provider API) and a minimap pin for the
-- active waypoint and database-backed quest source locations.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local Pins = FP:NewModule("Pins")

local QUEST_PIN_LEVEL = "PIN_FRAME_LEVEL_HEARTH_AND_HUSTLE"
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
	-- Above terrain overlays, below native quest markers and their hit targets.
	if self.UseFrameLevelType then self:UseFrameLevelType(QUEST_PIN_LEVEL) end
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
	if self.UseFrameLevelType then self:UseFrameLevelType(QUEST_PIN_LEVEL) end
	if self.SetScalingLimits then self:SetScalingLimits(1, 1, 1.3) end
end
-- A colored border and quest number identify the quest; the inner icon
-- identifies the action. Shared locations use a white + badge, never one
-- arbitrary quest's color. All art is shipped by the client.
local objectiveIcons={Npc="INV_Sword_04",Item="INV_Misc_Bag_10",Object="INV_Misc_Gear_01",
	Event="INV_Misc_Spyglass_03",Credit="INV_Gauntlets_04",Hint="INV_Misc_Book_09"}
function Pins:StyleObjectivePin(frame,pin,mini)
	local Q=FP.QuestObjectives
	local first=pin.entries[1] and pin.entries[1].group
	if not first then return end
	local ids,n={},0
	for _,entry in ipairs(pin.entries) do if not ids[entry.group.questID] then ids[entry.group.questID]=true;n=n+1 end end
	local r,g,b,slot=Q:Style(first.questID)
	if n>1 then r,g,b=1,1,1 end
	local size=mini and 11 or 18
	frame:SetSize(size,size)
	frame.Icon=frame.Icon or frame:CreateTexture(nil,"BACKGROUND")
	frame.Icon:SetTexture("Interface\\Buttons\\WHITE8X8")
	frame.Icon:SetVertexColor(r,g,b);frame.Icon:SetSize(size,size)
	if not frame.actionIcon then
		frame.actionIcon=frame:CreateTexture(nil,"ARTWORK")
		frame.actionIcon:SetPoint("CENTER")
		frame.actionGlyph=frame:CreateFontString(nil,"OVERLAY",mini and "GameFontNormalSmall" or "GameFontNormal")
		frame.actionGlyph:SetPoint("CENTER");frame.actionGlyph:SetTextColor(1,1,1)
		frame.questBadge=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		frame.questBadge:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",3,-4)
		frame.questBadge:SetTextColor(1,1,1);frame.questBadge:SetShadowColor(0,0,0,1);frame.questBadge:SetShadowOffset(1,-1)
	end
	local inset=mini and 2 or 4
	frame.actionIcon:SetSize(size-inset,size-inset)
	local icon=objectiveIcons[first.kind]
	if icon then
		frame.actionIcon:SetTexture("Interface\\Icons\\"..icon)
		frame.actionIcon:SetVertexColor(1,1,1);frame.actionGlyph:SetText("")
	else
		frame.actionIcon:SetTexture("Interface\\Buttons\\WHITE8X8")
		frame.actionIcon:SetVertexColor(.05,.05,.05)
		frame.actionGlyph:SetText(first.kind=="Pickup" and "!" or "?")
	end
	frame.questBadge:SetText(n>1 and "+" or tostring(slot))
	frame.questBadge:SetShown(not mini)
	frame.questID,frame.sharedQuests=first.questID,n
end
function HearthAndHustleObjectivePinMixin:OnAcquired(point)
	self.point = point; self:EnableMouse(true)
	Pins:StyleObjectivePin(self,point,false)
	self:SetPosition(point.x, point.y)
end
function HearthAndHustleObjectivePinMixin:ShouldMouseButtonBePassthrough(button) return button ~= "LeftButton" and button ~= "RightButton" end
function HearthAndHustleObjectivePinMixin:OnMouseEnter() if self.point then FP.QuestObjectives:Tooltip(self.point,self) end end
function HearthAndHustleObjectivePinMixin:OnMouseLeave() if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end
function HearthAndHustleObjectivePinMixin:OnClick(button)
	if not self.point or not self.point.entries[1] then return end
	if button=="RightButton" then FP.QuestObjectives:Focus(self.point.entries[1].group.questID)
	elseif button == "LeftButton" then FP.QuestObjectives:Guide(self.point) end
end

HearthAndHustleMapDataProviderMixin = {}

function HearthAndHustleMapDataProviderMixin:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
	self:GetMap():RemoveAllPinsByTemplate("HearthAndHustleObjectivePinTemplate")
end

function HearthAndHustleMapDataProviderMixin:RefreshAllData(fromOnShow)
	-- Native map callbacks do not pass through our event error sink.
	FP.pcall("worldmap-refresh", self.RefreshPins, self, fromOnShow)
end

function HearthAndHustleMapDataProviderMixin:RefreshPins(fromOnShow)
	self:RemoveAllData()
	local mapID = self:GetMap():GetMapID()
	FP.pcall("worldmap-legend", Pins.UpdateLegend, Pins, self:GetMap(), mapID)
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
		if FP.settings.questMinimapPins and FP.settings.minimapPin and #FP.QuestObjectives:VisibleGroups() > 0 then
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
	-- DEFAULT sits BELOW the explored-terrain and fog overlays in Forever.
	-- Register an explicit level above all terrain/blob layers; keep Blizzard's
	-- POI/quest icons above ours. Do this before any pooled pins are acquired.
	local levels = WorldMapFrame:GetPinFrameLevelsManager()
	if levels:InsertFrameLevelAbove(QUEST_PIN_LEVEL, "PIN_FRAME_LEVEL_MAP_HIGHLIGHT") then
		WorldMapFrame:ReapplyPinFrameLevels()
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
	local cellYards=radius and radius*18/((Minimap:GetWidth() or 140)/2)
	local w,h = API.GetMapWorldSize(pos.mapID)
	if not w or not h or not radius or radius <= 0 then hideAll(); return end
	for _,group in ipairs(FP.QuestObjectives:VisibleGroups()) do
		for _,p in ipairs(group.points) do
			if p.mapID == pos.mapID then
				local dx,dy=(p.x-pos.x)*w,(p.y-pos.y)*h
				if dx*dx+dy*dy <= radius*radius then
					local key=math.floor(p.x*w/cellYards)..":"..math.floor(p.y*h/cellYards)
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
	-- Grid cells alone can leave two icons touching across a cell boundary.
	-- Merge those into the nearest marker too, preserving every tooltip entry.
	local spaced={}
	for _,pin in ipairs(nearby) do
		local overlap
		for _,shown in ipairs(spaced) do
			local dx,dy=(pin.x-shown.x)*w*half/radius,(pin.y-shown.y)*h*half/radius
			if dx*dx+dy*dy < 14*14 then overlap=shown;break end
		end
		if overlap then
			for _,entry in ipairs(pin.entries) do overlap.entries[#overlap.entries+1]=entry end
		elseif #spaced<24 then spaced[#spaced+1]=pin end
	end
	nearby=spaced
	local rotating=API.IsMinimapRotating()
	for i=1,#nearby do
		local pin,frame=nearby[i],self.objectiveMini[i]
		if not frame then
			frame=CreateFrame("Button",nil,Minimap)
			frame:SetSize(10,10); frame:SetFrameStrata("MEDIUM")
			frame:SetFrameLevel((Minimap:GetFrameLevel() or 1)+3)
			frame.Icon=frame:CreateTexture(nil,"BACKGROUND");frame.Icon:SetPoint("CENTER")
			frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
			frame:SetScript("OnEnter",function(f) if f.point then FP.QuestObjectives:Tooltip(f.point,f) end end)
			frame:SetScript("OnLeave",function(f) if GameTooltip:IsOwned(f) then GameTooltip:Hide() end end)
			frame:SetScript("OnClick",function(f,button)
				if f.point then
					if button=="RightButton" then FP.QuestObjectives:Focus(f.point.entries[1].group.questID)
					else FP.QuestObjectives:Guide(f.point) end
				end
			end)
			self.objectiveMini[i]=frame
		end
		frame.point=pin
		self:StyleObjectivePin(frame,pin,true)
		local rel=pin.bearing-(rotating and pos.facing or 0)
		local x,y=U.RadialOffset(rel,pin.d*half/radius)
		frame:ClearAllPoints(); frame:SetPoint("CENTER",Minimap,"CENTER",x,y); frame:Show()
	end
	for i=#nearby+1,#self.objectiveMini do self.objectiveMini[i]:Hide() end
end

-- Compact, paged map key. Focusing/hiding changes markers only, never the route.
function Pins:UpdateLegend(map,mapID)
	local Q=FP.QuestObjectives
	if not self.legend then
		local f=CreateFrame("Frame","HearthAndHustleQuestLegend",map,"BackdropTemplate")
		self.legend=f; f:SetSize(254,266); f:SetPoint("BOTTOMLEFT",map,"BOTTOMLEFT",18,38)
		f:SetFrameLevel((map:GetFrameLevel() or 1)+40);f:EnableMouse(true)
		f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
		f:SetBackdropColor(.025,.035,.05,.94)
		local function button(text,x,y,w,fn)
			local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,20);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",fn);return b
		end
		f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetPoint("TOPLEFT",10,-10);f.title:SetText("Hearth & Hustle quests")
		f.collapse=button("-",226,-5,20,function() f.collapsed=not f.collapsed; self:UpdateLegend(map,map:GetMapID()) end)
		f.all=button("Show all",8,-30,70,function() Q:ShowAll() end)
		f.settings=button("Settings",82,-30,70,function() FP.Hub:Open("display") end)
		f.pageLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.pageLabel:SetPoint("TOPLEFT",160,-36)
		f.rows={}
		for i=1,6 do
			local b=CreateFrame("Button",nil,f);b:SetSize(236,27);b:SetPoint("TOPLEFT",9,-55-(i-1)*28)
			b:RegisterForClicks("LeftButtonUp","RightButtonUp")
			b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");b.text:SetAllPoints();b.text:SetJustifyH("LEFT")
			b:SetScript("OnClick",function(row,button)
				if row.questID then if button=="RightButton" then Q:ToggleHidden(row.questID) else Q:Focus(row.questID) end end
			end)
			b:SetScript("OnEnter",function(row)
				if not row.questID then return end
				GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(Q:QuestLabel(row.questID,row.questTitle))
				GameTooltip:AddLine("Click: focus/unfocus. Right-click: hide/show.",1,1,1,true)
				GameTooltip:AddLine("Sword: kill · Bag: loot · Gear: interact · Spyglass: event",.8,.8,.8,true)
				GameTooltip:AddLine("! Pickup · ? Turn-in · White +: shared location",.8,.8,.8,true);GameTooltip:Show()
			end)
			b:SetScript("OnLeave",function(row) if GameTooltip:IsOwned(row) then GameTooltip:Hide() end end)
			f.rows[i]=b
		end
		f.prev=button("<",8,-226,25,function() f.page=math.max(1,(f.page or 1)-1);self:UpdateLegend(map,map:GetMapID()) end)
		f.next=button(">",38,-226,25,function() f.page=(f.page or 1)+1;self:UpdateLegend(map,map:GetMapID()) end)
		f.hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.hint:SetPoint("TOPLEFT",72,-230);f.hint:SetWidth(174);f.hint:SetJustifyH("LEFT");f.hint:SetText("Click quest: focus\nRight-click: hide/show")
	end
	local f=self.legend
	if not FP.settings.worldMapPins or not FP.settings.questWorldPins or FP.settings.questMapLegend==false then f:Hide();return end
	local rows=Q:Legend(mapID)
	if f.mapID~=mapID then f.page=1;f.mapID=mapID end
	local pages=math.max(1,math.ceil(#rows/6));f.page=math.min(f.page or 1,pages)
	f.collapse:SetText(f.collapsed and "+" or "-");f:SetHeight(f.collapsed and 28 or 260)
	for _,control in ipairs({f.all,f.settings,f.prev,f.next,f.hint,f.pageLabel}) do control:SetShown(not f.collapsed) end
	f.pageLabel:SetText(f.page.." / "..pages)
	for i,b in ipairs(f.rows) do
		local row=rows[(f.page-1)*6+i]
		b.questID,b.questTitle=row and row.questID,row and row.title
		if row then
			local hidden=(FP.cdb.questMapHidden or {})[row.questID]
			local state=hidden and "Hidden" or (Q.focusedQuest==row.questID and "Focused" or (row.markers>0 and (row.markers.." markers") or "Locations unavailable here"))
			b.text:SetText(Q:QuestLabel(row.questID,U.Truncate(row.title,31)).."\n"..FP.GREY..state.."|r")
		elseif i==1 then b.text:SetText("No quest markers on this map.") end
		b:SetShown(not f.collapsed and (row~=nil or i==1))
	end
	f:Show()
end
