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
