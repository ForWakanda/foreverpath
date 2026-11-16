-- A display on the game's existing soft-interact nameplate. No targeting,
-- interaction, spell or loot calls. Optional because enabling the game's
-- Interact Key can also change how untargeted spells choose their recipient.
local _, FP = ...
local API = FP.API
local N = FP:NewModule("NearbySparkle")
local function settings() return FP.settings.questSparkle end
local function store()
	FP.db.questSparkle.nearby = FP.db.questSparkle.nearby or { restore = {} }
	return FP.db.questSparkle.nearby
end

function N:Note(state, object)
	if self.state == state and self.guid == (object and object.guid) then return end
	self.state, self.guid = state, object and object.guid
	store().last = { t = API.Now(), version = FP.version, build = FP.clientBuild,
		state = state, name = object and object.name, guid = object and object.guid }
	if state == "display attached" then
		store().lastAttached = store().last
		store().attachments = (store().attachments or 0) + 1
	end
end

function N:Ready()
	if not API.NearbySparkleAvailable() then return false, "unavailable" end
	for _, row in ipairs(API.NearbySparkleSettings()) do
		if row.value == nil then return false, "unavailable" end
		if tonumber(row.value) ~= tonumber(row.want) then return false, "setup" end
	end
	return true
end

-- Undo only values still equal to what we set. A later player/addon change wins.
-- Retain unsuccessful restores so a retry/reload cannot lose the original value.
function N:Restore()
	local st, current = store(), {}
	for _, row in ipairs(API.NearbySparkleSettings()) do current[row.name] = row.value end
	for i = #st.restore, 1, -1 do
		local row = st.restore[i]
		local value = current[row.name]
		if value ~= nil and value ~= row.applied then
			table.remove(st.restore, i)
		elseif value ~= nil then
			local ok = API.SetNearbySparkleSetting(row.name, row.before)
			if ok then table.remove(st.restore, i) else return false end
		else return false end
	end
	return #st.restore == 0
end

-- Called only by the explicit GUI setup button. There is no automatic reapply.
function N:Enable()
	if API.InCombat() then FP:Print("Nearby sparkles: leave combat, then click Enable again."); return false end
	if not API.NearbySparkleAvailable() then FP:Print("Nearby sparkles: this client has no supported object/nameplate API. Nothing changed."); return false end
	local rows = API.NearbySparkleSettings()
	for _, row in ipairs(rows) do
		if row.value == nil or tonumber(row.value) == nil then
			FP:Print("Nearby sparkles: this client does not expose all required settings. Nothing changed."); return false
		end
	end
	if not settings().nearby and #store().restore > 0 and not self:Restore() then
		FP:Print("Nearby sparkles: previous settings still need restoring. Click Disable / restore to retry."); return false
	end
	-- Re-read after finishing an earlier undo.
	rows = API.NearbySparkleSettings()
	for _, row in ipairs(rows) do
		if row.value == nil or tonumber(row.value) == nil then
			FP:Print("Nearby sparkles: settings became unavailable. Click Enable again when ready."); return false
		end
	end
	for _, row in ipairs(rows) do
		if tonumber(row.value) ~= tonumber(row.want) then
			local saved
			for _, old in ipairs(store().restore) do if old.name == row.name then saved = old; break end end
			-- If someone changed a previously owned setting, preserve that newer value.
			if saved then saved.before, saved.applied = row.value, row.want
			else store().restore[#store().restore + 1] = { name = row.name, before = row.value, applied = row.want } end
			local ok = API.SetNearbySparkleSetting(row.name, row.want)
			if not ok then
				settings().nearby = false; self:Hide(); self:Restore(); self:Note("setup refused")
				FP:Print("Nearby sparkles: the client refused setup. Previous settings restored where possible; use Disable / restore if an undo is pending.")
				return false
			end
		end
	end
	settings().nearby = true
	self.ready = self:Ready()
	self:Update()
	FP:Print("Nearby object sparkles enabled: one object at a time, within about 15 yards. Disable / restore undoes the Interact Key setup.")
	return true
end

function N:Disable()
	settings().nearby = false
	self:Hide()
	local ok = self:Restore()
	self:Note(ok and "off" or "restore pending")
	FP:Print(ok and "Nearby sparkles off; restored the settings this feature changed."
		or "Nearby sparkles off; restoring settings is pending. Leave combat, then click Disable / restore again if needed.")
	return ok
end

function N:Hide()
	if self.frame then self.frame:Hide(); self.frame:ClearAllPoints() end
	self.plate = nil
end

function N:CreateDisplay()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(72, 72); f:EnableMouse(false); f:SetFrameStrata("MEDIUM")
	f.stars = {}
	for i = 1, 6 do
		local star = f:CreateTexture(nil, "OVERLAY")
		star:SetTexture("Interface\\Cooldown\\star4")
		star:SetVertexColor(1, .8, .2); star:SetSize(14, 14)
		f.stars[i] = star
	end
	self.frame = f
	f:SetScript("OnUpdate", function(_, elapsed)
		N.phase = (N.phase or 0) + elapsed
		for i, star in ipairs(f.stars) do
			local angle = N.phase * .7 + i * math.pi / 3
			star:ClearAllPoints()
			star:SetPoint("CENTER", f, "CENTER", math.cos(angle) * 24, math.sin(angle) * 16)
			star:SetAlpha(.3 + .7 * math.abs(math.sin(N.phase * 2 + i)))
		end
	end)
	return f
end

function N:Update()
	if not settings().nearby then self:Hide(); self:Note("off"); return end
	if API.InCombat() then self:Hide(); self:Note("combat"); return end
	if not self.ready then self:Hide(); self:Note("setup needed"); return end
	local object, why = API.NearbySparkleObject()
	if not object then self:Hide(); self:Note(why); return end
	local f = self.frame or self:CreateDisplay()
	if self.plate ~= object.plate then
		f:ClearAllPoints()
		local ok = pcall(f.SetPoint, f, "CENTER", object.plate, "CENTER", 0, 0)
		if not ok then self:Hide(); self:Note("nameplate anchor unavailable"); return end
		self.plate = object.plate
	end
	f:Show(); self:Note("display attached", object)
end

function N:Lines()
	local ready, why = self:Ready()
	local enabled = settings().nearby
	local line = not enabled and "Nearby object sparkles: off."
		or (not ready and (why == "unavailable" and "Nearby sparkles: required settings unavailable." or "Nearby sparkles: settings changed; click Enable to set up again.")
		or "Nearby object sparkles: on (hidden in combat).")
	if #store().restore > 0 and not enabled then line = line .. " Settings restore pending." end
	return { line, "One nearby object at a time, about 15 yards. Includes quest objects, herbs, ore and chests; WoW chooses the object.",
		"The native effect remains separate. Neither mode guarantees every object will sparkle." }
end

function N:OnEnable()
	self.ready = self:Ready()
	local function refresh() N.ready = N:Ready(); N:Update() end
	FP:RegisterEvent("CVAR_UPDATE", function() FP.Throttle("nearby-sparkle-settings", .2, refresh) end)
	FP:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", function() N:Hide(); N:Update() end)
	FP:RegisterEvent("NAME_PLATE_UNIT_ADDED", function() N:Update() end)
	FP:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function() N:Hide() end)
	FP:RegisterEvent("PLAYER_REGEN_DISABLED", function() N:Hide(); N:Note("combat") end)
	FP:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if not settings().nearby and #store().restore > 0 then N:Restore() end
		refresh()
	end)
	FP:RegisterEvent("PLAYER_ENTERING_WORLD", refresh)
	-- Finish an explicit earlier off request, never activate settings at login.
	if not settings().nearby and #store().restore > 0 then self:Restore() end
	self:Update()
	if C_Timer and C_Timer.NewTicker then
		self.ticker = C_Timer.NewTicker(.2, function()
			if settings().nearby then FP.pcall("nearby-sparkle", N.Update, N) end
		end)
	end
end
