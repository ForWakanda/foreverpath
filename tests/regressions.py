#!/usr/bin/env python3
"""Preflight regressions run by tools/check.sh. No game/client writes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

LUA = os.environ.get("LUA", str(Path.home() / ".local/bin/lua5.1"))
BOOT = r'''
package.path = "./tests/?.lua;" .. package.path
local M = require("wowmock")
local FP = {}
for line in io.lines("ForeverPath/ForeverPath.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then
        assert(loadfile("ForeverPath/" .. line:gsub("\\", "/")))("ForeverPath", FP)
    end
end
M.FireEvent("ADDON_LOADED", "ForeverPath")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers(10)
M.RunTimers(2)
FP.Pos:Refresh(true)
local function addQuest(id, complete)
    local q = {questID=id, title="Quest " .. id, waypoint={1413, 0.60, 0.60},
        objectives={{text="Mob slain: 0/1", type="monster", numFulfilled=0, numRequired=1, finished=false}}}
    M.AddQuest(q)
    M.complete[id] = complete
    FP.Recorder.RescanLog("review")
    return q
end
local function active() return FP.Waypoints:GetActive() end
local function cmd(s) SlashCmdList.FOREVERPATH(s) end
local function snapshot(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local parts={}
    for k,v in pairs(value) do parts[#parts+1]=snapshot(k).."="..snapshot(v) end
    table.sort(parts)
    return "{"..table.concat(parts,";").."}"
end
'''

CASES = {
    "arrival_then_completion_resumes_arrow": r'''
local q = addQuest(9001)
FP.Planner:Auto("review")
M.px, M.py = 0.60, 0.60
M.Tick(1)
assert(not active(), "arrival setup failed")
q.objectives[1].finished = true
q.objectives[1].numFulfilled = 1
M.complete[9001] = true
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(1); M.RunTimers(2)
assert(active() and active().source.kind == "turnin", "objective completed after arrival: arrow remains absent")
''',
    "turnin_arrival_does_not_loop": r'''
addQuest(9001, true)
FP.Planner:Auto("review")
M.px, M.py = 0.60, 0.60
local before = FP.cdb.nextId
for i=1,5 do M.Tick(1); M.RunTimers(1.1) end
assert(FP.cdb.nextId == before, "standing at unturned-in quest creates " .. (FP.cdb.nextId-before) .. " replacement waypoints")
''',
    "manual_waypoint_survives_auto": r'''
addQuest(9001)
cmd("way 47.2 61.8 Manual")
local id = active().id
FP.Planner:Auto("accept")
assert(active().id == id, "auto-next replaced the active manual waypoint")
''',
    "reopening_loot_does_not_duplicate_items": r'''
M.lootSource = "Creature-0-1-1-1-7001-00000001"
M.lootSlots = {{name="Cloth", qty=2, itemID=4306}}
M.FireEvent("LOOT_OPENED")
M.FireEvent("LOOT_OPENED")
local c = FP.data.creatures[7001]
assert(c.loot[4306] == 2, "one corpse with two cloth became " .. c.loot[4306] .. " cloth / " .. c.looted .. " corpse")
''',
    "loot_is_attributed_per_slot_source": r'''
local a = "Creature-0-1-1-1-7001-00000001"
local b = "Creature-0-1-1-1-7002-00000002"
M.lootSlots = {{name="Cloth", qty=2, itemID=4306}, {name="Tusk", qty=1, itemID=5001}}
GetLootSourceInfo = function(slot) return slot == 1 and a or b, M.lootSlots[slot].qty end
M.FireEvent("LOOT_OPENED")
assert(FP.data.creatures[7002] and FP.data.creatures[7002].loot[5001] == 1,
    "second creature's tusk was assigned to the first creature")
''',
    "batched_progress_not_assigned_to_unrelated_last_kill": r'''
local a, b = addQuest(9001), addQuest(9002)
FP.Recorder:OnUnitDied("Creature-0-1-1-1-7001-00000001")
a.objectives[1].numFulfilled = 1
M.FireEvent("QUEST_LOG_UPDATE")
FP.Recorder:OnUnitDied("Creature-0-1-1-1-7002-00000002")
b.objectives[1].numFulfilled = 1
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(1)
assert(not (FP.data.quests[9001].obj[1].mobs or {})[7002], "both quest objectives were assigned to the last kill (7002)")
''',
    "manual_apicheck_persists_successful_probes": r'''
cmd("apicheck")
local r = FP.db.apicheck[tostring(FP.clientBuild) .. "-manual"]
assert(r.rows and r.rows["probe:playerPos"], "manual apicheck stores counts/failures but drops successful probe results")
''',
    "record_off_preserves_planner_updates": r'''
local q = addQuest(9001)
FP.Planner:Auto("review")
M.RunTimers(2) -- drain the pre-existing scan callbacks before disabling recording
cmd("record off")
q.objectives[1].finished = true
M.complete[9001] = true
M.FireEvent("QUEST_LOG_UPDATE")
M.RunTimers(1); M.RunTimers(2)
assert(active() and active().source.kind == "turnin", "record off leaves the completed quest's objective active")
''',
    "failed_party_send_is_not_reported_success": r'''
IsInGroup = function() return true end
-- Build 70124 Enum.SendAddonMessageResult.AddonMessageThrottle == 3.
C_ChatInfo.SendAddonMessage = function() return 3 end
cmd("partysync")
local chat = M.Chat()
assert(not chat[#chat]:find("sent your quest state", 1, true), "throttled send was reported as sent")
''',
    "party_import_refreshes_visible_plan": r'''
addQuest(9001)
FP.Planner:Build()
assert(not FP.Planner.steps[1].shared)
IsInGroup = function() return true end
M.SetUnit("party1", {name="Friend", realm="Realm"})
M.FireEvent("CHAT_MSG_ADDON", "FPATH", "FP1;Friend;MAGE;20;9001", "PARTY", "Friend-Realm")
assert(FP.Planner.steps[1].shared, "received quest state never refreshed the planner")
''',
    "creature_sighting_not_stored_as_exact_player_position": r'''
M.SetUnit("target", {guid="Creature-0-1-1-1-7001-00000001", name="Distant mob", level=20, reaction=2})
M.FireEvent("PLAYER_TARGET_CHANGED")
local p = FP.data.creatures[7001].pos[1]
assert(not p or p.observer or p.uncertainty, "targeting a distant mob stores player coordinates as its unqualified location")
''',
    "selftest_preserves_party_state": r'''
FP.Party:Import("FP1;Friend;HUNTER;20;9001", "paste")
FP.SelfTest:Run(true)
assert(FP.cdb.party.name == "Friend", "selftest erased the real imported party state")
''',
    "selftest_preserves_active_waypoint": r'''
local a = FP.Waypoints:Add(1413, 0.46, 0.56, "Near")
local b = FP.Waypoints:Add(1413, 0.80, 0.80, "Chosen")
FP.SelfTest:Run(true)
assert(active().id == b.id, "selftest cleared the explicit active waypoint and selected the nearest instead")
''',
}

CASES.update({
    "loot_all_source_pairs_and_quantities": r'''
M.lootSlots = {{name="Cloth", qty=15, itemID=4306}}
GetLootSourceInfo = function()
    return "Creature-0-1-1-1-7001-1",1,"Creature-0-1-1-1-7002-2",2,
        "Creature-0-1-1-1-7003-3",3,"Creature-0-1-1-1-7004-4",4,"GameObject-0-1-1-1-7005-5",5
end
M.FireEvent("LOOT_OPENED")
for i=1,4 do assert(FP.data.creatures[7000+i].loot[4306] == i) end
assert(FP.data.objects[7005].loot[4306] == 5)
''',
    "partial_loot_and_duplicate_slots": r'''
M.lootSource = "Creature-0-1-1-1-7001-1"
M.lootSlots = {{name="Cloth",qty=2,itemID=4306},{name="Cloth",qty=3,itemID=4306}}
M.FireEvent("LOOT_OPENED")
M.lootSlots = {{name="Cloth",qty=3,itemID=4306}}
M.FireEvent("LOOT_OPENED"); M.FireEvent("LOOT_OPENED")
assert(FP.data.creatures[7001].loot[4306] == 5 and FP.data.creatures[7001].looted == 1)
''',
    "unknown_loot_source_keeps_target_uncertain": r'''
GetLootSourceInfo = nil
M.SetUnit("target", {guid="Creature-0-1-1-1-7001-1",dead=true})
M.lootSlots = {{name="Cloth",qty=2,itemID=4306}}
M.FireEvent("LOOT_OPENED")
assert(not FP.data.creatures[7001])
assert(FP.data.lootObservations[1].items[4306] == 2)
assert(FP.data.lootObservations[1].attribution == "unknown")
''',
    "malformed_source_total_is_not_allocated": r'''
M.lootSlots = {{name="Cloth",qty=2,itemID=4306}}
GetLootSourceInfo = function() return "Creature-0-1-1-1-7001-1",3 end
M.FireEvent("LOOT_OPENED")
assert(not FP.data.creatures[7001] and FP.data.lootObservations[1].items[4306] == 2)
''',
    "loot_dedup_survives_full_addon_reload": r'''
M.lootSource = "Creature-0-1-1-1-7001-1"
M.lootSlots = {{name="Cloth",qty=2,itemID=4306}}
M.FireEvent("LOOT_OPENED")
M.frames, M.timers, M.tickers = {}, {}, {}
local nextFP = {}
for line in io.lines("ForeverPath/ForeverPath.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then assert(loadfile("ForeverPath/" .. line:gsub("\\", "/")))("ForeverPath", nextFP) end
end
M.FireEvent("ADDON_LOADED", "ForeverPath"); M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOOT_OPENED")
assert(nextFP.data.creatures[7001].loot[4306] == 2 and nextFP.data.creatures[7001].looted == 1)
assert(#nextFP.db.errors == 0)
''',
    "item_objective_temporal_candidate_not_confirmed": r'''
local q = addQuest(9001)
q.objectives[1].type = "item"
M.lootSource = "Creature-0-1-1-1-7001-1"
M.lootSlots = {{name="Unrelated item",qty=2,itemID=4306}}
M.FireEvent("LOOT_OPENED")
q.objectives[1].numFulfilled = 1
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1)
local ev = FP.data.progress[#FP.data.progress]
assert(ev.attribution == "unconfirmed" and not ev.src and ev.lootItems[4306] == 2)
assert(not FP.data.quests[9001].obj[1].src)
''',
    "record_off_stops_delayed_and_profession_dataset_writes": r'''
M.SetUnit("npc", {guid="Creature-0-1-1-1-7001-1", name="Trainer"})
M.FireEvent("TRAINER_SHOW")
cmd("record off")
local before = snapshot(FP.data)
M.FireEvent("TRADE_SKILL_SHOW")
M.FireEvent("PLAYER_LEVEL_UP",21)
M.FireEvent("PLAYER_DEAD")
M.FireEvent("QUEST_ACCEPTED",9999)
M.RunTimers(3)
assert(snapshot(FP.data) == before, "record off mutated dataset")
assert(FP.Prof.open and #FP.Prof.open.recipes > 0, "profession UI should still work without recording")
''',
    "record_off_at_login_does_not_collect_dataset": r'''
M.frames, M.timers, M.tickers = {}, {}, {}
ForeverPathDB = {settings={record=false}}
ForeverPathCharDB = nil
local nextFP = {}
for line in io.lines("ForeverPath/ForeverPath.toc") do
    line=line:gsub("\r", "")
    if line:match("%.lua$") then assert(loadfile("ForeverPath/" .. line:gsub("\\", "/")))("ForeverPath",nextFP) end
end
M.AddQuest({questID=9001,title="Quest",objectives={}})
M.FireEvent("ADDON_LOADED", "ForeverPath"); M.FireEvent("PLAYER_LOGIN")
M.RunTimers(10); M.RunTimers(3)
assert(next(nextFP.data.chars) == nil and next(nextFP.data.quests) == nil)
assert(nextFP.db.apicheck["70124"], "diagnostic probes should remain enabled")
''',
    "record_toggle_does_not_infer_progress_while_disabled": r'''
local q=addQuest(9001)
cmd("record off")
q.objectives[1].numFulfilled=1
cmd("record on")
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1)
assert(#FP.data.progress == 0)
''',
    "arrived_objective_waits_and_explicit_next_skips": r'''
addQuest(9001); local b=addQuest(9002); b.waypoint={1413,0.8,0.8}
FP.Planner:Auto("test"); M.px,M.py=0.6,0.6; M.Tick(1)
assert(not active() and FP.Planner.waiting.questID == 9001)
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1); M.RunTimers(200)
assert(not active(), "unchanged objective must not reactivate after timeout")
cmd("next")
assert(active() and active().source.questID == 9002)
''',
    "arrived_turnin_advances_when_turned_in": r'''
addQuest(9001,true); local b=addQuest(9002); b.waypoint={1413,0.8,0.8}
FP.Planner:Auto("test"); M.px,M.py=0.6,0.6; M.Tick(1)
assert(FP.Planner.waiting.kind == "turnin")
M.FireEvent("QUEST_TURNED_IN",9001,1200,0); M.RemoveQuest(9001)
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(2); M.RunTimers(2)
assert(active() and active().source.questID == 9002)
''',
    "manual_waypoint_before_login_replan_is_preserved": r'''
addQuest(9001)
cmd("way 47.2 61.8 Manual")
local id=active().id
M.FireEvent("QUEST_ACCEPTED",9001); M.RunTimers(2)
assert(active().id == id)
''',
    "persistent_waypoint_arrival_printed_once_until_departure": r'''
cmd("way here Home")
local count=#M.Chat()
M.Tick(1); M.RunTimers(10); M.Tick(3)
local arrivals=0
for i=count+1,#M.Chat() do if M.Chat()[i]:find("Arrived:",1,true) then arrivals=arrivals+1 end end
assert(arrivals == 1)
''',
    "party_send_success_error_lockdown": r'''
IsInGroup=function() return true end
C_ChatInfo.SendAddonMessage=function() return 0 end
assert(FP.Party:Send() == true)
for code=1,12 do C_ChatInfo.SendAddonMessage=function() return code end; assert(FP.Party:Send() == false) end
C_ChatInfo.InChatMessagingLockdown=function() return true end
assert(FP.Party:Send() == false)
''',
    "party_large_snapshot_chunks_and_reassembles": r'''
IsInGroup=function() return true end
M.SetUnit("party1",{name="Friend",realm="Realm"})
for id=100001,100040 do addQuest(id,true) end
local messages={}
C_ChatInfo.SendAddonMessage=function(_,msg) assert(#msg<=255); messages[#messages+1]=msg; return 0 end
assert(FP.Party:Send())
assert(#messages>1)
for i=#messages,1,-1 do M.FireEvent("CHAT_MSG_ADDON","FPATH",messages[i],"PARTY","Friend-Realm") end
assert(FP.Util.Count(FP.cdb.party.quests)==40 and FP.cdb.party.complete[100040])
''',
    "party_live_state_cleared_but_paste_seed_retained": r'''
IsInGroup=function() return true end
M.SetUnit("party1",{name="Friend",realm="Realm"})
M.FireEvent("CHAT_MSG_ADDON","FPATH","FP1;Friend;MAGE;20;9001","PARTY","Friend-Realm")
assert(FP.cdb.party.name=="Friend")
IsInGroup=function() return false end
M.FireEvent("GROUP_ROSTER_UPDATE")
assert(not FP.cdb.party.name)
FP.Party:Import("FP1;Seed;MAGE;20;9001","paste")
M.FireEvent("GROUP_ROSTER_UPDATE")
assert(FP.cdb.party.name=="Seed")
''',
    "party_ignores_outsiders_and_refreshes_on_completion_removal": r'''
IsInGroup=function() return true end
M.SetUnit("party1",{name="Friend",realm="Realm"})
M.FireEvent("CHAT_MSG_ADDON","FPATH","FP1;Stranger;MAGE;20;9001","WHISPER","Stranger-Realm")
assert(not FP.cdb.party.name)
local sent={}
C_ChatInfo.SendAddonMessage=function(_,msg) sent[#sent+1]=msg; return 0 end
addQuest(9001); M.RunTimers(6)
local n=#sent
M.complete[9001]=true; M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1); M.RunTimers(6)
assert(#sent>n and sent[#sent]:find("9001c",1,true))
M.RemoveQuest(9001); M.FireEvent("QUEST_REMOVED",9001); M.RunTimers(6)
assert(not sent[#sent]:find("9001",1,true))
''',
    "manual_probe_history_and_exception_are_preserved": r'''
local best=FP.API.GetBestMap
FP.API.GetBestMap=function() error("test map probe failure") end
cmd("apicheck")
local r=FP.db.apicheck["70124-manual"]
assert(r.rows["probe:bestMap"].status=="error")
assert(r.rows["probe:facing"].ok and r.rows["probe:facing"].note)
FP.API.GetBestMap=best
cmd("apicheck")
assert(FP.db.apicheck["70124-manual"].rows["probe:bestMap"].ok)
assert(#FP.db.apicheckHistory>=2)
''',
    "hearth_cooldown_reads_70170_c_spell_table_shape": r'''
local cont, item = C_Container.GetItemCooldown, C_Item and C_Item.GetItemCooldown
C_Container.GetItemCooldown = nil
if C_Item then C_Item.GetItemCooldown = nil end
local saved = C_Spell.GetItemCooldown
C_Spell.GetItemCooldown = function(id) assert(id == 6948); return { startTime = GetTime() - 100, duration = 1800, isEnabled = true, modRate = 1 } end
local remaining = FP.API.GetHearthCooldown()
assert(remaining > 1690 and remaining <= 1700, "C_Spell.GetItemCooldown table shape not read: " .. tostring(remaining))
C_Spell.GetItemCooldown = function() return nil end
assert(FP.API.GetHearthCooldown() == 0, "MayReturnNothing must read as no cooldown")
C_Spell.GetItemCooldown = saved
C_Container.GetItemCooldown = cont
if C_Item then C_Item.GetItemCooldown = item end
''',
    "selftest_preserves_all_character_data": r'''
FP.Party:Import("FP1;Friend;MAGE;20;9001","paste")
cmd("way 60 60 Test")
local before=snapshot(FP.cdb)
local ok=FP.SelfTest:Run(true)
assert(ok and snapshot(FP.cdb)==before)
''',
    "world_conversion_retries_transient_failure": r'''
local real=C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos=function() return nil end
local point={mapID=1413,x=0.6,y=0.6}
assert(not FP.Pos:DistanceTo(point))
C_Map.GetWorldPosFromMapPos=real
assert(FP.Pos:DistanceTo(point))
''',
    "map_pin_right_click_is_owned_and_removes_waypoint": r'''
cmd("way 60 60 Test")
FP.Pins.provider:RefreshAllData()
local pin=WorldMapFrame._pins[1]
assert(not pin:ShouldMouseButtonBePassthrough("RightButton") and #pin._passthrough==0)
pin:OnClick("RightButton")
assert(not active())
''',
    "waypoint_percent_validation_and_low_map_id": r'''
cmd("way 1 2 Near edge")
assert(active().x==0.01 and active().y==0.02)
cmd("way 12 45 60 Low map")
assert(active().mapID==12 and active().x==0.45 and active().y==0.6)
local n=#FP.Waypoints.list
cmd("way -10 50"); cmd("way 101 50"); cmd("way 1e309 2"); cmd("way 12 40 200")
assert(#FP.Waypoints.list==n)
assert(not FP.Waypoints:Add(12,0/0,0.5))
''',
    "craftable_yellow_not_hidden_by_unavailable_orange": r'''
FP.Prof.open={recipes={}}
for i=1,13 do FP.Prof.open.recipes[i]={id=i,name="Unavailable",diff=0,rec={reag={[1000+i]=1}}} end
FP.Prof.open.recipes[14]={id=14,name="Available",diff=1,rec={reag={[2000]=2}}}
C_Item.GetItemCount=function(id,bank) assert(not bank); return id==2000 and 4 or 0 end
local list=FP.Prof:BestCrafts(12)
assert(list[1].id==14 and list[1].craftable==2)
''',
    "profession_scan_isolates_character_learned_state": r'''
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
assert(FP.data.recipes[197].r[3839].learned==nil)
C_TradeSkillUI.GetRecipeInfo=function(id) return {recipeID=id,name="Unlearned",learned=false} end
FP.Prof:ScanRecipes()
assert(#FP.Prof.open.recipes==0)
''',
    "profession_queue_honors_close_and_record_toggle": r'''
local ids={}; for i=1,45 do ids[i]=10000+i end
C_TradeSkillUI.GetFilteredRecipeIDs=function() return ids end
FP.Prof:ScanRecipes()
assert(FP.Util.Count(FP.data.recipes[197].r)==20)
M.FireEvent("TRADE_SKILL_CLOSE")
M.RunTimers(1)
assert(FP.Util.Count(FP.data.recipes[197].r)==20)
FP.Prof:ScanRecipes()
cmd("record off")
local before=snapshot(FP.data)
M.RunTimers(2)
assert(snapshot(FP.data)==before)
''',
    "v1_migration_preserves_but_separates_biased_evidence": r'''
M.frames,M.timers,M.tickers={},{},{}
ForeverPathDB={version=1,data={creatures={[7001]={loot={[4306]=4},looted=1,pos={{m=1413,x=.5,y=.5}}}},
    quests={[9001]={obj={{mobs={[7001]=2}}},items={[4306]={[7001]=1}}}}}}
ForeverPathCharDB=nil
local nextFP={}
for line in io.lines("ForeverPath/ForeverPath.toc") do
    if line:match("%.lua$") then assert(loadfile("ForeverPath/"..line:gsub("\\","/")))("ForeverPath",nextFP) end
end
M.FireEvent("ADDON_LOADED","ForeverPath")
local c=nextFP.data.creatures[7001]
assert(c.legacyLootV1[4306]==4 and next(c.loot)==nil and c.looted==0 and c.pos[1].observer)
local q=nextFP.data.quests[9001]
assert(q.obj[1].legacyMobCandidatesV1[7001]==2 and not q.obj[1].mobs and q.legacyItemsV1)
''',
})

CASES.update({
    "unsupported_loot_source_remains_observed_unknown": r'''
M.lootSlots={{name="Box loot",qty=2,itemID=4306}}
GetLootSourceInfo=function() return "Item-0-1-1-1-7001-1",2 end
M.FireEvent("LOOT_OPENED")
assert(FP.data.lootObservations[1].items[4306]==2 and next(FP.data.creatures)==nil)
''',
    "v1_paste_seed_survives_upgrade_and_login": r'''
M.frames,M.timers,M.tickers={},{},{}
ForeverPathDB={version=1}
ForeverPathCharDB={party={name="Friend",from="paste",quests={[9001]=true},complete={}}}
local nextFP={}
for line in io.lines("ForeverPath/ForeverPath.toc") do
    if line:match("%.lua$") then assert(loadfile("ForeverPath/"..line:gsub("\\","/")))("ForeverPath",nextFP) end
end
M.FireEvent("ADDON_LOADED","ForeverPath"); M.FireEvent("PLAYER_LOGIN")
assert(nextFP.cdb.party.name=="Friend" and nextFP.cdb.party.mode=="paste")
''',
})

CASES.update({
    "auto_recovers_idle_and_reroutes_after_movement": r'''
local a=addQuest(9001); local b=addQuest(9002)
a.waypoint={1413,.60,.60}; b.waypoint={1413,.80,.80}
FP.Waypoints:RemoveBySource("plan")
FP.Panel:Toggle(false)
M.Tick(1); M.RunTimers(4)
assert(active() and active().source.questID==9001, "idle planner requires /fp next")
M.px,M.py=.78,.78
M.Tick(1); M.RunTimers(4)
assert(active() and active().source.questID==9002, "movement never reconsiders nearest quest")
''',
    "leaving_arrived_area_resumes_navigation": r'''
addQuest(9001); local b=addQuest(9002); b.waypoint={1413,.80,.80}
FP.Planner:Auto("test"); M.px,M.py=.6,.6; M.Tick(1)
assert(FP.Planner.waiting and not active())
FP.Panel:Toggle(false)
M.px,M.py=.78,.78; M.Tick(1); M.RunTimers(4)
assert(active() and active().source.questID==9002, "leaving area leaves arrow paused forever")
''',
    "active_plan_updates_changed_poi_and_progress": r'''
local a=addQuest(9001); FP.Planner:Auto("test")
a.waypoint={1413,.65,.65}; a.objectives[1].numFulfilled=1; a.objectives[1].numRequired=3
FP.Planner:Auto("test")
assert(active().x==.65 and active().title:find("1/3",1,true), "same quest keeps stale coordinates/progress")
''',
    "auto_respects_stop_off_and_explicit_selection": r'''
addQuest(9001); local b=addQuest(9002); b.waypoint={1413,.80,.80}
FP.Planner:Build(); FP.Planner:Go(FP.Planner.steps[2])
M.Tick(1); M.RunTimers(4)
assert(active().source.questID==9002, "explicit row selection overwritten")
cmd("way clear"); M.Tick(1); M.RunTimers(4)
assert(not active(), "clear immediately recreates arrow")
cmd("auto on"); assert(active())
cmd("auto off"); FP.Waypoints:RemoveBySource("plan")
M.Tick(1); M.RunTimers(4); assert(not active())
''',
    "auto_small_distance_changes_do_not_flap": r'''
local a=addQuest(9001); local b=addQuest(9002)
b.waypoint={1413,.601,.6}
FP.Planner:Auto("test"); local id=active().id
M.px,M.py=.7,.6; M.Tick(1); M.RunTimers(4)
assert(active().id==id, "tiny distance difference changes target")
''',
})

CASES.update({
    "forever_base_profession_records_recipes_and_shows_panel_help": r'''
C_TradeSkillUI.GetChildProfessionInfo=function() return {professionID=0} end
C_TradeSkillUI.GetBaseProfessionInfo=function() return {professionID=197,professionName="Tailoring",skillLevel=108,maxSkillLevel=150} end
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
assert(FP.data.recipes[197] and FP.data.recipes[197].r[3839], "Forever base profession never scanned")
assert(FP.Panel.footer:GetText():find("Recipe 3839",1,true), "profession recommendations hidden behind slash command")
''',
    "profession_delayed_loading_retries_and_close_cancels": r'''
local orig=C_TradeSkillUI.GetChildProfessionInfo
C_TradeSkillUI.GetChildProfessionInfo=function() return nil end
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(2)
C_TradeSkillUI.GetChildProfessionInfo=orig
M.RunTimers(2)
assert(FP.Prof.open and #FP.Prof.open.recipes==2, "asynchronous profession data never retried")
M.FireEvent("TRADE_SKILL_CLOSE")
FP.Prof.open=nil
M.FireEvent("TRADE_SKILL_SHOW"); M.FireEvent("TRADE_SKILL_CLOSE"); M.RunTimers(5)
assert(not FP.Prof.open, "queued scan ran after window closed")
''',
    "profession_linked_view_is_not_character_recipe_evidence": r'''
C_TradeSkillUI.IsTradeSkillLinked=function() return true end
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
assert(not FP.Prof.open and next(FP.data.recipes)==nil, "linked player recipes treated as ours")
''',
    "profession_rank_cap_and_unknown_reagents_have_honest_guidance": r'''
C_TradeSkillUI.GetChildProfessionInfo=function() return {professionID=197,professionName="Tailoring",skillLevel=150,maxSkillLevel=150} end
GetProfessionInfo=function() return "Tailoring",1,150,150,0,0,197 end
FP.Prof:ScanRecipes(); cmd("prof")
assert(M.Chat()[#M.Chat()]:find("cap",1,true), "capped profession still recommends skill-up crafts")
C_TradeSkillUI.GetRecipeSchematic=function() return {reagentSlotSchematics={{required=true,quantityRequired=1,reagents={}}}} end
assert(FP.API.GetRecipeReagents(3839)==nil, "missing reagent treated as empty known recipe")
''',
    "profession_helper_updates_for_bags_and_disabled_recipes": r'''
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
C_Item.GetItemCount=function() return 0 end
M.FireEvent("BAG_UPDATE_DELAYED"); M.RunTimers(2)
assert(FP.Panel.footer:GetText():find("Need",1,true), "bag changes did not refresh material needs")
C_TradeSkillUI.GetRecipeInfo=function(id) return {recipeID=id,name="Disabled",learned=true,relativeDifficulty=0,disabled=true} end
FP.Prof:ScanRecipes(); local list=FP.Prof:BestCrafts(12)
assert(#list==0, "disabled recipes recommended")
''',
})

CASES.update({
    "mage_cast_keeps_sent_target_identity_when_target_changes": r'''
M.SetUnit("target",{name="Enemy",player=true})
M.FireEvent("UNIT_SPELLCAST_SENT","player","Enemy","Cast-A",118)
M.SetUnit("target",{name="Boar",player=false})
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","player","Cast-A",118)
local e=FP.CastTimers.active[1]
assert(e.target=="Enemy" and e.drText=="DR full", "DR reads the new target instead of the cast target")
assert(FP.CastTimers:Lines()[1].text:find("est.",1,true), "cast estimate presented as observed effect")
''',
    "nova_does_not_invent_single_target_dr_and_missing_sent_does_not_guess": r'''
M.SetUnit("target",{name="Enemy",player=true})
M.FireEvent("UNIT_SPELLCAST_SENT","player","Enemy","Cast-N",122)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","player","Cast-N",122)
local e=FP.CastTimers.active[1]
assert(not e.target and not e.drText and not FP.CastTimers.dr.Enemy, "AoE root attributed to selected target")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","player","Cast-Unknown",118)
e=FP.CastTimers.active[2]
assert(not e.target and not e.drText, "missing cast target replaced with selected target")
''',
    "pvp_party_messages_reject_outsiders_and_invalid_durations": r'''
M.inGroup=true; M.SetUnit("party1",{name="Friend",realm="Realm"})
local function msg(body,channel,sender) M.FireEvent("CHAT_MSG_ADDON","FPATH",body,channel or "PARTY",sender or "Friend-Realm") end
msg("PT;118;Polymorph;20;Enemy;;cc","WHISPER","Stranger-Realm")
msg("PT;118;Polymorph;1e309;Enemy;;cc")
msg("PT;118;Polymorph;-20;Enemy;;cc")
assert(#FP.CastTimers.active==0 and FP.Coordination.received==0, "untrusted/invalid timer accepted")
msg("PT;118;Polymorph;20;Enemy;;cc")
assert(#FP.CastTimers.active==1 and FP.Coordination.received==1)
''',
    "quest_route_yields_to_battleground_and_recovers_after_exit": r'''
addQuest(9001); FP.Planner:Auto("test"); assert(active())
M.bg=true; FP.Planner:Auto("test")
assert(not active(), "quest arrow stays active in battleground")
M.bg=false; FP.Planner:Auto("test"); assert(active())
''',
    "bg_record_off_and_ambiguous_flag_selection": r'''
cmd("record off"); M.bg=true; M.flags={{x=.3,y=.3,tex=111},{x=.7,y=.7,tex=222}}
local before=snapshot(FP.data.bg)
FP.Battleground:Detect(); cmd("pvp track"); FP.Battleground:Scan()
assert(snapshot(FP.data.bg)==before, "battleground writes despite recording off")
assert(not active(), "first flag silently assumed to be the enemy carrier")
cmd("pvp track 2"); FP.Battleground:Scan()
assert(active() and active().x==.7)
cmd("pvp track off"); assert(not active())
''',
})

CASES.update({
    "pvp_roster_record_off_preserves_dataset_but_keeps_live_hud": r'''
M.SetUnit("target",{name="Enemy",player=true,canAttack=true,class="MAGE",race="Human",level=30})
FP.Roster:Observe("target")
cmd("record off")
local before=snapshot(FP.data.pvp)
FP.Roster:Observe("target"); FP.Roster:OnTargetDied()
assert(snapshot(FP.data.pvp)==before, "record off still writes PvP sightings/deaths")
assert(FP.Roster.session.Enemy.note=="died")
''',
})

PREP_SETUP = r'''
NUM_TOTAL_EQUIPPED_BAG_SLOTS=5
M.level=30
M.known={[759]=true,[3567]=true,[130]=true}
C_SpellBook={IsSpellKnown=function(id) return M.known[id] or false end}
M.bags={[0]={{159,12},{3772,10},{1251,5},{4540,99},{3385,2},{8079,20},{17056,1}},[5]={{17031,2}},[-1]={{159,200}}}
C_Container.GetContainerNumSlots=function(bag) assert(bag>=0 and bag<=5, "bank scanned"); return #(M.bags[bag] or {}) end
C_Container.GetContainerItemInfo=function(bag,slot) local i=M.bags[bag][slot]; return {itemID=i[1],stackCount=i[2]} end
C_Item.GetItemInfo=function(id)
    local food=id==159 or id==3772 or id==4540 or id==8079
    local class=(food or id==1251 or id==3385) and 0 or 15
    local sub=food and 5 or (id==1251 and 7 or 1)
    return "Item "..id,"link",1,1,id==8079 and 55 or 1,"type","subtype",20,"",123,0,class,sub
end
C_Item.GetItemSpell=function(id) return id==4540 and "Nourriture" or "Boisson", 430 end
local function prepRow(key)
    for _,r in ipairs(FP.MagePrep.rows or {}) do if r.key==key then return r end end
end
FP.MagePrep:Refresh()
'''
CASES.update({
    "mage_prep_counts_bags_excludes_food_potions_and_overlevel_drinks": PREP_SETUP + r'''
assert(prepRow("water").count==22 and prepRow("water").missing==18)
assert(prepRow("bandages").count==5)
assert(prepRow("reagent:17031").count==2)
assert(prepRow("reagent:17056").count==1)
assert(prepRow("gem:5514").missing==1)
assert(not prepRow("gem:5513") and not prepRow("reagent:17032") and not prepRow("reagent:17020"))
''',
    "mage_prep_updates_after_purchase_and_learning_without_dataset_writes": PREP_SETUP + r'''
cmd("record off"); local before=snapshot(FP.data)
M.bags[0][1][2]=40; M.bags[0][8]={5514,1}
M.known[11417]=true
M.FireEvent("BAG_UPDATE_DELAYED"); M.FireEvent("SPELLS_CHANGED"); M.RunTimers(1)
assert(prepRow("water").missing==0 and prepRow("gem:5514").missing==0)
assert(prepRow("reagent:17032").missing==5)
assert(snapshot(FP.data)==before)
''',
    "mage_prep_unknown_api_cache_and_spell_state_do_not_report_zero": PREP_SETUP + r'''
local original=C_Item.GetItemInfo
C_Item.GetItemInfo=function(id) if id==159 then return nil end return original(id) end
FP.MagePrep:Refresh(); assert(prepRow("water").count==nil and prepRow("water").missing==nil)
C_Item.GetItemInfo=original; M.FireEvent("GET_ITEM_INFO_RECEIVED",159,true); M.RunTimers(1)
assert(prepRow("water").count==22)
C_SpellBook.IsSpellKnown=nil; FP.MagePrep:Refresh()
assert(not prepRow("gem:5514") and not prepRow("reagent:17031"))
assert(FP.MagePrep.rows[#FP.MagePrep.rows].text:find("unavailable",1,true))
C_Container.GetContainerNumSlots=nil; FP.MagePrep:Refresh()
assert(#FP.MagePrep.rows==1 and not prepRow("water"))
''',
    "mage_prep_never_scans_inventory_or_spells_during_combat": PREP_SETUP + r'''
M.FireEvent("PLAYER_REGEN_DISABLED")
C_Container.GetContainerNumSlots=function() error("combat bag read") end
C_SpellBook.IsSpellKnown=function() error("combat spell read") end
M.FireEvent("BAG_UPDATE_DELAYED"); M.RunTimers(2)
FP.MagePrep:Refresh(); cmd("prep")
assert(#FP.MagePrep:Lines()==0)
assert(M.Chat()[#M.Chat()]:find("after combat",1,true))
''',
    "mage_prep_auto_visibility_and_user_controls": PREP_SETUP + r'''
FP.MagePrep.untilTime=0; FP.MagePrep.bg=false
assert(#FP.MagePrep:Lines()==0)
M.FireEvent("MERCHANT_SHOW"); M.RunTimers(1); assert(#FP.MagePrep:Lines()>0)
M.FireEvent("MERCHANT_CLOSED"); assert(#FP.MagePrep:Lines()==0)
M.bg=true; M.FireEvent("ZONE_CHANGED_NEW_AREA"); M.RunTimers(1); assert(#FP.MagePrep:Lines()>0)
M.bg=false; M.FireEvent("ZONE_CHANGED_NEW_AREA"); M.RunTimers(25); assert(#FP.MagePrep:Lines()==0)
cmd("prep show"); M.RunTimers(1); assert(#FP.MagePrep:Lines()>0)
cmd("prep hide"); assert(#FP.MagePrep:Lines()==0)
cmd("prep auto"); M.RunTimers(1); assert(#FP.MagePrep:Lines()>0)
cmd("prep off"); assert(#FP.MagePrep:Lines()==0)
cmd("prep on"); M.RunTimers(1); assert(#FP.MagePrep:Lines()>0)
''',
    "mage_prep_goals_are_validated_and_character_specific": PREP_SETUP + r'''
cmd("prep water 60"); M.RunTimers(1)
assert(FP.cdb.prep.water==60 and prepRow("water").missing==38)
cmd("prep water -1"); cmd("prep water 1e309"); cmd("prep water 2.5"); cmd("prep water 201")
assert(FP.cdb.prep.water==60)
cmd("prep bandages 0"); M.RunTimers(1); assert(not prepRow("bandages"))
assert(not FP.settings.prep and FP.charDefaults.prep.water==40)
''',
    "mage_prep_non_mage_is_inert": PREP_SETUP + r'''
M.class="HUNTER"; FP.MagePrep.isMage=false
C_Container.GetContainerNumSlots=function() error("Hunter inventory scanned by Mage module") end
FP.MagePrep:Refresh(); cmd("prep")
assert(#FP.MagePrep:Lines()==0)
assert(M.Chat()[#M.Chat()]:find("for Mages",1,true))
''',
    "mage_prep_probe_retains_real_counts_and_lookup_state": PREP_SETUP + r'''
cmd("apicheck")
local r=FP.db.apicheck["70124-manual"].rows["probe:magePrep"]
assert(r.ok and r.note:find("drink count 22",1,true) and r.note:find("lookup true",1,true))
''',
})

CASES.update({
    "mage_prep_adapter_combat_guard_and_read_failures_are_unknown": PREP_SETUP + r'''
InCombatLockdown=function() return true end
C_Container.GetContainerNumSlots=function() error("must not read bags") end
local inv,why=FP.API.GetPrepInventory()
assert(not inv and why:find("combat",1,true))
InCombatLockdown=function() return false end
inv,why=FP.API.GetPrepInventory(); assert(not inv and why:find("unavailable",1,true))
''',
    "mage_prep_does_not_override_pvp_hide_or_off": PREP_SETUP + r'''
cmd("pvp hide"); cmd("prep show"); M.RunTimers(2)
assert(not FP.PvP.frame:IsShown() and FP.settings.pvp.manual=="hide")
cmd("pvp off"); cmd("prep on"); M.RunTimers(2)
assert(not FP.PvP.frame:IsShown() and not FP.settings.pvp.enabled)
cmd("pvp on"); cmd("pvp auto"); M.RunTimers(2)
assert(FP.PvP.frame:IsShown())
''',
})

failed = 0
for name, body in CASES.items():
    result = subprocess.run([LUA, "-"], input=BOOT + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + result.stderr.splitlines()[0])

# Corrupt an actual XML file in an ephemeral copy; never change the real checkout.
with tempfile.TemporaryDirectory(prefix="foreverpath-gate-review-") as tmp:
    for name in ("ForeverPath", "tests", "tools"):
        shutil.copytree(name, Path(tmp) / name)
    (Path(tmp) / "ForeverPath/Nav/MapPins.xml").write_text("<Ui><broken></Ui>\n")
    result = subprocess.run(["bash", "tools/check.sh"], cwd=tmp, text=True, capture_output=True)
    assert "BAD XML" in result.stdout, "XML corruption was not exercised"
    if result.returncode == 0:
        failed += 1
        print("FAIL deployment_gate_rejects_malformed_xml")
        print("  BAD XML printed, mock reports ALL CHECKS PASSED, check.sh exits 0")
    else:
        print("PASS deployment_gate_rejects_malformed_xml")

# Missing TOC entries, compiler failure, and bypass attempts must also reject.
for scenario in ("missing_toc_file", "compiler_failure", "deploy_bypass"):
    with tempfile.TemporaryDirectory(prefix="foreverpath-gate-review-") as tmp:
        for name in ("ForeverPath", "tests", "tools"):
            shutil.copytree(name, Path(tmp) / name)
        env = os.environ.copy()
        command = ["bash", "tools/check.sh"]
        if scenario == "missing_toc_file":
            with (Path(tmp) / "ForeverPath/ForeverPath.toc").open("a") as toc:
                toc.write("Missing.xml\n")
        elif scenario == "compiler_failure":
            env["LUAC"] = "/bin/false"
        else:
            addons = Path(tmp) / "AddOns"
            addons.mkdir()
            sentinel = addons / "ForeverPath"
            sentinel.mkdir()
            (sentinel / "keep.txt").write_text("unchanged")
            env["WOW_ADDONS"] = str(addons)
            command = ["bash", "tools/deploy.sh", "--no-check"]
        result = subprocess.run(command, cwd=tmp, env=env, text=True, capture_output=True)
        passed = result.returncode != 0
        if scenario == "deploy_bypass":
            passed = passed and (sentinel / "keep.txt").read_text() == "unchanged"
        print(("PASS " if passed else "FAIL ") + scenario)
        if not passed:
            failed += 1

print(f"{failed} failed / {len(CASES) + 4} preflight regressions")
raise SystemExit(1 if failed else 0)
