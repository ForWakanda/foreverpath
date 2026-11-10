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

HUB = r'''
local H=FP.Hub
local function page(key) H:Open(key) end
local function click(id)
    local b=assert(H.controls[id],id)
    assert(b:IsEnabled(),id.." is unexpectedly disabled")
    b:GetScript("OnClick")(b)
end
local function check(id,on)
    local b=assert(H.controls[id]); b:SetChecked(on); click(id)
end
local function field(id,text) H.controls[id]:SetText(tostring(text)) end
local function selectRow(id,n)
    local b=H.controls[id].rows[n or 1]; assert(b.item); b:GetScript("OnClick")(b)
end
'''

CASES = {
    "hub_all_sections_are_read_only_and_reuse_frames": HUB + r'''
cmd("way 60 60 Preserve")
local beforeSettings,beforeData,beforeChar=snapshot(FP.settings),snapshot(FP.data),snapshot(FP.cdb)
local calls=0
FP.Party.Send=function() calls=calls+1 end
FP.Vendor.SellClicked=function() calls=calls+1 end
FP.Vendor.RepairClicked=function() calls=calls+1 end
ForeverPath_OnAddonCompartmentClick()
assert(H.frame:IsShown() and H.selected=="navigation")
for _,s in ipairs(H.sections) do page(s[1]); assert(H.pages[s[1]].body:GetHeight()>=432) end
local count=#M.frames
for _,s in ipairs(H.sections) do page(s[1]) end
assert(#M.frames==count, "browsing leaks UI frames")
assert(calls==0 and snapshot(FP.settings)==beforeSettings and snapshot(FP.data)==beforeData)
assert(snapshot(FP.cdb)==beforeChar, "browsing changed character state")
cmd(""); assert(not H.frame:IsShown())
FP.Panel.toolsButton:GetScript("OnClick")(); assert(H.frame:IsShown())
FP.DungeonPanel:Open(); FP.DungeonPanel.toolsButton:GetScript("OnClick")()
assert(not FP.DungeonPanel.frame:IsShown() and H.frame:IsShown())
assert(#FP.db.errors==0)
''',
    "hub_quest_selection_search_and_defer_without_slash": HUB + r'''
addQuest(9001); addQuest(9002)
page("navigation")
field("questSearch","9002"); H.controls.questSearch:GetScript("OnTextChanged")()
assert(#H.controls.quests.items==1)
selectRow("quests"); click("goQuest")
assert(active().source.questID==9002 and FP.Planner.pinned)
field("skipMinutes",5); click("skipQuest")
assert(FP.Planner.deferred[9002] and active().source.questID==9001)
click("restoreQuests"); assert(not FP.Planner.deferred[9002])
click("pause"); assert(not FP.settings.autoNext and active())
click("resume"); assert(FP.settings.autoNext and FP.settings.arrow.shown)
assert(#FP.db.errors==0)
''',
    "hub_waypoint_validation_pagination_and_planned_removal": HUB + r'''
page("waypoints")
field("waypointX",101); field("waypointY",60); click("addWaypoint")
assert(#FP.Waypoints.list==0 and H.resultText:GetText():find("0 to 100",1,true))
field("waypointX",45.4); field("waypointY",70.4); field("waypointName","Cave entrance")
click("addWaypoint")
assert(math.abs(active().x-.454)<1e-9 and math.abs(active().y-.704)<1e-9 and active().title=="Cave entrance")
for i=1,12 do FP.Waypoints:Add(1413,.1+i/100,.3,"Place "..i) end
H:Refresh(); local list=H.controls.waypointList
list.next:GetScript("OnClick")(); assert(list.page==2 and list.rows[1].item)
selectRow("waypointList"); local id=H:Selected(list).wp.id
click("activateWaypoint"); assert(active().id==id)
click("removeWaypoint"); assert(not FP.Waypoints:Get(id))
FP.Waypoints:Clear(); addQuest(9001); FP.Planner.paused=nil; FP.Planner:Auto("test")
H:Refresh(); selectRow("waypointList"); click("removeWaypoint")
M.RunTimers(9); assert(not active() and FP.Planner.paused, "removed planned waypoint returned")
assert(#FP.db.errors==0)
''',
    "hub_profession_recipe_picker_validates_batch_and_keeps_drafts": HUB + r'''
M.FireEvent("TRADE_SKILL_SHOW"); M.RunTimers(3)
C_Item.GetItemCount=function() return 5 end
page("professions")
local list=H.controls.recipeList
for _,item in ipairs(list.items) do if item.key==3839 then list.selected=item.key end end
H:Refresh(); assert(H:Selected(list))
field("craftCount",3); click("planCraft")
assert(FP.Prof.plan.id==3839 and FP.Prof.plan.target==3)
click("craftMaterials"); assert(H.resultText:GetText():find("7×",1,true))
field("craftCount","unfinished"); FP:Fire("RECIPES_SCANNED"); M.RunTimers(.3)
assert(H.controls.craftCount:GetText()=="unfinished", "refresh erased draft input")
click("planCraft"); assert(FP.Prof.plan.target==3 and H.resultText:GetText():find("Enter craft count",1,true))
click("clearCraft"); assert(not FP.Prof.plan and #FP.db.errors==0)
''',
    "hub_party_copy_import_and_explicit_send": HUB + r'''
local sent=0
FP.Party.Send=function() sent=sent+1; return true end
addQuest(9001)
page("party"); click("partyCopy")
assert(sent==0 and H.controls.partyCode:GetText():find("FP1;",1,true))
field("partyCode","FP1;Friend;HUNTER;20;9001c")
click("partyImport"); assert(FP.cdb.party.name=="Friend" and sent==0)
click("duo"); assert(H.resultText:GetText():find("Friend",1,true))
click("partySync"); assert(sent==1)
field("partyCode","bad snapshot"); click("partyImport")
assert(FP.cdb.party.name=="Friend" and H.resultText:GetText():find("doesn't look",1,true))
assert(#FP.db.errors==0)
''',
    "hub_display_town_pvp_controls_reuse_existing_guards": HUB + r'''
cmd("way 60 60 Preserve")
local wp=active()
page("display")
check("displayworldMapPins",false); check("displayminimapPin",false); check("arrowshown",false)
assert(not FP.Arrow.frame:IsShown() and not FP.Pins.mini:IsShown() and #WorldMapFrame._pins==0)
field("arrowScale",150); click("arrowApplyScale"); assert(FP.settings.arrow.scale==1.5)
field("arrowScale",500); click("arrowApplyScale"); assert(FP.settings.arrow.scale==1.5)
check("barFPS",false); assert(not FP.settings.bar.fps)
page("town")
check("vendorenabled",false); check("vendortooltipPrice",false); check("vendorrewardValues",false)
field("durabilityThreshold",35); field("ammoThreshold",300); click("applyReminders")
assert(FP.settings.reminders.durability==35 and FP.settings.reminders.ammo==300)
field("durabilityThreshold",91); field("ammoThreshold",400); click("applyReminders")
assert(FP.settings.reminders.durability==35 and FP.settings.reminders.ammo==300, "invalid form partially applied")
page("pvp"); check("pvpEnabled",false); assert(not FP.settings.pvp.enabled)
field("flagIndex",2); click("trackFlag"); assert(FP.settings.pvp.flagIndex==2)
click("untrackFlag"); assert(not FP.settings.pvp.trackFlag)
assert(active()==wp and #FP.db.errors==0)
''',
    "hub_rare_watch_forms_keep_secure_scan_on_existing_hud": HUB + r'''
page("rare")
local original=#FP.RareWatch:Watch().rares
field("rareName","Test Rare"); field("rareID",1234); click("rareAdd")
assert(#FP.RareWatch:Watch().rares==original+1)
assert(FP.RareWatch:MacroText():find("/targetexact Test Rare",1,true))
local list=H.controls.rareList; list.selected=original+1; H:Refresh(); click("rareRemove")
assert(#FP.RareWatch:Watch().rares==original)
local scans=FP.RareWatch:Current() and FP.RareWatch:Current().scans
click("rareScan")
assert(FP.settings.rare.manual=="show" and FP.settings.rare.enabled)
assert((FP.RareWatch:Current() and FP.RareWatch:Current().scans)==scans, "opening HUD triggered a scan")
M.combatLockdown=true
field("rareName","Combat Rare"); click("rareAdd")
assert(FP.RareWatch.macroPending, "secure macro update was not deferred")
assert(#FP.db.errors==0)
''',
    "hub_destructive_confirmation_cancel_close_and_exact_action": HUB + r'''
cmd("way 60 60 Preserve")
local wp=active()
page("navigation"); click("clearRoute")
assert(H.pending and active()==wp)
H.confirmNo:GetScript("OnClick")(); assert(not H.pending and active()==wp)
click("clearRoute"); page("tools"); assert(not H.pending and active()==wp)
click("resetAccount"); assert(H.pending and ForeverPathDB)
H:Toggle(); assert(not H.pending and ForeverPathDB, "closing left a destructive action armed")
page("navigation"); click("clearRoute"); H.confirmYes:GetScript("OnClick")()
assert(not active() and FP.Planner.paused and not H.pending)
local account=ForeverPathDB
page("tools"); click("resetCharacter")
assert(ForeverPathCharDB and ForeverPathDB==account)
H.confirmYes:GetScript("OnClick")()
assert(ForeverPathCharDB==nil and ForeverPathDB==account)
assert(#FP.db.errors==0)
''',
    "hub_output_capture_is_bounded_and_restored_after_failure": HUB + r'''
page("tools")
local before=#M.Chat()
click("statusReport")
assert(#M.Chat()==before and H.resultText:GetText():find("recording:",1,true))
FP:Print("ordinary chat still works"); assert(#M.Chat()==before+1)
local ok,lines=FP:CaptureOutput(function()
    for i=1,250 do FP:Print("line "..i) end
    error("deliberate test failure")
end)
assert(not ok and #lines==200 and not FP.outputSink)
FP:Print("restored after failure"); assert(#M.Chat()==before+2)
local ok,lines=FP:CaptureOutput(function()
    FP:Print("outer")
    local inner,output=FP:CaptureOutput(function() FP:Print("inner") end)
    assert(inner and output[1]=="inner")
    FP:Print("outer again")
end)
assert(ok and #lines==2 and lines[2]=="outer again" and not FP.outputSink)
''',
    "hub_refresh_is_coalesced_and_closed_window_does_no_work": HUB + r'''
page("waypoints"); field("waypointName","Draft destination")
local count=0; local original=H.Refresh
H.Refresh=function(self) count=count+1; return original(self) end
for i=1,20 do FP:Fire("WAYPOINTS_CHANGED") end
M.RunTimers(.3)
assert(count==1 and H.controls.waypointName:GetText()=="Draft destination")
H:Toggle(); count=0
for i=1,20 do FP:Fire("WAYPOINTS_CHANGED") end
M.RunTimers(.3); assert(count==0)
assert(#FP.db.errors==0)
''',
    "hub_fit_saved_position_and_diagnostic_actions": HUB + r'''
UIParent:SetSize(1024,600)
page("tools")
assert(H.frame:GetScale()<1 and H.frame:GetScale()*690<=576)
H.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-40)
H.frame:GetScript("OnDragStop")(H.frame)
assert(FP.settings.hub.point=="TOPLEFT" and FP.settings.hub.x==30 and FP.settings.hub.y==-40)
for _,id in ipairs({"statusReport","apiCheck","selfTest","probeNow","probeDump","exportInfo","errorReport"}) do click(id) end
assert(not FP.outputSink and #FP.db.errors==0)
UIParent:SetSize(1920,1080); M.FireEvent("UI_SCALE_CHANGED")
assert(H.frame:GetScale()==1)
''',
    "hub_supplies_town_and_rare_information_actions": HUB + r'''
page("town")
field("prepwater",60); click("applyPrepwater"); assert(FP.cdb.prep.water==60)
field("prepbandages",15); click("applyPrepbandages"); assert(FP.cdb.prep.bandages==15)
field("prepreagents",8); click("applyPrepreagents"); assert(FP.cdb.prep.reagents==8)
click("prepShow"); assert(FP.settings.pvp.manual=="show" and FP.cdb.prep.mode=="show")
click("prepAuto"); assert(FP.cdb.prep.mode=="auto")
click("prepHide"); assert(FP.cdb.prep.mode=="hide")
for _,id in ipairs({"prepReport","junkValue","trainerLookup"}) do click(id) end
page("rare"); click("rareStatus"); click("rareRuns")
page("display"); click("audioStatus"); click("audioTest")
assert(#FP.db.errors==0)
''',
    "display_settings_normal_panel_entry_preserves_preferences_and_route": r'''
cmd("way 60 60 Keep my route")
local wp=active()
FP.settings.worldMapPins=false
FP.settings.minimapPin=false
FP.settings.arrow.shown=false
FP.settings.arrow.locked=true
FP.settings.arrow.flip=true
FP.settings.arrow.scale=1.7
local before=snapshot(FP.settings)
FP.Panel:Toggle(false)
ForeverPath_OnAddonCompartmentClick()
assert(FP.Hub.frame:IsShown())
FP.Panel:Toggle(true)
FP.Panel.settingsButton:GetScript("OnClick")()
local P=FP.Panel
assert(P.frame:IsShown() and P.displayFrame:IsShown())
assert(snapshot(FP.settings)==before, "opening settings changed preferences")
for _,b in ipairs(P.displayChecks) do
    local settings=b.arrow and FP.settings.arrow or FP.settings
    assert(b:GetChecked()==settings[b.key])
end
assert(P.arrowSize:GetText()=="Arrow size: 170%")
assert(active()==wp and #FP.Waypoints.list==1)
local window=P.displayFrame
P:OpenSettings(); assert(P.displayFrame==window)
local count=0
for _,name in ipairs(UISpecialFrames) do if name=="ForeverPathDisplaySettings" then count=count+1 end end
assert(count==1, "escape registration duplicated on reopen")
assert(FP.settings==ForeverPathDB.settings and #FP.db.errors==0)
''',
    "display_settings_pin_toggles_apply_immediately_and_survive_ticks": r'''
cmd("way 60 60 Keep my route")
local P=FP.Panel
P:OpenSettings()
local wp=active()
local function click(i,on)
    local b=P.displayChecks[i]; b:SetChecked(on); b:GetScript("OnClick")(b)
end
click(1,false); click(2,false); click(3,false)
assert(#WorldMapFrame._pins==0 and not FP.Pins.mini:IsShown() and not FP.Arrow.frame:IsShown())
M.RunTimers(12)
assert(#WorldMapFrame._pins==0 and not FP.Pins.mini:IsShown() and not FP.Arrow.frame:IsShown())
assert(active()==wp and #FP.Waypoints.list==1 and not FP.Planner.paused)
WorldMapFrame:Hide()
click(1,true)
WorldMapFrame:Show(); FP.Pins.provider:RefreshAllData()
assert(#WorldMapFrame._pins==1)
click(2,true); click(3,true)
assert(FP.Pins.mini:IsShown() and FP.Arrow.frame:IsShown())
assert(active()==wp and FP.db.settings.worldMapPins and FP.db.settings.minimapPin)
FP.Pos.cache.valid=false
FP.Pins:UpdateMinimap(FP.Pos.cache)
assert(not FP.Pins.mini:IsShown() and #FP.db.errors==0)
''',
    "display_settings_arrow_lock_flip_size_and_narrow_reset": r'''
cmd("way 60 60 Manual")
local P,A=FP.Panel,FP.Arrow
P:OpenSettings()
local original=A.tex._rotation
local lock,flip=P.displayChecks[4],P.displayChecks[5]
lock:SetChecked(true); lock:GetScript("OnClick")(lock)
A.frame:GetScript("OnDragStart")(A.frame)
assert(not A.frame._moving, "locked arrow can still drag")
lock:SetChecked(false); lock:GetScript("OnClick")(lock)
A.frame:GetScript("OnDragStart")(A.frame)
assert(A.frame._moving)
A.frame:SetPoint("CENTER",UIParent,"CENTER",75,125)
A.frame:GetScript("OnDragStop")(A.frame)
assert(FP.settings.arrow.x==75 and FP.settings.arrow.y==125)
flip:SetChecked(true); flip:GetScript("OnClick")(flip)
assert(math.abs(A.tex._rotation+original)<0.0001)
for i=1,40 do P.larger:GetScript("OnClick")() end
assert(FP.settings.arrow.scale==3 and A.frame:GetScale()==3 and not P.larger:IsEnabled())
for i=1,40 do P.smaller:GetScript("OnClick")() end
assert(FP.settings.arrow.scale==0.4 and A.frame:GetScale()==0.4 and not P.smaller:IsEnabled())
FP.settings.arrow.shown=false
FP.settings.worldMapPins=false
local wp=active()
P.resetArrow:GetScript("OnClick")()
assert(FP.settings.arrow.x==0 and FP.settings.arrow.y==180 and FP.settings.arrow.scale==1)
assert(FP.settings.arrow.flip and not FP.settings.arrow.shown and not FP.settings.worldMapPins)
assert(active()==wp and not A.frame:IsShown() and P.smaller:IsEnabled() and P.larger:IsEnabled())
assert(P.arrowSize:GetText()=="Arrow size: 100%" and #FP.db.errors==0)
''',
    "display_settings_sync_existing_commands_and_saved_false_values": r'''
cmd("settings")
local P=FP.Panel
assert(P.displayFrame:IsShown())
cmd("arrow hide"); cmd("arrow lock"); cmd("arrow flip"); cmd("arrow scale 1.6")
assert(not P.displayChecks[3]:GetChecked() and P.displayChecks[4]:GetChecked() and P.displayChecks[5]:GetChecked())
assert(P.arrowSize:GetText()=="Arrow size: 160%")
cmd("guide")
assert(P.displayChecks[3]:GetChecked() and P.arrowSize:GetText()=="Arrow size: 100%")
P.displayChecks[1]:SetChecked(false); P.displayChecks[1]:GetScript("OnClick")(P.displayChecks[1])
P.displayChecks[2]:SetChecked(false); P.displayChecks[2]:GetScript("OnClick")(P.displayChecks[2])
-- Startup fills missing fields, preserving existing false values and arrow choices.
local saved=FP.Util.Copy(ForeverPathDB)
local restored=FP.deepDefaults(saved,FP.defaults)
assert(not restored.settings.worldMapPins and not restored.settings.minimapPin)
assert(restored.settings.arrow.locked and restored.settings.arrow.flip)
assert(#FP.db.errors==0)
''',
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
    "planned_map_pins_leave_native_quest_mouse_input_alone": r'''
addQuest(9001)
FP.Planner:Tick()
for i=1,4 do
    M.RunTimers(3)
    FP.Pins.provider:RefreshAllData()
    local pin=assert(WorldMapFrame._pins[1])
    assert(pin.wp.source.type=="plan")
    assert(not pin:IsMouseMotionEnabled(), "planned pin blocks quest hover")
    assert(not pin:IsMouseClickEnabled(), "planned pin blocks quest click")
    assert(pin:ShouldMouseButtonBePassthrough("RightButton"), "planned pin consumes map zoom-out")
    assert(pin.pinFrameLevelType=="PIN_FRAME_LEVEL_DEFAULT", "pin still covers native quest markers")
    local id=active().id
    pin:OnClick("RightButton")
    assert(active() and active().id==id, "passive pin removed the route")
    assert(FP.Arrow.frame:IsShown(), "map fix stopped arrow guidance")
end
assert(#FP.db.errors==0)
''',
    "map_pin_pool_reuse_restores_manual_mouse_controls": r'''
cmd("way 60 60 Manual")
local manual=active()
FP.Pins.provider:RefreshAllData()
local pin=assert(WorldMapFrame._pins[1])
local plan={id=999,mapID=1413,x=0.6,y=0.6,title="Quest",source={type="plan",questID=9001}}
for i=1,3 do
    pin:OnAcquired(plan,true)
    pin:CheckMouseButtonPassthrough("RightButton")
    assert(not pin:IsMouseMotionEnabled() and not pin:IsMouseClickEnabled())
    assert(#pin._passthrough==1)
    pin:OnAcquired(manual,true)
    pin:CheckMouseButtonPassthrough("RightButton")
    assert(pin:IsMouseMotionEnabled() and pin:IsMouseClickEnabled(), "pooled manual pin stayed passive")
    assert(#pin._passthrough==0)
end
local other=FP.Waypoints:Add(1413,0.7,0.7,"Other")
assert(active()==other)
pin:OnClick("LeftButton")
assert(active()==manual)
pin:OnClick("RightButton")
assert(not FP.Waypoints:Get(manual.id) and active()==other)
''',
    "manual_map_pins_stay_below_native_quest_markers": r'''
cmd("way 60 60 Test")
FP.Pins.provider:RefreshAllData()
local pin=assert(WorldMapFrame._pins[1])
assert(pin.pinFrameLevelType=="PIN_FRAME_LEVEL_DEFAULT", "manual pin still covers native quest markers")
assert(pin:IsMouseMotionEnabled() and pin:IsMouseClickEnabled())
''',
    "map_pin_callbacks_do_not_replace_or_hide_native_tooltips": r'''
addQuest(9001); FP.Planner:Tick(); FP.Pins.provider:RefreshAllData()
local pin=assert(WorldMapFrame._pins[1])
local owner="native quest"
local hides=0
GameTooltip.SetOwner=function(_,frame) owner=frame end
GameTooltip.IsOwned=function(_,frame) return owner==frame end
GameTooltip.Hide=function() hides=hides+1 end
pin:OnMouseEnter(); pin:OnMouseLeave()
assert(owner=="native quest" and hides==0, "passive callback interfered with quest tooltip")
pin:OnAcquired({id=123,mapID=1413,x=0.6,y=0.6,title="Manual"},true)
pin:OnMouseEnter()
assert(owner==pin)
pin:OnMouseLeave()
assert(hides==1, "manual pin did not dismiss its own tooltip")
owner="native quest"
pin:OnMouseLeave()
assert(hides==1, "late leave callback hid another pin's tooltip")
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

# v0.8.0: vendor helper, info bar, trainer notes --------------------------------
VENDOR_SETUP = r"""
NUM_TOTAL_EQUIPPED_BAG_SLOTS=4
M.items[1000]={"Broken Fang",0,5,12}       -- gray, 12c each
M.items[1001]={"Torn Sack",0,1,350}        -- gray, 3s 50c
M.items[1002]={"Linen Cloth",1,20,13}      -- white, must never sell
M.items[1003]={"Soggy Scroll",0,1,0}       -- gray, worthless
M.EnableBags({[0]={{1000,4},{1002,20},{1001,1},{1003,1}},[1]={},[2]={},[3]={},[4]={}})
local V=FP.Vendor
local function chat(pat) for _,l in ipairs(M.Chat()) do if l:find(pat,1,true) then return l end end end
"""
CASES.update({
    "vendor_strip_sells_grays_and_repairs_only_on_click": VENDOR_SETUP + r"""
assert(not V.frame:IsShown())
MerchantFrame:Show(); M.FireEvent("MERCHANT_SHOW"); M.RunTimers(1)
assert(V.frame:IsShown(), "strip opens with the merchant")
assert(#M.sold==0, "nothing sells without a click")
local junk=API_JUNK or FP.API.GetJunk()
assert(#junk.items==2 and junk.total==398, "two gray stacks worth 3s 98c; worthless/white excluded")
assert(V.sell:GetText():find("Sell 2 grays",1,true) and V.sell:GetText():find("3s 98c",1,true), V.sell:GetText())
assert(V.sell:IsEnabled())
assert(V.repair:GetText()=="Gear repaired" and not V.repair:IsEnabled())
V.sell:GetScript("OnClick")(V.sell); M.RunTimers(1)
assert(#M.sold==2 and M.sold[1]==1001 and M.sold[2]==1000, "both grays sold, highest value first")
assert(#M.bags[0]==2 and M.bags[0][1][1]==1002, "white stack untouched")
assert(V.sell:GetText()=="No gray items" and not V.sell:IsEnabled())
M.repairCost=1500; M.money=1200; M.FireEvent("UPDATE_INVENTORY_DURABILITY"); M.RunTimers(1)
assert(V.repair:GetText():find("short",1,true) and not V.repair:IsEnabled(), "cannot afford: disabled")
M.money=50000; M.FireEvent("PLAYER_MONEY"); M.RunTimers(1)
assert(V.repair:GetText()=="Repair 15s 0c" and V.repair:IsEnabled())
assert(not M.repaired, "repair waits for the click")
V.repair:GetScript("OnClick")(V.repair); M.RunTimers(1)
assert(M.repaired==1 and chat("Repaired for 15s 0c"))
M.canRepair=false; M.repairCost=800; M.FireEvent("MERCHANT_UPDATE"); M.RunTimers(1)
assert(V.repair:GetText():find("Repair elsewhere",1,true) and not V.repair:IsEnabled())
M.FireEvent("MERCHANT_CLOSED"); MerchantFrame:Hide()
assert(not V.frame:IsShown() and chat("Sold 2 gray items for 3s 98c"))
assert(not pcall(C_Container.UseContainerItem,0,1), "mock refuses sells outside a merchant")
assert(V:SellClicked()==0, "no sale with the merchant closed")
""",
    "vendor_strip_refuses_combat_and_defers_to_blizzard_junk_button": VENDOR_SETUP + r"""
MerchantFrame:Show(); M.FireEvent("MERCHANT_SHOW"); M.RunTimers(1)
M.combatLockdown=true; M.FireEvent("PLAYER_REGEN_DISABLED")
assert(V.sell:GetText()=="Sell grays (after combat)" and not V.sell:IsEnabled())
assert(V:SellClicked()==0 and #M.sold==0, "no sale in combat even if clicked")
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(1)
assert(V.sell:IsEnabled())
MerchantSellAllJunkButton=M.NewFrame("Button","MerchantSellAllJunkButton")
M.FireEvent("MERCHANT_UPDATE"); M.RunTimers(1)
assert(V.sell:GetText():find("Gray value",1,true) and not V.sell:IsEnabled(), "Blizzard's own junk button wins")
assert(V:SellClicked()==0 and #M.sold==0)
MerchantSellAllJunkButton=nil
cmd("vendor off"); assert(not V.frame:IsShown())
M.FireEvent("MERCHANT_SHOW"); assert(not V.frame:IsShown(), "disabled strip stays hidden")
cmd("vendor on"); cmd("vendor junk"); assert(chat("2 gray items worth 3s 98c"))
""",
    "vendor_tooltip_value_away_from_merchant_only": VENDOR_SETUP + r"""
assert(V.tooltipHook and #M.tooltipHooks==1)
local hook=M.tooltipHooks[1].fn
GameTooltip._item={link="|Hitem:1001:0|h[x]|h",id=1001}; GameTooltip._lines=nil
hook(GameTooltip,{})
assert(GameTooltip._lines and GameTooltip._lines[1][1]=="Vendor value" and GameTooltip._lines[1][2]:find("3s 50c",1,true), "value line added")
GameTooltip._item={link="|Hitem:1000:0|h[x]|h",id=1000}; GameTooltip._lines=nil
hook(GameTooltip,{})
assert(GameTooltip._lines[1][2]:find("12c",1,true) and GameTooltip._lines[1][2]:find("stack 60c",1,true), "stack value shown for stackables")
GameTooltip._item={link="|Hitem:1003:0|h[x]|h",id=1003}; GameTooltip._lines=nil
hook(GameTooltip,{}); assert(not GameTooltip._lines, "worthless item: no line")
GameTooltip._item={link="|Hitem:777777:0|h[x]|h",id=777777}; GameTooltip._lines=nil
hook(GameTooltip,{}); assert(not GameTooltip._lines, "uncached item: no invented price")
MerchantFrame:Show()
GameTooltip._item={link="|Hitem:1001:0|h[x]|h",id=1001}; GameTooltip._lines=nil
hook(GameTooltip,{}); assert(not GameTooltip._lines, "Blizzard prices items at a vendor")
MerchantFrame:Hide()
cmd("vendor tooltip off"); GameTooltip._lines=nil; hook(GameTooltip,{}); assert(not GameTooltip._lines)
local other=M.NewFrame("GameTooltip","SomeOtherTooltip"); other._item={link="|Hitem:1001:0|h[x]|h",id=1001}
cmd("vendor tooltip on"); hook(other,{}); assert(not other._lines, "only the game tooltips are decorated")
""",
    "quest_reward_values_mark_best_choice_without_choosing": VENDOR_SETUP + r"""
M.items[2001]={"Sturdy Belt",2,1,1500}
M.items[2002]={"Thin Gloves",2,1,900}
M.questChoices={2001,2002}
local buttons=QuestInfoFrame.rewardsFrame.RewardButtons
for i=1,2 do local b=M.NewFrame("Button"); b.type="choice"; b:SetID(i); buttons[i]=b end
local fixed=M.NewFrame("Button"); fixed.type="reward"; fixed:SetID(1); buttons[3]=fixed
M.FireEvent("QUEST_COMPLETE"); M.RunTimers(1)
assert(V.rewardsShown==2, "two priced choices decorated; the fixed reward is uncached")
assert(buttons[1].fpValue:GetText():find("ffd100",1,true) and buttons[1].fpValue:GetText():find("15s 0c",1,true), "best choice is gold")
assert(buttons[2].fpValue:GetText():find("9a9a9a",1,true) and buttons[2].fpValue:GetText():find("9s 0c",1,true), "the other is grey")
assert(not fixed.fpValue)
M.items[5555]={"Quilboar Sword",1,1,250}
M.FireEvent("GET_ITEM_INFO_RECEIVED"); M.RunTimers(1)
assert(V.rewardsShown==3 and fixed.fpValue:GetText():find("2s 50c",1,true), "cached later -> decorated")
buttons[2]:Hide(); QuestInfo_ShowRewards(); M.RunTimers(1)
assert(not buttons[2].fpValue:IsShown(), "hidden button loses its value text")
cmd("vendor rewards off"); M.FireEvent("QUEST_DETAIL"); M.RunTimers(1)
assert(#FP.db.errors==0)
""",
    "infobar_xp_rate_time_to_level_and_combat_safe_reminders": r"""
local B=FP.InfoBar
local function chat(pat) local n=0 for _,l in ipairs(M.Chat()) do if l:find(pat,1,true) then n=n+1 end end return n end
assert(B.frame:IsShown(), "bar shows by default")
B:Paint()
assert(B.text:GetText():find("xp/h —",1,true), "no rate before 2 minutes")
M.xp=12000; local t0=M.now
M.now=t0+600; M.xp=13200; M.FireEvent("PLAYER_XP_UPDATE","player")
M.now=t0+1200; M.xp=14400; M.FireEvent("PLAYER_XP_UPDATE","player")
B:Paint()
local rate,gained,elapsed=B:Rate()
assert(gained==2400 and elapsed==FP.Util.Now()-B.samples[1].t, "window runs from the login seed sample: gained="..tostring(gained).." elapsed="..tostring(elapsed).." expected="..tostring(FP.Util.Now()-B.samples[1].t))
assert(math.abs(rate-2400/elapsed*3600)<0.001, "rate = gained / elapsed, got "..tostring(rate))
assert(B.text:GetText():find(tostring(math.floor(rate+0.5)).." xp/h",1,true) and B.text:GetText():find("to level",1,true), B.text:GetText())
-- level-up carries the remainder into the new level
M.level=21; M.xp=300; M.FireEvent("PLAYER_LEVEL_UP",21); M.RunTimers(1)
assert(B.gained==2400+(17000-14400)+300, "xp across the level-up counted once")
-- reminders
M.durability={[1]={10,100},[5]={80,100}}
M.FireEvent("UPDATE_INVENTORY_DURABILITY"); B:Paint()
assert(B.remind:IsShown() and B.remind:GetText():find("Repair soon: 10%",1,true))
assert(chat("Repair soon: 10%")==1)
B:Paint(); B:Paint(); assert(chat("Repair soon: 10%")==1, "chat reminder not repeated within 10 minutes")
M.now=M.now+700; B:Paint(); assert(chat("Repair soon: 10%")==2, "repeats after the interval")
-- a known self-buff that is not active, out of combat only
M.class="SHAMAN"; M.known={[324]=true}; C_SpellBook={IsSpellKnown=function(id) return M.known[id] or false end}
M.auras={}; B:Paint()
assert(B.remind:GetText():find("Buff: Lightning Shield",1,true), B.remind:GetText())
M.auras={[325]=true}; B:Paint()
assert(not B.remind:GetText():find("Lightning Shield",1,true), "any rank active clears the reminder")
M.known={}; M.auras={}; B:Paint()
assert(not B.remind:GetText():find("Lightning Shield",1,true), "unknown spell: no reminder")
M.known={[324]=true}
M.inCombat=true; M.combatLockdown=true; M.FireEvent("PLAYER_REGEN_DISABLED"); B:Paint()
assert(not B.remind:IsShown(), "no reminders (and no aura reads) in combat")
assert(B.text:GetText():find("dura 10%",1,true), "cached durability still shown in combat")
M.inCombat=false; M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(1)
assert(B.remind:IsShown())
cmd("remind durability 5"); B:Paint(); assert(not B.remind:GetText():find("Repair soon",1,true))
cmd("remind off"); assert(not B.remind:IsShown())
cmd("bar hide"); assert(not B.frame:IsShown() and FP.settings.bar.shown==false)
cmd("bar show"); assert(B.frame:IsShown())
assert(#FP.db.errors==0)
""",
    "infobar_ammo_and_imbue_reminders_are_class_gated": r"""
local B=FP.InfoBar
M.usesAmmo=true; M.ammoCount=150; M.invIDs={[0]=2512}
B:Paint()
assert(B.text:GetText():find("ammo 150",1,true) and B.remind:GetText():find("Ammo low: 150",1,true))
M.ammoCount=900; B:Paint(); assert(not B.remind:GetText():find("Ammo low",1,true))
M.usesAmmo=false; B:Paint(); assert(not B.text:GetText():find("ammo",1,true), "non-ammo class shows no ammo segment")
M.class="SHAMAN"; M.known={[8017]=true}; C_SpellBook={IsSpellKnown=function(id) return M.known[id] or false end}
M.invIDs={[16]=2500}; M.imbues={}
B:Paint(); assert(B.remind:GetText():find("Imbue weapon",1,true), B.remind:GetText())
M.imbues={[16]={remainingTimeMs=600000,chargesRemaining=0}}; B:Paint()
assert(not B.remind:GetText():find("Imbue",1,true), "active imbue clears it")
M.invIDs={}; M.imbues={}; B:Paint(); assert(not B.remind:GetText():find("Imbue",1,true), "no weapon: nothing to imbue")
C_UnitAuras.GetPlayerAuraBySpellID=function() return M.Secret() end
M.known={[324]=true}; B:Paint(); assert(not B.remind:GetText():find("Lightning",1,true), "secret aura read: unknown, never 'missing'")
assert(#FP.db.errors==0)
""",
    "trainer_summary_and_level_up_notes_use_recorded_class_trainers": r"""
local function chat(pat) for _,l in ipairs(M.Chat()) do if l:find(pat,1,true) then return l end end end
M.class="SHAMAN"; M.level=20
GetNumTrainerServices=function() return 4 end
local svc={{"Lightning Shield","available",nil,20,"Rank 3"},{"Ghost Wolf","unavailable",nil,22,""},{"Water Walking","unavailable",nil,28,""},{"Healing Wave","used",nil,18,"Rank 4"}}
GetTrainerServiceInfo=function(i) local s=svc[i]; return s[1],s[2],s[3],s[4],s[5] end
GetTrainerServiceCost=function(i) return ({1200,5000,9000,600})[i], false end
GetTrainerServiceSkillReq=function() return nil,nil,false end
IsTradeskillTrainer=function() return false end
M.money=3000
M.SetUnit("npc",{guid="Creature-0-4379-1-13-3066-00003BB8F2",name="Kardris Dreamseeker",level=40,reaction=5})
M.FireEvent("TRAINER_SHOW"); M.RunTimers(1)
local line=chat("Trainer: 1 available now for 12s 0c")
assert(line and line:find("you can afford all",1,true) and line:find("Lightning Shield (Rank 3) 12s 0c",1,true), tostring(line))
assert(chat("Next at level 22: Ghost Wolf 50s 0c"))
assert(FP.data.trainers[3066].class=="SHAMAN", "trainer record carries the visiting class")
M.FireEvent("TRAINER_UPDATE"); M.RunTimers(2)
local n=0 for _,l in ipairs(M.Chat()) do if l:find("Trainer: 1 available",1,true) then n=n+1 end end
assert(n==1, "update with the same list does not reprint")
M.FireEvent("TRAINER_CLOSED")
M.level=22; M.FireEvent("PLAYER_LEVEL_UP",22); M.RunTimers(2)
assert(chat("Level 22: 1 new spell at your class trainer (recorded at Kardris Dreamseeker) — Ghost Wolf 50s 0c"))
M.level=23; M.FireEvent("PLAYER_LEVEL_UP",23); M.RunTimers(2)
assert(not chat("Level 23:"), "no recorded spell at 23: silence")
FP.data.trainers[3066].class="MAGE"
cmd("trainer 28"); assert(chat("No recorded SHAMAN trainer teaches anything at level 28"))
FP.data.trainers[3066].class="SHAMAN"
cmd("trainer 28"); assert(chat("Level 28 at Kardris Dreamseeker: Water Walking 90s 0c"))
assert(#FP.db.errors==0)
""",
})

OBJECTIVES = r'''
local sourceCalls=0
local data={
 Quest={[9101]={objectives={{{11}},{{21}},{{31}}}},[9102]={objectives={nil,nil,{{32}}}}},
 Npc={ [11]={name="Cave Spider",spawns={[15]={{32,23},{32.1,23.1},{33,24},{-1,-1},{101,20}}}},
       [12]={name="Hidden Spider",spawns={[15]={{34,25}},[17]={{60,60}}}},
       [13]={name="Quartermaster",spawns={[15]={{40,40}}}} },
 Object={[21]={name="Ancient Crate",spawns={[15]={{35,26}}}}},
 Item={[31]={name="Venom Sac",npcDrops={12},objectDrops={21},vendors={13}},
       [32]={name="Lost Key",itemDrops={33}},[33]={name="Container",itemDrops={32},npcDrops={11}}}
}
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function(v)return v==1 end,
 Support={Get=function()return {private={areaIdToUiMapId="return {[15]=1445,[17]=1413}"}}end}}
for _,kind in ipairs({"Quest","Npc","Object","Item"}) do
 local k=kind
 LibQuestieDB[k]={Get=function(id,key) sourceCalls=sourceCalls+1; return data[k][id] and data[k][id][key] end}
end
local function objective(text,kind,done) return {text=text,type=kind,finished=done or false,numFulfilled=0,numRequired=3} end
local q={questID=9101,title="Three objectives",objectives={
 objective("Venom Sac: 0/3","item"),objective("Cave Spider slain: 0/3","monster"),objective("Ancient Crate: 0/3","object")}}
M.AddQuest(q)
local Q=FP.QuestObjectives
Q:Refresh(true)
'''

CASES.update({
"quest_locations_match_live_order_and_item_sources": OBJECTIVES+r'''
assert(Q.matched==3 and Q.missing==0)
assert(Q.groups[1].name=="Venom Sac" and Q.groups[2].name=="Cave Spider")
local roles={};for _,p in ipairs(Q.groups[1].points)do roles[p.role]=true end
assert(roles.drop and roles.object and roles.vendor)
assert(#Q.groups[2].points==3, "invalid/sentinel spawns accepted")
assert(#Q:WorldPins(1445)>0 and #Q:WorldPins(1413)==1)
q.objectives[1].finished=true;Q:Refresh()
assert(Q.matched==2 and Q.groups[1].name=="Cave Spider", "completion used database order")
M.complete[9101]=true;Q:Refresh();assert(#Q.groups==0)
''',
"quest_locations_unknown_wording_and_ambiguous_sources_fail_closed": OBJECTIVES+r'''
q.objectives[1].text="Different item: 0/3"
q.objectives[2].text="Cave Spider Matriarch slain: 0/3"
q.objectives[3].type="event";Q:Refresh(true)
assert(Q.matched==0 and Q.missing==3)
local refs={{kind="Item",name="Same"},{kind="Item",name="Same"}}
assert(not Q:Match(objective("Same: 0/3","item"),refs))
assert(Q:Match(objective("Saco de veneno: 0/3","item"),{{kind="Item",name="Saco de veneno"}}))
assert(not Q:Match(objective("Saco de veneno: 0/3","monster"),{{kind="Item",name="Saco de veneno"}}))
''',
"quest_locations_dependency_missing_wrong_flavor_and_read_errors": OBJECTIVES+r'''
LibQuestieDB.flavor.expansion="Classic";Q:Refresh();assert(#Q.groups==0 and Q.status:find("Forever database",1,true))
LibQuestieDB.flavor.expansion="Forever";LibQuestieDB.RequireContract=function() error("provider failure") end
Q:Refresh(true);assert(#Q.groups==0)
LibQuestieDB.RequireContract=function()return true end
LibQuestieDB.Npc.Get=function()error("bad read")end
Q:Refresh(true);assert(#Q.groups==0 and #FP.db.errors==0)
LibQuestieDB=nil;Q:Refresh();assert(#Q.groups==0 and Q.status:find("install/enable",1,true))
addQuest(9001);FP.Planner:Build();assert(#FP.Planner.steps>0, "missing provider broke normal routing")
''',
"quest_locations_container_cycle_and_map_validation": OBJECTIVES+r'''
M.AddQuest({questID=9102,title="Container",objectives={objective("Lost Key: 0/3","item")}})
Q:Refresh(true);assert(Q.matched==4)
local refs=FP.API.GetQuestReference(9102);assert(#refs[1].points==3)
local old=FP.API.GetMapInfo
FP.API.GetMapInfo=function(id)if id==1445 then return {mapType=4} end return old(id) end
refs=FP.API.GetQuestReference(9102);assert(#refs[1].points==0, "dungeon frames accepted")
''',
"quest_locations_cached_and_refreshed_after_abandon": OBJECTIVES+r'''
local calls=sourceCalls;Q:Refresh();Q:Refresh();assert(sourceCalls==calls)
FP.Planner:Build();assert(sourceCalls==calls, "planner repeatedly decodes provider")
for i=#M.quests,1,-1 do if M.quests[i].questID==9101 then table.remove(M.quests,i)end end
Q:Refresh();assert(#Q.groups==0 and not Q.references[9101])
''',
"quest_locations_world_marker_hover_click_and_native_priority": OBJECTIVES+r'''
M.mapID=1445;FP.Pos:Refresh(true)
FP.Pins.provider:RefreshAllData()
local pin
for _,p in ipairs(WorldMapFrame._pins)do if p._pinTemplate=="ForeverPathObjectivePinTemplate"then pin=p;break end end
assert(pin and pin.pinFrameLevelType=="PIN_FRAME_LEVEL_DEFAULT" and pin:IsMouseClickEnabled())
pin:OnMouseEnter();assert(GameTooltip:IsOwned(pin))
pin:OnClick("RightButton");assert(not active())
pin:OnClick("LeftButton");assert(active().source.type=="quest-location")
local wp=active();FP.Planner:Auto("test");assert(active()==wp)
M.complete[9101]=true;Q:Refresh();assert(not active())
''',
"quest_locations_nearest_guidance_fallback_preserves_native": OBJECTIVES+r'''
M.mapID=1445;M.px=.34;M.py=.25;FP.Pos:Refresh(true)
FP.Planner:Build()
local m,x,y,how=FP.Planner:ResolveObjective(9101,1)
assert(m==1445 and how:find("known source:",1,true))
q.waypoint={1445,.5,.5}
m,x,y,how=FP.Planner:ResolveObjective(9101,1)
assert(x==.5 and how=="waypoint", "database overrode native navigation")
''',
"quest_locations_world_budget_fairness_and_selection": OBJECTIVES+r'''
local points={};for i=1,500 do points[i]={mapID=1445,x=(i%100)/100,y=math.floor(i/100)/10,name="Many",entityID=11,role="kill"}end
Q.groups={{questID=9101,objIndex=1,name="Many",points=points},
 {questID=9102,objIndex=1,name="One",points={{mapID=1445,x=.995,y=.995,name="One",entityID=12,role="kill"}}}}
Q.worldCache={};local pins=Q:WorldPins(1445);assert(#pins==350)
local found=false;for _,p in ipairs(pins)do for _,e in ipairs(p.entries)do if e.group.questID==9102 then found=true end end end
assert(found,"large objective starved another quest")
FP.settings.questSelectedOnly=true;C_SuperTrack={GetSuperTrackedQuestID=function()return 9102 end}
assert(#Q:WorldPins(1445)==1)
C_SuperTrack.GetSuperTrackedQuestID=function()return 0 end
assert(#Q:WorldPins(1445)==0)
''',
"quest_locations_minimap_nearby_only_rotation_pool_and_settings": OBJECTIVES+r'''
M.mapID=1445;M.px=.34;M.py=.25;FP.Pos:Refresh(true)
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
local pool=FP.Pins.objectiveMini;assert(#pool>0 and #pool<=40)
for _,f in ipairs(pool)do if f:IsShown()then assert(f.point.d<=FP.API.GetMinimapViewRadius())end end
local count=#pool
FP.Pins.lastObjectiveMini=nil;FP.API.IsMinimapRotating=function()return true end
FP.Pos.cache.facing=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache);assert(#pool==count)
FP.settings.questMinimapPins=false;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
for _,f in ipairs(pool)do assert(not f:IsShown())end
FP.settings.questWorldPins=false;FP.Pins.provider:RefreshAllData();assert(#WorldMapFrame._pins==0)
assert(#FP.db.errors==0)
''',
"quest_locations_gui_controls_and_diagnostics": OBJECTIVES+HUB+r'''
page("display");check("displayquestSelectedOnly",true);check("displayquestWorldPins",false);check("displayquestMinimapPins",false)
assert(FP.settings.questSelectedOnly and not FP.settings.questWorldPins and not FP.settings.questMinimapPins)
page("navigation");assert(Q:Summary():find("3 unfinished",1,true))
assert(FP.db.questLocations.matched==3 and FP.db.questLocations.version==FP.version)
assert(#FP.db.errors==0)
''',
})

CASES["quest_locations_automatic_log_lifecycle_and_late_provider"] = OBJECTIVES+r'''
local provider=LibQuestieDB
LibQuestieDB=nil;Q:Refresh();assert(#Q.groups==0)
LibQuestieDB=provider;M.Tick(1)
assert(Q.matched==3,"late provider did not recover automatically")
M.AddQuest({questID=9102,title="Container",objectives={objective("Lost Key: 0/3","item")}})
M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(4);M.RunTimers(2);assert(Q.matched==4)
q.objectives[1].finished=true;M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(4);M.RunTimers(2)
assert(Q.matched==3,"completion did not refresh automatically")
M.RemoveQuest(9101);M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(4);M.RunTimers(2)
assert(Q.matched==1 and not Q.references[9101])
'''

CHAINS = r'''
local records={
 [201]={name="The Same Name",preQuestSingle={202,203},requiredLevel=30,startedBy={{501}}},
 [202]={name="First step",preQuestGroup={204,205}},
 [203]={name="Alternative first step"},
 [204]={name="Old beginning",exclusiveTo={206}},
 [205]={name="Another beginning"},
 [206]={name="Alternate beginning"},
 [207]={name="The Same Name",preQuestSingle={201}},
 [208]={name="Optional lead-in",breadcrumbForQuestId=201},
 [209]={name="Needs active parent",parentQuest=201,availableStartingWith=202},
}
local finished={};local calls=0
C_QuestLog.IsQuestFlaggedCompleted=function(qid)return finished[qid] or false end
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function()return true end,
 Support={Get=function()return {private={areaIdToUiMapId="return {[17]=1413}"}}end},
 Quest={Get=function(qid,key)calls=calls+1;return records[qid] and records[qid][key] end,
 GetAllIds=function()local ids={};for qid in pairs(records)do ids[#ids+1]=qid end;table.sort(ids);return ids end},
 Npc={Get=function(_,key)if key=="name"then return "Quest Giver"elseif key=="spawns"then return {[17]={{60,60},{-1,-1}}}end end},
 Item={Get=function()return "Starting Letter"end},Object={Get=function()end}}
local C=FP.QuestChains
C:StartIndex(true)
local function ctx()return C:Context()end
'''

CASES.update({
"chains_any_and_all_prerequisites_are_distinct": CHAINS+r'''
assert(C:Requirements(C:Get(201),ctx())==false)
finished[203]=true;assert(C:Requirements(C:Get(201),ctx())==true)
assert(C:Requirements(C:Get(202),ctx())==false)
finished[204]=true;assert(C:Requirements(C:Get(202),ctx())==false)
finished[205]=true;assert(C:Requirements(C:Get(202),ctx())==true)
local lines=table.concat(C:Details(201,ctx())," ")
assert(lines:find("ANY ONE",1,true) and not lines:find("Available",1,true))
''',
"chains_group_alternatives_and_exact_negative_ids": CHAINS+r'''
finished[206],finished[205]=true,true
assert(C:Requirements(C:Get(202),ctx())==true,"exclusive alternative must satisfy positive group")
records[202].preQuestGroup={-204,205};C:StartIndex(true)
assert(C:Requirements(C:Get(202),ctx())==false,"negative entry must require exact quest")
finished[204]=true;assert(C:Requirements(C:Get(202),ctx())==true)
''',
"chains_unknown_states_are_not_missing_or_completed": CHAINS+r'''
C_QuestLog.IsQuestFlaggedCompleted=nil
assert(C:Requirements(C:Get(201),ctx())==nil)
assert(C:StateLabel(201,ctx())=="State unknown")
C_QuestLog.IsQuestFlaggedCompleted=function()return M.Secret()end
assert(C:Requirements(C:Get(201),ctx())==nil)
C_QuestLog.IsQuestFlaggedCompleted=function()error("unavailable")end
assert(C:Requirements(C:Get(201),ctx())==nil and #FP.db.errors==0)
''',
"chains_live_status_and_offer_win_over_reference": CHAINS+r'''
finished[201]=true
assert(C:StateLabel(201,ctx())=="Completed")
addQuest(201,false);assert(C:StateLabel(201,ctx())=="In quest log")
M.complete[201]=true;assert(C:StateLabel(201,ctx())=="Ready to turn in")
M.RemoveQuest(201);finished[201]=false
local context=ctx();context.offers[201]={questID=201}
assert(C:StateLabel(201,context)=="Offered on current map")
assert(C:Requirements(C:Get(201),context)==false,"reference requirements stay separate from offer")
''',
"chains_optional_leadins_and_parent_gates": CHAINS+r'''
records[201].breadcrumbs={208};C:StartIndex(true)
finished[203]=true
assert(C:Requirements(C:Get(201),ctx())==true,"optional lead-in became mandatory")
assert(C:Requirements(C:Get(209),ctx())==false)
addQuest(201);finished[202]=true
assert(C:Requirements(C:Get(209),ctx())==true)
M.RemoveQuest(201);finished[201]=true
assert(C:Requirements(C:Get(209),ctx())==false,"completed parent is not active parent")
''',
"chains_cutoffs_and_branches_are_not_prerequisites": CHAINS+r'''
records[201].nextQuestInChain=207;records[201].exclusiveTo={203};records[201].disabledByQuest=208
records[201].availableUntilCompleted=205;C:StartIndex(true)
finished[207],finished[203],finished[205]=true,true,true;addQuest(208)
local blockers=table.concat(C:Blockers(C:Get(201),ctx())," ")
assert(blockers:find("Later step",1,true) and blockers:find("Alternative branch",1,true) and blockers:find("blocker",1,true) and blockers:find("cutoff",1,true))
local links=C:Links(201,ctx());local found=false
for _,row in ipairs(links)do if row.id==207 and row.label:find("Later step",1,true)then found=true end end
assert(found)
''',
"chains_missing_conflicting_and_cyclic_references_are_visible": CHAINS+r'''
assert(table.concat(C:Details(999,ctx())," "):find("coverage gap",1,true))
assert(table.concat(C:Details(203,ctx())," "):find("does not prove",1,true))
records[201].preQuestGroup={204};C:StartIndex(true)
local value,notes=C:Requirements(C:Get(201),ctx());assert(value==nil and notes[1]:find("Conflicting",1,true))
records[204].preQuestSingle={202};C:StartIndex(true)
local rows=C:Links(202,ctx());assert(#rows<=100)
local cycle=false;for _,row in ipairs(rows)do if row.label:find("cycle",1,true)then cycle=true end end
assert(cycle)
''',
"chains_search_duplicate_names_ids_and_log_filter": CHAINS+r'''
local rows=C:Search("The Same Name",false,ctx());assert(#rows==2 and rows[1].id==201 and rows[2].id==207)
assert(#C:Search("#207",false,ctx())==1)
assert(#C:Search("",true,ctx())==0)
addQuest(201);assert(#C:Search("",true,ctx())==1)
local stateCalls=0;FP.API.GetDungeonQuestState=function()stateCalls=stateCalls+1;return {}end
C:Search("",false,ctx());assert(stateCalls==0,"search scanned live state for every catalog record")
''',
"chains_index_batches_generation_and_cache": CHAINS+r'''
for i=300,450 do records[i]={name="Quest "..i,preQuestSingle={201}}end
C:StartIndex(true);assert(C.loading and C.scanned==40 and not C.indexed)
local prior=calls;C:Get(201);C:Get(201);assert(calls==prior)
records[400]=nil;C:StartIndex(true)
for i=1,8 do M.RunTimers(.03)end
assert(C.indexed and not C.records[400] and C.followups[201][450])
local rows=C:Links(201,ctx());assert(#rows<=100)
''',
"chains_adapter_rejects_bad_ids_fields_and_provider": CHAINS+r'''
assert(not FP.API.GetQuestChainRecord(nil) and not FP.API.GetQuestChainRecord(-1))
records[201].preQuestSingle={202,"invalid"};C:StartIndex(true)
assert(C:Get(201).incomplete and C:Requirements(C:Get(201),ctx())==false)
records[201].preQuestSingle="broken";C:StartIndex(true)
assert(C:Requirements(C:Get(201),ctx())==nil)
LibQuestieDB=nil;C:StartIndex(true)
assert(not C.loading and not C.indexed and not C:Get(201))
assert(table.concat(C:Details(201,ctx())," "):find("coverage gap",1,true))
''',
"chains_pickup_only_on_click_and_cleans_up_on_accept": CHAINS+r'''
C:Details(201,ctx());C:Links(201,ctx());assert(not active())
local ok,message=C:GuidePickup(201);assert(ok and active().source.type=="chain-pickup")
assert(active().mapID==1413 and active().x==.6 and message:find("not guaranteed",1,true))
addQuest(201);FP:Fire("QUESTLOG_SCANNED");assert(not active())
assert(not C:GuidePickup(201))
M.RemoveQuest(201);finished[201]=true;assert(not C:GuidePickup(201))
records[203].startedBy={nil,nil,{900}};C:StartIndex(true)
assert(not C:GuidePickup(203),"item starter invented a location")
''',
"chains_gui_search_drilldown_back_and_drafts": CHAINS+HUB+r'''
page("chains");field("chainSearch","The Same Name");H.controls.chainSearch:GetScript("OnTextChanged")()
assert(#H.controls.chainResults.items==2 and not FP.ChainPanel.currentOnly)
selectRow("chainResults",1);click("chainInspect")
assert(FP.ChainPanel.questID==201 and FP.ChainPanel.view=="detail")
assert(FP.ChainPanel.detailText:GetText():find("ANY ONE",1,true))
selectRow("chainLinks",1);local linked=H:Selected(H.controls.chainLinks).id;click("chainFollow")
assert(FP.ChainPanel.questID==linked and #FP.ChainPanel.history==1)
click("chainBack");assert(FP.ChainPanel.questID==201)
click("chainSearchBack");assert(FP.ChainPanel.view=="browser" and H.controls.chainSearch:GetText()=="The Same Name")
assert(#H.controls.chainResults.items==2)
local count=#M.frames
selectRow("chainResults",2);click("chainInspect");click("chainSearchBack")
assert(#M.frames==count and #FP.db.errors==0)
''',
"chains_navigation_entry_and_live_refresh_preserve_route": CHAINS+HUB+r'''
addQuest(201);cmd("way 50 50 Keep my route");local wp=active()
page("navigation");field("questSearch","Quest 201");H.controls.questSearch:GetScript("OnTextChanged")()
selectRow("quests");click("viewQuestChain")
assert(H.selected=="chains" and FP.ChainPanel.questID==201 and active()==wp)
assert(FP.ChainPanel.detailText:GetText():find("In quest log",1,true))
M.complete[201]=true;FP:Fire("QUESTLOG_SCANNED");M.RunTimers(.3)
assert(FP.ChainPanel.detailText:GetText():find("Ready to turn in",1,true) and active()==wp)
assert(#FP.db.errors==0)
''',
})

CASES["chains_unknown_blockers_and_signed_single_stay_unknown"] = CHAINS+r'''
records[201].preQuestSingle={-202};records[201].disabledByQuest=203;C:StartIndex(true)
finished[202]=true
assert(C:Requirements(C:Get(201),ctx())==nil)
C_QuestLog.IsOnQuest=nil
assert(table.concat(C:Blockers(C:Get(201),ctx())," "):find("unknown",1,true))
assert(not C:GuidePickup(201) and not C:GuidePickup(nil))
'''
CASES["chains_selected_link_survives_completion_refresh"] = CHAINS+HUB+r'''
H:OpenQuestChain(201);selectRow("chainLinks",1)
local key=H.controls.chainLinks.selected
finished[202]=true;FP:Fire("QUESTLOG_SCANNED");M.RunTimers(.3)
assert(H.controls.chainLinks.selected==key and H:Selected(H.controls.chainLinks))
'''

CASES["chains_large_ancestry_keeps_followups_visible"] = CHAINS+r'''
records[201].preQuestSingle={};records[201].preQuestGroup={}
for i=300,390 do records[i]={name="Ancestor "..i};table.insert(records[201].preQuestGroup,i)end
C:StartIndex(true);for i=1,4 do M.RunTimers(.03)end
local rows=C:Links(201,ctx());local found=false
for _,row in ipairs(rows)do if row.id==207 and row.label:find("Follow-up",1,true)then found=true end end
assert(found and #rows<=100,"ancestor list hid direct follow-up")
'''

REWARDS = r'''
local R,A=FP.QuestRewards,FP.API
local selected=9001
C_QuestLog.GetSelectedQuest=function() return selected end
C_QuestLog.GetTitleForQuestID=function(id) return "Reward quest "..id end
HaveQuestRewardData=function() return true end
GetQuestLogRewardXP=function() return 1200 end
GetQuestLogRewardMoney=function() return 321 end
GetNumQuestLogChoices=function() return 2 end
GetNumQuestLogRewards=function() return 1 end
GetQuestLogChoiceInfo=function(i) return "Choice "..i,nil,i,2,i~=2,100+i end
GetQuestLogRewardInfo=function(i) return "Fixed",nil,1,2,true,103 end
GetQuestLogItemLink=function(kind,i) return "item:"..(kind=="choice" and 100+i or 103) end
local items={
 [101]={loc="INVTYPE_FINGER",price=100,stats={ITEM_MOD_STRENGTH_SHORT=5,ITEM_MOD_STAMINA_SHORT=2}},
 [102]={loc="INVTYPE_FINGER",price=75,stats={ITEM_MOD_STRENGTH_SHORT=2}},
 [103]={loc="",price=9999,stats={}},
 [201]={loc="INVTYPE_FINGER",price=50,stats={ITEM_MOD_STRENGTH_SHORT=3}},
 [202]={loc="INVTYPE_FINGER",price=50,stats={ITEM_MOD_STRENGTH_SHORT=7}},
}
local gear={[11]=201,[12]=202,[16]=201,[17]=202}
C_Item.GetItemInfo=function(link)
 local id=tonumber(tostring(link):match("item:(%d+)"));local item=items[id]
 if not item or item.loading then return nil end
 return "Item "..id,link,2,30,20,"Armor","Mail",20,item.loc,nil,item.price
end
C_Item.GetItemStats=function(link) local id=tonumber(link:match("item:(%d+)"));return items[id].stats end
GetInventoryItemID=function(unit,slot) return gear[slot] end
GetInventoryItemLink=function(unit,slot) return gear[slot] and ("item:"..gear[slot]) end
local function rewards() local s=A.GetRewardContext("log");R:Rank(s);return s end
'''
CASES.update({
"rewards_counts_stack_value_and_fixed_vs_choice":REWARDS+r'''
local s=rewards()
assert(s.questID==9001 and s.xp==1200 and s.money==321 and #s.items==3)
assert(s.items[1].value==100 and s.items[2].value==150 and s.items[3].value==9999)
assert(not s.items[1].bestVendor and s.items[2].bestVendor and not s.items[3].bestVendor)
assert(s.items[2].usable==false)
items[101].price=150;s=rewards();assert(s.items[1].bestVendor and s.items[2].bestVendor)
''',
"rewards_incomplete_data_never_claims_best_value":REWARDS+r'''
items[102].loading=true
local s=rewards();assert(s.items[2].value==nil and not s.items[1].bestVendor)
items[102].loading=false
GetQuestLogChoiceInfo=function() return "Mystery",nil,nil,2,true end
s=rewards();assert(s.items[1].count==nil and s.items[1].value==nil and not s.items[1].bestVendor)
GetNumQuestLogRewards=nil;s=rewards();assert(not s.countsKnown and s.message)
''',
"rewards_ring_alternatives_and_positive_negative_stats":REWARDS+r'''
local row=rewards().items[1];local comparisons=R:Comparisons(row)
assert(#comparisons==2 and comparisons[1].stats.ITEM_MOD_STRENGTH_SHORT==3 and comparisons[2].stats.ITEM_MOD_STRENGTH_SHORT==7)
local text=R:Details(row);assert(text:find("5 / 3 (+2)",1,true) and text:find("5 / 7 (-2)",1,true))
gear[11]=nil;comparisons=R:Comparisons(row);assert(next(comparisons[1].stats)==nil)
''',
"rewards_two_handed_replaces_both_equipped_hands":REWARDS+r'''
items[101].loc="INVTYPE_2HWEAPON"
local row=rewards().items[1];local c=R:Comparisons(row)
assert(#c==1 and c[1].stats.ITEM_MOD_STRENGTH_SHORT==10)
assert(R:Details(row):find("5 / 10 (-5)",1,true))
items[202].loading=true;c=R:Comparisons(row);assert(c[1].stats==nil)
''',
"rewards_secret_or_error_reads_stay_unknown":REWARDS+r'''
GetInventoryItemID=function() return M.Secret() end
assert(A.GetRewardEquipment(11).status=="unknown")
GetInventoryItemID=function() error("restricted") end
assert(A.GetRewardEquipment(11).status=="unknown")
items[101].stats={ITEM_MOD_STRENGTH_SHORT=M.Secret()}
assert(rewards().items[1].item.stats==nil)
GetNumQuestLogChoices=function() return M.Secret() end
local s=rewards();assert(not s.countsKnown and #s.items==1)
GetNumQuestLogChoices=function() return 1000000 end
assert(#rewards().items==1)
''',
"rewards_dialog_failures_never_fall_back_to_log":REWARDS+r'''
QuestFrame=CreateFrame("Frame");QuestFrame:Show()
GetQuestID=function() return 9100 end
GetTitleText=function() return "Dialog quest" end
GetNumQuestChoices=function() return 1 end
GetNumQuestRewards=function() return 0 end
GetQuestItemInfo=function() error("not ready") end
GetQuestItemLink=nil;GetRewardMoney=nil;GetRewardXP=nil
local s=A.GetRewardContext("dialog")
assert(s.questID==9100 and s.title=="Dialog quest" and #s.items==1)
assert(not s.items[1].item and not s.items[1].count and not s.money and not s.xp)
GetNumQuestChoices=nil;s=A.GetRewardContext("dialog");assert(#s.items==0 and not s.countsKnown)
QuestFrame:Hide();assert(not A.GetRewardContext("dialog").questID)
''',
"rewards_combat_and_missing_reward_data_stop_reads":REWARDS+r'''
local reads=0;GetNumQuestLogChoices=function() reads=reads+1;return 0 end
A.InCombat=function()return true end
assert(not rewards().questID and reads==0)
A.InCombat=function()return false end
HaveQuestRewardData=function()return false end
assert(rewards().message and reads==0)
HaveQuestRewardData=function()return M.Secret() end
assert(rewards().message and reads==0)
''',
"rewards_identity_change_discards_mixed_snapshot":REWARDS+r'''
GetQuestLogRewardInfo=function()selected=9002;return "Fixed",nil,1 end
local s=rewards();assert(not s.questID and #s.items==0 and s.message:find("changed"))
''',
"rewards_ui_selection_equipment_and_item_load_refresh":REWARDS+HUB+r'''
cmd("way 60 60 Preserve")
local before=snapshot(FP.Waypoints.list)
page("rewards");selectRow("rewardItems",2)
assert(FP.RewardPanel.details:GetText():find("Choice 2"))
items[102].loading=true;M.FireEvent("GET_ITEM_INFO_RECEIVED",102,false);M.RunTimers(1)
assert(FP.RewardPanel.details:GetText():find("loading"))
items[102].loading=false;gear[11]=nil
M.FireEvent("PLAYER_EQUIPMENT_CHANGED",11);M.RunTimers(1)
assert(FP.RewardPanel.details:GetText():find("Empty slot"))
assert(H.controls.rewardItems.selected=="choice:2" and snapshot(FP.Waypoints.list)==before)
selected=9002;M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(1)
assert(FP.RewardPanel.snapshot.questID==9002 and H.controls.rewardItems.selected=="choice:1")
assert(#FP.db.errors==0)
''',
"rewards_hidden_page_does_not_read_or_create_frames":REWARDS+HUB+r'''
page("rewards");page("town");local count=#M.frames
local calls=0;A.GetRewardContext=function()calls=calls+1;return {items={}} end
M.FireEvent("GET_ITEM_INFO_RECEIVED",101,true);M.FireEvent("PLAYER_EQUIPMENT_CHANGED",11);M.RunTimers(1)
assert(calls==0 and #M.frames==count)
H.frame:Hide();M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(1);assert(calls==0)
''',
"rewards_dialog_compare_button_requires_click":REWARDS+HUB+r'''
QuestFrame=CreateFrame("Frame");QuestFrame:Show()
page("navigation");M.dialogQuest=9001;M.FireEvent("QUEST_DETAIL");M.RunTimers(1)
assert(H.selected=="navigation" and R.button:IsShown())
local count=#M.frames;R.button:GetScript("OnClick")()
assert(H.selected=="rewards" and FP.RewardPanel.mode=="dialog")
M.FireEvent("QUEST_FINISHED");assert(not R.button:IsShown())
M.FireEvent("QUEST_DETAIL");assert(R.button:IsShown())
assert(#FP.db.errors==0)
''',
"rewards_empty_stats_unsellable_and_missing_api":REWARDS+r'''
items[101].price=0;items[102].price=0
local s=rewards();assert(s.items[1].value==0 and not s.items[1].bestVendor)
C_Item.GetItemStats=nil;assert(rewards().items[1].item.stats==nil)
C_QuestLog.GetSelectedQuest=nil;s=rewards();assert(not s.questID and #s.items==0)
''',
})

CASES["rewards_item_cache_requests_are_bounded_and_values_finite"] = REWARDS+r'''
local requests=0
C_Item.RequestLoadItemDataByID=function()requests=requests+1 end
items[101].loading=true
for i=1,10 do rewards() end
assert(requests==1)
for i=1000,1300 do A.GetRewardItem("item:"..i) end
assert(requests==128)
items[101].loading=false;items[101].price=1e300
GetQuestLogChoiceInfo=function()return "Huge",nil,1e300,2,true end
local s=rewards();assert(s.items[1].value==nil and not s.items[2].bestVendor)
'''

EVENTS=OBJECTIVES+r'''
data.Quest[9101].triggerEnd={"Explore the ruined tower",{[15]={{45,55},{-1,-1},{120,50}},[17]={{40,40}}}}
q.objectives={objective("Explore the ruined tower","event"),objective("Cave Spider slain: 0/3","monster")}
Q:Refresh(true)
local function eventPin(kind)
 for _,pin in ipairs(Q:WorldPins(1445))do for _,entry in ipairs(pin.entries)do if entry.group.kind==kind then return pin end end end
end
'''
CASES.update({
"events_trigger_coordinates_and_progress_match":EVENTS+r'''
assert(Q.matched==2 and Q.events==1 and Q.hints==0 and Q.missing==0)
assert(Q.groups[1].kind=="Event" and #Q.groups[1].points==2 and Q.groups[1].points[1].mapID==1413)
local pin=eventPin("Event");assert(pin and pin.x==.45 and pin.y==.55)
local owner=CreateFrame("Frame");Q:Tooltip(pin,owner)
assert(GameTooltip:IsOwned(owner))
assert(Q:Guide(pin) and active().title:find("Event:",1,true))
assert(active().desc:find("Arrival alone",1,true) and active().source.objIndex==1)
q.objectives[1].finished=true;Q:Refresh();assert(Q.events==0 and not active())
''',
"events_type_singleton_counts_finished_rows_and_rejects_ambiguity":EVENTS+r'''
q.objectives[1].text="Localized event wording";Q:Refresh();assert(Q.events==1)
q.objectives[3]=objective("Other event","event",true);Q:Refresh();assert(Q.events==0)
q.objectives[1].text="Explore the ruined tower";Q:Refresh();assert(Q.events==1)
q.objectives[3].text=q.objectives[1].text;Q:Refresh();assert(Q.events==0)
q.objectives[3]=nil;q.objectives[1].type="spell";Q:Refresh();assert(Q.events==0)
''',
"events_empty_or_unknown_live_progress_not_invented":EVENTS+r'''
q.objectives={};Q:Refresh();assert(Q.matched==0 and #Q.groups==0)
q.objectives={objective("Explore the ruined tower","event")};q.objectives[1].finished=nil
Q:Refresh();assert(Q.events==0 and Q.missing==1)
q.objectives[1].finished=false;Q:Refresh();assert(Q.events==1)
''',
"events_no_ordinary_objectives_table_required":EVENTS+r'''
data.Quest[9101].objectives=nil;q.objectives={objective("Explore the ruined tower","event")}
Q:Refresh(true);assert(Q.events==1 and Q.missing==0)
local old=FP.API.GetMapInfo
FP.API.GetMapInfo=function()return {mapType=4}end
Q:Refresh(true);assert(Q.events==0 and Q.missing==1)
FP.API.GetMapInfo=old;data.Quest[9101].triggerEnd[2]={[15]={{-1,-1},{"bad",55},{},{45,55}}}
Q:Refresh(true);assert(Q.events==1 and #Q.groups[1].points==1)
''',
"events_credit_targets_use_members_not_root_dummy":OBJECTIVES+r'''
data.Npc[99]={name="Invisible credit dummy",spawns={[15]={{99,99}}}}
data.Quest[9101].objectives={[5]={{{11,12},99,"Creatures freed",17}}}
q.objectives={objective("Creatures freed: 0/3","monster")};Q:Refresh(true)
assert(Q.events==1 and Q.groups[1].kind=="Credit" and #Q.groups[1].points==5)
for _,p in ipairs(Q.groups[1].points) do assert(p.entityID~=99 and p.role=="credit") end
q.objectives[1].text="Different credit text: 0/3";Q:Refresh();assert(Q.events==1)
q.objectives[2]=objective("Other creature slain","monster",true);Q:Refresh();assert(Q.events==0)
q.objectives[1].text="Creatures freed: 0/3";Q:Refresh();assert(Q.events==1)
data.Quest[9101].objectives[1]={{11}};q.objectives[1].text="Different credit text";q.objectives[2]=nil
Q:Refresh(true);assert(Q.events==0)
''',
"events_credit_and_ordinary_matching_ambiguity":OBJECTIVES+r'''
data.Quest[9101].objectives={[1]={{11}},[5]={{{12},11,nil,0}}}
q.objectives={objective("Cave Spider slain: 0/3","monster")};Q:Refresh(true)
assert(Q.matched==0 and Q.missing==1)
''',
"events_quest_hints_are_separate_and_never_auto_route":EVENTS+r'''
data.Quest[9101].extraObjectives={
 {{[15]={{46,56}}},4,"Use the brazier",0},
 {nil,4,"Talk to the scout",0,{{"monster",13}}},
 {nil,4,"Indexed hint not safely bound",1,{{"object",21}}},
}
Q:Refresh(true);assert(Q.events==1 and Q.hints==2 and Q.matched==2)
local g;for _,row in ipairs(Q.groups)do if row.kind=="Hint"then g=row;break end end
assert(g and not g.objIndex)
local saved=Q.groups;Q.groups={g};assert(not Q:Nearest(9101,1) and not Q:Nearest(9101,nil));Q.groups=saved
local pin=eventPin("Hint");assert(Q:Guide(pin) and active().title:find("Hint:",1,true))
assert(active().desc:find("individual objective progress is not tracked",1,true))
q.objectives[1].finished=true;Q:Refresh();assert(active() and Q.hints==2)
M.complete[9101]=true;Q:Refresh();assert(not active() and #Q.groups==0)
''',
"events_hint_references_and_custom_coordinates_do_not_mix":EVENTS+r'''
data.Quest[9101].extraObjectives={
 {{[15]={{99,99}}},4,"Open the crate",0,{{"object",21}}},
 {nil,4,"Obtain the key",0,{{"item",32}}},
}
Q:Refresh(true);assert(Q.hints==2)
for _,g in ipairs(Q.groups)do if g.kind=="Hint"then for _,p in ipairs(g.points)do assert(p.x~=.99)end end end
local last=Q.groups[#Q.groups];assert(#last.points==3 and last.points[1].entityID==11)
''',
"events_hint_display_toggle_and_selected_quest_filter":EVENTS+HUB+r'''
data.Quest[9101].extraObjectives={{{[15]={{46,56}}},4,"Use the brazier",0}}
Q:Refresh(true);assert(eventPin("Hint"))
page("display");check("displayquestEventHints",false);assert(not eventPin("Hint") and eventPin("Event"))
check("displayquestEventHints",true);assert(eventPin("Hint"))
FP.settings.questSelectedOnly=true;C_SuperTrack={GetSuperTrackedQuestID=function()return 9102 end}
assert(#Q:WorldPins(1445)==0)
page("navigation");assert(Q:Summary():find("1 event/credit objectives; 1 quest hints",1,true))
assert(FP.db.questLocations.events==1 and FP.db.questLocations.hints==1)
''',
"events_clicked_objective_follows_reordering_and_cleans_up":EVENTS+r'''
assert(Q:Guide(eventPin("Event")))
local wp=active();q.objectives[1],q.objectives[2]=q.objectives[2],q.objectives[1]
Q:Refresh();assert(active()==wp and wp.source.objIndex==2)
q.objectives[1].finished=true;Q:Refresh();assert(active()==wp)
q.objectives[2].finished=true;Q:Refresh();assert(not active())
''',
"events_stale_pin_click_rejects_completed_or_missing_target":EVENTS+r'''
local pin=eventPin("Event");q.objectives[1].finished=true
assert(Q:Guide(pin)==false and not active())
q.objectives[1].finished=false;Q:Refresh();pin=eventPin("Event")
M.quests={};assert(Q:Guide(pin)==false and #Q.groups==0)
''',
"events_native_navigation_wins_and_manual_route_survives_refresh":EVENTS+r'''
M.mapID=1445;M.px=.45;M.py=.55;FP.Pos:Refresh(true)
local m,x,y,how=FP.Planner:ResolveObjective(9101,1)
assert(m==1445 and x==.45 and how:find("event completion area:",1,true))
q.waypoint={1445,.2,.3};m,x,y,how=FP.Planner:ResolveObjective(9101,1);assert(x==.2 and how=="waypoint")
cmd("way 60 60 My manual waypoint");local wp=active()
q.objectives[1].finished=true;Q:Refresh();assert(active()==wp)
''',
"events_minimap_and_automatic_lifecycle_without_commands":EVENTS+r'''
M.mapID=1445;M.px=.45;M.py=.55;FP.Pos:Refresh(true)
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
local found=false
for _,f in ipairs(FP.Pins.objectiveMini)do if f:IsShown()then for _,e in ipairs(f.point.entries)do if e.group.kind=="Event"then found=true end end end end
assert(found)
q.objectives[1].finished=true;M.FireEvent("QUEST_LOG_UPDATE");M.RunTimers(1);M.RunTimers(1)
assert(Q.events==0)
assert(#FP.db.errors==0)
''',
"events_malformed_reference_data_is_bounded_and_protected":EVENTS+r'''
data.Quest[9101].triggerEnd={"Explore the ruined tower",{[15]={false,{}, {45,55}, {0/0,1}}}}
data.Quest[9101].extraObjectives={{nil,4,"Unknown binding",nil},false,{nil,4,"Bad refs",0,{false}}}
Q:Refresh(true);assert(Q.events==1 and Q.hints==0)
data.Quest[9101].triggerEnd={"Explore the ruined tower",{[15]={{M.Secret(),55}}}}
Q:Refresh(true);assert(Q.events==0 and #FP.db.errors==0)
assert(not FP.API.GetQuestReference(nil))
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
