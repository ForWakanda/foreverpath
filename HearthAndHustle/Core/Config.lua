-- HearthAndHustle / Core / Config.lua
-- SavedVariables are created inside ADDON_LOADED (never at file scope).
local ADDON, FP = ...
local U = FP.Util

FP.DB_VERSION = 2

local function deepDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then target[k] = {} end
			deepDefaults(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
	return target
end
FP.deepDefaults = deepDefaults

FP.defaults = {
	settings = {
		debug = false,
		record = false,
		recordQuestText = false,     -- long quest descriptions are opt-in
		autoNext = true,             -- when a waypoint is done, arrow moves to the next planned step
		nearestFirst = true,
		arriveRadius = 15,
		minimapPin = true,
		worldMapPins = true,
		questWorldPins = true,
		questMinimapPins = true,
		questSelectedOnly = false,
		questEventHints = true,
		questContactPins = true,
		questMapLegend = true,
		questDensePins = false,
		arrow = { shown = true, locked = false, scale = 1.0, flip = false, x = 0, y = 180, point = "CENTER" },
		panel = { shown = true, locked = false, scale = 1.0, x = -20, y = -160, point = "TOPRIGHT", maxSteps = 10 },
		hub = { point = "CENTER", x = 0, y = 0 },
		probe = { enabled = false },                        -- beta diagnostic: records which values are secret and when
		pvp = { enabled = true, share = true, trackFlag = false, locked = false, scale = 1.0, x = 30, y = 120, point = "LEFT" },
		rare = { enabled = true, share = true, sound = true, locked = false, scale = 1.0, x = 0, y = -200, point = "TOP" },   -- dungeon rare watch (/hh rare)
		vendor = { enabled = true, tooltipPrice = true, rewardValues = true },   -- merchant strip, tooltip value, quest reward value (/hh vendor)
		bar = { shown = true, locked = false, scale = 1.0, x = 0, y = -4, point = "TOP", fps = true },   -- status line (/hh bar)
		reminders = { enabled = true, buffs = true, durability = 20, ammo = 200 },   -- out-of-combat reminders (/hh remind)
		trainer = { enabled = true },   -- trainer notes (/hh trainer)
	},
	data = {
		quests = {}, npcs = {}, creatures = {}, objects = {}, items = {},
		vendors = {}, trainers = {}, taxi = { nodes = {}, edges = {} }, binds = {},
		progress = {}, deaths = {}, zones = {}, recipes = {}, chars = {}, xp = {}, lootObservations = {}, pvp = { players = {} }, bg = {},
	},
	meta = { created = 0, builds = {}, counters = {} },
	apicheck = {},
	errors = {},
}

FP.charDefaults = {
	gear = { weights = {}, wishlist = {} },
	prep = { enabled = true, mode = "auto", food = 20, water = 40, bandages = 10, reagents = 5, supplies = {} },
	waypoints = {},
	activeId = nil,
	nextId = 1,
	completed = {},
	levels = {},
	professions = {},
	bind = {},
	party = {},
	lastRoute = {},
	lootSeen = {},
}

-- Renamed from "ForeverPath" in v0.17.0. A SavedVariables file copied to the new
-- name still defines the old globals, so adopt them once. An unrelated addon now
-- uses that name and the same variable names: only a table with OUR schema counts.
local function legacyAccount(db)
	return type(db) == "table" and type(db.settings) == "table" and type(db.settings.arrow) == "table"
		and type(db.data) == "table" and type(db.data.quests) == "table" and type(db.meta) == "table"
end
local function legacyCharacter(db)
	return type(db) == "table" and type(db.waypoints) == "table" and type(db.completed) == "table" and U.Finite(db.nextId)
end
local function deepCopy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do copy[deepCopy(k, seen)] = deepCopy(v, seen) end
	return copy
end
local function adoptLegacy()
	local account, character = rawget(_G, "ForeverPathDB"), rawget(_G, "ForeverPathCharDB")
	local oldLoaded = FP.API and FP.API.IsAddOnLoaded and FP.API.IsAddOnLoaded("ForeverPath")
	local adopted
	-- While the old addon is still running it keeps writing its tables: take a copy.
	if HearthAndHustleDB == nil and legacyAccount(account) then
		HearthAndHustleDB = oldLoaded and deepCopy(account) or account; adopted = true
	end
	-- Character data belongs with the account data it was recorded beside.
	if HearthAndHustleCharDB == nil and legacyCharacter(character) and legacyAccount(account) then
		HearthAndHustleCharDB = oldLoaded and deepCopy(character) or character; adopted = true
	end
	if adopted then FP.migratedFrom = oldLoaded and "ForeverPath (still installed)" or "ForeverPath" end
end

local function onAddonLoaded(event, name)
	if name ~= ADDON then return end
	adoptLegacy()
	HearthAndHustleDB = HearthAndHustleDB or {}
	HearthAndHustleCharDB = HearthAndHustleCharDB or {}
	FP.db = deepDefaults(HearthAndHustleDB, FP.defaults)
	FP.cdb = deepDefaults(HearthAndHustleCharDB, FP.charDefaults)
	FP.settings = FP.db.settings
	-- Retired custom Hunter sounds must not return from an older saved profile.
	FP.settings.hunterAudio = nil
	FP.data = FP.db.data
	if FP.db.meta.created == 0 then FP.db.meta.created = U.Now() end
	if FP.clientBuild then
		FP.db.meta.builds[tostring(FP.clientBuild)] = U.Now()
	end
	if (FP.db.version or 0) < FP.DB_VERSION then
		if FP.cdb.party.from == "paste" then FP.cdb.party.mode = "paste" end
		-- Preserve v0.1 observations, but never mix known-biased totals/guesses
		-- into the corrected dataset. No history is deleted.
		for _, entities in ipairs({ FP.data.creatures, FP.data.objects }) do
			for _, entity in pairs(entities) do
				if next(entity.loot or {}) then entity.legacyLootV1, entity.loot = entity.loot, {} end
				if entity.looted then entity.legacyLootedV1, entity.looted = entity.looted, 0 end
				if entity.count then entity.legacyCountV1, entity.count = entity.count, 0 end
				for _, p in ipairs(entity.pos or {}) do p.observer, p.source = true, "legacy-observer" end
			end
		end
		for _, q in pairs(FP.data.quests) do
			if q.items then q.legacyItemsV1, q.items = q.items, nil end
			for _, o in pairs(q.obj or {}) do
				if o.mobs then o.legacyMobCandidatesV1, o.mobs = o.mobs, nil end
				if o.src then o.legacySourceCandidatesV1, o.src = o.src, nil end
			end
		end
		FP.db.version = FP.DB_VERSION
	end
	FP.dbReady = true
	FP:InitModules()
	FP:Fire("DB_READY")
end
FP:RegisterEvent("ADDON_LOADED", onAddonLoaded)

for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do
 local kind=event
 FP:RegisterEvent(kind,function(_,addon,action)
  addon,action=FP.safe(addon),FP.safe(action)
  if addon==ADDON then FP:ReportError(kind,tostring(action or "unknown action")) end
 end)
end

FP:RegisterEvent("PLAYER_LOGIN", function()
	if not FP.dbReady then return end
	FP:EnableModules()
	FP:Fire("ENABLED")
	FP:Print("v" .. FP.version .. " loaded on build " .. tostring(FP.clientBuild) .. ". " .. FP.GREY .. "Open Hearth & Hustle from the addon compartment or /hh.|r")
	if FP.migratedFrom == "ForeverPath" then
		FP:Print("Formerly ForeverPath: your settings and recorded data were carried over. Commands are now /hh and /hustle.")
	elseif FP.migratedFrom then
		FP:Print(FP.RED .. "The old ForeverPath folder is still installed.|r Your data was copied. Log out, delete Interface\\AddOns\\ForeverPath, then log back in.")
	end
end)
