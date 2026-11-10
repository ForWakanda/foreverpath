-- Informational comparisons; no stat weights, reward selection or gear actions.
local _,FP=...
local R=FP:NewModule("QuestRewards")
local API,U=FP.API,FP.Util
local SLOTS={
	INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_BODY={4},
	INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},
	INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},
	INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},
	INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},
	INVTYPE_HOLDABLE={17},INVTYPE_2HWEAPON={16,17},INVTYPE_RANGED={18},
	INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18},INVTYPE_TABARD={19},
}
local SLOT_NAMES={[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",[16]="Main hand",[17]="Off hand",[18]="Ranged / relic"}

function R:Rank(snapshot)
	local best,complete,choices=nil,snapshot.countsKnown==true,0
	for _,row in ipairs(snapshot.items) do
		row.bestVendor=nil
		if row.kind=="choice" then
			choices=choices+1
			if row.value==nil then complete=false else best=math.max(best or 0,row.value) end
		end
	end
	if complete and choices>1 and best and best>0 then
		for _,row in ipairs(snapshot.items) do row.bestVendor=row.kind=="choice" and row.value==best end
	end
end

local function statLines(reward,baseline)
	if not reward or not baseline then return {"Stat comparison unavailable while item data is incomplete."} end
	local keys,seen={},{}
	for key in pairs(reward) do seen[key]=true end
	for key in pairs(baseline) do seen[key]=true end
	for key in pairs(seen) do keys[#keys+1]=key end
	table.sort(keys)
	local lines={"Stat: reward / equipped (change)"}
	for _,key in ipairs(keys) do
		local a,b=reward[key] or 0,baseline[key] or 0
		lines[#lines+1]=string.format("%s: %g / %g (%+g)",API.GetRewardStatLabel(key),a,b,a-b)
	end
	if #keys==0 then return {"No numeric item stats returned. Check the full item tooltips."} end
	return lines
end
local function equippedName(item)
	if item.status=="empty" then return "Empty slot" end
	return item.name or "Equipped item data unavailable"
end

function R:Comparisons(row)
	local item=row.item
	local slots=item and SLOTS[item.equipLoc]
	if not slots then return {} end
	local out={}
	if item.equipLoc=="INVTYPE_2HWEAPON" then
		local main,off=API.GetRewardEquipment(16),API.GetRewardEquipment(17)
		local stats
		if main.stats and off.stats then
			stats={}
			for k,v in pairs(main.stats) do stats[k]=(stats[k] or 0)+v end
			for k,v in pairs(off.stats) do stats[k]=(stats[k] or 0)+v end
		end
		out[1]={title="Replacing both hands: "..equippedName(main).." + "..equippedName(off),stats=stats}
	else
		for _,slot in ipairs(slots) do
			local gear=API.GetRewardEquipment(slot)
			local title=(SLOT_NAMES[slot] or "Equipped")..": "..equippedName(gear)
			out[#out+1]={title=title,stats=gear.stats}
		end
	end
	return out
end

function R:Details(row)
	if not row then return "Select an item above to compare it with your gear." end
	local lines={row.name..(row.count and (" ×"..row.count) or " (quantity unavailable)"),
		row.kind=="choice" and "Choice reward — choose one in Blizzard's quest dialog." or "Guaranteed item reward",
		"Vendor value for this stack: "..(row.value and U.MoneyString(row.value) or "unavailable")}
	if row.bestVendor then lines[#lines+1]="Highest vendor value among all listed choices (ties included)." end
	if row.usable==false then lines[#lines+1]="Blizzard marks this reward unusable by your character."
	elseif row.usable==nil then lines[#lines+1]="Usability is unavailable; check the item tooltip." end
	if not row.item then lines[#lines+1]="Item data is loading or unavailable."
	else
		local item=row.item
		lines[#lines+1]=(item.subtype or "Item").." · item level "..tostring(item.level or "?").." · requires level "..tostring(item.minLevel or "?")
		local comparisons=self:Comparisons(row)
		if #comparisons==0 then
			lines[#lines+1]="No equipped-slot comparison for this item type."
		else
			if item.equipLoc=="INVTYPE_WEAPON" or item.equipLoc=="INVTYPE_WEAPONMAINHAND" or item.equipLoc=="INVTYPE_WEAPONOFFHAND" or item.equipLoc=="INVTYPE_SHIELD" or item.equipLoc=="INVTYPE_HOLDABLE" then
				lines[#lines+1]="Hand comparisons are per slot. Check dual-wield rules and any two-handed weapon you would also remove."
			end
			for _,c in ipairs(comparisons) do
				lines[#lines+1]="\n"..c.title
				for _,line in ipairs(statLines(item.stats,c.stats)) do lines[#lines+1]=line end
			end
		end
	end
	lines[#lines+1]="\nNumeric stats do not capture every weapon effect, enchant, set bonus or proc. Vendor value and item level do not determine your best upgrade."
	return table.concat(lines,"\n")
end

function R:OnEnable()
	local function dialogButton(show)
		if not self.button and show and _G.QuestFrame then
			local b=CreateFrame("Button",nil,QuestFrame,"UIPanelButtonTemplate")
			b:SetSize(180,24);b:SetPoint("TOPRIGHT",QuestFrame,"BOTTOMRIGHT",-4,-4)
			b:SetText("Compare rewards")
			b:SetScript("OnClick",function()
				FP.Hub:Open("rewards");FP.RewardPanel.mode="dialog";FP.Hub:Refresh()
			end)
			self.button=b
		end
		if self.button then if show then self.button:Show() else self.button:Hide() end end
	end
	FP:RegisterEvent("QUEST_DETAIL",function() dialogButton(true) end)
	FP:RegisterEvent("QUEST_COMPLETE",function() dialogButton(true) end)
	FP:RegisterEvent("QUEST_FINISHED",function() dialogButton(false) end)
	local function refresh()
		local H=FP.Hub
		if H and H.frame and H.frame:IsShown() and H.selected=="rewards" then
			FP.Throttle("reward-page",.2,function() if H.selected=="rewards" then H:Refresh() end end)
		end
	end
	for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_DETAIL","QUEST_COMPLETE","QUEST_FINISHED","QUEST_ITEM_UPDATE",
		"GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do
		FP:RegisterEvent(event,refresh)
	end
	if type(hooksecurefunc)=="function" and type(QuestInfo_ShowRewards)=="function" then
		hooksecurefunc("QuestInfo_ShowRewards",refresh)
	end
end
