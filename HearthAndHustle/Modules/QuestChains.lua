-- Quest graph reference + current character state. Never infers a live offer
-- from prerequisite completion, and never changes gameplay while browsing.
local _, FP = ...
local API, U = FP.API, FP.Util
local C = FP:NewModule("QuestChains")
C.records, C.followups, C.starters = {}, {}, {}

local function id(value) return U.Finite(value) and value > 0 and value == math.floor(value) end
local function present(value) return U.Finite(value) and value ~= 0 end
local function any(values)
	local unknown = false
	for _,v in ipairs(values) do if v.value == true then return true elseif v.value == nil then unknown=true end end
	if unknown then return nil end
	return false
end
local function all(values)
	local unknown = false
	for _,v in ipairs(values) do if v.value == false then return false elseif v.value == nil then unknown=true end end
	if unknown then return nil end
	return true
end

function C:Get(questID)
	if not id(questID) then return nil end
	if self.records[questID] == nil then self.records[questID] = API.GetQuestChainRecord(questID) or false end
	return self.records[questID] or nil
end

function C:Title(questID)
	local q = self:Get(questID)
	return (q and q.name or API.GetQuestTitle(questID) or "Quest") .. " (#" .. questID .. ")"
end

-- Build the reverse edges and name index in small batches, only on first use.
-- A refresh generation prevents old queued batches writing into a new index.
function C:StartIndex(force)
	if self.loading or self.indexed then if not force then return end end
	self.generation = (self.generation or 0)+1
	local generation = self.generation
	self.records,self.followups,self.searchRows,self.starters = {},{},{},{}
	self.indexed,self.loading,self.scanned = false,false,0
	local ready,status = API.QuestDatabaseStatus()
	self.status = status
	local ids = ready and API.GetQuestChainIDs() or nil
	if not ids then self.status = ready and "Database search unavailable; current quests can still be inspected." or status; return end
	self.loading,self.total = true,#ids
	local function link(parent,child)
		if not id(parent) or not id(child) then return end
		self.followups[parent] = self.followups[parent] or {}
		self.followups[parent][child] = true
	end
	local function batch()
		if generation ~= self.generation then return end
		for i=self.scanned+1,math.min(self.scanned+40,#ids) do
			local q = self:Get(ids[i])
			if q then
				self.searchRows[#self.searchRows+1] = {key=q.id,id=q.id,name=q.name,lower=q.name:lower()}
				-- Reverse prerequisites, not nextQuestInChain: that field also
				-- suppresses an earlier quest after the later quest is accepted.
				for _,list in ipairs({q.preQuestGroup,q.preQuestSingle}) do
					for _,parent in ipairs(list) do link(math.abs(parent),q.id) end
				end
				link(q.parentQuest,q.id); link(q.availableStartingWith,q.id)
			end
			self.scanned=i
		end
		if self.scanned >= #ids then
			self.loading,self.indexed = false,true
			table.sort(self.searchRows,function(a,b) if a.lower~=b.lower then return a.lower<b.lower end return a.id<b.id end)
			self.status = #self.searchRows .. " quest records searchable. Reference data may be incomplete."
			FP:Fire("QUEST_CHAINS_CHANGED")
		else FP.After(.02,batch) end
	end
	batch()
end

function C:Context()
	local ctx={states={},log={},offers={},level=API.PlayerLevel()}
	for _,q in ipairs(API.GetQuestLog()) do ctx.log[q.questID]=q end
	for _,q in ipairs(API.GetQuestOffers(API.GetBestMap())) do ctx.offers[q.questID]=q end
	function ctx:State(questID)
		if not self.states[questID] then
			local s = API.GetDungeonQuestState(questID)
			-- A live log row is stronger evidence than an unavailable IsOnQuest.
			if self.log[questID] then s.onQuest=true; s.ready=self.log[questID].isComplete end
			self.states[questID]=s
		end
		return self.states[questID]
	end
	return ctx
end

function C:StateLabel(questID,ctx)
	local s=ctx:State(questID)
	if s.onQuest then return s.ready and "Ready to turn in" or "In quest log" end
	if s.completed then return "Completed" end
	if ctx.offers[questID] then return "Offered on current map" end
	if s.onQuest == nil or s.completed == nil then return "State unknown" end
	return "Not in quest log"
end

function C:PrerequisiteValue(parent,group,ctx)
	if parent<0 and not group then return nil end -- only ALL groups define signed entries
	local pid=math.abs(parent)
	local completed=ctx:State(pid).completed
	if completed == true or not group or parent < 0 then return completed end
	-- A positive ALL-group entry can be satisfied by one of its exclusive
	-- alternatives; a negative entry explicitly requires that exact quest.
	local q=self:Get(pid)
	if not q then return nil end
	local alternatives={{value=completed}}
	for _,alt in ipairs(q.exclusiveTo) do
		local value
		if id(alt) then value=ctx:State(alt).completed end
		alternatives[#alternatives+1]={value=value}
	end
	return any(alternatives)
end

function C:Requirements(q,ctx)
	local gates,notes={},{}
	local single,group=q.preQuestSingle,q.preQuestGroup
	if #single>0 and #group>0 then
		gates[#gates+1]={value=nil}; notes[#notes+1]="Conflicting prerequisite lists: verify at the quest giver."
	else
		local list=#single>0 and single or group
		if #list>0 then
			local values={}
			for _,pid in ipairs(list) do values[#values+1]={value=self:PrerequisiteValue(pid,#group>0,ctx)} end
			local value
			if #single>0 then value=any(values) else value=all(values) end
			gates[#gates+1]={value=value}
			notes[#notes+1]=(#single>0 and "Complete ANY ONE listed prerequisite" or "Complete ALL listed prerequisites") ..
				(value==true and " — met." or (value==false and " — not yet met." or " — state unknown."))
		end
	end
	for _,spec in ipairs({{"parentQuest","Keep in your quest log: ","active"},{"availableStartingWith","Active or completed: ","either"}}) do
		local pid=q[spec[1]]
		if id(pid) then
			local s=ctx:State(pid)
			local value=s.onQuest
			if spec[3]=="either" then value=any({{value=s.onQuest},{value=s.completed}}) end
			gates[#gates+1]={value=value}
			notes[#notes+1]=spec[2]..self:Title(pid)..(value==true and " — met." or (value==false and " — needed." or " — unknown."))
		end
	end
	if q.incomplete then gates[#gates+1]={value=nil}; notes[#notes+1]="Some reference fields could not be read." end
	if #gates==0 then notes[#notes+1]="No prerequisite quests listed; this does not prove the quest has none." end
	return all(gates),notes
end

function C:Blockers(q,ctx)
	local notes={}
	local function check(pid,mode,label)
		if not id(pid) then return end
		local s=ctx:State(pid)
		local value
		if mode=="active" then value=s.onQuest
		elseif mode=="complete" then value=s.completed
		else value=any({{value=s.onQuest},{value=s.completed}}) end
		if value then notes[#notes+1]=label..self:Title(pid)
		elseif value==nil then notes[#notes+1]="Linked restriction state unknown: "..self:Title(pid) end
	end
	for _,pid in ipairs(q.exclusiveTo) do check(pid,"either","Alternative branch active/completed: ") end
	check(q.nextQuestInChain,"either","Later step already active/completed: ")
	check(q.availableUntilCompleted,"complete","Listed cutoff already completed: ")
	check(q.disabledByQuest,"active","Listed blocker in quest log: ")
	check(q.breadcrumbForQuestId,"either","Lead-in destination already active/completed: ")
	for _,pid in ipairs(q.breadcrumbs) do check(pid,"active","Optional lead-in still in your log: ") end
	return notes
end

function C:Search(query,currentOnly,ctx)
	query=U.Trim(query or ""):lower()
	local rows,seen={},{}
	local function add(questID,name)
		if seen[questID] then return end
		if query=="" or tostring(questID)==query:gsub("^#","") or name:lower():find(query,1,true) then
			seen[questID]=true
			rows[#rows+1]={key=questID,id=questID,name=name}
		end
	end
	-- Search evaluates live state only for matching rows, not the whole DB.
	for questID,q in pairs(ctx.log) do add(questID,tostring(q.title)) end
	if not currentOnly then for _,row in ipairs(self.searchRows or {}) do add(row.id,row.name) end end
	table.sort(rows,function(a,b)
		local al,bl=ctx.log[a.id]~=nil,ctx.log[b.id]~=nil
		if al~=bl then return al end
		if a.name~=b.name then return a.name<b.name end
		return a.id<b.id
	end)
	return rows
end

function C:Links(questID,ctx)
	local rows,seen,visits={},{},0
	local function add(pid,label,depth)
		if not id(pid) then return end
		local key=label:gsub(" %[met%]", "")..":"..pid..":"..depth
		if seen[key] or #rows>=100 then return end
		seen[key]=true
		rows[#rows+1]={key=key,id=pid,label=string.rep("  ",depth)..label..": "..self:Title(pid).." — "..self:StateLabel(pid,ctx)}
	end
	local function parents(pid,depth,trail)
		visits=visits+1
		if visits>100 then return end
		local q=self:Get(pid)
		if not q then return end
		for _,spec in ipairs({{q.preQuestSingle,"Need any one"},{q.preQuestGroup,"Need all"}}) do
			for _,signed in ipairs(spec[1]) do
				if #rows>=70 then return end -- reserve room for direct follow-ups
				local parent=math.abs(signed)
				local value=self:PrerequisiteValue(signed,spec[2]=="Need all",ctx)
				local label=spec[2]..(signed<0 and (spec[2]=="Need all" and " (exact quest)" or " (special reference; verify)") or "")..(value==true and " [met]" or "")
				if trail[parent] then add(parent,label.." [cycle in reference]",depth)
				else
					add(parent,label,depth)
					if depth<7 and #rows<90 then trail[parent]=true; parents(parent,depth+1,trail);trail[parent]=nil end
				end
			end
		end
	end
	parents(questID,0,{[questID]=true})
	local q=self:Get(questID)
	if not q then return rows end
	for _,spec in ipairs({{"parentQuest","Keep in log"},{"availableStartingWith","Active or completed"},
		{"breadcrumbForQuestId","Optional lead-in destination"},{"nextQuestInChain","Later step / cutoff"},
		{"availableUntilCompleted","Closes after completing"},{"disabledByQuest","Blocked while active"}}) do add(q[spec[1]],spec[2],0) end
	for _,spec in ipairs({{"breadcrumbs","Optional lead-in"},{"exclusiveTo","Alternative branch"},{"inGroupWith","Related quest"}}) do
		for _,pid in ipairs(q[spec[1]]) do add(pid,spec[2],0) end
	end
	local follows={}
	for pid in pairs(self.followups[questID] or {}) do follows[pid]=true end
	for _,pid in ipairs(q.childQuests) do follows[pid]=true end
	local sorted={};for pid in pairs(follows) do sorted[#sorted+1]=pid end;table.sort(sorted)
	for _,pid in ipairs(sorted) do add(pid,"Follow-up (check its requirements)",0) end
	return rows
end

function C:Starters(questID)
	if not self.starters[questID] then self.starters[questID]=API.GetQuestChainStarters(questID) end
	return self.starters[questID]
end

function C:Details(questID,ctx)
	local q=self:Get(questID)
	local lines={self:Title(questID).." — "..self:StateLabel(questID,ctx)}
	local ready,providerStatus=API.QuestDatabaseStatus()
	if not ready then lines[#lines+1]=providerStatus end
	if not q then lines[#lines+1]="No chain reference found. This is a coverage gap, not proof of no prerequisites.";return lines end
	if present(q.requiredLevel) then lines[#lines+1]="Listed minimum level: "..q.requiredLevel..(U.Finite(ctx.level) and ctx.level<q.requiredLevel and " — you need more levels." or "") end
	local value,notes=self:Requirements(q,ctx)
	for _,line in ipairs(notes) do lines[#lines+1]=line end
	for _,line in ipairs(self:Blockers(q,ctx)) do lines[#lines+1]=line.." (reference)." end
	local restrictions={}
	for _,spec in ipairs({{"requiredClasses","class"},{"requiredRaces","race/faction"},{"requiredSpell","spell"},{"requiredSpecialization","specialization"},{"requiredMaxLevel","maximum level"},{"specialFlags","repeat/event rules"}}) do
		if present(q[spec[1]]) then restrictions[#restrictions+1]=spec[2] end
	end
	for _,spec in ipairs({{"requiredSkill","profession"},{"requiredRanks","profession rank"},{"requiredMinRep","minimum reputation"},{"requiredMaxRep","maximum reputation"}}) do
		if q[spec[1]] then restrictions[#restrictions+1]=spec[2] end
	end
	if #restrictions>0 then lines[#lines+1]="Other listed restrictions: "..table.concat(restrictions,", ")..". Check the quest giver." end
	local starts=self:Starters(questID)
	for i,start in ipairs(starts) do
		if i>6 then lines[#lines+1]="More pickup sources are listed in the database.";break end
		local text="Pickup: "..start.name..(start.kind=="Item" and " (starting item)" or "")
		local point=start.points[1]
		if point then text=text..(point.entrance and " — dungeon entrance (giver inside): " or " — ")..API.GetMapName(point.mapID).." "..U.FormatCoords(point.x,point.y) end
		lines[#lines+1]=text
	end
	if #starts==0 then lines[#lines+1]="Pickup source not recorded." end
	lines[#lines+1]="Reference chain; completion alone does not guarantee pickup availability. Optional lead-ins are not mandatory prerequisites."
	if not self.indexed then lines[#lines+1]="Follow-up search is incomplete while the index loads or the database is unavailable." end
	return lines
end

function C:GuidePickup(questID)
	if not id(questID) then return false,"Choose a quest first." end
	local ctx=self:Context()
	local state=ctx:State(questID)
	if state.onQuest or state.completed then return false,"This quest is already in your log or completed; use normal quest guidance." end
	if state.onQuest==nil or state.completed==nil then return false,"Quest state is unavailable; check the quest log before choosing a pickup." end
	local offer=ctx.offers[questID]
	local best,distance=offer,nil
	if not best then
		FP.Pos:Refresh(true)
		for _,starter in ipairs(self:Starters(questID)) do
			for _,point in ipairs(starter.points) do
				local d=FP.Pos:DistanceTo(point) or math.huge
				if (not point.entrance or not API.InInstance()) and d and (not distance or d<distance) then best,distance=point,d end
			end
		end
	end
	if not best then return false,"No pickup coordinates could be resolved. Check the pickup details." end
	FP.Waypoints:RemoveBySource("chain-pickup")
	FP.Waypoints:Add(best.mapID,best.x,best.y,(best.entrance and "Entrance for pickup: " or "Pickup: ")..self:Title(questID),{
		source={type="chain-pickup",questID=questID,entrance=best.entrance},radius=15,
		desc=best.entrance and ("Entrance to "..best.dungeonName.."; quest giver is inside. Check requirements there.") or "Known pickup location; check requirements with the quest giver."})
	return true,best.entrance and "Guiding to the dungeon entrance; the known quest giver is inside. Availability is not guaranteed." or "Guiding to the known pickup location. Availability is not guaranteed."
end

function C:OnEnable()
	FP:On("QUESTLOG_SCANNED",function()
		for i=#FP.Waypoints.list,1,-1 do
			local wp=FP.Waypoints.list[i]
			if wp.source and wp.source.type=="chain-pickup" then
				local s=API.GetDungeonQuestState(wp.source.questID)
				if s.onQuest or s.completed then FP.Waypoints:Remove(wp.id) end
			end
		end
		FP:Fire("QUEST_CHAINS_CHANGED")
	end)
end
