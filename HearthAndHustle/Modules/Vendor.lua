-- HearthAndHustle / Modules / Vendor.lua
-- Vendor helper (v0.8.0), modeled on what the most-installed Forever addons
-- (ForeverPlus, ForeverForge, Leatrix Plus) do at a merchant, kept behind this
-- project's line: the addon shows, the player clicks.
--   * at an open merchant: a strip with "Sell grays (n · value)" and "Repair cost"
--     buttons. One click = one player action; nothing sells or repairs on its own.
--   * vendor value on item tooltips away from a vendor (Blizzard shows it at one).
--   * vendor value under each quest reward; the best-value choice is gold.
--     It never picks a reward.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local V = FP:NewModule("Vendor")

local SELL_BATCH = 12          -- bag slots sold per click (one click, one batch)

local function s() return FP.settings.vendor end

-------------------------------------------------------------------------------
-- Merchant strip
-------------------------------------------------------------------------------
function V:OnInit()
	local f = CreateFrame("Frame", "HearthAndHustleVendorStrip", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(336, 30)
	f:SetFrameStrata("HIGH")
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
		f:SetBackdropBorderColor(0.37, 0.84, 1, 0.8)
	end

	local sell = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	self.sell = sell
	sell:SetSize(190, 22)
	sell:SetPoint("LEFT", 6, 0)
	sell:SetScript("OnClick", function() V:SellClicked() end)
	sell:SetScript("OnEnter", function(btn)
		local junk = V.junk
		if not junk or #junk.items == 0 then return end
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:AddLine("Gray items in your bags", 1, 0.82, 0)
		for i = 1, math.min(#junk.items, 12) do
			local it = junk.items[i]
			GameTooltip:AddDoubleLine(tostring(it.name or it.itemID) .. (it.count > 1 and (" ×" .. it.count) or ""), U.MoneyString(it.value), 0.6, 0.6, 0.6, 1, 1, 1)
		end
		if #junk.items > 12 then GameTooltip:AddLine("… and " .. (#junk.items - 12) .. " more", 0.6, 0.6, 0.6) end
		GameTooltip:AddLine("Click sells up to " .. SELL_BATCH .. " of them. Nothing sells without the click.", 0.5, 0.8, 1, true)
		GameTooltip:Show()
	end)
	sell:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local repair = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	self.repair = repair
	repair:SetSize(128, 22)
	repair:SetPoint("LEFT", sell, "RIGHT", 6, 0)
	repair:SetScript("OnClick", function() V:RepairClicked() end)

	f:Hide()
end

local function anchorStrip(f)
	f:ClearAllPoints()
	local m = _G.MerchantFrame
	if type(m) == "table" and m.GetPoint then
		f:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, -2)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
	end
end

function V:OnEnable()
	local E = function(ev, fn) FP:RegisterEvent(ev, fn) end
	E("MERCHANT_SHOW", function() V:OnMerchant(true) end)
	E("MERCHANT_CLOSED", function() V:OnMerchant(false) end)
	E("MERCHANT_UPDATE", function() V:RequestRefresh() end)
	E("BAG_UPDATE_DELAYED", function() V:RequestRefresh() end)
	E("PLAYER_MONEY", function() V:RequestRefresh() end)
	E("UPDATE_INVENTORY_DURABILITY", function() V:RequestRefresh() end)
	E("GET_ITEM_INFO_RECEIVED", function() V:RequestRefresh(); V:RequestRewards() end)
	E("PLAYER_REGEN_DISABLED", function() V:Refresh() end)
	E("PLAYER_REGEN_ENABLED", function() V:RequestRefresh() end)
	E("QUEST_COMPLETE", function() V:RequestRewards() end)
	E("QUEST_DETAIL", function() V:RequestRewards() end)
	E("QUEST_FINISHED", function() V.rewardsShown = nil end)

	if type(hooksecurefunc) == "function" and type(QuestInfo_ShowRewards) == "function" then
		hooksecurefunc("QuestInfo_ShowRewards", function() V:RequestRewards() end)
		self.rewardHook = true
	end
	self.tooltipHook = API.AddTooltipItemHook(function(tooltip) V:OnTooltip(tooltip) end)
end

function V:OnMerchant(open)
	self.merchant = open
	if open and s().enabled then
		anchorStrip(self.frame)
		self.sold, self.soldValue = 0, 0
		self:Refresh()
		self.frame:Show()
	else
		self.frame:Hide()
		if self.sold and self.sold > 0 then
			FP:Print(string.format("Sold %d gray %s for %s.", self.sold, self.sold == 1 and "item" or "items", U.MoneyString(self.soldValue)))
			self.sold = 0
		end
	end
end

function V:RequestRefresh()
	if not self.merchant then return end
	FP.Throttle("vendor-strip", 0.3, function() V:Refresh() end)
end

function V:Refresh()
	if not self.merchant then return end
	local combat = API.InCombat()
	local junk, why = API.GetJunk()
	self.junk = junk
	if API.BlizzardSellsJunk() then
		-- Blizzard's own Sell All Junk button is on this client: do not duplicate it.
		self.sell:SetText("Gray value: " .. (junk and U.MoneyString(junk.total) or "n/a"))
		self.sell:Disable()
	elseif not junk then
		self.sell:SetText(combat and "Sell grays (after combat)" or ("Grays: " .. tostring(why)))
		self.sell:Disable()
	elseif #junk.items == 0 then
		self.sell:SetText(junk.unpriced > 0 and ("Grays: " .. junk.unpriced .. " not priced yet") or "No gray items")
		self.sell:Disable()
	else
		self.sell:SetText(string.format("Sell %d gray%s · %s", #junk.items, #junk.items == 1 and "" or "s", U.MoneyString(junk.total)) .. (junk.unpriced > 0 and (" +" .. junk.unpriced .. "?") or ""))
		self.sell:Enable()
	end

	local rep = API.GetRepairInfo()
	local money = API.GetMoney()
	self.repairInfo = rep
	if not rep then
		self.repair:SetText("Repair: n/a"); self.repair:Disable()
	elseif not rep.merchantRepairs then
		self.repair:SetText(rep.needed and ("Repair elsewhere: " .. U.MoneyString(rep.cost)) or "No repair here"); self.repair:Disable()
	elseif not rep.needed or rep.cost == 0 then
		self.repair:SetText("Gear repaired"); self.repair:Disable()
	elseif money and money < rep.cost then
		self.repair:SetText("Repair " .. U.MoneyString(rep.cost) .. " (short)"); self.repair:Disable()
	elseif combat then
		self.repair:SetText("Repair after combat"); self.repair:Disable()
	else
		self.repair:SetText("Repair " .. U.MoneyString(rep.cost)); self.repair:Enable()
	end
end

-- One click sells one batch. The next batch needs the next click.
function V:SellClicked()
	if not self.merchant or API.InCombat() or API.BlizzardSellsJunk() then return 0 end
	local junk = API.GetJunk()
	if not junk or #junk.items == 0 then self:Refresh(); return 0 end
	local n = 0
	for i = 1, math.min(#junk.items, SELL_BATCH) do
		local it = junk.items[i]
		if API.SellSlot(it.bag, it.slot) then
			n = n + 1
			self.sold = (self.sold or 0) + 1
			self.soldValue = (self.soldValue or 0) + it.value
		end
	end
	FP.After(0.5, function() V:Refresh() end)
	self:Refresh()
	return n
end

function V:RepairClicked()
	local rep = self.repairInfo or API.GetRepairInfo()
	if not self.merchant or not rep or not rep.merchantRepairs or not rep.needed or rep.cost == 0 then return false end
	local money = API.GetMoney()
	if money and money < rep.cost then return false end
	local ok = API.RepairAll()
	if ok then FP:Print("Repaired for " .. U.MoneyString(rep.cost) .. ".") end
	FP.After(0.5, function() V:Refresh() end)
	return ok
end

-------------------------------------------------------------------------------
-- Tooltip vendor value (away from a vendor; Blizzard adds its own at one)
-------------------------------------------------------------------------------
local function alreadyPriced(tooltip)
	-- Blizzard's sell-price line uses the SELL_PRICE global string.
	local name = type(tooltip.GetName) == "function" and tooltip:GetName() or nil
	local n = type(tooltip.NumLines) == "function" and tooltip:NumLines() or 0
	if not name or type(SELL_PRICE) ~= "string" then return false end
	for i = 1, n do
		local fs = _G[name .. "TextLeft" .. i]
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and not FP.issecret(text) and text:find(SELL_PRICE, 1, true) then return true end
	end
	return false
end

function V:OnTooltip(tooltip)
	if not s().tooltipPrice or API.MerchantOpen() then return false end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return false end
	local link, id = API.GetTooltipItem(tooltip)
	if not link and not id then return false end
	local price, stack = API.GetItemValue(link or id)
	if not price or price <= 0 or alreadyPriced(tooltip) then return false end
	local right = U.MoneyString(price)
	if stack and stack > 1 then right = right .. FP.GREY .. "  ·  stack " .. U.MoneyString(price * stack) .. "|r" end
	tooltip:AddDoubleLine("Vendor value", right, 0.6, 0.6, 0.6, 1, 1, 1)
	if type(tooltip.Show) == "function" then tooltip:Show() end
	return true
end

-------------------------------------------------------------------------------
-- Quest reward values
-------------------------------------------------------------------------------
function V:RequestRewards()
	if not s().rewardValues then return end
	FP.Throttle("vendor-rewards", 0.2, function() V:DecorateRewards() end)
end

local function rewardButtons()
	local qi = _G.QuestInfoFrame
	local rf = type(qi) == "table" and qi.rewardsFrame or _G.QuestInfoRewardsFrame
	return type(rf) == "table" and type(rf.RewardButtons) == "table" and rf.RewardButtons or nil
end

function V:DecorateRewards()
	local buttons = rewardButtons()
	if not buttons then return 0 end
	local values = API.GetQuestRewardValues()
	FP.QuestRewards:Rank({ items = values, countsKnown = values.countsKnown == true })
	local byKey = {}
	for _, v in ipairs(values) do byKey[v.type .. ":" .. v.index] = v end
	local n = 0
	for _, b in pairs(buttons) do
		if type(b) == "table" and type(b.GetID) == "function" then
			local v = b.type and byKey[tostring(b.type) .. ":" .. tostring(b:GetID())] or nil
			if v and v.value and b:IsShown() then
				if not b.fpValue then
					b.fpValue = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					b.fpValue:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
					b.fpValue:SetJustifyH("RIGHT")
				end
				local gold = v.bestVendor
				b.fpValue:SetText((gold and FP.GOLD or FP.GREY) .. U.MoneyString(v.value) .. "|r")
				b.fpValue:Show()
				n = n + 1
			elseif b.fpValue then
				b.fpValue:SetText("")
				b.fpValue:Hide()
			end
		end
	end
	self.rewardsShown = n
	return n
end

-------------------------------------------------------------------------------
-- /hh vendor
-------------------------------------------------------------------------------
function V:Command(rest)
	local args = U.Split(rest or "", " ")
	local sub, val = (args[1] or ""):lower(), (args[2] or ""):lower()
	local function onoff(current)
		if val == "on" then return true elseif val == "off" then return false else return not current end
	end
	if sub == "on" then s().enabled = true; FP:Print("vendor strip on")
	elseif sub == "off" then s().enabled = false; self.frame:Hide(); FP:Print("vendor strip off")
	elseif sub == "tooltip" or sub == "price" then s().tooltipPrice = onoff(s().tooltipPrice); FP:Print("tooltip vendor value " .. (s().tooltipPrice and "on" or "off"))
	elseif sub == "rewards" then s().rewardValues = onoff(s().rewardValues); FP:Print("quest reward values " .. (s().rewardValues and "on" or "off"))
	elseif sub == "junk" or sub == "grays" then
		local junk, why = API.GetJunk()
		if not junk then FP:Print("Grays: " .. tostring(why)); return end
		FP:Print(string.format("%d gray %s worth %s%s", #junk.items, #junk.items == 1 and "item" or "items", U.MoneyString(junk.total), junk.unpriced > 0 and (" (+" .. junk.unpriced .. " not priced yet)") or ""))
		for i = 1, math.min(#junk.items, 10) do
			local it = junk.items[i]
			FP:Print("  " .. tostring(it.name or it.itemID) .. (it.count > 1 and (" ×" .. it.count) or "") .. "  " .. U.MoneyString(it.value))
		end
	else
		FP:Print("vendor strip " .. (s().enabled and "on" or "off") .. " · tooltip value " .. (s().tooltipPrice and "on" or "off") .. " · reward values " .. (s().rewardValues and "on" or "off") .. (self.tooltipHook and "" or " · tooltip hook unavailable on this client") .. (self.rewardHook and "" or " · reward hook: event-driven"))
		FP:Print("/hh vendor on|off | tooltip on|off | rewards on|off | junk")
	end
end
