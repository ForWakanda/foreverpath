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

function D:Evaluate(id, ctx)
    local q, state = catalog.quests[id], ctx:State(id)
    if state.onQuest == true then
        if state.ready == true then return "ready", "Ready to turn in", FP.GREEN end
        return "active", "In quest log", FP.GREEN
    end
    if state.completed == true then return "done", "Completed", FP.GREY end
    -- Live availability outranks provisional catalogue restrictions and chains.
    if ctx.offers[id] then return "offer", "Available on this map", FP.GOLD end
    local restriction = self:Restriction(q, ctx.char)
    if restriction then return "restricted", restriction, FP.GREY end
    if state.onQuest == nil or state.completed == nil then return "unknown", "Quest state unavailable", FP.GOLD end
    if U.Finite(q.minLevel) and U.Finite(ctx.char.level) and ctx.char.level < q.minLevel then
        return "level", "Listed minimum: level " .. q.minLevel, FP.GOLD
    end
    local missing, unknown = false, false
    for _, pre in ipairs(q.prerequisites or {}) do
        local gate = self:Gate(pre, ctx)
        if gate == false then missing = true elseif gate == nil then unknown = true end
    end
    if missing then return "prereq", "Check prerequisite", FP.GOLD end
    if unknown then return "unknown", "Prerequisite unknown", FP.GOLD end
    if q.followUpOf then return "pickup", "Follow-up: check pickup", FP.GOLD end
    if q.pickupType == "drop" then return "pickup", "Starts from an item", FP.GOLD end
    return "pickup", "Missing: check pickup", FP.GOLD
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
    local rows, counts, seen = {}, { active = 0, done = 0, check = 0, hidden = 0 }, {}
    for _, id in ipairs(catalog.dungeons[key] and catalog.dungeons[key].quests or {}) do
        if not seen[id] and catalog.quests[id] then
            seen[id] = true
            local code, label, color = self:Evaluate(id, ctx)
            if code == "restricted" and not all then counts.hidden = counts.hidden + 1
            else
                rows[#rows + 1] = { id = id, quest = catalog.quests[id], code = code, label = label, color = color }
                if code == "active" or code == "ready" then counts.active = counts.active + 1
                elseif code == "done" then counts.done = counts.done + 1
                elseif code ~= "restricted" then counts.check = counts.check + 1 end
            end
        end
    end
    local order = { offer=1, pickup=2, prereq=3, unknown=4, active=5, ready=6, level=7, done=8, restricted=9 }
    table.sort(rows, function(a,b)
        if order[a.code] ~= order[b.code] then return order[a.code] < order[b.code] end
        if a.quest.name ~= b.quest.name then return a.quest.name < b.quest.name end
        return a.id < b.id
    end)
    return rows, counts, ctx
end

function D:Pickup(q)
    local p = q.pickup or {}
    local parts = { p.name or "Giver not recorded" }
    if p.zone then parts[#parts + 1] = p.zone end
    if p.subzone then parts[#parts + 1] = p.subzone end
    if p.coordinates then parts[#parts + 1] = p.coordinates end
    return table.concat(parts, " - ")
end

function D:Details(row, ctx)
    local q = row.quest
    local lines = { row.color .. row.label .. "|r  |  " .. q.name .. " (#" .. row.id .. ")",
        "Pickup: " .. self:Pickup(q),
        "Listed minimum: " .. tostring(q.minLevel or "unknown") .. " | Faction: " .. (q.faction or "not restricted in reference") ..
        (q.classes and (" | Class: " .. table.concat(q.classes, ", ")) or "") }
    if q.breadcrumbOnly then lines[#lines + 1] = "Optional lead-in quest." end
    if q.followUpOf then lines[#lines + 1] = "Continuation of quest #" .. q.followUpOf .. "; may be obtained during or after the run." end
    if q.pickupType == "drop" then lines[#lines + 1] = "Item-started quest: obtain the starting item yourself." end
    local visited = {}
    local function chain(id, depth)
        if visited[id] or depth > 12 then return end
        visited[id] = true
        for _, pre in ipairs(catalog.quests[id] and catalog.quests[id].prerequisites or {}) do
            local gate = self:Gate(pre, ctx)
            local mark = pre.relationship ~= "required" and "Optional" or (gate == true and "Done" or (gate == false and "Needed (reference)" or "Unknown"))
            if pre.state == "active" and gate == true then mark = "In log" end
            lines[#lines + 1] = mark .. ": " .. (pre.note or ("Quest #" .. tostring(pre.questID or "?")))
            for _, pid in ipairs(pre.anyOf or (pre.questID and {pre.questID}) or {}) do
                local parent = catalog.quests[pid]
                if parent and gate ~= true then
                    lines[#lines + 1] = "  " .. parent.name .. " (#" .. pid .. "): " .. self:Pickup(parent)
                    chain(pid, depth + 1)
                end
            end
        end
    end
    chain(row.id, 1)
    if q.conflict then lines[#lines + 1] = FP.GOLD .. "Conflicting reports: " .. q.conflict .. "|r" end
    lines[#lines + 1] = q.classicSourceOnly and "Classic reference: Forever availability unconfirmed." or "Community reference: pickup, level and chain requirements may have changed in Forever."
    lines[#lines + 1] = "Reference: wowhead.com/forever/quest=" .. row.id
    return table.concat(lines, "\n\n")
end
