-- Minimal WoW API mock for running HearthAndHustle outside the game (Lua 5.1).
-- Explicit frame methods only; misspelled/nonexistent APIs must fail the tests.
local M = { timers = {}, tickers = {}, frames = {}, units = {}, facing = 0, mapID = 1413, px = 0.45, py = 0.55,
	quests = {}, complete = {}, dialogQuest = nil, now = 1000 }

local noop = function() end
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
M.vec = vec

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------
local Frame = {}
for _, method in ipairs({ "ClearAllPoints", "SetFrameStrata", "SetFrameLevel", "SetMovable", "SetClampedToScreen",
	"EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetJustifyH", "SetScale",
	"SetAllPoints", "SetOwner", "AddLine", "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture",
	"SetWordWrap", "SetAutoFocus", "SetHitRectInsets" }) do Frame[method] = noop end
Frame.__index = function(t, k)
	local v = rawget(Frame, k)
	if v ~= nil then return v end
	return nil
end
function Frame:Show() self._shown = true end
function Frame:Hide()
	local shown=self._shown; self._shown = false
	if shown and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Frame:IsShown() return self._shown and true or false end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:SetScale(scale) self._scale = scale end
function Frame:GetScale() return self._scale or 1 end
function Frame:SetChecked(checked) self._checked = checked and true or false end
function Frame:GetChecked() return self._checked or false end
function Frame:SetMaxLetters(n) self._maxLetters = n end
function Frame:SetFocus() self._focused = true end
function Frame:ClearFocus() self._focused = false end
function Frame:StartMoving() self._moving = true end
function Frame:StopMovingOrSizing() self._moving = false end
function Frame:SetWidth(w) self._w = w end
function Frame:SetScrollChild(child) self._scrollChild = child end
function Frame:SetVerticalScroll(y) self._scrollY = y end
function Frame:SetHeight(h) self._h = h end
function Frame:GetWidth() return self._w or 140 end
function Frame:GetHeight() return self._h or 100 end
function Frame:SetPoint(point, rel, relPoint, x, y)
	if type(rel) == "number" then x, y, rel, relPoint = rel, relPoint, nil, nil end
	self._point = { point, rel, relPoint or point, x or 0, y or 0 }
end
function Frame:GetPoint() local p = self._point or { "CENTER", nil, "CENTER", 0, 0 }; return p[1], p[2], p[3], p[4], p[5] end
function Frame:GetFrameLevel() return 1 end
function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:RegisterEvent(ev) self._events[ev] = true end
function Frame:RegisterUnitEvent(ev, ...) self._events[ev] = true; self._unitEvents = self._unitEvents or {}; self._unitEvents[ev] = { ... } end
function Frame:UnregisterEvent(ev) self._events[ev] = nil end
function Frame:EnableMouse(enabled) self._mouseClick, self._mouseMotion = enabled, enabled end
function Frame:IsMouseClickEnabled() return self._mouseClick ~= false end
function Frame:IsMouseMotionEnabled() return self._mouseMotion ~= false end
function Frame:SetTexture(path) self._texture = path; return true end
function Frame:GetTexture() return self._texture end
function Frame:SetAtlas(name) self._atlas = name end
function Frame:SetText(t) self._text = t end
function Frame:SetFormattedText(f, ...) self._text = string.format(f, ...) end
function Frame:GetText() return self._text end
function Frame:GetStringHeight() local t = self._text; if issecretvalue(t) then return M.Secret() end if type(t) ~= "string" then t = "" end local _, n = t:gsub("\n", ""); return (n + 1) * 12 end
function Frame:SetRotation(r) self._rotation = r end
function Frame:SetVertexColor(r, g, b) self._color = { r, g, b } end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:SetPassThroughButtons(...) self._passthrough = {...} end
function Frame:CreateTexture() return M.NewFrame("Texture") end
function Frame:CreateFontString() return M.NewFrame("FontString") end
function Frame:HighlightText() end
function Frame:SetBackdrop() end
function Frame:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v end
function Frame:GetAttribute(k) return self._attrs and self._attrs[k] end
function Frame:RegisterForClicks(...) self._clicks = { ... } end

function M.NewFrame(kind, name, parent, template)
	local f = setmetatable({ _kind = kind, _shown = true, _scripts = {}, _events = {}, _name = name, _parent = parent, _template = template }, Frame)
	if name then _G[name] = f end
	table.insert(M.frames, f)
	return f
end
CreateFrame = M.NewFrame

function M.FireEvent(event, ...)
	for _, f in ipairs(M.frames) do
		if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
	end
end

-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------
UIParent = M.NewFrame("Frame", "UIParent")
UISpecialFrames = {}
Minimap = M.NewFrame("Frame", "Minimap"); Minimap._w = 140
GameTooltip = M.NewFrame("GameTooltip", "GameTooltip")
GameTooltip.SetOwner = function(self, owner) self._owner = owner end
GameTooltip.IsOwned = function(self, owner) return self._owner == owner end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
	msg = tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	M.chat = M.chat or {}
	table.insert(M.chat, msg)
	if M.verbose then print("  [chat] " .. msg) end
end }
GetTime = function() return M.now end
GetServerTime = function() return 1790000000 + M.now end
GetBuildInfo = function() return "1.60.1", "70124", "Sep 30 2026", 16001, "", "beta" end
-- Secret stand-in: a table that errors on concat/arithmetic/comparison like the client's secrets.
local secretMeta = { __concat = function() error("secret value") end, __add = function() error("secret value") end,
	__lt = function() error("secret value") end, __le = function() error("secret value") end, __tostring = function() return "<secret>" end }
function M.Secret() return setmetatable({ __secret = true }, secretMeta) end
issecretvalue = function(v) return type(v) == "table" and rawget(v, "__secret") == true end
CreateVector2D = vec
IsShiftKeyDown = function() return false end
IsInGroup = function() return M.inGroup or false end
InCombatLockdown = function() return M.combatLockdown or false end
IsInInstance = function() if M.instance then return true, M.instance.type or "party" end return false, "none" end
GetInstanceInfo = function()
	local i = M.instance
	if not i then return "The Barrens", "none", 0, "", 0, 0, false, 1414, 0, nil, false end
	return i.name, i.type or "party", 1, "Normal", 5, 0, false, i.mapID or 189, 5, nil, false
end
M.played = {}
PlaySound = function(kit, channel) table.insert(M.played, { kit = kit, channel = channel }); return true, 1 end
SOUNDKIT = { RAID_WARNING = 8959 }
C_VignetteInfo = { GetVignettes = function() local out = {}; for _, v in ipairs(M.vignettes or {}) do out[#out + 1] = v.guid end return out end,
	GetVignetteInfo = function(guid) for _, v in ipairs(M.vignettes or {}) do if v.guid == guid then return { vignetteGUID = guid, name = v.name, atlasName = v.atlas or "VignetteKill", type = 0, onMinimap = true, isDead = false } end end end }
INSTANCE_RESET_SUCCESS = "%s has been reset."
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function() return "0.1.0-test" end }
C_Timer = {
	After = function(sec, fn) table.insert(M.timers, { at = M.now + sec, fn = fn }) end,
	NewTicker = function(sec, fn)
		local t = { sec = sec, fn = fn, Cancel = function(self) self.cancelled = true end }
		table.insert(M.tickers, t)
		return t
	end,
}
function M.RunTimers(advance)
	M.now = M.now + (advance or 10)
	local guard = 0
	while true do
		local due
		for i, t in ipairs(M.timers) do if t.at <= M.now then due = i; break end end
		if not due then break end
		local t = table.remove(M.timers, due)
		t.fn()
		guard = guard + 1
		if guard > 500 then error("timer storm") end
	end
end
function M.Tick(n)
	for _ = 1, (n or 1) do
		M.now = M.now + 0.6
		for _, t in ipairs(M.tickers) do if not t.cancelled then t.fn() end end
	end
end
function M.Chat() return M.chat or {} end

CreateFromMixins = function(...)
	local o = {}
	for i = 1, select("#", ...) do
		local m = select(i, ...)
		if type(m) == "table" then for k, v in pairs(m) do o[k] = v end end
	end
	return o
end
MapCanvasPinMixin = {
	SetPosition = function(self, x, y) self._px, self._py = x, y end,
	UseFrameLevelType = function(self, level) self.pinFrameLevelType = level end, SetScalingLimits = noop,
	ShouldMouseButtonBePassthrough = function(_, button) return button == "RightButton" end,
	CheckMouseButtonPassthrough = function(self, button)
		if self:ShouldMouseButtonBePassthrough(button) then self:SetPassThroughButtons(button)
		else self:SetPassThroughButtons() end
	end,
}
MapCanvasDataProviderMixin = {
	OnAdded = function(self, map) self._map = map end,
	GetMap = function(self) return self._map end,
}
WorldMapFrame = M.NewFrame("Frame", "WorldMapFrame")
WorldMapFrame._providers = {}
WorldMapFrame._pins = {}
WorldMapFrame.AddDataProvider = function(self, p) p:OnAdded(self); table.insert(self._providers, p) end
WorldMapFrame.GetMapID = function() return M.mapID end
WorldMapFrame.RemoveAllPinsByTemplate = function(self, template)
	for i=#self._pins,1,-1 do if self._pins[i]._pinTemplate == template then table.remove(self._pins,i) end end
end
WorldMapFrame.AcquirePin = function(self, template, ...)
	local pin = M.NewFrame("Frame", nil, self, template)
	pin.Icon = M.NewFrame("Texture")
	pin._pinTemplate = template
	for k, v in pairs(template == "HearthAndHustleObjectivePinTemplate" and HearthAndHustleObjectivePinMixin or HearthAndHustleMapPinMixin) do pin[k] = v end
	pin:OnLoad()
	pin:OnAcquired(...)
	pin:CheckMouseButtonPassthrough("RightButton")
	table.insert(self._pins, pin)
	return pin
end
C_Texture = { GetAtlasInfo = function() return {} end }

-- units
function M.SetUnit(unit, info) M.units[unit] = info end
UnitExists = function(unit) return M.units[unit] ~= nil end
UnitGUID = function(unit) local u = M.units[unit]; if u and u.secret then return M.Secret() end return u and u.guid end
UnitName = function(unit) if unit == "player" then return "Chiznooch" end local u = M.units[unit]; if u and u.secret then return M.Secret() end return u and u.name, u and u.realm end
UnitLevel = function(unit) if unit == "player" then return M.level or 20 end return M.units[unit] and M.units[unit].level end
UnitIsPlayer = function(unit) if unit == "player" then return true end return M.units[unit] and M.units[unit].player or false end
UnitIsDead = function(unit) return M.units[unit] and M.units[unit].dead or false end
UnitIsDeadOrGhost = function() return false end
UnitClassification = function(unit) return M.units[unit] and M.units[unit].classification or "normal" end
UnitCreatureType = function(unit) return M.units[unit] and M.units[unit].ctype or "Humanoid" end
UnitReaction = function(_, unit) return M.units[unit] and M.units[unit].reaction or 2 end
UnitClass = function(unit) if unit ~= "player" and M.units[unit] and M.units[unit].class then local c = M.units[unit].class; return c:sub(1,1) .. c:sub(2):lower(), c end local c = M.class or "MAGE"; return c:sub(1,1) .. c:sub(2):lower(), c end
UnitRace = function(unit) if unit ~= "player" and M.units[unit] and M.units[unit].race then return M.units[unit].race, M.units[unit].race end return "Blood Elf", "BloodElf" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitCanAttack = function(_, unit) return M.units[unit] and M.units[unit].canAttack or false end
UnitIsPVP = function() return true end
PLAYER_FACTION_GROUP = { [0] = "Horde", [1] = "Alliance" }
RAID_CLASS_COLORS = { PRIEST = { colorStr = "ffffffff" }, MAGE = { colorStr = "ff3fc7eb" }, HUNTER = { colorStr = "ffaad372" } }
UnitXP = function() return M.xp or 12000 end
UnitXPMax = function() return 17000 end
GetXPExhaustion = function() return 3000 end
GetRealmName = function() return "Classic Beta PvP 2" end
GetRealZoneText = function() return "The Barrens" end
GetSubZoneText = function() return "The Crossroads" end
GetPlayerFacing = function() return M.facing end
GetBindLocation = function() return "The Crossroads" end

-- map: fake linear world, x=north, y=west, 10000 yd square
local W = 10000
C_Map = {
	GetBestMapForUnit = function() return M.mapID end,
	GetPlayerMapPosition = function(mapID) if M.noPosition then return nil end return vec(M.px, M.py) end,
	GetWorldPosFromMapPos = function(mapID, v) return 1, vec(W - v.y * W, W - v.x * W) end,
	GetMapPosFromWorldPos = function(c, v, mapID) return mapID or M.mapID, vec((W - v.y) / W, (W - v.x) / W) end,
	GetMapInfo = function(id) return { mapID = id, name = (id == 1413 and "The Barrens" or ("Map " .. id)), mapType = 3, parentMapID = 1414 } end,
	GetMapWorldSize = function() return W, W end,
	CanSetUserWaypointOnMap = function() return true end,
	SetUserWaypoint = function() return true end,
	ClearUserWaypoint = noop,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m, x, y } end }
C_Minimap = { GetViewRadius = function() return 233.3 end }
C_CVar = { GetCVarBool = function() return M.rotateMinimap or false end }

-- quest log
function M.AddQuest(q) table.insert(M.quests, q) end
function M.RemoveQuest(id) for i, q in ipairs(M.quests) do if q.questID == id then table.remove(M.quests, i) return end end end
local function questByID(id) for _, q in ipairs(M.quests) do if q.questID == id then return q end end end
C_QuestLog = {
	GetNumQuestLogEntries = function() return #M.quests + 1, #M.quests end,
	GetInfo = function(i)
		if i == 1 then return { isHeader = true, title = "The Barrens" } end
		local q = M.quests[i - 1]
		if not q then return nil end
		return { questID = q.questID, title = q.title, level = q.level or 20, difficultyLevel = q.level or 20, suggestedGroup = q.suggestedGroup or 0, isHeader = false, isHidden = false, questLogIndex = i }
	end,
	GetQuestObjectives = function(id) local q = questByID(id); return q and q.objectives or {} end,
	ReadyForTurnIn = function(id) return M.complete[id] and true or false end,
	IsComplete = function(id) return M.complete[id] and true or false end,
	IsOnQuest = function(id) return questByID(id) ~= nil end,
	GetLogIndexForQuestID = function(id) for i, q in ipairs(M.quests) do if q.questID == id then return i + 1 end end return nil end,
	GetTitleForQuestID = function(id) local q = questByID(id); return q and q.title or nil end,
	GetAllCompletedQuestIDs = function() return { 1, 2, 3 } end,
	IsQuestFlaggedCompleted = function() return false end,
	GetQuestsOnMap = function(mapID) return M.pois or {} end,
	GetNextWaypoint = function(id) local q = questByID(id); if q and q.waypoint then return q.waypoint[1], q.waypoint[2], q.waypoint[3] end return nil end,
	GetNextWaypointForMap = function() return nil end,
	GetDistanceSqToQuest = function() return 250000, true end,
	GetQuestDifficultyLevel = function() return 20 end,
	RequestLoadQuestByID = noop,
}
GetQuestLogRewardXP = function() return 1200, 1200 end
HaveQuestRewardData = function() return true end
GetQuestLogRewardMoney = function() return 500 end
GetQuestID = function() return M.dialogQuest end
GetTitleText = function() local q = questByID(M.dialogQuest); return q and q.title or "Offered Quest" end
GetObjectiveText = function() return "Bring 8 Quilboar Tusks to Mankrik." end
GetQuestText = function() return "Long quest text." end
GetRewardXP = function() return 1200 end
GetRewardMoney = function() return 500 end
GetSuggestedGroupSize = function() return 0 end
QuestGetAutoAccept = function() return false end
GetNumQuestRewards = function() return 1 end
GetNumQuestChoices = function() return 0 end
GetQuestItemInfo = function() return "Quilboar Sword", 1, 1, 2, true, 5555 end
GetQuestItemLink = function() return "|cff1eff00|Hitem:5555:0:0:0|h[Quilboar Sword]|h|r" end
C_GossipInfo = {
	GetAvailableQuests = function() return M.gossipAvailable or {} end,
	GetActiveQuests = function() return M.gossipActive or {} end,
	GetOptions = function() return { { name = "I want to train." } } end,
}
C_Item = { GetItemInfo = function(id) return "Item " .. id end, GetItemCount = function() return M.itemCount or 5 end, RequestLoadItemDataByID = noop }
C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
GetNumLootItems = function() return M.lootSlots and #M.lootSlots or 0 end
GetLootSlotInfo = function(i) local s = M.lootSlots[i]; return 1, s.name, s.qty, nil, 1, false, s.quest or false, s.questID, true end
GetLootSlotLink = function(i) local s = M.lootSlots[i]; return "|Hitem:" .. s.itemID .. ":0|h[" .. s.name .. "]|h" end
GetLootSlotType = function() return 1 end
GetLootSourceInfo = function(i) return M.lootSource, M.lootSlots[i].qty end
GetMerchantNumItems = function() return 2 end
C_MerchantFrame = { GetItemInfo = function(i) return { name = "Vendor item " .. i, price = 120 * i, stackCount = 1, numAvailable = -1, hasExtendedCost = false } end }
GetMerchantItemLink = function(i) return "|Hitem:" .. (2320 + i) .. ":0|h[x]|h" end
GetNumTrainerServices = function() return 2 end
GetTrainerServiceInfo = function(i) return (i == 1 and "Azure Silk Hood" or "Spidersilk Boots"), "available", 1, 0, "" end
GetTrainerServiceSkillReq = function(i) return "Tailoring", 100 + i * 10, true end
GetTrainerServiceCost = function() return 500, true end
GetTrainerServiceSkillLine = function() return "Tailoring" end
IsTradeskillTrainer = function() return true end
GetTaxiMapID = function() return 1413 end
C_TaxiMap = { GetAllTaxiNodes = function() return {
	{ nodeID = 22, position = vec(0.51, 0.30), name = "Crossroads, The Barrens", state = 0, slotIndex = 1 },
	{ nodeID = 23, position = vec(0.40, 0.10), name = "Orgrimmar", state = 1, slotIndex = 2 },
	{ nodeID = 24, position = vec(0.20, 0.90), name = "Ratchet", state = 2, slotIndex = 3 },
} end }
TaxiNodeCost = function(slot) return 110 * slot end
GetProfessions = function() return 1, 2, nil, nil, nil end
GetProfessionInfo = function(idx) if idx == 1 then return "Tailoring", 1, 108, 150, 0, 0, 197 end return "Enchanting", 1, 103, 150, 0, 0, 333 end
C_TradeSkillUI = {
	GetChildProfessionInfo = function() return { professionID = 197, professionName = "Tailoring", skillLevel = 108, maxSkillLevel = 150, parentProfessionID = 197, parentProfessionName = "Tailoring" } end,
	GetFilteredRecipeIDs = function() return { 3839, 8760 } end,
	GetRecipeInfo = function(id) return { recipeID = id, name = "Recipe " .. id, learned = true, relativeDifficulty = (id == 3839) and 0 or 1, numSkillUps = 1, categoryID = 1, icon = 1 } end,
	GetRecipeSchematic = function(id) return { outputItemID = id + 100, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = { { reagents = { { itemID = 4306 } }, quantityRequired = 4, required = true } } } end,
}
M.sounds = {}
PlaySoundFile = function(path, channel) table.insert(M.sounds, { path = path, channel = channel }); return true, #M.sounds end
C_Spell = {
	GetSpellName = function(id) return ({ [2643] = "Multi-Shot", [14288] = "Multi-Shot", [136] = "Mend Pet", [3111] = "Mend Pet", [1978] = "Serpent Sting", [118] = "Polymorph", [2139] = "Counterspell", [122] = "Frost Nova", [19503] = "Scatter Shot" })[id] end,
	GetSpellDescription = function(id) return ({ [118] = "Transforms the enemy into a sheep, forcing it to wander around for up to 20 sec.", [2139] = "Counters the enemy's spellcast, preventing any spell from that school of magic from being cast for 10 sec.", [122] = "Blasts enemies near the caster for 19 to 22 Frost damage and freezes them in place for up to 8 sec." })[id] or "" end,
	GetSpellTexture = function(id) return 100000 + (id or 0) end,
}
C_RestrictedActions = { IsAddOnRestrictionActive = function(t) return M.restrictions and M.restrictions[t] or false end, GetAddOnRestrictionState = function() return 0 end }
C_Secrets = { HasSecretRestrictions = function() return true end, ShouldAurasBeSecret = function() return M.inCombat or false end, ShouldCooldownsBeSecret = function() return M.inCombat or false end,
	ShouldUnitIdentityBeSecret = function(u) return false end, ShouldUnitSpellCastingBeSecret = function(u) return u ~= "player" end }
C_PvP = { IsBattleground = function() return M.bg or false end, GetActiveMatchState = function() return M.bg and 3 or 0 end, GetZonePVPInfo = function() return "contested", false, nil end,
	GetBattlefieldFlagPosition = function(i, mapID) local f = M.flags and M.flags[i]; if f then return f.x, f.y, f.tex end return nil end,
	GetScoreInfo = function(i) local sc = M.scores and M.scores[i]; return sc end }
GetNumBattlefieldFlagPositions = function() return M.flags and #M.flags or 0 end
GetNumBattlefieldScores = function() return M.scores and #M.scores or 0 end
C_AreaPoiInfo = { GetAreaPOIForMap = function() local ids = {}; for id in pairs(M.pois or {}) do ids[#ids+1] = id end table.sort(ids) return ids end,
	GetAreaPOIInfo = function(mapID, id) local p = M.pois[id]; return p and { areaPoiID = id, name = p.name, description = p.desc, atlasName = p.atlas, textureIndex = p.tex, position = vec(p.x, p.y) } or nil end,
	IsAreaPOITimed = function(id) return M.pois[id] and M.pois[id].secs ~= nil end, GetAreaPOISecondsLeft = function(id) return M.pois[id].secs end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
UnitAffectingCombat = function() return M.inCombat or false end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 50 end
UnitCastingInfo = function() return nil end
M.addonSent = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end, SendAddonMessage = function(prefix, msg) table.insert(M.addonSent, msg); return 0 end, InChatMessagingLockdown = function() return M.lockdown or false end }


-------------------------------------------------------------------------------
-- v0.8.0 vendor / status stubs. Bag functions are installed by M.EnableBags()
-- so earlier scenarios keep their "bag reads unavailable" behaviour.
-------------------------------------------------------------------------------
Enum = Enum or {}
Enum.ItemQuality = Enum.ItemQuality or { Poor = 0, Common = 1, Uncommon = 2 }
Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1, Unit = 2 }
INVSLOT_AMMO, INVSLOT_MAINHAND, INVSLOT_OFFHAND = 0, 16, 17
SELL_PRICE = "Sell Price:"
GetMoney = function() return M.money or 123456 end
GetRepairAllCost = function() local c = M.repairCost or 0; return c, c > 0 end
CanMerchantRepair = function() return M.canRepair ~= false end
RepairAllItems = function() M.repaired = (M.repaired or 0) + 1; M.money = (M.money or 123456) - (M.repairCost or 0); M.repairCost = 0 end
GetInventoryItemDurability = function(slot) local d = M.durability and M.durability[slot]; if d then return d[1], d[2] end return nil end
UnitUsesAmmo = function() return M.usesAmmo or false end
GetInventoryItemCount = function(_, slot) if slot == 0 then return M.ammoCount or 0 end return 1 end
GetInventoryItemID = function(_, slot) return M.invIDs and M.invIDs[slot] or nil end
GetFramerate = function() return M.fps or 60 end
GetNetStats = function() return 0, 0, 40, 55 end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) if M.auras and M.auras[id] then return { spellId = id } end return nil end
C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return M.imbues and M.imbues[slot] or nil end }
M.tooltipHooks = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) table.insert(M.tooltipHooks, { kind = kind, fn = fn }) end }
TooltipUtil = { GetDisplayedItem = function(tt) if tt._item then return "name", tt._item.link, tt._item.id end end }
function Frame:AddDoubleLine(l, r) self._lines = self._lines or {}; table.insert(self._lines, { l, r }) end
function Frame:NumLines() return 0 end
function Frame:GetName() return self._name end
function Frame:GetStringWidth() return 600 end
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:IsEnabled() return self._enabled ~= false end
function Frame:SetID(id) self._id = id end
function Frame:GetID() return self._id or 0 end
ItemRefTooltip = M.NewFrame("GameTooltip", "ItemRefTooltip")
MerchantFrame = M.NewFrame("Frame", "MerchantFrame"); MerchantFrame:Hide()
hooksecurefunc = function(name, fn) local orig = _G[name]; _G[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end end
QuestInfoFrame = { rewardsFrame = { RewardButtons = {} } }
QuestInfo_ShowRewards = function() end
M.questChoices = {}
GetNumQuestChoices = function() return #M.questChoices end
GetQuestItemLink = function(kind, i) if kind == "choice" and M.questChoices[i] then return "|cff1eff00|Hitem:" .. M.questChoices[i] .. ":0:0:0|h[x]|h|r" end return "|cff1eff00|Hitem:5555:0:0:0|h[Quilboar Sword]|h|r" end
-- M.items[id] = { name, quality, stack, price, class, sub }; others keep the name-only fallback.
M.items = {}
local baseGetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
	local key = type(id) == "string" and tonumber(id:match("item:(%d+)")) or id
	local it = M.items[key]
	if it then return it[1], "link", it[2], 1, 1, "type", "subtype", it[3], "", 123, it[4], it[5] or 15, it[6] or 1 end
	return baseGetItemInfo(id)
end
function M.EnableBags(bags)
	M.bags = bags
	M.sold = {}
	C_Container.GetContainerNumSlots = function(bag) return #(M.bags[bag] or {}) end
	C_Container.GetContainerItemInfo = function(bag, slot)
		local i = M.bags[bag] and M.bags[bag][slot]
		if not i then return nil end
		local it = M.items[i[1]] or {}
		return { itemID = i[1], stackCount = i[2], quality = it[2], hasNoValue = i.noValue or false, hyperlink = "|Hitem:" .. i[1] .. ":0|h[x]|h", isLocked = false }
	end
	C_Container.UseContainerItem = function(bag, slot)
		if not MerchantFrame:IsShown() then error("UseContainerItem outside a merchant") end
		table.insert(M.sold, M.bags[bag][slot][1]); table.remove(M.bags[bag], slot)
	end
end

return M
