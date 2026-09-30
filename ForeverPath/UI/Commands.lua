-- ForeverPath / UI / Commands.lua
local ADDON, FP = ...
local U, API = FP.Util, FP.API
local C = FP:NewModule("Commands")

local function p(...) FP:Print(...) end

local function help()
	p("commands:")
	p("  /fp               toggle the next-steps panel")
	p("  /fp next          arrow to the planner's best next step")
	p("  /fp auto on|off   auto-advance the arrow (now " .. (FP.settings.autoNext and "on" or "off") .. ")")
	p("  /fp way 47.2 61.8 [title]   waypoint on your current map (also: way <mapID> x y)")
	p("  /fp way here [title] | way list | way next | way clear | way rm <id>")
	p("  /fp goto <quest id or part of the title>")
	p("  /fp arrow lock|unlock|flip|scale <n>|reset|hide|show")
	p("  /fp panel reset|scale <n>|lock|unlock")
	p("  /fp prof          professions + best skill-up crafts (open the profession window first)")
	p("  /fp record on|off | /fp status | /fp apicheck | /fp selftest | /fp export")
	p("  /fp pvp [status|track|spells|lock|reset|scale n|on|off]   PvP HUD: your CC/lockout timers with DR estimates, battleground objectives, enemies seen")
	p("  /fp probe [on|off|now|dump]   beta diagnostic: which values are secret, and when")
	p("  /fp partyexport | partyimport <string> | partysync")
	p("  /fp debug | /fp reset data|char confirm")
end

local function findQuest(arg)
	local id = tonumber(arg)
	for _, info in ipairs(API.GetQuestLog()) do
		if (id and info.questID == id) or (not id and tostring(info.title):lower():find(arg:lower(), 1, true)) then
			return info
		end
	end
	return nil
end

local function cmdWay(rest)
	local args = U.Split(rest, " ")
	local sub = args[1] and args[1]:lower() or ""
	if sub == "" or sub == "list" then
		if #FP.Waypoints.list == 0 then p("no waypoints"); return end
		for _, wp in ipairs(FP.Waypoints.list) do
			local active = FP.Waypoints:GetActive()
			p((active and active.id == wp.id and FP.GOLD .. "* |r" or "  ") .. FP.Waypoints:Describe(wp))
		end
	elseif sub == "clear" then
		FP.Waypoints:Clear(); p("waypoints cleared")
	elseif sub == "next" then
		local wp = FP.Waypoints:Next(); if wp then p("active: " .. tostring(wp.title)) end
	elseif sub == "rm" or sub == "remove" then
		if FP.Waypoints:Remove(tonumber(args[2] or "")) then p("removed") else p("no such id") end
	elseif sub == "here" then
		local pos = FP.Pos:Refresh(true)
		if not pos.mapID or not pos.x then p("no position available here"); return end
		local title = table.concat(args, " ", 2)
		FP.Waypoints:Add(pos.mapID, pos.x, pos.y, title ~= "" and title or ("Here " .. U.FormatCoords(pos.x, pos.y)), { persistent = true, radius = 5 })
		p("waypoint added at " .. U.FormatCoords(pos.x, pos.y))
	else
		-- Numeric triples mean mapID + percentage coordinates (including low map IDs).
		local a, b, c = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		local mapID, x, y, titleFrom
		if a and b and c then mapID, x, y, titleFrom = a, b / 100, c / 100, 4
		elseif a and b then mapID, x, y, titleFrom = API.GetBestMap(), a / 100, b / 100, 3
		else p("usage: /fp way <x%> <y%> [title] or /fp way <mapID> <x%> <y%> [title]"); return end
		if not U.ValidMapPoint(mapID, x, y) then p("use a positive integer map ID and coordinates from 0 to 100 percent"); return end
		local title = table.concat(args, " ", titleFrom)
		local wp = FP.Waypoints:Add(mapID, x, y, title ~= "" and title or (API.GetMapName(mapID) .. " " .. U.FormatCoords(x, y)))
		p("waypoint #" .. wp.id .. ": " .. wp.title)
	end
end

local function cmdArrow(rest)
	local args = U.Split(rest, " ")
	local sub = args[1] and args[1]:lower() or ""
	local s = FP.settings.arrow
	if sub == "lock" then s.locked = true
	elseif sub == "unlock" then s.locked = false
	elseif sub == "flip" then s.flip = not s.flip; p("arrow rotation flipped: " .. tostring(s.flip) .. " (use if the arrow points the wrong way)")
	elseif sub == "scale" then s.scale = math.max(0.4, math.min(3, tonumber(args[2] or "") or 1)); FP.Arrow:ApplySettings()
	elseif sub == "reset" then FP.Arrow:ResetPosition()
	elseif sub == "hide" then s.shown = false; FP.Arrow:Refresh()
	elseif sub == "show" then s.shown = true; FP.Arrow:Refresh()
	else p("arrow: lock | unlock | flip | scale <n> | reset | hide | show"); return end
	p("arrow " .. sub)
end

local function cmdPanel(rest)
	local args = U.Split(rest, " ")
	local sub = args[1] and args[1]:lower() or ""
	local s = FP.settings.panel
	if sub == "reset" then FP.Panel:ResetPosition()
	elseif sub == "scale" then s.scale = math.max(0.5, math.min(2, tonumber(args[2] or "") or 1)); FP.Panel:ApplySettings()
	elseif sub == "lock" then s.locked = true
	elseif sub == "unlock" then s.locked = false
	else FP.Panel:Toggle(); return end
	p("panel " .. sub)
end

local function cmdStatus()
	p("v" .. FP.version .. " · client " .. tostring(FP.clientVersion) .. " build " .. tostring(FP.clientBuild) .. " · toc " .. tostring(FP.clientToc))
	p("recording: " .. (FP.settings.record and FP.GREEN .. "on|r" or FP.RED .. "off|r") .. " · auto-next: " .. tostring(FP.settings.autoNext) .. " · debug: " .. tostring(FP.settings.debug))
	p("dataset: " .. FP.Recorder:Summary())
	local counters = FP.db.meta.counters
	local parts = {}
	for k, v in pairs(counters) do parts[#parts + 1] = k .. "=" .. v end
	table.sort(parts)
	p("counters: " .. table.concat(parts, " "))
	p("professions: " .. FP.Prof:Summary())
	p("party: " .. FP.Party:Summary())
	local wp = FP.Waypoints:GetActive()
	p("waypoint: " .. (wp and FP.Waypoints:Describe(wp) or "none") .. " · ticker " .. tostring(FP.Pos:IsTicking()))
	local errs = FP.db.errors or {}
	p("errors stored: " .. #errs .. (#errs > 0 and (" · last: " .. tostring(errs[#errs].where) .. ": " .. U.Truncate(errs[#errs].err, 120)) or ""))
	local pos = FP.Pos:Refresh(true)
	p("position: " .. (pos.mapID and (API.GetMapName(pos.mapID) .. " " .. (pos.x and U.FormatCoords(pos.x, pos.y) or "?")) or "unknown") .. " · facing " .. (pos.facing and string.format("%.2f", pos.facing) or "nil"))
end

local function cmdApiCheck()
	local rows = API.Check()
	local missing = {}
	local ok = 0
	for _, r in ipairs(rows) do
		if r.ok then ok = ok + 1 else missing[#missing + 1] = r.name .. (r.note and (" (" .. r.note .. ")") or "") end
	end
	p(string.format("API check: %d ok, %d missing/failed", ok, #missing))
	for _, m in ipairs(missing) do p("  " .. FP.RED .. "missing|r " .. m) end
	for _, r in ipairs(rows) do
		if r.name:find("^probe:") then p("  " .. (r.ok and FP.GREEN .. "ok|r " or FP.RED .. "no|r ") .. r.name .. (r.note and (": " .. r.note) or "")) end
	end
	API.StoreCheck(rows, true)
end

local function cmdProf()
	p("professions: " .. FP.Prof:Summary())
	local list, open = FP.Prof:BestCrafts(12)
	if not list then p(FP.GREY .. "open a profession window once so I can read its recipes, then /fp prof again|r"); return end
	p(string.format("%s %d/%d — skill-up crafts you can make now:", tostring(open.name), open.skill or 0, open.max or 0))
	local shown = 0
	for _, e in ipairs(list) do
		local col = FP.Prof.DIFF_COLORS[e.diff] or ""
		local craft = e.craftable
		if craft == nil then p("  " .. col .. e.name .. "|r " .. FP.GREY .. "(reagents not scanned yet)|r")
		elseif craft > 0 then p(string.format("  %s%s|r ×%d", col, e.name, craft)); shown = shown + 1
		else p(string.format("  %s%s|r ×0 " .. FP.GREY .. "need %s|r", col, e.name, FP.Prof:MissingFor(e.rec, 1))) end
	end
	if shown == 0 then p(FP.GREY .. "nothing craftable from your bags right now.|r") end
end

local function cmdGoto(arg)
	if not arg or arg == "" then p("usage: /fp goto <quest id | part of title>"); return end
	local info = findQuest(arg)
	if not info then p("no quest in your log matches '" .. arg .. "'"); return end
	FP.Planner:Build()
	for _, s in ipairs(FP.Planner.steps) do
		if s.questID == info.questID and s.mapID and s.x then
			FP.Planner:Go(s)
			p(FP.GOLD .. "Go:|r " .. s.title .. (s.dist and (" " .. U.FormatDistance(s.dist)) or ""))
			return
		end
	end
	p("no known location for '" .. tostring(info.title) .. "' yet (" .. (info.isComplete and "turn-in NPC unknown" or "objective area unknown") .. "). Talk to the giver again or make progress and I'll learn it.")
end

local exportFrame
local function showExport(text)
	if not exportFrame then
		exportFrame = CreateFrame("Frame", "ForeverPathExport", UIParent, "BackdropTemplate")
		exportFrame:SetSize(420, 90)
		exportFrame:SetPoint("CENTER")
		exportFrame:SetFrameStrata("DIALOG")
		if exportFrame.SetBackdrop then
			exportFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			exportFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
		end
		local eb = CreateFrame("EditBox", nil, exportFrame, "InputBoxTemplate")
		eb:SetSize(380, 30)
		eb:SetPoint("TOP", 0, -20)
		eb:SetAutoFocus(true)
		eb:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
		eb:SetScript("OnEnterPressed", function() exportFrame:Hide() end)
		exportFrame.eb = eb
		local hint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("BOTTOM", 0, 12)
		hint:SetText("Ctrl-C to copy, then paste to your friend: /fp partyimport <string>. Esc closes.")
	end
	exportFrame.eb:SetText(text)
	exportFrame.eb:HighlightText()
	exportFrame:Show()
end

function C:Handle(msg)
	msg = U.Trim(msg or "")
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower() or ""
	if cmd == "" or cmd == "panel" and rest == "" then FP.Panel:Toggle()
	elseif cmd == "help" or cmd == "?" then help()
	elseif cmd == "next" then
		FP.Planner:Build()
		local s = FP.Planner:NextStep()
		if s then FP.Planner:Go(s); p(FP.GOLD .. "Next:|r " .. s.title .. (s.dist and (" " .. U.FormatDistance(s.dist)) or "")) else p("nothing to plan: no quests with a known location") end
	elseif cmd == "auto" then
		local v = rest:lower()
		if v == "on" then FP.settings.autoNext = true elseif v == "off" then FP.settings.autoNext = false else FP.settings.autoNext = not FP.settings.autoNext end
		p("auto-next " .. (FP.settings.autoNext and "on" or "off"))
		if FP.settings.autoNext then FP.Planner:Auto("cmd") end
	elseif cmd == "way" or cmd == "wp" then cmdWay(rest)
	elseif cmd == "goto" then cmdGoto(rest)
	elseif cmd == "arrow" then cmdArrow(rest)
	elseif cmd == "panel" then cmdPanel(rest)
	elseif cmd == "prof" then cmdProf()
	elseif cmd == "status" then cmdStatus()
	elseif cmd == "apicheck" then cmdApiCheck()
	elseif cmd == "selftest" then FP.SelfTest:Run()
	elseif cmd == "record" then
		local v = rest:lower()
		if v == "on" then FP.settings.record = true elseif v == "off" then FP.settings.record = false else FP.settings.record = not FP.settings.record end
		FP.recordEpoch = (FP.recordEpoch or 0) + 1
		FP:Fire("RECORDING_CHANGED")
		p("recording " .. (FP.settings.record and "on" or "off"))
	elseif cmd == "audio" then
		local sub = rest:lower()
		local s = FP.settings.hunterAudio
		if sub == "on" then s.enabled = true; p("hunter combat audio feedback on")
		elseif sub == "off" then s.enabled = false; p("hunter combat audio feedback off")
		elseif sub == "test" then
			local f1, w1 = FP.HunterAudio:Play("short")
			local f2, w2 = FP.HunterAudio:Play("long")
			p("played " .. tostring(f1) .. " (" .. tostring(w1) .. "), " .. tostring(f2) .. " (" .. tostring(w2) .. ")" .. ((w1 and w2) and "" or " — a false/nil means the client did not find the file: restart the game client after deploying new sound files"))
		else p(FP.HunterAudio:Status()) end
	elseif cmd == "pvp" then FP.PvP:Command(rest)
	elseif cmd == "probe" then
		local sub = rest:lower()
		if sub == "on" then FP.settings.probe.enabled = true; p("probe on")
		elseif sub == "off" then FP.settings.probe.enabled = false; p("probe off")
		elseif sub == "now" then FP.Probe:Sample("manual"); for _, l in ipairs(FP.Probe:Status()) do p(l) end
		elseif sub == "dump" then
			for i = math.max(1, #FP.db.probe.samples - 9), #FP.db.probe.samples do
				local s = FP.db.probe.samples[i]
				p(string.format("#%d %s: %s", i, tostring(s.trig), s.sig))
			end
		else for _, l in ipairs(FP.Probe:Status()) do p(l) end end
	elseif cmd == "debug" then FP.settings.debug = not FP.settings.debug; p("debug " .. tostring(FP.settings.debug))
	elseif cmd == "export" then
		p("dataset: " .. FP.Recorder:Summary())
		p("saved on logout/reload to WTF\\Account\\<acct>\\SavedVariables\\ForeverPath.lua — /reload now to flush it to disk.")
	elseif cmd == "partyexport" then showExport(FP.Party:ExportString())
	elseif cmd == "partyimport" then
		local ok, name, n = FP.Party:Import(rest, "paste")
		if ok then p("imported " .. tostring(name) .. ": " .. n .. " quests; the planner now favours shared quests"); FP.Planner:Build() else p("that doesn't look like a ForeverPath export string") end
	elseif cmd == "partysync" then
		local sent, why = FP.Party:Send()
		p(sent and "sent your quest state to the party" or ("party sync failed: " .. tostring(why)))
	elseif cmd == "reset" then
		local what, confirm = rest:match("^(%S+)%s*(%S*)$")
		if confirm ~= "confirm" then p("this wipes data. /fp reset data confirm   or   /fp reset char confirm"); return end
		if what == "data" then
			ForeverPathDB = nil
			p("dataset wiped; /reload to finish")
		elseif what == "char" then
			ForeverPathCharDB = nil
			p("character settings wiped; /reload to finish")
		end
	else
		p("unknown command '" .. cmd .. "'. /fp help")
	end
end

SLASH_FOREVERPATH1 = "/fp"
SLASH_FOREVERPATH2 = "/foreverpath"
SlashCmdList["FOREVERPATH"] = function(msg)
	local ok, err = pcall(C.Handle, C, msg)
	if not ok then FP:ReportError("command", err) end
end

function ForeverPath_OnAddonCompartmentClick()
	FP.Panel:Toggle()
end
