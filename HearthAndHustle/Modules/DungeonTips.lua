-- HearthAndHustle / Modules / DungeonTips.lua
-- A card for the dungeon you are standing in: which stop of the run you are at
-- and what to use there. For a shaman that is one totem per element with the
-- reason; every class gets what the enemies at that stop do. Hover a line for
-- the long version.
--
-- What moves the card: your own clicks (the arrows, a line, /hh tips next), a
-- boss pull or kill when the game announces it by name, and a sub-zone name
-- where a dungeon has rooms the game names. Nothing else can: inside a dungeon
-- Forever hides enemy names, casts and debuffs from addons, so the card cannot
-- react to what a creature does, and it never targets, casts or places a totem.
-- Text comes from Data/DungeonTips.lua (Classic reference data, labelled so).
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local T = FP:NewModule("DungeonTips")
local D = FP.DungeonTipsData

local WIDTH, ROW_H, MAX_ROWS, LABEL_W, TOP = 380, 16, 12, 44, 24
local RUN_KEEP = 3 * 3600        -- seconds a run's place is kept while you are away
local RECEIPT_CAP = 60
local COLORS = {
	earth = "|cffd2a679", fire = "|cffff7a45", water = "|cff58b4ff", air = "|cffbfe8ff",
	watch = "|cffffd100", here = FP.GREY, next = FP.GREY, room = FP.GREY,
}

local function s() return FP.settings.dungeonTips end
local function receipts() return FP.db.dungeonTips end
local function norm(text) return type(text) == "string" and (text:lower():gsub("[^%a]", "")) or "" end
local function short(totem) return (tostring(totem):gsub(" Totem$", "")) end
local function plain(text) return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
T.Plain = plain

local function count(key) local c = receipts().counts; c[key] = (c[key] or 0) + 1 end

-------------------------------------------------------------------------------
-- Dungeons and the place in a run
-------------------------------------------------------------------------------
function T:Dungeon(key) return key and D.dungeons[key] or nil end

-- A dungeon by part of its name ("schol"), or nil.
function T:Find(text)
	local want = norm(text)
	if want == "" then return nil end
	for _, key in ipairs(D.order) do
		local d = D.dungeons[key]
		if norm(d.name):find(want, 1, true) or norm(key):find(want, 1, true) then return key end
	end
	return nil
end

-- The dungeon with tips you are standing in, or nil.
function T:Inside()
	local inst = API.GetInstance()
	if not inst.inInstance or type(inst.name) ~= "string" then return nil, inst end
	local name = inst.name:lower()
	for _, key in ipairs(D.order) do
		if name:find(D.dungeons[key].match, 1, true) then return key, inst end
	end
	return nil, inst
end

function T:IndexOf(dungeon, stopKey)
	for i, stop in ipairs(dungeon.stops) do if stop.key == stopKey then return i end end
	return nil
end

-- The place kept for a dungeon: { stop = key, killed = { key = true }, t, inside }.
function T:Run(key)
	local runs = FP.cdb.dungeonTips.runs
	local run = runs[key]
	if type(run) ~= "table" or type(run.killed) ~= "table" then
		run = { killed = {} }
		runs[key] = run
	end
	local dungeon = D.dungeons[key]
	if not self:IndexOf(dungeon, run.stop) then run.stop = dungeon.stops[1].key end
	return run
end

function T:NewRun(key)
	FP.cdb.dungeonTips.runs[key] = nil
	return self:Run(key)
end

-- Which dungeon the card is about: the one you are in, else the one being previewed.
function T:Active()
	local key = self.inside
	if not key and s().manual == "show" then
		key = self:Dungeon(FP.cdb.dungeonTips.preview) and FP.cdb.dungeonTips.preview or D.order[1]
	end
	if not key then return nil end
	local dungeon = D.dungeons[key]
	local run = self:Run(key)
	return key, dungeon, run, self:IndexOf(dungeon, run.stop)
end

function T:Go(target, how)
	local key, dungeon, run = self:Active()
	if not key then return false end
	local index = type(target) == "number" and target or self:IndexOf(dungeon, target)
	if not index or not dungeon.stops[index] then return false end
	run.stop, run.t, run.inside = dungeon.stops[index].key, U.Now(), self.inside == key
	count(how or "manual")
	receipts().last = { key = key, stop = run.stop, how = how or "manual", t = U.Now(), v = FP.version }
	self:Refresh()
	return true
end

function T:Step(delta)
	local key, dungeon, _, index = self:Active()
	if not key then return false end
	local to = index + delta
	if to < 1 then to = 1 elseif to > #dungeon.stops then to = #dungeon.stops end
	return self:Go(to, "manual")
end

-- A stop by number or by part of its title ("ras", "six", "jandice").
function T:Match(dungeon, text)
	local n = tonumber(text)
	if n and dungeon.stops[n] then return n end
	local want = norm(text)
	if want == "" then return nil end
	for i, stop in ipairs(dungeon.stops) do if norm(stop.key) == want then return i end end
	for i, stop in ipairs(dungeon.stops) do if norm(stop.title):find(want, 1, true) then return i end end
	return nil
end

-------------------------------------------------------------------------------
-- What the game announces
-------------------------------------------------------------------------------
-- The stop of a fight the game names, or nil. Either name may hold the other
-- ("The Lich, Ras Frostwhisper").
function T:StopForFight(dungeon, name)
	local want = norm(name)
	if want == "" then return nil end
	for i, stop in ipairs(dungeon.stops) do
		for _, boss in ipairs(stop.names or {}) do
			local b = norm(boss)
			if b == want or want:find(b, 1, true) or b:find(want, 1, true) then return i, stop end
		end
	end
	return nil
end

function T:StopForSubzone(dungeon, sub)
	local want = norm(sub)
	if want == "" then return nil end
	for i, stop in ipairs(dungeon.stops) do
		for _, room in ipairs(stop.subzones or {}) do if norm(room) == want then return i, stop end end
	end
	return nil
end

-- Kept so the next data pull shows what the game calls a fight or a room:
-- that is what a dungeon's `names` and `subzones` lists are written from.
local function note(store, key, extra)
	local rec = store[key]
	if not rec then
		if U.Count(store) >= RECEIPT_CAP then return end
		rec = { n = 0 }
		store[key] = rec
	end
	rec.n, rec.t, rec.v = rec.n + 1, U.Now(), FP.version
	for k, v in pairs(extra or {}) do rec[k] = v end
end

function T:OnFight(event, id, name, success)
	local key, inst = self:Inside()
	if not inst.inInstance then return end
	name, id = FP.safe(name), FP.safe(id)
	if type(name) ~= "string" then count("secretName"); return end
	local dungeon = self:Dungeon(key)
	local index, stop
	if dungeon then index, stop = self:StopForFight(dungeon, name) end
	note(receipts().encounters, tostring(inst.name) .. ": " .. name, { id = type(id) == "number" and id or nil, stop = stop and stop.key or false, last = event })
	if not stop or not s().enabled then return end
	self.inside = key
	local run = self:Run(key)
	if event == "ENCOUNTER_START" then
		self:Go(index, "pull")
	elseif event == "BOSS_KILL" or FP.safe(success) == 1 then
		self:Killed(dungeon, run, index)
	end
end

-- After a kill the card moves on, unless you have already stepped elsewhere
-- (which is also why a second announcement of the same kill moves nothing).
function T:Killed(dungeon, run, index)
	local stop = dungeon.stops[index]
	run.killed[stop.key] = true
	run.t = U.Now()
	if run.stop ~= stop.key then self:Refresh(); return end
	local to = index + 1
	if stop.group then
		local overview, last, open = nil, index, false
		for i, other in ipairs(dungeon.stops) do
			if other.group == stop.group then
				if other.kind == "overview" then overview = i
				else last = math.max(last, i); if not run.killed[other.key] then open = true end end
			end
		end
		to = open and overview or (last + 1)
	end
	if not dungeon.stops[to] then self:Refresh(); return end
	self:Go(to, "kill")
end

function T:OnZone(entering)
	local was = self.inside
	local key, inst = self:Inside()
	self.inside = s().enabled and key or nil
	if key then
		local _, sub = API.GetZoneText()
		if type(sub) == "string" and sub ~= "" then
			local rooms = receipts().subzones
			if not rooms[key] and U.Count(rooms) < 30 then rooms[key] = {} end
			if rooms[key] then note(rooms[key], sub) end
		end
		if self.inside then
			local run = self:Run(key)
			-- A place left over from a preview or from hours ago is not this run.
			if was ~= key and (not run.inside or not run.t or U.Now() - run.t > RUN_KEEP) then run = self:NewRun(key) end
			run.inside, run.t = true, U.Now()
			if was ~= key and entering ~= false then
				count("entered")
				self:Hello(key)
			end
			local index, stop = self:StopForSubzone(self:Dungeon(key), sub)
			if stop and run.stop ~= stop.key and not run.killed[stop.key] then self:Go(index, "room"); return end
		end
	end
	self:Refresh()
end

function T:Hello(key)
	if self.greeted == key then return end
	self.greeted = key
	local dungeon = self:Dungeon(key)
	FP:Print(FP.GOLD .. dungeon.name .. " tips|r are on the card: " .. #dungeon.stops .. " stops. The arrows on the card step through them (or /hh tips next on a button); a boss pull moves it when the game announces the fight. " .. FP.GREY .. D.source .. "|r")
end

-------------------------------------------------------------------------------
-- Lines
-------------------------------------------------------------------------------
-- The class is read again each time but never forgotten: a pull must not blank the card.
function T:Class()
	local class = API.GetCharInfo().class
	if type(class) == "string" then self.class = class end
	return self.class
end

-- A totem's icon, looked up once. The card is repainted on a boss pull, in
-- combat: a lookup that fails or answers with a hidden value there gives no
-- icon for now and is asked again later, and never costs the line itself.
local icons = {}
local function totemIcon(name)
	if icons[name] ~= nil then return icons[name] or nil end
	local def = D.totems[name]
	if not def then return nil end
	local ok, texture = pcall(function()
		local known = FP.safe(API.GetSpellName(def.id))
		if type(known) ~= "string" then return nil end
		if known ~= name then return false end
		return API.GetSpellTexture(def.id) or nil
	end)
	if not ok then return nil end
	if texture ~= nil then icons[name] = texture end   -- false: this client gives the id another name
	return texture or nil
end
T.Icon = totemIcon

local function stopTitle(stop, run)
	return stop.title .. (stop.optional and " (optional)" or "") .. (run and run.killed[stop.key] and " · done" or "")
end

-- The card's lines for one stop: { label, color, text, tip = { title, body }, icon, go, head }.
function T:Rows(dungeon, index, class, run)
	local stop = dungeon.stops[index]
	local rows = {}
	local function add(row) rows[#rows + 1] = row; return row end
	add({ head = true, text = stopTitle(stop, run), tip = { stop.title, (stop.roomHint and (stop.roomHint:gsub("^%l", string.upper) .. ". ") or "") .. (stop.threat or "") } })
	if stop.kind == "overview" then
		for i, other in ipairs(dungeon.stops) do
			if other.group == stop.group and other.kind ~= "overview" then
				local done = run and run.killed[other.key]
				local brief = other.brief and other.brief[class] or other.threat or ""
				add({ label = other.room or "", color = COLORS.room, go = i, dim = done and true or nil,
					text = (other.short or other.title) .. ": " .. (done and "done" or brief),
					tip = { other.title .. (other.roomHint and (" — " .. other.roomHint) or ""), (other.threat or "") .. "\nClick for this boss." } })
			end
		end
		add({ label = "Watch", color = COLORS.watch, text = stop.threat, tip = { stop.title, stop.threat } })
	else
		if stop.here then add({ label = "Here", color = COLORS.here, text = stop.here, tip = { "Who stands here", stop.here .. ". " .. (stop.threat or "") } })
		elseif stop.roomHint then add({ label = "Room", color = COLORS.room, text = (stop.roomHint:gsub("^%l", string.upper)), tip = { stop.title, stop.roomHint } }) end
		local lines = stop.classes and stop.classes[class]
		if lines then
			for _, line in ipairs(lines) do
				local element, totem, say, why = line[1], line[2], line[3], line[4]
				local names = short(totem) .. (line.or_ and (" or " .. short(line.or_)) or "")
				add({ label = D.elementNames[element] or element, color = COLORS[element], icon = totemIcon(totem),
					text = names .. " — " .. say,
					tip = { totem .. (line.or_ and (" or " .. line.or_) or ""), why } })
			end
		elseif stop.threat then
			add({ label = "Watch", color = COLORS.watch, text = stop.threat, tip = { stop.title, stop.threat } })
		end
		for _, w in ipairs(stop.watch or {}) do
			add({ label = "Watch", color = COLORS.watch, text = w[1], tip = { w[1], w[2] } })
		end
	end
	-- A boss of a group leads back to the group's list; the list leads past the group.
	local nextIndex, member = index + 1, stop.group and stop.kind ~= "overview"
	if stop.group then
		for i, other in ipairs(dungeon.stops) do
			if other.group == stop.group then
				if member and other.kind == "overview" then nextIndex = i
				elseif not member and i >= nextIndex then nextIndex = i + 1 end
			end
		end
	end
	local after = dungeon.stops[nextIndex]
	if after then
		add({ label = member and "Back" or "Next", color = COLORS.next, go = nextIndex, dim = true, text = stopTitle(after, run),
			tip = { after.title, (after.threat or "") .. "\nClick to go there." } })
	end
	return rows
end

-- The whole dungeon as chat or page lines.
function T:Lines(key, class)
	local dungeon = self:Dungeon(key)
	if not dungeon then return {} end
	class = class or self:Class()
	local out = { FP.GOLD .. dungeon.name .. "|r — " .. #dungeon.stops .. " stops. " .. FP.GREY .. D.source .. "|r" }
	for i, stop in ipairs(dungeon.stops) do
		if stop.kind ~= "overview" then
			local parts = {}
			for _, line in ipairs(stop.classes and stop.classes[class] or {}) do
				parts[#parts + 1] = (COLORS[line[1]] or "") .. short(line[2]) .. (line.or_ and ("/" .. short(line.or_)) or "") .. "|r"
			end
			out[#out + 1] = string.format("%d. %s%s|r%s", i, FP.GOLD, stopTitle(stop), #parts > 0 and (": " .. table.concat(parts, " · ")) or "")
			out[#out + 1] = "    " .. FP.GREY .. (stop.threat or "") .. "|r"
		else
			out[#out + 1] = string.format("%d. %s%s|r", i, FP.GOLD, stop.title)
		end
	end
	return out
end

function T:StatusText()
	local key, dungeon, _, index = self:Active()
	local lines = {}
	if not s().enabled then lines[#lines + 1] = "The tips card is switched off."
	elseif self.inside then lines[#lines + 1] = FP.GREEN .. "Inside " .. dungeon.name .. "|r: stop " .. index .. " of " .. #dungeon.stops .. ", " .. dungeon.stops[index].title .. "."
	elseif key then lines[#lines + 1] = "Previewing " .. dungeon.name .. ": stop " .. index .. " of " .. #dungeon.stops .. "."
	else lines[#lines + 1] = "The card appears by itself inside a dungeon that has tips." end
	local names = {}
	for _, k in ipairs(D.order) do names[#names + 1] = D.dungeons[k].name end
	lines[#lines + 1] = "Dungeons with tips: " .. table.concat(names, ", ") .. "."
	lines[#lines + 1] = FP.GREY .. D.source .. "|r"
	return table.concat(lines, "\n")
end

-------------------------------------------------------------------------------
-- Card
-------------------------------------------------------------------------------
local function savePosition(frame)
	local point, _, _, x, y = frame:GetPoint(1)
	if point then local set = s(); set.point, set.x, set.y = point, x, y end
end

local function showTip(owner, tip)
	if not tip or not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(tip[1], 1, 0.82, 0)
	if tip[2] and tip[2] ~= "" then GameTooltip:AddLine(tip[2], 1, 1, 1, true) end
	GameTooltip:Show()
end

local function smallButton(parent, text, onClick, tipTitle, tipBody)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(22, 18)
	b:SetText(text)
	b:SetScript("OnClick", function() FP.pcall("tips-click", onClick) end)
	b:SetScript("OnEnter", function(btn) showTip(btn, { tipTitle, tipBody }) end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return b
end

function T:OnInit()
	local f = CreateFrame("Frame", "HearthAndHustleDungeonTips", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(WIDTH, 80)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	local function dragStart() if not s().locked then f:StartMoving() end end
	local function dragStop() f:StopMovingOrSizing(); savePosition(f) end
	f:SetScript("OnDragStart", dragStart)
	f:SetScript("OnDragStop", dragStop)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
		f:SetBackdropBorderColor(0.35, 0.7, 1, 0.8)
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.title = title
	title:SetPoint("TOPLEFT", 8, -7)
	title:SetJustifyH("LEFT")
	self.close = smallButton(f, "x", function() T:Command("hide") end, "Hide the card", "/hh tips brings it back; /hh tips auto lets it appear by itself again.")
	self.close:SetPoint("TOPRIGHT", -6, -4)
	self.forward = smallButton(f, ">", function() T:Step(1) end, "Next stop", "Also: /hh tips next, which works from a macro button.")
	self.forward:SetPoint("RIGHT", self.close, "LEFT", -6, 0)
	self.back = smallButton(f, "<", function() T:Step(-1) end, "Previous stop", "Also: /hh tips prev.")
	self.back:SetPoint("RIGHT", self.forward, "LEFT", -2, 0)
	self.rows = {}
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, f)
		row:SetSize(WIDTH - 16, ROW_H)
		row:SetPoint("TOPLEFT", 8, -TOP - (i - 1) * ROW_H)
		row:EnableMouse(true)
		row:RegisterForDrag("LeftButton")
		row:SetScript("OnDragStart", dragStart)
		row:SetScript("OnDragStop", dragStop)
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", 0, 0)
		label:SetWidth(LABEL_W)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(13, 13)
		icon:SetPoint("LEFT", LABEL_W, 0)
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", LABEL_W + 17, 0)
		text:SetPoint("RIGHT", -2, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		row.label, row.icon, row.text = label, icon, text
		row:SetScript("OnEnter", function(r) if r.data then showTip(r, r.data.tip) end end)
		row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		row:SetScript("OnMouseUp", function(r) if r.data and r.data.go then FP.pcall("tips-row", function() T:Go(r.data.go, "manual") end) end end)
		row:Hide()
		self.rows[i] = row
	end
	self:ApplySettings()
	f:Hide()
end

function T:ApplySettings()
	local set, f = s(), self.frame
	f:ClearAllPoints()
	f:SetPoint(set.point or "TOPLEFT", UIParent, set.point or "TOPLEFT", set.x or 30, set.y or -420)
	f:SetScale(set.scale or 1)
end

function T:ResetPosition()
	local set = s()
	set.point, set.x, set.y, set.scale = "TOPLEFT", 30, -420, 1
	self:ApplySettings()
end

function T:Refresh()
	local f = self.frame
	if not f then return end
	local set = s()
	local key, dungeon, run, index = self:Active()
	if not set.enabled or set.manual == "hide" or not key then f:Hide(); return end
	local rows = self:Rows(dungeon, index, self:Class(), run)
	self.shown = rows
	self.title:SetText(FP.COLOR .. "Hearth & Hustle|r tips · " .. dungeon.name .. " · " .. index .. "/" .. #dungeon.stops .. (self.inside and "" or FP.GREY .. " · preview|r"))
	local n = 0
	for i, row in ipairs(self.rows) do
		local r = rows[i]
		row.data = r
		if r then
			n = n + 1
			if r.head then
				row.label:SetText("")
				row.label:SetWidth(1)
				row.icon:Hide()
				row.text:ClearAllPoints()
				row.text:SetPoint("LEFT", 0, 0)
				row.text:SetPoint("RIGHT", -2, 0)
				row.text:SetText(FP.GOLD .. r.text .. "|r")
			else
				row.label:SetWidth(LABEL_W)
				row.label:SetText((r.color or "") .. (r.label or "") .. "|r")
				if r.icon then row.icon:SetTexture(r.icon); row.icon:Show() else row.icon:Hide() end
				row.text:ClearAllPoints()
				row.text:SetPoint("LEFT", LABEL_W + (r.icon and 17 or 0), 0)
				row.text:SetPoint("RIGHT", -2, 0)
				row.text:SetText((r.dim and FP.GREY or "") .. r.text .. (r.dim and "|r" or ""))
			end
			row:Show()
		else
			row:Hide()
		end
	end
	f:SetHeight(TOP + n * ROW_H + 8)
	if not f:IsShown() then f:Show(); count("shown") end
end

-------------------------------------------------------------------------------
-- /hh tips ...
-------------------------------------------------------------------------------
function T:Command(rest)
	rest = U.Trim(rest or "")
	local args = U.Split(rest, " ")
	local sub = (args[1] or ""):lower()
	local tail = U.Trim(rest:sub(#(args[1] or "") + 1))
	local set = s()
	local p = function(...) FP:Print(...) end
	local function preview(text)
		local key = text ~= "" and self:Find(text) or nil
		if text ~= "" and not key then p("No tips for \"" .. text .. "\" yet. Dungeons with tips: " .. table.concat(self:Names(), ", ") .. "."); return false end
		if key then FP.cdb.dungeonTips.preview = key end
		return true
	end
	if sub == "" or sub == "toggle" then
		set.manual = (self.frame:IsShown() and "hide" or "show")
		if set.manual == "show" then set.enabled = true end
		self:Refresh()
		p("Tips card " .. (self.frame:IsShown() and "shown" or "hidden") .. ". /hh tips auto lets it appear by itself inside a dungeon.")
	elseif sub == "show" then
		if not preview(tail) then return end
		set.manual, set.enabled = "show", true
		self:Refresh()
		local key = self:Active()
		p("Tips card shown" .. (self.inside and "" or (": a preview of " .. self:Dungeon(key).name)) .. ".")
	elseif sub == "hide" then set.manual = "hide"; self:Refresh(); p("Tips card hidden. /hh tips auto brings it back inside a dungeon.")
	elseif sub == "auto" then set.manual = nil; self:Refresh(); p("Tips card automatic: it appears inside a dungeon that has tips.")
	elseif sub == "on" or sub == "off" then
		set.enabled = sub == "on"
		self:OnZone(false)
		p("Dungeon tips " .. sub .. ".")
	elseif sub == "lock" then set.locked = true; p("Tips card locked.")
	elseif sub == "unlock" then set.locked = false; p("Tips card unlocked: drag it.")
	elseif sub == "reset" then self:ResetPosition(); p("Tips card position reset.")
	elseif sub == "scale" then set.scale = math.max(0.5, math.min(2, tonumber(args[2] or "") or 1)); self:ApplySettings(); p("Tips card size " .. set.scale)
	elseif sub == "next" or sub == "prev" or sub == "back" then
		if not self:Step(sub == "next" and 1 or -1) then p("No dungeon card to step. /hh tips show previews one.") end
	elseif sub == "first" or sub == "newrun" then
		local key = self:Active()
		if not key then p("No dungeon card. /hh tips show previews one."); return end
		if sub == "newrun" then self:NewRun(key) end
		self:Go(1, "manual")
		if sub == "newrun" then p("Tips: " .. self:Dungeon(key).name .. " starts over at the first stop.") end
	elseif sub == "go" or tonumber(sub) then
		local key, dungeon = self:Active()
		if not key then p("No dungeon card. /hh tips show previews one."); return end
		local want = sub == "go" and tail or sub
		local index = self:Match(dungeon, want)
		if not index then p("No stop \"" .. want .. "\" in " .. dungeon.name .. ". /hh tips list shows them."); return end
		self:Go(index, "manual")
	elseif sub == "list" then
		local key
		if tail ~= "" then key = self:Find(tail) else key = self:Active() or D.order[1] end
		if not key then p("No tips for \"" .. tail .. "\" yet. Dungeons with tips: " .. table.concat(self:Names(), ", ") .. "."); return end
		for _, line in ipairs(self:Lines(key)) do p(line) end
	elseif sub == "status" then
		for line in self:StatusText():gmatch("[^\n]+") do p(line) end
	else
		p("/hh tips | show [dungeon] | hide | auto | on | off | next | prev | first | go <stop number or name> | list [dungeon] | newrun | lock | unlock | reset | scale <n> | status")
	end
end

function T:Names()
	local names = {}
	for _, key in ipairs(D.order) do names[#names + 1] = D.dungeons[key].name end
	return names
end

function T:OnEnable()
	local function zone(entering) return function() FP.After(1, function() T:OnZone(entering) end) end end
	FP:RegisterEvent("PLAYER_ENTERING_WORLD", zone(true))
	FP:RegisterEvent("ZONE_CHANGED_NEW_AREA", zone(true))
	FP:RegisterEvent("ZONE_CHANGED_INDOORS", zone(true))
	FP:RegisterEvent("ZONE_CHANGED", zone(true))
	FP:RegisterEvent("ENCOUNTER_START", function(event, id, name) T:OnFight(event, id, name) end)
	FP:RegisterEvent("ENCOUNTER_END", function(event, id, name, _, _, success) T:OnFight(event, id, name, success) end)
	FP:RegisterEvent("BOSS_KILL", function(event, id, name) T:OnFight(event, id, name) end)
	FP.After(2, function() T:OnZone(true) end)
end
