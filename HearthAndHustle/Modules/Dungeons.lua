-- Dungeon preparation is informational. A reference entry is not a live offer.
local _, FP = ...
local API, U = FP.API, FP.Util
local D = FP:NewModule("Dungeons")
local catalog = FP.DungeonCatalog

local function contains(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

function D:Context()
    local ctx = { char = API.GetCharInfo(), states = {}, offers = {} }
    function ctx:State(id)
        if not self.states[id] then self.states[id] = API.GetDungeonQuestState(id) end
        return self.states[id]
    end
    local mapID = API.GetBestMap()
    if mapID then
        API.RequestQuestOffers(mapID)
        local ok, offers = pcall(API.GetQuestOffers, mapID)
        if ok and type(offers) == "table" then
            for _, q in ipairs(offers) do ctx.offers[q.questID] = q end
        end
    end
    return ctx
end

function D:Restriction(q, char)
    if q.faction and char.faction and q.faction ~= char.faction then return q.faction .. " only" end
    if q.classes and #q.classes > 0 and char.class and not contains(q.classes, char.class) then return table.concat(q.classes, "/") .. " only" end
    if q.races and #q.races > 0 and char.race and not contains(q.races, char.race) then return table.concat(q.races, "/") .. " only" end
end

-- One gate can require any one alternative; separate gates are ANDed.
-- Breadcrumbs are useful directions, never mandatory gates.
function D:Gate(prereq, ctx)
    if prereq.relationship ~= "required" then return true end
    local ids = prereq.anyOf or (prereq.questID and {prereq.questID}) or {}
    if #ids == 0 then return nil end
    local unknown = false
    for _, id in ipairs(ids) do
        local s = ctx:State(id)
        local value = s.completed
        if prereq.state == "active" then value = s.onQuest end
        if value == true then return true end
        if value == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

-------------------------------------------------------------------------------
-- Where a quest comes from. The installed quest database answers first (the
-- giver and its place, or the starting item and what drops it, and whether
-- that is inside a dungeon); the bundled catalogue is the fallback. Reference
-- data: it says where a quest starts, never that it is offered right now.
-------------------------------------------------------------------------------
local CLASS_BIT = { WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024 }
local function bit(mask, value) return math.floor(mask / value) % 2 == 1 end
local function recorded(text) return type(text) == "string" and text ~= "" and not text:lower():find("awaiting verification", 1, true) end
local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- "Horde" / "Alliance" when the reference limits a quest to one side.
function D:ReferenceFaction(mask)
    if not U.Finite(mask) or mask <= 0 then return nil end
    local alliance = bit(mask, 1) or bit(mask, 4) or bit(mask, 8) or bit(mask, 64) or bit(mask, 4294967296)
    local horde = bit(mask, 2) or bit(mask, 16) or bit(mask, 32) or bit(mask, 128) or bit(mask, 8589934592)
    if alliance and not horde then return "Alliance" end
    if horde and not alliance then return "Horde" end
end

-- Why this character cannot take a quest, from the catalogue or the database.
function D:Barred(id, char)
    local q = catalog.quests[id]
    local restriction = q and self:Restriction(q, char)
    if restriction then return restriction end
    local record = FP.QuestChains:Get(id)
    if not record then return nil end
    local faction = self:ReferenceFaction(record.requiredRaces)
    if faction and char.faction and faction ~= char.faction then return faction .. " only" end
    local classes, own = record.requiredClasses, char.class and CLASS_BIT[char.class]
    if U.Finite(classes) and classes > 0 and own and not bit(classes, own) then return "other classes only" end
end

-------------------------------------------------------------------------------
-- One quest under two numbers. The reference lists some quests more than once
-- (an older and a newer version, or one version per dungeon) and marks them
-- exclusive to each other. Exclusive and the same name: a version of this quest.
-- Holding one of them is holding the quest; the giver offers nothing more.
-------------------------------------------------------------------------------
function D:Variants(id)
    local chains = FP.QuestChains
    if self.variantsFor ~= chains.records then self.variants, self.variantsFor = {}, chains.records end
    if self.variants[id] then return self.variants[id] end
    local out, record = {}, chains:Get(id)
    for _, alt in ipairs(record and record.exclusiveTo or {}) do
        if U.Finite(alt) and alt > 0 and alt ~= id then
            local other = chains:Get(alt)
            if other and other.name ~= nil and other.name == record.name then out[#out + 1] = alt end
        end
    end
    table.sort(out)
    self.variants[id] = out
    return out
end

-- The version the character has: one in the log first, else one completed.
function D:Held(id, ctx)
    local done
    for _, alt in ipairs(self:Variants(id)) do
        local s = ctx:State(alt)
        if s.onQuest == true then return alt, s end
        if s.completed == true and not done then done = alt end
    end
    if done then return done, ctx:State(done) end
end

-- The dungeons whose list names a quest.
function D:ListedIn(id)
    if not self.listed then
        self.listed = {}
        for key, dungeon in pairs(catalog.dungeons) do
            for _, qid in ipairs(dungeon.quests) do
                self.listed[qid] = self.listed[qid] or {}
                table.insert(self.listed[qid], key)
            end
        end
        for _, keys in pairs(self.listed) do table.sort(keys) end
    end
    return self.listed[id] or {}
end

-- The number a dungeon quest is in the log under: its own, or that of a
-- version no dungeon list carries. Nil when it is not in the log.
function D:LogID(id)
    if API.GetDungeonQuestState(id).onQuest == true then return id end
    for _, alt in ipairs(self:Variants(id)) do
        if #self:ListedIn(alt) == 0 and API.GetDungeonQuestState(alt).onQuest == true then return alt end
    end
end

function D:Area(key)
    local area = self.entranceAreas[key or ""]
    return area and (API.GetDungeonAreaID(area) or area) or nil
end

local function byName(a, b) if a.name ~= b.name then return a.name < b.name end return a.id < b.id end
local function within(entry) return entry.dungeon ~= nil and not entry.outdoor end

function D:Origin(id)
    local chains = FP.QuestChains
    if self.originFor ~= chains.starters then self.origins, self.originFor = {}, chains.starters end
    if self.origins[id] then return self.origins[id] end
    local q = catalog.quests[id] or {}
    local o = { kind = "none", givers = {}, items = {}, sources = {}, more = 0 }
    -- the catalogue's zone stays as a hint for a giver the database cannot place
    o.zone = recorded(q.pickup and q.pickup.zone) and q.pickup.zone or nil
    for _, starter in ipairs(chains:Starters(id)) do
        if starter.kind == "Item" then
            o.items[#o.items + 1] = starter
            for _, source in ipairs(starter.sources or {}) do o.sources[#o.sources + 1] = source end
            o.more = o.more + (starter.sources and starter.sources.more or 0)
            -- sources beyond the ones kept for display were checked too
            if starter.sources and (starter.sources.outside or starter.sources.unchecked) then o.elsewhere = true end
        else o.givers[#o.givers + 1] = starter end
    end
    table.sort(o.givers, byName); table.sort(o.items, byName); table.sort(o.sources, byName)
    local list
    if #o.givers > 0 then o.kind, o.known, list = "giver", true, o.givers
    elseif #o.items > 0 then o.kind, o.known, list = "item", true, o.sources
    else
        -- no database, or a quest it does not have: what the catalogue recorded
        local p = q.pickup or {}
        o.kind = q.pickupType == "drop" and "item" or (recorded(p.name) and "giver" or "none")
        o.name = recorded(p.name) and p.name or nil
        o.place = recorded(p.subzone) and p.subzone or nil
        o.coords = recorded(p.coordinates) and p.coordinates or nil
    end
    if list and #list > 0 then
        o.inside = true
        for _, entry in ipairs(list) do
            if not within(entry) then o.inside = false
            elseif not o.dungeon then o.dungeon, o.dungeonArea = entry.dungeon, entry.dungeonArea end
        end
        if o.elsewhere then o.inside = false end -- a source outside, or too many to check: never "only inside"
    end
    self.origins[id] = o
    return o
end

-- "Shade of Eranikus (level 55 elite)"
local function creature(entry)
    local bits = {}
    if entry.level then bits[#bits + 1] = "level " .. entry.level end
    if entry.rank then bits[#bits + 1] = entry.rank end
    return entry.name .. (#bits > 0 and (" (" .. table.concat(bits, " ") .. ")") or "")
end

-- the first known outdoor place of a contact: "Tanaris 67.0, 22.0"
local function outdoors(entry)
    local best
    for _, p in ipairs(entry.points or {}) do
        if not p.entrance and (not best or p.mapID < best.mapID or (p.mapID == best.mapID and (p.x < best.x or (p.x == best.x and p.y < best.y)))) then best = p end
    end
    if best then return API.GetMapName(best.mapID) .. " " .. U.FormatCoords(best.x, best.y), best end
end

function D:InsideText(entry, key)
    local area = self:Area(key)
    if not entry.dungeon then return "" end
    if area and entry.dungeonArea == area then return "inside this dungeon" end
    return "inside " .. entry.dungeon
end

local function names(list, limit, more, describe)
    local out = {}
    for i = 1, math.min(limit, #list) do out[i] = describe and describe(list[i]) or list[i].name end
    local rest = #list - #out + (more or 0)
    return table.concat(out, ", ") .. (rest > 0 and (" and " .. rest .. " more") or "")
end

-- One plain line: where this quest starts.
function D:OriginText(id, key, long)
    local o = self:Origin(id)
    if o.kind == "giver" and o.known then
        local giver, place = o.givers[1]
        for _, g in ipairs(o.givers) do
            local text = outdoors(g)
            if text then giver, place = g, text; break end
        end
        if place then return giver.name .. " — " .. place .. (#o.givers > 1 and (" (or " .. plural(#o.givers - 1, "other giver") .. ")") or "") end
        if giver.dungeon then return giver.name .. " — " .. self:InsideText(giver, key) end
        return giver.name .. " — " .. (o.zone and (o.zone .. " (exact place not in the quest database)") or "place not in the quest database")
    elseif o.kind == "item" and o.known then
        local item = o.items[1].name
        if #o.sources == 0 then return "Item: " .. item .. " — what drops it is not in the reference" end
        local drops, other = {}, {}
        for _, source in ipairs(o.sources) do
            if source.how == "drop" or source.how == "object" then drops[#drops + 1] = source else other[#other + 1] = source end
        end
        if #drops == 0 then
            local first = other[1]
            local how = first.how == "vendor" and ("sold by " .. first.name) or first.how == "reward" and ("reward of the quest " .. first.name) or ("found in " .. first.name)
            local place = first.how == "vendor" and outdoors(first)
            return "Item: " .. item .. " — " .. how .. (place and (", " .. place) or "")
        end
        local from = (drops[1].kind == "Object" and "found in " or "drops from ") .. names(drops, long and 4 or 2, o.more, long and creature or nil)
        if o.inside then return "Item: " .. item .. " — " .. from .. ", " .. self:InsideText(drops[1], key) end
        local place
        for _, source in ipairs(drops) do place = outdoors(source); if place then break end end
        return "Item: " .. item .. " — " .. from .. (place and (", " .. place) or (drops[1].dungeon and (", " .. self:InsideText(drops[1], key)) or ""))
    end
    -- catalogue only
    local parts = {}
    if o.name then parts[#parts + 1] = o.name end
    if o.zone then parts[#parts + 1] = o.zone end
    if o.place then parts[#parts + 1] = o.place end
    if o.coords then parts[#parts + 1] = o.coords end
    if #parts == 0 then
        return o.kind == "item" and "Starts from an item; which one is not recorded" or "Where it starts is not recorded (no quest database entry)"
    end
    return (o.kind == "item" and "Item from: " or "") .. table.concat(parts, " — ")
end

-------------------------------------------------------------------------------
-- What has to be done first. Each need is a set of quests of which one must be
-- completed; all needs must hold. The database's chain leads; the catalogue
-- adds what only it knows (quests new in Forever).
-------------------------------------------------------------------------------
function D:Needs(id)
    local needs, listed = {}, {}
    local record = FP.QuestChains:Get(id)
    if record then
        if #record.preQuestSingle > 0 then
            local ids = {}
            for _, pid in ipairs(record.preQuestSingle) do ids[#ids + 1] = math.abs(pid); listed[math.abs(pid)] = true end
            -- the same step under its other number counts too
            for i = 1, #ids do
                for _, alt in ipairs(self:Variants(ids[i])) do
                    if not listed[alt] then ids[#ids + 1] = alt; listed[alt] = true end
                end
            end
            needs[#needs + 1] = { ids = ids }
        end
        for _, signed in ipairs(record.preQuestGroup) do
            local pid = math.abs(signed)
            local ids = { pid }
            listed[pid] = true
            local parent = signed > 0 and FP.QuestChains:Get(pid)
            -- one of two exclusive branches satisfies a step that names the other
            for _, alt in ipairs(parent and parent.exclusiveTo or {}) do if U.Finite(alt) and alt > 0 then ids[#ids + 1] = alt end end
            needs[#needs + 1] = { ids = ids }
        end
    end
    -- The database's chain stands when it has one; the catalogue speaks where the
    -- database is silent (quests new in Forever) and for "keep X in your log".
    local q, fromDatabase = catalog.quests[id], #needs
    for _, pre in ipairs(q and q.prerequisites or {}) do
        if pre.relationship == "required" then
            local ids = pre.anyOf or (pre.questID and { pre.questID }) or {}
            local known = false
            for _, pid in ipairs(ids) do if listed[pid] then known = true end end
            if not known and (fromDatabase == 0 or pre.state == "active") then
                needs[#needs + 1] = { ids = ids, active = pre.state == "active", catalogue = pre }
            end
        end
    end
    return needs
end

function D:NeedValue(need, ctx)
    if need.catalogue then return self:Gate(need.catalogue, ctx) end
    if #need.ids == 0 then return nil end
    local unknown = false
    for _, pid in ipairs(need.ids) do
        local value = ctx:State(pid).completed
        if value == true then return true end
        if value == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

function D:QuestName(id)
    local q = catalog.quests[id]
    if q and q.name then return q.name end
    local record = FP.QuestChains:Get(id)
    return record and record.name or ("Quest #" .. id)
end

-- The quests still to finish before this one, first to last, for this
-- character. `unknown`: a step the client would not answer for. `dead`: a step
-- with no branch this character can take.
-- `cut`: the chain is longer than the walk follows, so the steps listed do NOT
-- reach its first quest (the amulet chain of 20+ quests was cut at 19 until
-- v0.33.0 and its cut end shown as the start). Never name a first step then.
D.PATH_DEPTH, D.PATH_BUDGET = 60, 120
function D:Path(id, ctx)
    local path = { steps = {} }
    local trail, listed, budget = { [id] = true }, {}, self.PATH_BUDGET
    local function walk(qid, depth)
        for _, need in ipairs(self:Needs(qid)) do
            local value = self:NeedValue(need, ctx)
            if value == nil then path.unknown = true
            elseif value == false then
                local pick, fallback
                for _, pid in ipairs(need.ids) do
                    if not self:Barred(pid, ctx.char) then
                        fallback = fallback or pid
                        if ctx:State(pid).onQuest == true then pick = pid; break end
                    end
                end
                pick = pick or fallback
                if not pick then path.dead = true
                elseif trail[pick] then path.unknown = true -- a loop in the reference
                elseif budget <= 0 or depth >= self.PATH_DEPTH then path.unknown, path.cut = true, true
                elseif not listed[pick] then
                    listed[pick], trail[pick], budget = true, true, budget - 1
                    walk(pick, depth + 1)
                    trail[pick] = nil
                    path.steps[#path.steps + 1] = pick
                    if need.active then path.keep = pick end
                end
            end
        end
    end
    walk(id, 1)
    path.blocked = #path.steps > 0 or path.dead == true
    return path
end

-- A later step already taken, or the other branch finished: no longer offered.
function D:Closed(id, ctx)
    local record = FP.QuestChains:Get(id)
    if not record then return nil end
    local nextID = record.nextQuestInChain
    if U.Finite(nextID) and nextID > 0 and nextID ~= id then
        local s = ctx:State(nextID)
        if s.completed == true or s.onQuest == true then return "the next step, " .. self:QuestName(nextID) .. ", is already " .. (s.completed == true and "done" or "in your log") end
    end
    for _, alt in ipairs(record.exclusiveTo) do
        if U.Finite(alt) and alt > 0 then
            local s = ctx:State(alt)
            if s.completed == true then return "you finished the other branch, " .. self:QuestName(alt) end
            if s.onQuest == true then return "the other branch, " .. self:QuestName(alt) .. ", is in your log" end
        end
    end
end

-- "the Dire Maul: North version" / "another version"
function D:VersionText(alt, key)
    for _, other in ipairs(self:ListedIn(alt)) do
        if other ~= key and catalog.dungeons[other] then return "the " .. catalog.dungeons[other].name .. " version" end
    end
    return "another version"
end

function D:MinLevel(id)
    local q, record = catalog.quests[id], FP.QuestChains:Get(id)
    local level = q and U.Finite(q.minLevel) and q.minLevel or nil
    if record and U.Finite(record.requiredLevel) and record.requiredLevel > (level or 0) then level = record.requiredLevel end
    return level
end

-- Returns code, label, colour and, when the character holds this quest under
-- another number, that number: the log, the turn-in and the arrow use it.
function D:Evaluate(id, ctx)
    local q, state = catalog.quests[id], ctx:State(id)
    if state.onQuest == true then
        if state.ready == true then return "ready", "Ready to turn in", FP.GREEN end
        return "active", "In your log", FP.GREEN
    end
    if state.completed == true then return "done", "Completed", FP.GREY end
    -- Live availability outranks provisional catalogue restrictions and chains.
    if ctx.offers[id] then return "offer", "Offered on this map", FP.GOLD end
    local restriction = self:Barred(id, ctx.char)
    if restriction then return "restricted", restriction, FP.GREY end
    if state.onQuest == nil or state.completed == nil then return "unknown", "Quest state unavailable", FP.GOLD end
    -- A version of this quest is in the log or finished: it is not a pickup.
    local alt, held = self:Held(id, ctx)
    if alt then
        -- a version with a row of its own (here or in another dungeon) is that row's business
        if #self:ListedIn(alt) > 0 then return "closed", "No longer offered", FP.GREY end
        if held.onQuest == true then
            if held.ready == true then return "ready", "Ready to turn in", FP.GREEN, alt end
            return "active", "In your log", FP.GREEN, alt
        end
        return "done", "Completed", FP.GREY, alt
    end
    if self:Closed(id, ctx) then return "closed", "No longer offered", FP.GREY end
    local level = self:MinLevel(id)
    if level and U.Finite(ctx.char.level) and ctx.char.level < level then
        return "level", "Needs level " .. level, FP.GOLD
    end
    local path = self:Path(id, ctx)
    if #path.steps > 0 then return "prereq", "Chain: " .. (path.cut and "more than " or "") .. plural(#path.steps, "quest") .. " first", FP.GOLD end
    if path.dead then return "prereq", "Needs a quest you cannot take", FP.GOLD end
    if path.unknown then return "unknown", "Prerequisite unknown", FP.GOLD end
    -- the giver was asked and did not offer it: the reference is wrong for this character
    local asked = self:Asked(id)
    if asked and asked.refused then return "refused", "Not offered", FP.GREY end
    local o = self:Origin(id)
    if o.inside then return "inside", o.kind == "item" and "Drops inside" or "Pick up inside", FP.GOLD end
    if o.kind == "item" then return "pickup", "Starts from an item", FP.GOLD end
    if o.kind == "none" then return "pickup", "Pickup not recorded", FP.GOLD end
    return "pickup", "Pick up", FP.GOLD
end

function D:List()
    local list = {}
    for key, d in pairs(catalog.dungeons) do list[#list + 1] = { key = key, data = d } end
    table.sort(list, function(a, b)
        local al, bl = tonumber((a.data.recommendedLevel or ""):match("%d+")) or a.data.minLevel or 0,
            tonumber((b.data.recommendedLevel or ""):match("%d+")) or b.data.minLevel or 0
        if al ~= bl then return al < bl end
        return a.data.name < b.data.name
    end)
    return list
end

function D:Rows(key, all, ctx)
    ctx = ctx or self:Context()
    ctx.key = key
    local rows, counts, seen = {}, { active = 0, done = 0, check = 0, hidden = 0, by = {} }, {}
    for _, id in ipairs(catalog.dungeons[key] and catalog.dungeons[key].quests or {}) do
        if not seen[id] and catalog.quests[id] then
            seen[id] = true
            local code, label, color, as = self:Evaluate(id, ctx)
            counts.by[code] = (counts.by[code] or 0) + 1
            if code == "restricted" and not all then counts.hidden = counts.hidden + 1
            else
                rows[#rows + 1] = { id = id, quest = catalog.quests[id], code = code, label = label, color = color, as = as }
                if code == "active" or code == "ready" then counts.active = counts.active + 1
                elseif code == "done" then counts.done = counts.done + 1
                elseif code ~= "restricted" and code ~= "closed" then counts.check = counts.check + 1 end
            end
        end
    end
    -- what to do before the run comes first
    local order = { offer=1, pickup=2, prereq=3, inside=4, ready=5, active=6, level=7, unknown=8, refused=9, closed=10, done=11, restricted=12 }
    table.sort(rows, function(a,b)
        if order[a.code] ~= order[b.code] then return order[a.code] < order[b.code] end
        if a.quest.name ~= b.quest.name then return a.quest.name < b.quest.name end
        return a.id < b.id
    end)
    -- kept for the next data pull: did the quest database answer, and what the list came to
    if FP.db then
        FP.db.dungeonSources = { t = U.Now(), version = FP.version, key = key, rows = #rows, hidden = counts.hidden,
            database = API.QuestDatabaseStatus() == true, by = U.Copy(counts.by) }
    end
    return rows, counts, ctx
end

-------------------------------------------------------------------------------
-- The giver's own word. The quest database says where a quest starts. Whether
-- the giver offers it to this character is known only from the giver's dialog:
-- the database records no worn-item, reputation or content-phase requirement,
-- and its own design notes call availability "consumer policy".
--
-- So each conversation with a giver is remembered, per character: when, at
-- what level, and which quests were on offer. A quest on that list is
-- confirmed. A quest the database starts at that giver and that was NOT on a
-- full list is "not offered", as long as nothing it waits on was handed in
-- since and the character was old enough when asking. The player can say the
-- same with a button, for a giver who opens no dialog at all.
-------------------------------------------------------------------------------
local GIVERS_KEPT, TURNINS_KEPT = 300, 600

-- Reading never creates anything in the saved character: only a conversation,
-- a hand-in or the player's button (`write`) does.
function D:Memory(write)
    local cdb = FP.cdb
    if write then cdb.givers, cdb.notOffered, cdb.turnins = cdb.givers or {}, cdb.notOffered or {}, cdb.turnins or {} end
    return cdb.givers or {}, cdb.notOffered or {}, cdb.turnins or {}
end

local function trim(list, keep, stamp)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    while n > keep do
        local oldest, at
        for key, value in pairs(list) do
            local t = stamp(value)
            if not at or t < at or (t == at and key < oldest) then oldest, at = key, t end
        end
        list[oldest] = nil; n = n - 1
    end
end

-- `full`: a greeting, which lists everything on offer and replaces what was known.
-- A quest dialog opened directly names one quest and proves nothing about others.
function D:Remember(npc, list, full)
    if type(npc) ~= "table" or npc.kind ~= "Creature" or not U.Finite(npc.id) then return end
    local givers, marked = self:Memory(true)
    local now = U.Now()
    local rec = givers[npc.id] or { offered = {} }
    if full then rec.offered, rec.full, rec.level = {}, now, API.PlayerLevel() end
    for _, q in ipairs(list or {}) do
        local id = type(q) == "table" and q.questID
        if U.Finite(id) and id > 0 then rec.offered[id] = now; marked[id] = nil end
    end
    rec.t = now
    if type(npc.name) == "string" and npc.name ~= "" then rec.name = npc.name end
    givers[npc.id] = rec
    trim(givers, GIVERS_KEPT, function(value) return value.t or 0 end)
    FP:Fire("DUNGEON_GIVERS_CHANGED")
end

-- When the last quest this one waits on was handed in (0: before this was kept).
function D:OpenedAt(id)
    local _, _, turnins = self:Memory()
    local latest = 0
    for _, need in ipairs(self:Needs(id)) do
        for _, pid in ipairs(need.ids) do
            local t = turnins[pid]
            if t and t > latest then latest = t end
        end
    end
    return latest
end

-- nil, or { offered = true | refused = true, t, name, manual }
function D:Asked(id)
    local givers, marked = self:Memory()
    local best
    for _, starter in ipairs(FP.QuestChains:Starters(id)) do
        local rec = starter.kind == "Npc" and givers[starter.id]
        if rec then
            local seen, name = rec.offered[id], rec.name or starter.name
            if seen then
                if not best or not best.offered or seen > best.t then best = { offered = true, t = seen, name = name } end
            elseif rec.full and not (best and best.offered) and (not best or rec.full > best.t) then
                best = { refused = true, t = rec.full, name = name, level = rec.level }
            end
        end
    end
    if best and best.offered then return best end
    local opened, level = self:OpenedAt(id), self:MinLevel(id)
    -- a refusal counts only if the quest was open to the character when the giver was asked
    if best and (best.t < opened or (level and U.Finite(best.level) and best.level < level)) then best = nil end
    local mark = marked[id]
    if mark and mark >= opened and (not best or mark > best.t) then best = { refused = true, manual = true, t = mark } end
    return best
end

-- The player's own word, for a giver who opens no dialog. Player click only.
function D:MarkNotOffered(id, on)
    if not U.Finite(id) then return false end
    local _, marked = self:Memory(true)
    marked[id] = on and U.Now() or nil
    FP:Fire("DUNGEON_GIVERS_CHANGED")
    return true
end

local function ago(t)
    local s = math.max(0, U.Now() - t)
    if s < 90 then return "just now" end
    if s < 3600 then return math.floor(s / 60) .. " min ago" end
    if s < 86400 then return math.floor(s / 3600) .. " h ago" end
    local days = math.floor(s / 86400)
    return days .. (days == 1 and " day ago" or " days ago")
end

function D:AskedText(asked)
    if asked.offered then return "Offered when you spoke to " .. asked.name .. " " .. ago(asked.t) .. "." end
    if asked.manual then return "You marked it not offered " .. ago(asked.t) .. ". Talk to the giver, or undo the mark, to list it again." end
    return "Not offered when you spoke to " .. asked.name .. " " .. ago(asked.t) .. ". The quest database does not record why; talk to them again to refresh."
end

-------------------------------------------------------------------------------
-- What to do now, then what comes later. The checklist is this list.
--
-- "Now" is the dungeon's own quests that the reference says are open to the
-- character, each with its giver and the nearest known place, nearest first,
-- plus what is in the log. The first quest of each chain a dungeon quest sits
-- behind is listed once, below those, as a chain the player could start: the
-- reference's word, not an instruction, until its giver has been seen to
-- offer it (then it is a pickup like any other). A chain that could not be
-- followed to its first quest names none. What a giver was asked for and did
-- not offer is "Not offered". "Later" is what stays shut until something
-- above is done. Reference places, straight-line distances.
-------------------------------------------------------------------------------
-- The nearest known place outside a dungeon to start a quest:
-- point, who or what gives it there, yards (nil across the sea), other continent.
function D:Near(id, ctx)
    local offer = ctx.offers[id]
    local pos = FP.Pos.cache or {}
    local best, bestD, name
    local function consider(points, label)
        for _, point in ipairs(points or {}) do
            if not point.entrance and U.ValidMapPoint(point.mapID, point.x, point.y) then
                local c, wx, wy = FP.Pos:WorldOf(point)
                local d = (pos.valid and wx and c == pos.continent) and U.Distance(pos.wx, pos.wy, wx, wy) or math.huge
                if not best or d < bestD or (d == bestD and (point.mapID < best.mapID or (point.mapID == best.mapID and (point.x < best.x or (point.x == best.x and point.y < best.y))))) then
                    best, bestD, name = point, d, label
                end
            end
        end
    end
    if offer and U.ValidMapPoint(offer.mapID, offer.x, offer.y) then
        -- seen on offer on this map: the place is where the player stood with the giver
        local asked, starters = self:Asked(id), FP.QuestChains:Starters(id)
        consider({ offer }, (asked and asked.name) or (starters[1] and starters[1].name) or nil)
    else
        for _, starter in ipairs(FP.QuestChains:Starters(id)) do
            consider(starter.points, starter.name)
            for _, source in ipairs(starter.sources or {}) do consider(source.points, starter.name .. ", from " .. source.name) end
        end
    end
    if not best then return nil end
    local far = false
    if bestD == math.huge then
        local c = FP.Pos:WorldOf(best)
        far = pos.valid == true and c ~= nil and pos.continent ~= nil and c ~= pos.continent
    end
    return best, name, bestD ~= math.huge and bestD or nil, far
end

-- "Sagorne Creststrider — Orgrimmar 38.7, 35.9 · 127 yd"
function D:NearText(id, ctx)
    local point, name, dist, far = self:Near(id, ctx)
    if not point then return self:OriginText(id, ctx.key) end
    return (name and (name .. " — ") or "") .. API.GetMapName(point.mapID) .. " " .. U.FormatCoords(point.x, point.y)
        .. (dist and (" · " .. U.FormatDistance(dist)) or (far and " · other continent" or ""))
end

local function listNames(D, ids, limit)
    local out = {}
    for i = 1, math.min(limit, #ids) do out[i] = D:QuestName(ids[i]) end
    return table.concat(out, ", ") .. (#ids > limit and (" +" .. (#ids - limit)) or "")
end

local GROUP = { ready = 1, offer = 2, pickup = 2, stepactive = 3, active = 4, step = 5, inside = 6, prereq = 7, level = 8, unknown = 9, refused = 10, closed = 11, done = 12, restricted = 13 }
local NOW = { ready = true, offer = true, pickup = true, stepactive = true, active = true }
local WHITE = "|cffffffff"
-- a chain start its giver was seen to offer is a pickup like any other
local function group(row) return (row.code == "step" and row.confirmed) and GROUP.pickup or GROUP[row.code] end

function D:Todo(key, all, ctx)
    FP.Pos:Refresh(true)
    local rows, counts
    rows, counts, ctx = self:Rows(key, all, ctx)
    local byId, starts, order = {}, {}, {}
    for _, row in ipairs(rows) do byId[row.id] = row end
    for _, row in ipairs(rows) do
        row.now = NOW[row.code] == true
        if row.code == "prereq" then
            row.path = self:Path(row.id, ctx)
            -- only a chain read to its start, every step known, names a first quest
            local first = not row.path.unknown and not row.path.dead and row.path.steps[1]
            if first then
                if not starts[first] then starts[first] = { id = first, toward = {}, steps = #row.path.steps }; order[#order + 1] = starts[first] end
                local start = starts[first]
                start.toward[#start.toward + 1] = row.id
                start.steps = math.min(start.steps, #row.path.steps)
            end
        end
    end
    counts.steps, counts.finish, counts.refused, counts.confirmed = 0, 0, counts.by.refused or 0, 0
    for _, start in ipairs(order) do
        -- the quest it opens directly is named first
        table.sort(start.toward, function(a, b)
            local an, bn = #byId[a].path.steps, #byId[b].path.steps
            if an ~= bn then return an < bn end
            if byId[a].quest.name ~= byId[b].quest.name then return byId[a].quest.name < byId[b].quest.name end
            return a < b
        end)
        local own = byId[start.id]
        if own then own.opens = start.toward -- a dungeon quest of this list that opens others
        elseif catalog.quests[start.id] or FP.QuestChains:Get(start.id) then -- a step nothing describes stays in the details
            local s = ctx:State(start.id)
            local held = s.onQuest == true
            local level = self:MinLevel(start.id)
            local asked = not held and self:Asked(start.id) or nil
            local row = { id = start.id, step = true, quest = { name = self:QuestName(start.id) }, opens = start.toward, steps = start.steps,
                code = held and "stepactive" or "step", label = held and "Finish first" or "Chain start", color = held and FP.GREEN or WHITE, now = held,
                needsLevel = (not held and level and U.Finite(ctx.char.level) and ctx.char.level < level) and level or nil }
            if asked and asked.refused then row.code, row.label, row.color = "refused", "Not offered", FP.GREY end
            rows[#rows + 1] = row
            if held then counts.finish = counts.finish + 1
            elseif row.code == "refused" then counts.refused = counts.refused + 1
            else counts.steps = counts.steps + 1 end
        end
    end
    for _, row in ipairs(rows) do
        if row.code == "pickup" or row.code == "offer" or row.code == "step" then
            local point, _, dist, far = self:Near(row.id, ctx)
            row.dist, row.far, row.placed = dist, far, point ~= nil
            local asked = self:Asked(row.id)
            if asked and asked.offered then row.confirmed, row.asked = true, asked; counts.confirmed = counts.confirmed + 1 end
        elseif row.code == "refused" then row.asked = self:Asked(row.id) end
        if row.code == "pickup" or row.code == "offer" then row.label, row.color = "Pick up now", FP.GOLD end
        if row.code == "step" and row.confirmed then
            row.label, row.color, row.now = "Pick up now", FP.GOLD, true
            counts.steps, counts.pick = counts.steps - 1, (counts.pick or 0) + 1
        end
        if row.code == "prereq" then row.label, row.color = "Later: " .. (row.path.cut and "more than " or "") .. plural(#row.path.steps, "quest") .. " first", FP.GREY end
    end
    table.sort(rows, function(a, b)
        if group(a) ~= group(b) then return group(a) < group(b) end
        if a.code == "step" and b.code == "step" and not a.confirmed and a.steps ~= b.steps then return a.steps < b.steps end -- the short chains first
        if a.code == "pickup" or a.code == "offer" or a.code == "step" then
            local ad, bd = a.dist or (a.far and 1e9 or (a.placed and 1e8 or 1e10)), b.dist or (b.far and 1e9 or (b.placed and 1e8 or 1e10))
            if ad ~= bd then return ad < bd end
        end
        if a.quest.name ~= b.quest.name then return a.quest.name < b.quest.name end
        return a.id < b.id
    end)
    -- kept for the next data pull, beside what Rows wrote: the size of the do-now list, and
    -- how many quests were recognised in the log or completed under their other number
    if FP.db and FP.db.dungeonSources then
        local held = 0
        for _, row in ipairs(rows) do if row.as then held = held + 1 end end
        local receipt = FP.db.dungeonSources
        receipt.lines, receipt.steps, receipt.finish, receipt.held = #rows, counts.steps, counts.finish, held
        -- ...and what the givers' own answers changed: quests seen on offer, quests asked for and not offered
        receipt.confirmed, receipt.refused = counts.confirmed, counts.refused
    end
    return rows, counts, ctx
end

-- The first line of a row: what to do, the quest, and what it opens.
function D:Title(row)
    local text = row.color .. row.label .. "|r - " .. row.quest.name
    if row.step then
        text = text .. FP.GREY .. "  ·  " .. (row.steps > 1 and (row.steps .. " quests to ") or "leads to ") .. listNames(self, row.opens, 1) .. "|r"
    elseif row.opens and row.code ~= "done" and row.code ~= "closed" then
        text = text .. FP.GREY .. "  ·  leads to " .. listNames(self, row.opens, 1) .. "|r"
    end
    return text
end

-- "Now: 2 to pick up · 2 in your log.  3 chains you could start (unconfirmed).  Later: 9 behind a quest chain."
function D:TodoText(counts)
    local by = counts.by or {}
    local now, later, rest = {}, {}, {}
    local function add(list, n, text) if (n or 0) > 0 then list[#list + 1] = n .. " " .. text end end
    add(now, by.ready, "to turn in")
    add(now, (by.offer or 0) + (by.pickup or 0) + (counts.pick or 0), "to pick up")
    add(now, counts.finish, (counts.finish == 1 and "chain step" or "chain steps") .. " to finish")
    add(now, by.active, "in your log")
    add(later, by.inside, (by.inside == 1 and "starts" or "start") .. " inside")
    add(later, by.prereq, "behind a quest chain")
    add(later, by.level, (by.level == 1 and "needs" or "need") .. " a higher level")
    add(later, by.unknown, "unknown")
    add(rest, counts.refused, "not offered when asked")
    add(rest, counts.done, "completed")
    add(rest, by.closed, "no longer offered")
    add(rest, counts.hidden, "for other classes/factions")
    local lines = {}
    if #now > 0 then lines[#lines + 1] = FP.GOLD .. "Now:|r " .. table.concat(now, " · ") end
    if (counts.steps or 0) > 0 then lines[#lines + 1] = (counts.steps == 1 and "1 chain" or (counts.steps .. " chains")) .. " you could start (unconfirmed)" end
    if #later > 0 then lines[#lines + 1] = "Later: " .. table.concat(later, " · ") end
    if #lines == 0 and #rest == 0 then return "Nothing listed for this character." end
    if #lines == 0 then lines[1] = "Nothing left to pick up here." end
    return table.concat(lines, ".  ") .. "." .. (#rest > 0 and ("\n" .. FP.GREY .. table.concat(rest, " · ") .. "|r") or "")
end

-- The catalogue's own pickup words (used when there is no quest database).
function D:Pickup(q)
    local p = q.pickup or {}
    local parts = { recorded(p.name) and p.name or "Giver not recorded" }
    if recorded(p.zone) then parts[#parts + 1] = p.zone end
    if recorded(p.subzone) then parts[#parts + 1] = p.subzone end
    if recorded(p.coordinates) then parts[#parts + 1] = p.coordinates end
    return table.concat(parts, " - ")
end

-- "Yeh'kinya — Tanaris 67.0, 22.0" / "Essence Font — inside this dungeon"
function D:ContactText(entry, key)
    local place = outdoors(entry)
    if place then return entry.name .. " — " .. place end
    if entry.dungeon then return entry.name .. " — " .. self:InsideText(entry, key) end
    return entry.name
end

function D:TurnInText(id, key)
    local enders = API.GetQuestEnders(id)
    table.sort(enders, byName)
    for _, ender in ipairs(enders) do if outdoors(ender) then return self:ContactText(ender, key) end end
    return enders[1] and self:ContactText(enders[1], key) or nil
end

-- The step that opens a chain quest, in a few words.
function D:NextText(path, ctx)
    local nextID = path.steps[1]
    if not nextID then return path.dead and "A step in its chain is for another class or faction" or "A step in its chain could not be read" end
    local s = ctx:State(nextID)
    local text
    if s.onQuest == true then
        text = "finish " .. self:QuestName(nextID) .. (s.ready == true and " (ready to turn in)" or " (in your log)")
    else
        local level = self:MinLevel(nextID)
        -- a step neither the database nor the bundled list knows: say so, with its number
        if not catalog.quests[nextID] and not FP.QuestChains:Get(nextID) then return "quest #" .. nextID .. ", which the quest database does not list" end
        text = self:QuestName(nextID) .. " · " .. self:OriginText(nextID, ctx.key)
        if not ctx.offers[nextID] and level and U.Finite(ctx.char.level) and ctx.char.level < level then text = text .. " (needs level " .. level .. ")" end
        -- the giver was asked for that step and did not offer it: say so instead of sending the player back
        local asked = self:Asked(nextID)
        if asked and asked.refused then
            text = self:QuestName(nextID) .. " · not offered when you " .. (asked.manual and "last checked" or ("spoke to " .. asked.name))
        end
    end
    return text
end

-- Why a quest is no longer offered, in a few words.
function D:ClosedWhy(id, ctx)
    local alt, held = self:Held(id, ctx)
    if alt then return "you " .. (held.onQuest == true and "have " or "finished ") .. self:VersionText(alt, ctx.key) .. " of this quest" end
    return self:Closed(id, ctx) or "a later step is done"
end

-- The line under a quest's name: the one thing to know about it right now.
function D:Where(row, ctx)
    local id, code = row.id, row.code
    if code == "done" then return "" end
    if code == "ready" or code == "active" then
        local turnin = self:TurnInText(row.as or id, ctx.key)
        return turnin and ("Turn in: " .. turnin) or ""
    end
    if code == "closed" then return "Because " .. self:ClosedWhy(id, ctx) end
    if code == "refused" then
        local asked = self:Asked(id)
        return asked and self:AskedText(asked) or "Not offered."
    end
    if code == "step" then
        return self:NearText(id, ctx) .. (row.needsLevel and (" · needs level " .. row.needsLevel) or "")
            .. (row.confirmed and (" · offered " .. ago(row.asked.t)) or " · unconfirmed: ask the giver")
    end
    if code == "stepactive" then
        local turnin = self:TurnInText(id, ctx.key)
        return "In your log" .. (turnin and (" · turn in: " .. turnin) or "")
    end
    -- in the do-now list a giver is named with the nearest place and how far it is
    if row.now and (code == "pickup" or code == "offer") and self:Origin(id).kind == "giver" then
        return self:NearText(id, ctx) .. (row.confirmed and (" · offered " .. ago(row.asked.t)) or "")
    end
    if code == "prereq" then
        local path = self:Path(id, ctx)
        if path.cut then return "A very long chain: the list could not follow it back to its first quest. View quest chain." end
        return "Next: " .. self:NextText(path, ctx) .. (#path.steps > 1 and (" · then " .. (#path.steps - 1) .. " more") or "")
    end
    if code == "inside" then
        -- the label already says "inside": name what gives it, and that nothing is owed beforehand
        local o = self:Origin(id)
        local area, text = self:Area(ctx.key)
        if o.kind == "item" then text = o.items[1].name .. ", from " .. names(o.sources, 2, o.more)
        else text = names(o.givers, 2) end
        if o.dungeonArea ~= area then text = text .. " (" .. tostring(o.dungeon) .. ")" end
        return text .. ". Nothing to pick up first."
    end
    return self:OriginText(id, ctx.key)
end

function D:Details(row, ctx)
    local q, id = row.quest, row.id
    local key = ctx.key
    local record = FP.QuestChains:Get(id)
    local level = self:MinLevel(id)
    local lines = { row.color .. row.label .. "|r  |  " .. q.name .. " (#" .. id .. ")"
        .. (U.Finite(q.questLevel) and ("  ·  level " .. q.questLevel .. " quest") or "") .. (level and ("  ·  needs level " .. level) or "") }
    if row.step then
        lines[#lines + 1] = "A chain step, not a dungeon quest: " .. (row.steps > 1 and ("the first of " .. row.steps .. " quests before ") or "it opens ")
            .. listNames(self, row.opens, 6) .. "."
        if row.code == "step" and not row.confirmed then
            lines[#lines + 1] = FP.GOLD .. "Unconfirmed.|r The quest database names this as the chain's first quest; it does not know whether the giver offers it to you (a quest can need an item, a reputation or content that is not out). Talking to the giver settles it and this list remembers the answer. If the giver has nothing, press \"Giver didn't offer it\"."
        end
    elseif row.opens then
        lines[#lines + 1] = "The first step toward: " .. listNames(self, row.opens, 6) .. "."
    end
    local o = self:Origin(id)
    local how = self:OriginText(id, key, true)
    if o.inside then
        how = how .. ". " .. (o.kind == "item" and "It drops during the run: nothing to pick up before you go." or "The giver is inside: nothing to pick up before you go.")
    elseif o.kind == "item" and o.known then how = how .. ". Looting it starts the quest."
    end
    -- a quest already held or finished has nothing to fetch: the giver is history
    local have = row.code == "active" or row.code == "ready" or row.code == "stepactive" or row.code == "done"
    lines[#lines + 1] = (have and "Given by: " or "How to get it: ") .. how
    if row.code == "closed" then lines[#lines + 1] = "No longer offered: " .. self:ClosedWhy(id, ctx) .. "." end
    local asked = (row.code == "refused" or row.confirmed) and self:Asked(id) or nil
    if asked then lines[#lines + 1] = self:AskedText(asked) end
    if row.as then
        lines[#lines + 1] = (row.code == "done" and "Completed as #" or "In your log as #") .. row.as
            .. ": the quest database lists this quest under two numbers. Nothing to pick up."
    end
    local ask = API.GetQuestAskText(id)
    if ask then lines[#lines + 1] = "What it asks: " .. ask end
    local turnin = self:TurnInText(row.as or id, key)
    if turnin then lines[#lines + 1] = "Turn in: " .. turnin end
    -- the chain before it, in the order to do it
    local path = self:Path(id, ctx)
    if #path.steps > 0 then
        lines[#lines + 1] = "Before it (" .. plural(#path.steps, "quest") .. ", in order):"
        for i, pid in ipairs(path.steps) do
            local s = ctx:State(pid)
            local mark = s.onQuest == true and (s.ready == true and "ready to turn in" or "in your log") or (i == 1 and "next" or "after that")
            local stepLevel = self:MinLevel(pid)
            lines[#lines + 1] = "  " .. i .. ". " .. self:QuestName(pid) .. " (#" .. pid .. ") — " .. mark .. ": " .. self:OriginText(pid, key)
                .. ((stepLevel and U.Finite(ctx.char.level) and ctx.char.level < stepLevel) and (" · needs level " .. stepLevel) or "")
        end
        if path.keep then lines[#lines + 1] = "  Keep " .. self:QuestName(path.keep) .. " in your log: this quest is offered while it is active." end
    end
    if path.dead then lines[#lines + 1] = "A step in its chain is listed for another class or faction; check the giver." end
    if path.unknown then lines[#lines + 1] = "A step in its chain could not be read from the client; check the giver." end
    if #path.steps == 0 and not path.dead and not path.unknown then
        local needs = self:Needs(id)
        if #needs > 0 then lines[#lines + 1] = "Its chain is done: " .. plural(#needs, "earlier step") .. " completed." end
    end
    local nextID = record and record.nextQuestInChain
    if U.Finite(nextID) and nextID > 0 and nextID ~= id then lines[#lines + 1] = "Leads to: " .. self:QuestName(nextID) .. " (#" .. nextID .. ")" end
    local limits = {}
    if q.faction then limits[#limits + 1] = q.faction .. " only" end
    if q.classes and #q.classes > 0 then limits[#limits + 1] = table.concat(q.classes, ", ") .. " only" end
    if q.races and #q.races > 0 then limits[#limits + 1] = table.concat(q.races, ", ") .. " only" end
    if #limits > 0 then lines[#lines + 1] = "Limited to: " .. table.concat(limits, " · ") end
    if q.breadcrumbOnly then lines[#lines + 1] = "Optional lead-in quest." end
    if q.conflict then lines[#lines + 1] = FP.GOLD .. "Conflicting reports: " .. q.conflict .. "|r" end
    lines[#lines + 1] = FP.GREY .. (o.known and "From the installed quest database: where a quest starts, not proof it is offered to you now."
        or (API.QuestDatabaseStatus() and "Not in the quest database; this is the bundled list, which may be out of date for Forever."
            or "QuestieDB (Forever) is not enabled: givers, places and chains come from the bundled list only.")) .. "|r"
    return table.concat(lines, "\n\n")
end


-- Explicit catalogue-to-provider AreaID crosswalk. No name matching against
-- other-expansion dungeons, no guessed coordinates for uncovered Forever sites.
D.entranceAreas={
    ["blackfathom-deeps"]=719,["blackrock-depths"]=1584,["city-of-dalaran"]=16544,
    ["deadmines"]=1581,["dire-maul-east"]=10026,["dire-maul-north"]=10022,["dire-maul-west"]=10023,
    ["excavation-site-wetlands"]=16732,["gnomeregan"]=721,["hall-of-thanes"]=16919,
    ["lower-blackrock-spire"]=1583,["upper-blackrock-spire"]=1583,["maraudon"]=2100,
    ["ragefire-chasm"]=2437,["razorfen-downs"]=722,["razorfen-kraul"]=491,["ruins-of-lordaeron"]=16611,
    ["scarlet-monastery-armory"]=796,["scarlet-monastery-cathedral"]=796,
    ["scarlet-monastery-graveyard"]=796,["scarlet-monastery-library"]=796,
    ["scholomance"]=2057,["shadowfang-keep"]=209,["stratholme-main-gate"]=2017,
    ["stratholme-service-gate"]=2017,["sunken-temple"]=1477,["the-stockade"]=717,
    ["uldaman"]=1337,["wailing-caverns"]=718,["zul-farrak"]=1176,
}
function D:Entrances(key)
    local points=API.GetDungeonEntrances(self.entranceAreas[key])
    local gate=key=="stratholme-main-gate" and 1 or key=="stratholme-service-gate" and 2
    if gate then
        for _,p in ipairs(points) do if p.entranceIndex==gate then return {p} end end
        return {}
    end
    return points
end
function D:RouteNote(key)
    local area=self.entranceAreas[key]
    if area==796 then return "Shared monastery approach; choose your wing inside the complex." end
    if area==1583 or area==1584 then return "Blackrock Mountain approach; continue inside to your dungeon entrance." end
    return "Outdoor entrance/approach only. Interior paths and boss order are not mapped."
end
function D:GuideEntrance(key,index)
    if API.InInstance() then return false,"Already inside an instance; outdoor entrance guidance is paused." end
    local p=self:Entrances(key)[index or 1]
    if not p or not catalog.dungeons[key] then return false,"No supported entrance coordinates for this dungeon." end
    FP.Waypoints:RemoveBySource("dungeon-entrance")
    local wp=FP.Waypoints:Add(p.mapID,p.x,p.y,"Entrance: "..catalog.dungeons[key].name,{
        source={type="dungeon-entrance",dungeon=key,entrance=true},radius=20,
        desc=self:RouteNote(key)})
    return wp~=nil,"Guiding to the outdoor entrance/approach. "..self:RouteNote(key)
end
local function logStep(questID)
    FP.Pos:Refresh(true)
    for _,step in ipairs(FP.Planner:Build()) do
        if step.questID==questID and step.mapID then
            return FP.Planner:Go(step)~=nil,"Guiding the selected quest. Follow the quest instructions inside the dungeon."
        end
    end
    return false,"No usable coordinates for this quest step. Follow the quest instructions; interior paths may be unavailable."
end
-- A chain step that is not itself a dungeon quest: to its giver, or to what it asks once it is in the log.
function D:GuideStep(id)
    if not U.Finite(id) then return false,"Choose a quest first." end
    if API.GetDungeonQuestState(id).onQuest==true then return logStep(id) end
    local ok,message=FP.QuestChains:GuidePickup(id)
    return ok,ok and ("Guiding to the chain step "..self:QuestName(id)..". "..message) or message
end
function D:GuideQuest(id)
    if not catalog.quests[id] then return false,"Choose a dungeon quest first." end
    local ctx=self:Context()
    local code,_,_,as=self:Evaluate(id,ctx)
    if code=="active" or code=="ready" then return logStep(as or id) end
    if code=="offer" or code=="pickup" or code=="inside" then return FP.QuestChains:GuidePickup(id) end
    if code=="prereq" then
        -- the click leads to the step that opens the chain, not to a giver who will refuse
        local path=self:Path(id,ctx)
        if path.cut then return false,"This chain is too long to follow back to its first quest. View its chain." end
        local nextID=path.steps[1]
        if not nextID then return false,"A step in this quest's chain is not available to this character." end
        if ctx:State(nextID).onQuest==true then return logStep(nextID) end
        local ok,message=FP.QuestChains:GuidePickup(nextID)
        return ok,ok and ("Guiding to the next step of the chain: "..self:QuestName(nextID)..". "..message) or message
    end
    return false,"Check this quest's requirements first. View its chain for prerequisites and pickup details."
end
function D:OnEnable()
    FP:On("NPC_QUESTS_SEEN", function(npc, list, full) self:Remember(npc, list, full) end)
    FP:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
        if not U.Finite(questID) then return end
        local _, _, turnins = self:Memory(true)
        turnins[questID] = U.Now()
        trim(turnins, TURNINS_KEPT, function(value) return value end)
    end)
    local function entering()
        if not API.InInstance() then return end
        for i=#FP.Waypoints.list,1,-1 do
            local wp=FP.Waypoints.list[i]
            if wp.source and wp.source.entrance then FP.Waypoints:Remove(wp.id) end
        end
        if FP.Planner.waiting and FP.Planner.waiting.entrance then FP.Planner.waiting=nil end
    end
    FP:RegisterEvent("PLAYER_ENTERING_WORLD",entering)
    FP:RegisterEvent("ZONE_CHANGED_NEW_AREA",entering)
    entering()
end
