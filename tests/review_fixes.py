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
