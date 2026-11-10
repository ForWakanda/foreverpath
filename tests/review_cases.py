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

REVIEW_CASES.update({
"review_resume_releases_manual_route_without_deleting_saved_places": r'''
local q=addQuest(9001);cmd("way 20 20 Saved place");local manual=active()
FP.Hub:Open("navigation");FP.Hub.controls.resume:GetScript("OnClick")()
assert(manual.suspended and FP.Waypoints:Get(manual.id)==manual and active().source.questID==9001)
FP.Waypoints:SetActive(manual.id);assert(active()==manual and not manual.suspended)
FP.Hub.controls.pause:GetScript("OnClick")();assert(FP.Planner.paused and FP.settings.autoNext)
''',
"review_utf8_settings_refresh_and_panel_anchor": r'''
assert(FP.Util.Truncate("éclair猫",4)=="écl…")
assert(FP.Util.Truncate("猫猫猫",2)=="猫…")
FP.Hub:Open("town");local field=FP.Hub.controls.prepfood
assert(not field:HasFocus())
FP.cdb.prep.food=55;FP.Hub:Refresh();assert(field:GetText()=="55")
field:SetText("61");FP.cdb.prep.food=56;FP.Hub:Refresh();assert(field:GetText()=="61","draft lost")
local f=FP.Panel.frame;f._left,f._top=200,800
UIParent:SetHeight(1080);FP.Panel:ApplySettings()
assert(FP.settings.panel.point=="TOPLEFT" and FP.settings.panel.x==200 and FP.settings.panel.y==-280)
f:SetHeight(300);assert(FP.settings.panel.y==-280)
''',
"review_checklist_does_not_enable_pvp_and_windows_close_with_escape": r'''
FP.settings.pvp.enabled=false;FP.settings.pvp.manual="hide"
FP.Hub:Open("town");FP.Hub.controls.prepShow:GetScript("OnClick")();M.RunTimers(1)
assert(not FP.settings.pvp.enabled and FP.settings.pvp.manual=="hide" and FP.PvP.frame:IsShown())
FP.Hub.controls.prepHide:GetScript("OnClick")();M.RunTimers(1);assert(not FP.PvP.frame:IsShown())
cmd("partyexport")
local names={};for _,n in ipairs(UISpecialFrames) do names[n]=true end
assert(names.HearthAndHustleDungeons and names.HearthAndHustleExport)
''',
})

REVIEW_CASES.update({
"review_fresh_defaults_opt_out_and_observations_are_bounded": r'''
assert(FP.defaults.settings.record==false and FP.defaults.settings.probe.enabled==false)
local records={old={last=1},new={last=5},middle={last=3}}
FP.Util.TrimRecords(records,2);assert(not records.old and records.new and records.middle)
for i=1,510 do FP.data.pvp.players["Player"..i]={last=i} end
FP.Recorder:TrimData();assert(FP.Util.Count(FP.data.pvp.players)==500 and not FP.data.pvp.players.Player1)
''',
"review_trainer_keeps_multiple_ranks_and_recipe_scans_deduplicate": r'''
M.SetUnit("npc",{guid="Creature-0-4379-1-13-3066-00003BB8D2",name="Trainer",level=60})
FP.API.GetTrainerServices=function() return {
 {name="Lightning Bolt",sub="Rank 1",level=1,cost=10},
 {name="Lightning Bolt",sub="Rank 2",level=4,cost=100}} end
FP.Recorder:OnTrainer()
assert(FP.Util.Count(FP.data.trainers[3066].services)==2)
assert(#FP.Trainer:NotesForLevel(4)==1 and FP.Trainer:NotesForLevel(4)[1].list[1].name=="Lightning Bolt")
M.FireEvent("TRADE_SKILL_SHOW");M.RunTimers(3)
local count=FP.db.meta.counters.recipes
local calls=0;local original=FP.API.GetRecipeReagents
FP.API.GetRecipeReagents=function(...) calls=calls+1;return original(...) end
M.FireEvent("TRADE_SKILL_LIST_UPDATE");M.RunTimers(1)
assert(FP.db.meta.counters.recipes==count and calls==0)
M.FireEvent("TRADE_SKILL_CLOSE");M.FireEvent("TRADE_SKILL_SHOW");M.RunTimers(3)
assert(calls>0 and FP.db.meta.counters.recipes==count)
''',
})

REVIEW_CASES["review_probe_off_stops_event_telemetry"] = r'''
FP.settings.probe.enabled=false
local before=snapshot(FP.db.probe)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","player","cast",123)
M.FireEvent("UNIT_AURA","target",{})
M.FireEvent("PLAYER_TARGET_CHANGED");M.RunTimers(1)
assert(snapshot(FP.db.probe)==before)
'''
