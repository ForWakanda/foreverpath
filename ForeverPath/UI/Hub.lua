-- ForeverPath / UI / Hub.lua
-- Click-driven home for existing features. Browsing is read-only; actions use
-- the same guarded modules as slash commands, with results kept in the window.
local _, FP = ...
local U, API = FP.Util, FP.API
local H = FP:NewModule("Hub")
local W = 600
local SECTIONS = {
	{"navigation", "Navigation", "Choose your next quest or resume your route."},
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
	local f = CreateFrame("Frame","ForeverPathHub",UIParent,"BackdropTemplate")
	self.frame = f
	local s=FP.settings.hub
	f:SetSize(860,690); f:SetPoint(s.point,UIParent,s.point,s.x,s.y); f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart",function(frame) frame:StartMoving() end)
	f:SetScript("OnDragStop",function(frame)
		frame:StopMovingOrSizing()
		local point,_,_,x,y=frame:GetPoint(1)
		if point then s.point,s.x,s.y=point,x,y end
	end)
	f:SetScript("OnHide",function() self:CancelConfirm() end)
	backdrop(f)
	label(f,FP.COLOR .. "ForeverPath|r",18,-16,220,"GameFontNormalLarge")
	label(f,"Your journey, at a glance",18,-40,155)
	self.heading = label(f,"",180,-18,600,"GameFontNormalLarge")
	self.subtitle = label(f,"",180,-45,620)
	local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
	close:SetPoint("TOPRIGHT",2,2); close:SetScript("OnClick",function() f:Hide() end)
	if UISpecialFrames then table.insert(UISpecialFrames,"ForeverPathHub") end
	self.nav = {}
	for i,section in ipairs(SECTIONS) do
		local key = section[1]
		self.nav[key] = button(f,section[2],16,-82-(i-1)*34,142,function() self:Select(key) end)
	end
	button(f,"Compact panel",16,-415,142,function() FP.Panel:Toggle() end)
	button(f,"Dungeon quests",16,-447,142,function() f:Hide(); FP.DungeonPanel:Open() end)
	label(f,"Choose a section.\nChanges save automatically.\n\nDrag the title area to move this window.",20,-493,134)
	button(f,"Recenter window",16,-620,142,function()
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
	self:Select(key or self.selected or "navigation")
end

function H:Select(key)
	local section
	for _,s in ipairs(SECTIONS) do if s[1]==key then section=s end end
	if not section then return end
	self:CancelConfirm()
	if not self.pages[key] then self:BuildPage(key) end
	for k,p in pairs(self.pages) do
		if k==key then p.scroll:Show() else
			for _,field in ipairs(p.fields) do field:ClearFocus() end
			p.scroll:Hide()
		end
	end
	for k,b in pairs(self.nav) do if k==key then b:Disable() else b:Enable() end end
	self.selected=key
	if key=="navigation" then FP.Planner:Build() end
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
	local size=self:Field(p,prefix.."Size","HUD size (50–200%)",math.floor(settings.scale*100+.5))
	self:Actions(p,{
		{prefix.."ApplySize","Apply size",function() local n=self:Number(size,"size",50,200,true); if n then command(prefix.." scale "..n/100) end end},
		{prefix.."ResetPosition","Reset HUD position",function() command(prefix.." reset") end},
	})
end

function H:BuildPage(key)
	local p=self:NewPage(key)
	if key=="navigation" then
		self:Text(p,"",function()
			local wp=FP.Waypoints:GetActive()
			return (wp and ("Current: "..U.Truncate(wp.title,85)) or "No active destination.") .. "\nAutomatic selection: " .. (FP.settings.autoNext and not FP.Planner.paused and "on" or "paused/off")
		end)
		self:Actions(p,{
			{"resume","Resume guidance",function() command("auto on"); FP.settings.arrow.shown=true; FP.Arrow:Refresh() end},
			{"pause","Pause selection",function() command("auto off") end},
			{"nextStep","Next suggestion",function() command("next") end},
		})
		self:Text(p,"Pause keeps your current destination. Clear route removes destinations and pauses guidance.")
		self:Actions(p,{
			{"pickups","Find available pickups",function() command("pickups") end},
			{"clearRoute","Clear route",function() FP.Waypoints:Clear() end,confirm="Remove all saved waypoints and pause guidance? Your quests stay in your quest log."},
		})
		self:Actions(p,{{"recoverGuide","Restore arrow and compact panel",function() command("guide") end}})
		self:Section(p,"Quest locations")
		self:Text(p,"",function() return FP.QuestObjectives:Summary() end)
		self:Text(p,"Small orange dots mark known sources for unfinished quests. Hover for details; click to guide there. Nearby sources appear on the minimap. Dense world-map points are grouped, with up to 350 markers; the minimap shows the nearest 40. Some event and new Forever objectives have no locations yet.")
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
		end,function(item) local s=item.step; return (s.deferred and "[Deferred] " or "")..tostring(s.title).." — "..tostring(s.text or s.kind) end)
		search:SetScript("OnTextChanged",function() list.page=1; self:Refresh() end)
		self:Actions(p,{
			{"goQuest","Guide to selected quest",function()
				local item=self:Selected(list); if not item then return end
				if item.step.kind=="hearth" then FP:Print("Use your Hearthstone to "..tostring(item.step.title))
				elseif FP.Planner:Go(item.step) then FP:Print("Heading to "..item.step.title)
				else FP:Print("No coordinates available yet. Check the quest directions.") end
			end,enabled=function() return self:Selected(list)~=nil end},
			{"refreshQuests","Refresh quest list",function() FP.Planner:Build() end},
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
		self:Text(p,"",function() return "Checklist display: "..FP.cdb.prep.mode..". Supplies appear inside the PvP HUD; enable that HUD if hidden." end)
		self:Actions(p,{
			{"prepShow","Show checklist",function() command("pvp on"); command("pvp show"); command("prep show") end},
			{"prepAuto","Automatic checklist",function() command("prep auto") end},
			{"prepHide","Hide checklist",function() command("prep hide") end},
		})
		for _,entry in ipairs({{"water","Drink target"},{"bandages","Bandage target"},{"reagents","Reagent target"}}) do
			local key,name=entry[1],entry[2]
			local field=self:Field(p,"prep"..key,name,FP.cdb.prep[key])
			self:Actions(p,{{"applyPrep"..key,"Save "..name:lower(),function() local n=self:Number(field,name,0,200,true); if n then command("prep "..key.." "..n) end end}})
		end
		self:Actions(p,{{"prepReport","Check carried supplies",function() command("prep") end}})
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
		local dura=self:Field(p,"durabilityThreshold","Durability threshold (0–90%)",FP.settings.reminders.durability)
		local ammo=self:Field(p,"ammoThreshold","Ammo threshold (0–5000)",FP.settings.reminders.ammo)
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
		local flag=self:Field(p,"flagIndex","Flag map slot (1–10)",FP.settings.pvp.flagIndex or 1)
		self:Actions(p,{
			{"trackFlag","Track flag slot",function() local n=self:Number(flag,"flag slot",1,10,true); if n then command("pvp track "..n) end end},
			{"untrackFlag","Stop flag tracking",function() command("pvp track off") end},
		})
		self:Actions(p,{
			{"pvpReport","Current PvP status",function() command("pvp status") end},
			{"pvpSpells","Supported spell timers",function() command("pvp spells") end},
		})
		self:Actions(p,{{"pvpClear","Clear session timers / roster",function() command("pvp clear") end,confirm="Clear the current PvP timers and session roster? This does not change your quests or waypoint route."}})
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
		local instance=self:Field(p,"rareInstance","Instance name",FP.RareWatch:Watch().instance)
		self:Actions(p,{{"rareSetInstance","Set watched instance",function()
			local name=U.Trim(instance:GetText()); if name=="" then FP:Print("Enter an instance name."); return end
			command("rare instance "..name)
		end}})
		local list=self:List(p,"rareList",function()
			local out={}; for i,r in ipairs(FP.RareWatch:Watch().rares) do out[#out+1]={key=i,rare=r} end; return out
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
		self:Section(p,"Map pins and arrow")
		for _,entry in ipairs({{"worldMapPins","World-map pins"},{"minimapPin","Minimap pin"}}) do
			local key,text=entry[1],entry[2]
			self:Check(p,"display"..key,text,function() return FP.settings[key] end,function(v) FP.settings[key]=v; FP.Panel:ApplyDisplaySettings() end)
		end
		for _,entry in ipairs({{"questWorldPins","Quest source locations on world map"},{"questMinimapPins","Nearby quest sources on minimap"},{"questSelectedOnly","Only show sources for the selected quest"}}) do
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
			local size=self:Field(p,key.."Scale",title.." size (%)",math.floor(s.scale*100+.5))
			self:Actions(p,{
				{key.."ApplyScale","Apply size",function() local n=self:Number(size,"size",min,max,true); if n then command(key.." scale "..n/100) end end},
				{key.."Reset","Reset position & size",function() command(key.." reset"); size:SetText(tostring(math.floor(s.scale*100+.5))) end},
			})
		end
		self:Check(p,"barFPS","Show FPS and latency",function() return FP.settings.bar.fps end,function(v) command("bar fps "..onoff(v)) end)
		self:Section(p,"Hunter audio")
		self:Check(p,"hunterAudio","Enable Hunter sound cues",function() return FP.settings.hunterAudio.enabled end,function(v) command("audio "..onoff(v)) end)
		self:Actions(p,{{"audioTest","Play sample sounds",function() command("audio test") end},{"audioStatus","Audio status",function() command("audio") end}})
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
		self:Actions(p,{{"resetAccount","Reset account data & settings",function() command("reset data confirm") end,confirm="Remove the account's recorded dataset AND account-wide settings on your next reload? This affects every character using ForeverPath."}})
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
	e:SetMaxLetters(4096); e:SetText(tostring(value or ""))
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

function H:List(p,id,get,describe)
	local list={page=1,rows={},get=get,describe=describe}
	self.controls[id]=list
	for i=1,7 do
		local row=button(p.body,"",0,-p.y,W,function() end)
		row:SetSize(W,26)
		row:SetScript("OnClick",function(btn) if btn.item then list.selected=btn.item.key; self:Refresh() end end)
		row:SetScript("OnEnter",function(btn)
			if not btn.item then return end
			GameTooltip:SetOwner(btn,"ANCHOR_RIGHT"); GameTooltip:AddLine(describe(btn.item),1,1,1,true); GameTooltip:Show()
		end)
		row:SetScript("OnLeave",function(btn) if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end end)
		list.rows[i]=row; p.y=p.y+29
	end
	list.caption=label(p.body,"",160,-p.y-6,280)
	list.prev=button(p.body,"Previous",0,-p.y,130,function() list.page=math.max(1,list.page-1); self:Refresh() end)
	list.next=button(p.body,"Next",W-130,-p.y,130,function() list.page=list.page+1; self:Refresh() end)
	p.y=p.y+36
	table.insert(p.refreshers,function()
		list.items=get() or {}
		local pages=math.max(1,math.ceil(#list.items/7))
		list.page=math.min(list.page,pages)
		list.caption:SetText(#list.items .. " items  ·  " .. list.page .. " / " .. pages)
		if list.page>1 then list.prev:Enable() else list.prev:Disable() end
		if list.page<pages then list.next:Enable() else list.next:Disable() end
		for i,b in ipairs(list.rows) do
			b.item=list.items[(list.page-1)*7+i]
			if b.item then
				b:SetText((list.selected==b.item.key and FP.GOLD .. "> " or "") .. U.Truncate(describe(b.item),82) .. "|r"); b:Show()
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
	for _,event in ipairs({"WAYPOINTS_CHANGED","PLAN_UPDATED","PROFESSIONS_CHANGED","RECIPES_SCANNED","PARTY_UPDATED","PVP_CHANGED","RARE_CHANGED","DISPLAY_SETTINGS_CHANGED"}) do FP:On(event,refresh) end
	FP:RegisterEvent("PLAYER_REGEN_ENABLED",refresh)
	FP:RegisterEvent("PLAYER_REGEN_DISABLED",refresh)
	FP:RegisterEvent("UI_SCALE_CHANGED",function() self:FitWindow() end)
	FP:RegisterEvent("DISPLAY_SIZE_CHANGED",function() self:FitWindow() end)
end
