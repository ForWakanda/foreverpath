"""Regressions from the November 10 client-data and module review."""
REVIEW_CASES = {
"review_count_first_objective_and_uncached_label": r'''
local Q=FP.QuestObjectives
local ref={kind="Npc",name="Twilight Raider",points={}}
for _,label in ipairs({"8/8 Twilight Raider slain","Twilight Raider slain: 8/8","|cffffffff8/8 Twilight Raider slain|r"}) do
 assert(Q:Match({type="monster",text=label},{ref})==ref)
 assert(FP.Util.ObjectiveText(label)=="Twilight Raider slain")
end
assert(not Q:Match({type="monster",text="0/8   slain"},{ref}))
assert(not FP.Util.ObjectiveText("0/8 "))
local q=addQuest(9001);q.objectives[1].text="0/8 Twilight Raider slain"
FP.Recorder.RescanLog("known");q.objectives[1].text="0/8   slain";FP.Recorder.RescanLog("uncached")
assert(FP.data.quests[9001].obj[1].text=="Twilight Raider slain")
q.objectives[1].text="2/8 Twilight Raider slain";FP.Planner:Build()
assert(FP.Planner.steps[1].text=="Twilight Raider slain")
''',
"review_hearth_is_never_automatic_selection": r'''
FP.API.GetSelectedQuest=function() return nil end
local p=FP.Planner;p.waiting=nil;p.steps={{kind="hearth",mapID=1413,x=.3,y=.3},{kind="objective",questID=9,mapID=1413,x=.4,y=.4}}
assert(p:NextStep()==p.steps[2]);p.steps[2]=nil;assert(p:NextStep()==nil)
''',
"review_delivery_does_not_route_to_accept_position": r'''
local q=addQuest(9001,true);q.waypoint=nil;q.objectives={}
FP.data.quests[9001]={gpos={m=1413,x=.2,y=.3},givers={},enders={}}
assert(FP.Planner:ResolveTurnIn(9001)==nil)
q.objectives={{text="1/1 Mob slain",type="monster",numRequired=1,finished=true}}
assert(FP.Planner:ResolveTurnIn(9001)==1413)
FP.data.quests[9001].startItem=123;assert(FP.Planner:ResolveTurnIn(9001)==nil)
FP.data.quests[9001].epos={m=1413,x=.4,y=.5};assert(FP.Planner:ResolveTurnIn(9001)==1413)
''',
"review_other_continent_destination_and_local_preference": r'''
local distant={mapID=1417,x=.2,y=.3,name="Other continent"}
local nearby={mapID=1413,x=.6,y=.6,name="Nearby"}
FP.Pos.DistanceTo=function(_,p) if p==nearby then return 40 end end
FP.QuestObjectives.groups={{questID=9,objIndex=1,points={distant}}}
assert(FP.QuestObjectives:Nearest(9,1)==distant)
FP.QuestObjectives.groups[1].points[2]=nearby;assert(FP.QuestObjectives:Nearest(9,1)==nearby)
FP.API.GetQuestEnders=function() return {{points={distant}}} end
assert(FP.Planner:ResolveTurnIn(9)==1417)
''',
"review_unchanged_auto_route_does_not_refresh_pins": r'''
addQuest(9001);FP.Planner:Auto();FP.Planner:Auto()
local changes=0;FP:On("WAYPOINTS_CHANGED",function() changes=changes+1 end)
FP.Planner:Auto();assert(changes==0,changes)
''',
}

REVIEW_CASES.update({
"review_delivery_uses_known_ender_and_unavailable_zones_fail_closed": r'''
local q=addQuest(9001);q.objectives={};q.waypoint=nil
FP.API.GetQuestEnders=function() return {{points={{mapID=1413,x=.4,y=.5,name="Recipient"}}}} end
local m,x,y,how=FP.Planner:ResolveObjective(9001,1);assert(m==1413 and how=="known turn-in: Recipient")
LibQuestieDB={flavor={expansion="Forever"},RequireContract=function() return true end}
for _,k in ipairs({"Quest","Npc","Item","Object"}) do LibQuestieDB[k]={Get=function() end} end
assert(not FP.API.QuestDatabaseStatus())
''',
"review_recorded_objective_corpus_cleaning": r'''
local rows=dofile("tests/fixtures/recorded-objectives.lua");assert(#rows>400)
local stripped=0
for _,o in ipairs(rows) do
 local text=FP.Util.ObjectiveText(o.text)
 if o.text:match("^%d+/%d+") then
  stripped=stripped+1;assert(not text or not text:match("^%d+/%d+"))
 end
end
assert(stripped>350)
''',
})
