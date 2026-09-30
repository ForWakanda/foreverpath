-- ForeverPath / Core / Namespace.lua
-- One addon table, one event frame, one error sink. Everything else hangs off FP.
local ADDON, FP = ...
_G.ForeverPath = FP

FP.name = ADDON
FP.version = "dev"

FP.COLOR = "|cff5fd7ff"
FP.GREY  = "|cff9a9a9a"
FP.GOLD  = "|cffffd100"
FP.GREEN = "|cff5ad65a"
FP.RED   = "|cffff5a5a"

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------
local function join(...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do parts[i] = tostring((select(i, ...))) end
	return table.concat(parts, " ")
end

function FP:Print(...)
	local frame = DEFAULT_CHAT_FRAME or ChatFrame1
	local msg = FP.COLOR .. "ForeverPath|r: " .. join(...)
	if frame and frame.AddMessage then frame:AddMessage(msg) else print(msg) end
end

function FP:Debug(...)
	if FP.settings and FP.settings.debug then
		FP:Print(FP.GREY .. "[dbg]|r", ...)
	end
end

-------------------------------------------------------------------------------
-- Secret values (Midnight/Forever "addon disarmament"). A secret value looks
-- like a normal value but errors on comparison/arithmetic/concat. Anything the
-- recorder reads about units goes through FP.safe().
-------------------------------------------------------------------------------
local issecret = (type(issecretvalue) == "function") and issecretvalue or function() return false end
FP.issecret = issecret
function FP.safe(v)
	if v == nil then return nil end
	if issecret(v) then return nil end
	return v
end

-------------------------------------------------------------------------------
-- Error sink: never let one bad API call kill the addon; keep the last errors
-- in SavedVariables so they can be read from the file after the session.
-------------------------------------------------------------------------------
FP.errorCounts = {}
function FP:ReportError(where, err)
	err = tostring(err)
	local key = where .. "|" .. err
	local n = (FP.errorCounts[key] or 0) + 1
	FP.errorCounts[key] = n
	if FP.db then
		FP.db.errors = FP.db.errors or {}
		local list = FP.db.errors
		if n == 1 then
			table.insert(list, { t = (FP.API and FP.API.Now()) or 0, where = where, err = err, build = FP.clientBuild })
			while #list > 60 do table.remove(list, 1) end
		end
	end
	if n == 1 or (FP.settings and FP.settings.debug) then
		FP:Print(FP.RED .. "error|r in " .. where .. ": " .. err)
	end
end

function FP.pcall(where, fn, ...)
	local ok, a, b, c, d, e = pcall(fn, ...)
	if not ok then
		FP:ReportError(where, a)
		return nil
	end
	return a, b, c, d, e
end

-------------------------------------------------------------------------------
-- Events: one frame, a list of handlers per event, each handler in pcall.
-------------------------------------------------------------------------------
FP.frame = CreateFrame("Frame", "ForeverPathEventFrame")
FP.handlers = {}
FP.unavailableEvents = {}

function FP:RegisterEvent(event, fn)
	local list = FP.handlers[event]
	if not list then
		local ok, err = pcall(FP.frame.RegisterEvent, FP.frame, event)
		if not ok then
			FP.unavailableEvents[event] = tostring(err)
			FP:Debug("event unavailable:", event, err)
			return false
		end
		list = {}
		FP.handlers[event] = list
	end
	table.insert(list, fn)
	return true
end

FP.frame:SetScript("OnEvent", function(_, event, ...)
	local list = FP.handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], event, ...)
		if not ok then FP:ReportError(event, err) end
	end
end)

-------------------------------------------------------------------------------
-- Internal message bus (addon-internal, not addon comms).
-------------------------------------------------------------------------------
FP.callbacks = {}
function FP:On(msg, fn)
	FP.callbacks[msg] = FP.callbacks[msg] or {}
	table.insert(FP.callbacks[msg], fn)
end
function FP:Fire(msg, ...)
	local list = FP.callbacks[msg]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then FP:ReportError("msg:" .. msg, err) end
	end
end

-------------------------------------------------------------------------------
-- Modules: OnInit runs once SavedVariables exist, OnEnable at PLAYER_LOGIN.
-------------------------------------------------------------------------------
FP.modules = {}
FP.moduleOrder = {}
function FP:NewModule(name)
	local m = { name = name }
	FP.modules[name] = m
	table.insert(FP.moduleOrder, m)
	FP[name] = m
	return m
end
function FP:InitModules()
	for _, m in ipairs(FP.moduleOrder) do
		if m.OnInit then FP.pcall("init:" .. m.name, m.OnInit, m) end
	end
end
function FP:EnableModules()
	for _, m in ipairs(FP.moduleOrder) do
		if m.OnEnable then FP.pcall("enable:" .. m.name, m.OnEnable, m) end
	end
	FP.enabled = true
end

-------------------------------------------------------------------------------
-- Timers
-------------------------------------------------------------------------------
function FP.After(seconds, fn)
	C_Timer.After(seconds, function()
		local ok, err = pcall(fn)
		if not ok then FP:ReportError("timer", err) end
	end)
end

-- Coalesce bursts: many calls within `seconds` run fn once.
local pending = {}
function FP.Throttle(key, seconds, fn)
	if pending[key] then return end
	pending[key] = true
	C_Timer.After(seconds, function()
		pending[key] = nil
		local ok, err = pcall(fn)
		if not ok then FP:ReportError("throttle:" .. key, err) end
	end)
end
