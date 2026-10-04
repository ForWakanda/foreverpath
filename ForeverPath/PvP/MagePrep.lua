-- Mage supplies: information only. No casts, purchases, item use, cooldowns or auras.
local ADDON, FP = ...
local API, U = FP.API, FP.Util
local Prep = FP:NewModule("MagePrep")

-- Item/spell associations only; learned state is read from the character.
-- No training-level assumptions, restoration amounts or cooldown claims.
local GEMS = {
	{ item = 5514, spell = 759, name = "Mana Agate" },
	{ item = 5513, spell = 3552, name = "Mana Jade" },
	{ item = 8007, spell = 10053, name = "Mana Citrine" },
	{ item = 8008, spell = 10054, name = "Mana Ruby" },
}
local REAGENTS = {
	{ item = 17056, name = "Slow Fall feathers", action = "stock", spells = { 130 } },
	{ item = 17031, name = "Teleport runes", spells = { 3561, 3562, 3563, 3565, 3566, 3567 } },
	{ item = 17032, name = "Portal runes", spells = { 10059, 11416, 11417, 11418, 11419, 11420 } },
	{ item = 17020, name = "Arcane Powder", spells = { 23028 } },
}

local function knowsAny(spells)
	local unknown = false
	for _, id in ipairs(spells) do
		local known = API.KnowsSpell(id)
		if known == true then return true end
		if known == nil then unknown = true end
	end
	if unknown then return nil end
	return false
end

function Prep:IsMage()
	return API.GetCharInfo().class == "MAGE"
end

local function stockRow(key, name, count, goal, action)
	local missing = count and math.max(0, goal - count) or nil
	local text, color
	if count == nil then text, color = name .. ": count unavailable", FP.GREY
	elseif missing > 0 then text, color = string.format("%s %d/%d — %s %d", name, count, goal, action, missing), FP.GOLD
	else text, color = string.format("%s %d/%d — stocked", name, count, goal), FP.GREEN end
	return { key = key, count = count, goal = goal, missing = missing, text = color .. text .. "|r" }
end

function Prep:Refresh(attempt)
	if self.combat or API.InCombat() or not FP.cdb.prep.enabled or not self:IsMage() then return end
	local inv, reason = API.GetPrepInventory()
	self.inventory, self.reason, self.rows = inv, reason, {}
	self.bg = API.InBattleground()
	local s = FP.cdb.prep
	if not inv then
		self.rows[1] = { text = FP.GREY .. tostring(reason) .. "|r" }
	else
		if s.water > 0 then self.rows[#self.rows + 1] = stockRow("water", "Drinks", inv.waterKnown and inv.water or nil, s.water, "stock") end
		if s.bandages > 0 then self.rows[#self.rows + 1] = stockRow("bandages", "Bandages (carried)", inv.bandagesKnown and inv.bandages or nil, s.bandages, "stock") end
		local unknown = false
		for _, gem in ipairs(GEMS) do
			local known = API.KnowsSpell(gem.spell)
			if known == true then self.rows[#self.rows + 1] = stockRow("gem:" .. gem.item, gem.name, inv.counts[gem.item] or 0, 1, "conjure")
			elseif known == nil then unknown = true end
		end
		if s.reagents > 0 then
			for _, reagent in ipairs(REAGENTS) do
				local known = knowsAny(reagent.spells)
				if known == true then self.rows[#self.rows + 1] = stockRow("reagent:" .. reagent.item, reagent.name, inv.counts[reagent.item] or 0, s.reagents, reagent.action or "buy")
				elseif known == nil then unknown = true end
			end
		end
		if unknown then self.rows[#self.rows + 1] = { text = FP.GREY .. "Gem/reagent needs: spells unavailable|r" } end
	end
	self.scannedAt = API.Time()
	FP:Fire("PVP_CHANGED")
	-- Item cache responses normally drive refresh; retries also cover delayed bags.
	if (not inv or not inv.waterKnown or not inv.bandagesKnown) and (attempt or 0) < 3 then
		local generation = self.generation
		FP.After(1, function() if Prep.generation == generation then Prep:Refresh((attempt or 0) + 1) end end)
	end
end

function Prep:RequestRefresh()
	self.generation = (self.generation or 0) + 1
	FP.Throttle("mage-prep", 0.3, function() Prep:Refresh() end)
end

function Prep:Briefly()
	self.untilTime = API.Time() + 20
	self:RequestRefresh()
	FP.After(20.1, function() FP:Fire("PVP_CHANGED") end)
end

function Prep:Lines()
	local s = FP.cdb.prep
	if not self.isMage or not s.enabled or s.mode == "hide" or self.combat or API.InCombat() then return {} end
	if s.mode ~= "show" and not self.merchant and not self.bg and API.Time() >= (self.untilTime or 0) then return {} end
	return self.rows or { { text = FP.GREY .. "Reading bag supplies…|r" } }
end

function Prep:Command(rest)
	if not self:IsMage() then FP:Print("The preparation checklist is for Mages."); return end
	local args, s = U.Split(rest or "", " "), FP.cdb.prep
	local sub = (args[1] or ""):lower()
	if sub == "water" or sub == "bandages" or sub == "reagents" then
		local n = tonumber(args[2])
		if not U.Finite(n) or n < 0 or n > 200 or n ~= math.floor(n) then FP:Print("Use a whole-number stocking target from 0 to 200 (0 hides that category)."); return end
		s[sub] = n
		FP:Print(sub .. " stocking target: " .. n)
	elseif sub == "on" or sub == "off" then
		s.enabled = sub == "on"
		if s.enabled then s.mode = "auto" end
		FP:Print("Mage preparation checklist " .. sub)
	elseif sub == "show" or sub == "hide" or sub == "auto" then
		s.mode = sub
		if sub ~= "hide" then s.enabled = true end
		FP:Print("Mage preparation display: " .. sub)
	elseif sub ~= "" then
		FP:Print("prep: show | hide | auto | on | off | water <n> | bandages <n> | reagents <n>")
		return
	end
	self:Briefly()
	if (sub == "show" or sub == "auto" or sub == "on") and (not FP.settings.pvp.enabled or FP.settings.pvp.manual == "hide") then
		FP:Print("The PvP HUD is hidden; use /fp pvp on and /fp pvp auto to display the checklist.")
	end
	if sub == "" then
		if self.combat or API.InCombat() then FP:Print("Supply checks resume after combat."); return end
		if not s.enabled then FP:Print("Checklist disabled; /fp prep on to enable."); return end
		self:Refresh()
		FP:Print("Mage supplies — bags only; stocking targets, not combat readiness:")
		for _, row in ipairs(self.rows or {}) do FP:Print(row.text) end
	end
	FP:Fire("PVP_CHANGED")
end

function Prep:OnEnable()
	self.isMage = self:IsMage()
	if not self.isMage then return end
	self.combat = API.InCombat()
	FP.PvP:RegisterSection("Mage supplies", 5, function() return Prep:Lines() end)
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED" }) do
		FP:RegisterEvent(event, function() self:RequestRefresh() end)
	end
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_ENTERING_BATTLEGROUND", "ZONE_CHANGED_NEW_AREA" }) do
		FP:RegisterEvent(event, function() self:Briefly() end)
	end
	FP:RegisterEvent("MERCHANT_SHOW", function() self.merchant = true; self:RequestRefresh() end)
	FP:RegisterEvent("MERCHANT_CLOSED", function() self.merchant = false; FP:Fire("PVP_CHANGED") end)
	FP:RegisterEvent("PLAYER_REGEN_DISABLED", function() self.combat = true; self.generation = (self.generation or 0) + 1; FP.PvP:Refresh() end)
	FP:RegisterEvent("PLAYER_REGEN_ENABLED", function() self.combat = false; self:RequestRefresh() end)
	self:Briefly()
end
