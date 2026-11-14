local _,FP=...
local P=FP:NewModule("QuestLocationPanel")
local Q,API,U=FP.QuestObjectives,FP.API,FP.Util

function P:Open(questID)
	local requested=questID or Q:AttentionQuest()
	FP.Hub:Open("locations")
	self.quests.selected=requested
	self.quests.page=1;self.locations.selected=nil;self.locations.page=1
	FP.Hub:Refresh()
	for i,row in ipairs(self.quests.items) do if row.key==self.questID then self.quests.page=math.ceil(i/5);break end end
	FP.Hub:Refresh()
end

function P:Build(H,p)
	H:Text(p,"Find the creatures, drops, objects and quest contacts you need. Locations are known search areas, not a live scan of enemies.")
	local search=H:Field(p,"locationSearch","Find a quest","")
	self.quests=H:List(p,"locationQuests",function()
		local rows,query={},U.Trim(search:GetText() or ""):lower()
		for _,q in ipairs(API.GetQuestLog()) do
			if query=="" or q.title:lower():find(query,1,true) or tostring(q.questID)==query then
				rows[#rows+1]={key=q.questID,title=q.title,complete=q.isComplete}
			end
		end
		table.sort(rows,function(a,b)return a.title<b.title end)
		local selected=self.quests.selected or self.questID or Q:AttentionQuest()
		local found=false;for _,r in ipairs(rows) do if r.key==selected then found=true end end
		self.quests.selected=found and selected or (rows[1] and rows[1].key)
		if self.questID~=self.quests.selected then self.locations.selected=nil;self.locations.page=1 end
		self.questID=self.quests.selected
		return rows
	end,function(row)return Q:QuestLabel(row.key,row.title)..(row.complete and " — ready for turn-in" or "") end,{count=5})
	search:SetScript("OnTextChanged",function() self.quests.page=1;H:Refresh() end)
	H:Text(p,"",function()return self.questID and Q:LocationSummary(self.questID) or "Your quest log is empty." end)
	p.y=p.y+45
	H:Actions(p,{
		{"showQuestMap","Show quest on map",function()
			if Q:ShowQuest(self.questID) then H.frame:Hide() else FP:Print("No map location is available yet for this quest.") end
		end,enabled=function()return self.questID~=nil end},
		{"locationShowAll","Show all quests",function()Q:ShowAll() end},
		{"locationRefresh","Refresh locations",function()Q:Refresh(true) end},
	})
	H:Section(p,"Known locations — nearest first")
	self.locations=H:List(p,"questSourceLocations",function()
		local rows=self.questID and Q:Locations(self.questID) or {}
		local found=false;for _,r in ipairs(rows) do if r.key==self.locations.selected then found=true end end
		if not found then self.locations.selected=rows[1] and rows[1].key end
		return rows
	end,function(row)
		return row.point.name.." — "..API.GetMapName(row.point.mapID).." "..U.FormatCoords(row.point.x,row.point.y)..
			(row.distance and (" · "..U.FormatDistance(row.distance)) or "")..(row.group.kind=="Area" and " (approximate area)" or "")
	end,{count=6})
	H:Actions(p,{
		{"guideQuestSource","Guide to this location",function()
			local row=H:Selected(self.locations);if not row then return end
			Q:Reveal(self.questID,row.group.kind)
			if Q:Guide({entries={row}}) then FP:Print("Heading to "..row.point.name..". Search nearby; this is a known location.") end
		end,enabled=function()return H:Selected(self.locations)~=nil end},
		{"showSourceMap","Show this location",function()
			local row=H:Selected(self.locations)
			if row and Q:ShowQuest(self.questID,row) then H.frame:Hide() end
		end,enabled=function()return H:Selected(self.locations)~=nil end},
	})
	H:Text(p,"",function()
		local row=H:Selected(self.locations)
		return row and (row.group.title.."\n"..row.group.text.."\n"..(row.group.kind=="Area" and "The client supplies an area, not an exact creature or drop location." or "Known source locations do not guarantee a living spawn or a drop.")) or "Select a location above."
	end)
	p.y=p.y+35
end
