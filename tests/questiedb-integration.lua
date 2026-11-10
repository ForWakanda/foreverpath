-- Optional offline integration against the actual packaged provider. Run from
-- a QuestieDB source checkout (its emulator), passing this repo and an unpacked
-- QuestieDB 1.0.13 Forever addon directory. No game/client files are written.
local repo, root = assert(arg[1], "Hearth & Hustle repo path"), assert(arg[2], "unpacked QuestieDB path")
local em = dofile("emulator/metadata.lua")
dofile("emulator/client.lua").install({expansion="Forever",faction="Horde",classFile="SHAMAN",classId=7,raceName="Orc",raceFile="Orc",raceId=2,level=38})
local metadata = em.parse(root .. "/QuestieDB_Forever.toc")
em.install("QuestieDB", metadata)
local db = em.loadAddon(root .. "/QuestieDB_Forever.toc", "QuestieDB", root)
assert(db.readMode == "baked" and db.flavor.expansion == "Forever")
package.path = repo .. "/tests/?.lua;" .. package.path
local M = require("wowmock")
local FP = {}
for line in io.lines(repo .. "/HearthAndHustle/HearthAndHustle.toc") do
	if line:match("%.lua$") then assert(loadfile(repo .. "/HearthAndHustle/" .. line:gsub("\\", "/")))("HearthAndHustle", FP) end
end
M.FireEvent("ADDON_LOADED", "HearthAndHustle"); M.FireEvent("PLAYER_LOGIN"); M.RunTimers(12)
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
print("Provider quest records:",#db.Quest.GetAllIds(),"(not a count of mapped Hearth & Hustle quests)")

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
Q:Refresh(true);assert(Q.events==1 and Q.missing==0,"authored dungeon event entrance missing")
assert(#Q.groups[1].points==1 and Q.groups[1].points[1].entrance)
local eventPoint=Q.groups[1].points[1]
assert(eventPoint.mapID==1458 and math.abs(eventPoint.x-.7241)<.000001 and math.abs(eventPoint.y-.1137)<.000001)
print("PASS packaged dungeon event: A Frightened Request -> Ruins of Lordaeron entrance",eventPoint.mapID,eventPoint.x,eventPoint.y)
M.quests={};M.complete[92474]=false
M.AddQuest({questID=92474,title="Falling With Style",objectives={{text="Use Walk on Air",type="spell",finished=false}}})
Q:Refresh(true);assert(Q.matched==0 and Q.missing==1,"spell with no reference location invented a destination")
print("PASS packaged unknown: locationless spell remains unmapped")
assert(#FP.db.errors==0,"event integration stored errors")

-- Entrance crosswalk, real sentinel aliases and known quest contacts.
local D=FP.Dungeons
local count=0
for _,dungeon in ipairs(D:List())do
 local points=D:Entrances(dungeon.key)
 if #points>0 then count=count+1 end
 for _,p in ipairs(points)do assert(p.entrance and p.x>=0 and p.y>=0 and p.x<=1 and p.y<=1)end
end
assert(count==30,"dungeon coverage changed: "..count)
local rfc=D:Entrances("ragefire-chasm")[1];assert(rfc.mapID==1454 and rfc.x==.526 and rfc.y==.49)
local strat=D:Entrances("stratholme-service-gate")[1];assert(strat.mapID==1423 and math.abs(strat.x-.4145)<.000001 and math.abs(strat.y-.1774)<.000001)
local wc=D:Entrances("wailing-caverns")[1];assert(wc.mapID==1413 and wc.x==.46 and wc.y==.365)
for _,qid in ipairs({7461,5382})do
 local refs=FP.API.GetQuestReference(qid);local points=0
 for _,ref in ipairs(refs or {})do for _,p in ipairs(ref.points)do
  assert(p.entrance and p.mapID==(qid==7461 and 1444 or 1422),"instance floor escaped as outdoor coordinate")
  points=points+1
 end end
 assert(points>0,"actual dungeon alias objective missing")
 print("PASS packaged dungeon objective",qid,points,"entrance points")
end
local pickup=FP.API.GetQuestChainStarters(7461)
assert(#pickup>0 and pickup[1].points[1].entrance,"Shen'dralar Ancient pickup entrance missing")
local itemStart=FP.API.GetQuestChainStarters(6981)
assert(#itemStart==1 and itemStart[1].kind=="Item" and #itemStart[1].points==0,"item start invented pickup coordinates")
local enders=FP.API.GetQuestEnders(1486)
assert(#enders>0 and #enders[1].points>0,"Deviate Hides turn-in missing")
M.instance=nil;M.quests={};M.mapID=1413;M.px=.4;M.py=.4;FP.Pos:Refresh(true)
FP.Waypoints:Clear();FP.DungeonPanel:Open("wailing-caverns")
FP.DungeonPanel.entranceButton:GetScript("OnClick")()
assert(FP.Waypoints:GetActive().source.entrance)
M.instance={type="party"};M.FireEvent("ZONE_CHANGED_NEW_AREA");M.RunTimers(.5)
assert(not FP.Waypoints:GetActive() and not FP.DungeonPanel.entranceButton:IsEnabled())
assert(#FP.db.errors==0,"dungeon integration stored errors")
print("PASS packaged dungeon checklist: 30/35 entrances, converted Stratholme, pickup/turn-in contacts, entry cleanup; zero stored mock errors")

-- Gear source lookup uses the installed provider's item->reward quest relation.
local sources=FP.API.GetGearQuestSources(6504) -- Wingblade
local fang
for _,q in ipairs(sources) do if q.id==914 then fang=q end end
assert(fang and fang.name=="Leaders of the Fang", "Wingblade reward source missing")
local oldChar=FP.API.GetCharInfo
FP.API.GetCharInfo=function() return {name="Gear fixture",class="HUNTER",level=30} end
H:Open("gear")
FP.GearPanel.filter={slot="MAIN",source="Quest",query="6504",level=30,unknown=true}
H:Refresh()
assert(#H.controls.gearItems.items==1 and H.controls.gearItems.items[1].key==6504)
assert(#FP.GearPanel.questSources>0 and H.controls.gearQuestSource:IsEnabled())
assert(FP.GearPanel.details:GetText():find("Leaders of the Fang",1,true))
FP.API.GetCharInfo=oldChar
assert(#FP.db.errors==0)
print("PASS packaged gear: Wingblade -> Leaders of the Fang, filtered gear UI, source details; zero stored mock errors")
