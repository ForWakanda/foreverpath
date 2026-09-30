-- ForeverPath / Core / Config.lua
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
		record = true,
		recordQuestText = false,     -- long quest descriptions are opt-in
		autoNext = true,             -- when a waypoint is done, arrow moves to the next planned step
		nearestFirst = true,
		arriveRadius = 15,
		minimapPin = true,
		worldMapPins = true,
		arrow = { shown = true, locked = false, scale = 1.0, flip = false, x = 0, y = 180, point = "CENTER" },
		panel = { shown = true, locked = false, scale = 1.0, x = -20, y = -160, point = "TOPRIGHT", maxSteps = 10 },
		hunterAudio = { enabled = true, cooldown = 30 },   -- Hunter combat audio feedback (Hunters only)
		probe = { enabled = true },                        -- beta diagnostic: records which values are secret and when
		pvp = { enabled = true, share = true, trackFlag = false, locked = false, scale = 1.0, x = 30, y = 120, point = "LEFT" },
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

local function onAddonLoaded(event, name)
	if name ~= ADDON then return end
	ForeverPathDB = ForeverPathDB or {}
	ForeverPathCharDB = ForeverPathCharDB or {}
	FP.db = deepDefaults(ForeverPathDB, FP.defaults)
	FP.cdb = deepDefaults(ForeverPathCharDB, FP.charDefaults)
	FP.settings = FP.db.settings
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

FP:RegisterEvent("PLAYER_LOGIN", function()
	if not FP.dbReady then return end
	FP:EnableModules()
	FP:Fire("ENABLED")
	FP:Print("v" .. FP.version .. " loaded on build " .. tostring(FP.clientBuild) .. ". " .. FP.GREY .. "/fp for the panel, /fp help for commands.|r")
end)
