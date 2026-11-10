-- Optional offline integration against the actual packaged provider. Run from
-- a QuestieDB source checkout (its emulator), passing this repo and an unpacked
-- QuestieDB 1.0.13 Forever addon directory. No game/client files are written.
local repo, root = assert(arg[1], "ForeverPath repo path"), assert(arg[2], "unpacked QuestieDB path")
local em = dofile("emulator/metadata.lua")
dofile("emulator/client.lua").install({expansion="Forever",faction="Horde",classFile="SHAMAN",classId=7,raceName="Orc",raceFile="Orc",raceId=2,level=38})
local metadata = em.parse(root .. "/QuestieDB_Forever.toc")
em.install("QuestieDB", metadata)
local db = em.loadAddon(root .. "/QuestieDB_Forever.toc", "QuestieDB", root)
assert(db.readMode == "baked" and db.flavor.expansion == "Forever")
package.path = repo .. "/tests/?.lua;" .. package.path
local M = require("wowmock")
local FP = {}
for line in io.lines(repo .. "/ForeverPath/ForeverPath.toc") do
	if line:match("%.lua$") then assert(loadfile(repo .. "/ForeverPath/" .. line:gsub("\\", "/")))("ForeverPath", FP) end
end
M.FireEvent("ADDON_LOADED", "ForeverPath"); M.FireEvent("PLAYER_LOGIN"); M.RunTimers(12)
assert(FP.API.QuestDatabaseStatus())
local cases = {
	{1322, "The Black Shield", "Acidic Venom Sac: 0/5", "item", 106, 1445},
	{788, "Cutting Teeth", "Mottled Boar slain: 0/10", "monster", 64, 1411},
	{815, "Break a Few Eggs", "Taillasher Egg: 0/3", "item", 19, 1411},
}
for _,case in ipairs(cases) do
	M.quests = {}
	M.mapID = case[6]; M.px, M.py = .45, .45; FP.Pos:Refresh(true)
	local q={questID=case[1],title=case[2],objectives={{text=case[3],type=case[4],finished=false,numRequired=5,numFulfilled=0}}}
	M.AddQuest(q)
	local started=os.clock()
	FP.QuestObjectives:Refresh(true)
	assert(FP.QuestObjectives.matched==1, FP.QuestObjectives:Summary())
	local group=FP.QuestObjectives.groups[1]
	assert(#group.points==case[5], "provider source points changed")
	FP.Pins.provider:RefreshAllData()
	local point=group.points[1];M.px,M.py=point.x,point.y;FP.Pos:Refresh(true)
	FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
	assert(#FP.QuestObjectives:WorldPins(case[6])>0 and #FP.Pins.objectiveMini>0)
	local pin=FP.QuestObjectives:WorldPins(case[6])[1]
	FP.QuestObjectives:Guide(pin);assert(FP.Waypoints:GetActive().source.questID==case[1])
	q.objectives[1].finished=true;FP.QuestObjectives:Refresh()
	assert(#FP.QuestObjectives.groups==0 and not FP.Waypoints:GetActive())
	print("PASS packaged provider",case[1],case[2],case[5].." source points",string.format("%.3fs",os.clock()-started))
end
-- Same quest, deliberately reversed live order: database ordering cannot decide
-- which finished objective to hide.
M.quests={};M.AddQuest({questID=784,title="Vanquish the Betrayers",objectives={
	{text="Lieutenant Benedict slain: 0/1",type="monster",finished=false},
	{text="Kul Tiras Marine slain: 0/8",type="monster",finished=false},
	{text="Kul Tiras Sailor slain: 8/8",type="monster",finished=true}}})
FP.QuestObjectives:Refresh(true)
assert(FP.QuestObjectives.matched==2)
assert(FP.QuestObjectives.groups[1].name=="Lieutenant Benedict" and #FP.QuestObjectives.groups[1].points==1)
assert(FP.QuestObjectives.groups[2].name=="Kul Tiras Marine" and #FP.QuestObjectives.groups[2].points==20)
assert(#FP.db.errors==0)
print("PASS packaged provider: mixed objective order and completion; zero stored mock errors")
print("Provider quest records:",#db.Quest.GetAllIds(),"(not a count of mapped ForeverPath quests)")

-- Quest chain integration: actual prerequisite, reverse-edge, pickup and search
-- fields from the same pinned distribution, exercised through the tools UI.
local C,H=FP.QuestChains,FP.Hub
local before=collectgarbage("count")
local started=os.clock()
H:Open("chains")
assert(C.loading and C.scanned==40)
local batches=0
while C.loading do M.RunTimers(.03);batches=batches+1;assert(batches<200,"chain index did not finish")end
assert(C.indexed and #C.searchRows==5233)
local q=C:Get(1322)
assert(q.name=="The Black Shield" and q.preQuestSingle[1]==1321)
assert(C:Get(1321).preQuestSingle[1]==1251)
assert(C.followups[1322][1323] and C.followups[1323][1276])
local context=C:Context()
local rows=C:Search("The Black Shield",false,context)
assert(#rows>=6,"same-name quest stages collapsed")
local seen={};for _,row in ipairs(C:Links(1322,context))do seen[row.id]=true end
assert(seen[1321] and seen[1251] and seen[1323])
local starts=C:Starters(1322)
assert(starts[1].name=="Do'gol" and #starts[1].points>0 and starts[1].points[1].mapID==1445)
H:OpenQuestChain(1322)
assert(FP.ChainPanel.questID==1322 and FP.ChainPanel.detailText:GetText():find("Do'gol",1,true))
assert(H.pages.chains.body:GetHeight()>432)
print("PASS packaged chain index:",#C.searchRows,"records",batches.." async batches",string.format("%.3fs CPU, %.0f KiB growth",os.clock()-started,collectgarbage("count")-before))
print("PASS Black Shield chain: 1251 -> 1321 -> 1322 -> 1323 -> 1276; distinct stages, Do'gol pickup, UI details")
assert(#FP.db.errors==0,"chain UI stored errors")

-- Actual packaged event records, including labels previously observed in saved
-- quest data. Fixtures replay the client shape; they do not prove live rendering.
local Q=FP.QuestObjectives
local eventCases={
 {870,"The Forgotten Pools","Explore the waters of the Forgotten Pools",1413,.4506,.2253},
 {1273,"Questioning Reethe","Question Reethe with Ogron",1445,.4247,.3807},
 {25,"Stonetalon Standstill","Scout the gazebo on Mystral Lake that overlooks the nearby Alliance outpost.",1440,.4892,.6956},
 {898,"Free From the Hold","Escort Gilthares Firebough back to Ratchet",1413,.6227,.3909},
}
for _,case in ipairs(eventCases)do
 M.quests={};M.complete[case[1]]=false;M.mapID=case[4];M.px=case[5];M.py=case[6];FP.Pos:Refresh(true)
 local q={questID=case[1],title=case[2],objectives={{text=case[3],type="event",finished=false,numRequired=1,numFulfilled=0}}}
 M.AddQuest(q);Q:Refresh(true)
 assert(Q.events==1 and Q.missing==0,case[2].." did not map")
 local point=Q.groups[1].points[1]
 assert(point.mapID==case[4] and math.abs(point.x-case[5])<.000001 and math.abs(point.y-case[6])<.000001)
 local pins=Q:WorldPins(case[4]);assert(#pins>0 and Q:Guide(pins[1]))
 assert(FP.Waypoints:GetActive().desc:find("Event completion area",1,true))
 local clicked=FP.Waypoints:GetActive()
 q.objectives[1].finished=true;Q:Refresh();assert(Q.events==0)
 for _,wp in ipairs(FP.Waypoints.list)do assert(wp~=clicked,"completed event waypoint survived")end
 -- The older planner waypoint may become active again; it is not this event.
 print("PASS packaged event",case[1],case[2],case[4],case[5],case[6])
end
M.quests={};M.complete[5561]=false
M.AddQuest({questID=5561,title="Kodo Roundup",objectives={{text="Kodos Tamed: 0/5",type="monster",finished=false,numRequired=5,numFulfilled=0}}})
Q:Refresh(true);assert(Q.events==1 and Q.hints==1)
local targets={};for _,p in ipairs(Q.groups[1].points)do targets[p.entityID]=true end
assert(targets[4700] and targets[4701] and targets[4702])
assert(Q.groups[2].kind=="Hint" and not Q.groups[2].objIndex)
print("PASS packaged credit+hint: Kodo Roundup, all three target species and separate lure destination")
M.quests={};M.complete[1136]=false
M.AddQuest({questID=1136,title="Frostmaw",objectives={{text="Frostmaw's Mane: 0/1",type="item",finished=false}}})
Q:Refresh(true);assert(Q.hints==1)
local found=false;for _,g in ipairs(Q.groups)do if g.kind=="Hint"then
 assert(g.name=="Use a Fresh Carcass at the Flame of Uzel" and #g.points>0)
 for _,p in ipairs(g.points)do assert(p.entityID==1770)end
 found=true
end end;assert(found)
print("PASS packaged interaction hint: Frostmaw's Flame of Uzel")
M.quests={};M.complete[92401]=false
M.AddQuest({questID=92401,title="A Frightened Request",objectives={{text="Investigate the disappearance of Edward Heartweaver in the Ruins of Lordaeron.",type="event",finished=false}}})
Q:Refresh(true);assert(Q.events==0 and Q.missing==1,"sentinel coordinates became an event location")
M.quests={};M.complete[92474]=false
M.AddQuest({questID=92474,title="Falling With Style",objectives={{text="Use Walk on Air",type="spell",finished=false}}})
Q:Refresh(true);assert(Q.matched==0 and Q.missing==1,"spell with no reference location invented a destination")
print("PASS packaged unknowns: event sentinel and locationless spell remain unmapped")
assert(#FP.db.errors==0,"event integration stored errors")
