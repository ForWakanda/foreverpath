"""Dungeon quests say where they start (v0.29.0). Mock-only.

The report: at level 54 the Sunken Temple checklist showed "Missing: check pickup" and
"Contact awaiting verification" for The Essence of Eranikus, which starts from an item
the last boss drops. The installed quest database knew; the checklist never asked it.
These cases use the shipped catalogue with a quest database shaped like the real one.
"""
from travel import WORLD

SOURCES = WORLD + r'''
local D,DP,C=FP.Dungeons,FP.DungeonPlan,FP.QuestChains
M.class="SHAMAN";M.level=54;FP.cdb.gear.profile="healer"
local HORDE,ALLIANCE=8589934770,4294967373
local NPC={
 [8579]={name="Yeh'kinya",spawns={[440]={{67,22.4}}}},
 [8115]={name="Witch Doctor Uzer'i",spawns={[357]={{74.4,43.4}}}},
 [7771]={name="Marvon Rivetseeker",spawns={[440]={{52.7,45.9}}}},
 [5598]={name="Atal'ai Exile",spawns={[47]={{33.8,75.2}}}},
 [9999]={name="Angelas Moonbreeze",spawns={[357]={{31.8,45.6}}}},
 [5709]={name="Shade of Eranikus",spawns={[1477]={{-1,-1}}},rank=1,minLevel=55,maxLevel=55},
 [15362]={name="Malfurion Stormrage",spawns={[1477]={{-1,-1}}},rank=3,maxLevel=1},
 [4802]={name="Blackfathom Tide Priestess",spawns={[357]={{20,30}}},maxLevel=25},
}
local OBJECT={[148512]={name="Essence Font",spawns={[1477]={{-1,-1}}}}}
local ITEM={
 [10454]={name="Essence of Eranikus",npcDrops={5709}},
 [16790]={name="Damp Note",npcDrops={4802}},
 [20000]={name="Unplaced Scroll"},
}
local QUEST={
 [3373]={name="The Essence of Eranikus",startedBy={nil,nil,{10454}},finishedBy={nil,{148512}},requiredLevel=48,nextQuestInChain=3374,
  objectivesText={"Place the Essence of Eranikus in the Essence Font located in this lair in the Sunken Temple."}},
 [3374]={name="The Essence of Eranikus",preQuestSingle={3373}},
 [3520]={name="Screecher Spirits",startedBy={{8579}}},
 [3527]={name="The Prophecy of Mosh'aru",startedBy={{8579}},preQuestSingle={3520}},
 [4787]={name="The Ancient Egg",startedBy={{8579}},preQuestSingle={3527}},
 [3528]={name="The God Hakkar",startedBy={{8579}},finishedBy={{8579}},preQuestSingle={4787},requiredLevel=40},
 [3380]={name="The Sunken Temple",startedBy={{8115}},finishedBy={{7771}},requiredRaces=HORDE,nextQuestInChain=3444},
 [3445]={name="The Sunken Temple",startedBy={{9999}},finishedBy={{7771}},requiredRaces=ALLIANCE,nextQuestInChain=3444},
 [3444]={name="The Stone Circle",startedBy={{7771}},preQuestSingle={3380,3445}},
 [3446]={name="Into the Depths",startedBy={{7771}},preQuestSingle={3444}},
 [1446]={name="Jammal'an the Prophet",startedBy={{5598}},finishedBy={{5598}}},
 [8733]={name="Eranikus, Tyrant of the Dream",startedBy={{15362}},requiredLevel=60},
}
local support={private={areaIdToUiMapId="return {[440]=1446,[357]=1444,[47]=1425,[8]=1435}",dungeons={
 [1477]={"The Temple of Atal'Hakkar",nil,8,{{8,69.9,53.5}}},
}}}
local function reader(t) return {Get=function(id,key) return t[id] and t[id][key] end} end
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function()return true end,
 Support={Get=function()return support end},Quest=reader(QUEST),Npc=reader(NPC),Item=reader(ITEM),Object=reader(OBJECT)}
LibQuestieDB.Quest.GetAllIds=function()return {} end
local done={}
C_QuestLog.IsQuestFlaggedCompleted=function(id) return done[id] or false end
local function fresh() DP.memo,DP.gearMemo=nil,nil;C.starters={};C.records={} end
local function rows(key) fresh();local r,counts,ctx=D:Rows(key or "sunken-temple",false);local by={};for _,row in ipairs(r) do by[row.id]=row end;return by,counts,ctx,r end
local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) end
local function log(id,title,complete) M.AddQuest({questID=id,title=title,objectives={{text="0/1 Thing",type="item",numFulfilled=0,numRequired=1,finished=false}}});M.complete[id]=complete;FP.Recorder.RescanLog("sources") end
local function active() return FP.Waypoints:GetActive() end
stand(1446,.5,.5)
'''


def cases(hub):
    return {
        # the report itself
        'dungeon_quest_started_by_a_boss_drop_says_so_instead_of_check_pickup': SOURCES + r'''
local by,counts,ctx=rows()
local r=by[3373]
assert(r.code=="inside" and r.label=="Drops inside", r.code.." / "..r.label)
assert(D:Where(r,ctx)=="Essence of Eranikus, from Shade of Eranikus. Nothing to pick up first.", D:Where(r,ctx))
local text=plain(D:Details(r,ctx))
assert(text:find("How to get it: Item: Essence of Eranikus — drops from Shade of Eranikus (level 55 elite), inside this dungeon. It drops during the run: nothing to pick up before you go.",1,true), text)
assert(text:find("What it asks: Place the Essence of Eranikus in the Essence Font",1,true), text)
assert(text:find("Turn in: Essence Font — inside this dungeon",1,true) and text:find("Leads to: The Essence of Eranikus (#3374)",1,true), text)
assert(text:find("From the installed quest database",1,true))
-- nothing on the page sends you to a search engine
for _,row in pairs(by) do
 local all=row.label.."\n"..D:Where(row,ctx).."\n"..plain(D:Details(row,ctx))
 assert(not all:find("check pickup",1,true) and not all:lower():find("awaiting verification",1,true) and not all:find("Check prerequisite",1,true), all)
end
-- the itinerary: under Inside, never a pickup to fetch before the run
local plan=DP:Build("sunken-temple")
local drop,inside,before
for i,row in ipairs(plan.rows) do
 if row.type=="header" and row.text=="— Inside —" then inside=i elseif row.type=="header" and row.text=="— Before you enter —" then before=i end
 if row.quest and row.quest.id==3373 then drop=row;assert(inside and i>inside, "listed before the Inside header") end
end
assert(drop and drop.type=="drop" and drop.text=="Drops inside: The Essence of Eranikus — from Shade of Eranikus", drop and drop.text)
assert(#drop.text<=82, "the list cuts a row at 82 characters")
for _,row in ipairs(plan.rows) do assert(not (row.text or ""):find("giver not recorded",1,true), row.text) end
-- the click leads to the entrance, since that is where it starts
assert(DP:CanGuide(drop) and D:GuideQuest(3373))
assert(active().source.type=="chain-pickup" and active().source.entrance and active().mapID==1435)
-- a giver inside is "pick up inside"; below its level it says the level first
M.level=60;by,counts,ctx=rows()
-- (its own chain is not in this database: the step is named by number, not hidden)
assert(by[8733].code=="prereq" and D:Where(by[8733],ctx)=="Next: quest #8555, which the quest database does not list", D:Where(by[8733],ctx))
done[8555]=true;by,counts,ctx=rows()
assert(by[8733].code=="inside" and by[8733].label=="Pick up inside" and D:Where(by[8733],ctx)=="Malfurion Stormrage. Nothing to pick up first.", D:Where(by[8733],ctx))
done[8555]=nil;M.level=54;by,counts,ctx=rows()
assert(by[8733].code=="level" and by[8733].label=="Needs level 60" and D:Where(by[8733],ctx)=="Malfurion Stormrage — inside this dungeon")
-- many creatures drop it, all inside: still "inside", the list shortened; one of them outdoors and it no longer is
local many={};for i=1,14 do NPC[70000+i]={name=string.format("Temple Guard %02d",i),spawns={[1477]={{-1,-1}}}};many[i]=70000+i end
ITEM[10454].npcDrops=many;by,counts,ctx=rows()
assert(by[3373].code=="inside" and D:Where(by[3373],ctx)=="Essence of Eranikus, from Temple Guard 01, Temple Guard 02 and 12 more. Nothing to pick up first.", D:Where(by[3373],ctx))
NPC[70014].spawns={[440]={{10,10}}};by,counts,ctx=rows()
assert(by[3373].code=="pickup" and by[3373].label=="Starts from an item", "a drop outside the dungeon, past the listed ones, was missed")
local lots={};for i=1,70 do lots[i]=70001 end;ITEM[10454].npcDrops=lots;by,counts,ctx=rows()
assert(by[3373].code=="pickup", "too many sources to check must not read as only inside")
ITEM[10454].npcDrops={5709}
-- seen from another dungeon's list the dungeon is named
assert(D:OriginText(3373,"zul-farrak"):find("inside The Temple of Atal'Hakkar",1,true), D:OriginText(3373,"zul-farrak"))
assert(#FP.db.errors==0)
''',

        'dungeon_quest_behind_a_chain_names_the_next_step_and_where': SOURCES + r'''
done[3520]=true
local by,counts,ctx=rows()
-- the catalogue lists no prerequisite for this one: it used to be shown as a pickup
assert(#FP.DungeonCatalog.quests[3528].prerequisites==0)
local r=by[3528]
assert(r.code=="prereq" and r.label=="Chain: 2 quests first", r.code.." / "..r.label)
assert(D:Where(r,ctx)=="Next: The Prophecy of Mosh'aru · Yeh'kinya — Tanaris 67.0, 22.4 · then 1 more", D:Where(r,ctx))
local path=D:Path(3528,ctx);assert(#path.steps==2 and path.steps[1]==3527 and path.steps[2]==4787 and not path.dead and not path.unknown)
local text=plain(D:Details(r,ctx))
assert(text:find("Before it (2 quests, in order):",1,true) and text:find("1. The Prophecy of Mosh'aru (#3527) — next: Yeh'kinya — Tanaris 67.0, 22.4",1,true)
 and text:find("2. The Ancient Egg (#4787) — after that: Yeh'kinya — Tanaris 67.0, 22.4",1,true), text)
-- the itinerary keeps it out of the pickups and names the first step
local plan=DP:Build("sunken-temple");local chain
for _,row in ipairs(plan.rows) do
 if row.quest and row.quest.id==3528 then chain=row end
 assert(not (row.type=="pickup" and row.quest.id==3528), "a quest behind a chain was routed as a pickup")
end
assert(chain.type=="chain" and chain.first==3527 and chain.text=="The God Hakkar — first: The Prophecy of Mosh'aru + 1 more", chain.text)
assert(plan.chain>=1 and DP:Summary(plan):find("behind a quest chain",1,true))
-- the click leads to the step that opens the chain, not to a giver who will refuse
assert(not active() and DP:CanGuide(chain) and D:GuideQuest(3528))
assert(active().source.type=="chain-pickup" and active().source.questID==3527 and active().mapID==1446, "guided to "..tostring(active().source.questID))
-- with the step in the log it says so; finished, the count drops; all done, it is a pickup
FP.Waypoints:Clear();log(3527,"The Prophecy of Mosh'aru");by,counts,ctx=rows()
assert(D:Where(by[3528],ctx)=="Next: finish The Prophecy of Mosh'aru (in your log) · then 1 more", D:Where(by[3528],ctx))
M.complete[3527]=true;by,counts,ctx=rows();assert(D:Where(by[3528],ctx):find("(ready to turn in)",1,true))
M.quests={};M.complete={};FP.Recorder.RescanLog("sources");done[3527]=true;by,counts,ctx=rows()
assert(by[3528].label=="Chain: 1 quest first" and D:Where(by[3528],ctx)=="Next: The Ancient Egg · Yeh'kinya — Tanaris 67.0, 22.4", D:Where(by[3528],ctx))
done[4787]=true;by,counts,ctx=rows()
assert(by[3528].code=="pickup" and by[3528].label=="Pick up" and D:Where(by[3528],ctx)=="Yeh'kinya — Tanaris 67.0, 22.4")
assert(plain(D:Details(by[3528],ctx)):find("Its chain is done: 1 earlier step completed.",1,true))
-- "any one of" picks the branch this character can take
assert(D:ReferenceFaction(HORDE)=="Horde" and D:ReferenceFaction(ALLIANCE)=="Alliance" and D:ReferenceFaction(0)==nil and D:ReferenceFaction(HORDE+77)==nil)
by,counts,ctx=rows();path=D:Path(3446,ctx)
assert(#path.steps==2 and path.steps[1]==3380 and path.steps[2]==3444, table.concat(path.steps,","))
assert(D:Where(by[3446],ctx):find("Next: The Sunken Temple · Witch Doctor Uzer'i — Feralas 74.4, 43.4",1,true), D:Where(by[3446],ctx))
local alliance={char={faction="Alliance",class="SHAMAN",level=54},offers={}}
function alliance:State(id) return {onQuest=false,completed=false,ready=false} end
path=D:Path(3446,alliance);assert(path.steps[1]==3445, "the Alliance branch for an Alliance character")
-- either branch finished satisfies the step
done[3445]=true;by,counts,ctx=rows();assert(by[3444].code=="pickup" and #D:Path(3446,ctx).steps==1);done[3445]=nil
-- a loop in the reference ends as "unknown", never as a pickup and never as a hang
QUEST[3520].preQuestSingle={3528};done[3520]=nil;done[3527]=nil;done[4787]=nil;by,counts,ctx=rows()
assert(D:Path(3528,ctx).unknown and by[3528].code~="pickup")
assert(#plain(D:Details(by[3528],ctx))<4000)
assert(#FP.db.errors==0)
''',

        'dungeon_quest_no_longer_offered_and_item_starts_outside': SOURCES + r'''
-- the lead-in is not offered once the next step is done or in the log
local by,counts,ctx=rows()
assert(by[3380].code=="pickup" and D:Where(by[3380],ctx)=="Witch Doctor Uzer'i — Feralas 74.4, 43.4")
done[3444]=true;by,counts,ctx=rows()
assert(by[3380].code=="closed" and by[3380].label=="No longer offered" and D:Where(by[3380],ctx)=="Because the next step, The Stone Circle, is already done", D:Where(by[3380],ctx))
local plan=DP:Build("sunken-temple");for _,row in ipairs(plan.rows) do assert(not (row.quest and row.quest.id==3380), "a closed quest is still on the itinerary") end
assert(not D:GuideQuest(3380) and not active())
done[3444]=nil
-- nor a quest whose other branch is finished
QUEST[1446].exclusiveTo={3520};done[3520]=true;by,counts,ctx=rows()
assert(by[1446].code=="closed" and D:Where(by[1446],ctx)=="Because you finished the other branch, Screecher Spirits", D:Where(by[1446],ctx))
QUEST[1446].exclusiveTo=nil;done[3520]=nil
-- an item that drops outdoors is a stop on the way, at the place it drops
QUEST[1446].startedBy={nil,nil,{16790}};by,counts,ctx=rows()
assert(by[1446].code=="pickup" and by[1446].label=="Starts from an item")
assert(D:Where(by[1446],ctx)=="Item: Damp Note — drops from Blackfathom Tide Priestess, Feralas 20.0, 30.0", D:Where(by[1446],ctx))
plan=DP:Build("sunken-temple");local stop
for _,row in ipairs(plan.rows) do if row.type=="pickup" and row.quest.id==1446 then stop=row end end
assert(stop and stop.item and stop.text:find("Feralas — get the starting item: Jammal'an the Prophet (Damp Note, from Blackfathom Tide Priestess)",1,true), stop and stop.text)
assert(D:GuideQuest(1446) and active().source.questID==1446 and active().mapID==1444 and not active().source.entrance)
-- an item the reference cannot place says exactly that
FP.Waypoints:Clear();QUEST[1446].startedBy={nil,nil,{20000}};by,counts,ctx=rows()
assert(D:Where(by[1446],ctx)=="Item: Unplaced Scroll — what drops it is not in the reference")
plan=DP:Build("sunken-temple");local unplaced
for _,row in ipairs(plan.rows) do if row.type=="pickup-unplaced" and row.quest.id==1446 then unplaced=row end end
assert(unplaced and unplaced.text=="Starts from an item (where it drops is not in the reference): Jammal'an the Prophet — Unplaced Scroll", unplaced and unplaced.text)
-- the chain browser names the drop too
local chainText=table.concat(C:Details(3373,C:Context()),"\n")
assert(chainText:find("Pickup: starts from an item. Item: Essence of Eranikus — drops from Shade of Eranikus (level 55 elite), inside The Temple of Atal'Hakkar",1,true), chainText)
-- the reference's faction limits a quest the catalogue leaves open
FP.DungeonCatalog.quests[3380].faction=nil
local alliance={char={faction="Alliance",class="SHAMAN",level=54},offers={}}
function alliance:State(id) return {onQuest=false,completed=false,ready=false} end
assert(D:Evaluate(3380,alliance)=="restricted" and select(2,D:Evaluate(3380,alliance))=="Horde only")
assert(#FP.db.errors==0)
''',

        'dungeon_quest_without_the_database_falls_back_to_the_bundled_list': SOURCES + r'''
LibQuestieDB=nil
local by,counts,ctx=rows()
-- the catalogue's giver and zone, plainly
assert(by[1446].code=="pickup" and by[1446].label=="Pick up" and D:Where(by[1446],ctx)=="Atal'ai Exile — The Hinterlands", D:Where(by[1446],ctx))
-- no giver recorded: say that, not a placeholder
local r=by[3373];assert(r.code=="pickup" and r.label=="Pickup not recorded", r.label)
assert(D:Where(r,ctx)=="Where it starts is not recorded (no quest database entry)", D:Where(r,ctx))
local text=plain(D:Details(r,ctx))
assert(text:find("QuestieDB (Forever) is not enabled",1,true) and not text:lower():find("awaiting verification",1,true), text)
-- the catalogue's own chain still gates, with its step named
assert(by[3444].code=="prereq" and D:Where(by[3444],ctx):find("Next: The Sunken Temple · Witch Doctor Uzer'i — Feralas",1,true), D:Where(by[3444],ctx))
assert(D:Pickup(FP.DungeonCatalog.quests[3373])=="Giver not recorded")
assert(#FP.db.errors==0)
''',

        'dungeon_checklist_window_lists_pickups_first_with_where': hub + SOURCES + r'''
done[3520]=true
local P=FP.DungeonPanel
fresh();P:Open("sunken-temple")
-- what to pick up now leads (v0.32.0: the do-now list); every visible row says where on its second line
local first=P.questButtons[1]
assert(first.row.code=="pickup" and plain(first.title:GetText()):find("^Pick up now %- "), plain(first.title:GetText()))
local later;for _,row in ipairs(P.rows) do if row.now then assert(not later, "a do-now line after a later one") else later=true end end
local summary=P.summary:GetText()
assert(summary:find("to pick up",1,true) and summary:find("behind a quest chain",1,true) and summary:find("1 starts inside",1,true) and not summary:find("to check",1,true), summary)
local function show(id)
 for i,row in ipairs(P.rows) do if row.id==id then
  P.questPage=math.ceil(i/7);P:Refresh()
  local b=P.questButtons[(i-1)%7+1];b:GetScript("OnClick")(b);return b
 end end
 error("quest "..id.." not listed")
end
local b=show(3373)
assert(plain(b.title:GetText())=="Drops inside - The Essence of Eranikus" and plain(b.pickup:GetText())=="Essence of Eranikus, from Shade of Eranikus. Nothing to pick up first.")
assert(P.guideQuest:GetText()=="Guide entrance" and P.guideQuest:IsEnabled() and plain(P.details:GetText()):find("How to get it:",1,true))
b=show(3528)
assert(plain(b.title:GetText())=="Later: 2 quests first - The God Hakkar" and plain(b.pickup:GetText()):find("Next: The Prophecy of Mosh'aru",1,true))
assert(P.guideQuest:GetText()=="Guide next step" and P.guideQuest:IsEnabled())
assert(not active(), "browsing set a destination")
P.guideQuest:GetScript("OnClick")(P.guideQuest);assert(active().source.questID==3527)
b=show(1446);assert(P.guideQuest:GetText()=="Guide pickup")
-- the receipt for the next data pull
local receipt=FP.db.dungeonSources
assert(receipt.key=="sunken-temple" and receipt.database==true and receipt.version==FP.version and receipt.by.inside==1 and receipt.by.prereq>=1 and receipt.lines==#P.rows and receipt.rows+receipt.steps+receipt.finish==receipt.lines and receipt.held==0)
assert(#FP.db.errors==0)
''',
    }
