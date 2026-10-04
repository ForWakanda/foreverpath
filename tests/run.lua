-- Loads the addon in TOC order under the mock and drives a play session.
package.path = "./tests/?.lua;" .. package.path
local M = require("wowmock")
M.verbose = os.getenv("VERBOSE") ~= nil
local ADDON = "ForeverPath"
local FP = {}

local files = {}
for line in io.lines("ForeverPath/ForeverPath.toc") do
	line = line:gsub("\r", "")
	if line:match("%.lua$") then files[#files + 1] = "ForeverPath/" .. line:gsub("\\", "/") end
end
for _, path in ipairs(files) do
	local chunk, err = loadfile(path)
	assert(chunk, err)
	chunk(ADDON, FP)
end
print(string.format("loaded %d files", #files))

local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end end
local function errorsEmpty(stage)
	local errs = FP.db and FP.db.errors or {}
	if #errs > 0 then
		for _, e in ipairs(errs) do print("  addon error @" .. e.where .. ": " .. e.err) end
		error("addon reported errors during " .. stage)
	end
end

-- Login
M.AddQuest({ questID = 1234, title = "Lost in Battle", level = 20, objectives = { { text = "Mankrik's Wife found: 0/1", type = "object", finished = false, numFulfilled = 0, numRequired = 1 } } })
M.AddQuest({ questID = 1235, title = "Raptor Horns", level = 21, objectives = { { text = "Raptor Horn: 0/6", type = "item", finished = false, numFulfilled = 0, numRequired = 6 } }, waypoint = { 1413, 0.55, 0.45 } })
M.pois = { { questID = 1234, x = 0.40, y = 0.60, isQuestStart = false, inProgress = true, numObjectives = 1 } }
M.FireEvent("ADDON_LOADED", ADDON)
check(FP.dbReady, "db ready")
M.FireEvent("PLAYER_LOGIN")
check(FP.enabled, "modules enabled")
M.RunTimers(10)
errorsEmpty("login")

-- Self test
local ok, pass, fail = FP.SelfTest:Run(true)
check(ok, "selftest failed: " .. fail)
print(string.format("selftest: %d passed", pass))

-- API check under the mock
local rows = FP.API.Check()
local missing = 0
for _, r in ipairs(rows) do if not r.ok then missing = missing + 1; if M.verbose then print("  missing: " .. r.name .. " " .. tostring(r.note)) end end end
print(string.format("apicheck: %d rows, %d missing under mock", #rows, missing))

-- Planner: auto-next should have set a plan waypoint (login timer)
check(#FP.Waypoints.list == 1, "auto-next created a waypoint, got " .. #FP.Waypoints.list)
check(not FP.Waypoints.list[1].title:find("0/1 0/1"), "objective text not doubled: " .. FP.Waypoints.list[1].title)
local active = FP.Waypoints:GetActive()
check(active.source and active.source.type == "plan", "active is a plan waypoint")
print("auto-next: " .. active.title .. " @ " .. FP.Util.FormatCoords(active.x, active.y))

-- Arrow + minimap math on the ticker
M.Tick(3)
FP.Arrow:OnUpdate(0.1)
check(FP.Arrow.dist._text ~= nil and FP.Arrow.dist._text ~= "?", "arrow distance text: " .. tostring(FP.Arrow.dist._text))
check(type(FP.Arrow.tex._rotation) == "number", "arrow rotation set")
FP.Pins:UpdateMinimap(FP.Pos.cache)
check(FP.Pins.mini:IsShown(), "minimap pin shown")
print("arrow: " .. FP.Arrow.dist._text .. " rot " .. string.format("%.2f", FP.Arrow.tex._rotation))

-- World map provider
check(FP.Pins.provider ~= nil, "world map provider registered")
FP.Pins.provider:RefreshAllData()
check(#WorldMapFrame._pins == 1, "one world map pin, got " .. #WorldMapFrame._pins)
WorldMapFrame._pins[1]:OnMouseEnter(); WorldMapFrame._pins[1]:OnMouseLeave()

-- Commands
local function cmd(s) SlashCmdList.FOREVERPATH(s) end
cmd("status"); cmd("help"); cmd("apicheck")
cmd("way 47.2 61.8 Test spot")
check(#FP.Waypoints.list == 2, "manual waypoint added")
cmd("way list"); cmd("way next"); cmd("arrow flip"); cmd("arrow flip"); cmd("arrow scale 1.2"); cmd("panel reset")
cmd("goto raptor")
errorsEmpty("commands")

-- Recorder: talk to Mankrik, get a quest, kill a quilboar, loot, progress
M.SetUnit("npc", { guid = "Creature-0-4379-1-13-3446-00003BB8D2", name = "Mankrik", level = 25, reaction = 5 })
M.gossipAvailable = { { questID = 1236, title = "Consumed by Hatred", questLevel = 21, isTrivial = false, frequency = 1, repeatable = false } }
M.gossipActive = { { questID = 1234, title = "Lost in Battle", questLevel = 20, isComplete = false } }
M.FireEvent("GOSSIP_SHOW")
check(FP.data.npcs[3446] and FP.data.npcs[3446].n == "Mankrik", "npc recorded")
check(FP.data.quests[1236] and FP.data.quests[1236].givers[3446], "offer recorded with giver")
check(FP.data.quests[1234].enders[3446], "active quest ender recorded")
M.dialogQuest = 1236
M.FireEvent("QUEST_DETAIL", 0)
check(FP.data.quests[1236].xp["20"] == 1200 and FP.data.quests[1236].rew[1] == 5555, "offer xp + reward item recorded")
M.AddQuest({ questID = 1236, title = "Consumed by Hatred", level = 21, objectives = { { text = "Razormane Quilboar slain: 0/8", type = "monster", finished = false, numFulfilled = 0, numRequired = 8 } } })
M.FireEvent("QUEST_ACCEPTED", 1236)
M.RunTimers(3)
check(FP.data.quests[1236].log[1].acc, "accept logged")
M.SetUnit("npc", nil)

M.SetUnit("target", { guid = "Creature-0-4379-1-13-3396-00003BB8E0", name = "Razormane Quilboar", level = 19, reaction = 2 })
M.FireEvent("PLAYER_TARGET_CHANGED")
check(FP.data.creatures[3396] and FP.data.creatures[3396].n == "Razormane Quilboar", "creature sighting recorded")
M.units.target.dead = true
M.FireEvent("PLAYER_TARGET_DIED")
M.FireEvent("CHAT_MSG_COMBAT_XP_GAIN", "Razormane Quilboar dies, you gain 85 experience.")
check(FP.data.creatures[3396].kills == 1 and FP.data.creatures[3396].xp["20"] == 85, "kill + xp recorded")
local q = nil
for _, qq in ipairs(M.quests) do if qq.questID == 1236 then q = qq end end
q.objectives[1].numFulfilled = 1
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(1)
check(#FP.data.progress == 1 and FP.data.progress[1].killCandidates[1] == 3396 and FP.data.progress[1].kill == nil and FP.data.progress[1].q == 1236, "progress keeps a kill candidate without claiming attribution")
check(not FP.data.quests[1236].obj[1].mobs, "temporal candidate must not become confirmed objective -> mob")
M.lootSlots = { { name = "Silk Cloth", qty = 2, itemID = 4306 }, { name = "Quilboar Tusk", qty = 1, itemID = 5001, quest = true, questID = 1236 } }
M.lootSource = "Creature-0-4379-1-13-3396-00003BB8E0"
M.FireEvent("LOOT_OPENED", false, false)
check(FP.data.creatures[3396].loot[4306] == 2 and FP.data.creatures[3396].looted == 1, "loot recorded on creature")
check(FP.data.quests[1236].items[5001][3396] == 1, "quest item source recorded")
M.FireEvent("LOOT_OPENED", false, false)
check(FP.data.creatures[3396].looted == 1 and FP.data.creatures[3396].loot[4306] == 2, "same corpse and items not double counted")
M.SetUnit("target", nil)

-- vendor / trainer / taxi / inn / misc
M.SetUnit("npc", { guid = "Creature-0-4379-1-13-3881-00003BB8F0", name = "Innkeeper Boorand", level = 30, reaction = 5 })
M.FireEvent("MERCHANT_SHOW")
check(FP.data.vendors[3881] and FP.data.vendors[3881].items[2321].p == 120, "vendor recorded")
M.FireEvent("CONFIRM_BINDER", "The Crossroads")
M.FireEvent("HEARTHSTONE_BOUND")
check(FP.cdb.bind.area == "The Crossroads" and FP.cdb.bind.m == 1413, "bind recorded")
M.SetUnit("npc", { guid = "Creature-0-4379-1-13-3704-00003BB8F1", name = "Devrak", level = 30, reaction = 5 })
M.FireEvent("TAXIMAP_OPENED", 1)
check(FP.data.taxi.nodes[22] and FP.data.taxi.nodes[22].npc == 3704, "taxi node + flight master")
check(FP.data.taxi.edges["22>23"] and FP.data.taxi.edges["22>23"].cost == 220, "taxi edge with cost")
M.SetUnit("npc", { guid = "Creature-0-4379-1-13-3704-00003BB8F9", name = "Mahani", level = 30, reaction = 5 })
M.FireEvent("TRAINER_SHOW")
M.RunTimers(1)
check(FP.data.trainers[3704] and FP.data.trainers[3704].services["Azure Silk Hood"].rank == 110, "trainer services recorded")
M.FireEvent("PLAYER_XP_UPDATE", "player")
M.level = 21
M.FireEvent("PLAYER_LEVEL_UP", 21)
check(FP.cdb.levels["21"] ~= nil, "level up recorded")
M.FireEvent("PLAYER_DEAD")
check(#FP.data.deaths == 1, "death recorded")
M.FireEvent("ZONE_CHANGED_NEW_AREA")
check(FP.data.zones["The Barrens"] and FP.data.zones["The Barrens"].m == 1413, "zone recorded")
M.FireEvent("TRADE_SKILL_SHOW")
M.RunTimers(3)
check(FP.data.recipes[197] and FP.data.recipes[197].r[3839].reag[4306] == 4, "recipe + reagents recorded")
cmd("prof")
errorsEmpty("recorder")

-- Completing and turning in
M.complete[1236] = true
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(2)
FP.Planner:Build()
check(FP.Planner.steps[1].kind == "turnin" and FP.Planner.steps[1].questID == 1236, "complete quest ranks first as turn-in: " .. tostring(FP.Planner.steps[1].title))
-- 1236 has no recorded ender yet -> falls back to the giver (most Classic quests return to the giver)
check(FP.Planner.steps[1].how == "giver", "turn-in falls back to giver, got " .. tostring(FP.Planner.steps[1].how))
-- 1234's ender (Mankrik) was recorded from the gossip active-quest list
local m, x, y, how = FP.Planner:ResolveTurnIn(1234)
check((how == "recorded" or how == "npc") and m == 1413, "recorded ender resolves to a recorded position, got " .. tostring(how))
M.SetUnit("npc", { guid = "Creature-0-4379-1-13-3446-00003BB8D2", name = "Mankrik", level = 25, reaction = 5 })
M.dialogQuest = 1236
M.FireEvent("QUEST_COMPLETE")
M.FireEvent("QUEST_TURNED_IN", 1236, 1350, 800)
M.RemoveQuest(1236)
M.complete[1236] = nil
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(3)
check(FP.data.quests[1236].xp["21"] == 1350 and FP.data.quests[1236].money == 800, "turn-in xp/money recorded")
check(FP.data.quests[1236].log[1].done, "turn-in closes the log entry")
check(FP.cdb.completed[1236], "completed flag")
-- chain hint: a new quest offered by the same NPC right after
M.dialogQuest = 1237
M.FireEvent("QUEST_DETAIL", 0)
check(FP.data.quests[1237].after[1236], "chain hint recorded")
errorsEmpty("turn-in")

-- Party
local exp = FP.Party:ExportString()
check(exp:match("^FP1;Chiznooch;MAGE;"), "export string: " .. exp)
cmd("partyimport FP1;Hunterbro;HUNTER;20;1234,1235c")
check(FP.cdb.party.name == "Hunterbro", "party import via command")
FP.Planner:Build()
local sharedSeen = false
for _, s in ipairs(FP.Planner.steps) do if s.shared then sharedSeen = true end end
check(sharedSeen, "planner marks shared quests")

-- instance: no position
M.noPosition = true
M.Tick(2)
FP.Arrow:OnUpdate(0.1)
check(FP.Arrow.dist._text:find("no position") or FP.Arrow.dist._text:find("%?"), "arrow degrades without position: " .. tostring(FP.Arrow.dist._text))
M.noPosition = false

cmd("record off"); cmd("record on"); cmd("auto off"); cmd("auto on"); cmd("way clear"); cmd("export"); cmd("selftest")
errorsEmpty("end")

-- SavedVariables sanity: no functions / userdata leaked into the DB
local function scan(t, path, seen)
	seen = seen or {}
	if seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		local tv = type(v)
		check(tv ~= "function" and tv ~= "userdata" and tv ~= "thread", "non-serializable value at " .. path .. "." .. tostring(k))
		check(type(k) ~= "table", "table key at " .. path)
		if tv == "table" then scan(v, path .. "." .. tostring(k), seen) end
	end
end
scan(ForeverPathDB, "ForeverPathDB"); scan(ForeverPathCharDB, "ForeverPathCharDB")
-- Hunter audio feedback: inert on a Mage, active on a Hunter, chance + cooldown + channel dedupe
check(FP.HunterAudio.active == false and FP.HunterAudio.frame == nil, "hunter audio inert on a Mage")
M.class = "HUNTER"
FP.HunterAudio:Activate()
check(FP.HunterAudio.active and FP.HunterAudio.registered.UNIT_SPELLCAST_SUCCEEDED, "hunter audio registered")
FP.HunterAudio.TRIGGERS["Multi-Shot"].chance = 1
FP.HunterAudio.TRIGGERS["Mend Pet"].chance = 1
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-1978-0001", 1978)
check(FP.HunterAudio.plays == 0 and FP.HunterAudio.seen == 0, "unrelated spell ignored")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-2643-0002", 2643)
local function inPool(path, pool)
	for _, f in ipairs(FP.HunterAudio.POOLS[pool]) do
		if path:sub(-#f) == f and path:find("Hunter", 1, true) then return true end
	end
	return false
end
check(FP.HunterAudio.plays == 1 and #M.sounds == 1 and inPool(M.sounds[1].path, "short"), "Multi-Shot played a short cue: " .. tostring(M.sounds[1] and M.sounds[1].path))
check(M.sounds[1].channel == "SFX", "SFX channel")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-2643-0003", 2643)
check(FP.HunterAudio.plays == 1 and FP.HunterAudio.seen == 2, "cooldown blocks a second cue")
M.now = M.now + 31
M.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3-1-1-1-3111-0004", 3111)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-3111-0004", 3111)
check(FP.HunterAudio.plays == 2 and FP.HunterAudio.seen == 3 and inPool(M.sounds[2].path, "long"), "Mend Pet channel counted once, long cue: " .. tostring(M.sounds[2] and M.sounds[2].path))
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-3-1-1-1-2643-0005", 2643)
check(FP.HunterAudio.seen == 3, "other units ignored")
M.now = M.now + 31
FP.settings.hunterAudio.enabled = false
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-2643-0006", 2643)
check(FP.HunterAudio.plays == 2, "disabled setting suppresses cues")
FP.settings.hunterAudio.enabled = true
cmd("audio"); cmd("audio test"); cmd("audio off"); cmd("audio on")
check(FP.HunterAudio.plays == 4, "audio test plays both pools")
-- every listed cue file exists on disk
for _, pool in pairs(FP.HunterAudio.POOLS) do
	for _, file in ipairs(pool) do
		local fh = io.open("ForeverPath/Sounds/Hunter/" .. file, "rb")
		check(fh ~= nil, "missing sound file " .. file)
		if fh then fh:close() end
	end
end
M.class = nil
errorsEmpty("hunter audio")

-- API probe: records distinct secrecy states on transitions, dedupes repeats
check(FP.db.probe and #FP.db.probe.samples >= 1, "probe recorded the login sample")
local before = #FP.db.probe.samples
M.SetUnit("target", { guid = "Creature-0-4379-1-13-3396-00003BB8E1", name = "Razormane Quilboar", level = 19, reaction = 2 })
M.FireEvent("PLAYER_TARGET_CHANGED"); M.RunTimers(2)
check(#FP.db.probe.samples == before + 1, "target change produced a new distinct sample")
M.inCombat = true
M.FireEvent("PLAYER_REGEN_DISABLED"); M.RunTimers(3)
local last = FP.db.probe.samples[#FP.db.probe.samples]
check(last.sig:find("c.combat=0") and last.sig:find("c.pAuras=1"), "combat sample carries predicate answers: " .. last.sig)
M.FireEvent("PLAYER_REGEN_DISABLED"); M.RunTimers(3)
check((FP.db.probe.repeats or 0) >= 1, "identical state deduped as a repeat")
M.inCombat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
check(FP.db.probe.registration.note ~= nil, "registration note recorded")
cmd("probe"); cmd("probe now"); cmd("probe dump"); cmd("probe off"); cmd("probe on")
M.SetUnit("target", nil)
errorsEmpty("probe")

-- PvP module -----------------------------------------------------------------
check(not FP.PvP.frame:IsShown(), "pvp hud hidden with nothing to show")
M.SetUnit("target", { guid = "Player-4-0A1B2C3D", name = "Noblewarrior", level = 21, reaction = 2, player = true, class = "PRIEST", race = "Undead", canAttack = true })
M.FireEvent("PLAYER_TARGET_CHANGED"); M.RunTimers(1)
check(FP.Roster.session.Noblewarrior and FP.Roster.session.Noblewarrior.class == "PRIEST", "enemy player observed with class")
check(FP.data.pvp.players.Noblewarrior.level == 21, "enemy player persisted")
-- own casts: Polymorph x4 -> DR full, half, quarter, immune
local function cast(id, guid) M.FireEvent("UNIT_SPELLCAST_SENT", "player", "Noblewarrior", guid, id); M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", guid, id) end
cast(118, "Cast-1"); M.RunTimers(1)
local t = FP.CastTimers.active[1]
check(t and t.spell == "Polymorph" and t.target == "Noblewarrior" and t.duration == 20 and t.drText == "DR full", "poly timer 20s from tooltip, DR full: " .. tostring(t and t.duration) .. " " .. tostring(t and t.drText))
check(FP.PvP.frame:IsShown(), "pvp hud shown once a timer exists")
cast(118, "Cast-2"); local t2 = FP.CastTimers.active[2]
check(t2 and t2.duration == 10 and t2.drText == "DR ½", "second poly halves")
cast(118, "Cast-3"); local t3 = FP.CastTimers.active[3]
check(t3 and t3.duration == 5 and t3.drText == "DR ¼", "third poly quarters")
cast(118, "Cast-4")
check(#FP.CastTimers.active == 3, "fourth poly is immune: no timer")
check(FP.CastTimers:DRState("Noblewarrior", "polymorph") == "immune", "DR state immune")
cast(2139, "Cast-5"); local cs = FP.CastTimers.active[#FP.CastTimers.active]
check(cs and cs.spell == "Counterspell" and cs.kind == "lockout" and cs.duration == 10, "counterspell lockout 10s from tooltip")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-6", 1978)
check(#FP.CastTimers.active == 4, "untracked spell ignored")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-7", 118)
check(#FP.CastTimers.active == 4, "other units ignored")
local lines = FP.CastTimers:Lines(); check(#lines == 4 and lines[1].frac and lines[1].frac > 0, "timer lines with bars")
M.now = M.now + 40; FP.CastTimers:Prune(); check(#FP.CastTimers.active == 0, "timers expire")
check(FP.CastTimers:DRState("Noblewarrior", "polymorph") == "full", "DR resets after the window")
-- coordination: in a group, own CC broadcasts; partner's message becomes a timer; lockdown blocks sends
M.inGroup = true
M.SetUnit("party1", {name="Hunterbro",realm="ClassicBetaPvP2"})
cast(122, "Cast-8"); M.RunTimers(1)
check(#M.addonSent >= 1 and M.addonSent[#M.addonSent]:match("^PT;122;Frost Nova;8%.0;;;root$"), "own CC broadcast: " .. tostring(M.addonSent[#M.addonSent]))
M.FireEvent("CHAT_MSG_ADDON", "FPATH", "PT;19503;Scatter Shot;4.0;Noblewarrior;DR full;cc", "PARTY", "Hunterbro-ClassicBetaPvP2")
local partner = FP.CastTimers.active[#FP.CastTimers.active]
check(partner and partner.owner == "Hunterbro" and partner.spell == "Scatter Shot" and partner.duration == 4, "partner CC received as a timer")
M.FireEvent("CHAT_MSG_ADDON", "FPATH", "PT;19503;Scatter Shot;4.0;X;;cc", "PARTY", "Chiznooch")
check(FP.Coordination.received == 1, "own echoed message ignored")
M.lockdown = true
local sentBefore = #M.addonSent
cast(122, "Cast-9")
check(#M.addonSent == sentBefore and (FP.Coordination.lockedSends or 0) == 1, "lockdown blocks broadcast")
M.lockdown = false
-- battleground: objectives + flags + scoreboard + flag waypoint
M.bg = true
M.pois = { [101] = { name = "Blacksmith", desc = "Horde controlled", atlas = "HordeSymbol", tex = 3, x = 0.5, y = 0.5 }, [102] = { name = "Stables", desc = "Contested", atlas = "AllianceSymbol", tex = 2, x = 0.2, y = 0.3, secs = 42 } }
M.flags = { { x = 0.505, y = 0.495, tex = 555 } }
M.scores = { { name = "Noblewarrior", faction = 1, classToken = "PRIEST", raceName = "Undead" }, { name = "Chiznooch", faction = 0, classToken = "MAGE", raceName = "Blood Elf" } }
M.FireEvent("PLAYER_ENTERING_BATTLEGROUND"); M.RunTimers(2)
check(FP.Battleground.active and #FP.Battleground.pois == 2 and #FP.Battleground.flags == 1, "battleground detected with objectives + flag")
local bgl = FP.Battleground:Lines()
check(bgl[1].text:find("Blacksmith") and bgl[1].text:find("|cffff4040Horde"), "objective state from atlas/description: " .. bgl[1].text)
check(bgl[2].text:find("Stables") and bgl[2].text:find("contested") and bgl[2].text:find("42s"), "contested objective with timer: " .. bgl[2].text)
check(bgl[3].text:find("near Blacksmith") and bgl[3].icon == 555, "flag described relative to the nearest landmark: " .. bgl[3].text)
check(FP.data.bg["1413"] and FP.data.bg["1413"].pois[101] and FP.data.bg["1413"].flags["555"] == 1, "battleground observations recorded")
M.FireEvent("UPDATE_BATTLEFIELD_SCORE"); M.RunTimers(4)
check(FP.Roster.enemyComp and FP.Roster.enemyComp.PRIEST == 1 and not FP.Roster.enemyComp.MAGE, "scoreboard enemy composition")
cmd("pvp track")
check(FP.settings.pvp.trackFlag, "track flag on")
M.Tick(1); M.RunTimers(1)
local bgwp
for _, wp in ipairs(FP.Waypoints.list) do if wp.source and wp.source.type == "bg" then bgwp = wp end end
check(bgwp and bgwp.x == 0.505, "flag waypoint created at the flag position")
M.flags[1].x = 0.30; FP.Battleground:Scan()
check(bgwp.x == 0.30, "flag waypoint follows the flag")
cmd("pvp status"); cmd("pvp spells"); cmd("pvp"); cmd("pvp auto")
M.bg = false
M.FireEvent("ZONE_CHANGED_NEW_AREA"); M.RunTimers(2)
check(not FP.Battleground.active, "battleground mode off after leaving")
local left = false
for _, wp in ipairs(FP.Waypoints.list) do if wp.source and wp.source.type == "bg" then left = true end end
check(not left, "flag waypoint removed on leaving")
cmd("pvp clear"); cmd("pvp track")
M.SetUnit("target", nil)
errorsEmpty("pvp")

print("dataset: " .. FP.Recorder:Summary())
print("ALL CHECKS PASSED")
