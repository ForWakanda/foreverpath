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
local function todo(key) fresh();local r,counts,ctx=D:Todo(key or "scholomance",false);return index(r),counts,ctx,r end
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

        # report 3: "it just needs to be clearer what quests to pick up next and where"
        'dungeon_checklist_leads_with_what_to_pick_up_now_and_where': CLARITY + r'''
log(5341,"Barov Family Fortune");log(8258,"The Darkreaver Menace")
stand(1422,.5,.5)
local by,counts,ctx,list=todo()
local function line(row) return plain(D:Title(row)).." | "..plain(D:Where(row,ctx)) end
-- today's pickups first, nearest first, each with giver, place and distance; a quest that opens others says so
-- (the quest it leads to directly is the one named: Bag of Horrors is 1 quest on, Kirtonos 2, Ras Frostwhisper 3)
assert(line(list[1])=="Pick up now - Doctor Theolen Krastinov, the Butcher  ·  leads to Krastinov's Bag of Horrors +2 | Eva Sarkhoff — Western Plaguelands 70.2, 73.7 · 3.11k yd", line(list[1]))
assert(line(list[2])=="Pick up now - Plagued Hatchlings  ·  leads to Healthy Dragon Scale | Betina Bigglezink — Eastern Plaguelands 81.5, 59.8 · 13.2k yd", line(list[2]))
assert(list[3].id==8969 and plain(D:Where(list[3],ctx))=="Bodley — Burning Steppes 30.0, 30.0 · 28.1k yd", line(list[3]))
-- then what is in the log (a held version included)
assert(list[4].code=="active" and list[5].code=="active")
-- then the first quest of a chain, once, however many dungeon quests wait behind it: a chain he could
-- start, in white, not an instruction (v0.33.0: the reference cannot know whether its giver offers it)
assert(list[6].step and list[6].code=="step" and list[6].id==4726 and #list[6].opens==2 and list[6].steps==2)
assert(list[6].label=="Chain start" and list[6].color=="|cffffffff" and not list[6].now and not list[6].confirmed)
assert(line(list[6])=="Chain start - Broodling Essence  ·  2 quests to Betina Bigglezink +1 | Tinkee Steamboil — Burning Steppes 65.2, 24.0 · 27.4k yd · unconfirmed: ask the giver", line(list[6]))
local n=0;for _,row in ipairs(list) do if row.id==4726 then n=n+1 end end;assert(n==1, "one line per chain start")
-- then what stays shut, in grey
assert(line(by[5341])=="In your log - Barov Family Fortune  ·  leads to The Last Barov | Turn in: Alexi Barov — Tirisfal Glades 83.1, 71.6", line(by[5341]))
assert(line(by[7668])=="In your log - The Darkreaver Menace | Turn in: Sagorne Creststrider — Orgrimmar 38.7, 35.9", line(by[7668]))
assert(by[4771].code=="prereq" and by[4771].label=="Later: 2 quests first" and by[4771].color==FP.GREY and not by[4771].now)
assert(plain(D:Where(by[4771],ctx))=="Next: Broodling Essence · Tinkee Steamboil — Burning Steppes 65.2, 24.0 · then 1 more")
local seenLater
for _,row in ipairs(list) do
 if row.now then assert(not seenLater, "a do-now line after a later one: "..row.quest.name) else seenLater=true end
end
-- the summary says the same in one line
local summary=plain(D:TodoText(counts))
assert(summary:find("Now: 3 to pick up · 2 in your log.  1 chain you could start (unconfirmed).  Later: 8 behind a quest chain.",1,true) and summary:find("behind a quest chain",1,true), summary)
-- the details of a chain start say what it is for
local text=plain(D:Details(list[6],ctx))
assert(text:find("A chain step, not a dungeon quest: the first of 2 quests before Betina Bigglezink, Dawn's Gambit.",1,true), text)
assert(plain(D:Details(by[5382],ctx)):find("The first step toward: Krastinov's Bag of Horrors, Kirtonos the Herald, The Lich, Ras Frostwhisper.",1,true), plain(D:Details(by[5382],ctx)))
-- across the sea it says so instead of a distance, and those lines come after the ones on this continent
stand(1454,.38,.37);by,counts,ctx,list=todo()
assert(plain(D:Where(by[5382],ctx))=="Eva Sarkhoff — Western Plaguelands 70.2, 73.7 · other continent", plain(D:Where(by[5382],ctx)))
-- a chain step already in the log: finish it, with its turn-in
log(4726,"Broodling Essence");by,counts,ctx,list=todo()
assert(by[4726].code=="stepactive" and line(by[4726])=="Finish first - Broodling Essence  ·  2 quests to Betina Bigglezink +1 | In your log · turn in: Tinkee Steamboil — Burning Steppes 65.2, 24.0", line(by[4726]))
assert(plain(D:TodoText(counts)):find("1 chain step to finish",1,true))
drop(4726)
-- a chain is as long as the shortest way to a dungeon quest behind it
QUEST[5531].preQuestSingle={4726};by,counts,ctx,list=todo()
assert(by[4726].steps==1 and plain(D:Title(by[4726]))=="Chain start - Broodling Essence  ·  leads to Betina Bigglezink +1", plain(D:Title(by[4726])))
QUEST[5531].preQuestSingle={4808}
-- two known givers: the nearer one is named, with its place
stand(1422,.5,.5)
NPC[11217]={name="Lucien Sarkhoff",spawns={[139]={{10,10}}}};QUEST[5382].startedBy={{11216,11217}};by,counts,ctx,list=todo()
assert(plain(D:Where(by[5382],ctx))=="Eva Sarkhoff — Western Plaguelands 70.2, 73.7 · 3.11k yd", plain(D:Where(by[5382],ctx)))
stand(1423,.12,.12);by,counts,ctx,list=todo()
assert(plain(D:Where(by[5382],ctx))=="Lucien Sarkhoff — Eastern Plaguelands 10.0, 10.0 · 283 yd", plain(D:Where(by[5382],ctx)))
QUEST[5382].startedBy={{11216}};stand(1454,.38,.37)
-- a step the character is too low for says so
QUEST[4726].requiredLevel=61;by,counts,ctx,list=todo()
assert(plain(D:Where(by[4726],ctx)):find(" · needs level 61",1,true), plain(D:Where(by[4726],ctx)))
QUEST[4726].requiredLevel=nil
-- a step nothing describes gets no line of its own
QUEST[4808].preQuestSingle={4999};by,counts,ctx,list=todo()
assert(not by[4999] and by[4771].code=="prereq" and plain(D:Where(by[4771],ctx)):find("quest #4999, which the quest database does not list",1,true))
QUEST[4808].preQuestSingle={4726}
-- the plain list (itinerary, receipts) is unchanged by the do-now list
local plainRows=select(4,rows());for _,row in ipairs(plainRows) do assert(not row.step and FP.DungeonCatalog.quests[row.id]) end
assert(#FP.db.errors==0)
''',

        'dungeon_checklist_window_shows_the_do_now_list_and_guides_a_chain_start': hub + CLARITY + r'''
log(8258,"The Darkreaver Menace")
stand(1422,.5,.5)
local P=FP.DungeonPanel
fresh();P:Open("scholomance")
assert(#P.questButtons==7, "seven lines a page")
local b1,b3=P.questButtons[1],P.questButtons[6]
assert(plain(b1.title:GetText())=="Pick up now - Doctor Theolen Krastinov, the Butcher  ·  leads to Krastinov's Bag of Horrors +2", plain(b1.title:GetText()))
assert(plain(b1.pickup:GetText())=="Eva Sarkhoff — Western Plaguelands 70.2, 73.7 · 3.11k yd", plain(b1.pickup:GetText()))
assert(plain(P.summary:GetText()):find("Now: 4 to pick up · 1 in your log.  1 chain you could start (unconfirmed).",1,true), plain(P.summary:GetText()))
-- no line tells him to pick up the quest he holds
for _,row in ipairs(P.rows) do assert(not (row.id==7668 and row.code~="active"), row.code) end
-- the receipt for the next data pull: one quest recognised under its other number, one chain start listed
local receipt=FP.db.dungeonSources
assert(receipt.key=="scholomance" and receipt.held==1 and receipt.steps==1 and receipt.finish==0 and receipt.lines==#P.rows and receipt.rows==#P.rows-1)
-- a chain start: its own button text, and the click leads to its giver
assert(b3.row.step and b3.row.id==4726)
b3:GetScript("OnClick")(b3)
assert(P.selectedQuest==4726 and P.guideQuest:GetText()=="Guide pickup" and P.guideQuest:IsEnabled() and P.viewChain:IsEnabled())
assert(plain(P.details:GetText()):find("A chain step, not a dungeon quest",1,true))
assert(not active(), "browsing set a destination")
P.guideQuest:GetScript("OnClick")(P.guideQuest)
assert(active() and active().source.type=="chain-pickup" and active().source.questID==4726 and active().mapID==1428)
-- in the log it guides the quest instead of the giver
FP.Waypoints:Clear();log(4726,"Broodling Essence");P:Refresh()
local held;for _,b in ipairs(P.questButtons) do if b.row and b.row.id==4726 then held=b end end
held:GetScript("OnClick")(held);assert(held.row.code=="stepactive" and P.guideQuest:GetText()=="Guide objective")
P.guideQuest:GetScript("OnClick")(P.guideQuest)
assert(not active() or active().source.type~="chain-pickup")
-- (with a place for its objective the arrow goes there, the same as any quest in the log)
drop(4726);quest(4726,"Broodling Essence",1428,.5,.5);FP.Recorder.RescanLog("clarity")
local ok,message=D:GuideStep(4726)
assert(ok and message:find("Guiding the selected quest",1,true) and active() and active().mapID==1428 and active().source.type~="chain-pickup", tostring(message))
assert(#FP.db.errors==0)
''',

        # report of 2026-11-22, v0.32.0: "start a chain from Mokvar in Orgrimmar ... there is nothing to start"
        'dungeon_chain_longer_than_the_walk_never_names_its_cut_end_as_the_start': CLARITY + r'''
-- a dungeon quest behind 25 quests, like the amulet chain (20+): the walk stopped at 19 and the
-- list called the place it stopped the start of the chain
for i=1,25 do QUEST[60000+i]={name=string.format("Long Step %02d",i),startedBy={{i==1 and 10267 or 16033}},finishedBy={{16033}},preQuestSingle=i>1 and {60000+i-1} or nil} end
QUEST[8992].preQuestSingle={60025}
local by,counts,ctx,list=todo()
local path=D:Path(8992,ctx)
assert(#path.steps==25 and path.steps[1]==60001 and not path.cut and not path.unknown, #path.steps.." steps, first "..tostring(path.steps[1]))
assert(by[60001] and by[60001].step and by[60001].steps==25 and not by[60007], "the chain's first quest is the one listed")
for _,row in ipairs(list) do assert(not (row.step and row.id~=60001 and row.id>60000), "a quest in the middle of the chain was listed as its start: "..row.quest.name) end
assert(plain(D:Title(by[60001]))=="Chain start - Long Step 01  ·  25 quests to The Right Piece of Lord Valthalak's Amulet", plain(D:Title(by[60001])))
assert(by[8992].label=="Later: 25 quests first" and plain(D:Where(by[8992],ctx)):find("Next: Long Step 01",1,true))
-- a chain longer than any limit: no first quest is named anywhere, and the click does not lead to the cut end
local keep=D.PATH_DEPTH;D.PATH_DEPTH=10
by,counts,ctx,list=todo()
path=D:Path(8992,ctx);assert(path.cut and path.unknown and #path.steps<25)
for _,row in ipairs(list) do assert(not (row.step and row.id>60000), "the cut end of a chain was listed as its start: "..row.quest.name) end
assert(by[8992].code=="prereq" and by[8992].label:find("^Later: more than %d+ quests first$"), by[8992].label)
assert(plain(D:Where(by[8992],ctx))=="A very long chain: the list could not follow it back to its first quest. View quest chain.", plain(D:Where(by[8992],ctx)))
FP.Waypoints:Clear();local ok,message=D:GuideQuest(8992)
assert(not ok and not active() and message:find("too long to follow back",1,true), tostring(message))
local plan=DP:Build("scholomance");local chain
for _,row in ipairs(plan.rows) do if row.type=="chain" and row.quest.id==8992 then chain=row end end
assert(chain and chain.first==nil and chain.text=="The Right Piece of Lord Valthalak's Amulet — a very long chain; its first quest is not worked out", chain and chain.text)
D.PATH_DEPTH=keep
-- a chain with a step the reference cannot answer for names no first quest either
QUEST[60010].preQuestSingle={60009,nil};QUEST[60012].preQuestGroup={60011,60011};QUEST[60011].preQuestSingle={60011}
by,counts,ctx,list=todo();path=D:Path(8992,ctx)
assert(path.unknown and not path.cut, "a loop in the reference")
for _,row in ipairs(list) do assert(not (row.step and row.id>60000), "a first quest was named for a chain with an unreadable step") end
assert(#FP.db.errors==0)
''',

        'dungeon_chain_start_is_the_references_word_until_its_giver_answers': CLARITY + r'''
stand(1422,.5,.5)
local function talk(id,name,quests,event)
 M.SetUnit("npc",{guid="Creature-0-1-0-0-"..id.."-00001",name=name});M.gossipAvailable=quests or {}
 M.FireEvent(event or "GOSSIP_SHOW");M.RunTimers(.2)
end
-- browsing remembers nothing
local by,counts,ctx,list=todo()
assert(FP.cdb.givers==nil and FP.cdb.notOffered==nil and FP.cdb.turnins==nil, "reading the list wrote to the character")
local start=by[4726]
assert(start.code=="step" and start.label=="Chain start" and not start.now and not start.confirmed)
assert(plain(D:Where(start,ctx)):find(" · unconfirmed: ask the giver",1,true))
assert(plain(D:Details(start,ctx)):find("Unconfirmed. The quest database names this as the chain's first quest; it does not know whether the giver offers it to you",1,true))
local before=plain(D:TodoText(counts));assert(before:find("Now: 5 to pick up.  1 chain you could start (unconfirmed).",1,true), before)
-- its giver has it on offer: now it is a pickup like any other, and says how it knows
stand(1428,.652,.24);talk(10267,"Tinkee Steamboil",{{questID=4726,title="Broodling Essence",questLevel=52}})
by,counts,ctx,list=todo();start=by[4726]
assert(start.code=="step" and start.confirmed and start.now and start.label=="Pick up now" and start.color==FP.GOLD)
-- (standing with the giver: the place is where the dialog was, and the giver is still named)
assert(plain(D:Where(start,ctx))=="Tinkee Steamboil — Burning Steppes 65.2, 24.0 · 0 yd · offered just now", plain(D:Where(start,ctx)))
stand(1422,.5,.5);by,counts,ctx,list=todo();start=by[4726]
assert(plain(D:Where(start,ctx))=="Tinkee Steamboil — Burning Steppes 65.2, 24.0 · 27.4k yd · offered just now", plain(D:Where(start,ctx)))
local pos;for i,row in ipairs(list) do if row.id==4726 then pos=i end end
assert(pos<=6 and list[6].now and list[7].code~="pickup" and list[7].code~="step", "a confirmed chain start sits with the pickups, by distance")
-- (with a quest in the log: the confirmed start is above it, where an unconfirmed one is below)
log(5341,"Barov Family Fortune");local withLog=select(4,todo());local at={};for i,row in ipairs(withLog) do at[row.id]=i end
assert(at[4726]<at[5341], "a chain start its giver offers was left below the log")
drop(5341);by,counts,ctx,list=todo();start=by[4726]
assert(plain(D:TodoText(counts)):find("Now: 6 to pick up.",1,true) and not plain(D:TodoText(counts)):find("you could start",1,true), plain(D:TodoText(counts)))
assert(plain(D:Details(start,ctx)):find("Offered when you spoke to Tinkee Steamboil just now.",1,true))
-- the same giver, asked again, has nothing: not offered, out of the way, and it says who was asked
M.RunTimers(600);talk(10267,"Tinkee Steamboil",{})
by,counts,ctx,list=todo();start=by[4726]
assert(start.code=="refused" and start.label=="Not offered" and start.color==FP.GREY and not start.now, start.code)
assert(plain(D:Where(start,ctx))=="Not offered when you spoke to Tinkee Steamboil just now. The quest database does not record why; talk to them again to refresh.", plain(D:Where(start,ctx)))
for i,row in ipairs(list) do if row.now then assert(row.id~=4726) end end
local text=plain(D:TodoText(counts));assert(text:find("Now: 5 to pick up.",1,true) and text:find("1 not offered when asked",1,true) and not text:find("you could start",1,true), text)
-- the quests behind it stop sending him back to that giver
assert(plain(D:Where(by[4771],ctx))=="Next: Broodling Essence · not offered when you spoke to Tinkee Steamboil · then 1 more", plain(D:Where(by[4771],ctx)))
-- a dungeon quest of its own that its giver does not offer: no longer a pickup, no stop on the itinerary
talk(11216,"Eva Sarkhoff",{})
by,counts,ctx,list=todo()
assert(by[5382].code=="refused" and plain(D:Where(by[5382],ctx)):find("Not offered when you spoke to Eva Sarkhoff",1,true))
local plan=DP:Build("scholomance");local later
for _,row in ipairs(plan.rows) do
 assert(not (row.type=="pickup" and row.quest.id==5382), "routed to a giver who was asked and had nothing")
 if row.type=="later" and row.quest.id==5382 then later=row end
end
assert(later and later.text=="Not offered: Doctor Theolen Krastinov, the Butcher", later and later.text)
FP.Waypoints:Clear();assert(not D:GuideQuest(5382) and not active())
-- other givers' quests are untouched: asking one giver says nothing about another
assert(by[5529].code=="pickup" and by[5341].code=="pickup" and not by[5529].confirmed)
-- a quest dialog opened directly names one quest and refuses nothing
M.dialogQuestID=5529
talk(11035,"Betina Bigglezink",{},"QUEST_DETAIL")
local givers=FP.cdb.givers
assert(givers[11035]==nil or givers[11035].full==nil, "a single quest dialog was taken for the giver's whole list")
by=todo();assert(by[5531]==nil or by[5531].code~="refused")
-- an answer given before the quest was open to him does not count: she refused Bag of Horrors
-- while the Butcher was still undone; once the Butcher is handed in the old answer is void
assert(D:Asked(5515) and D:Asked(5515).refused, "asked while it was shut: recorded")
M.RunTimers(600);done[5382]=true;M.FireEvent("QUEST_TURNED_IN",5382,0,0)
by,counts,ctx=todo()
assert(D:Asked(5515)==nil and by[5515].code=="pickup", "a refusal from before the prerequisite was handed in still counts: "..by[5515].code)
-- asked again after that, with nothing: now it counts
M.RunTimers(600);talk(11216,"Eva Sarkhoff",{});by=todo();assert(by[5515].code=="refused")
-- nor one given when he was below the quest's level
done[5382]=nil;FP.cdb.givers[11216].level=40;QUEST[5382].requiredLevel=55;FP.cdb.turnins={}
by=todo();assert(by[5382].code~="refused", "a refusal at level 40 was held against a level-55 quest")
-- the player's own word, for a giver who opens no dialog, and its undo
FP.cdb.givers={};by=todo();assert(by[4726].code=="step")
assert(D:MarkNotOffered(4726,true));by,counts,ctx=todo()
assert(by[4726].code=="refused" and by[4726].asked.manual and plain(D:Where(by[4726],ctx)):find("^You marked it not offered just now%."), plain(D:Where(by[4726],ctx)))
assert(plain(D:Where(by[4771],ctx))=="Next: Broodling Essence · not offered when you last checked · then 1 more", plain(D:Where(by[4771],ctx)))
D:MarkNotOffered(4726,false);by=todo();assert(by[4726].code=="step")
-- the giver offering it clears the mark
D:MarkNotOffered(4726,true);talk(10267,"Tinkee Steamboil",{{questID=4726,title="Broodling Essence"}});by=todo()
assert(by[4726].confirmed and FP.cdb.notOffered[4726]==nil)
-- the memory is bounded
for i=1,400 do D:Remember({kind="Creature",id=900000+i,name="N"..i},{},true) end
local n=0;for _ in pairs(FP.cdb.givers) do n=n+1 end;assert(n==300, n.." givers kept")
assert(#FP.db.errors==0)
''',

        'dungeon_checklist_window_marks_a_quest_its_giver_did_not_offer': hub + CLARITY + r'''
log(8258,"The Darkreaver Menace")
stand(1422,.5,.5)
local P=FP.DungeonPanel
fresh();P:Open("scholomance")
local function pick(id)
 for i,row in ipairs(P.rows) do if row.id==id then
  P.questPage=math.ceil(i/7);P:Refresh()
  local b=P.questButtons[(i-1)%7+1];assert(b.row.id==id);b:GetScript("OnClick")(b);return b
 end end
 error("not listed: "..id)
end
-- a quest in the log: nothing to mark
pick(7668);assert(not P.notOffered:IsEnabled() and P.notOffered:GetText()=="Giver didn't offer it")
-- a chain start: the button is there, and one click takes the line out of the way
local b=pick(4726);assert(b.row.code=="step" and P.notOffered:IsEnabled())
P.notOffered:GetScript("OnClick")(P.notOffered)
b=pick(4726);assert(b.row.code=="refused" and plain(b.title:GetText()):find("^Not offered %- Broodling Essence") and plain(b.pickup:GetText()):find("^You marked it not offered"), plain(b.title:GetText()))
assert(P.notOffered:GetText()=="Undo: not offered" and P.notOffered:IsEnabled() and not P.guideQuest:IsEnabled())
assert(plain(P.summary:GetText()):find("1 not offered when asked",1,true) and not plain(P.summary:GetText()):find("you could start",1,true))
assert(FP.db.dungeonSources.refused==1 and FP.db.dungeonSources.steps==0 and FP.db.dungeonSources.confirmed==0)
-- undo
P.notOffered:GetScript("OnClick")(P.notOffered)
b=pick(4726);assert(b.row.code=="step" and P.notOffered:GetText()=="Giver didn't offer it")
-- a dungeon quest can be marked the same way
b=pick(5382);assert(P.notOffered:IsEnabled());P.notOffered:GetScript("OnClick")(P.notOffered)
local found;for _,row in ipairs(P.rows) do if row.id==5382 then found=row end end;assert(found.code=="refused")
D:MarkNotOffered(5382,false)
-- talking to a giver refreshes the open window: what was offered cannot be marked "not offered"
M.SetUnit("npc",{guid="Creature-0-1-0-0-10267-00001",name="Tinkee Steamboil"});M.gossipAvailable={{questID=4726,title="Broodling Essence"}}
M.FireEvent("GOSSIP_SHOW");M.RunTimers(1)
b=pick(4726);assert(b.row.confirmed and plain(b.title:GetText()):find("^Pick up now %- Broodling Essence") and not P.notOffered:IsEnabled())
assert(FP.db.dungeonSources.confirmed==1)
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
