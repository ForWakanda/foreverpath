-- Search and inspect share the existing tools window; each view owns its
-- scroll height. Browsing a chain never changes the selected quest or route.
local _, FP = ...
local C, API = FP.QuestChains, FP.API
local P = FP:NewModule("ChainPanel")
P.history = {}

function P:Inspect(questID,remember)
	if not FP.Util.Finite(questID) or questID<=0 then return end
	if remember and self.questID and self.questID~=questID then
		self.history[#self.history+1]=self.questID
		if #self.history>30 then table.remove(self.history,1) end
	end
	self.questID,self.view=questID,"detail"
	if self.links then self.links.page,self.links.selected=1,nil end
	if self.search then self.search:ClearFocus() end
	self.page.scroll:SetVerticalScroll(0)
	FP.Hub:Refresh()
end

function P:Build(H,p)
	self.page,self.view=p,"browser"
	local function view(parent)
		local frame=CreateFrame("Frame",nil,parent or p.body)
		frame:SetPoint("TOPLEFT"); frame:SetSize(600,432)
		return {body=frame,y=0,refreshers={},fields={}}
	end
	local b,d=view(),view()
	self.browser,self.detail=b,d
	H:Text(b,"",function()
		return C.loading and ("Preparing quest search: "..C.scanned.." / "..C.total.."… Current quests can be inspected now.") or
			(C.status or "Open a quest to see its prerequisites and follow-ups.")
	end)
	self.search=H:Field(b,"chainSearch","Quest name or ID","")
	self.currentOnly=true
	H:Check(b,"chainCurrentOnly","Only quests in my log",function() return self.currentOnly end,function(v) self.currentOnly=v;self.results.page=1 end)
	self.results=H:List(b,"chainResults",function() return C:Search(self.search:GetText(),self.currentOnly,self.ctx) end,
		function(row) return row.name.." (#"..row.id..") — "..C:StateLabel(row.id,self.ctx) end)
	self.search:SetScript("OnTextChanged",function()
		-- Typing searches the reference as well as the log; returning to an
		-- empty search leaves the user's explicit filter choice intact.
		if FP.Util.Trim(self.search:GetText() or "")~="" then self.currentOnly=false end
		self.results.page=1;H:Refresh()
	end)
	H:Actions(b,{
		{"chainInspect","Inspect quest",function() local row=H:Selected(self.results);if row then self:Inspect(row.id,true) end end,
			enabled=function()return H:Selected(self.results)~=nil end},
		{"chainCurrent","Current quest",function()
			local selected=API.GetSelectedQuest()
			if selected then self:Inspect(selected,true) else FP:Print("Select a quest in your quest log, or choose one from the list.") end
		end},
		{"chainRefresh","Refresh reference",function() C:StartIndex(true) end},
	})
	H:Text(b,"Select a quest to inspect its chain. Quests with the same title are distinguished by quest ID. Search includes completed quests and quests you have not accepted.")
	b.body:SetHeight(math.max(432,b.y+12))

	H:Actions(d,{
		{"chainSearchBack","Back to search",function() self.view="browser";p.scroll:SetVerticalScroll(0) end},
		{"chainBack","Previous quest",function()
			local previous=table.remove(self.history); if previous then self:Inspect(previous,false) end
		end,enabled=function() return #self.history>0 end},
		{"chainPickup","Guide to pickup",function() local _,message=C:GuidePickup(self.questID);FP:Print(message) end,
			enabled=function()
				local s=self.questID and self.ctx:State(self.questID)
				return s and s.onQuest==false and s.completed==false
			end},
	})
	local text=d.body:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
	text:SetPoint("TOPLEFT",0,-d.y);text:SetWidth(600);text:SetJustifyH("LEFT")
	self.detailText=text
	local below=view(d.body)
	H:Section(below,"Before and after this quest")
	H:Text(below,"Indented rows belong to the prerequisite immediately above them. ANY ONE rows are alternatives. Long chains are shortened; inspect a linked quest to continue.")
	self.links=H:List(below,"chainLinks",function() return self.linkRows or {} end,function(row)return row.label end)
	H:Actions(below,{{"chainFollow","Inspect linked quest",function()
		local row=H:Selected(self.links);if row then self:Inspect(row.id,true) end
	end,enabled=function()return H:Selected(self.links)~=nil end}})
	H:Text(below,"",function() return self.linkRows and #self.linkRows==0 and "No linked quests are recorded here. Missing links do not prove a chain is complete." or "" end)
	below.body:SetHeight(below.y+12)
	for _,field in ipairs(b.fields) do p.fields[#p.fields+1]=field end
	table.insert(p.refreshers,function()
		self.ctx=C:Context()
		if self.view=="detail" and self.questID then
			b.body:Hide();d.body:Show()
			self.linkRows=C:Links(self.questID,self.ctx)
			text:SetText(table.concat(C:Details(self.questID,self.ctx),"\n\n"))
			local height=math.max(80,text:GetStringHeight()+16)
			below.body:ClearAllPoints();below.body:SetPoint("TOPLEFT",0,-d.y-height)
			d.body:SetHeight(d.y+height+below.y+12)
			for _,fn in ipairs(d.refreshers) do fn() end
			for _,fn in ipairs(below.refreshers) do fn() end
			p.body:SetHeight(math.max(432,d.body:GetHeight()))
		else
			d.body:Hide();b.body:Show()
			for _,fn in ipairs(b.refreshers) do fn() end
			p.body:SetHeight(math.max(432,b.y+12))
		end
	end)
end
