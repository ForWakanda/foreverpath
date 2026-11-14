-- HearthAndHustle / UI / Hub.lua
-- Click-driven home for existing features. Browsing is read-only; actions use
-- the same guarded modules as slash commands, with results kept in the window.
local _, FP = ...
local U, API = FP.Util, FP.API
local H = FP:NewModule("Hub")
local W = 600
local SECTIONS = {
	{"home", "Overview", "Quest, gear and preparation tools for your next adventure."},
	{"gear", "Best in slot", "Find gear by slot, compare stats and plan your next upgrade."},
	{"dungeons", "Dungeons", "Entrance guidance, quest preparation and pickup routes."},
	{"navigation", "Navigation", "Choose your next quest or resume your route."},
	{"locations", "Quest locations", "Find quest targets, inspect known locations and show them on the map."},
	{"rewards", "Quest rewards", "Compare reward items, equipped gear, and vendor values."},
	{"chains", "Quest chains", "Explore prerequisites, optional lead-ins, and what comes next."},
	{"waypoints", "Waypoints", "Save places, enter coordinates, and manage your destinations."},
	{"professions", "Professions", "Choose a learned recipe and plan the materials for a batch."},
	{"party", "Party", "Compare quest progress and exchange snapshots with your partner."},
	{"town", "Supplies & town", "Preparation, vendor information, reminders, and trainer notes."},
	{"pvp", "PvP", "HUD preferences, battleground objectives, and session information."},
	{"rare", "Rare watch", "Manage the watch list and review your dungeon runs."},
	{"display", "Display", "Arrange your arrow, compact quest panel, and status line."},
	{"tools", "Diagnostics", "Recording, checks, and data management."},
}
H.sections = SECTIONS

local function label(parent, text, x, y, width, font)
	local l = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	l:SetPoint("TOPLEFT", x, y); l:SetWidth(width); l:SetJustifyH("LEFT"); l:SetText(text)
	return l
end
local function backdrop(f, alpha)
	f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
	f:SetBackdropColor(.035,.045,.065,alpha or .98)
	f:SetBackdropBorderColor(.22,.48,.60,.9)
end
local function button(parent, text, x, y, width, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",fn)
	return b
end
local function scroll(parent, x, y, width, height)
	local s = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	s:SetPoint("TOPLEFT",x,y); s:SetSize(width,height)
	local c = CreateFrame("Frame",nil,s); c:SetSize(width,height); s:SetScrollChild(c)
	return s,c
end
local function command(text) FP.Commands:Handle(text) end
local function onoff(value) return value and "on" or "off" end

function H:OnInit()
	self.pages, self.controls = {}, {}
end

function H:FitWindow()
	if not self.frame then return end
	local width,height=UIParent:GetWidth(),UIParent:GetHeight()
	self.frame:SetScale(math.max(.4,math.min(1,(width-24)/860,(height-24)/690)))
end

function H:Create()
	local f = CreateFrame("Frame","HearthAndHustleHub",UIParent,"BackdropTemplate")
	self.frame = f
	local s=FP.settings.hub
	f:SetSize(860,690); f:SetPoint(s.point,UIParent,s.point,s.x,s.y); f:SetFrameStrata("DIALOG");f:SetToplevel(true)
	f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart",function(frame) frame:StartMoving() end)
	f:SetScript("OnDragStop",function(frame)
		frame:StopMovingOrSizing()
		local point,_,_,x,y=frame:GetPoint(1)
		if point then s.point,s.x,s.y=point,x,y end
	end)
	f:SetScript("OnHide",function() self:CancelConfirm() end)
	backdrop(f)
	label(f,FP.COLOR .. "Hearth & Hustle|r",18,-16,220,"GameFontNormalLarge")
	label(f,"Your journey, at a glance",18,-40,155)
	self.heading = label(f,"",180,-18,600,"GameFontNormalLarge")
	self.subtitle = label(f,"",180,-45,620)
	local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
	close:SetPoint("TOPRIGHT",2,2); close:SetScript("OnClick",function() f:Hide() end)
	if UISpecialFrames then table.insert(UISpecialFrames,"HearthAndHustleHub") end
	self.nav = {}
	for i,section in ipairs(SECTIONS) do
		local key = section[1]
		self.nav[key] = button(f,section[2],16,-78-(i-1)*29,142,function() self:Select(key) end)
	end
	button(f,"Compact panel",16,-532,142,function() FP.Panel:Toggle() end)
	button(f,"Quest map settings",16,-564,142,function() self:Select("display") end)
	label(f,"Drag the title area to move.\nPreferences save automatically.",20,-596,134)
	button(f,"Recenter window",16,-635,142,function()
		s.point,s.x,s.y="CENTER",0,0; f:ClearAllPoints(); f:SetPoint("CENTER"); self:FitWindow()
	end)
	label(f,"Results",180,-530,600,"GameFontNormal")
	self.resultScroll,self.resultChild = scroll(f,180,-550,620,106)
	self.resultText = label(self.resultChild,"Select a feature to get started.",0,0,W)
	self.footer = label(f,"",18,-670,810)
	self:FitWindow()
	f:Hide()
end

function H:Toggle()
	if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end
end

function H:Open(key)
	if not self.frame then self:Create() end
	self.frame:Show()
	self:FitWindow()
	self:Select(key or self.selected or "home")
end

function H:OpenQuestChain(questID)
	self:Open("chains")
	FP.ChainPanel:Inspect(questID,true)
end

function H:Select(key)
	local section
	for _,s in ipairs(SECTIONS) do if s[1]==key then section=s end end
	if not section then return end
	self:CancelConfirm()
	if not self.pages[key] then self:BuildPage(key) end
	if key=="town" then FP.ClassPrep:RequestRefresh() end
	for k,p in pairs(self.pages) do
		if k==key then p.scroll:Show() else
			for _,field in ipairs(p.fields) do field:ClearFocus() end
			p.scroll:Hide()
		end
	end
	for k,b in pairs(self.nav) do if k==key then b:Disable() else b:Enable() end end
	self.selected=key
	if key=="navigation" then FP.Planner:Build() end
	if key=="chains" then FP.QuestChains:StartIndex() end
	self.heading:SetText(section[2]); self.subtitle:SetText(section[3])
	self:Refresh()
	self:SetResults(self.pages[key].results or {"Choose an action above. Its results appear here."})
end

function H:SetResults(lines)
	if not self.frame then return end
	self.resultText:SetText(table.concat(lines,"\n"))
	self.resultChild:SetHeight(math.max(106,self.resultText:GetStringHeight()+12))
	self.resultScroll:SetVerticalScroll(0)
end

function H:Run(title,fn)
	self:CancelConfirm()
	local page=self.pages[self.selected]
	local ok,lines,err=FP:CaptureOutput(fn)
	if not ok then
		FP:ReportError("hub-action",err)
		lines={FP.RED .. "Could not finish:|r " .. tostring(err)}
	elseif #lines==0 then lines={title .. "."} end
	table.insert(lines,1,FP.GOLD .. title .. "|r")
	if page then page.results=lines end
	self:SetResults(lines)
	self:Refresh()
	return ok
end

function H:CancelConfirm()
	if FP.GearPanel and FP.GearPanel.weightsFrame then FP.GearPanel.weightsFrame:Hide() end
	self.pending=nil
	if self.confirmFrame then self.confirmFrame:Hide() end
end

function H:Confirm(title,detail,fn)
	if not self.confirmFrame then
		local f=CreateFrame("Frame",nil,self.frame,"BackdropTemplate")
		self.confirmFrame=f
		f:SetSize(540,150); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true); backdrop(f)
		self.confirmText=label(f,"",16,-16,508,"GameFontHighlight")
		self.confirmYes=button(f,"Confirm",300,-112,100,function()
			local pending=self.pending
			self:CancelConfirm()
			if pending then self:Run(pending.title,pending.fn) end
		end)
		self.confirmNo=button(f,"Cancel",412,-112,110,function() self:CancelConfirm() end)
	end
	self.pending={title=title,fn=fn}
	self.confirmText:SetText(FP.GOLD .. title .. "|r\n\n" .. detail)
	self.confirmFrame:Show()
end

function H:NewPage(key)
	local s,c=scroll(self.frame,180,-82,620,432)
	local p={key=key,scroll=s,body=c,y=0,refreshers={},fields={}}
	self.pages[key]=p
	return p
end

function H:Text(p,text,live)
	local l=label(p.body,text,0,-p.y,W)
	local h=live and 64 or math.max(28,l:GetStringHeight()+10)
	p.y=p.y+h
	if live then table.insert(p.refreshers,function() l:SetText(live()) end) end
	return l
end

function H:HudControls(p,prefix,settings)
	self:Check(p,prefix.."Enabled","Enable this feature",function() return settings.enabled end,function(v) command(prefix.." "..onoff(v)) end)
	self:Text(p,"",function() return "HUD display: " .. (settings.manual or "automatic") .. ". Choose when it appears below." end)
	self:Actions(p,{
		{prefix.."Show","Show HUD",function() command(prefix.." show") end},
		{prefix.."Hide","Hide HUD",function() command(prefix.." hide") end},
		{prefix.."Auto","Automatic",function() command(prefix.." auto") end},
	})
	self:Check(p,prefix.."Lock","Lock HUD position",function() return settings.locked end,function(v) command(prefix.." "..(v and "lock" or "unlock")) end)
	local size=self:Field(p,prefix.."Size","HUD size (50–200%)",function() return math.floor(settings.scale*100+.5) end)
	self:Actions(p,{
		{prefix.."ApplySize","Apply size",function() local n=self:Number(size,"size",50,200,true); if n then command(prefix.." scale "..n/100) end end},
		{prefix.."ResetPosition","Reset HUD position",function() command(prefix.." reset") end},
	})
end

function H:BuildOverview(p)
 self:Text(p,"",function()
  local char=API.GetCharInfo();local wp=FP.Waypoints:GetActive()
  return FP.GOLD..tostring(char.name).." · Level "..tostring(char.level or "?").." "..tostring(char.class or "").."|r\n"..
   (wp and ("Heading to "..wp.title) or "Choose a tool below to plan your next step.")
 end)
 local cards={
  {"navigation","Quest navigation","Automatic objective and event markers. Click a source on the map to guide there.","INV_Misc_Map_01"},
  {"gear","Best in slot","Browse gear, compare equipped items and save a wishlist for your class.","INV_Chest_Chain_04"},
  {"rewards","Compare quest rewards","Choice and guaranteed rewards, vendor values, tooltips and stat differences.","INV_Misc_Gift_01"},
  {"chains","Quest chains","Search quests, inspect prerequisites and guide to known pickup locations.","INV_Misc_Book_09"},
  {"dungeons","Dungeon preparation","Entrance routes, quest checklists and pickup / turn-in guidance.","INV_Misc_Key_03"},
  {"town","Supplies & town","Supplies for every class, personal targets, vendor and trainer information.","INV_Misc_Bag_08"},
 }
 for i,card in ipairs(cards) do
  local key=card[1];local x=((i-1)%2)*304;local y=p.y+math.floor((i-1)/2)*108
  local b=CreateFrame("Button",nil,p.body,"BackdropTemplate")
  b:SetSize(294,98);b:SetPoint("TOPLEFT",x,-y);backdrop(b,.8)
  local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(28,28);icon:SetPoint("TOPLEFT",12,-12);icon:SetTexture("Interface\\Icons\\"..card[4])
  label(b,FP.GOLD..card[2].."|r",48,-14,234,"GameFontNormal")
  label(b,card[3],12,-46,270)
  local hl=b:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(.2,.6,.8,.12)
  b:SetScript("OnClick",function() self:Select(key) end);self.controls["home_"..key]=b
 end
 p.y=p.y+324
 self:Text(p,"Quest maps work automatically. Use Display for source markers, event hints and overlay settings; the remaining tools are always in the sidebar.")
end

function H:BuildPage(key)
	local p=self:NewPage(key)
	if key=="home" then
		self:BuildOverview(p)
	elseif key=="gear" then
		FP.GearPanel:Build(self,p)
	elseif key=="dungeons" then
		self:Text(p,"Choose a dungeon to prepare quests and guide to its entrance. Inspecting the checklist does not change your route.")
		local list=self:List(p,"hubDungeons",function() return FP.Dungeons:List() end,function(row) return row.data.name.." · "..tostring(row.data.recommendedLevel or "Level unknown") end)
		self:Actions(p,{{"openDungeonChecklist","Open quest checklist",function() local row=self:Selected(list);self.frame:Hide();FP.DungeonPanel:Open(row and row.key) end}})
		self:Text(p,"Entrance routes and quest pickup / objective / turn-in guidance are available inside the checklist. Interior paths and boss order are not mapped.")
	elseif key=="locations" then
		FP.QuestLocationPanel:Build(self,p)
	elseif key=="rewards" then
		FP.RewardPanel:Build(self,p)
	elseif key=="chains" then
		FP.ChainPanel:Build(self,p)
	elseif key=="navigation" then
		self:Text(p,"",function()
			local wp=FP.Waypoints:GetActive()
			return (wp and ("Current: "..U.Truncate(wp.title,85)) or "No active destination.") .. ((wp and (not wp.source or wp.source.type~="plan")) and "\nManual destination holds guidance. Resume guidance to return to quests; saved destinations are kept." or "") .. "\nAutomatic selection: " .. (FP.settings.autoNext and not FP.Planner.paused and "on" or "paused/off")
		end)
		self:Actions(p,{
			{"resume","Resume guidance",function() FP.Waypoints:SuspendManual();command("auto on"); FP.settings.arrow.shown=true; FP.Arrow:Refresh() end},
			{"pause","Pause selection",function() FP.Planner.paused=true;FP:Fire("WAYPOINTS_CHANGED");FP:Print("Guidance paused for this session.") end},
			{"nextStep","Next suggestion",function() command("next") end},
		})
		self:Text(p,"Pause keeps your current destination. Clear route removes destinations and pauses guidance.")
		self:Actions(p,{
			{"pickups","Find available pickups",function() command("pickups") end},
			{"clearRoute","Clear route",function() FP.Waypoints:Clear() end,confirm="Remove all saved waypoints and pause guidance? Your quests stay in your quest log."},
		})
		self:Actions(p,{{"recoverGuide","Restore arrow and compact panel",function() command("guide") end}})
		self:Section(p,"Quest locations")
		self:Actions(p,{{"browseQuestLocations","Browse quest targets and locations",function()FP.QuestLocationPanel:Open() end}})
		self:Text(p,"",function() return FP.QuestObjectives:Summary() end)
		self:Text(p,"Quest colors and numbers match the map legend and this list. Sword: kill; bag: loot; gear: interact; spyglass: event; ! pickup; ? turn-in. Click a legend quest to focus it, right-click to hide it, or Show all to restore everything. A white + marks shared locations. Hover for progress; click a marker to guide. Some objectives still lack known sources.")
		self:Section(p,"Quest destinations")
		local search=self:Field(p,"questSearch","Find a quest","")
		local list=self:List(p,"quests",function()
			local out,query={},U.Trim(search:GetText() or ""):lower()
			for _,s in ipairs(FP.Planner.steps or {}) do
				if query=="" or tostring(s.title):lower():find(query,1,true) or tostring(s.text):lower():find(query,1,true) then
					out[#out+1]={key=tostring(s.questID)..":"..tostring(s.kind)..":"..tostring(s.objIndex),step=s}
				end
			end
			return out
		end,function(item) local s=item.step; return (s.deferred and "[Deferred] " or "")..(s.questID and FP.QuestObjectives:QuestLabel(s.questID,s.title) or tostring(s.title)).." — "..tostring(s.text or s.kind) end)
		search:SetScript("OnTextChanged",function() list.page=1; self:Refresh() end)
		self:Actions(p,{
			{"goQuest","Guide to selected quest",function()
				local item=self:Selected(list); if not item then return end
				if item.step.kind=="hearth" then FP:Print("Use your Hearthstone to "..tostring(item.step.title))
				elseif FP.Planner:Go(item.step) then FP:Print("Heading to "..item.step.title)
				else FP:Print("No coordinates available yet. Check the quest directions.") end
			end,enabled=function() return self:Selected(list)~=nil end},
			{"refreshQuests","Refresh quest list",function() FP.Planner:Build() end},
			{"viewQuestChain","View quest chain",function() local item=self:Selected(list);if item then self:OpenQuestChain(item.step.questID) end end,
				enabled=function()local item=self:Selected(list);return item and item.step.questID~=nil end},
		})
		self:Section(p,"A crowded quest?")
		local mins=self:Field(p,"skipMinutes","Defer current quest (minutes)",10)
		self:Actions(p,{
			{"skipQuest","Defer current quest",function() local n=self:Number(mins,"minutes",1,60,true); if n then command("skip "..n) end end},
			{"restoreQuests","Restore deferred quests",function() command("skip clear") end},
		})
	elseif key=="waypoints" then
		local list=self:List(p,"waypointList",function()
			local out={}; for _,wp in ipairs(FP.Waypoints.list) do out[#out+1]={key=wp.id,wp=wp} end; return out
		end,function(item) return FP.Waypoints:Describe(item.wp) end)
		self:Actions(p,{
			{"activateWaypoint","Make active",function() local item=self:Selected(list); if item then FP.Waypoints:SetActive(item.wp.id) end end,enabled=function() return self:Selected(list)~=nil end},
			{"removeWaypoint","Remove selected",function()
				local item=self:Selected(list); if not item then return end
				if item.wp.source and item.wp.source.type=="plan" then FP:Fire("NAV_CANCELLED") end
				FP.Waypoints:Remove(item.wp.id); FP:Print("Removed "..item.wp.title)
			end,enabled=function() return self:Selected(list)~=nil end},
			{"cycleWaypoint","Next waypoint",function() command("way next") end},
		})
		self:Text(p,"Removing a planned destination pauses selection so it will not immediately return.")
		self:Section(p,"Add a destination")
		local name=self:Field(p,"waypointName","Name (optional)","")
		local x=self:Field(p,"waypointX","X coordinate (0–100%)","")
		local y=self:Field(p,"waypointY","Y coordinate (0–100%)","")
		local map=self:Field(p,"waypointMap","Map ID (blank = current map)","")
		self:Actions(p,{
			{"addWaypoint","Add coordinates",function()
				local px=self:Number(x,"X coordinate",0,100); if not px then return end
				local py=self:Number(y,"Y coordinate",0,100); if not py then return end
				local id=API.GetBestMap()
				if U.Trim(map:GetText())~="" then id=self:Number(map,"map ID",1,100000,true); if not id then return end end
				if not U.ValidMapPoint(id,px/100,py/100) then FP:Print("Current map unavailable. Enter a map ID or try outdoors."); return end
				local title=U.Trim(name:GetText()); if title=="" then title=API.GetMapName(id).." "..U.FormatCoords(px/100,py/100) end
				FP.Waypoints:Add(id,px/100,py/100,title); FP:Print("Added "..title)
			end},
			{"saveHere","Save current location",function() command("way here "..U.Trim(name:GetText())) end},
		})
	elseif key=="professions" then
		self:Text(p,"Open your profession window once to load learned recipes. This plans materials; you choose what to craft.")
		self:Text(p,"",function() return FP.Prof:Summary() end)
		local list=self:List(p,"recipeList",function()
			local out={}; local open=FP.Prof.open
			if open and not open.stale then
				for _,e in ipairs(open.recipes) do if not e.rec.disabled then out[#out+1]={key=e.id,recipe=e} end end
			end
			table.sort(out,function(a,b) return tostring(a.recipe.name)<tostring(b.recipe.name) end); return out
		end,function(item) return tostring(item.recipe.name) end)
		local crafts=self:Field(p,"craftCount","Number of crafts",1)
		self:Actions(p,{
			{"planCraft","Plan selected recipe",function()
				local n=self:Number(crafts,"craft count",1,200,true); local item=self:Selected(list)
				if n and item then command("prof plan "..item.key.." "..n) end
			end,enabled=function() return self:Selected(list)~=nil end},
			{"craftMaterials","Show materials",function() local lines=FP.Prof:PlanLines(); if #lines==0 then FP:Print("Select a recipe and create a batch plan first.") else for _,l in ipairs(lines) do FP:Print(l) end end end},
			{"clearCraft","Clear batch plan",function() command("prof plan clear") end},
		})
		self:Actions(p,{{"skillCrafts","Skill-up suggestions",function() command("prof") end}})
	elseif key=="party" then
		self:Text(p,"",function() return FP.Party:Summary() end)
		self:Text(p,"Quest comparisons use your partner's last snapshot. Confirm readiness with them before leaving.")
		self:Actions(p,{
			{"duo","Compare quest progress",function() command("duo") end},
			{"partySync","Send my quest snapshot",function() command("partysync") end},
		})
		self:Section(p,"Copy or paste a party snapshot")
		local code=self:Field(p,"partyCode","Snapshot text","")
		self:Actions(p,{
			{"partyCopy","Create copyable snapshot",function() code:SetText(FP.Party:ExportString()); code:HighlightText(); code:SetFocus(); FP:Print("Press Ctrl-C to copy the selected text. Share it with your partner.") end},
			{"partyImport","Import pasted snapshot",function() command("partyimport "..U.Trim(code:GetText())) end},
		})
	elseif key=="town" then
		self:Section(p,"Class supplies")
		self:Check(p,"prepEnabled","Enable preparation checklist",function() return FP.cdb.prep.enabled end,function(v) command("prep "..onoff(v)) end)
		self:Text(p,"",function() return FP.ClassPrep:ClassLabel().." supplies. Overlay: "..FP.cdb.prep.mode..". Carried counts are also shown below, independently of the PvP HUD." end)
		self:List(p,"supplySummary",function()
			if API.InCombat() or FP.ClassPrep.combat then return {{key="status",text="Supply checks resume after combat."}} end
			if not FP.cdb.prep.enabled then return {{key="status",text="Preparation checklist disabled."}} end
			local rows={}
			for i,row in ipairs(FP.ClassPrep.rows or {{text="Reading bag supplies…"}}) do rows[#rows+1]={key=row.key or i,text=row.text} end
			return rows
		end,function(row)return row.text end)
		self:Actions(p,{
			{"prepShow","Show checklist",function() command("prep show") end},
			{"prepAuto","Automatic checklist",function() command("prep auto") end},
			{"prepHide","Hide checklist",function() command("prep hide") end},
		})
		for _,entry in ipairs({{"food","Food target"},{"water","Drink target (mana classes)"},{"bandages","Bandage target"},{"reagents","Mage reagent target"}}) do
			local key,name=entry[1],entry[2]
			if key~="reagents" or API.GetCharInfo().class=="MAGE" then
			local field=self:Field(p,"prep"..key,name,function() return FP.cdb.prep[key] end)
			self:Actions(p,{{"applyPrep"..key,"Save "..name:lower(),function() local n=self:Number(field,name,0,200,true); if n then command("prep "..key.." "..n) end end}})
			end
		end
		self:Actions(p,{{"prepReport","Check carried supplies",function() command("prep") end}})
		self:Section(p,"Personal supplies")
		self:Text(p,"Choose a carried or tracked item below, or paste an item link/ID. Set a target to track reagents, poisons, pet supplies or other items for this character. These are your stocking targets; they do not claim the item is required or usable.")
		local item=self:Field(p,"supplyItem","Item link or ID","")
		local target=self:Field(p,"supplyTarget","Carried target (0 removes)",5)
		self:Actions(p,{{"saveSupply","Save personal supply",function()
			local n=self:Number(target,"target",0,200,true)
			if n then local _,message=FP.ClassPrep:SetSupply(U.Trim(item:GetText()),n);FP:Print(message) end
		end}})
		local supplies=self:List(p,"personalSupplies",function() return FP.ClassPrep:Supplies(true) end,function(row)
			return row.name.." (#"..row.id..") — "..(row.count~=nil and row.count.." carried" or "count unavailable")..(row.goal>0 and " / target "..row.goal or "")
		end)
		for _,button in ipairs(supplies.rows) do
			button:SetScript("OnClick",function(btn)
				if btn.item then
					supplies.selected=btn.item.key;item:SetText(tostring(btn.item.id));target:SetText(tostring(btn.item.goal>0 and btn.item.goal or 5));self:Refresh()
				end
			end)
		end
		self:Actions(p,{{"removeSupply","Stop tracking selected item",function()
			local row=self:Selected(supplies)
			if row then local _,message=FP.ClassPrep:SetSupply(row.id,0);FP:Print(message) end
		end,enabled=function() local row=self:Selected(supplies);return row and row.goal>0 end}})
		self:Section(p,"Vendor helper")
		for _,entry in ipairs({{"enabled","Show vendor helper",""},{"tooltipPrice","Vendor values in tooltips","tooltip "},{"rewardValues","Vendor values on quest rewards","rewards "}}) do
			local key,text,sub=entry[1],entry[2],entry[3]
			self:Check(p,"vendor"..key,text,function() return FP.settings.vendor[key] end,function(v) command("vendor "..sub..onoff(v)); if sub=="" and v then FP.Vendor:OnMerchant(FP.Vendor.merchant) end end)
		end
		self:Text(p,"Selling and repairs stay on the merchant window, where prices and items are visible before you click.")
		self:Actions(p,{{"junkValue","Review gray-item values",function() command("vendor junk") end}})
		self:Section(p,"Reminders")
		self:Check(p,"remindersEnabled","Enable out-of-combat reminders",function() return FP.settings.reminders.enabled end,function(v) command("remind "..onoff(v)) end)
		self:Check(p,"remindersBuffs","Include missing self-buffs",function() return FP.settings.reminders.buffs end,function(v) command("remind buffs "..onoff(v)) end)
		local dura=self:Field(p,"durabilityThreshold","Durability threshold (0–90%)",function() return FP.settings.reminders.durability end)
		local ammo=self:Field(p,"ammoThreshold","Ammo threshold (0–5000)",function() return FP.settings.reminders.ammo end)
		self:Actions(p,{{"applyReminders","Save reminder thresholds",function()
			local a=self:Number(dura,"durability",0,90,true); local b=self:Number(ammo,"ammo",0,5000,true)
			if a and b then command("remind durability "..a); command("remind ammo "..b) end
		end}})
		self:Section(p,"Trainer notes")
		self:Check(p,"trainerEnabled","Enable trainer notes",function() return FP.settings.trainer.enabled end,function(v) command("trainer "..onoff(v)) end)
		local lvl=self:Field(p,"trainerLevel","Look ahead to level",(API.PlayerLevel() or 1)+1)
		self:Actions(p,{{"trainerLookup","Show recorded training",function() local n=self:Number(lvl,"level",1,100,true); if n then command("trainer "..n) end end}})
	elseif key=="pvp" then
		self:Text(p,"Timers are estimates from your own actions. Battleground flag numbers identify map slots, not enemy teams.")
		self:HudControls(p,"pvp",FP.settings.pvp)
		self:Section(p,"Battleground navigation")
		local flag=self:Field(p,"flagIndex","Flag map slot (1–10)",function() return FP.settings.pvp.flagIndex or 1 end)
		self:Actions(p,{
			{"trackFlag","Track flag slot",function() local n=self:Number(flag,"flag slot",1,10,true); if n then command("pvp track "..n) end end},
			{"untrackFlag","Stop flag tracking",function() command("pvp track off") end},
		})
		self:Actions(p,{
			{"pvpReport","Current PvP status",function() command("pvp status") end},
			{"pvpSpells","Supported spell timers",function() command("pvp spells") end},
		})
		self:Actions(p,{{"pvpClear","Clear session timers / roster",function() command("pvp clear") end,confirm="Clear the current PvP timers and session roster? This does not change your quests or waypoint route."}})
		if FP.EnemyWatch then
			local EW,set=FP.EnemyWatch,FP.settings.enemyWatch
			self:Section(p,"Enemy watch (open world)")
			self:Text(p,"",function() local st=EW:Status(); return U.Trim(st[2] or st[1]).."\n"..U.Trim(st[3] or "") end)
			self:Check(p,"enemyWatchEnabled","Watch for enemy players near me",function() return set.enabled end,function(v) command("enemies "..onoff(v)) end)
			self:Check(p,"enemyWatchAlerts","Alert in chat and on screen",function() return set.alerts end,function(v) command("enemies alerts "..onoff(v)) end)
			self:Check(p,"enemyWatchSound","Play alert sounds",function() return set.sound end,function(v) command("enemies sound "..onoff(v)) end)
			self:Check(p,"enemyWatchStealth","Alert when a visible enemy uses Stealth, Vanish, Prowl or Shadowmeld",function() return set.stealth end,function(v) command("enemies stealth "..onoff(v)) end)
			self:Check(p,"enemyWatchShare","Share sightings with my party",function() return set.share end,function(v) command("enemies share "..onoff(v)) end)
			self:Text(p,"It sees a player whose nameplate is on screen, or one you target, focus or mouse over. It cannot see stealthed players or anyone out of nameplate range.")
			self:Actions(p,{
				{"enemyNameplates","Turn on enemy nameplates",function() command("enemies nameplates") end,enabled=function() local _,ok=EW:NameplateLine(); return not ok end},
				{"enemyList","Nearby enemies",function() command("enemies list") end},
				{"enemyStats","Recent enemies and record",function() command("enemies stats 15") end},
			})
			self:Section(p,"Kill On Sight")
			local kos=self:List(p,"kosList",function()
				local out={}; for _,name in ipairs(EW:SortedNames(FP.db.enemyWatch.kos)) do out[#out+1]={key=name,name=name,reason=FP.db.enemyWatch.kos[name].reason} end; return out
			end,function(item) return item.name .. (item.reason and ("  —  "..item.reason) or "") end,{count=5})
			self:Actions(p,{{"kosRemove","Remove selected",function() local item=self:Selected(kos); if item then command("kos -"..item.name); kos.selected=nil end end,enabled=function() return self:Selected(kos)~=nil end}})
			local kosName=self:Field(p,"kosName","Player name (blank = my target)","")
			local kosReason=self:Field(p,"kosReason","Reason (optional)","")
			self:Actions(p,{{"kosAdd","Add to Kill On Sight",function()
				local name,reason=U.Trim((kosName:GetText():gsub(":",""))),U.Trim(kosReason:GetText())
				command("kos +"..name..(reason~="" and (": "..reason) or ""))
			end}})
			self:Section(p,"Ignored enemies")
			local ignored=self:List(p,"ignoreList",function()
				local out={}; for _,name in ipairs(EW:SortedNames(FP.db.enemyWatch.ignore)) do out[#out+1]={key=name,name=name} end; return out
			end,function(item) return item.name end,{count=4})
			local ignoreName=self:Field(p,"ignoreName","Player name (blank = my target)","")
			self:Actions(p,{
				{"ignoreAdd","Ignore",function() command("ignore +"..U.Trim(ignoreName:GetText())) end},
				{"ignoreRemove","Stop ignoring selected",function() local item=self:Selected(ignored); if item then command("ignore -"..item.name); ignored.selected=nil end end,enabled=function() return self:Selected(ignored)~=nil end},
			})
		end
	elseif key=="rare" then
		self:Text(p,"",function() local status=FP.RareWatch:StatusLines(); return status end)
		self:HudControls(p,"rare",FP.settings.rare)
		self:Check(p,"rareShare","Share rare sightings with party",function() return FP.settings.rare.share end,function(v) command("rare share "..onoff(v)) end)
		self:Check(p,"rareSound","Play rare alert sounds",function() return FP.settings.rare.sound end,function(v) command("rare sound "..onoff(v)) end)
		self:Actions(p,{
			{"rareScan","Open HUD for Scan",function()
				command("rare on"); command("rare show")
				FP:Print("Use the Scan button on the rare HUD inside the watched instance. Each click checks one target; it only finds creatures loaded by your client.")
				if FP.RareWatch.inside then self.frame:Hide() end
			end},
			{"rareStatus","Run details",function() command("rare status") end},
			{"rareRuns","Recent runs",function() command("rare runs") end},
		})
		self:Actions(p,{
			{"rareAbsent","Mark not up",function() command("rare notup") end,confirm="Mark this run's rare as not up? This is your observation, not a guaranteed full-instance scan."},
			{"rareNewRun","Start new run record",function() command("rare newrun") end,confirm="Close the current rare-watch record and open a new one? This does not reset the game instance."},
		})
		self:Section(p,"Watch list")
		local instance=self:Field(p,"rareInstance","Instance name",function() return FP.RareWatch:Watch().instance end)
		self:Actions(p,{{"rareSetInstance","Set watched instance",function()
			local name=U.Trim(instance:GetText()); if name=="" then FP:Print("Enter an instance name."); return end
			command("rare instance "..name)
		end}})
		local list=self:List(p,"rareList",function()
			local out={}; for i,r in ipairs(FP.RareWatch:Watch().rares) do out[#out+1]={key=tostring(r.id or "")..":"..r.name,rare=r} end; return out
		end,function(item) return item.rare.name .. (item.rare.id and ("  ("..item.rare.id..")") or "") end)
		self:Actions(p,{{"rareRemove","Remove selected rare",function() local item=self:Selected(list); if item then command("rare rm "..item.rare.name); list.selected=nil end end,enabled=function() return self:Selected(list)~=nil end}})
		local name=self:Field(p,"rareName","Exact rare name","")
		local id=self:Field(p,"rareID","Creature ID (optional)","")
		self:Actions(p,{{"rareAdd","Add rare to watch list",function()
			local text=U.Trim(name:GetText()); if text=="" then FP:Print("Enter the rare's exact name."); return end
			local num=""; if U.Trim(id:GetText())~="" then num=self:Number(id,"creature ID",1,10000000,true); if not num then return end; num=num.." " end
			command("rare add "..num..text)
		end}})
	elseif key=="display" then
		self:Section(p,"Action bars")
		self:Check(p,"barGuardEnabled","Put back action buttons that vanish at login, spec change or level-up",function() return FP.settings.barGuard.enabled end,function(v) command("bars "..onoff(v)) end)
		self:Check(p,"barGuardNotice","Tell me in chat when buttons were put back",function() return FP.settings.barGuard.announce end,function(v) command("bars notice "..onoff(v)) end)
		self:Text(p,"Fills empty slots only, never in combat, and never uses an ability. Your own edits are remembered as you make them.")
		self:Section(p,"Quest items")
		self:Check(p,"questSparkleEnabled","Keep the game's sparkle on quest items you can pick up",function() return FP.settings.questSparkle.enabled end,function(v) command("sparkle "..onoff(v)) end)
		self:Text(p,"Keeps one graphics setting of the game switched on, also after a graphics preset resets it. The game draws the sparkle and decides what gets one. Switching it off takes effect after a full game restart.")
		self:Section(p,"Map pins and arrow")
		for _,entry in ipairs({{"worldMapPins","World-map pins"},{"minimapPin","Minimap pin"}}) do
			local key,text=entry[1],entry[2]
			self:Check(p,"display"..key,text,function() return FP.settings[key] end,function(v) FP.settings[key]=v; FP.Panel:ApplyDisplaySettings() end)
		end
		for _,entry in ipairs({{"questWorldPins","Quest source locations on world map"},{"questMinimapPins","Nearby quest sources on minimap"},{"questSelectedOnly","Only show sources for the selected quest"},{"questEventHints","Show quest hints (separate from objective progress)"},{"questContactPins","Show confirmed pickups and known turn-ins"},{"questMapLegend","Show clickable quest legend on world map"},{"questDensePins","Dense world-map markers (350 instead of 150)"}}) do
			local key,text=entry[1],entry[2]
			self:Check(p,"display"..key,text,function() return FP.settings[key] end,function(v) FP.settings[key]=v; FP.Panel:ApplyDisplaySettings() end)
		end
		for _,entry in ipairs({{"shown","Show navigation arrow"},{"locked","Lock arrow position"},{"flip","Reverse arrow rotation"}}) do
			local key,text=entry[1],entry[2]
			self:Check(p,"arrow"..key,text,function() return FP.settings.arrow[key] end,function(v) FP.settings.arrow[key]=v; FP.Panel:ApplyDisplaySettings() end)
		end
		self:Text(p,"Unlock to drag the arrow. Reverse rotation only if it points the wrong way. Hiding displays keeps your route active.")
		for _,entry in ipairs({{"arrow","Arrow",40,300},{"panel","Compact quest panel",50,200},{"bar","Status line",50,200}}) do
			local key,title,min,max=entry[1],entry[2],entry[3],entry[4]
			local s=FP.settings[key]
			if key~="arrow" then
				self:Section(p,title)
				self:Check(p,key.."Shown","Show "..title:lower(),function() return s.shown end,function(v) if key=="panel" then FP.Panel:Toggle(v) else FP.InfoBar:Toggle(v) end end)
				self:Check(p,key.."Locked","Lock position",function() return s.locked end,function(v) command(key.." "..(v and "lock" or "unlock")) end)
			end
			local size=self:Field(p,key.."Scale",title.." size (%)",function() return math.floor(s.scale*100+.5) end)
			self:Actions(p,{
				{key.."ApplyScale","Apply size",function() local n=self:Number(size,"size",min,max,true); if n then command(key.." scale "..n/100) end end},
				{key.."Reset","Reset position & size",function() command(key.." reset"); size:SetText(tostring(math.floor(s.scale*100+.5))) end},
			})
		end
		self:Check(p,"barFPS","Show FPS and latency",function() return FP.settings.bar.fps end,function(v) command("bar fps "..onoff(v)) end)
	elseif key=="tools" then
		self:Text(p,"",function() return "Recorded: "..FP.Recorder:Summary().."\nStored errors: "..#(FP.db.errors or {}) end)
		self:Check(p,"recording","Record observations",function() return FP.settings.record end,function(v) command("record "..onoff(v)) end)
		self:Check(p,"debugging","Debug messages",function() return FP.settings.debug end,function(v) if FP.settings.debug~=v then command("debug") end end)
		self:Check(p,"probing","Enable API probes",function() return FP.settings.probe.enabled end,function(v) command("probe "..onoff(v)) end)
		self:Actions(p,{
			{"statusReport","Addon status",function() command("status") end},
			{"apiCheck","Check APIs",function() command("apicheck") end},
			{"selfTest","Run self-test",function() command("selftest") end},
		})
		self:Actions(p,{
			{"probeNow","Sample APIs now",function() command("probe now") end},
			{"probeDump","Recent probe samples",function() command("probe dump") end},
			{"exportInfo","Recorded-data location",function() command("export") end},
		})
		self:Actions(p,{{"errorReport","View stored errors",function()
			local errors=FP.db.errors or {}; if #errors==0 then FP:Print("No errors stored.") end
			for _,e in ipairs(errors) do FP:Print(tostring(e.where)..": "..tostring(e.err)) end
		end}})
		self:Section(p,"Data management")
		self:Text(p,"These actions remove saved information. Each requires a separate confirmation.")
		self:Actions(p,{{"resetRareHistory","Clear rare-run history",function() command("rare clear confirm") end,confirm="Permanently delete all recorded rare-watch runs? The watch list is kept."}})
		self:Actions(p,{{"resetCharacter","Reset character data",function() command("reset char confirm") end,confirm="Remove this character's saved waypoints, profession state, party snapshot and other character data on your next reload?"}})
		self:Actions(p,{{"resetAccount","Reset account data & settings",function() command("reset data confirm") end,confirm="Remove the account's recorded dataset AND account-wide settings on your next reload? This affects every character using Hearth & Hustle."}})
	end
	p.body:SetHeight(math.max(432,p.y+12))
end

function H:Section(p,text)
	p.y=p.y+10; label(p.body,text,0,-p.y,W,"GameFontNormal"); p.y=p.y+28
end

function H:Actions(p,defs)
	local width=(W-(#defs-1)*8)/#defs
	for i,d in ipairs(defs) do
		local b=button(p.body,d[2],(i-1)*(width+8),-p.y,width,function()
			if d.confirm then self:Confirm(d[2],d.confirm,d[3]) else self:Run(d[2],d[3]) end
		end)
		self.controls[d[1]]=b
		if d.enabled then table.insert(p.refreshers,function() if d.enabled() then b:Enable() else b:Disable() end end) end
	end
	p.y=p.y+34
end

function H:Check(p,id,text,get,set)
	local b=CreateFrame("CheckButton",nil,p.body,"UICheckButtonTemplate")
	b:SetSize(24,24); b:SetPoint("TOPLEFT",0,-p.y); b:SetHitRectInsets(0,-(W-24),0,0)
	label(b,text,30,-5,W-36,"GameFontHighlight")
	b:SetScript("OnClick",function(btn) self:Run(text,function() set(btn:GetChecked()==true) end) end)
	self.controls[id]=b
	table.insert(p.refreshers,function() b:SetChecked(get()==true) end)
	p.y=p.y+29
	return b
end

function H:Field(p,id,text,value,width)
	label(p.body,text,0,-p.y-7,246)
	local e=CreateFrame("EditBox",nil,p.body,"InputBoxTemplate")
	e:SetSize(width or 334,24); e:SetPoint("TOPLEFT",260,-p.y); e:SetAutoFocus(false)
	local get=type(value)=="function" and value or nil
 e:SetMaxLetters(4096);e:SetText(tostring(get and get() or value or ""));e:ClearFocus()
 if get then
  local last=e:GetText()
  table.insert(p.refreshers,function()
   local current=tostring(get() or "")
   if not e:HasFocus() and (e:GetText()==last or e:GetText()==current) then e:SetText(current);last=current end
  end)
 end
	e:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
	e:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
	self.controls[id]=e; p.fields[#p.fields+1]=e
	p.y=p.y+34
	return e
end

function H:Number(field,name,min,max,integer)
	local n=tonumber(field:GetText())
	if not U.Finite(n) or n<min or n>max or (integer and n~=math.floor(n)) then
		FP:Print("Enter " .. name .. " from " .. min .. " to " .. max .. (integer and " (whole numbers)." or "."))
		return nil
	end
	return n
end

function H:List(p,id,get,describe,options)
	options=options or {}
	local width,count=options.width or W,options.count or 7
	local list={page=1,rows={},get=get,describe=describe}
	self.controls[id]=list
	for i=1,count do
		local row=button(p.body,"",0,-p.y,width,function() end)
		row:SetSize(width,26)
		row:SetScript("OnClick",function(btn) if btn.item then list.selected=btn.item.key; self:Refresh() end end)
		row:SetScript("OnEnter",function(btn)
			if not btn.item then return end
			GameTooltip:SetOwner(btn,"ANCHOR_RIGHT"); GameTooltip:AddLine(describe(btn.item),1,1,1,true); GameTooltip:Show()
		end)
		row:SetScript("OnLeave",function(btn) if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end end)
		list.rows[i]=row; p.y=p.y+29
	end
	list.caption=label(p.body,"",options.width and 64 or 160,-p.y-6,options.width and 160 or 280)
	list.prev=button(p.body,"Previous",0,-p.y,options.width and 62 or 130,function() list.page=math.max(1,list.page-1); self:Refresh() end)
	list.next=button(p.body,"Next",width-(options.width and 62 or 130),-p.y,options.width and 62 or 130,function() list.page=list.page+1; self:Refresh() end)
	p.y=p.y+36
	table.insert(p.refreshers,function()
		list.items=get() or {}
		local pages=math.max(1,math.ceil(#list.items/count))
		list.page=math.min(list.page,pages)
		list.caption:SetText(#list.items .. " items  ·  " .. list.page .. " / " .. pages)
		if list.page>1 then list.prev:Enable() else list.prev:Disable() end
		if list.page<pages then list.next:Enable() else list.next:Disable() end
		for i,b in ipairs(list.rows) do
			b.item=list.items[(list.page-1)*count+i]
			if b.item then
				b:SetText((list.selected==b.item.key and FP.GOLD .. "> " or "") .. U.Truncate(describe(b.item),options.width and 36 or 82) .. "|r"); b:Show()
			else b:Hide() end
		end
	end)
	return list
end

function H:Selected(list)
	for _,item in ipairs(list.items or {}) do if item.key==list.selected then return item end end
end

function H:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	local p=self.pages[self.selected]
	if not p then return end
	for _,fn in ipairs(p.refreshers) do fn() end
	local wp=FP.Waypoints:GetActive()
	self.footer:SetText("v" .. FP.version .. "   ·   " .. (wp and ("Heading to " .. U.Truncate(wp.title,75)) or "No active destination"))
end

function H:OnEnable()
	local function refresh()
		if self.frame and self.frame:IsShown() then
			FP.Throttle("hub-refresh",.2,function() self:Refresh() end)
		end
	end
	for _,event in ipairs({"WAYPOINTS_CHANGED","PLAN_UPDATED","PROFESSIONS_CHANGED","RECIPES_SCANNED","PARTY_UPDATED","PVP_CHANGED","RARE_CHANGED","DISPLAY_SETTINGS_CHANGED","QUEST_CHAINS_CHANGED"}) do FP:On(event,refresh) end
	FP:RegisterEvent("PLAYER_REGEN_ENABLED",refresh)
	FP:RegisterEvent("PLAYER_REGEN_DISABLED",refresh)
	FP:RegisterEvent("UI_SCALE_CHANGED",function() self:FitWindow() end)
	FP:RegisterEvent("DISPLAY_SIZE_CHANGED",function() self:FitWindow() end)
end
