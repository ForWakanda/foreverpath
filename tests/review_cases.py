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

REVIEW_CASES.update({
"review_rare_messages_reject_nonfinite_and_outside_context": r'''
local R=FP.RareWatch
for _,n in ipairs({"1e999","nan","-5.5","0","1.5","2147483648"}) do assert(not R:Decode("RW;kill;"..n..";x"),n) end
for _,n in ipairs({"1e999","nan","-1","1.5","256"}) do assert(not R:Decode("RW;up;"..n..";Undead;x"),n) end
local p=R:Decode("RW;up;40;Undead;|Tfoo|t");assert(p and not p.name:find("|",1,true))
R:OpenRun({name="Test"},"test");R.inside=false
local before=snapshot(FP.db.rare);assert(not R:Receive("RW;kill;6490;x","friend"));assert(snapshot(FP.db.rare)==before)
R.inside=true;FP.settings.rare.enabled=false;assert(not R:Receive("RW;no","friend"));assert(snapshot(FP.db.rare)==before)
FP.settings.rare.enabled=true;assert(R:Receive("RW;kill;6490;x","friend"));assert(R:Current().kills[6490]==1)
assert(not FP.Party:Parse("FP1;|Tfoo|t;MAGE;40;1"))
''',
"review_pin_passthrough_and_secure_hud_wait_for_combat_end": r'''
local calls=0
MapCanvasPinMixin.CheckMouseButtonPassthrough=function() calls=calls+1 end
FP.API.InCombat=function() return true end
HearthAndHustleMapPinMixin.CheckMouseButtonPassthrough({})
HearthAndHustleObjectivePinMixin.CheckMouseButtonPassthrough({})
assert(calls==0)
local R=FP.RareWatch
local old=R.frame.SetHeight;R.frame.SetHeight=function() error("protected anchor resized") end
R:Layout();R:ApplySettings();R:Refresh();assert(R.scanPending)
R.frame.SetHeight=old;FP.API.InCombat=function() return false end
HearthAndHustleMapPinMixin.CheckMouseButtonPassthrough({});assert(calls==1)
M.FireEvent("PLAYER_REGEN_ENABLED");assert(not R.scanPending)
''',
"review_blocked_actions_are_recorded": r'''
M.FireEvent("ADDON_ACTION_BLOCKED","OtherAddon","ignored")
assert(#FP.db.errors==0)
M.FireEvent("ADDON_ACTION_BLOCKED","HearthAndHustle","SetPassThroughButtons()")
assert(#FP.db.errors==1 and FP.db.errors[1].where=="ADDON_ACTION_BLOCKED")
FP.db.errors={}
''',
})

REVIEW_CASES.update({
"review_gear_catalog_loads_only_on_demand_and_has_missing_stats": r'''
assert(not FP.GearCatalog,"catalog loaded at login")
local old=C_AddOns.LoadAddOn;local loads=0
C_AddOns.LoadAddOn=function(...) loads=loads+1;return old(...) end
M.combatLockdown=true;assert(not FP.API.EnsureGearCatalog() and loads==0)
M.combatLockdown=false;assert(FP.API.EnsureGearCatalog() and loads==1)
assert(FP.API.EnsureGearCatalog() and loads==1)
local slots,stats={},{}
for _,item in ipairs(FP.GearCatalog.items) do
 slots[item.equipLoc]=(slots[item.equipLoc] or 0)+1
 for k in pairs(item.stats) do stats[k]=(stats[k] or 0)+1 end
end
assert(slots.INVTYPE_CLOAK==375 and slots.INVTYPE_THROWN==13)
assert(stats.ITEM_MOD_ATTACK_POWER_SHORT>=320 and stats.ITEM_MOD_MANA_REGENERATION_SHORT>=260 and stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT>=550)
''',
"review_gear_level_proxy_stays_bounded_and_offhand_checks_skill": r'''
FP.API.GetCharInfo=function() return {class="SHAMAN",level=40} end
local item={id=1,name="Reward",equipLoc="INVTYPE_CLOAK",classID=4,subclassID=1,level=30,stats={},sources={},sourceTypes={}}
FP.GearCatalog={items={item}}
assert(#FP.Gear:Rows({slot="CLOAK",level=30})==1)
assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==0)
item.level=nil;assert(#FP.Gear:Rows({slot="CLOAK",level=20})==0)
assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==1)
assert(not FP.Gear:SlotMatches({equipLoc="INVTYPE_WEAPON"},"OFF"))
M.dualWield=true;assert(FP.Gear:SlotMatches({equipLoc="INVTYPE_WEAPON"},"OFF"))
''',
"review_gear_dungeon_alias_and_wings_are_explicit": r'''
local P=FP.GearPanel
local function row(name) return {item={sourceTypes={"Dungeon"},sources={name}}} end
assert(#P:Dungeons(row("Scarlet Monastery"))==4)
assert(#P:Dungeons(row("Blackrock Spire"))==2)
assert(#P:Dungeons(row("Stratholme"))==2)
assert(P:Dungeons(row("Temple of Atal'Hakkar"))[1].key=="sunken-temple")
assert(#P:Dungeons(row("Unmapped dungeon"))==0)
''',
})
