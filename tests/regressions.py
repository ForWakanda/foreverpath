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
    "dungeon_catalog_integrity_and_all_panels": r"""
local D,P=FP.Dungeons,FP.DungeonPanel
local before=snapshot(FP.Waypoints.list)
local count, populated=0,0
for _,item in ipairs(D:List()) do
    count=count+1
    local seen={}
    for _,id in ipairs(item.data.quests) do
        assert(not seen[id], "duplicate dungeon row"); seen[id]=true
        local q=FP.DungeonCatalog.quests[id]
        assert(q and type(q.name)=="string" and type(q.pickup)=="table", "incomplete catalogue record")
    end
    if #item.data.quests>0 then populated=populated+1 end
    P:Open(item.key)
    for page=1,math.max(1,math.ceil(#P.rows/6)) do
        P.questPage=page; P:Refresh()
        for _,b in ipairs(P.questButtons) do
            if b.row then b:GetScript("OnClick")(b); assert(P.details:GetText():find("Pickup:",1,true)) end
        end
    end
end
assert(count==35 and populated==30, "catalogue coverage count changed")
assert(snapshot(FP.Waypoints.list)==before, "browsing changed the active route")
assert(#FP.db.errors==0)
""",
    "dungeon_checklist_live_lifecycle_without_commands": r"""
local D,P=FP.Dungeons,FP.DungeonPanel
FP.Panel.dungeons:GetScript("OnClick")()
assert(P.frame:IsShown())
P:Select("ragefire-chasm")
local function status(id) for _,r in ipairs(P.rows) do if r.id==id then return r.code end end end
assert(status(5761)=="pickup")
addQuest(5761); M.FireEvent("QUEST_ACCEPTED",5761); M.RunTimers(1)
assert(status(5761)=="active")
M.complete[5761]=true; M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1)
assert(status(5761)=="ready")
M.RemoveQuest(5761); M.FireEvent("QUEST_REMOVED",5761); M.RunTimers(1)
assert(status(5761)=="pickup", "abandon was mistaken for turn-in")
C_QuestLog.IsQuestFlaggedCompleted=function(id) return id==5761 end
M.FireEvent("QUEST_TURNED_IN",5761); M.RunTimers(1)
assert(status(5761)=="done")
assert(P.counts.done==1 and #FP.db.errors==0)
""",
    "dungeon_prerequisites_any_all_active_optional_and_unknown": r"""
local D=FP.Dungeons
local states={}
local ctx={char={faction="Horde",class="SHAMAN",level=60},offers={}}
function ctx:State(id) return states[id] or {onQuest=false,completed=false} end
assert(D:Gate({relationship="breadcrumb",questID=1},ctx)==true)
assert(D:Gate({relationship="required",anyOf={1,2}},ctx)==false)
states[2]={completed=true,onQuest=false}
assert(D:Gate({relationship="required",anyOf={1,2}},ctx)==true)
assert(D:Gate({relationship="required",questID=2,state="active"},ctx)==false)
states[2].onQuest=true
assert(D:Gate({relationship="required",questID=2,state="active"},ctx)==true)
states[1]={}
assert(D:Gate({relationship="required",questID=1},ctx)==nil)
assert(D:Gate({relationship="required",note="Unknown chain"},ctx)==nil)
assert(D:Gate({relationship="required",anyOf={1,3}},ctx)==nil)
local q=FP.DungeonCatalog.quests[5761]
q.prerequisites={{relationship="required",anyOf={1,2}},{relationship="required",questID=3}}
assert(D:Evaluate(5761,ctx)=="prereq", "separate gates must be ANDed")
states[3]={completed=true}
assert(D:Evaluate(5761,ctx)=="pickup")
q.prerequisites={{relationship="required",questID=1}}
assert(D:Evaluate(5761,ctx)=="unknown")
q.prerequisites={{relationship="required",questID=5761}}
local text=D:Details({id=5761,quest=q,color="",label="Missing"},ctx)
assert(#text<3000, "cyclic prerequisite details did not terminate")
""",
    "dungeon_unknown_apis_and_secret_flags_do_not_become_missing": r"""
local D=FP.Dungeons
C_QuestLog.IsOnQuest=function() return M.Secret() end
C_QuestLog.IsComplete=function() error("unavailable") end
C_QuestLog.IsQuestFlaggedCompleted=nil
local s=FP.API.GetDungeonQuestState(5761)
assert(s.onQuest==nil and s.ready==nil and s.completed==nil)
FP.DungeonPanel:Open("ragefire-chasm")
for _,r in ipairs(FP.DungeonPanel.rows) do assert(r.code=="unknown") end
C_QuestLog.IsOnQuest=function() return true end
assert(D:Evaluate(5761,D:Context())=="active", "known active state should survive missing completion API")
assert(#FP.db.errors==0)
""",
    "dungeon_filters_live_offers_and_actual_log_override_reference": r"""
local D=FP.Dungeons
local ctx={char={faction="Alliance",class="MAGE",level=1},offers={}}
function ctx:State(id) return {onQuest=false,completed=false,ready=false} end
local rows,counts=D:Rows("ragefire-chasm",false,ctx)
assert(#rows==0 and counts.hidden==8)
assert(#D:Rows("ragefire-chasm",true,ctx)==8)
assert(D:Evaluate(5761,ctx)=="restricted")
ctx.offers[5761]={questID=5761}
assert(D:Evaluate(5761,ctx)=="offer", "live offer must override faction and level reference")
ctx.offers={}
function ctx:State(id) return {onQuest=id==5761,completed=false,ready=false} end
rows,counts=D:Rows("ragefire-chasm",false,ctx)
assert(#rows==1 and rows[1].code=="active")
assert(D:Restriction({classes={"WARLOCK"}},ctx.char)=="WARLOCK only")
assert(not D:Restriction({classes={"MAGE"}},ctx.char))
ctx.char.faction=nil; ctx.char.class=nil
assert(not D:Restriction({faction="Horde",classes={"WARLOCK"}},ctx.char), "unknown character must not hide quests")
""",
    "dungeon_paging_filter_empty_coverage_and_persistence": r"""
local P=FP.DungeonPanel
cmd("dungeon blackrock depths")
assert(P.settings.selected=="blackrock-depths" and #P.rows>6)
P.questNext:GetScript("OnClick")(); assert(P.questPage==2)
local last=P.questButtons[1].row.id
P.questButtons[1]:GetScript("OnClick")(P.questButtons[1]); assert(P.selectedQuest==last)
P.filter:GetScript("OnClick")(); assert(P.settings.all and P.questPage==1)
P.frame:Hide(); P:Open(); assert(P.settings.selected=="blackrock-depths" and P.settings.all)
P:Select("the-drowned-city")
assert(P.summary:GetText():find("Coverage missing",1,true))
assert(P.details:GetText():find("does not mean it has no quests",1,true))
P:Select("ragefire-chasm")
P.selectedQuest=5722; P:RefreshDetails(true)
assert(P.details:GetText():find("Conflicting reports",1,true))
assert(P.scroll._scrollY==0 and #FP.db.errors==0)
""",
    "dungeon_list_refresh_does_not_require_recorder_or_steal_navigation": r"""
cmd("record off")
cmd("way 55 66 Dungeon group meeting")
local before=snapshot(FP.Waypoints.list)
FP.DungeonPanel:Open("wailing")
assert(FP.DungeonPanel.settings.selected=="wailing-caverns")
addQuest(1486); M.FireEvent("QUEST_ACCEPTED",1486); M.RunTimers(1)
local found=false
for _,r in ipairs(FP.DungeonPanel.rows) do if r.id==1486 then found=r.code=="active" end end
assert(found and snapshot(FP.Waypoints.list)==before)
FP.DungeonPanel.frame:Hide()
local old=FP.DungeonPanel.rows
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(1)
assert(FP.DungeonPanel.rows==old, "closed panel should not rescan catalogue")
""",

    "normal_questing_needs_no_commands": r'''
FP.Panel:Toggle(false)
local q=addQuest(9001)
M.Tick(4)
assert(active() and active().source.questID==9001 and FP.Arrow.frame:IsShown())
FP.Arrow.frame:Hide(); M.Tick(4)
assert(FP.Arrow.frame:IsShown(), "normal tick did not recover display")
M.px,M.py=.6,.6; M.Tick(1)
assert(FP.Planner.waiting and FP.Arrow.frame:IsShown())
FP.Arrow.frame:Hide(); M.Tick(4)
assert(FP.Arrow.frame:IsShown(), "waiting state did not recover display")
q.objectives[1].finished=true; M.complete[9001]=true; q.waypoint={1413,.7,.7}
M.FireEvent("QUEST_LOG_UPDATE"); M.RunTimers(2); M.Tick(4)
assert(active().source.kind=="turnin")
M.px,M.py=.7,.7; M.Tick(1)
assert(FP.Planner.waiting.kind=="turnin" and FP.Arrow.frame:IsShown())
M.RemoveQuest(9001)
C_QuestLine={GetAvailableQuestLines=function() return {{questID=9002,questName="Next quest",x=.8,y=.8}} end}
M.FireEvent("QUEST_TURNED_IN",9001,100,0); M.Tick(4)
assert(active().source.kind=="pickup" and active().source.questID==9002)
M.px,M.py=.8,.8; M.Tick(1)
assert(FP.Planner.waiting.kind=="pickup")
local nextQuest=addQuest(9002); nextQuest.waypoint={1413,.9,.9}
M.FireEvent("QUEST_ACCEPTED",9002); M.Tick(4)
assert(active().source.kind=="objective" and active().source.questID==9002)
M.Tick(31)
assert(FP.db.navigation.active.source.questID==9002 and FP.db.navigation.arrowShown)
assert(not FP.Panel.frame:IsShown(), "automatic guidance must work with the panel closed")
''',
    "missing_coordinates_show_status_then_recover_automatically": r'''
local q=addQuest(9001); q.waypoint=nil
M.Tick(4)
assert(not active() and FP.Arrow.frame:IsShown())
assert(FP.Arrow.title:GetText()=="Quest directions unavailable" and not FP.Arrow.tex:IsShown())
M.pois={{questID=9001,x=.7,y=.7,isQuestStart=false}}
M.Tick(4)
assert(active().source.questID==9001 and FP.Arrow.tex:IsShown())
FP.settings.arrow.shown=false; M.Tick(4)
assert(not FP.Arrow.frame:IsShown(), "respect deliberate hide")
FP.settings.arrow.shown=true; FP.Waypoints:Clear(); M.Tick(4)
assert(not FP.Arrow.frame:IsShown() and not active(), "respect deliberate stop")
''',

    "quest_pickups_follow_client_offers_then_acceptance": r'''
M.pois = {{questID=9100,x=.55,y=.55,isQuestStart=true}, {questID=9101,x=.65,y=.65,isQuestStart=false}}
C_QuestLine = {GetAvailableQuestLines=function() return {
    {questID=9100,questName="Nearby pickup",x=.55,y=.55},
    {questID=9102,questName="Hidden",x=.6,y=.6,isHidden=true},
    {questID=9103,questName="Already working",x=.6,y=.6,inProgress=true},
    {questID=9104,questName="Bad coords",x=2,y=.6},
    {questID=9105,questName="Done",x=.6,y=.6},
} end}
C_QuestLog.IsQuestFlaggedCompleted=function(id) return id==9105 end
FP.Planner:Auto("test")
assert(#FP.Planner.steps==1 and active().source.kind=="pickup" and active().source.questID==9100)
assert(active().title=="Pick up: Nearby pickup")
M.px,M.py=.55,.55; M.Tick(1)
assert(not active() and FP.Planner.waiting.kind=="pickup" and FP.Arrow.frame:IsShown())
FP.Planner:Auto("test"); assert(not active(), "pickup arrival must wait for acceptance")
addQuest(9100); FP.Planner:CheckActive()
assert(active() and active().source.kind=="objective", "accepted offer did not become objective")
assert(#FP.Planner.steps==1)
''',
    "pickup_deferral_expiry_and_missing_apis": r'''
C_QuestLine={GetAvailableQuestLines=function() return {{questID=9100,x=.55,y=.55}} end}
cmd("pickups"); assert(active().source.kind=="pickup")
cmd("skip 1"); FP.Planner:Auto("test"); assert(not active())
M.now=M.now+61; FP.Planner:Auto("test"); assert(active().source.questID==9100)
C_QuestLine.GetAvailableQuestLines=function() error("unavailable") end
FP.Planner:Auto("test"); assert(not active(), "vanished offer must stop routing")
C_QuestLine=nil; C_QuestLog.GetQuestsOnMap=nil
assert(#FP.API.GetQuestOffers(M.mapID)==0)
assert(#FP.db.errors==0)
''',
    "selected_quest_priority_and_manual_override": r'''
local a=addQuest(9001); a.waypoint={1413,.46,.56}
local b=addQuest(9002); b.waypoint={1413,.8,.8}
C_SuperTrack={GetSuperTrackedQuestID=function() return 9002 end}
FP.Planner:Auto("test"); assert(active().source.questID==9002)
cmd("goto 9001"); FP.Planner:Auto("test"); assert(active().source.questID==9001)
M.FireEvent("SUPER_TRACKING_CHANGED"); assert(active().source.questID==9002)
cmd("way 80 80 manual"); M.FireEvent("SUPER_TRACKING_CHANGED")
assert(active().title=="manual")
''',
    "arrived_indicator_stays_visible_then_clears": r'''
addQuest(9001); FP.Planner:Auto("test")
M.px,M.py=.6,.6; M.Tick(1)
assert(FP.Planner.waiting and not active() and FP.Arrow.frame:IsShown())
FP.Arrow:OnUpdate(.1)
assert(FP.Arrow.dist:GetText():find("Objective area",1,true))
cmd("way clear"); assert(not FP.Arrow.frame:IsShown())
cmd("guide"); assert(FP.Arrow.frame:IsShown() and FP.Panel.frame:IsShown())
M.Tick(1); FP.API.InBattleground=function() return true end; FP.Planner:Auto("bg")
assert(not FP.Arrow.frame:IsShown())
''',
    "map_specific_waypoint_fallback_and_invalid_points": r'''
local q=addQuest(9001); q.waypoint={0,0,0}
C_QuestLog.GetNextWaypointForMap=function(id,m) return .7,.8 end
FP.Planner:Auto("test")
assert(active() and active().x==.7 and active().y==.8)
q.waypoint=nil; C_QuestLog.GetNextWaypointForMap=function() return -1,2 end
M.pois={{questID=9001,x=2,y=.5}}
FP.Planner:Auto("test"); assert(not active())
''',
    "navigation_snapshot_captures_actual_ui_and_quests": r'''
cmd("apicheck")
assert(#FP.db.errors==0, "empty navigation snapshot throws")
addQuest(9001); cmd("guide"); cmd("apicheck")
local check=FP.db.apicheck["70124-manual"]
assert(check.navigation.active.source.questID==9001)
assert(check.rows["probe:navigationUI"].ok and #check.navigation.quests==1)
FP.Arrow.OnUpdate=function() error("render failure fixture") end
FP.Arrow.frame:GetScript("OnUpdate")(FP.Arrow.frame,.1)
assert(FP.db.errors[#FP.db.errors].where=="arrow-render")
FP.db.errors={} -- the deliberate rendering failure was captured above
''',

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
    "way_shortcut_decimal_coordinates_and_manual_priority": r'''
assert(SLASH_FOREVERPATHWAY1 == "/way")
SlashCmdList.FOREVERPATHWAY("45.4 70.4")
local wp=active()
assert(wp and wp.mapID==1413)
assert(math.abs(wp.x-.454)<1e-12 and math.abs(wp.y-.704)<1e-12)
addQuest(9001); M.RunTimers(4)
assert(active().id==wp.id, "auto route replaced /way target")
SlashCmdList.FOREVERPATHWAY("45.4 70.4 Quest cave")
assert(active().title=="Quest cave")
cmd("way 45.4 70.4 Quest cave")
assert(active().mapID==wp.mapID and active().x==wp.x and active().y==wp.y)
''',
    "way_shortcut_map_edges_and_invalid_input": r'''
SlashCmdList.FOREVERPATHWAY("12 45.4 70.4 Other zone")
assert(active().mapID==12 and active().title=="Other zone")
SlashCmdList.FOREVERPATHWAY("0 100 Map edge")
assert(active().x==0 and active().y==1)
SlashCmdList.FOREVERPATHWAY("0.5 1 Near edge")
assert(active().x==.005 and active().y==.01)
local n=#FP.Waypoints.list
for _, input in ipairs({"-1 70.4", "45.4 100.1", "1e309 70.4", "45.4", "foo bar", "12 45.4 101"}) do
    SlashCmdList.FOREVERPATHWAY(input)
end
assert(#FP.Waypoints.list==n)
assert(#(FP.db.errors or {})==0)
''',
    "way_shortcut_management_commands": r'''
SlashCmdList.FOREVERPATHWAY("45.4 70.4 First")
local first=active().id
SlashCmdList.FOREVERPATHWAY("46 71 Second")
SlashCmdList.FOREVERPATHWAY("next")
assert(active().id==first)
SlashCmdList.FOREVERPATHWAY("rm "..first)
assert(not FP.Waypoints:Get(first))
SlashCmdList.FOREVERPATHWAY("clear")
assert(#FP.Waypoints.list==0)
SlashCmdList.FOREVERPATHWAY("here Home")
assert(active().title=="Home" and active().persistent)
SlashCmdList.FOREVERPATHWAY("")
assert(#(FP.db.errors or {})==0)
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
assert(table.concat((function() local t={} for _,r in ipairs(FP.MagePrep.rows) do t[#t+1]=r.text end return t end)(), " "):find("spells unavailable",1,true))
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
    "class_prep_unsupported_class_is_inert": PREP_SETUP + r'''
M.class="WARRIOR"; FP.MagePrep.isMage=false
C_Container.GetContainerNumSlots=function() error("Unsupported class inventory scanned") end
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

CASES.update({
    "rare_watch_only_inside_watched_instance_and_secret_safe": r"""
local RW = FP.RareWatch
-- Barrens: a rare target with a readable name is not a watched sighting
M.SetUnit("target", { guid = "Creature-0-4379-1-13-5842-00003BB8E0", name = "Takk the Leaper", level = 19, reaction = 2, classification = "rare" })
M.FireEvent("PLAYER_TARGET_CHANGED")
assert(RW:Current() == nil, "no run outside an instance")
-- an unwatched dungeon: no run, no hud
M.instance = { name = "The Deadmines", mapID = 36 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(not RW.inside and RW:Current() == nil and not RW.frame:IsShown(), "Deadmines is not watched")
-- watched dungeon, secret everything on a normal mob: silent; on a rare: sighting without touching the secret
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW.inside and RW:Current(), "run opened")
M.SetUnit("mouseover", { secret = true, level = 31, reaction = 2, classification = "elite" })
M.FireEvent("UPDATE_MOUSEOVER_UNIT")
assert(not RW:Current().seen, "elite trash is not a rare")
M.SetUnit("nameplate3", { secret = true, level = 33, reaction = 2, classification = "rareelite", ctype = "Undead" })
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
local run = RW:Current()
assert(run.seen and run.sightings[1].how == "nameplate" and run.sightings[1].cls == "rareelite" and run.sightings[1].secret == 1, "rare elite via nameplate")
assert(run.seenName == nil and run.seenID == nil, "secret identity is never stored")
-- a friendly rare (reaction 5) is not a hunt target
M.SetUnit("party1target", { secret = true, level = 60, reaction = 5, classification = "rare" })
M.FireEvent("UNIT_TARGET", "party1")
assert(#run.sightings == 1, "friendly rare ignored")
-- with recording off the rare watch still works (it is live information, not dataset)
cmd("record off")
M.SetUnit("target", { secret = true, level = 33, reaction = 2, classification = "rare" })
M.FireEvent("PLAYER_TARGET_CHANGED")
assert(#run.sightings == 2, "sighting recorded with dataset recording off")
assert(FP.data.creatures[6490] == nil, "no creature identity invented in the dataset")
""",
    "rare_watch_runs_key_by_loot_and_merge_on_reentry": r"""
local RW = FP.RareWatch
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.lootSlots = { { name = "Linen Cloth", qty = 1, itemID = 2589 } }
M.lootSource = "Creature-0-4379-189-1001-4295-00003BB9A1"
M.FireEvent("LOOT_OPENED", false, false)
assert(RW:Current().key == "1001" and FP.db.rare.order[1] == "1001" and #FP.db.rare.order == 1, "keyed by zoneUID")
-- walk out and back in without a reset: same run
M.instance = nil; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.instance = { name = "Scarlet Monastery", mapID = 189 }; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW:Current().key:find("^visit%-") and #FP.db.rare.order == 2, "re-entry from outside opens a provisional run")
M.lootSource = "Creature-0-4379-189-1001-4295-00003BB9A9"
M.FireEvent("LOOT_OPENED", false, false)
assert(RW:Current().key == "1001" and #FP.db.rare.order == 1 and RW:Current().visits == 2, "same-instance loot folds the visit back")
-- the partner reset it while we were outside: a different zoneUID starts a new run
M.lootSource = "Creature-0-4379-189-1002-4295-00003BB9A2"
M.FireEvent("LOOT_OPENED", false, false)
assert(RW:Current().key == "1002" and #FP.db.rare.order == 2 and FP.db.rare.runs["1001"].closedWhy == "superseded", "new zoneUID starts a new run")
-- scan counts, then reset, re-enter, loot proves it is the SAME instance again (merge, no third run)
RW:AfterScan()
assert(RW:Current().scans == 1, "scan counted")
M.FireEvent("CHAT_MSG_SYSTEM", "Scarlet Monastery has been reset.", "", "", "")
assert(RW:Current() == nil, "closed on reset")
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(#FP.db.rare.order == 3 and RW:Current().key:find("^visit%-"), "provisional third run")
RW:AfterScan()
M.lootSource = "Creature-0-4379-189-1002-4295-00003BB9A3"
M.FireEvent("LOOT_OPENED", false, false)
assert(#FP.db.rare.order == 2 and RW:Current().key == "1002" and RW:Current().scans == 2 and RW:Current().visits == 2, "provisional visit folded into the known instance")
local st = RW:Stats()
assert(st.runs == 2 and st.checked == 1 and st.scans == 2, string.format("stats runs %d checked %d scans %d", st.runs, st.checked, st.scans))
assert(RW.IsResetMessage("Scarlet Monastery has been reset.") == "Scarlet Monastery" and not RW.IsResetMessage("Scarlet Monastery cannot be reset."), "reset message parse")
""",
    "rare_watch_scan_button_is_a_macro_and_defers_in_combat": r"""
local RW = FP.RareWatch
assert(RW.scan:GetAttribute("type") == "macro", "secure macro button")
assert(RW.scan._clicks[1] == "AnyUp" and RW.scan._clicks[2] == "AnyDown", "click registration")
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW.scan:IsShown(), "scan visible inside")
-- combat: watch-list edits must not touch secure attributes until combat ends
M.combatLockdown = true
cmd("rare add 1234 Test Rare")
assert(RW.macroPending and not RW.scan:GetAttribute("macrotext"):find("Test Rare"), "macro change deferred in combat")
M.combatLockdown = false
M.FireEvent("PLAYER_REGEN_ENABLED")
assert(not RW.macroPending and RW.scan:GetAttribute("macrotext"):find("/targetexact Test Rare$"), "macro applied after combat")
-- hiding/showing the protected button is also deferred
M.combatLockdown = true
M.instance = nil; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW.scan:IsShown() and RW.scanPending and not RW.frame:IsShown(), "scan button untouched in combat; hud itself hidden")
M.combatLockdown = false
M.FireEvent("PLAYER_REGEN_ENABLED")
assert(not RW.scan:IsShown(), "scan button hidden once combat ends")
cmd("rare rm Test Rare")
assert(#FP.db.rareWatch.rares == 3, "watch list restored")
-- scan with the rare already targeted counts as a hit; without, as a miss
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
RW:AfterScan()
assert(RW:Current().scans == 1 and RW:Current().lastMiss and not RW:Current().seen, "miss recorded")
M.SetUnit("target", { secret = true, level = 33, reaction = 2, classification = "rare" })
RW:AfterScan()
assert(RW:Current().scans == 2 and RW:Current().seen and RW:Current().sightings[1].how == "scan", "hit via scan")
""",
    "rare_watch_party_messages_reject_outsiders_and_malformed": r"""
local RW = FP.RareWatch
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.inGroup = true
M.SetUnit("party1", { guid = "Player-4-0A1B2C3E", name = "Hunterbro", player = true })
M.FireEvent("CHAT_MSG_ADDON", "FPATH", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Stranger")
assert(not RW:Current().seen, "outsider ignored")
M.FireEvent("CHAT_MSG_ADDON", "OTHER", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Hunterbro")
assert(not RW:Current().seen, "other prefix ignored")
for _, bad in ipairs({ "RW;up", "RW;up;33", "RW;bogus;1", "RW;kill;x", "RW;no;extra", "RW;up;" .. string.rep("x", 200) }) do
	assert(RW:Decode(bad) == nil, "malformed accepted: " .. bad)
end
assert(RW:Decode("RW;up;;;") and RW:Decode("RW;up;;;").level == nil, "empty fields decode")
local sent = #M.addonSent
M.FireEvent("CHAT_MSG_ADDON", "FPATH", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Hunterbro")
assert(RW:Current().seen and RW:Current().seenName == "Azshir the Sleepless" and RW:Current().sightings[1].by == "Hunterbro", "party sighting applied")
assert(#M.addonSent == sent, "received sighting is not re-broadcast")
-- name sanitising on send
assert(RW:Encode("up", { level = 33, creatureType = "Undead", name = "Bad;Name|r" }) == "RW;up;33;Undead;BadNamer", "separators stripped")
-- sharing off: no broadcast on our own sighting
cmd("rare share off")
M.FireEvent("CHAT_MSG_SYSTEM", "Scarlet Monastery has been reset.", "", "", "")
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.SetUnit("target", { secret = true, level = 33, reaction = 2, classification = "rare" })
M.FireEvent("PLAYER_TARGET_CHANGED")
assert(RW:Current().seen and #M.addonSent == sent, "share off: nothing sent")
""",
})

CASES.update({
    "rare_hud_layout_survives_secret_measurements": r"""
local RW = FP.RareWatch
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.SetUnit("target", { secret = true, level = 33, reaction = 2, classification = "rare" })
M.FireEvent("PLAYER_TARGET_CHANGED"); M.RunTimers(1)
assert(RW.nameShown, "secret name shown")
-- the client may hand back a secret height for any row; the layout must not throw
local real = RW.detail.GetStringHeight
RW.detail.GetStringHeight = function() return M.Secret() end
RW:Refresh()
assert(FP.db.rare.secretLayout and FP.db.rare.secretLayout.detail == 1, "secret measurement counted")
assert(RW.frame:GetHeight() >= 96, "frame still sized")
RW.detail.GetStringHeight = real
RW:Refresh()
assert(FP.db.rare.secretLayout.detail == 1 and not FP.db.rare.secretLayout.name, "name row is never measured")
""",
})

CASES.update({
    "rare_watch_hunter_pet_guid_keys_the_run_on_entry": r"""
local RW = FP.RareWatch
-- a pet summoned on another map must not key the run
M.SetUnit("partypet1", { guid = "Pet-0-4379-1-13-417-00003BB9A0", name = "Bigcow", player = false })
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW:Current().key:find("^visit%-") and not RW:Current().petZone, "foreign-map pet ignored")
-- the pet re-summons inside: keyed before any loot
M.SetUnit("partypet1", { guid = "Pet-0-4379-189-182404-417-00003BB9A1", name = "Bigcow", player = false })
M.RunTimers(7)
assert(RW:Current().key == "182404" and RW:Current().uidSource == "pet" and RW:Current().petZone == "182404", "pet zoneUID keys the run: " .. tostring(RW:Current().key))
-- loot from the same instance agrees; nothing changes
M.lootSlots = { { name = "Linen Cloth", qty = 1, itemID = 2589 } }
M.lootSource = "Creature-0-4379-189-182404-4295-00003BB9A1"
M.FireEvent("LOOT_OPENED", false, false)
assert(RW:Current().key == "182404" and #FP.db.rare.order == 1, "loot agrees with the pet key")
-- after a reset the pet carries the new zoneUID: new run without looting
M.FireEvent("CHAT_MSG_SYSTEM", "Scarlet Monastery has been reset.", "", "", "")
M.SetUnit("partypet1", { guid = "Pet-0-4379-189-182500-417-00003BB9A2", name = "Bigcow", player = false })
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW:Current().key == "182500" and #FP.db.rare.order == 2, "new run keyed from the pet after reset")
""",
})

CASES.update({
    "rare_watch_reentry_from_outside_starts_fresh_but_merges_same_instance": r"""
local RW = FP.RareWatch
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.SetUnit("partypet1", { guid = "Pet-0-4379-189-182404-417-00003BB9A1", name = "Bigcow", player = false })
M.RunTimers(7)
M.lootSlots = { { name = "Ghostshard Talisman", qty = 1, itemID = 7716 } }
M.lootSource = "Creature-0-4379-189-182404-6490-00003BB9F0"
M.FireEvent("LOOT_OPENED", false, false)
assert(RW:Current().key == "182404" and RW:Current().kills[6490] == 1, "killed in run 182404")
-- /reload inside the instance keeps the run
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(RW:Current().key == "182404" and #FP.db.rare.order == 1, "reload inside keeps the run")
-- partner resets while we are outside: no system message here, pet carries the new id
M.instance = nil; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.SetUnit("partypet1", { guid = "Pet-0-4379-189-182500-417-00003BB9A2", name = "Bigcow", player = false })
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
local run = RW:Current()
assert(run.key == "182500" and not next(run.kills) and #FP.db.rare.order == 2 and FP.db.rare.runs["182404"].closedWhy == "left", "fresh run after re-entry: " .. tostring(run.key))
M.RunTimers(1)
assert(not RW.status:GetText():find("KILLED"), "hud no longer says killed: " .. tostring(RW.status:GetText()))
-- walking out and back into the SAME instance (no reset) folds the visit back, kill intact
M.lootSource = "Creature-0-4379-189-182500-6489-00003BB9F1"
M.FireEvent("LOOT_OPENED", false, false)
M.instance = nil; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.instance = { name = "Scarlet Monastery", mapID = 189 }
M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
M.RunTimers(7)
assert(RW:Current().key == "182500" and RW:Current().kills[6489] == 1 and #FP.db.rare.order == 2, "same instance merges back with its kill")
""",
})


CASES.update({
    "shaman_supplies_no_mage_gems_and_hunter_preserved": PREP_SETUP + r'''
M.class="SHAMAN"
FP.MagePrep:Refresh()
assert(prepRow("water").count==22 and not prepRow("gem:5514") and not prepRow("reagent:17031"))
assert(FP.MagePrep.rows[#FP.MagePrep.rows-2].text:find("Enhancement",1,true))
cmd("prep show"); assert(#FP.MagePrep:Lines()>0)
M.class="HUNTER"; FP.MagePrep:Refresh()
assert(prepRow("water") and not prepRow("gem:5514"))
assert(FP.MagePrep.rows[#FP.MagePrep.rows].text:find("pet supplies",1,true))
''',
    "bag_space_excludes_specialty_bags_and_preserves_unknown": r'''
NUM_TOTAL_EQUIPPED_BAG_SLOTS=2
C_Container.GetContainerNumFreeSlots=function(bag) return 4, bag==1 and 32 or 0 end
assert(FP.API.GetFreeBagSlots()==8)
C_Container.GetContainerNumFreeSlots=function() return M.Secret(),0 end
assert(FP.API.GetFreeBagSlots()==nil)
InCombatLockdown=function() return true end
C_Container.GetContainerNumFreeSlots=function() error("combat read") end
assert(FP.API.GetFreeBagSlots()==nil)
''',
    "turnin_live_navigation_beats_beta_and_recorded_is_fallback": r'''
local q=addQuest(9001,true)
FP.data.quests[9001].epos={m=1413,x=.1,y=.1}
local m,x,y,how=FP.Planner:ResolveTurnIn(9001)
assert(how=="waypoint" and x==.6)
q.waypoint=nil; M.pois={}
m,x,y,how=FP.Planner:ResolveTurnIn(9001)
assert(how=="recorded" and x==.1)
''',
    "route_cluster_counts_distinct_quests_and_bonus_is_bounded": r'''
for id=9001,9006 do addQuest(id) end
FP.Planner:Build()
assert(FP.Planner.steps[1].cluster==5)
assert(FP.Planner.steps[1].score==FP.Planner.steps[1].dist-180)
M.RemoveQuest(9003); M.RemoveQuest(9004); M.RemoveQuest(9005); M.RemoveQuest(9006)
local q=M.quests[1]
q.objectives[2]={text="Other",finished=false}
FP.Planner:Build()
for _,s in ipairs(FP.Planner.steps) do assert(s.cluster==1) end
''',
    "skip_defers_all_objectives_expires_and_keeps_manual_waypoints": r'''
local q=addQuest(9001); addQuest(9002)
q.objectives[2]={text="Other",finished=false}
FP.Planner:Auto("test"); assert(active().source.questID==9001)
cmd("skip 1"); assert(active().source.questID==9002)
FP.Planner:Auto("test"); assert(active().source.questID==9002)
assert(FP.Planner.deferred[9001])
M.now=M.now+61; FP.Planner:Build(); assert(not FP.Planner.deferred[9001])
cmd("way .4 .5 Manual"); local id=active().id
cmd("skip"); assert(active().id==id)
''',
    "skip_only_quest_does_not_loop_and_click_resumes": r'''
addQuest(9001); FP.Planner:Auto("test")
cmd("skip 10"); assert(not active())
FP.Planner:Auto("test"); assert(not active())
FP.Planner:Go(FP.Planner.steps[1]); assert(active() and not FP.Planner.deferred[9001])
cmd("skip 10"); cmd("skip clear"); assert(active())
''',
    "skip_after_arrival_and_invalid_minutes": r'''
addQuest(9001); FP.Planner:Auto("test")
M.px,M.py=.6,.6; M.Tick(1); assert(FP.Planner.waiting)
cmd("skip -1"); assert(not FP.Planner.deferred[9001])
cmd("skip"); assert(FP.Planner.deferred[9001] and not FP.Planner.waiting)
''',
    "duo_snapshot_distinguishes_missing_pending_and_both_ready": r'''
addQuest(9001,true); addQuest(9002,true); addQuest(9003)
assert(FP.Party:Import("FP1;Friend;HUNTER;20;9001,9002c,9004", "paste"))
local text=table.concat(FP.Party:Checklist(), "\n")
assert(text:find("Partner still working: Quest 9001",1,true))
assert(text:find("Both ready to turn in: Quest 9002",1,true))
assert(text:find("Only you: Quest 9003",1,true) and text:find("Partner only: quest 9004",1,true))
FP.Planner:Build()
for _,s in ipairs(FP.Planner.steps) do if s.questID==9001 then assert(s.partnerPending) end end
''',
    "high_level_quest_penalty_does_not_penalize_turnin": r'''
local q=addQuest(9001); q.level=30; q.suggestedGroup=5
local q2=addQuest(9002,true); q2.level=30
M.level=20; FP.Planner:Build()
assert(FP.Planner.steps[1].questID==9002)
local s=FP.Planner.steps[2]; assert(s.highLevel and s.groupSize==5 and s.score>s.dist)
''',
    "profession_batch_shopping_updates_bags_and_clears": r'''
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
C_Item.GetItemCount=function() return 5 end
cmd("prof plan 3839 3")
local lines=table.concat(FP.Prof:PlanLines(),"\n")
assert(lines:find("7×",1,true) and lines:find("1 of 3",1,true))
assert(FP.Panel.footer:GetText():find("Shopping target",1,true))
C_Item.GetItemCount=function() return 12 end
M.FireEvent("BAG_UPDATE_DELAYED")
assert(FP.Panel.footer:GetText():find("Materials stocked",1,true))
cmd("prof plan 3839 0"); assert(FP.Prof.plan.target==3)
cmd("prof plan 99999 4"); assert(FP.Prof.plan.id==3839)
cmd("prof plan clear"); assert(not FP.Prof.plan and #FP.Prof:PlanLines()==0)
''',
    "profession_unavailable_counts_never_invent_shopping_deficit": r'''
local rec={reag={[4306]=4}}
C_Item.GetItemCount=function() error("unavailable") end
assert(FP.Prof:Craftable(rec)==nil)
assert(FP.Prof:MissingFor(rec,3)=="bag counts unavailable")
C_Item.GetItemCount=function() return M.Secret() end
assert(FP.Prof:Craftable(rec)==nil)
C_Item.GetItemCount=function() return -1 end
assert(FP.Prof:Craftable(rec)==nil)
''',
})

failed = 0
for name, body in CASES.items():
    result = subprocess.run([LUA, "-"], input=BOOT + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + result.stderr.splitlines()[0])

# Fresh release logins exercise module registration with each actual launch class.
for player_class in ("SHAMAN", "HUNTER"):
    boot = BOOT.replace('local FP = {}', 'M.class = "' + player_class + '"\nGetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end\nlocal FP = {}')
    body = PREP_SETUP + r'''
cmd("prep show"); M.RunTimers(1)
assert(FP.clientBuild=="70790" and #FP.MagePrep:Lines()>0)
assert(not prepRow("gem:5514") and not prepRow("reagent:17031"))
assert(FP.PvP.frame:IsShown())
M.FireEvent("PLAYER_REGEN_DISABLED"); assert(#FP.MagePrep:Lines()==0)
M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(1)
assert(#FP.MagePrep:Lines()>0 and #FP.db.errors==0)
'''
    result = subprocess.run([LUA, "-"], input=boot + body, text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + "fresh_70790_" + player_class.lower())
    if result.returncode:
        failed += 1
        print(result.stderr)

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

print(f"{failed} failed / {len(CASES) + 6} preflight regressions")
raise SystemExit(1 if failed else 0)
