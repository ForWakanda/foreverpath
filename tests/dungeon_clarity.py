"""Dungeon quests: one dungeon chosen on the page, a quest held under its other number,
and a list that says what to pick up now and where (v0.32.0). Mock-only.

The report (level 60 shaman, 2026-11-22): he clicked Scholomance under "Which dungeon
next", scrolled down, pressed "Open quest checklist" and got Dire Maul: East; the
Scholomance list then sent him to Orgrimmar to pick up The Darkreaver Menace, which was
already in his log; and the list did not say what to pick up next or where.
Causes: the page kept two dungeon selections; the bundled list knows that quest as 7668
while the game gave him 8258 (the quest database marks the two exclusive to each other);
and the list mixed today's pickups with quests many steps away.
These cases use the shipped catalogue with a quest database shaped like the real one.
"""
from travel import WORLD
from dungeon_next import NEXT

CLARITY = WORLD + r'''
local D,DP,C=FP.Dungeons,FP.DungeonPlan,FP.QuestChains
M.class="SHAMAN";M.level=60;FP.cdb.gear.profile="healer"
NAMES[1422]="Western Plaguelands";NAMES[1423]="Eastern Plaguelands";NAMES[1428]="Burning Steppes"
OFF[1422]={20000,-10000};OFF[1423]={20000,-20000};OFF[1428]={-10000,-10000}
local HORDE,ALLIANCE=8589934770,4294967373
local NPC={
 [13417]={name="Sagorne Creststrider",spawns={[1637]={{38.7,35.9}}}},
 [11035]={name="Betina Bigglezink",spawns={[139]={{81.5,59.8}}}},
 [11216]={name="Eva Sarkhoff",spawns={[28]={{70.2,73.7}}}},
 [11022]={name="Alexi Barov",spawns={[85]={{83.1,71.6}}}},
 [10267]={name="Tinkee Steamboil",spawns={[46]={{65.2,24}}}},
 [16033]={name="Bodley",spawns={[46]={{30,30}}}},
}
local SHAMAN=64
local QUEST={
 [7667]={name="Material Assistance",startedBy={{13417}},finishedBy={{13417}},requiredRaces=HORDE,requiredClasses=SHAMAN,nextQuestInChain=8258},
 [7668]={name="The Darkreaver Menace",startedBy={{13417}},finishedBy={{13417}},requiredRaces=HORDE,requiredClasses=SHAMAN,preQuestSingle={7667},exclusiveTo={8258}},
 [8258]={name="The Darkreaver Menace",startedBy={{13417}},finishedBy={{13417}},requiredRaces=HORDE,requiredClasses=SHAMAN,preQuestSingle={7667},exclusiveTo={7668}},
 [5529]={name="Plagued Hatchlings",startedBy={{11035}},finishedBy={{11035}}},
 [5582]={name="Healthy Dragon Scale",startedBy={{11035}},preQuestSingle={5529}},
 [5382]={name="Doctor Theolen Krastinov, the Butcher",startedBy={{11216}},finishedBy={{11216}}},
 [5515]={name="Krastinov's Bag of Horrors",startedBy={{11216}},preQuestSingle={5382}},
 [5384]={name="Kirtonos the Herald",startedBy={{11216}},preQuestSingle={5515}},
 [5466]={name="The Lich, Ras Frostwhisper",startedBy={{11216}},preQuestSingle={5384}},
 [5341]={name="Barov Family Fortune",startedBy={{11022}},finishedBy={{11022}},requiredRaces=HORDE},
 [5342]={name="The Last Barov",startedBy={{11022}},preQuestSingle={5341},requiredRaces=HORDE},
 [4726]={name="Broodling Essence",startedBy={{10267}},finishedBy={{10267}}},
 [4808]={name="Felnok Steelspring",startedBy={{10267}},finishedBy={{10267}},preQuestSingle={4726}},
 [4771]={name="Dawn's Gambit",startedBy={{11035}},preQuestSingle={4808}},
 [5531]={name="Betina Bigglezink",startedBy={{11035}},preQuestSingle={4808}},
 [8966]={name="The Left Piece of Lord Valthalak's Amulet",startedBy={{16033}},exclusiveTo={8967,8968,8969}},
 [8967]={name="The Left Piece of Lord Valthalak's Amulet",startedBy={{16033}},exclusiveTo={8966,8968,8969}},
 [8968]={name="The Left Piece of Lord Valthalak's Amulet",startedBy={{16033}},exclusiveTo={8966,8967,8969}},
 [8969]={name="The Left Piece of Lord Valthalak's Amulet",startedBy={{16033}},exclusiveTo={8966,8967,8968}},
 [8992]={name="The Right Piece of Lord Valthalak's Amulet",startedBy={{16033}},preQuestSingle={8969}},
}
local support={private={areaIdToUiMapId="return {[1637]=1454,[139]=1423,[28]=1422,[85]=1420,[46]=1428}",dungeons={
 [2057]={"Scholomance",nil,28,{{28,69.7,73.2}}},
}}}
local function reader(t) return {Get=function(id,key) return t[id] and t[id][key] end} end
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function()return true end,
 Support={Get=function()return support end},Quest=reader(QUEST),Npc=reader(NPC),Item=reader({}),Object=reader({})}
LibQuestieDB.Quest.GetAllIds=function()return {} end
local done={[7667]=true,[8962]=true} -- his shaman chain step; the amulet chain's lead-in
C_QuestLog.IsQuestFlaggedCompleted=function(id) return done[id] or false end
local function fresh() DP.memo,DP.gearMemo=nil,nil;C.starters={};C.records={} end
local function index(r) local by={};for _,row in ipairs(r) do by[row.id]=row end;return by end
local function rows(key) fresh();local r,counts,ctx=D:Rows(key or "scholomance",false);return index(r),counts,ctx,r end
local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) end
local function log(id,title,complete) M.AddQuest({questID=id,title=title,objectives={{text="0/1 Thing",type="item",numFulfilled=0,numRequired=1,finished=false}}});M.complete[id]=complete;FP.Recorder.RescanLog("clarity") end
local function drop(id) M.RemoveQuest(id);M.complete[id]=nil;FP.Recorder.RescanLog("clarity") end
local function active() return FP.Waypoints:GetActive() end
stand(1454,.38,.37)
'''


def cases(hub):
    return {
        # report 2: "pick up The Darkreaver Menace from Sagorne Creststrider" while it sat in his log
        'dungeon_quest_in_the_log_under_its_other_number_is_not_a_pickup': CLARITY + r'''
-- the bundled list knows the quest as 7668; the game gave him 8258
assert(FP.DungeonCatalog.quests[7668] and not FP.DungeonCatalog.quests[8258])
local by,counts,ctx=rows()
assert(by[7668].code=="pickup" and by[7668].as==nil, "with neither version held it is a pickup")
local pickups=counts.by.pickup
log(8258,"The Darkreaver Menace")
by,counts,ctx=rows()
local r=by[7668]
assert(r.code=="active" and r.label=="In your log" and r.as==8258, r.code.." / "..r.label.." / "..tostring(r.as))
assert(D:Where(r,ctx)=="Turn in: Sagorne Creststrider — Orgrimmar 38.7, 35.9", D:Where(r,ctx))
local text=plain(D:Details(r,ctx))
assert(text:find("In your log as #8258: the quest database lists this quest under two numbers. Nothing to pick up.",1,true), text)
assert(text:find("Given by: Sagorne Creststrider",1,true) and not text:find("How to get it",1,true), "a quest in the log is not something to go and get")
assert(counts.active==1 and counts.by.pickup==pickups-1, "it still counts as a pickup")
assert(D:LogID(7668)==8258 and D:LogID(5529)==nil)
-- the itinerary: in the log, never a stop at the giver
local plan=DP:Build("scholomance");local held
for _,row in ipairs(plan.rows) do
 assert(not ((row.type=="pickup" or row.type=="pickup-unplaced") and row.quest.id==7668), "routed to the giver of a quest already in the log")
 assert(not (row.text or ""):find("pick up: The Darkreaver Menace",1,true), row.text)
 if row.quest and row.quest.id==7668 then held=row end
end
assert(held and held.type=="active" and held.text=="In your log: The Darkreaver Menace", held and held.text)
-- the page opens on the dungeon he holds a quest for
assert(DP:Default()=="scholomance", DP:Default())
-- the click never leads to the giver
FP.Waypoints:Clear();D:GuideQuest(7668)
assert(not active() or active().source.type~="chain-pickup", "guided to the giver of a quest already in the log")
-- ready to turn in, then turned in
M.complete[8258]=true;by,counts,ctx=rows()
assert(by[7668].code=="ready" and by[7668].label=="Ready to turn in" and by[7668].as==8258)
plan=DP:Build("scholomance");local turnin
for _,row in ipairs(plan.rows) do if row.type=="turnin" and row.quest.id==7668 then turnin=row end end
assert(turnin and turnin.text=="Turn in: The Darkreaver Menace")
drop(8258);done[8258]=true;by,counts,ctx=rows()
assert(by[7668].code=="done" and by[7668].label=="Completed" and by[7668].as==8258)
assert(plain(D:Details(by[7668],ctx)):find("Completed as #8258",1,true))
done[8258]=nil
-- a version is exclusive AND has the same name: another quest that merely excludes it is a branch
QUEST[8258].name="Another Road";log(8258,"Another Road");by,counts,ctx=rows()
assert(by[7668].code=="closed" and by[7668].as==nil and D:Where(by[7668],ctx)=="Because the other branch, Another Road, is in your log", by[7668].code.." "..D:Where(by[7668],ctx))
drop(8258);QUEST[8258].name="The Darkreaver Menace"
-- same name without the exclusive mark (a chain of same-named steps) is not a version either
QUEST[7668].exclusiveTo=nil;log(8258,"The Darkreaver Menace");by,counts,ctx=rows()
assert(by[7668].code=="pickup" and #D:Variants(7668)==0)
assert(#FP.db.errors==0)
''',

        'dungeon_quest_versions_per_dungeon_close_the_others_and_satisfy_a_chain_step': CLARITY + r'''
-- one quest, one version per dungeon: holding another dungeon's version closes this one
local by,counts,ctx=rows()
assert(by[8969].code=="pickup")
log(8967,"The Left Piece of Lord Valthalak's Amulet");by,counts,ctx=rows()
local r=by[8969]
assert(r.code=="closed" and r.label=="No longer offered" and r.as==nil, r.code)
assert(D:Where(r,ctx)=="Because you have the Dire Maul: North version of this quest", D:Where(r,ctx))
assert(plain(D:Details(r,ctx)):find("No longer offered: you have the Dire Maul: North version of this quest.",1,true))
assert(D:LogID(8969)==nil, "another dungeon's version is not this dungeon's quest in the log")
local plan=DP:Build("scholomance");for _,row in ipairs(plan.rows) do assert(not (row.quest and row.quest.id==8969), "a closed version is on the itinerary") end
-- in its own dungeon it is simply in the log
local own=rows("dire-maul-north");assert(own[8967].code=="active" and own[8967].as==nil)
-- a chain step held under its other number: "finish it", not "pick it up"
by,counts,ctx=rows()
assert(by[8992].code=="prereq" and D:Where(by[8992],ctx)=="Next: finish The Left Piece of Lord Valthalak's Amulet (in your log)", D:Where(by[8992],ctx))
-- ...and finished under the other number it opens the next quest
drop(8967);done[8967]=true;by,counts,ctx=rows()
assert(by[8969].code=="closed" and D:Where(by[8969],ctx)=="Because you finished the Dire Maul: North version of this quest", D:Where(by[8969],ctx))
assert(by[8992].code=="pickup", "the step was finished under its other number: "..by[8992].code)
assert(#FP.db.errors==0)
''',

        # report 1: clicked Scholomance in the ranking, "Open quest checklist" showed another dungeon
        'which_dungeon_next_click_chooses_the_dungeon_for_the_whole_page': NEXT + hub + r'''
page("dungeons")
local nextList,it=H.controls.dungeonNext,H.controls.hubDungeons
-- the page opens with both lists on the same dungeon
assert(it.selected~=nil and nextList.selected==it.selected)
-- pick one in the ranking that is not the one the itinerary opened on
local n;for i,b in ipairs(nextList.rows) do if b.item and b.item.key~=it.selected then n=i;break end end
local key=nextList.rows[n].item.key
selectRow("dungeonNext",n)
-- the itinerary below is that dungeon's, on the page of the list that shows it, with no further click
assert(it.selected==key and H:Selected(it) and H:Selected(it).key==key, "the itinerary kept the other dungeon")
local shown;for _,b in ipairs(it.rows) do if b.item and b.item.key==key then shown=true end end
assert(shown and H.controls.dungeonSummary:GetText():find(FP.DungeonCatalog.dungeons[key].name,1,true))
-- and the checklist button at the bottom opens that dungeon, not the one the page opened on
click("openDungeonChecklist")
assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==key, "opened "..tostring(FP.DungeonPanel.settings.selected).." instead of "..key)
assert(FP.DungeonPanel.heading:GetText():find(FP.DungeonCatalog.dungeons[key].name,1,true))
-- the button under the ranking does the same
FP.DungeonPanel.frame:Hide();page("dungeons")
local other;for i,b in ipairs(nextList.rows) do if b.item and b.item.key~=key then other=i;break end end
local otherKey=nextList.rows[other].item.key
selectRow("dungeonNext",other);assert(H.controls.dungeonNextOpen:GetText()=="Open its quest checklist")
click("dungeonNextOpen");assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==otherKey and not H.frame:IsShown())
-- choosing in the itinerary list moves the ranking's mark too: the two never name different dungeons
FP.DungeonPanel.frame:Hide();page("dungeons")
for i,b in ipairs(it.rows) do if b.item and b.item.key~=it.selected then selectRow("hubDungeons",i);break end end
assert(nextList.selected==it.selected)
local marked=H:Selected(nextList)
assert(marked==nil or marked.key==it.selected)
-- a dungeon the ranking does not list: nothing is marked there, and its button is off
if not marked then assert(not H.controls.dungeonNextOpen:IsEnabled() and H.controls.dungeonNextDetails:GetText():find("Select a dungeon",1,true)) end
click("openDungeonChecklist");assert(FP.DungeonPanel.settings.selected==it.selected)
assert(#FP.db.errors==0)
''',
    }
