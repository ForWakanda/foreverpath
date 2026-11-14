"""Player-selected enemy identities and honest navigation explanations."""

def cases(hub):
    return {
        'enemy_browser_names_are_not_reparsed_as_commands': r'''
local W=FP.EnemyWatch
M.Enemy("target","Alex","One")
W:Receive("EW;1;Alex: party text;MAGE;30;Guild","Friend-Realm")
assert(W:BrowseAction("Alex: party text","kos","Reason"))
assert(W:KOS("Alex: party text") and not W:KOS("Alex One"))
W:BrowseAction("Alex: party text","ignore")
assert(W:Ignored("Alex: party text") and not W:Ignored("Alex One"))
assert(not W:BrowseAction("Nobody Known","kos"))
''',

        'enemy_browser_exact_clicks_keep_same_first_names_separate': hub + r'''
local W=FP.EnemyWatch
M.Enemy("target","Alex","One")
M.Enemy("focus","Alex","Two")
page("pvp");field("enemySearch","Alex")
assert(#H.controls.enemyPlayers.items==2)
assert(not H.controls.enemyAddKOS:IsEnabled())
selectRow("enemyPlayers",1);local chosen=H:Selected(H.controls.enemyPlayers).name
field("enemyReason","Ambushed me");click("enemyAddKOS")
assert(W:KOS(chosen).reason=="Ambushed me")
local other=chosen=="Alex One" and "Alex Two" or "Alex One"
assert(not W:KOS(other) and not H.controls.enemyAddKOS:IsEnabled())
click("enemyRemoveKOS");assert(not W:KOS(chosen))
click("enemyIgnore")
assert(W:Ignored(chosen) and not W:Ignored(other) and #H.controls.enemyPlayers.items==1)
assert(not H.controls.enemyIgnore:IsEnabled())
selectRow("ignoreList",1);click("ignoreRemove")
assert(not W:Ignored(chosen) and #H.controls.enemyPlayers.items==2)
''',
        'enemy_browser_party_reports_and_possible_outcomes_stay_distinct': hub + r'''
local W,DB=FP.EnemyWatch,FP.db.enemyWatch
W:Receive("EW;1;Reported Person;MAGE;30;Guild","Friend-Realm")
local row=W:Browse("Reported")[1]
assert(row and row.source:find("Party report",1,true) and not row.record)
assert(W:BrowseDetails(row):find("No local encounter",1,true))
M.Enemy("target","Reported","Person")
row=W:Browse("Reported")[1]
assert(row.record and row.source:find("Seen locally",1,true))
DB.lastDeath={possible=row.name,confirmed=false}
assert(W:BrowseDetails(row):find("possible attacker only",1,true))
assert((row.record.losses or 0)==0)
DB.lastDeath={name=row.name}
assert(W:BrowseDetails(row):find("confirmation not recorded",1,true))
DB.lastDeath.confirmed=true
assert(W:BrowseDetails(row):find("confirmed by death recap",1,true))
''',
        'enemy_browser_ages_relog_and_hidden_refresh_are_read_only': hub + r'''
local W,DB=FP.EnemyWatch,FP.db.enemyWatch
DB.players["Old Person"]={last=FP.API.Now()-7200,wins=2,losses=1}
local row=W:Browse("Old")[1]
assert(row.age==7200 and not row.nearby and row.source=="Recorded encounter")
M.Enemy("target","Recent","Person")
page("pvp");local state=snapshot(FP.db.enemyWatch)..snapshot(FP.cdb)
local frames=#M.frames
for i=1,5 do H:Refresh() end
assert(#M.frames==frames and state==snapshot(FP.db.enemyWatch)..snapshot(FP.cdb))
local calls=0;local browse=W.Browse
W.Browse=function(self,query) calls=calls+1;return browse(self,query) end
H.frame:Hide();M.Tick(2);assert(calls==0)
page("pvp");calls=0;M.Tick(2);assert(calls>0 and #M.frames==frames)
W.nearby={};row=W:Browse("Recent")[1]
assert(not row.nearby and row.source=="Recorded encounter")
''',
        'enemy_browser_filter_stale_selection_and_instance_context': hub + r'''
local W=FP.EnemyWatch
M.Enemy("target","Alex","One");M.Enemy("focus","Alex","Two")
page("pvp");field("enemySearch","One");H.controls.enemySearch:GetScript("OnTextChanged")();selectRow("enemyPlayers")
field("enemySearch","Two");H.controls.enemySearch:GetScript("OnTextChanged")()
assert(not H.controls.enemyIgnore:IsEnabled())
H.controls.enemyIgnore:GetScript("OnClick")(H.controls.enemyIgnore)
assert(not W:Ignored("Alex One") and not W:Ignored("Alex Two"))
FP.API.InInstance=function() return true end
for _,r in ipairs(W:Browse()) do assert(not r.nearby) end
''',
        'navigation_explanation_manual_resume_preserves_saved_destination': hub + r'''
addQuest(9101)
cmd("way 55 55 Saved place");local wp=active();wp.persistent=true
local state=snapshot(FP.cdb)..snapshot(FP.settings)
local title,detail=FP.Planner:Guidance()
assert(title=="Manual destination" and detail:find("saved destinations are kept",1,true))
assert(state==snapshot(FP.cdb)..snapshot(FP.settings))
FP.Panel:Toggle(true);FP.Panel.resumeButton:GetScript("OnClick")()
assert(FP.Waypoints:Get(wp.id) and wp.suspended)
assert(active().source.type=="plan")
assert(FP.Panel.guidanceText:GetText()==FP.Planner:Guidance())
FP.Panel.guidanceButton:GetScript("OnClick")();assert(H.selected=="navigation")
''',
        'navigation_explanation_selected_pinned_auto_and_source': r'''
local P=FP.Planner
addQuest(9101);P:Build()
FP.API.GetSelectedQuest=function() return 9101 end
P:Go(P:NextStep(),true)
local title,detail=P:Guidance()
assert(title=="Selected quest" and detail:find("tracked quest",1,true))
assert(detail:find("client waypoint",1,true))
P:Go(P:NextStep());assert(P:Guidance()=="Chosen quest step")
P.pinned=nil;FP.API.GetSelectedQuest=function() return nil end
local title,detail=P:Guidance()
assert(title=="Automatic quest choice" and detail:find("straight-line",1,true))
assert(not detail:find("nearest",1,true))
P.current={questID=999,title="Stale",how="WRONG"}
assert(not select(2,P:Guidance()):find("WRONG",1,true))
''',
        'navigation_explanation_paused_waiting_missing_and_battleground': r'''
local P=FP.Planner
FP.Waypoints:Clear();assert(P:Guidance()=="Guidance paused")
P.paused=nil;FP.settings.autoNext=true
local title,detail=P:Guidance()
assert(title=="No active destination" and detail:find("Quest locations",1,true))
P.waiting={title="Quest",kind="objective"}
assert(P:Guidance()=="Working in the quest area")
P.paused=true;assert(P:Guidance()=="Guidance paused")
FP.API.InBattleground=function() return true end
assert(P:Guidance()=="Quest guidance suspended")
''',
        'navigation_explanation_location_hold_and_turnin': r'''
local P=FP.Planner
FP.Waypoints:Clear();P.paused=nil;FP.settings.autoNext=true
FP.Waypoints:Add(1413,.6,.6,"Quest source",{source={type="quest-location",questID=9101}})
assert(P:Guidance()=="Selected quest location")
FP.Waypoints:Clear();P.paused=nil
addQuest(9101,true);P:Build();P:Go(P:NextStep(),true)
assert(select(2,P:Guidance()):find("Ready to turn in",1,true))
''',
    }
