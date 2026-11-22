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
function D:Path(id, ctx)
    local path = { steps = {} }
    local trail, listed, budget = { [id] = true }, {}, 40
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
                elseif trail[pick] or budget <= 0 or depth >= 20 then path.unknown = true -- a loop in the reference
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
    if #path.steps > 0 then return "prereq", "Chain: " .. plural(#path.steps, "quest") .. " first", FP.GOLD end
    if path.dead then return "prereq", "Needs a quest you cannot take", FP.GOLD end
    if path.unknown then return "unknown", "Prerequisite unknown", FP.GOLD end
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
    local order = { offer=1, pickup=2, prereq=3, inside=4, ready=5, active=6, level=7, unknown=8, closed=9, done=10, restricted=11 }
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

-- "4 to pick up first · 5 behind a chain · 1 starts inside · 3 need a higher level"
function D:CountsText(counts)
    local bits, by = {}, counts.by or {}
    local function add(n, text) if (n or 0) > 0 then bits[#bits + 1] = n .. " " .. text end end
    add((by.offer or 0) + (by.pickup or 0), "to pick up first")
    add(by.prereq, "behind a quest chain")
    add(by.inside, (by.inside == 1 and "starts" or "start") .. " inside")
    add(counts.active, "in your log")
    add(by.level, (by.level == 1 and "needs" or "need") .. " a higher level")
    add(by.unknown, "unknown")
    add(counts.done, "completed")
    add(by.closed, "no longer offered")
    add(counts.hidden, "for other classes/factions")
    return #bits > 0 and table.concat(bits, " · ") or "Nothing listed for this character."
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
    if code == "prereq" then
        local path = self:Path(id, ctx)
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
    local o = self:Origin(id)
    local how = self:OriginText(id, key, true)
    if o.inside then
        how = how .. ". " .. (o.kind == "item" and "It drops during the run: nothing to pick up before you go." or "The giver is inside: nothing to pick up before you go.")
    elseif o.kind == "item" and o.known then how = how .. ". Looting it starts the quest."
    end
    -- a quest already held or finished has nothing to fetch: the giver is history
    local have = row.code == "active" or row.code == "ready" or row.code == "done"
    lines[#lines + 1] = (have and "Given by: " or "How to get it: ") .. how
    if row.code == "closed" then lines[#lines + 1] = "No longer offered: " .. self:ClosedWhy(id, ctx) .. "." end
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
function D:GuideQuest(id)
    if not catalog.quests[id] then return false,"Choose a dungeon quest first." end
    local ctx=self:Context()
    local code,_,_,as=self:Evaluate(id,ctx)
    if code=="active" or code=="ready" then return logStep(as or id) end
    if code=="offer" or code=="pickup" or code=="inside" then return FP.QuestChains:GuidePickup(id) end
    if code=="prereq" then
        -- the click leads to the step that opens the chain, not to a giver who will refuse
        local nextID=self:Path(id,ctx).steps[1]
        if not nextID then return false,"A step in this quest's chain is not available to this character." end
        if ctx:State(nextID).onQuest==true then return logStep(nextID) end
        local ok,message=FP.QuestChains:GuidePickup(nextID)
        return ok,ok and ("Guiding to the next step of the chain: "..self:QuestName(nextID)..". "..message) or message
    end
    return false,"Check this quest's requirements first. View its chain for prerequisites and pickup details."
end
function D:OnEnable()
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
