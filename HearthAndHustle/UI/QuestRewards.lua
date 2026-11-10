local _,FP=...
local P=FP:NewModule("RewardPanel")
local R,API,U=FP.QuestRewards,FP.API,FP.Util

function P:Build(H,p)
	self.mode="log"
	-- Snapshot first, then lists, then details: one consistent read per refresh.
	table.insert(p.refreshers,function()
		self.snapshot=API.GetRewardContext(self.mode)
		R:Rank(self.snapshot)
		local identity=self.mode..":"..tostring(self.snapshot.questID)
		if identity~=self.identity then
			self.identity=identity
			if self.list then self.list.selected=nil;self.list.page=1 end
		end
	end)
	H:Actions(p,{
		{"rewardLog","Quest log selection",function() self.mode="log" end},
		{"rewardDialog","Open quest dialog",function() self.mode="dialog" end},
		{"rewardRefresh","Refresh rewards",function() end},
	})
	H:Text(p,"",function()
		local s=self.snapshot
		return (self.mode=="dialog" and "Quest offer / turn-in" or "Quest log selection")..": "..(s.title or "No quest")..
			(s.questID and (" (#"..s.questID..")") or "").."\nXP: "..tostring(s.xp or "unavailable")..
			" · Quest money: "..(s.money and U.MoneyString(s.money) or "unavailable").."\n"..(s.message or "Select a reward below. To change quests, select one in Blizzard's quest log.")
	end)
	p.y=p.y+24 -- leave room for a wrapped quest title / unavailable-data message
	self.list=H:List(p,"rewardItems",function()
		local rows=self.snapshot.items
		local found=false
		for _,row in ipairs(rows) do if row.key==self.list.selected then found=true end end
		if not found then self.list.selected=rows[1] and rows[1].key or nil end
		return rows
	end,function(row)
		return (row.kind=="choice" and "Choose: " or "Receive: ")..row.name.." ×"..tostring(row.count or "?")..
			" · "..(row.value and U.MoneyString(row.value) or "value unavailable")..(row.bestVendor and " · best vendor value" or "")
	end)
	for _,button in ipairs(self.list.rows) do
		button:SetScript("OnEnter",function(b)
			if not b.item then return end
			GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
			if b.item.link and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(b.item.link)
			else GameTooltip:AddLine(b.item.name,1,1,1,true) end
			GameTooltip:Show()
		end)
	end
	H:Section(p,"Equipment comparison")
	self.details=p.body:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
	self.details:SetPoint("TOPLEFT",0,-p.y);self.details:SetWidth(600);self.details:SetJustifyH("LEFT")
	local y=p.y
	table.insert(p.refreshers,function()
		local row=H:Selected(self.list)
		if not row and self.list.items[1] then self.list.selected=self.list.items[1].key;row=self.list.items[1] end
		self.details:SetText(R:Details(row))
		p.body:SetHeight(math.max(432,y+self.details:GetStringHeight()+24))
	end)
end
