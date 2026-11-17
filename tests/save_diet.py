"""Save diet (schema 3, v0.28.0): a recorded profile is slimmed once at login, and the
recorder keeps only what a feature reads back unless the research dataset is switched on.
Mock-only; the same login was also replayed against a real 6.6 MB profile (see docs/SPEC.md)."""

# A schema-2 profile as a played character leaves it: research rows next to the few
# records a feature reads. Loaded through the real ADDON_LOADED / PLAYER_LOGIN path.
LEGACY = r'''
M.frames,M.timers,M.tickers={},{},{}
M.chat={}
local function pt(x) return {m=1413,x=x,y=.5,z="The Barrens",observer=true,source="player"} end
local xp={};for i=1,400 do xp[i]={t=1000+i*60,xp=i,max=50000,l=30} end
local samples={};for i=1,200 do samples[i]={t=i,sig="s"..i} end
local function report(t) return {t=t,ok=1,fail=0,rows={},navigation={quests={}}} end
HearthAndHustleDB={version=2,
 settings={record=true,probe={enabled=true},arrow={shown=true}},
 meta={created=5,builds={},counters={kills=14926,progress=3096}},
 data={
  creatures={[3396]={n="Razormane Quilboar",kills=4,loot={[4306]=2},pos={pt(.4)}},[260569]={n="Shady Smuggler",kills=0,loot={},pos={pt(.6)}}},
  objects={[166863]={count=3,loot={},pos={pt(.3)}}},
  items={[4306]={n="Silk Cloth"},[11504]={n="Un'Goro Soil",quest=4290}},
  vendors={[3881]={n="Innkeeper",items={[159]={p=25}}}},
  zones={["The Barrens"]={m=1413,first=1,last=2}},
  binds={[3881]={area="Crossroads"}},
  recipes={[165]={n="Leatherworking",r={[2149]={diff={["1"]=0,["2"]=1}}}}},
  progress={{q=9001,o=1,from=0,to=1,t=10},{q=9001,o=1,from=1,to=2,t=11}},
  deaths={{t=12,l=30}},
  lootObservations={{t=13,items={[4306]=1}}},
  quests={
   [9001]={t="Kept quest",givers={[3446]=true},enders={[3447]=true},gpos={m=1413,x=.5,y=.3},epos={m=1413,x=.52,y=.31},startItem=nil,
    obj={{text="Mob slain",type="monster",req=8,pos={pt(.41),pt(.45)},legacyMobCandidatesV1={[3396]=2},legacySourceCandidatesV1={x=1}}},
    log={{c="A-B",acc=1,done=2}},items={[4306]={[3396]=1}},legacyItemsV1={[4306]=true},xp={["30"]=1350},text="kept: long quest text is opt-in"},
   [9002]={t="Bare quest",givers={},enders={},xp={}},
  },
  npcs={
   [3446]={n="Mankrik",pos={pt(.5)},flags={quest=true},gossip={"A","B"},first=1,last=2},
   [3447]={n="Named by a quest only",pos={pt(.52)},flags={},first=1,last=2},
   [3704]={n="Flagged trainer",pos={pt(.48)},flags={trainer=true},first=1,last=2},
   [7777]={n="Only looked at",pos={pt(.7)},flags={},first=1,last=2},
  },
  trainers={[3704]={n="Mahani",services={a={name="Bandage"}}}},
  taxi={nodes={[25]={n="Crossroads, The Barrens",m=1464,x=.55,y=.53}},edges={["25>23"]={cost=110}}},
  xp={["Tester-Realm"]=xp},
  chars={["Tester-Realm"]={class="SHAMAN",level=30}},
  pvp={players={Noblewarrior={class="PRIEST",seen=2}}},bg={},
 },
 apicheck={["70790"]=report(1),["70862"]=report(2),["70888"]=report(3),["70888-manual"]=report(4),["70938"]=report(5),["70790-manual"]=report(0)},
 apicheckHistory={report(1),report(2),report(3)},
 probe={samples=samples,events={["UNIT_AURA:player:table"]=9},registration={},lastSig="s200",count=200},
 errors={},
}
HearthAndHustleCharDB={waypoints={},completed={},nextId=1,lootSeen={["Creature-0-1-1-1-3396-1"]={t=1,items={},quests={}}}}
local function boot()
 M.frames,M.timers,M.tickers={},{},{}
 local nextFP={}
 for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
  line=line:gsub("\r","")
  if line:match("%.lua$") then assert(loadfile("HearthAndHustle/"..line:gsub("\\","/")))("HearthAndHustle",nextFP) end
 end
 M.FireEvent("ADDON_LOADED","HearthAndHustle");M.FireEvent("PLAYER_LOGIN");M.RunTimers(10);M.RunTimers(2)
 return nextFP
end
local function said(text) local n=0;for _,line in ipairs(M.Chat()) do if tostring(line):find(text,1,true) then n=n+1 end end;return n end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
'''


def cases(hub):
    return {
        'save_diet_slims_a_recorded_profile_once_and_keeps_what_features_read': LEGACY + r'''
local F=boot()
local db,d=HearthAndHustleDB,HearthAndHustleDB.data
assert(db.version==3 and F.DB_VERSION==3)
-- research rows are gone
for _,key in ipairs({"creatures","objects","items","vendors","zones","binds","recipes","progress","deaths","lootObservations"}) do
 assert(type(d[key])=="table" and next(d[key])==nil, key.." was kept")
end
-- the quest record the route reads is whole; its logs, loot tallies and old biased candidates are not
local q=d.quests[9001]
assert(q.t=="Kept quest" and q.givers[3446] and q.enders[3447] and q.gpos.x==.5 and q.epos.x==.52 and q.xp["30"]==1350)
assert(#q.obj[1].pos==2 and q.obj[1].text=="Mob slain" and q.obj[1].req==8)
assert(q.log==nil and q.items==nil and q.legacyItemsV1==nil and q.obj[1].legacyMobCandidatesV1==nil and q.obj[1].legacySourceCandidatesV1==nil)
assert(q.text=="kept: long quest text is opt-in", "opt-in quest text is the player's choice, not research data")
assert(d.quests[9002] and count(d.quests)==2)
-- NPCs: spoken to, or named by a quest; never the ones only looked at. Gossip lines go.
assert(d.npcs[3446] and d.npcs[3446].gossip==nil and d.npcs[3446].pos[1].x==.5)
assert(d.npcs[3447] and d.npcs[3704] and d.npcs[7777]==nil)
-- untouched: trainers, flight points, the old PvP roster, characters
assert(d.trainers[3704].services.a.name=="Bandage" and d.taxi.nodes[25].x==.55 and d.taxi.edges["25>23"].cost==110)
assert(d.pvp.players.Noblewarrior.seen==2 and d.chars["Tester-Realm"].class=="SHAMAN")
-- XP: the newest samples, in order
local xp=d.xp["Tester-Realm"]
assert(#xp==180 and xp[1].xp==221 and xp[180].xp==400 and xp[2].t>xp[1].t)
-- diagnostics: newest three API reports, no history, no probe samples (its event counters stay)
-- (this login's own report for the mock build is the fourth)
assert(db.apicheck["70938"] and db.apicheck["70888-manual"] and db.apicheck["70888"] and db.apicheckHistory==nil)
assert(db.apicheck["70790"]==nil and db.apicheck["70862"]==nil and db.apicheck["70790-manual"]==nil and count(db.apicheck)<=4)
assert(#db.probe.samples==0 and db.probe.events["UNIT_AURA:player:table"]==9)
-- settings: recording stays on, the dataset and the beta probe are off
assert(db.settings.record==true and db.settings.recordDataset==false and db.settings.probe.enabled==false)
assert(next(HearthAndHustleCharDB.lootSeen)==nil)
-- the receipt for the next data pull, and one line in chat
local r=db.meta.diet
assert(r.from==2 and r.version==F.version and r.probeWasOn==true)
assert(r.removed.creatures==2 and r.removed.progress==2 and r.removed.npcs==1 and r.removed.xpSamples==220 and r.removed.apicheck==3
 and r.removed.apicheckHistory==3 and r.removed.probeSamples==200 and r.removed.questFields==5 and r.removed.items==2, snapshot(r.removed))
assert(db.meta.counters.kills==14926, "lifetime counters are kept")
assert(said("Save file slimmed")==1)
-- positive control: the route still finds the recorded turn-in place of the kept quest
local m,x,y,how=F.Planner:ResolveTurnIn(9001)
assert(m==1413 and x==.52 and how=="recorded", tostring(how))
assert(#db.errors==0)
-- second login: nothing more is removed and nothing is announced, even with the dataset back on
db.settings.recordDataset=true;db.settings.probe.enabled=true
d.creatures[1]={n="Recorded on purpose",kills=1,loot={},pos={}}
db.probe.samples[1]={t=1,sig="x"}
local stamp=r.t
M.chat={}
local G=boot()
assert(HearthAndHustleDB.data.creatures[1] and #HearthAndHustleDB.probe.samples>=1 and HearthAndHustleDB.settings.probe.enabled==true)
assert(HearthAndHustleDB.meta.diet.t==stamp and said("Save file slimmed")==0 and #HearthAndHustleDB.errors==0)
FP.db=HearthAndHustleDB
''',

        'save_diet_leaves_a_fresh_install_and_an_empty_profile_alone': r'''
M.chat={}
local function boot()
 M.frames,M.timers,M.tickers={},{},{}
 local nextFP={}
 for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
  line=line:gsub("\r","")
  if line:match("%.lua$") then assert(loadfile("HearthAndHustle/"..line:gsub("\\","/")))("HearthAndHustle",nextFP) end
 end
 M.FireEvent("ADDON_LOADED","HearthAndHustle");M.FireEvent("PLAYER_LOGIN");M.RunTimers(10);M.RunTimers(2)
 return nextFP
end
local function said(text) local n=0;for _,line in ipairs(M.Chat()) do if tostring(line):find(text,1,true) then n=n+1 end end;return n end
-- nothing saved yet
HearthAndHustleDB,HearthAndHustleCharDB=nil,nil
local F=boot()
assert(HearthAndHustleDB.version==3 and HearthAndHustleDB.meta.diet==nil and said("Save file slimmed")==0)
assert(HearthAndHustleDB.settings.record==false and HearthAndHustleDB.settings.recordDataset==false)
-- an older profile with nothing to remove keeps its probe choice and is told nothing
HearthAndHustleDB={version=2,settings={record=false,probe={enabled=true}}};HearthAndHustleCharDB=nil
boot()
assert(HearthAndHustleDB.version==3 and HearthAndHustleDB.meta.diet==nil and HearthAndHustleDB.settings.probe.enabled==true and said("Save file slimmed")==0)
assert(#HearthAndHustleDB.errors==0)
FP.db=HearthAndHustleDB
''',

        'recorder_without_the_dataset_keeps_route_data_and_drops_research_rows': r'''
local d=FP.data
local function play()
 -- a quest giver, a kill that moves an objective, loot, a vendor, a death, a zone, XP
 M.SetUnit("npc",{guid="Creature-0-4379-1-13-3446-00003BB8D2",name="Mankrik",level=25,reaction=5})
 M.dialogQuest=9101;M.FireEvent("QUEST_DETAIL",0)
 local q={questID=9101,title="Diet quest",objectives={{text="0/2 Quilboar slain",type="monster",numFulfilled=0,numRequired=2,finished=false}}}
 M.AddQuest(q);M.FireEvent("QUEST_ACCEPTED",9101);M.RunTimers(1)
 M.SetUnit("npc",nil)
 M.SetUnit("mouseover",{guid="Creature-0-4379-1-13-5555-00003BB8E9",name="Bystander",level=20,reaction=5})
 M.FireEvent("UPDATE_MOUSEOVER_UNIT")
 M.SetUnit("target",{guid="Creature-0-4379-1-13-3396-00003BB8E0",name="Razormane Quilboar",level=19,reaction=2})
 M.FireEvent("PLAYER_TARGET_CHANGED")
 M.units.target.dead=true;M.FireEvent("PLAYER_TARGET_DIED")
 q.objectives[1].numFulfilled=1;q.objectives[1].text="1/2 Quilboar slain"
 M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(1)
 M.lootSlots={{name="Silk Cloth",qty=1,itemID=4306}};M.FireEvent("LOOT_OPENED")
 M.SetUnit("target",nil)
 M.SetUnit("npc",{guid="Creature-0-4379-1-13-3881-00003BB8F0",name="Innkeeper Boorand",level=30,reaction=5})
 M.FireEvent("MERCHANT_SHOW");M.SetUnit("npc",nil)
 M.FireEvent("PLAYER_DEAD");M.FireEvent("ZONE_CHANGED_NEW_AREA");M.RunTimers(2)
 M.FireEvent("PLAYER_XP_UPDATE","player")
end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
-- the default: recording on, research dataset off
cmd("record dataset off")
assert(FP.settings.record==true and FP.settings.recordDataset==false and FP.Recorder.Dataset()==false)
play()
local ids={};for i=1,5 do ids[i]=10000+i end
C_TradeSkillUI.GetFilteredRecipeIDs=function() return ids end
FP.Prof:ScanRecipes();M.RunTimers(2)
assert(next(d.recipes)==nil, "the recipe table is research data")
assert(count(d.creatures)==0 and #d.progress==0 and #d.deaths==0 and count(d.vendors)==0 and count(d.zones)==0 and count(d.items)==0
 and #d.lootObservations==0 and count(FP.cdb.lootSeen)==0, "research rows were written with the dataset off")
-- what the route reads is still recorded: the giver, where it stood, and where the objective moved
local q=d.quests[9101]
assert(q and q.t=="Diet quest" and q.givers[3446] and q.gpos and q.gpos.m and q.log==nil)
assert(d.npcs[3446] and d.npcs[3446].flags.quest and d.npcs[5555]==nil and d.npcs[3881]==nil)
assert(q.obj[1].pos and #q.obj[1].pos==1, "the objective area must still be folded into the quest")
local key=FP.Recorder.char
assert(#d.xp[key]==1)
-- XP samples stop at the last three hours' worth
for i=1,400 do d.xp[key][#d.xp[key]+1]={t=i,xp=i,max=9,l=1} end
M.now=(M.now or 0)+120;FP.Recorder:OnLevelUp(31)
assert(#d.xp[key]==180, #d.xp[key])
-- switched on, the same play records the research rows as before
cmd("record dataset on")
assert(FP.Recorder.Dataset()==true)
M.RemoveQuest(9101);FP.Recorder.RescanLog("reset")
play()
assert(d.creatures[3396] and d.creatures[3396].kills==1 and d.creatures[5555] and #d.progress==1 and #d.deaths==1 and count(d.zones)>=1
 and d.items[4306] and d.quests[9101].log and d.vendors[3881], "the dataset recorder lost a row")
FP.Prof:ScanRecipes();M.RunTimers(2)
assert(d.recipes[197] and FP.Util.Count(d.recipes[197].r)==5)
''',

        'record_command_and_diagnostics_page_have_both_levels': hub + r'''
local function last() local c=M.Chat();return tostring(c[#c]) end
cmd("record off");cmd("record dataset off")
assert(FP.settings.record==false and FP.settings.recordDataset==false and FP.Recorder.Dataset()==false)
-- the dataset needs recording, so asking for it switches both on
cmd("record dataset on")
assert(FP.settings.record==true and FP.settings.recordDataset==true and last():find("research dataset on",1,true))
-- recording off silences the dataset without forgetting the choice
cmd("record off")
assert(FP.settings.recordDataset==true and FP.Recorder.Dataset()==false and last():find("research dataset off",1,true))
cmd("record on");assert(FP.Recorder.Dataset()==true)
-- asking is not changing; a typo changes nothing
local epoch=FP.recordEpoch
cmd("record dataset");assert(FP.settings.recordDataset==true and FP.recordEpoch==epoch and last():find("recording on",1,true))
cmd("record datset on");assert(FP.settings.recordDataset==true and FP.settings.record==true and FP.recordEpoch==epoch and last():find("Usage",1,true))
cmd("record dataset maybe");assert(FP.settings.recordDataset==true and last():find("Usage",1,true))
-- bare /hh record still toggles
cmd("record");assert(FP.settings.record==false);cmd("record");assert(FP.settings.record==true)
-- the Diagnostics page shows and sets both
page("tools")
assert(H.controls.recording:GetChecked() and H.controls.recordingDataset:GetChecked())
check("recordingDataset",false);assert(FP.settings.recordDataset==false and FP.settings.record==true)
check("recording",false);assert(FP.settings.record==false)
''',

        'api_reports_keep_no_history_and_only_the_newest_builds': r'''
cmd("apicheck");cmd("apicheck")
assert(FP.db.apicheckHistory==nil, "the report history is back")
for i=1,6 do FP.db.apicheck["build"..i]={t=i,rows={}} end
FP.Recorder:TrimData()
local n=0;for _ in pairs(FP.db.apicheck) do n=n+1 end
assert(n==3 and FP.APICHECK_KEPT==3, n)
assert(FP.db.apicheck["70124-manual"], "the report just made is the newest")
''',
    }
