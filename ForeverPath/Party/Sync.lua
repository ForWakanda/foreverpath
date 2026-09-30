-- Party seed + bounded addon-message snapshots. Paste state is deliberately persistent;
-- connected-party state is discarded when that sender leaves the group.
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local S = FP:NewModule("Party")
local MAX_IDS, MAX_BYTES = 40, 1024
local sequence, pending = 0, {}

function S:ExportString()
	local c, ids = API.GetCharInfo(), {}
	for _, info in ipairs(API.GetQuestLog()) do
		ids[#ids + 1] = info.questID .. (info.isComplete and "c" or "")
		if #ids >= MAX_IDS then break end
	end
	table.sort(ids)
	return string.format("FP1;%s;%s;%s;%s", tostring(c.name), tostring(c.class or "?"), tostring(c.level or 0), table.concat(ids, ","))
end

-- Pure parser: also used by the in-game self-test without touching player state.
function S:Parse(str)
	if type(str) ~= "string" or #str > MAX_BYTES then return nil end
	local name, class, level, list = str:match("^FP1;([^;]+);([^;]+);(%d+);(.*)$")
	if not name or #name > 64 or #class > 24 or not U.Finite(tonumber(level)) then return nil end
	local quests, complete, n = {}, {}, 0
	for token in list:gmatch("[^,]+") do
		local id, c = token:match("^(%d+)(c?)$")
		id = tonumber(id)
		if not U.Finite(id) or id < 1 or id > 2147483647 then return nil end
		n = n + 1
		if n > MAX_IDS then return nil end
		quests[id] = true
		if c == "c" then complete[id] = true end
	end
	return { name = name, class = class, level = tonumber(level), quests = quests, complete = complete }
end

function S:Import(str, from)
	local p = self:Parse(str)
	if not p then return false end
	p.t, p.from = U.Now(), from
	p.mode = from == "paste" and "paste" or "live"
	FP.cdb.party = p
	FP:Fire("PARTY_UPDATED")
	return true, p.name, U.Count(p.quests)
end

function S:Send()
	if not API.InGroup() then return false, "not in a party" end
	local text = self:ExportString()
	if #text <= 255 then return API.SendPartyMessage(text) end
	if #text > MAX_BYTES then return false, "quest snapshot too large; use partyexport" end
	sequence = sequence + 1
	local id = tostring(U.Now()) .. "-" .. sequence
	local total = math.ceil(#text / 180)
	for i = 1, total do
		local ok, why = API.SendPartyMessage(string.format("FP2;%s;%d;%d;%s", id, i, total, text:sub((i-1)*180+1, i*180)))
		if not ok then return false, why end
	end
	return true
end

function S:Receive(msg, sender)
	if msg:sub(1, 4) == "FP1;" then pending[sender] = nil; return self:Import(msg, sender) end
	local id, part, total, body = msg:match("^FP2;([%d%-]+);(%d+);(%d+);(.*)$")
	part, total = tonumber(part), tonumber(total)
	if not id or #id > 40 or not part or not total or total > 6 or part < 1 or part > total or #body > 180 then return false end
	local now = U.Now()
	for who, p in pairs(pending) do if now - p.t > 15 then pending[who] = nil end end
	local p = pending[sender]
	if not p or p.id ~= id then p = { id = id, total = total, t = now, chunks = {} }; pending[sender] = p end
	if p.total ~= total then pending[sender] = nil; return false end
	p.chunks[part] = body
	for i = 1, total do if not p.chunks[i] then return false end end
	pending[sender] = nil
	return self:Import(table.concat(p.chunks), sender)
end

function S:OnRoster()
	pending = {}
	local p = FP.cdb.party
	if p.mode ~= "paste" and p.name and not API.IsPartySender(p.from) then
		FP.cdb.party = {}
		FP:Fire("PARTY_UPDATED")
	end
	FP.Throttle("party-send", 5, function() S:Send() end)
end

function S:OnEnable()
	API.RegisterPrefix()
	self:OnRoster()
	FP:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
		prefix, msg, channel, sender = FP.safe(prefix), FP.safe(msg), FP.safe(channel), FP.safe(sender)
		if prefix ~= API.PREFIX or channel ~= "PARTY" or type(msg) ~= "string" or #msg > 255 or not API.IsPartySender(sender) then return end
		self:Receive(msg, sender)
	end)
	FP:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:OnRoster() end)
	local function sendSoon() FP.Throttle("party-send", 5, function() S:Send() end) end
	for _, event in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "LEVEL_UP" }) do FP:On(event, sendSoon) end
	FP:On("QUESTLOG_SCANNED", function()
		local snapshot = self:ExportString()
		if snapshot ~= self.lastSnapshot then self.lastSnapshot = snapshot; sendSoon() end
	end)
end

function S:SharedWith(questID)
	local p = FP.cdb.party
	return p and p.quests and p.quests[questID] and true or false
end

function S:Summary()
	local p = FP.cdb.party
	if not p or not p.name then return FP.GREY .. "no party state (/fp partyexport on their side, /fp partyimport here)|r" end
	local shared = 0
	for _, info in ipairs(API.GetQuestLog()) do if p.quests[info.questID] then shared = shared + 1 end end
	return string.format("%s (%s %s): %d quests, %d shared%s", tostring(p.name), tostring(p.class), tostring(p.level), U.Count(p.quests), shared, p.mode == "paste" and " (paste seed)" or "")
end
