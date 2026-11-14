"""Transition regressions from the 2026-11-14 review. No client writes."""
REVIEW_FIX_CASES = {}

REVIEW_FIX_CASES['navigation_arrival_clears_after_continent_change'] = (r"""""", r"""
local q=addQuest(9001)
FP.Planner.waiting={questID=9001,kind="objective",objIndex=1,mapID=1413,x=.6,y=.6,radius=35,title="Old objective"}
M.mapID=1413;M.px=.6;M.py=.6;FP.Pos:Refresh(true)
assert(FP.Planner:WaitingValid(),"control: at the objective")
local world=C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos=function(id,v) local _,p=world(id,v);return id==1413 and 1 or 2,p end
M.mapID=1411;FP.Pos:Refresh(true)
local d,_,same=FP.Pos:VectorTo(FP.Planner.waiting)
print("distance="..tostring(d).."; same continent="..tostring(same).."; waiting="..tostring(FP.Planner:WaitingValid()))
assert(not FP.Planner:WaitingValid(),"arrival wait survives leaving the continent")
""")

REVIEW_FIX_CASES['arrival_wait_preserves_unavailable_position'] = (r"""""", r"""
addQuest(9001)
FP.Planner.waiting={questID=9001,kind="objective",objIndex=1,mapID=1413,x=.6,y=.6,radius=35}
M.noPosition=true;FP.Pos:Refresh(true)
assert(FP.Planner:WaitingValid(),"unavailable position must not imply departure")
M.noPosition=false;M.px=.1;M.py=.1;FP.Pos:Refresh(true)
assert(not FP.Planner:WaitingValid(),"walking away still releases arrival")
""")

REVIEW_FIX_CASES['bar_levelup_during_long_combat'] = (r"""""", r"""
local B=FP.BarGuard
M.SetAction(49,"spell",1049);M.SetAction(50,"spell",1050)
B:Reconcile();assert(FP.cdb.barGuard.specs[1].slots[49])
M.combatLockdown=true
M.FireEvent("PLAYER_LEVEL_UP",41)
M.actions[49]=nil;M.actions[50]=nil
M.FireEvent("ACTIONBAR_SLOT_CHANGED",49);M.FireEvent("ACTIONBAR_SLOT_CHANGED",50)
M.RunTimers(30); assert(B.deferred and #M.placed==0)
M.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED");M.RunTimers(2)
print("restored="..#M.placed.."; remembered slot 49="..tostring(FP.cdb.barGuard.specs[1].slots[49]~=nil))
assert(M.actions[49] and M.actions[50],"level-up recovery was forgotten while combat delayed it")
""")

REVIEW_FIX_CASES['control_bar_levelup_outside_combat_recovers'] = (r"""""", r"""
local B=FP.BarGuard;M.SetAction(49,"spell",1049);B:Reconcile()
M.FireEvent("PLAYER_LEVEL_UP",41);M.actions[49]=nil;M.RunTimers(3.1)
assert(M.actions[49] and M.actions[49].id==1049)
""")

REVIEW_FIX_CASES['bars_delayed_levelup_without_slot_events_and_later_hand_edit'] = (r"""""", r"""
local B=FP.BarGuard
M.SetAction(49,"spell",1049); B:Reconcile()
M.combatLockdown=true; M.FireEvent("PLAYER_LEVEL_UP",41); M.actions[49]=nil
M.RunTimers(40); assert(B.deferred and not M.actions[49])
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(2)
assert(M.actions[49] and not B.strictPending)
M.RunTimers(20); M.actions[49]=nil; M.FireEvent("ACTIONBAR_SLOT_CHANGED",49); M.RunTimers(2)
assert(not M.actions[49] and not FP.cdb.barGuard.specs[1].slots[49],"ordinary later edit stays removed")
""")

REVIEW_FIX_CASES['bars_interrupted_burst_finishes_after_long_combat'] = (r"""""", r"""
local B=FP.BarGuard
for i=49,51 do M.SetAction(i,"spell",1000+i) end; B:Reconcile()
M.WipeActions(49,51); M.RunTimers(1.6)
local place=FP.API.PlaceOnBar; local n=0
FP.API.PlaceOnBar=function(slot,entry)
 n=n+1
 if n==2 then M.combatLockdown=true; return false,"combat" end
 return place(slot,entry)
end
M.RunTimers(2.1); assert(B.deferred and #M.placed==1)
M.RunTimers(30); M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(2)
assert(#M.placed==3 and not B.strictPending)
""")

REVIEW_FIX_CASES['enemy_uncertain_death_is_not_a_confirmed_loss'] = ('', '\nlocal W=FP.EnemyWatch\nM.Enemy("nameplate1","Bystander","One")\nM.SetUnit("nameplate1target",{is="player"});W:Scan()\nM.recap={id=123,events={}}\nM.FireEvent("PLAYER_DEAD");M.RunTimers(2)\nlocal p=FP.db.enemyWatch.players["Bystander One"]\nprint("losses="..tostring(p.losses).."; attribution="..tostring(FP.db.enemyWatch.lastDeath.how))\nassert((p.losses or 0)==0,"a player merely targeting me was counted as my killer")\n')

REVIEW_FIX_CASES['control_confirmed_recap_counts_a_loss'] = ('', '\nlocal u=M.Enemy("nameplate1","Known","Enemy")\nM.recap={id=123,events={{sourceGUID=u.guid,sourceName="Known Enemy"}}}\nM.FireEvent("PLAYER_DEAD");M.RunTimers(2)\nassert(FP.db.enemyWatch.players["Known Enemy"].losses==1)\n')

REVIEW_FIX_CASES["enemy_death_callback_cancels_on_disable_or_world_change"] = ("", r'''
local W=FP.EnemyWatch; local u=M.Enemy("nameplate1","Known","Enemy")
M.recap={id=123,events={{sourceGUID=u.guid,sourceName="Known Enemy"}}}
M.FireEvent("PLAYER_DEAD"); W:Command("off"); W:Command("on"); M.RunTimers(2)
assert(not FP.db.enemyWatch.players["Known Enemy"].losses)
M.FireEvent("PLAYER_DEAD"); M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(not FP.db.enemyWatch.players["Known Enemy"].losses)
M.FireEvent("PLAYER_DEAD"); M.instance={type="party"}; M.RunTimers(2)
assert(not FP.db.enemyWatch.players["Known Enemy"].losses)
''')
REVIEW_FIX_CASES["enemy_recap_explicit_npc_guid_cannot_match_player_name"] = ("", r'''
M.Enemy("nameplate1","Known","Enemy")
M.recap={id=124,events={{sourceGUID="Creature-0-1",sourceName="Known Enemy"}}}
M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(not FP.db.enemyWatch.players["Known Enemy"].losses)
FP.EnemyWatch.nearby={}
M.recap={id=125,events={{sourceName="Known Enemy"}}}
M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(not FP.db.enemyWatch.players["Known Enemy"].losses,"historical account name is not a session sighting")
''')

REVIEW_FIX_CASES['enemy_ambiguous_first_name_must_not_mark_both'] = ('', '\nlocal W=FP.EnemyWatch\nM.Enemy("nameplate1","Alex","One");M.Enemy("nameplate2","Alex","Two")\nW:KosCommand("+Alex")\nprint("Alex One KOS="..tostring(W:KOS("Alex One")~=nil).."; Alex Two KOS="..tostring(W:KOS("Alex Two")~=nil))\nassert(not W:KOS("Alex One") and not W:KOS("Alex Two"),"ambiguous first name silently marks both players")\n')

REVIEW_FIX_CASES['control_full_name_kos_is_specific'] = ('', '\nM.Enemy("nameplate1","Alex","One");M.Enemy("nameplate2","Alex","Two")\nFP.EnemyWatch:KosCommand("+Alex One")\nassert(FP.EnemyWatch:KOS("Alex One") and not FP.EnemyWatch:KOS("Alex Two"))\n')

REVIEW_FIX_CASES["enemy_ignore_rejects_ambiguity_and_removes_exact_rows"] = ("", r'''
local W=FP.EnemyWatch
M.Enemy("nameplate1","Alex","One");M.Enemy("nameplate2","Alex","Two");M.Enemy("target","Other","Target")
W:IgnoreCommand("+Alex")
assert(not W:Ignored("Alex One") and not W:Ignored("Alex Two") and not W:Ignored("Other Target"))
W:KosCommand("+Alex");assert(not W:KOS("Other Target"),"invalid input cannot fall back to current target")
W:IgnoreCommand("+Alex One")
assert(W:Ignored("Alex One") and not W.nearby["Alex One"] and not W:Ignored("Alex Two"))
for _,r in ipairs(W:Rows()) do assert(not r.text:find("Alex One",1,true)) end
FP.db.enemyWatch.ignore["Alex Two"]=true
for _,r in ipairs(W:Rows()) do assert(not r.text:find("Alex Two",1,true)) end
''')
REVIEW_FIX_CASES["enemy_legacy_single_name_entries_never_wildcard"] = ("", r'''
local W=FP.EnemyWatch
FP.db.enemyWatch.kos.Alex={};FP.db.enemyWatch.ignore.Sam=1
M.Enemy("nameplate1","Alex","One");M.Enemy("nameplate2","Sam","Two")
assert(not W:KOS("Alex One") and not W:Ignored("Sam Two") and W.nearby["Sam Two"])
W:KosCommand("-Alex");W:IgnoreCommand("-Sam")
assert(not FP.db.enemyWatch.kos.Alex and not FP.db.enemyWatch.ignore.Sam)
''')

REVIEW_FIX_CASES['vendor_best_value_waits_for_all_choices'] = ('', '\nlocal buttons={}\nfor i=1,3 do local b=CreateFrame("Button");b:SetID(i);b.type="choice";b:Show();buttons[i]=b end\nQuestInfoFrame={rewardsFrame={RewardButtons=buttons}}\nFP.API.GetQuestRewardValues=function() return {{type="choice",index=1,value=100},{type="choice",index=2,value=200},{type="choice",index=3,value=nil}} end\nFP.Vendor:DecorateRewards()\nlocal text=buttons[2].fpValue:GetText()\nprint("highlight="..text)\nassert(text:sub(1,#FP.GOLD)~=FP.GOLD,"best vendor choice highlighted before third choice is priced")\n')

REVIEW_FIX_CASES["reward_adapter_preserves_unknown_counts_and_quantities"] = ("", r'''
GetNumQuestChoices=function() return 3 end;GetNumQuestRewards=function() return 0 end
GetQuestItemLink=function(_,i) return "item:"..i end
local qty=2
GetQuestItemInfo=function() return "Reward",1,qty end
FP.API.GetItemValue=function(link) return tonumber(link:match("%d+"))*100 end
local rows=FP.API.GetQuestRewardValues();FP.QuestRewards:Rank({items=rows,countsKnown=rows.countsKnown})
assert(rows[3].bestVendor and rows[3].value==600)
qty=nil; rows=FP.API.GetQuestRewardValues();FP.QuestRewards:Rank({items=rows,countsKnown=rows.countsKnown})
assert(rows[3].value==nil and not rows[3].bestVendor and rows[3].count==nil)
qty=M.Secret();rows=FP.API.GetQuestRewardValues();assert(rows[1].value==nil)
qty=1;GetNumQuestRewards=function() return nil end
rows=FP.API.GetQuestRewardValues();assert(rows.countsKnown==false and #rows==3)
GetNumQuestChoices=function() return 1e99 end;rows=FP.API.GetQuestRewardValues();assert(#rows==0 and not rows.countsKnown)
''')

REVIEW_FIX_CASES['vendor_disable_removes_existing_reward_labels'] = ('', '\nlocal b=CreateFrame("Button");b:SetID(1);b.type="choice";b:Show()\nQuestInfoFrame={rewardsFrame={RewardButtons={b}}}\nFP.API.GetQuestRewardValues=function() return {{type="choice",index=1,value=100}} end\nFP.Vendor:DecorateRewards();assert(b.fpValue:IsShown())\nFP.Vendor:Command("rewards off");M.FireEvent("QUEST_DETAIL");M.RunTimers(1)\nprint("enabled="..tostring(FP.settings.vendor.rewardValues).."; old label visible="..tostring(b.fpValue:IsShown()))\nassert(not b.fpValue:IsShown(),"disabled labels survive and can label a different reused reward button")\n')

REVIEW_FIX_CASES["vendor_queued_refresh_cannot_redraw_disabled_or_stale_prices"] = ("", r'''
local b=CreateFrame("Button");b:SetID(1);b.type="choice";b:Show()
QuestInfoFrame={rewardsFrame={RewardButtons={b}}}
local price=100
FP.API.GetQuestRewardValues=function() return {countsKnown=true,{kind="choice",type="choice",index=1,value=price}} end
local V=FP.Vendor; V:DecorateRewards();assert(b.fpValue:IsShown())
V:RequestRewards();V:Command("rewards off");price=999
M.RunTimers(1);assert(not b.fpValue:IsShown() and b.fpValue:GetText()=="")
V:Command("rewards on");M.RunTimers(1);assert(b.fpValue:IsShown() and b.fpValue:GetText():find("9s 99c",1,true))
M.FireEvent("QUEST_FINISHED");assert(not b.fpValue:IsShown())
''')

REVIEW_FIX_CASES['control_sparkle_combat_off_creates_reload_fixture'] = ('M.cvars.outlineModeShowLootEffectWhenDisabled="0"', '\nlocal Q=FP.QuestSparkle\nassert(FP.db.questSparkle.ours and M.cvars.outlineModeShowLootEffectWhenDisabled=="1")\nM.combatLockdown=true;Q:Command("off")\nassert(Q.pendingOff and FP.settings.questSparkle.enabled==false and FP.db.questSparkle.ours and M.cvars.outlineModeShowLootEffectWhenDisabled=="1")\n-- Without reloading, combat end successfully restores the original setting.\nM.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED")\nassert(M.cvars.outlineModeShowLootEffectWhenDisabled=="0")\n')

REVIEW_FIX_CASES['sparkle_disabled_pending_restore_survives_reload'] = ('HearthAndHustleDB={settings={questSparkle={enabled=false}},questSparkle={ours=true}}\nM.cvars.outlineModeShowLootEffectWhenDisabled="1"', '\nprint("enabled="..tostring(FP.settings.questSparkle.enabled).."; ours="..tostring(FP.db.questSparkle.ours).."; game="..M.cvars.outlineModeShowLootEffectWhenDisabled)\nassert(M.cvars.outlineModeShowLootEffectWhenDisabled=="0","disabled pending restore was lost across reload")\n')

REVIEW_FIX_CASES["sparkle_reload_off_waits_for_combat_and_unavailable_read"] = (r'''
HearthAndHustleDB={settings={questSparkle={enabled=false}},questSparkle={ours=true}}
M.cvars.outlineModeShowLootEffectWhenDisabled="1";M.combatLockdown=true
''', r'''
local Q=FP.QuestSparkle
assert(Q.pendingOff and FP.db.questSparkle.ours and #M.cvarWrites==0)
local read=FP.API.GetLootSparkle; FP.API.GetLootSparkle=function() return nil end
M.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED")
assert(Q.pendingOff and FP.db.questSparkle.ours and #M.cvarWrites==0,"unavailable is not already off")
FP.API.GetLootSparkle=read;M.FireEvent("CVAR_UPDATE");M.RunTimers(2)
assert(not Q.pendingOff and not FP.db.questSparkle.ours and M.cvars.outlineModeShowLootEffectWhenDisabled=="0")
''')
REVIEW_FIX_CASES["sparkle_disabled_unowned_setting_is_preserved"] = (r'''
HearthAndHustleDB={settings={questSparkle={enabled=false}}}
M.cvars.outlineModeShowLootEffectWhenDisabled="1"
''', r'''
assert(#M.cvarWrites==0 and M.cvars.outlineModeShowLootEffectWhenDisabled=="1")
''')

REVIEW_FIX_CASES['xp_rate_expires_when_all_gains_are_outside_the_hour'] = ('', '\nlocal B=FP.InfoBar\nlocal now=FP.Util.Now()\nB.samples={{t=now-7200,total=0},{t=now-7000,total=10000}};B.gained=10000\nlocal rate=B:Rate();print("XP in last hour=0; displayed rate="..tostring(rate))\nassert(rate==nil or rate==0,"last-hour XP rate includes gains from two hours ago")\n')

REVIEW_FIX_CASES["xp_rate_keeps_boundary_gain_and_recovers_after_idle"] = ("", r'''
local B=FP.InfoBar;local now=FP.Util.Now()
B.samples={{t=now-7200,total=0},{t=now-4000,total=9000},{t=now-3599,total=10000},{t=now-300,total=11000}};B.gained=11000
local rate,gained,elapsed=B:Rate();assert(rate==2000 and gained==2000 and elapsed==3600)
M.RunTimers(4000);assert(B:Rate()==nil)
now=FP.Util.Now();B.gained=11100;B.samples[#B.samples+1]={t=now,total=11100}
assert(B:Rate()==100,"new gain after idle is counted against the rolling hour")
B.samples={{t=now-600,total=0},{t=now,total=1200}};B.gained=1200
assert(B:Rate()==7200,"short sessions retain the measured elapsed time")
''')
