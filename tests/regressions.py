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
if not HearthAndHustleDB and not ForeverPathDB then HearthAndHustleDB={settings={record=true,probe={enabled=true}}} end
for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then
        assert(loadfile("HearthAndHustle/" .. line:gsub("\\", "/")))("HearthAndHustle", FP)
    end
end
M.FireEvent("ADDON_LOADED", "HearthAndHustle")
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
local function cmd(s) SlashCmdList.HEARTHANDHUSTLE(s) end
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

GEAR = r'''
local G=FP.Gear
local function item(id,loc,stats,extra)
 local row={id=id,name="Gear "..id,equipLoc=loc,classID=4,subclassID=1,level=25,minLevel=20,
 stats=stats or {},sources={"Test Dungeon"},sourceTypes={"Dungeon"},bosses={},subtype="Cloth"}
 for k,v in pairs(extra or {}) do row[k]=v end
 return row
end
FP.API.GetCharInfo=function() return {name="Tester",class="MAGE",level=30} end
FP.API.PlayerLevel=function() return 30 end
local a=item(1001,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10})
local b=item(1002,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=20})
FP.GearCatalog={date="fixture",items={a,b}}
'''

GEAR_CASES = {
 "gear_rank_filters_unknown_and_ties": GEAR + r'''
local rows=G:Rows({slot="HEAD",level=30});assert(#rows==2 and rows[1].key==1002)
a.stats.ITEM_MOD_INTELLECT_SHORT=20
rows=G:Rows({slot="HEAD",level=30});assert(rows[1].key==1001)
a.minLevel=nil;a.level=nil;b.minLevel=31
rows=G:Rows({slot="HEAD",level=30});assert(#rows==0)
rows=G:Rows({slot="HEAD",level=30,unknown=true});assert(#rows==1 and rows[1].key==1001)
rows=G:Rows({slot="HEAD",level=30,unknown=true,source="Quest"});assert(#rows==0)
rows=G:Rows({slot="HEAD",level=60,query="1002"});assert(#rows==1 and rows[1].key==1002)
rows=G:Rows({slot="FEET",level=60});assert(#rows==0)
''',
 "gear_class_armor_weapons_relics": GEAR + r'''
for class in pairs(G.classProfiles) do
 local char={class=class,level=30}
 assert(G:ClassMatches(a,char),class)
 assert(not G:ClassMatches(item(3,"INVTYPE_HEAD",{}, {subclassID=4}),char))
end
assert(G:ClassMatches(item(4,"INVTYPE_HEAD",{}, {subclassID=4}),{class="WARRIOR",level=40}))
assert(not G:ClassMatches(item(4,"INVTYPE_HEAD",{}, {classes="Priest"}),{class="MAGE",level=60}))
assert(not G:ClassMatches(item(5,"INVTYPE_WEAPON",{}, {classID=2,subclassID=7}),{class="SHAMAN",level=60}))
assert(G:ClassMatches(item(6,"INVTYPE_RELIC",{}, {subclassID=9}),{class="SHAMAN",level=60}))
assert(not G:ClassMatches(item(6,"INVTYPE_RELIC",{}, {subclassID=9}),{class="MAGE",level=60}))
assert(not G:ClassMatches(a,{class="UNKNOWN",level=60}))
''',
 "gear_weights_affect_rank_and_ranged_dps_scope": GEAR + r'''
a.stats.ITEM_MOD_STAMINA_SHORT=100
FP.cdb.gear.weights.caster={int=0,sta=1}
assert(G:Rows({slot="HEAD"})[1].key==1001)
FP.cdb.gear.weights.caster={int=0/0,sta=-4}
local w=G:Weights();assert(w.int==1 and w.sta==.3)
assert(G:Score({ITEM_MOD_SPELL_POWER_SHORT=44},{heal=1},"MAIN")==44)
assert(G:Score({ITEM_MOD_SPELL_HEALING_DONE_SHORT=124,ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=41},{heal=1},"MAIN")==124)
assert(G:Score({ITEM_MOD_SPELL_HEALING_DONE_SHORT=124,ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=41},{spell=1},"MAIN")==41)
assert(G:Score(nil,w,"HEAD")==nil)
assert(G:Score({ITEM_MOD_INTELLECT_SHORT=0/0},w,"HEAD")==nil)
assert(G:Score({ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},{dps=6,ranged=true},"MAIN")==0)
assert(G:Score({ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},{dps=6,ranged=true},"RANGED")==60)
assert(G:Score({ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},{dps=6},"RANGED")==0)
''',
 "gear_all_class_profiles_and_cross_character_setting": GEAR + r'''
for class,keys in pairs(G.classProfiles) do
 FP.API.GetCharInfo=function() return {class=class,level=30} end
 FP.cdb.gear.profile="unrecognized"
 local key,p=G:Profile();assert(key==keys[1] and p.name and G:Weights())
 for _,k in ipairs(keys) do FP.cdb.gear.profile=k;assert(G:Profile()==k) end
end
''',
 "gear_combat_pauses_without_item_reads": GEAR + r'''
FP.API.InCombat=function() return true end
FP.API.GetRewardItem=function() error("item read in combat") end
FP.API.GetRewardEquipment=function() error("equipment read in combat") end
assert(#G:Rows({})==0)
assert(G:Details({item=a},"HEAD"):find("after combat"))
assert(#FP.API.GetGearQuestSources(1001)==0)
''',
 "gear_comparisons_unknown_rings_and_hand_warning": GEAR + r'''
local called={}
FP.API.GetRewardItem=function() return nil end
FP.API.GetRewardEquipment=function(slot) called[#called+1]=slot;return {status="unknown"} end
local row={item=a,score=10,rank=1}
local details=G:Details(row,"FINGER");assert(details:find("unavailable") and called[1]==11 and called[2]==12)
assert(not details:find("stat%-score change"))
FP.API.GetRewardItem=function() return {stats={ITEM_MOD_INTELLECT_SHORT=12}} end
FP.API.GetRewardEquipment=function() return {status="empty",stats={}} end
assert(G:Details(row,"HEAD"):find("%+12.0"))
assert(not G:Details(row,"MAIN"):find("stat%-score change"))
assert(G:Details(row,"MAIN"):find("both hands"))
''',
 "gear_gui_filter_wishlist_and_weights_transaction": HUB + GEAR + r'''
page("gear");assert(#H.controls.gearItems.items==2)
selectRow("gearItems",1);click("gearSave");assert(FP.cdb.gear.wishlist[1002])
click("gearWishlist");assert(#H.controls.gearItems.items==1)
click("gearSave");assert(#H.controls.gearItems.items==0)
click("gearWishlist");field("gearLevel","bad");H.controls.gearLevel:GetScript("OnTextChanged")()
assert(#H.controls.gearItems.items==0)
field("gearLevel",30);H.controls.gearLevel:GetScript("OnTextChanged")();assert(#H.controls.gearItems.items==2)
click("gearWeights");local P=FP.GearPanel;assert(P.weightsFrame:IsShown())
P.weightFields.int:SetText("bad");P.weightApply:GetScript("OnClick")();assert(P.weightsFrame:IsShown() and not FP.cdb.gear.weights.caster)
P.weightFields.int:SetText("2");P.weightApply:GetScript("OnClick")();assert(FP.cdb.gear.weights.caster.int==2 and not P.weightsFrame:IsShown())
click("gearWeights");page("home");assert(not P.weightsFrame:IsShown())
page("gear");assert(H.controls.gearLevel:GetText()=="30")
assert(#FP.db.errors==0)
''',
 "gear_gui_source_links_and_browse_preserves_route": HUB + GEAR + r'''
cmd("way 60 60 Preserve")
local before=snapshot(FP.Waypoints.list)
FP.API.GetGearQuestSources=function() return {{id=9001,name="One"},{id=9002,name="Two"}} end
page("gear");assert(FP.GearPanel.sourceIndex==1)
click("gearNextQuestSource");assert(FP.GearPanel.sourceIndex==2)
local inspected
H.OpenQuestChain=function(self,id) inspected=id end
click("gearQuestSource");assert(inspected==9002)
assert(snapshot(FP.Waypoints.list)==before)
assert(FP.GearPanel:Dungeon({item={sourceTypes={"Quest","Dungeon"},sources={"Quest Rewards","The Deadmines"}}})=="The Deadmines")
''',
 "gear_provider_missing_bad_ids_and_errors": r'''
local API=FP.API
assert(#API.GetGearQuestSources(nil)==0 and #API.GetGearQuestSources(0)==0)
API.QuestDatabaseStatus=function() return true end
LibQuestieDB={Item={Get=function(id,key) assert(key=="questRewards");return {1,1,-2,0/0,2} end}}
API.GetQuestChainRecord=function(id) return {id=id,name="Quest "..id} end
local sources=API.GetGearQuestSources(1001);assert(#sources==2 and sources[1].id==1 and sources[2].id==2)
LibQuestieDB.Item.Get=function() error("provider failed") end
assert(#API.GetGearQuestSources(1001)==0)
''',
 "gear_catalog_forever_integrity_and_coverage": r'''
local seen,slots,classes={}, {}, {}
assert(FP.API.EnsureGearCatalog())
assert(#FP.GearCatalog.items>8000)
for _,item in ipairs(FP.GearCatalog.items) do
 assert(not seen[item.id]);seen[item.id]=true
 assert(#item.sources==#item.sourceTypes and #item.sources>0)
 assert(item.minLevel==nil or item.minLevel>=0)
 assert(not item.name:find("[TMP]",1,true))
 slots[item.equipLoc]=true
 for k,v in pairs(item.stats) do assert(FP.Util.Finite(v) and v>=0) end
end
for class in pairs(FP.Gear.classProfiles) do
 FP.API.GetCharInfo=function() return {class=class,level=60} end
 assert(#FP.Gear:Rows({slot="HEAD",level=60})>0,class)
end
assert(slots.INVTYPE_HEAD and slots.INVTYPE_FINGER and slots.INVTYPE_2HWEAPON)
assert(seen[7714] and seen[6504])
''',
 "hub_overview_cards_today_features_and_dungeon_entry": HUB + r'''
page("home")
for _,key in ipairs({"navigation","gear","rewards","chains","dungeons","town"}) do
 page("home");click("home_"..key);assert(H.selected==key)
end
page("dungeons");selectRow("hubDungeons",1);local key=H.controls.hubDungeons.items[1].key
click("openDungeonChecklist");assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==key)
assert(#FP.db.errors==0)
''',
}

CASES = {
    **GEAR_CASES,
    "hub_all_sections_are_read_only_and_reuse_frames": HUB + r'''
cmd("way 60 60 Preserve")
local beforeSettings,beforeData,beforeChar=snapshot(FP.settings),snapshot(FP.data),snapshot(FP.cdb)
local calls=0
FP.Party.Send=function() calls=calls+1 end
FP.Vendor.SellClicked=function() calls=calls+1 end
FP.Vendor.RepairClicked=function() calls=calls+1 end
HearthAndHustle_OnAddonCompartmentClick()
assert(H.frame:IsShown() and H.selected=="home")
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
click("pause"); assert(FP.Planner.paused and FP.settings.autoNext and active())
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
local list=H.controls.rareList; list.selected=tostring(FP.RareWatch:Watch().rares[original+1].id or "")..":"..FP.RareWatch:Watch().rares[original+1].name; H:Refresh(); click("rareRemove")
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
click("resetAccount"); assert(H.pending and HearthAndHustleDB)
H:Toggle(); assert(not H.pending and HearthAndHustleDB, "closing left a destructive action armed")
page("navigation"); click("clearRoute"); H.confirmYes:GetScript("OnClick")()
assert(not active() and FP.Planner.paused and not H.pending)
local account=HearthAndHustleDB
page("tools"); click("resetCharacter")
assert(HearthAndHustleCharDB and HearthAndHustleDB==account)
H.confirmYes:GetScript("OnClick")()
assert(HearthAndHustleCharDB==nil and HearthAndHustleDB==account)
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
local pvpManual=FP.settings.pvp.manual;click("prepShow"); assert(FP.settings.pvp.manual==pvpManual and FP.cdb.prep.mode=="show")
click("prepAuto"); assert(FP.cdb.prep.mode=="auto")
click("prepHide"); assert(FP.cdb.prep.mode=="hide")
for _,id in ipairs({"prepReport","junkValue","trainerLookup"}) do click(id) end
page("rare"); click("rareStatus"); click("rareRuns")
page("display"); assert(not H.controls.audioStatus and not H.controls.audioTest and not H.controls.hunterAudio)
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
HearthAndHustle_OnAddonCompartmentClick()
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
for _,name in ipairs(UISpecialFrames) do if name=="HearthAndHustleDisplaySettings" then count=count+1 end end
assert(count==1, "escape registration duplicated on reopen")
assert(FP.settings==HearthAndHustleDB.settings and #FP.db.errors==0)
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
local saved=FP.Util.Copy(HearthAndHustleDB)
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

    "npc_offers_fill_empty_map_list_without_recording": r"""
FP.settings.record=false
M.mapID=1424; M.px,M.py=.61,.20; FP.Pos:Refresh(true)
M.SetUnit("npc",{guid="Creature-0-1-0-0-2319-00001",name="Melisara"})
M.gossipAvailable={{questID=495,title="The Crown of Will",questLevel=39}}
assert(#FP.API.GetQuestOffers(M.mapID)==0, "standing nearby is not an observation")
M.FireEvent("GOSSIP_SHOW"); M.RunTimers(.2)
local offers,counts=FP.API.GetQuestOffers(M.mapID)
assert(#offers==1 and offers[1].questID==495 and counts.map==0 and counts.npc==1)
assert(offers[1].title=="The Crown of Will" and offers[1].how:find("Melisara"))
assert(offers[1].x==.61 and offers[1].y==.20)
assert(#FP.Planner.steps==1 and FP.Planner.steps[1].kind=="pickup")
M.FireEvent("GOSSIP_CLOSED"); M.units.npc=nil; M.px=.65
local again=FP.API.GetQuestOffers(M.mapID)
assert(#again==1 and again[1].x==.61, "must retain interaction position, not follow player")
cmd("apicheck")
local row=FP.db.apicheck["70124-manual"].rows["probe:questOffers"]
assert(row.ok and row.note:find("1 recent NPC%-confirmed"))
addQuest(495); M.FireEvent("QUEST_ACCEPTED",495)
assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.RemoveQuest(495); assert(#FP.API.GetQuestOffers(M.mapID)==0,"abandon must not resurrect stale offer")
assert(#FP.db.errors==0)
""",
    "npc_offers_greeting_detail_dedup_and_refresh": r"""
FP.settings.record=false
M.SetUnit("questnpc",{guid="Creature-0-1-0-0-2319-00001",name="Melisara"})
C_GossipInfo=nil
GetNumAvailableQuests=function() return 1 end
GetAvailableQuestInfo=function() return false,0,false,false,495 end
GetAvailableTitle=function() return "The Crown of Will" end
M.FireEvent("QUEST_GREETING")
assert(#FP.API.GetQuestOffers(M.mapID)==1)
M.dialogQuest=496; M.FireEvent("QUEST_DETAIL")
assert(#FP.API.GetQuestOffers(M.mapID)==2,"direct detail must supplement greeting")
C_QuestLine={GetAvailableQuestLines=function() return {{questID=495,x=.7,y=.8,questName="The Crown of Will"}} end}
local offers,c=FP.API.GetQuestOffers(M.mapID)
assert(#offers==2 and c.map==1 and c.npc==2)
assert(offers[1].x==.7,"prefer native coordinate for duplicate quest")
C_QuestLine=nil
GetNumAvailableQuests=function() return 0 end
M.FireEvent("QUEST_GREETING")
assert(#FP.API.GetQuestOffers(M.mapID)==0,"revisit must replace withdrawn offers")
M.FireEvent("QUEST_DETAIL"); M.now=M.now+301
assert(#FP.API.GetQuestOffers(M.mapID)==0,"expire historical sightings")
M.FireEvent("QUEST_DETAIL"); M.mapID=1424
assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.mapID=1413; assert(#FP.API.GetQuestOffers(M.mapID)==0,"map change discards old observation")
assert(#FP.db.errors==0)
""",
    "npc_offers_do_not_infer_from_target_or_bad_context": r"""
FP.settings.record=false
M.SetUnit("target",{guid="Creature-0-1-0-0-2319-00001",name="Melisara"})
M.dialogQuest=495; M.FireEvent("QUEST_DETAIL")
assert(#FP.API.GetQuestOffers(M.mapID)==0,"item/remote quest cannot use unrelated target")
M.units.npc=M.units.target; M.noPosition=true; M.FireEvent("QUEST_DETAIL")
assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.noPosition=false; M.combatLockdown=true; M.FireEvent("QUEST_DETAIL")
assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.combatLockdown=false; M.units.npc={guid="Creature-0-1-0-0-2319-00001",name="Melisara",secret=true}
M.FireEvent("QUEST_DETAIL"); assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.units.npc=M.units.target
M.gossipAvailable={{questID=0/0},{questID=math.huge},{questID=1.5},{questID=-2},{questID="495"}}
M.FireEvent("GOSSIP_SHOW"); assert(#FP.API.GetQuestOffers(M.mapID)==0)
M.gossipAvailable={{questID=495,title="The Crown of Will"}}
cmd("way 80 80 My destination"); M.FireEvent("GOSSIP_SHOW"); M.RunTimers(.2)
assert(active().title=="My destination","offer must preserve manual route")
M.FireEvent("ZONE_CHANGED_NEW_AREA"); assert(#FP.API.GetQuestOffers(M.mapID)==0)
assert(#FP.db.errors==0)
""",
    "npc_offer_repeatable_lifecycle_and_expired_route": r"""
FP.settings.record=false
M.SetUnit("npc",{guid="Creature-0-1-0-0-2319-00001",name="Melisara"})
M.dialogQuest=495
C_QuestLog.IsQuestFlaggedCompleted=function(id) return id==495 end
M.FireEvent("QUEST_DETAIL",12345)
assert(#FP.API.GetQuestOffers(M.mapID)==0,"item start cannot be attributed to open NPC")
QuestIsFromAreaTrigger=function() return true end
M.FireEvent("QUEST_DETAIL"); assert(#FP.API.GetQuestOffers(M.mapID)==0)
QuestIsFromAreaTrigger=nil
M.FireEvent("QUEST_DETAIL")
assert(#FP.API.GetQuestOffers(M.mapID)==1,"current offer overrides prior completion for repeatables")
M.RunTimers(.2); M.px=.1; FP.Pos:Refresh(true); cmd("pickups")
assert(active() and active().source.questID==495)
FP.Planner:CheckActive(); assert(active(),"completed repeatable remains an offered pickup")
M.now=M.now+301; FP.Planner:CheckActive()
assert(not active(),"expired NPC offer must clear even a pinned pickup route")
M.FireEvent("QUEST_DETAIL"); M.FireEvent("QUEST_TURNED_IN",495,0,0)
assert(#FP.API.GetQuestOffers(M.mapID)==0)
assert(#FP.db.errors==0)
""",
    "npc_offer_cache_is_bounded": r"""
FP.settings.record=false
M.SetUnit("npc",{guid="Creature-0-1-0-0-2319-00001",name="Melisara"})
M.gossipAvailable={}
for id=10000,10110 do M.gossipAvailable[#M.gossipAvailable+1]={questID=id,title="Offer "..id} end
M.FireEvent("GOSSIP_SHOW")
assert(#FP.API.GetQuestOffers(M.mapID)==100)
assert(#FP.db.errors==0)
""",
    "empty_pickup_probe_explains_incomplete_coverage": r"""
cmd("apicheck")
local row=FP.db.apicheck["70124-manual"].rows["probe:questOffers"]
assert(not row.ok and row.note:find("0 map%-listed") and row.note:find("may be incomplete"))
assert(not row.note:find("0 available pickups"))
""",

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
M.FireEvent("CHAT_MSG_ADDON", "HHUSTLE", "FP1;Friend;MAGE;20;9001", "PARTY", "Friend-Realm")
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
for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then assert(loadfile("HearthAndHustle/" .. line:gsub("\\", "/")))("HearthAndHustle", nextFP) end
end
M.FireEvent("ADDON_LOADED", "HearthAndHustle"); M.FireEvent("PLAYER_LOGIN")
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
HearthAndHustleDB = {settings={record=false}}
HearthAndHustleCharDB = nil
local nextFP = {}
for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
    line=line:gsub("\r", "")
    if line:match("%.lua$") then assert(loadfile("HearthAndHustle/" .. line:gsub("\\", "/")))("HearthAndHustle",nextFP) end
end
M.AddQuest({questID=9001,title="Quest",objectives={}})
M.FireEvent("ADDON_LOADED", "HearthAndHustle"); M.FireEvent("PLAYER_LOGIN")
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
for i=#messages,1,-1 do M.FireEvent("CHAT_MSG_ADDON","HHUSTLE",messages[i],"PARTY","Friend-Realm") end
assert(FP.Util.Count(FP.cdb.party.quests)==40 and FP.cdb.party.complete[100040])
''',
    "party_live_state_cleared_but_paste_seed_retained": r'''
IsInGroup=function() return true end
M.SetUnit("party1",{name="Friend",realm="Realm"})
M.FireEvent("CHAT_MSG_ADDON","HHUSTLE","FP1;Friend;MAGE;20;9001","PARTY","Friend-Realm")
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
M.FireEvent("CHAT_MSG_ADDON","HHUSTLE","FP1;Stranger;MAGE;20;9001","WHISPER","Stranger-Realm")
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
    local pin
    for _,candidate in ipairs(WorldMapFrame._pins) do if candidate.wp then pin=candidate;break end end
    assert(pin)
    assert(pin.wp.source.type=="plan")
    assert(not pin:IsMouseMotionEnabled(), "planned pin blocks quest hover")
    assert(not pin:IsMouseClickEnabled(), "planned pin blocks quest click")
    assert(pin:ShouldMouseButtonBePassthrough("RightButton"), "planned pin consumes map zoom-out")
    assert(pin:GetFrameLevel()<WorldMapFrame:GetPinFrameLevelsManager():GetFrameLevelStart("PIN_FRAME_LEVEL_ACTIVE_QUEST"), "pin still covers native quest markers")
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
    assert(#pin._passthrough==0, "passive pins should disable mouse input without passthrough")
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
assert(pin:GetFrameLevel()<WorldMapFrame:GetPinFrameLevelsManager():GetFrameLevelStart("PIN_FRAME_LEVEL_ACTIVE_QUEST"), "manual pin still covers native quest markers")
assert(pin:IsMouseMotionEnabled() and pin:IsMouseClickEnabled())
''',
    "map_pin_callbacks_do_not_replace_or_hide_native_tooltips": r'''
addQuest(9001); FP.Planner:Tick(); FP.Pins.provider:RefreshAllData()
local pin
for _,candidate in ipairs(WorldMapFrame._pins) do if candidate.wp then pin=candidate;break end end
assert(pin)
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
assert(SLASH_HEARTHANDHUSTLEWAY1 == "/way")
SlashCmdList.HEARTHANDHUSTLEWAY("45.4 70.4")
local wp=active()
assert(wp and wp.mapID==1413)
assert(math.abs(wp.x-.454)<1e-12 and math.abs(wp.y-.704)<1e-12)
addQuest(9001); M.RunTimers(4)
assert(active().id==wp.id, "auto route replaced /way target")
SlashCmdList.HEARTHANDHUSTLEWAY("45.4 70.4 Quest cave")
assert(active().title=="Quest cave")
cmd("way 45.4 70.4 Quest cave")
assert(active().mapID==wp.mapID and active().x==wp.x and active().y==wp.y)
''',
    "way_shortcut_map_edges_and_invalid_input": r'''
SlashCmdList.HEARTHANDHUSTLEWAY("12 45.4 70.4 Other zone")
assert(active().mapID==12 and active().title=="Other zone")
SlashCmdList.HEARTHANDHUSTLEWAY("0 100 Map edge")
assert(active().x==0 and active().y==1)
SlashCmdList.HEARTHANDHUSTLEWAY("0.5 1 Near edge")
assert(active().x==.005 and active().y==.01)
local n=#FP.Waypoints.list
for _, input in ipairs({"-1 70.4", "45.4 100.1", "1e309 70.4", "45.4", "foo bar", "12 45.4 101"}) do
    SlashCmdList.HEARTHANDHUSTLEWAY(input)
end
assert(#FP.Waypoints.list==n)
assert(#(FP.db.errors or {})==0)
''',
    "way_shortcut_management_commands": r'''
SlashCmdList.HEARTHANDHUSTLEWAY("45.4 70.4 First")
local first=active().id
SlashCmdList.HEARTHANDHUSTLEWAY("46 71 Second")
SlashCmdList.HEARTHANDHUSTLEWAY("next")
assert(active().id==first)
SlashCmdList.HEARTHANDHUSTLEWAY("rm "..first)
assert(not FP.Waypoints:Get(first))
SlashCmdList.HEARTHANDHUSTLEWAY("clear")
assert(#FP.Waypoints.list==0)
SlashCmdList.HEARTHANDHUSTLEWAY("here Home")
assert(active().title=="Home" and active().persistent)
SlashCmdList.HEARTHANDHUSTLEWAY("")
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
HearthAndHustleDB={version=1,data={creatures={[7001]={loot={[4306]=4},looted=1,pos={{m=1413,x=.5,y=.5}}}},
    quests={[9001]={obj={{mobs={[7001]=2}}},items={[4306]={[7001]=1}}}}}}
HearthAndHustleCharDB=nil
local nextFP={}
for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
    if line:match("%.lua$") then assert(loadfile("HearthAndHustle/"..line:gsub("\\","/")))("HearthAndHustle",nextFP) end
end
M.FireEvent("ADDON_LOADED","HearthAndHustle")
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
HearthAndHustleDB={version=1}
HearthAndHustleCharDB={party={name="Friend",from="paste",quests={[9001]=true},complete={}}}
local nextFP={}
for line in io.lines("HearthAndHustle/HearthAndHustle.toc") do
    if line:match("%.lua$") then assert(loadfile("HearthAndHustle/"..line:gsub("\\","/")))("HearthAndHustle",nextFP) end
end
M.FireEvent("ADDON_LOADED","HearthAndHustle"); M.FireEvent("PLAYER_LOGIN")
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
assert(active() and active().source.questID==9001, "idle planner requires /hh next")
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
local function msg(body,channel,sender) M.FireEvent("CHAT_MSG_ADDON","HHUSTLE",body,channel or "PARTY",sender or "Friend-Realm") end
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
    for _,r in ipairs(FP.ClassPrep.rows or {}) do if r.key==key then return r end end
end
FP.ClassPrep:Refresh()
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
FP.ClassPrep:Refresh(); assert(prepRow("water").count==nil and prepRow("water").missing==nil)
C_Item.GetItemInfo=original; M.FireEvent("GET_ITEM_INFO_RECEIVED",159,true); M.RunTimers(1)
assert(prepRow("water").count==22)
C_SpellBook.IsSpellKnown=nil; FP.ClassPrep:Refresh()
assert(not prepRow("gem:5514") and not prepRow("reagent:17031"))
assert(table.concat((function() local t={} for _,r in ipairs(FP.ClassPrep.rows) do t[#t+1]=r.text end return t end)(), " "):find("spells unavailable",1,true))
C_Container.GetContainerNumSlots=nil; FP.ClassPrep:Refresh()
assert(#FP.ClassPrep.rows==1 and not prepRow("water"))
''',
    "mage_prep_never_scans_inventory_or_spells_during_combat": PREP_SETUP + r'''
M.FireEvent("PLAYER_REGEN_DISABLED")
C_Container.GetContainerNumSlots=function() error("combat bag read") end
C_SpellBook.IsSpellKnown=function() error("combat spell read") end
M.FireEvent("BAG_UPDATE_DELAYED"); M.RunTimers(2)
FP.ClassPrep:Refresh(); cmd("prep")
assert(#FP.ClassPrep:Lines()==0)
assert(M.Chat()[#M.Chat()]:find("after combat",1,true))
''',
    "mage_prep_auto_visibility_and_user_controls": PREP_SETUP + r'''
FP.ClassPrep.untilTime=0; FP.ClassPrep.bg=false
assert(#FP.ClassPrep:Lines()==0)
M.FireEvent("MERCHANT_SHOW"); M.RunTimers(1); assert(#FP.ClassPrep:Lines()>0)
M.FireEvent("MERCHANT_CLOSED"); assert(#FP.ClassPrep:Lines()==0)
M.bg=true; M.FireEvent("ZONE_CHANGED_NEW_AREA"); M.RunTimers(1); assert(#FP.ClassPrep:Lines()>0)
M.bg=false; M.FireEvent("ZONE_CHANGED_NEW_AREA"); M.RunTimers(25); assert(#FP.ClassPrep:Lines()==0)
cmd("prep show"); M.RunTimers(1); assert(#FP.ClassPrep:Lines()>0)
cmd("prep hide"); assert(#FP.ClassPrep:Lines()==0)
cmd("prep auto"); M.RunTimers(1); assert(#FP.ClassPrep:Lines()>0)
cmd("prep off"); assert(#FP.ClassPrep:Lines()==0)
cmd("prep on"); M.RunTimers(1); assert(#FP.ClassPrep:Lines()>0)
''',
    "mage_prep_goals_are_validated_and_character_specific": PREP_SETUP + r'''
cmd("prep water 60"); M.RunTimers(1)
assert(FP.cdb.prep.water==60 and prepRow("water").missing==38)
cmd("prep water -1"); cmd("prep water 1e309"); cmd("prep water 2.5"); cmd("prep water 201")
assert(FP.cdb.prep.water==60)
cmd("prep bandages 0"); M.RunTimers(1); assert(not prepRow("bandages"))
assert(not FP.settings.prep and FP.charDefaults.prep.water==40)
''',
    "class_prep_warrior_has_food_and_bandages_without_mage_supplies": PREP_SETUP + r'''
M.class="WARRIOR";FP.ClassPrep:Refresh();cmd("prep show");M.RunTimers(1)
assert(#FP.ClassPrep:Lines()>0)
assert(prepRow("food").count==99 and prepRow("bandages").count==5)
assert(not prepRow("water") and not prepRow("gem:5514") and not prepRow("reagent:17031"))
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
assert(FP.PvP.frame:IsShown() and FP.settings.pvp.manual=="hide")
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
assert(RW.scan:IsShown() and RW.scanPending and RW.frame:IsShown(), "secure button and its anchor retain geometry in combat")
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
M.FireEvent("CHAT_MSG_ADDON", "HHUSTLE", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Stranger")
assert(not RW:Current().seen, "outsider ignored")
M.FireEvent("CHAT_MSG_ADDON", "OTHER", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Hunterbro")
assert(not RW:Current().seen, "other prefix ignored")
for _, bad in ipairs({ "RW;up", "RW;up;33", "RW;bogus;1", "RW;kill;x", "RW;no;extra", "RW;up;" .. string.rep("x", 200) }) do
	assert(RW:Decode(bad) == nil, "malformed accepted: " .. bad)
end
assert(RW:Decode("RW;up;;;") and RW:Decode("RW;up;;;").level == nil, "empty fields decode")
local sent = #M.addonSent
M.FireEvent("CHAT_MSG_ADDON", "HHUSTLE", "RW;up;33;Undead;Azshir the Sleepless", "PARTY", "Hunterbro")
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
FP.ClassPrep:Refresh()
assert(prepRow("water").count==22 and not prepRow("gem:5514") and not prepRow("reagent:17031"))
assert(FP.ClassPrep.rows[#FP.ClassPrep.rows].text:find("chosen weapon imbue",1,true))
assert(not FP.ClassPrep:Summary():find("Enhancement",1,true) and not FP.ClassPrep:Summary():find("Duo:",1,true))
cmd("prep show"); assert(#FP.ClassPrep:Lines()>0)
M.class="HUNTER"; FP.ClassPrep:Refresh()
assert(prepRow("water") and not prepRow("gem:5514"))
assert(FP.ClassPrep.rows[#FP.ClassPrep.rows].text:find("pet supplies",1,true))
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
for _,p in ipairs(WorldMapFrame._pins)do if p._pinTemplate=="HearthAndHustleObjectivePinTemplate"then pin=p;break end end
assert(pin and pin:GetFrameLevel()<WorldMapFrame:GetPinFrameLevelsManager():GetFrameLevelStart("PIN_FRAME_LEVEL_ACTIVE_QUEST") and pin:IsMouseClickEnabled())
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
Q.worldCache={};local sparse=Q:WorldPins(1445);assert(#sparse==150)
FP.settings.questDensePins=true;local pins=Q:WorldPins(1445);assert(#pins==350)
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
local pool=FP.Pins.objectiveMini;assert(#pool>0 and #pool<=24)
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
GetNumQuestLogChoices=function(id,allowComplete) assert(id==selected and allowComplete==true);return 2 end
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
 {{[15]={{49,59}}},4,"Use the brazier",0},
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


DUNGEON_ROUTES=OBJECTIVES+r'''
local support={private={areaIdToUiMapId="return {[15]=1445,[17]=1413,[718]=9999,[10014]=9998}",dungeons={
 [718]={"Wailing Caverns",{10014},17,{{17,46,36.5},{15,40,50}}},
 [2017]={"Stratholme",nil,17,{{17,26.52,10.36},{15,41.45,17.74}}},
 [2437]={"Ragefire Chasm",nil,17,{{17,52.6,49}}},
 [1583]={"Blackrock Spire",nil,17,{{17,34.8,85.3},{15,29.4,38.3}}},
}}}
LibQuestieDB.Support.Get=function()return support end
M.mapID=1413;M.px=.4;M.py=.4;FP.Pos:Refresh(true)
'''
CASES.update({
"dungeon_entrances_authored_aliases_and_native_outdoor_maps":DUNGEON_ROUTES+r'''
local a=FP.API.GetDungeonEntrances(718);local b=FP.API.GetDungeonEntrances(10014)
assert(#a==2 and #b==2 and a[1].mapID==1413 and a[1].x==.46 and a[1].entrance)
assert(b[1].areaID==718 and a[1]~=b[1])
a[1].x=.9;assert(FP.API.GetDungeonEntrances(718)[1].x==.46,"provider data mutated")
assert(#FP.API.GetDungeonEntrances(99999)==0)
assert(#FP.Dungeons:Entrances("the-drowned-city")==0)
assert(FP.Dungeons:Entrances("stratholme-service-gate")[1].entranceIndex==2)
assert(FP.Dungeons:Entrances("stratholme-main-gate")[1].entranceIndex==1)
''',
"dungeon_sentinels_resolve_before_retired_floor_lookup":DUNGEON_ROUTES+r'''
data.Npc[11].spawns={[10014]={{-1,-1},{-1,-1},{25,30}},[718]={{20,20}},[15]={{30,40}}}
local refs=FP.API.GetQuestReference(9101);local pts=refs[1].points
assert(#pts==3,"duplicated sentinel or legacy floor accepted")
local entrances=0
for _,p in ipairs(pts)do assert(p.mapID~=9998 and p.mapID~=9999);if p.entrance then entrances=entrances+1;assert(p.dungeonName=="Wailing Caverns" and p.entityID==11 and p.role=="entrance")end end
assert(entrances==2)
''',
"dungeon_missing_malformed_entrances_never_invent_points":DUNGEON_ROUTES+r'''
data.Npc[11].spawns={[10014]={{-1,-1}}}
support.private.dungeons[718][4]={{17,101,20},{999999,30,40},false,{17,-1,-1}}
assert(#FP.API.GetDungeonEntrances(718)==0 and #FP.API.GetQuestReference(9101)[1].points==0)
support.private.dungeons[718]=false;assert(#FP.API.GetDungeonEntrances(10014)==0)
support.private.dungeons=nil;assert(#FP.API.GetDungeonEntrances(718)==0)
LibQuestieDB.Support.Get=function()error("provider unavailable")end
assert(#FP.API.GetDungeonEntrances(718)==0)
LibQuestieDB=nil;assert(#FP.API.GetDungeonEntrances(718)==0)
''',
"dungeon_outdoor_entrance_map_must_be_native_zone":DUNGEON_ROUTES+r'''
local old=FP.API.GetMapInfo
FP.API.GetMapInfo=function(id)if id==1413 then return {mapType=4} end return old(id)end
local p=FP.API.GetDungeonEntrances(718);assert(#p==1 and p[1].mapID==1445)
''',
"dungeon_objective_fallback_labels_click_and_native_priority":DUNGEON_ROUTES+r'''
data.Npc[11].spawns={[10014]={{-1,-1}}};Q:Refresh(true)
local m,x,y,how,entrance=FP.Planner:ResolveObjective(9101,2)
assert(m==1413 and entrance and how:find("dungeon entrance",1,true))
local pin
for _,p in ipairs(Q:WorldPins(1413))do for _,e in ipairs(p.entries)do if e.point.entrance and e.group.objIndex==2 then pin=p end end end
assert(pin and Q:Guide(pin))
assert(active().source.entrance and active().title:find("Entrance:",1,true))
Q:Tooltip(pin,UIParent)
q.waypoint={1445,.2,.3}
local m,x,y,how,entrance=FP.Planner:ResolveObjective(9101,2)
assert(m==1445 and how=="waypoint" and not entrance)
''',
"dungeon_entry_cleans_only_entrance_routes_and_blocks_new_ones":DUNGEON_ROUTES+r'''
FP.Waypoints:Clear()
local keep=FP.Waypoints:Add(1413,.8,.8,"Meeting place")
assert(FP.Dungeons:GuideEntrance("wailing-caverns",2))
data.Npc[11].spawns={[10014]={{-1,-1}}};Q:Refresh(true)
local pin
for _,p in ipairs(Q:WorldPins(1413))do for _,e in ipairs(p.entries)do if e.point.entrance and e.group.objIndex==2 then pin=p end end end
assert(pin and Q:Guide(pin))
FP.Planner.waiting={entrance=true}
M.instance={type="party"};M.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(#FP.Waypoints.list==1 and active()==keep and not FP.Planner.waiting)
assert(not FP.Dungeons:GuideEntrance("wailing-caverns",1))
assert(not Q:Guide(pin) and not Q:Nearest(9101,2))
M.instance=nil;assert(Q:Nearest(9101,2))
''',
"dungeon_planner_arrival_never_completes_objective":DUNGEON_ROUTES+r'''
FP.Waypoints:Clear();FP.Planner.paused=nil
q.objectives={objective("Cave Spider slain: 0/3","monster")}
data.Npc[11].spawns={[10014]={{-1,-1}}};Q:Refresh(true)
local step=FP.Planner:Build()[1];assert(step.entrance)
FP.Planner:Go(step);assert(active().source.entrance and active().title:find("Entrance:",1,true))
local wp=active();FP:Fire("WAYPOINT_ARRIVED",wp)
assert(FP.Planner.waiting.entrance and not q.objectives[1].finished)
M.instance={type="party"};M.FireEvent("PLAYER_ENTERING_WORLD");FP.Planner:Auto("instance")
assert(not active() and not FP.Planner.waiting)
assert(not FP.Planner:Go(step),"stale entrance step accepted inside instance")
''',
"dungeon_contacts_pickup_and_ender_separate_native_turnin_wins":DUNGEON_ROUTES+r'''
data.Quest[1486]={name="Deviate Hides",startedBy={{13}},finishedBy={{11}}}
data.Npc[11].spawns={[10014]={{-1,-1}}}
assert(FP.API.GetQuestChainStarters(1486)[1].id==13)
local ends=FP.API.GetQuestEnders(1486);assert(ends[1].id==11 and ends[1].points[1].entrance)
local quest=addQuest(1486,true);quest.waypoint=nil
local m,x,y,how,entrance=FP.Planner:ResolveTurnIn(1486)
assert(m==1413 and entrance and how:find("dungeon entrance",1,true))
quest.waypoint={1413,.8,.9};assert(select(4,FP.Planner:ResolveTurnIn(1486))=="waypoint")
quest.waypoint=nil;M.instance={type="party"};assert(FP.Planner:ResolveTurnIn(1486)==nil)
''',
"dungeon_pickup_inside_instance_is_entrance_and_clears_on_entry":DUNGEON_ROUTES+r'''
data.Quest[1486]={name="Deviate Hides",startedBy={{11}}}
data.Npc[11].spawns={[10014]={{-1,-1}}}
assert(FP.Dungeons:GuideQuest(1486));assert(active().source.type=="chain-pickup" and active().source.entrance)
assert(table.concat(FP.QuestChains:Details(1486,FP.QuestChains:Context()),"\n"):find("giver inside",1,true))
M.instance={type="party"};M.FireEvent("ZONE_CHANGED_NEW_AREA");assert(not active())
assert(not FP.QuestChains:GuidePickup(1486))
''',
"dungeon_panel_browsing_route_selection_and_chain_link":DUNGEON_ROUTES+r'''
local P=FP.DungeonPanel
FP.Waypoints:Clear();local keep=FP.Waypoints:Add(1413,.8,.8,"Meeting")
P:Open("wailing-caverns");assert(active()==keep and P.entranceButton:IsEnabled())
P.entranceNext:GetScript("OnClick")();assert(P.entranceIndex==2 and active()==keep)
P.entranceButton:GetScript("OnClick")();assert(active().mapID==1445 and active().source.type=="dungeon-entrance")
P:Select("the-drowned-city");assert(not P.entranceButton:IsEnabled() and not P.guideQuest:IsEnabled() and not P.viewChain:IsEnabled())
assert(P.entranceText:GetText():find("unavailable",1,true))
P:Select("wailing-caverns");P.selectedQuest=1486;P:RefreshDetails();assert(P.guideQuest:IsEnabled())
P.viewChain:GetScript("OnClick")();assert(not P.frame:IsShown() and FP.Hub.selected=="chains")
''',
"dungeon_quest_guidance_rechecks_state_and_never_hijacks_on_failure":DUNGEON_ROUTES+r'''
local keep=FP.Waypoints:Add(1413,.8,.8,"Meeting")
assert(not FP.Dungeons:GuideQuest(123456) and active()==keep)
C_QuestLog.IsQuestFlaggedCompleted=function(id)return id==1486 end
assert(not FP.Dungeons:GuideQuest(1486) and active()==keep)
C_QuestLog.IsQuestFlaggedCompleted=function()return false end
local q=addQuest(1486,true);FP.DungeonPanel:Open("wailing-caverns")
FP.DungeonPanel.selectedQuest=1486;FP.DungeonPanel:RefreshDetails()
assert(FP.DungeonPanel.guideQuest:GetText()=="Guide turn-in")
assert(FP.Dungeons:GuideQuest(1486) and active().source.kind=="turnin")
''',
})



CASES.update({
"class_supplies_food_drink_level_and_cache_boundaries": PREP_SETUP+r'''
assert(prepRow("food").count==99 and prepRow("water").count==22)
local old=C_Item.GetItemInfo
C_Item.GetItemInfo=function(id)if id==4540 then return "Bread","link",1,1,50,"type","subtype",20,"",123,0,0,5 end return old(id)end
FP.ClassPrep:Refresh();assert(prepRow("food").count==0 and prepRow("water").count==22)
C_Item.GetItemInfo=function(id)if id==4540 then return nil end return old(id)end
FP.ClassPrep:Refresh();assert(prepRow("food").count==nil and prepRow("food").missing==nil)
C_Item.GetItemInfo=old;C_Item.GetItemSpell=function(id)if id==4540 then return nil end return "Boisson"end
FP.ClassPrep:Refresh();assert(prepRow("food").count==nil)
''',
"class_supplies_personal_counts_and_bank_exclusion": PREP_SETUP+r'''
M.class="ROGUE"
local P=FP.ClassPrep
assert(P:SetSupply(17031,12));P:Refresh()
assert(prepRow("supply:17031").count==2 and prepRow("supply:17031").missing==10)
assert(not prepRow("water") and not prepRow("reagent:17031"))
M.bags[5]={{17031,15}};M.FireEvent("BAG_UPDATE_DELAYED");M.RunTimers(1)
assert(prepRow("supply:17031").missing==0)
assert(P:SetSupply(159,100));P:Refresh();assert(prepRow("supply:159").count==12)
assert(P:SetSupply(17031,0));M.RunTimers(1);assert(not prepRow("supply:17031"))
''',
"class_supplies_personal_validation_cap_and_character_storage":PREP_SETUP+r'''
local P=FP.ClassPrep
assert(P:SetSupply("|cffffffff|Hitem:17031:0|h[Rune]|h|r",9))
assert(FP.cdb.prep.supplies[17031]==9 and not FP.settings.supplies)
local before=snapshot(FP.cdb.prep)
for _,v in ipairs({"bad",-1,0,1.5,math.huge})do assert(not P:SetSupply(v,5))end
for _,v in ipairs({-1,201,1.5,math.huge})do assert(not P:SetSupply(17031,v))end
assert(snapshot(FP.cdb.prep)==before)
for i=1,19 do assert(P:SetSupply(i,5))end
assert(not P:SetSupply(999,5) and P:SetSupply(17031,10))
assert(P:SetSupply(1,0) and P:SetSupply(999,5))
local old=FP.cdb
FP.cdb=FP.deepDefaults({},FP.charDefaults);assert(not next(FP.cdb.prep.supplies))
FP.cdb=old;assert(FP.cdb.prep.supplies[17031]==10)
''',
"class_supplies_personal_unknown_inventory_and_combat":PREP_SETUP+r'''
local P=FP.ClassPrep
assert(P:SetSupply(17031,10));P:Refresh()
C_Container.GetContainerNumSlots=function()error("unavailable")end
P:Refresh();assert(prepRow("supply:17031").count==nil and prepRow("supply:17031").missing==nil)
M.inCombat=true;M.FireEvent("PLAYER_REGEN_DISABLED")
C_Item.GetItemInfo=function()error("item read in combat")end
C_Item.RequestLoadItemDataByID=function()error("item load in combat")end
assert(P:SetSupply(999,5));P:Refresh();P:Supplies(true)
assert(#P:Lines()==0 and P:Summary():find("after combat",1,true))
''',
"class_supplies_unknown_class_keeps_generic_tools":PREP_SETUP+r'''
M.class="FUTURE_CLASS"
FP.ClassPrep:Refresh();cmd("prep show");M.RunTimers(1)
assert(FP.ClassPrep:ClassLabel()=="Character" and #FP.ClassPrep:Lines()>0)
assert(prepRow("food") and prepRow("bandages") and prepRow("bags"))
assert(not prepRow("water") and not prepRow("gem:5514"))
''',
"class_supplies_food_target_validation_and_druid_mana":PREP_SETUP+r'''
M.class="DRUID";UnitPowerType=function()return 1,"RAGE"end
cmd("prep food 33");M.RunTimers(1);assert(prepRow("food").goal==33 and prepRow("water"))
cmd("prep food -1");cmd("prep food 201");assert(FP.cdb.prep.food==33)
cmd("prep food 0");M.RunTimers(1);assert(not prepRow("food"))
''',
"class_supplies_town_picker_and_counts_ignore_hidden_pvp":PREP_SETUP+HUB+r'''
M.class="PRIEST";FP.settings.pvp.enabled=false;FP.settings.pvp.manual="hide"
page("town");M.RunTimers(1)
assert(#H.controls.supplySummary.items>0 and not FP.PvP.frame:IsShown())
local list=H.controls.personalSupplies
local row
for _,b in ipairs(list.rows)do if b.item and b.item.id==159 then row=b;break end end
assert(row);row:GetScript("OnClick")(row)
assert(H.controls.supplyItem:GetText()=="159")
field("supplyTarget",25);click("saveSupply");M.RunTimers(1);H:Refresh()
assert(FP.cdb.prep.supplies[159]==25 and prepRow("supply:159").missing==13)
assert(not FP.PvP.frame:IsShown(),"opening town enabled PvP")
click("removeSupply");M.RunTimers(1);assert(not FP.cdb.prep.supplies[159])
field("supplyItem",17031);field("supplyTarget",8);click("saveSupply");M.RunTimers(1)
assert(FP.cdb.prep.supplies[17031]==8)
field("supplyItem",159);page("display");page("town");assert(H.controls.supplyItem:GetText()=="159","draft overwritten")
M.inCombat=true;M.FireEvent("PLAYER_REGEN_DISABLED");M.RunTimers(.3);H:Refresh()
assert(H.controls.supplySummary.items[1].text:find("after combat",1,true))
''',
"retired_hunter_audio_assets_and_action_events_stay_silent":HUB+r'''
assert(not FP.HunterAudio and not FP.settings.hunterAudio)
assert(not io.open("HearthAndHustle/Modules/HunterAudioFeedback.lua","rb"))
for i=1,10 do assert(not io.open(string.format("HearthAndHustle/Sounds/Hunter/hunter_feedback_%02d.ogg",i),"rb"))end
M.class="HUNTER";local count=#M.sounds
for _,id in ipairs({2643,136,1510})do
 M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","player","Cast-"..id,id)
 M.FireEvent("UNIT_SPELLCAST_CHANNEL_START","player","Cast-"..id,id)
end
cmd("audio on");cmd("audio test");assert(#M.sounds==count)
page("display");assert(not H.controls.hunterAudio and not H.controls.audioTest)
assert(FP.settings.rare.sound,"legitimate rare alert preference removed")
''',
})


CASES["class_supplies_failed_item_names_request_once_and_recover"] = PREP_SETUP+r'''
local calls=0
local old=C_Item.GetItemInfo
C_Item.GetItemInfo=function(id)if id==999999 then return nil end return old(id)end
C_Item.RequestLoadItemDataByID=function(id)if id==999999 then calls=calls+1 end end
assert(FP.ClassPrep:SetSupply(999999,5))
for i=1,5 do FP.ClassPrep:Refresh();FP.ClassPrep:Supplies(true);M.FireEvent("GET_ITEM_INFO_RECEIVED",999999,false);M.RunTimers(.4)end
assert(calls==1,"failed item load request loop")
assert(prepRow("supply:999999").count==0 and prepRow("supply:999999").text:find("Item #999999",1,true))
C_Item.GetItemInfo=old;M.FireEvent("GET_ITEM_INFO_RECEIVED",999999,true);M.RunTimers(.4)
assert(prepRow("supply:999999").text:find("Item 999999",1,true))
'''

from review_cases import REVIEW_CASES
CASES.update({
"quest_map_unique_name_fallback_async_and_ambiguous_rejection": OBJECTIVES+r'''
local built,lookups=0,0
LibQuestieDB.Item.BuildNameIndexAsync=function(batch)
 assert(batch<=250); coroutine.yield();built=built+1
end
LibQuestieDB.Item.IdsByName=function(name)
 lookups=lookups+1;assert(built==1,"lookup must wait for the complete index")
 if name=="Venom Sac" then return {31} elseif name=="Lost Key" then return {32,33} end
end
M.quests={}; M.AddQuest({questID=98192,title="New quest",objectives={objective("0/8 Venom Sac","item")}})
Q:Refresh(true);assert(Q.matched==0 and Q.missing==1 and lookups==0)
M.combatLockdown=true;M.RunTimers(.1);assert(built==0)
M.combatLockdown=false;for i=1,5 do M.RunTimers(.6) end
assert(Q.matched==1 and Q.groups[1].fallback and Q.groups[1].refKey=="Name:Item:31")
local cachedCalls=sourceCalls;Q.signature=nil;Q:Refresh();assert(sourceCalls<cachedCalls+10,"reuse active objective sources")
M.quests[1].objectives[1].text="0/1 Lost Key";Q:Refresh(true)
assert(Q.matched==0 and Q.missing==1,"duplicate item names must not guess an ID")
M.quests[1].objectives[1].text="0/1 Venom Sac fragment";Q:Refresh(true)
assert(Q.matched==0,"substring matching must not infer a different item")
M.quests[1].objectives[1].text="0/1   ";Q:Refresh(true);assert(Q.matched==0)
assert(#FP.db.errors==0)
''',
"quest_map_unique_creature_and_object_names_use_correct_types": OBJECTIVES+r'''
for _,kind in ipairs({"Npc","Object"}) do
 LibQuestieDB[kind].BuildNameIndexAsync=function() end
 local k=kind
 LibQuestieDB[kind].IdsByName=function(name)
  if k=="Npc" and name=="Cave Spider" then return {11} end
  if k=="Object" and name=="Ancient Crate" then return {21} end
 end
end
M.quests={}; M.AddQuest({questID=98193,title="New quest",objectives={
 objective("0/3 Cave Spider slain","monster"),objective("0/1 Ancient Crate","object")}})
Q:Refresh(true);for i=1,4 do M.RunTimers(.1) end
assert(Q.matched==2 and Q.groups[1].kind=="Npc" and Q.groups[2].kind=="Object")
M.quests[1].objectives[1].finished=true;Q:Refresh();assert(Q.matched==1)
assert(#FP.db.errors==0)
''',
"quest_map_colors_stable_unique_and_saved": OBJECTIVES+r'''
local other={questID=9102,title="Second quest",objectives={objective("0/1 Lost Key","item")}}
M.AddQuest(other);Q:Refresh(true)
local r,g,b,a,color=Q:Style(9101);local _,_,_,z,color2=Q:Style(9102)
assert(a~=z and color~=color2)
local saved=snapshot(FP.cdb.questMapStyles)
M.quests={other,q};Q:Refresh(true)
assert(snapshot(FP.cdb.questMapStyles)==saved,"log reorder changed colors/numbers")
Q:AssignStyles({other,q},{})
assert(snapshot(FP.cdb.questMapStyles)==saved,"reuse saved assignment after refresh")
M.AddQuest({questID=9,title="Earlier ID",objectives={}});Q:Refresh(true)
local _,_,_,after=Q:Style(9101);assert(after==a,"new quest recolored existing quest")
FP.cdb.questMapStyles[9102]=a;Q:Refresh(true)
local _,_,_,repaired=Q:Style(9102);assert(repaired~=a,"repair duplicate saved assignments")
assert(#FP.db.errors==0)
''',
"quest_map_focus_hide_legend_and_shared_marker": OBJECTIVES+r'''
M.mapID=1445;M.px=.32;M.py=.23;FP.Pos:Refresh(true)
M.AddQuest({questID=9102,title="Second quest",objectives={objective("0/1 Lost Key","item")}})
Q:Refresh(true);FP.Pins.provider:RefreshAllData()
local f=FP.Pins.legend
assert(f:IsShown() and f.rows[1].questID==9101 and f.rows[2].questID==9102)
local shared
for _,pin in ipairs(Q:WorldPins(1445)) do
 local ids={};for _,e in ipairs(pin.entries) do ids[e.group.questID]=true end
 if ids[9101] and ids[9102] then shared=pin end
end
assert(shared,"overlapping quest locations must be grouped")
local frame=WorldMapFrame:AcquirePin("HearthAndHustleObjectivePinTemplate",shared)
assert(frame.sharedQuests==2 and frame.questBadge:GetText()=="+" and frame.Icon._color[1]==1)
cmd("way 80 80 Keep route");local before=snapshot(FP.Waypoints.list)
f.rows[2]:GetScript("OnClick")(f.rows[2],"LeftButton")
assert(Q.focusedQuest==9102 and snapshot(FP.Waypoints.list)==before)
for _,g in ipairs(Q:VisibleGroups()) do assert(g.questID==9102) end
f.rows[2]:GetScript("OnClick")(f.rows[2],"RightButton")
assert(not Q.focusedQuest and FP.cdb.questMapHidden[9102])
for _,g in ipairs(Q:VisibleGroups()) do assert(g.questID~=9102) end
f.all:GetScript("OnClick")();assert(not next(FP.cdb.questMapHidden))
f.collapse:GetScript("OnClick")();assert(f.collapsed and not f.rows[1]:IsShown())
f.collapse:GetScript("OnClick")();assert(not f.collapsed and f.rows[1]:IsShown())
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
assert(#FP.Pins.objectiveMini>0 and FP.Pins.objectiveMini[1].questBadge)
assert(#FP.db.errors==0)
''',
"quest_map_icons_recycle_and_contacts_clear": r'''
FP.settings.record=false
M.gossipAvailable={{questID=9100,title="Pickup quest"}}
M.SetUnit("npc",{guid="Creature-0-1-0-0-2319-00001",name="Quest giver"})
M.FireEvent("GOSSIP_SHOW");M.RunTimers(.5)
local Q=FP.QuestObjectives
local pins=Q:WorldPins(M.mapID);assert(#pins==1 and pins[1].entries[1].group.kind=="Pickup")
local frame=WorldMapFrame:AcquirePin("HearthAndHustleObjectivePinTemplate",pins[1])
assert(frame.actionGlyph:GetText()=="!")
assert(Q:Guide(pins[1]) and active().source.kind=="pickup")
local q=addQuest(9100,true);M.FireEvent("QUEST_ACCEPTED",9100);Q:Refresh(true)
pins=Q:WorldPins(M.mapID);assert(#pins==1 and pins[1].entries[1].group.kind=="Turnin")
frame:OnAcquired(pins[1]);assert(frame.actionGlyph:GetText()=="?")
assert(Q:Guide(pins[1]) and active().source.kind=="turnin")
M.RemoveQuest(9100);M.FireEvent("QUEST_TURNED_IN",9100,0,0);Q:Refresh(true)
assert(#Q:WorldPins(M.mapID)==0 and not Q:Guide(pins[1]),"stale completed pin must not route")
assert(#FP.db.errors==0)
''',
"quest_map_legend_paging_and_filters": OBJECTIVES+HUB+r'''
M.mapID=1445
local oldLog=FP.API.GetQuestLog;FP.API.GetQuestLog=function() local log=oldLog();for _,q in ipairs(log) do q.header="Map 1445" end;return log end
for i=1,9 do M.AddQuest({questID=9200+i,title="Quest "..i,header="Map 1445",objectives={objective("0/1 Unknown","item")}}) end
Q:Refresh(true);FP.Pins.provider:RefreshAllData()
local f=FP.Pins.legend;assert(f.pageLabel:GetText()=="1 / 2")
f.next:GetScript("OnClick")();assert(f.pageLabel:GetText()=="2 / 2")
f.next:GetScript("OnClick")();assert(f.page==2,"page must stay bounded")
page("display");check("displayquestMapLegend",false);assert(not f:IsShown())
check("displayquestMapLegend",true);assert(f:IsShown())
FP.settings.questContactPins=false;FP.settings.questSelectedOnly=true;C_SuperTrack=nil;Q.worldCache={}
assert(#Q:WorldPins(1445)==0)
Q:Focus(9101);assert(#Q:WorldPins(1445)>0,"explicit focus works without native tracking")
assert(#FP.db.errors==0)
''',
})

CASES.update({
"quest_map_above_terrain_on_open_focus_browse_reopen": OBJECTIVES+r'''
M.mapID=1445;M.px=.32;M.py=.23;FP.Pos:Refresh(true)
WorldMapFrame:Hide()
M.AddQuest({questID=9102,title="Second quest",objectives={objective("0/1 Lost Key","item")}})
Q:Refresh(true)
WorldMapFrame:RemoveAllPinsByTemplate("HearthAndHustleObjectivePinTemplate")
WorldMapFrame:Show()
local levels=WorldMapFrame:GetPinFrameLevelsManager()
local function visiblePins(qid)
 local n=0
 for _,pin in ipairs(WorldMapFrame._pins) do
  local level=pin:GetFrameLevel()
  assert(level>levels:GetFrameLevelStart("PIN_FRAME_LEVEL_MAP_EXPLORATION"),"terrain covers marker")
  assert(level>levels:GetFrameLevelStart("PIN_FRAME_LEVEL_FOG_OF_WAR"),"fog covers marker")
  assert(level>levels:GetFrameLevelStart("PIN_FRAME_LEVEL_QUEST_BLOB"),"quest blob covers marker")
  assert(level<levels:GetFrameLevelStart("PIN_FRAME_LEVEL_QUEST_OFFER"),"native quest icon covered")
  if pin.point then
   n=n+1
   assert(pin.point.mapID==WorldMapFrame:GetMapID())
   assert(pin.questBadge:IsShown() and pin:GetWidth()==(pin.point.attention and 22 or 18))
   if qid then for _,e in ipairs(pin.point.entries) do assert(e.group.questID==qid) end end
  end
 end
 return n
end
assert(visiblePins()>0,"opening map did not draw quests")
local f=FP.Pins.legend
assert(f.rows[2].questID==9102)
f.rows[2]:GetScript("OnClick")(f.rows[2],"LeftButton")
assert(Q.focusedQuest==9102 and visiblePins(9102)>0,"legend did not focus drawn pins")
WorldMapFrame:Hide();WorldMapFrame:Show();assert(visiblePins(9102)>0)
f.all:GetScript("OnClick")();assert(not Q.focusedQuest and visiblePins()>0)
WorldMapFrame:SetMapID(1413);assert(visiblePins()>0,"browsed zone should show its sources")
WorldMapFrame:SetMapID(1445);assert(visiblePins()>0)
cmd("way 50 50 Manual");visiblePins()
WorldMapFrame:Hide();M.complete[9101]=true;M.complete[9102]=true;Q:Refresh(true)
WorldMapFrame:Show();assert(visiblePins()==0,"completed objectives survived reopen")
''',
"quest_minimap_compact_spaced_shared_and_bounded": OBJECTIVES+r'''
M.mapID=1445;M.px=.5;M.py=.5;FP.Pos:Refresh(true)
local points={}
-- Two different grid cells almost touching at the center, plus a dense field.
local radius=FP.API.GetMinimapViewRadius()
local cell=radius*18/70/10000
local boundary=math.ceil(.5/cell)*cell
points[1]={mapID=1445,x=boundary-.0001,y=.5,name="Left",entityID=11,role="kill"}
points[2]={mapID=1445,x=boundary+.0001,y=.5,name="Right",entityID=12,role="kill"}
local second=table.remove(points,2)
Q.groups={{questID=9101,kind="Npc",points=points},{questID=9102,kind="Npc",points={second}}};Q.contacts={}
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
local shared=FP.Pins.objectiveMini[1]
assert(shared and shared:IsShown() and shared.sharedQuests==2,"adjacent cells were not merged")
assert(#shared.point.entries==2,"merged marker lost a quest")
for i=-10,10 do for j=-10,10 do
 points[#points+1]={mapID=1445,x=.5+i*.002,y=.5+j*.002,name="Target",entityID=11,role="kill"}
end end
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
local shown={}
for _,f in ipairs(FP.Pins.objectiveMini) do if f:IsShown() then
 assert(f:GetWidth()==11 and f:GetHeight()==11 and not f.questBadge:IsShown(),"minimap icon/badge too large")
 assert(f.point.d<=radius)
 local _,_,_,x,y=f:GetPoint()
 for _,other in ipairs(shown) do
  local _,_,_,ox,oy=other:GetPoint()
  assert((x-ox)^2+(y-oy)^2>=14^2-.001,"neighboring minimap markers overlap")
 end
 shown[#shown+1]=f
end end
assert(#shown>1 and #shown<=24)
M.rotateMinimap=true;FP.Pos.cache.facing=1.2;FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
assert(#FP.Pins.objectiveMini==#shown,"rotation grew pool")
Q.groups={};FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
for _,f in ipairs(shown) do assert(not f:IsShown(),"stale pooled marker still shown") end
''',
"quest_map_native_callback_errors_recorded_and_legend_isolated": OBJECTIVES+r'''
M.mapID=1445
local legend=FP.Pins.UpdateLegend
FP.Pins.UpdateLegend=function() error("legend fixture failure") end
FP.Pins.provider:RefreshAllData()
assert(#WorldMapFrame._pins>0,"legend failure prevented map pins")
assert(#FP.db.errors==1 and FP.db.errors[1].where=="worldmap-legend")
FP.Pins.UpdateLegend=legend
local acquire=WorldMapFrame.AcquirePin
WorldMapFrame.AcquirePin=function() error("pin fixture failure") end
FP.Pins.provider:OnMapChanged()
assert(#FP.db.errors==2 and FP.db.errors[2].where=="worldmap-refresh")
WorldMapFrame.AcquirePin=acquire
FP.Pins.provider:RefreshAllData();assert(#WorldMapFrame._pins>0)
FP.db.errors={} -- expected fault injection; normal callbacks recovered
''',
})

CASES.update({
"quest_map_never_calls_restricted_passthrough_during_pin_lifecycle": OBJECTIVES+r'''
M.mapID=1445;M.px=.32;M.py=.23;FP.Pos:Refresh(true)
local native=MapCanvasPinMixin.CheckMouseButtonPassthrough
local restrictedCalls=0
MapCanvasPinMixin.CheckMouseButtonPassthrough=function()
 restrictedCalls=restrictedCalls+1;error("restricted SetPassThroughButtons")
end
for _,combat in ipairs({false,true,false}) do
 FP.API.InCombat=function() return combat end
 FP.Pins.provider:RefreshAllData()
 local pin=assert(WorldMapFrame._pins[1])
 pin.SetPassThroughButtons=function() restrictedCalls=restrictedCalls+1;error("direct restricted setter") end
 pin:CheckMouseButtonPassthrough("RightButton")
 assert(pin:IsMouseClickEnabled() and #pin._passthrough==0)
 pin:OnMouseEnter();assert(GameTooltip:IsOwned(pin));pin:OnMouseLeave()
 pin:OnClick("RightButton");assert(Q.focusedQuest==9101 or Q.focusedQuest==nil)
end
FP.API.InCombat=function() return false end
local manual={id=333,mapID=1445,x=.32,y=.23,title="Manual"}
local frame=WorldMapFrame:AcquirePin("HearthAndHustleMapPinTemplate",manual,true)
local plan={id=334,mapID=1445,x=.32,y=.23,title="Plan",source={type="plan"}}
frame:OnAcquired(plan,false);frame:CheckMouseButtonPassthrough("RightButton")
assert(not frame:IsMouseClickEnabled() and not frame:IsMouseMotionEnabled())
frame:OnAcquired(manual,true);frame:CheckMouseButtonPassthrough("RightButton")
assert(frame:IsMouseClickEnabled() and frame:IsMouseMotionEnabled() and #frame._passthrough==0)
assert(restrictedCalls==0)
-- Our override must never replace the native shared function.
assert(MapCanvasPinMixin.CheckMouseButtonPassthrough~=native)
''',
"quest_map_never_writes_native_pin_frame_levels": OBJECTIVES+r'''
-- Client report: ADDON_ACTION_BLOCKED Button:SetPassThroughButtons() twice on
-- 0.18.1. The blocked object is a Button; our pins are Frames. Inserting a
-- level rewrites startLevel on every native level above it, and native quest
-- pins (Buttons) read that value in ApplyFrameLevel before their restricted
-- passthrough call. Our pins must sit on an existing level, with no writes.
M.mapID=1445;M.px=.32;M.py=.23;FP.Pos:Refresh(true)
local levels=WorldMapFrame:GetPinFrameLevelsManager()
local before={};for k,v in pairs(levels.definitions) do before[k]=v end
WorldMapFrame:Hide();WorldMapFrame:RemoveAllPinsByTemplate("HearthAndHustleObjectivePinTemplate")
WorldMapFrame:Show();FP.Pins.provider:RefreshAllData()
local manual=WorldMapFrame:AcquirePin("HearthAndHustleMapPinTemplate",{id=335,mapID=1445,x=.32,y=.23,title="Manual"},true)
assert(#WorldMapFrame._pins>1,"no quest pins drawn")
assert(levels.writes==nil,"addon inserted a level into the native manager")
local n=0
for k,v in pairs(levels.definitions) do n=n+1;assert(before[k]==v,"native level moved: "..k) end
for k in pairs(before) do n=n-1 end
assert(n==0,"native level list changed")
assert(before[FP.Pins.questPinLevel],"quest pins use an unregistered level")
for _,pin in ipairs(WorldMapFrame._pins) do
 assert(pin.pinFrameLevelType==FP.Pins.questPinLevel)
 assert(pin:GetFrameLevel()>levels:GetFrameLevelStart("PIN_FRAME_LEVEL_MAP_HIGHLIGHT"),"highlight covers marker")
 assert(pin:GetFrameLevel()<levels:GetFrameLevelStart("PIN_FRAME_LEVEL_AREA_POI"),"native icon covered")
end
''',
"quest_minimap_sources_follow_the_parent_map_the_client_reports": OBJECTIVES+r'''
-- Client data: outdoor caves report the continent map while sources are stored
-- on the zone map. The world map projected them; the minimap showed none.
local function shown() local n=0;for _,f in ipairs(FP.Pins.objectiveMini or {}) do if f:IsShown() then n=n+1 end end;return n end
local function update() FP.Pos:Refresh(true);FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache) end
M.mapID=1445;M.px=.34;M.py=.25;update()
local zone=shown();assert(zone>0)
M.mapID=1414;update()
assert(shown()==zone,"sources vanished on the parent map: "..shown().." of "..zone)
for _,f in ipairs(FP.Pins.objectiveMini) do if f:IsShown() then
 assert(f.point.mapID==1445 and f.point.mx and f.point.entries[1].point.mapID==1445,"tooltip/guide must keep the source point")
end end
-- An unrelated map shows nothing, and the answer is cached per reported map.
local info=C_Map.GetMapInfo
C_Map.GetMapInfo=function(id) if id==1999 then return {mapID=id,name="Elsewhere",mapType=3,parentMapID=946} end return info(id) end
M.mapID=1999;update();assert(shown()==0,"unrelated map drew sources")
local calls=0;local world=FP.Pos.WorldOf;FP.Pos.WorldOf=function(...) calls=calls+1;return world(...) end
M.mapID=1414;update();local first=calls;update()
assert(calls-first<=shown(),"projection repeated for every source on every update")
Q:Refresh(true);update();assert(shown()==zone,"sources lost after a source refresh on the parent map")
''',
"party_cast_timer_text_is_plain": r'''
local C=FP.Coordination
local d=assert(C:Decode("PT;118;|cffff0000FAKE ALERT|r;30;|TInterface\\Icons\\Spell_Nature_Polymorph:20|t;|Hitem:1|h[x]|h;cc"))
for _,field in ipairs({"spell","target","drText"}) do assert(not d[field]:find("[|%c]"),field.." keeps escape codes: "..d[field]) end
assert(d.spell=="cffff0000FAKE ALERTr" and d.duration==30 and d.kind=="cc")
assert(C:Decode("PT;118;||;30;;;cc")==nil,"a name made only of escape bytes is rejected")
assert(C:Decode("PT;118;Polymorph;30;Bob;DR 1/2;cc").target=="Bob")
''',
"rare_hud_text_stays_current_in_combat_without_moving_the_frame": r'''
local RW=FP.RareWatch
FP.settings.rare.enabled=true;FP.settings.rare.manual="show";RW:Refresh()
assert(RW.frame:IsShown())
local moved=0
for _,name in ipairs({"SetHeight","SetPoint","ClearAllPoints","Show","Hide","SetScale"}) do
 local native=RW.frame[name];RW.frame[name]=function(...) moved=moved+1;return native(...) end
end
local scan=0
for _,name in ipairs({"Show","Hide"}) do local native=RW.scan[name];RW.scan[name]=function(...) scan=scan+1;return native(...) end end
local lines=RW.StatusLines
RW.StatusLines=function() return "RARE UP","level 33 elite","Runs 4" end
FP.API.InCombat=function() return true end
RW.layoutPending,RW.scanPending=nil,nil
RW:Refresh()
assert(RW.status:GetText()=="RARE UP" and RW.detail:GetText()=="level 33 elite" and RW.stats:GetText()=="Runs 4","HUD text frozen in combat")
assert(moved==0 and scan==0,"frame or secure button changed in combat")
assert(RW.layoutPending and RW.scanPending)
-- hidden HUD stays hidden and untouched in combat
FP.settings.rare.manual="hide";RW.StatusLines=function() error("no text read for a hidden HUD") end;RW:Refresh();assert(moved==0)
FP.API.InCombat=function() return false end;RW.StatusLines=lines;RW:Refresh();assert(not RW.frame:IsShown())
''',
"gear_unlisted_level_tick_widens_item_level_estimate_by_a_bounded_margin": r'''
FP.API.GetCharInfo=function() return {class="SHAMAN",level=40} end
local item={id=1,name="Reward",equipLoc="INVTYPE_CLOAK",classID=4,subclassID=1,level=24,stats={},sources={},sourceTypes={}}
FP.GearCatalog={items={item}}
assert(#FP.Gear:Rows({slot="CLOAK",level=20})==0)
assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==1,"tick did not widen the estimate")
item.level=25;assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==1)
item.level=26;assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==0,"margin is unbounded")
item.level=24;item.minLevel=22;assert(#FP.Gear:Rows({slot="CLOAK",level=20,unknown=true})==0,"a listed requirement was widened")
''',
"skill_up_without_profession_window_starts_no_recipe_scan": r'''
local scanned=0;FP:On("RECIPES_SCANNED",function() scanned=scanned+1 end)
local function settle(n) for _=1,n do M.RunTimers(.1) end end
M.FireEvent("CHAT_MSG_SKILL","Your skill in Maces has increased to 55.");M.FireEvent("SKILL_LINES_CHANGED");settle(60)
assert(scanned==0,"scan + retries without a profession window: "..scanned)
M.FireEvent("TRADE_SKILL_SHOW");settle(20)
local opened=scanned;assert(opened>0,"opening the window must scan")
M.FireEvent("CHAT_MSG_SKILL","Your skill in Leatherworking has increased to 101.");settle(20)
assert(scanned>opened,"skill-up with the window open must rescan")
M.FireEvent("TRADE_SKILL_CLOSE");settle(60);local closed=scanned
M.FireEvent("CHAT_MSG_SKILL","Your skill in Maces has increased to 56.");settle(60)
assert(scanned==closed,"scan after the window closed")
''',
"quest_map_action_texture_above_border_and_recovers_missing_art": OBJECTIVES+r'''
local pin=Q:WorldPins(1445)[1]
local frame=WorldMapFrame:AcquirePin("HearthAndHustleObjectivePinTemplate",pin)
local function ordered()
 assert(frame.Icon._drawLayer=="BACKGROUND", "quest-color square covers action art")
 assert(frame.actionIcon._drawLayer=="ARTWORK" and frame.actionIcon._drawSublevel==1)
 assert(frame.Icon:IsShown() and frame.actionIcon:IsShown() and frame.actionGlyph:IsShown())
end
ordered();assert(frame.actionGlyph:GetText()=="")
local set=frame.actionIcon.SetTexture
frame.actionIcon.SetTexture=function(self,path)
 if path:find("Interface\\Icons\\",1,true) then return false end
 return set(self,path)
end
pin.entries[1].group.kind="Npc"
frame.Icon:SetDrawLayer("ARTWORK",2);frame.actionIcon:Hide();frame.actionGlyph:Hide()
frame:OnAcquired(pin);ordered()
assert(frame.actionGlyph:GetText()=="X" and frame.actionIcon._color[1]==.05,"missing icon became blank square")
frame.actionIcon.SetTexture=set
frame:OnAcquired(pin);ordered();assert(frame.actionGlyph:GetText()=="","pooled fallback survived valid icon")
assert(frame.actionIcon:GetTexture()=="Interface\\Icons\\INV_Sword_04")
pin.entries[1].group.kind="Pickup";frame:OnAcquired(pin);ordered();assert(frame.actionGlyph:GetText()=="!")
pin.entries[1].group.kind="Turnin";frame:OnAcquired(pin);ordered();assert(frame.actionGlyph:GetText()=="?")
''',
"blocked_action_context_is_bounded_and_only_ours": r'''
FP.API.InCombat=function() return true end
WorldMapFrame:Hide()
debugstack=function() return string.rep("trace",2000) end
M.FireEvent("ADDON_ACTION_BLOCKED","OtherAddon","Button:SetPassThroughButtons()")
assert(not FP.db.blockedActions)
for i=1,20 do M.FireEvent("ADDON_ACTION_BLOCKED","HearthAndHustle","Button:SetPassThroughButtons()") end
local rows=FP.db.blockedActions
assert(#rows==1 and rows[1].combat and not rows[1].mapShown)
assert(rows[1].version==FP.version and #rows[1].trace==4096)
for i=1,12 do M.FireEvent("ADDON_ACTION_BLOCKED","HearthAndHustle","Test"..i) end
assert(#rows==10)
debugstack=function() error("unavailable trace") end
M.FireEvent("ADDON_ACTION_FORBIDDEN","HearthAndHustle","FailedTrace")
assert(#rows==10 and rows[10].trace==nil)
FP.db.errors={} -- expected blocked-event injections, no incidental Lua errors
''',
})

CASES.update(REVIEW_CASES)

from quest_guidance import cases as quest_guidance_cases
CASES.update(quest_guidance_cases(OBJECTIVES, HUB))

failed = 0
for name, body in CASES.items():
    boot = BOOT
    if name == "review_fresh_defaults_opt_out_and_observations_are_bounded":
        boot = boot.replace('if not HearthAndHustleDB and not ForeverPathDB then HearthAndHustleDB={settings={record=true,probe={enabled=true}}} end', '')
    result = subprocess.run([LUA, "-"], input=boot + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + result.stderr.splitlines()[0])

# Fresh release logins exercise module registration with each actual launch class.
for player_class in ("SHAMAN", "HUNTER", "MAGE", "WARRIOR", "ROGUE", "PRIEST", "WARLOCK", "DRUID", "PALADIN"):
    boot = BOOT.replace('local FP = {}', 'M.class = "' + player_class + '"\nGetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end\nlocal FP = {}')
    boot = boot.replace('local FP = {}', 'HearthAndHustleDB={settings={hunterAudio={enabled=true,cooldown=1}}}\nHearthAndHustleCharDB={prep={water=35,food=14,supplies={[17031]=9}}}\nlocal FP = {}')
    body = PREP_SETUP + r'''
assert(not FP.HunterAudio and not FP.settings.hunterAudio)
assert(FP.cdb.prep.food==14 and FP.cdb.prep.water==35 and FP.cdb.prep.supplies[17031]==9)
assert(prepRow("food") and prepRow("bandages") and prepRow("supply:17031"))
assert((prepRow("water")~=nil)==(M.class~="WARRIOR" and M.class~="ROGUE"))
FP.data.trainers={[1]={n="My trainer",class=M.class,services={Spell={lvl=31,cost=100}}},[2]={n="Other trainer",class="OTHER",services={Other={lvl=31,cost=100}}}}
assert(#FP.Trainer:NotesForLevel(31)==1)
assert(not FP.Dungeons:Restriction({classes={M.class}},FP.API.GetCharInfo()))
addQuest(9001);FP.Planner:Auto("all classes");assert(active() and active().source.questID==9001)
cmd("prep show"); M.RunTimers(1)
assert(FP.clientBuild=="70790" and #FP.ClassPrep:Lines()>0)
assert((prepRow("gem:5514")~=nil)==(M.class=="MAGE"))
assert((prepRow("reagent:17031")~=nil)==(M.class=="MAGE"))
assert(FP.PvP.frame:IsShown())
M.FireEvent("PLAYER_REGEN_DISABLED"); assert(#FP.ClassPrep:Lines()==0)
M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(1)
assert(#FP.ClassPrep:Lines()>0 and #FP.db.errors==0)
'''
    result = subprocess.run([LUA, "-"], input=boot + body, text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + "fresh_70790_" + player_class.lower())
    if result.returncode:
        failed += 1
        print(result.stderr)

# Renamed from ForeverPath in v0.17.0: saved data must follow, and another addon's
# tables that happen to use the old variable names must never be adopted.
LEGACY_ACCOUNT = 'ForeverPathDB={version=2,errors={},settings={arrow={x=-410.5,shown=true},autoNext=false,hunterAudio={enabled=true}},data={quests={[1322]={t="The Black Shield"}}},meta={created=77,builds={},counters={quests=1}}}'
LEGACY_CHAR = 'ForeverPathCharDB={nextId=901,activeId=900,completed={[100]=true},waypoints={{id=900,mapID=1413,x=.5,y=.68,title="Legacy waypoint",persistent=false,radius=15,t=5}},gear={weights={},wishlist={[6504]=true}}}'
RENAME_CASES = {
    "rename_adopts_legacy_saved_variables": (LEGACY_ACCOUNT + "\n" + LEGACY_CHAR, r"""
assert(HearthAndHustleDB==ForeverPathDB and HearthAndHustleCharDB==ForeverPathCharDB, "an orphaned legacy file is adopted, not copied")
assert(FP.db==HearthAndHustleDB and FP.cdb==HearthAndHustleCharDB and FP.migratedFrom=="ForeverPath")
assert(FP.settings.arrow.x==-410.5 and FP.settings.autoNext==false and FP.settings.hunterAudio==nil)
assert(FP.data.quests[1322].t=="The Black Shield" and FP.db.meta.created==77)
assert(FP.cdb.gear.wishlist[6504] and FP.cdb.nextId==901 and active() and active().title=="Legacy waypoint")
local told=false; for _,l in ipairs(M.Chat()) do if tostring(l):find("Formerly ForeverPath",1,true) then told=true end end
assert(told and SlashCmdList.HEARTHANDHUSTLE and SLASH_HEARTHANDHUSTLE1=="/hh" and SLASH_HEARTHANDHUSTLE2=="/hustle" and not SlashCmdList.FOREVERPATH)
"""),
    "rename_copies_legacy_data_while_old_addon_is_loaded": (LEGACY_ACCOUNT + "\n" + LEGACY_CHAR + '\nC_AddOns.IsAddOnLoaded=function(n) return n=="ForeverPath" end', r"""
assert(HearthAndHustleDB~=ForeverPathDB and HearthAndHustleCharDB~=ForeverPathCharDB, "a live old addon keeps its own tables")
assert(FP.settings.arrow.x==-410.5 and FP.data.quests[1322].t=="The Black Shield" and FP.cdb.gear.wishlist[6504])
FP.settings.arrow.x=1; FP.data.quests[1322].t="changed"; FP.cdb.gear.wishlist[6504]=nil
assert(ForeverPathDB.settings.arrow.x==-410.5 and ForeverPathDB.data.quests[1322].t=="The Black Shield" and ForeverPathCharDB.gear.wishlist[6504])
local warned=false; for _,l in ipairs(M.Chat()) do if tostring(l):find("old ForeverPath folder is still installed",1,true) then warned=true end end
assert(warned and FP.migratedFrom~="ForeverPath")
"""),
    "rename_ignores_foreign_tables_with_the_old_names": ('ForeverPathDB={profile={arrow=true},guides={"a","b"},settings={scale=2}}\nForeverPathCharDB={step=3,guide="Durotar",waypoints={}}', r"""
assert(HearthAndHustleDB~=ForeverPathDB and HearthAndHustleCharDB~=ForeverPathCharDB and FP.migratedFrom==nil)
assert(snapshot(ForeverPathDB)==snapshot({profile={arrow=true},guides={"a","b"},settings={scale=2}}), "another addon's account table was modified")
assert(snapshot(ForeverPathCharDB)==snapshot({step=3,guide="Durotar",waypoints={}}), "another addon's character table was modified")
assert(FP.settings.arrow.shown==true and FP.settings.scale==nil and next(FP.data.quests)==nil and #FP.cdb.waypoints==0)
"""),
    "rename_keeps_existing_new_data": (LEGACY_ACCOUNT + "\n" + LEGACY_CHAR + '\nHearthAndHustleDB={settings={arrow={x=7}}}\nHearthAndHustleCharDB={nextId=5,waypoints={},completed={}}', r"""
assert(HearthAndHustleDB~=ForeverPathDB and FP.settings.arrow.x==7 and FP.cdb.nextId==5 and FP.migratedFrom==nil)
assert(ForeverPathDB.settings.arrow.x==-410.5 and next(FP.data.quests)==nil)
"""),
}
for name, (preload, body) in RENAME_CASES.items():
    boot = BOOT.replace('local FP = {}', preload + '\nlocal FP = {}')
    result = subprocess.run([LUA, "-"], input=boot + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + (result.stderr.splitlines() or ["no error output"])[0])

# v0.19.0: action bar guard. On build 70938 the server can hand a dual-spec
# character emptied bars at login, on a spec change or on a level-up. Each case
# starts from saved character data and mock bars prepared before the addon loads.
BAR_HELPERS = r"""
local B=FP.BarGuard
local function put(slot,kind,id,name) M.SetAction(slot,kind,id,name); M.FireEvent("ACTIONBAR_SLOT_CHANGED",slot) end
local function count(first,last) local n=0; for slot=first,last do if M.actions[slot] then n=n+1 end end return n end
local function remembered(group) local n=0; for _ in pairs(FP.cdb.barGuard.specs[group].slots) do n=n+1 end return n end
local function said(text) local n=0; for _,l in ipairs(M.Chat()) do if tostring(l):find(text,1,true) then n=n+1 end end return n end
"""
BAR_MEMORY = r"""
local snap={}
for slot=1,12 do snap[slot]={k="spell",id=1000+slot}; M.SetAction(slot,"spell",1000+slot) end
for slot=49,72 do snap[slot]={k="spell",id=1000+slot} end
HearthAndHustleCharDB={barGuard={specs={[1]={slots=snap}},log={}}}
"""
BAR_CASES = {
    "bars_login_wipe_fills_empty_slots_only": (BAR_MEMORY + r"""
M.SetAction(60,"spell",9999)                      -- the player's own button on a remembered slot
M.SetAction(133,"spell",5); snap[133]={k="spell",id=5}; snap[200]={k="spell",id=6}; snap.junk=true
""", r"""
assert(count(49,72)==24 and #M.placed==23, "23 empty slots are filled: "..#M.placed)
assert(M.actions[60].id==9999 and M.actions[61].id==1061 and M.actions[49].id==1049, "an existing button is never replaced")
for _,slot in ipairs(M.placed) do assert(slot>=49 and slot<=72 and slot~=60) end
assert(M.cursor==nil and M.actions[133].id==5 and count(1,12)==12)
assert(said("Put 23 action buttons back")==1)
local log=FP.cdb.barGuard.log; assert(#log==1 and log[1].lost==23 and log[1].restored==23 and log[1].failed==0 and log[1].group==1)
assert(remembered(1)==36 and FP.cdb.barGuard.specs[1].slots[60].id==9999 and not FP.cdb.barGuard.specs[1].slots[133])
assert(B.mode=="track")
M.RunTimers(30); assert(#M.placed==23 and said("Put ")==1, "nothing is repeated")
local ok,why=FP.API.PlaceOnBar(60,{k="spell",id=1}); assert(ok==false and why=="occupied" and M.actions[60].id==9999 and M.cursor==nil)
"""),
    "bars_hand_edits_are_remembered_not_reverted": ("", r"""
assert(FP.settings.barGuard.enabled and remembered(1)==0 and #FP.cdb.barGuard.log==0, "fresh profile: on, nothing to restore")
assert(said("Action bar guard is watching your bars")==1 and FP.cdb.barGuard.introduced)
for slot=49,60 do put(slot,"spell",1000+slot) end
M.RunTimers(2); assert(remembered(1)==12)
for slot=49,53 do put(slot); M.RunTimers(1) end      -- five buttons dragged off, one a second
M.RunTimers(5); assert(#M.placed==0 and count(49,60)==7 and remembered(1)==7, "removed buttons stay removed")
for slot=54,56 do put(slot); M.RunTimers(0.4) end    -- as fast as a person can
M.RunTimers(8); assert(#M.placed==0 and count(49,60)==4 and remembered(1)==4)
put(54,"spell",77); put(49,"item",858); M.RunTimers(2)
assert(remembered(1)==6 and FP.cdb.barGuard.specs[1].slots[49].k=="item" and said("Put ")==0)
"""),
    "bars_burst_wipe_and_level_up_wipe_are_restored": ("", r"""
for slot=49,72 do put(slot,"spell",1000+slot) end
M.RunTimers(2); assert(remembered(1)==24)
M.WipeActions(49,72)
M.RunTimers(1.6); assert(#M.placed==0 and remembered(1)==24, "a burst is confirmed before anything is placed")
M.RunTimers(2.1); assert(count(49,72)==24 and #M.placed==24 and said("Put 24 action buttons back")==1)
M.RunTimers(20)
put(49); M.RunTimers(3); assert(count(49,72)==23 and #M.placed==24, "a later hand edit is still an edit")
M.FireEvent("PLAYER_LEVEL_UP",48); M.WipeActions(50,51)   -- two slots: below the burst size
M.RunTimers(3.1); assert(count(49,72)==23 and #M.placed==26, "buttons lost at a level-up are put back")
M.RunTimers(20); M.FireEvent("PLAYER_LEVEL_UP",49); M.actions[52]=nil   -- lost with no slot event at all
M.RunTimers(3.1); assert(M.actions[52] and #M.placed==27 and said("Action bar guard is watching")==1)
assert(#FP.cdb.barGuard.log==3 and remembered(1)==23)
"""),
    "bars_combat_defers_restore_and_keeps_memory": (BAR_MEMORY + "M.combatLockdown=true\n", r"""
assert(#M.placed==0 and M.blockedPlaces==0 and count(49,72)==0, "nothing is attempted in combat")
M.RunTimers(30); assert(M.blockedPlaces==0 and remembered(1)==36, "the memory survives a long fight")
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(2)
assert(count(49,72)==24 and M.blockedPlaces==0 and said("Put 24 action buttons back")==1)
"""),
    "bars_spec_change_uses_that_specs_memory": (BAR_MEMORY + r"""
local two={}
for slot=49,66 do two[slot]={k="spell",id=2000+slot} end
HearthAndHustleCharDB.barGuard.specs[2]={slots=two}
for slot=49,72 do M.SetAction(slot,"spell",1000+slot) end
""", r"""
assert(#M.placed==0 and remembered(1)==36 and remembered(2)==18)
-- Swap to spec 2; the server hands over its bars with all but one button gone.
M.specGroup=2; M.WipeActions(49,72); put(49,"spell",2049); M.FireEvent("ACTIVE_TALENT_GROUP_CHANGED",2,1)
M.RunTimers(1.6); assert(#M.placed==0, "a spec change is given time to finish")
M.RunTimers(2); assert(count(49,72)==18 and #M.placed==17)
for slot=49,66 do assert(M.actions[slot].id==2000+slot, "spec 2 gets spec 2's buttons") end
assert(remembered(1)==36 and FP.cdb.barGuard.specs[1].slots[50].id==1050, "spec 1's memory is untouched")
-- Back to spec 1 with intact bars: nothing to do, and spec 2's memory stays.
M.RunTimers(20); M.specGroup=1
for slot=49,72 do put(slot,"spell",1000+slot) end
M.FireEvent("ACTIVE_TALENT_GROUP_CHANGED",1,2); M.RunTimers(6)
assert(#M.placed==17 and remembered(2)==30 and remembered(1)==36)   -- spec 2 = main bar 12 + its 18
-- The emptied bars arrive while the client still reports the old spec group.
M.RunTimers(20); M.WipeActions(49,72); M.RunTimers(2.5)
M.specGroup=2; M.FireEvent("ACTIVE_TALENT_GROUP_CHANGED",2,1); M.RunTimers(6)
assert(count(49,72)==18 and #M.placed==35)
for slot=49,72 do assert(not M.actions[slot] or M.actions[slot].id>=2000, "spec 1's buttons never land on spec 2's bars") end
assert(remembered(1)==36 and remembered(2)==30)
"""),
    "bars_unreadable_slots_are_not_treated_as_empty": (BAR_MEMORY + "M.secretActions=true\n", r"""
assert(#M.placed==0 and remembered(1)==36 and #FP.cdb.barGuard.log==0, "secret slot data changes nothing")
assert(FP.API.ReadActionBars()==nil and FP.API.GetActionSlot(49)==false)
M.secretActions=false; M.RunTimers(6)
assert(count(49,72)==24 and remembered(1)==36)
"""),
    "bars_unplaceable_buttons_retry_then_are_forgotten_quietly": (r"""
local snap={[49]={k="spell",id=1049},[50]={k="macro",id=3,n="Heal"},[51]={k="item",id=858},[52]={k="macro",id=4,n="Gone"},[53]={k="flyout",id=9}}
HearthAndHustleCharDB={barGuard={specs={[1]={slots=snap}},log={}}}
M.unknownSpells[1049]=true; M.macros.Heal=11
""", r"""
assert(#M.placed==2 and M.actions[50].kind=="macro" and M.actions[50].name=="Heal" and M.actions[51].id==858, "a macro is found by name, not by its old index")
assert(count(49,53)==2 and M.cursor==nil and said("Put 2 action buttons back on your bars (3 could not be restored)")==1)
assert(remembered(1)==5 and FP.cdb.barGuard.specs[1].slots[49].fails==1)
put(60,"spell",7); put(60); M.RunTimers(2)
assert(remembered(1)==5, "an ordinary edit does not drop buttons still owed")
M.RunTimers(12); M.RunTimers(12); M.RunTimers(30)
assert(#M.placed==2 and remembered(1)==2 and said("Put ")==1 and #FP.cdb.barGuard.log==3, "three attempts, then silence")
cmd("bars"); assert(said("last restore: 2 of 5 missing buttons put back on spec 1")==1)
"""),
    "bars_late_spell_data_is_restored_on_the_recheck": (r"""
HearthAndHustleCharDB={barGuard={specs={[1]={slots={[49]={k="spell",id=1049},[50]={k="spell",id=1050}}}},log={}}}
M.unknownSpells[1049]=true
""", r"""
assert(#M.placed==1 and not M.actions[49] and remembered(1)==2)
M.unknownSpells[1049]=nil; M.RunTimers(11)
assert(M.actions[49].id==1049 and #M.placed==2 and FP.cdb.barGuard.specs[1].slots[49].fails==nil)
"""),
    "bars_drag_defers_and_a_disabled_guard_is_inert": (BAR_MEMORY + 'M.cursor={kind="spell",id=1}\n', HUB + r"""
assert(#M.placed==0 and M.cursor and M.cursor.id==1 and remembered(1)==36, "a held spell is never dropped or overwritten")
M.cursor=nil; M.RunTimers(3); assert(count(49,72)==24)
cmd("bars"); assert(said("Action bar guard on")==1 and said("spec 1 (active): 36 buttons remembered")==1)
page("display"); check("barGuardEnabled",false); assert(FP.settings.barGuard.enabled==false)
M.RunTimers(20); M.WipeActions(49,72); M.RunTimers(20)
assert(#M.placed==24 and count(49,72)==0 and remembered(1)==36, "off means off: no reads, no writes")
check("barGuardNotice",false); assert(FP.settings.barGuard.announce==false)
check("barGuardEnabled",true); M.RunTimers(3)
assert(#M.placed==24 and remembered(1)==12, "what happened while it was off is not second-guessed")
"""),
    "bars_refused_change_pauses_the_guard": (BAR_MEMORY + r"""
local place=PlaceAction
PlaceAction=function(slot) M.FireEvent("ADDON_ACTION_BLOCKED","HearthAndHustle","PlaceAction()") end
""", r"""
assert(#M.placed==0 and B.blocked and said("refused an action bar change")==1)
assert(remembered(1)==36 and M.cursor==nil)
M.WipeActions(1,12); M.RunTimers(30)
local blocked=0; for _,e in ipairs(FP.db.errors) do if e.where=="ADDON_ACTION_BLOCKED" then blocked=blocked+1 end end
assert(blocked==1 and said("refused an action bar change")==1, "one refusal, one report, no retries this session")
FP.db.errors={}
"""),
}
for name, (preload, body) in BAR_CASES.items():
    boot = BOOT.replace('local FP = {}', preload + '\nlocal FP = {}')
    result = subprocess.run([LUA, "-"], input=boot + BAR_HELPERS + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + (result.stderr.splitlines() or ["no error output"])[0])

# v0.20.0: quest item sparkles. The module keeps the client's own loot sparkle
# setting switched on. Each case checks the one console variable it may write,
# and that nothing else is ever written and nothing is written in combat.
SPARKLE_HELPERS = r"""
local Q=FP.QuestSparkle
local NAME="outlineModeShowLootEffectWhenDisabled"
local function said(text) local n=0; for _,l in ipairs(M.Chat()) do if tostring(l):find(text,1,true) then n=n+1 end end return n end
local function writes() return #M.cvarWrites end
local function onlyOurs()
    for _,w in ipairs(M.cvarWrites) do assert(w.name==NAME and not w.combat, "wrote "..tostring(w.name)..(w.combat and " in combat" or "")) end
    assert(M.cvars.graphicsOutlineMode=="2" and M.cvars.graphicsQuality=="6", "another setting changed")
end
-- A graphics preset: the client switches the sparkle off and announces a setting change.
local function preset() M.cvars[NAME]="0"; M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.RunTimers(2) end
"""
SPARKLE_CASES = {
    "sparkle_login_switches_the_one_setting_on": ("", r"""
assert(M.cvars[NAME]=="1" and writes()==1 and M.cvarWrites[1].value=="1"); onlyOurs()
assert(FP.settings.questSparkle.enabled and FP.db.questSparkle.ours==true and FP.db.questSparkle.count==1)
local last=FP.db.questSparkle.last
assert(last.reason=="login" and last.was=="0" and last.outline==true and last.failed==nil and last.version==FP.version)
assert(said("Quest items you can pick up now sparkle")==1 and said("Outline Mode is on")==1)
M.FireEvent("PLAYER_ENTERING_WORLD"); M.FireEvent("CVAR_UPDATE","Sound_MasterVolume","1"); M.RunTimers(30)
assert(writes()==1 and said("now sparkle")==1, "a setting that is on is not written again")
cmd("sparkle"); assert(said("Quest item sparkles on")==1 and said("game setting: on")==1)
cmd("apicheck")
local row=FP.db.apicheck["70124-manual"].rows["probe:lootSparkle"]
assert(row and row.ok and row.note=="loot sparkle setting on; outline mode on", row and row.note)
"""),
    "sparkle_graphics_preset_reset_is_put_back": ("", r"""
preset(); assert(M.cvars[NAME]=="1" and writes()==2); onlyOurs()
assert(FP.db.questSparkle.last.reason=="setting" and FP.db.questSparkle.count==2 and said("now sparkle")==1, "one chat line, ever")
for _=1,6 do M.RunTimers(61); preset() end
assert(M.cvars[NAME]=="1" and writes()==8 and Q.stopped==nil, "presets minutes apart are not a tug of war"); onlyOurs()
"""),
    "sparkle_waits_for_combat_to_end": ("M.combatLockdown=true\n", r"""
assert(writes()==0 and M.cvars[NAME]=="0" and Q.deferred, "nothing is written in combat")
M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.RunTimers(5); assert(writes()==0)
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED")
assert(M.cvars[NAME]=="1" and writes()==1 and FP.db.questSparkle.last.reason=="combat end"); onlyOurs()
"""),
    "sparkle_off_puts_back_what_it_switched_on": ("", HUB + r"""
page("display"); check("questSparkleEnabled",false)
assert(FP.settings.questSparkle.enabled==false and M.cvars[NAME]=="0" and writes()==2 and FP.db.questSparkle.ours==nil)
assert(H.resultText:GetText():find("fully exit and restart",1,true), "the restart notice is shown where the tick was made")
preset(); M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(30)
assert(writes()==2 and M.cvars[NAME]=="0", "off means off: no writes in either direction")
check("questSparkleEnabled",true); assert(M.cvars[NAME]=="1" and writes()==3 and FP.db.questSparkle.ours==true); onlyOurs()
"""),
    "sparkle_leaves_a_setting_it_found_on": ('M.cvars.outlineModeShowLootEffectWhenDisabled="1"\n', r"""
assert(writes()==0 and FP.db.questSparkle.ours==nil and said("now sparkle")==0)
cmd("sparkle off"); assert(writes()==0 and M.cvars[NAME]=="1" and said("stays as it is")==1, "the player's own setting is not switched off")
cmd("sparkle"); assert(said("Quest item sparkles off")==1 and said("the game keeps it")==1)
"""),
    "sparkle_remembers_across_sessions_that_it_switched_it_on": (
        'M.cvars.outlineModeShowLootEffectWhenDisabled="1"\nHearthAndHustleDB={questSparkle={ours=true,introduced=true,count=3}}\n', r"""
assert(writes()==0 and said("now sparkle")==0)
cmd("sparkle off"); assert(writes()==1 and M.cvars[NAME]=="0" and FP.db.questSparkle.ours==nil and said("fully exit and restart")==1); onlyOurs()
"""),
    "sparkle_missing_or_secret_setting_is_inert": ("M.cvars.outlineModeShowLootEffectWhenDisabled=nil\n", r"""
assert(writes()==0 and said("now sparkle")==0)
cmd("sparkle on"); cmd("sparkle"); assert(writes()==0 and said("this client has no such setting")==2)
M.cvars[NAME]="0"; M.secretCVars=true
M.FireEvent("CVAR_UPDATE",M.Secret(),M.Secret()); M.RunTimers(5); cmd("sparkle")
assert(writes()==0 and M.cvars[NAME]=="0", "a secret value is not a value")
M.secretCVars=nil; M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.RunTimers(2)
assert(writes()==1 and M.cvars[NAME]=="1"); onlyOurs()
"""),
    "sparkle_tug_of_war_stops_writing": ("", r"""
for _=1,10 do preset() end
assert(writes()==4 and M.cvars[NAME]=="0" and Q.stopped=="contested", "writes "..writes())
assert(said("keeps switching the quest item sparkle off")==1 and FP.db.questSparkle.last.failed=="contested")
cmd("sparkle"); assert(said("paused until the next login")==1)
cmd("sparkle on"); assert(M.cvars[NAME]=="1" and writes()==5 and Q.stopped==nil, "asking again is the player's call"); onlyOurs()
"""),
    "sparkle_refused_change_pauses_until_next_login": ("M.cvarProtected=true\n", r"""
assert(writes()==1 and M.cvars[NAME]=="0" and Q.stopped=="blocked" and said("did not accept the quest item sparkle setting")==1)
preset(); M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(30); cmd("sparkle on")
assert(writes()==1 and said("did not accept the quest item sparkle setting")==1, "one refusal, one line, no retries this session")
assert(FP.db.questSparkle.ours==nil and FP.db.questSparkle.last.failed=="blocked" and said("now sparkle")==0)
local blocked=0; for _,e in ipairs(FP.db.errors) do if e.where=="ADDON_ACTION_BLOCKED" then blocked=blocked+1 end end
assert(blocked==1 and #FP.db.errors==1); FP.db.errors={}
"""),
    "sparkle_silent_refusal_also_pauses": ('M.cvarProtected="silent"\n', r"""
assert(writes()==1 and M.cvars[NAME]=="0" and Q.stopped=="refused" and FP.db.questSparkle.last.failed=="refused")
preset(); M.RunTimers(30); assert(writes()==1 and FP.db.questSparkle.ours==nil and said("now sparkle")==0)
"""),
    "sparkle_off_in_combat_waits_and_a_change_of_mind_cancels": ("", r"""
M.combatLockdown=true; cmd("sparkle off")
assert(writes()==1 and M.cvars[NAME]=="1" and Q.pendingOff and said("switched back after combat")==1)
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED")
assert(M.cvars[NAME]=="0" and writes()==2 and FP.db.questSparkle.ours==nil)
cmd("sparkle on"); M.combatLockdown=true; cmd("sparkle off"); cmd("sparkle on")
assert(writes()==3 and M.cvars[NAME]=="1" and not Q.pendingOff)
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(5)
assert(writes()==3 and M.cvars[NAME]=="1" and FP.db.questSparkle.ours==true, "off then on again in one fight changes nothing"); onlyOurs()
"""),
    "sparkle_switched_off_profile_writes_nothing": ("HearthAndHustleDB={settings={questSparkle={enabled=false}}}\n", r"""
preset(); M.FireEvent("PLAYER_ENTERING_WORLD"); M.FireEvent("PLAYER_REGEN_ENABLED"); M.RunTimers(30)
assert(writes()==0 and M.cvars[NAME]=="0" and FP.db.questSparkle.ours==nil and said("sparkle")==0)
cmd("sparkle off"); assert(writes()==0 and said("quest item sparkles off")==1)
"""),
}
for name, (preload, body) in SPARKLE_CASES.items():
    boot = BOOT.replace('local FP = {}', preload + '\nlocal FP = {}')
    result = subprocess.run([LUA, "-"], input=boot + SPARKLE_HELPERS + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + (result.stderr.splitlines() or ["no error output"])[0])

# v0.21.0: enemy watch. Hostile players the client already shows (nameplate,
# target, focus, mouseover) are listed, alerted on and counted. Each case uses
# mock unit tokens; M.Enemy puts an enemy player on one.
ENEMY_HELPERS = r"""
local W=FP.EnemyWatch
local DB=FP.db.enemyWatch
local base=#M.played
local function said(text) local n=0; for _,l in ipairs(M.Chat()) do if tostring(l):find(text,1,true) then n=n+1 end end return n end
local function rows() local out={}; for _,r in ipairs(W:Rows()) do out[#out+1]=r.text end return table.concat(out,"\n") end
local function near() local n=0; for _ in pairs(W.nearby) do n=n+1 end return n end
local function lastKit() return #M.played>base and M.played[#M.played].kit or nil end
local function sent() local out={}; for _,m in ipairs(M.addonSent) do if tostring(m):sub(1,3)=="EW;" then out[#out+1]=m end end return out end
local function msg(body,channel,sender) M.FireEvent("CHAT_MSG_ADDON","HHUSTLE",body,channel or "PARTY",sender or "Friend-Realm") end
"""
ENEMY_CASES = {
    "enemy_nameplate_gives_full_name_one_alert_and_a_record": ("", r"""
M.Enemy("nameplate1","Fetto","Vandike",{guild="Gankers",level=42})
assert(W.nearby["Fetto Vandike"] and said("Enemy nearby: Fetto Vandike (42 Rogue) <Gankers>")==1 and #M.notices==1)
assert(#M.played==base+1 and lastKit()==8458)
M.Tick(5)
assert(said("Enemy nearby")==1 and #M.notices==1 and #M.played==base+1, "still on screen is not a new encounter")
local p=DB.players["Fetto Vandike"]
assert(p.seen==1 and p.class=="ROGUE" and p.guild=="Gankers" and p.level==42 and DB.counts.nameplate==1)
assert(rows():find("Fetto Vandike",1,true) and rows():find("<Gankers>",1,true) and rows():find("42 Rogue",1,true))
M.Enemy("nameplate2","Fetto","Other")
assert(W.nearby["Fetto Other"] and near()==2 and said("Enemy nearby")==2, "the same first name is not the same player")
M.Gone("nameplate1"); M.RunTimers(60); M.Enemy("nameplate1","Fetto","Vandike")
assert(said("Enemy nearby: Fetto Vandike")==1 and p.seen==1, "back within two minutes: the same encounter")
M.Gone("nameplate1"); M.RunTimers(130); M.Enemy("nameplate1","Fetto","Vandike")
assert(said("Enemy nearby: Fetto Vandike")==2 and p.seen==2, "back after two minutes: a new one")
cmd("apicheck")
local row=FP.db.apicheck["70124-manual"].rows["probe:enemyWatch"]
assert(row and row.ok and row.note:find("enemy nameplates on, outside combat on",1,true), row and row.note)
"""),
    "enemy_target_focus_mouseover_count_and_others_do_not": ("", r"""
M.Enemy("target","Ann","Bee"); M.Enemy("focus","Cee","Dee"); M.Enemy("mouseover","Eff","Gee")
assert(W.nearby["Ann Bee"] and W.nearby["Cee Dee"] and W.nearby["Eff Gee"])
assert(DB.counts.target==1 and DB.counts.focus==1 and DB.counts.mouseover==1 and said("Enemy nearby")==3 and #M.notices==1)
M.Enemy("nameplate3","Friend","Ly",{enemy=false}); M.Enemy("nameplate4","Boar",nil,{player=false}); M.Tick(2)
assert(near()==3 and not DB.players["Friend Ly"] and not DB.players["Boar"], "own faction and creatures are not enemies")
M.Enemy("nameplate5","Dead","One",{dead=true}); M.Tick(1)
assert(near()==3 and said("Dead One")==0, "a corpse is not a sighting")
"""),
    "enemy_withheld_identity_is_counted_not_guessed": ("", r"""
M.Enemy("nameplate1","Hidden","One",{secret=true}); M.Tick(2)
assert(near()==0 and said("Enemy nearby")==0 and DB.counts.secret==3 and next(DB.players)==nil)
M.FireEvent("NAME_PLATE_UNIT_ADDED",M.Secret()); M.FireEvent("PARTY_KILL",M.Secret(),M.Secret())
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED",M.Secret(),M.Secret(),M.Secret())
assert(near()==0 and DB.lastKill==nil)
"""),
    "enemy_kill_on_sight_list_and_alert": ("", r"""
cmd("kos fetto vandike: ganked me in STV")
assert(DB.kos["Fetto Vandike"].reason=="ganked me in STV")
M.Enemy("nameplate1","Fetto","Vandike")
assert(said("KILL ON SIGHT: Fetto Vandike (40 Rogue) — ganked me in STV")==1 and lastKit()==8959 and rows():find("KOS",1,true))
assert(said("Enemy nearby")==0)
cmd("kos Fetto"); assert(DB.kos["Fetto Vandike"]==nil and said("removed from Kill On Sight")==1, "a first name finds the one known player")
M.Enemy("target","Ann","Bee"); cmd("kos"); assert(DB.kos["Ann Bee"], "no name means the targeted enemy")
cmd("kos +Ann Bee"); assert(said("already on Kill On Sight")==1 and DB.kos["Ann Bee"])
cmd("kos Ann Bee: corpse camper"); assert(DB.kos["Ann Bee"].reason=="corpse camper", "a reason updates, it does not remove")
cmd("kos -Ann Bee"); assert(not DB.kos["Ann Bee"]); cmd("kos -Ann Bee"); assert(said("is not on Kill On Sight")==1)
cmd("kos zug"); assert(not DB.kos["Zug"]); M.Enemy("nameplate5","Zug","Zug")
assert(said("KILL ON SIGHT: Zug Zug")==0, "unknown first names do not become wildcards")
cmd("kos zug"); assert(DB.kos["Zug Zug"], "a unique known first name resolves exactly")
M.Gone("target"); M.Enemy("target","Boar",nil,{player=false}); cmd("kos"); assert(said("Target an enemy player")==1)
cmd("kos list"); assert(said("KOS Zug Zug")==1)
"""),
    "enemy_ignore_list_is_silent": ("", r"""
cmd("ignore Fetto Vandike"); M.Enemy("nameplate1","Fetto","Vandike"); M.Tick(3)
assert(near()==0 and said("Enemy nearby")==0 and #M.notices==0 and not DB.players["Fetto Vandike"])
cmd("kos Fetto Vandike"); assert(DB.kos["Fetto Vandike"] and not DB.ignore["Fetto Vandike"], "Kill On Sight ends ignoring")
cmd("ignore +Fetto Vandike"); assert(DB.ignore["Fetto Vandike"] and not DB.kos["Fetto Vandike"])
cmd("ignore -Fetto Vandike"); M.Tick(2)
assert(W.nearby["Fetto Vandike"] and said("Enemy nearby: Fetto Vandike")==1)
cmd("ignore"); assert(said("Target an enemy player")==1)
"""),
    "enemy_watch_is_off_in_instances_and_when_switched_off": ("", r"""
M.instance={type="party",name="Scarlet Monastery",mapID=189}
M.Enemy("nameplate1","In","Dungeon"); M.Enemy("target","In","Dungeon"); M.Tick(2)
assert(near()==0 and said("Enemy nearby")==0 and #W:Rows()==0)
M.instance={type="pvp",name="Warsong Gulch",mapID=489}; M.Tick(2); assert(near()==0)
M.instance=nil; cmd("enemies off"); M.Tick(2); M.FireEvent("PLAYER_TARGET_CHANGED")
assert(near()==0 and said("Enemy nearby")==0, "off means off")
cmd("enemies on"); assert(W.nearby["In Dungeon"] and said("Enemy nearby: In Dungeon")==1)
"""),
    "enemy_unflagged_and_sanctuary_are_quiet_kos_is_not": ("", r"""
M.Enemy("nameplate1","Pve","Player",{canAttack=false})
assert(W.nearby["Pve Player"] and said("Enemy nearby")==0 and #M.notices==0 and rows():find("not flagged",1,true))
cmd("kos Quiet One"); M.Enemy("nameplate2","Quiet","One",{canAttack=false}); assert(said("KILL ON SIGHT: Quiet One")==1)
C_PvP.GetZonePVPInfo=function() return "sanctuary" end
M.Enemy("nameplate3","Booty","Bay"); cmd("kos Safe Here"); M.Enemy("nameplate4","Safe","Here")
assert(W.nearby["Booty Bay"] and said("Enemy nearby")==0 and said("KILL ON SIGHT: Safe Here")==0, "a sanctuary stays quiet")
cmd("enemies alerts off"); C_PvP.GetZonePVPInfo=function() return "contested" end
M.Enemy("nameplate6","No","Alert"); assert(W.nearby["No Alert"] and said("No Alert")==0 and #M.notices==1)
"""),
    "enemy_town_raid_does_not_flood_chat": ("", r"""
for i=1,20 do M.Enemy("nameplate"..i,"Raider","N"..i) end
assert(said("Enemy nearby")==5 and said("Many enemy players nearby")==1 and #M.notices==1 and #M.played==base+1)
assert(near()==20 and #W:Rows()==11 and rows():find("+10 more",1,true))
cmd("enemies sound off"); M.RunTimers(130); for i=1,20 do M.Gone("nameplate"..i) end
M.Enemy("nameplate1","Lone","Rogue"); assert(said("Enemy nearby: Lone Rogue")==1 and #M.notices==2 and #M.played==base+1, "sound off is silent")
"""),
    "enemy_stealth_alert_needs_a_readable_cast": ("", r"""
C_Spell.GetSpellName=function(id) return ({[1784]="Stealth",[1856]="Vanish",[5215]="Prowl",[20580]="Shadowmeld",[77777]="Prowl",[133]="Fireball"})[id] end
M.Enemy("nameplate1","Sneak","Thief")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate1","Cast-1",1784)
assert(said("Sneak Thief used Stealth near you")==1 and lastKit()==12197 and rows():find("stealth",1,true))
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate1","Cast-1",1784); assert(said("used Stealth")==1, "one alert per player per burst")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate1","Cast-2",M.Secret())
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate1","Cast-3",133)
assert(DB.counts.castSecret==1 and DB.counts.castRead==3 and DB.counts.stealth==1 and said(" used ")==1)
M.Enemy("nameplate2","Cat","Druid",{class="DRUID"}); M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate2","Cast-4",77777)
assert(said("Cat Druid used Prowl near you")==1, "a changed id is caught by the spell's name")
M.SetUnit("party1",{name="Friend",player=true}); M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","party1","Cast-5",1784)
M.Enemy("nameplate3","Boar",nil,{player=false}); M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate3","Cast-6",1784)
assert(said(" used ")==2, "only visible enemy players")
M.RunTimers(10); cmd("enemies stealth off"); M.FireEvent("UNIT_SPELLCAST_SUCCEEDED","nameplate1","Cast-7",1856)
assert(said(" used ")==2 and DB.counts.stealth==2)
"""),
    "enemy_win_is_my_killing_blow_on_a_player_i_saw": ("", r"""
M.SetUnit("player",{guid="Player-1-Me"}); M.SetUnit("pet",{guid="Pet-0-Wolf"})
local a=M.Enemy("nameplate1","Fetto","Vandike"); local b=M.Enemy("nameplate2","Ann","Bee")
M.FireEvent("PARTY_KILL","Player-1-Me",a.guid)
assert(DB.players["Fetto Vandike"].wins==1 and said("You killed Fetto Vandike. Record against them: 1 win, 0 losses.")==1 and DB.lastKill.result=="win")
M.FireEvent("PARTY_KILL","Pet-0-Wolf",b.guid); assert(DB.players["Ann Bee"].wins==1, "the pet's killing blow counts")
M.FireEvent("PARTY_KILL","Player-1-Friend",a.guid); assert(DB.players["Fetto Vandike"].wins==1 and DB.lastKill.result=="not yours")
M.FireEvent("PARTY_KILL","Player-1-Me","Player-1-NeverSeen"); assert(DB.lastKill.result=="victim never seen")
M.FireEvent("PARTY_KILL","Player-1-Me","Creature-0-1-2-3"); assert(DB.lastKill.result=="victim never seen", "a creature kill is not recorded at all")
cmd("enemies stats"); assert(said("Fetto Vandike")>=2 and said("met 1 · 1-0")==2)
"""),
    "enemy_loss_from_the_death_recap_or_the_one_who_targeted_me": ("", r"""
local a=M.Enemy("nameplate1","Fetto","Vandike"); M.SetUnit("nameplate1target",{is="player"}); M.Tick(1)
local p=DB.players["Fetto Vandike"]
M.recap={id=5,events={{sourceGUID=a.guid,sourceName="Fetto"}}}
M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(p.losses==1 and said("Fetto Vandike killed you.")==1 and DB.lastDeath.how=="recap")
M.units["nameplate1target"]=nil; M.RunTimers(20); M.FireEvent("PLAYER_DEAD"); M.RunTimers(2); M.RunTimers(4)
assert(p.losses==1 and DB.lastDeath.name==nil and DB.lastDeath.how:find("stale",1,true), "an old recap is not a new death")
M.SetUnit("nameplate1target",{is="player"}); M.Tick(1)
M.recap={id=6,events={{sourceGUID="Creature-0-1-2-3",sourceName="Boar"}}}; M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(p.losses==1 and DB.lastDeath.how:find("not an enemy player",1,true), "a creature's killing blow is nobody's win")
M.Tick(1); M.recap={id=7,events={}}; M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(p.losses==1 and DB.lastDeath.name==nil and DB.lastDeath.possible=="Fetto Vandike" and DB.lastDeath.confirmed==false, "targeting is an uncertain hint, never a confirmed loss")
M.Enemy("nameplate2","Ann","Bee"); M.SetUnit("nameplate2target",{is="player"}); M.Tick(1)
M.recap={id=8,events={}}; M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(p.losses==1 and not DB.players["Ann Bee"].losses and DB.lastDeath.how:find("2 had you targeted",1,true), "two suspects: nobody gets it")
M.recap={id=9,events={{sourceName="Ann"}}}; M.FireEvent("PLAYER_DEAD"); M.RunTimers(2)
assert(DB.players["Ann Bee"].losses==1, "a recap with a first name finds the one enemy seen with it")
"""),
    "enemy_party_share_sends_once_and_trusts_only_the_party": ("", r"""
M.inGroup=true; M.SetUnit("party1",{name="Friend",realm="Realm"})
M.Enemy("nameplate1","Fetto","Vandike",{guild="Bad;Guild|x"}); M.Tick(3)
assert(#sent()==1 and sent()[1]=="EW;1;Fetto Vandike;ROGUE;40;BadGuildx", sent()[1])
msg("EW;1;Zug Zug;WARRIOR;60;Horde Slayers")
assert(W.nearby["Zug Zug"].by=="Friend" and said("Enemy nearby: Zug Zug (60 Warrior) <Horde Slayers> — seen by Friend")==1)
assert(not DB.players["Zug Zug"] and #sent()==1 and DB.counts.party==1, "a friend's sighting is not my encounter and is not passed on")
msg("EW;1;Zug Zug;WARRIOR;60;Horde Slayers"); msg("EW;1;Fetto Vandike;ROGUE;40;"); assert(said("seen by Friend")==1, "already known here")
M.Enemy("nameplate3","Zug","Zug",{class="WARRIOR",level=60})
assert(DB.players["Zug Zug"].seen==1 and DB.counts.nameplate==2 and W.nearby["Zug Zug"].by==nil, "then seen here: met")
assert(said("Enemy nearby: Zug Zug")==1 and #sent()==1, "but not announced or sent a second time")
msg("EW;1;Stranger One;MAGE;60;","PARTY","Stranger-Realm"); msg("EW;1;Whisper One;MAGE;60;","WHISPER"); msg("EW;2;Future One;MAGE;60;")
msg("EW;1;;MAGE;60;"); msg("EW;1;Bad Level;MAGE;abc;"); msg("EW;1;Too;Many;Fields;MAGE;60;x")
msg("EW;1;Odd Class;m|cffage;999;")
assert(near()==3 and W.nearby["Odd Class"] and not W.nearby["Odd Class"].class and not W.nearby["Odd Class"].level, "bad fields are dropped, not shown")
cmd("ignore Loud One"); msg("EW;1;Loud One;MAGE;60;"); assert(not W.nearby["Loud One"])
cmd("enemies share off"); msg("EW;1;Late One;MAGE;60;"); M.RunTimers(5); M.Enemy("nameplate2","Ann","Bee")
assert(not W.nearby["Late One"] and W.nearby["Ann Bee"] and #sent()==1, "share off: nothing in, nothing out")
"""),
    "enemy_nameplate_help_is_said_once_and_switched_only_on_request": ('M.cvars.nameplateShowAll="0"\n', HUB + r"""
local function plateWrites() local n=0; for _,w in ipairs(M.cvarWrites) do if w.name:find("^nameplate") then n=n+1 end end return n end
assert(said("nameplates only show in combat")==1 and DB.nameplateHint and plateWrites()==0, "the addon says it, it does not switch it")
cmd("enemies"); assert(said("nameplates only show in combat")==2)
M.combatLockdown=true; cmd("enemies nameplates")
assert(plateWrites()==0 and M.cvars.nameplateShowAll=="0" and said("cannot be changed in combat")==1)
M.combatLockdown=false; page("pvp"); assert(H.controls.enemyNameplates:IsEnabled()); click("enemyNameplates")
assert(M.cvars.nameplateShowAll=="1" and M.cvars.nameplateShowEnemies=="1" and plateWrites()==1, "only the setting that was off is written")
H:Refresh(); assert(not H.controls.enemyNameplates:IsEnabled())
for _,w in ipairs(M.cvarWrites) do assert(w.name=="nameplateShowAll" or w.name=="outlineModeShowLootEffectWhenDisabled", w.name) end
"""),
    "enemy_hub_controls_lists_and_settings": ("", HUB + r"""
page("pvp")
check("enemyWatchAlerts",false); check("enemyWatchSound",false); check("enemyWatchStealth",false); check("enemyWatchShare",false)
local set=FP.settings.enemyWatch
assert(set.enabled and not set.alerts and not set.sound and not set.stealth and not set.share)
check("enemyWatchEnabled",false); assert(not set.enabled); check("enemyWatchEnabled",true)
field("kosName","fetto vandike"); field("kosReason","camper"); click("kosAdd")
assert(DB.kos["Fetto Vandike"].reason=="camper")
field("kosReason",""); click("kosAdd"); assert(DB.kos["Fetto Vandike"] and H.resultText:GetText():find("already on Kill On Sight",1,true), "Add never removes")
selectRow("kosList",1); click("kosRemove"); assert(not DB.kos["Fetto Vandike"])
field("ignoreName","Ann Bee"); click("ignoreAdd"); click("ignoreAdd"); assert(DB.ignore["Ann Bee"], "Ignore never un-ignores")
selectRow("ignoreList",1); click("ignoreRemove"); assert(not DB.ignore["Ann Bee"])
M.Enemy("nameplate1","Fetto","Vandike"); click("enemyList"); assert(H.resultText:GetText():find("Fetto Vandike",1,true))
click("enemyStats"); assert(H.resultText:GetText():find("met 1",1,true))
"""),
    "enemy_list_supersedes_the_first_name_roster_only_when_it_has_rows": ("", r"""
M.SetUnit("target",{name="Duelist",player=true,canAttack=true,class="MAGE",level=30}); M.FireEvent("PLAYER_TARGET_CHANGED")
local function section(name) local on=false; for _,r in ipairs(FP.PvP:Collect()) do if r.header and r.text:find(name,1,true) then on=true end end return on end
assert(section("Enemies seen") and not section("Enemies nearby"), "a duel opponent of my own faction stays on the old list")
M.Enemy("nameplate1","Fetto","Vandike")
assert(section("Enemies nearby") and not section("Enemies seen"), "no double listing")
"""),
}
for name, (preload, body) in ENEMY_CASES.items():
    boot = BOOT.replace('local FP = {}', preload + '\nlocal FP = {}')
    result = subprocess.run([LUA, "-"], input=boot + ENEMY_HELPERS + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors: "..tostring(FP.db.errors[1] and FP.db.errors[1].err))\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print("  " + (result.stderr.splitlines() or ["no error output"])[0])

# Review transition cases use preloads to exercise persisted state after reload.
from review_fixes import REVIEW_FIX_CASES
for name, (preload, body) in REVIEW_FIX_CASES.items():
    boot = BOOT.replace('local FP = {}', preload + '\nlocal FP = {}')
    result = subprocess.run([LUA, "-"], input=boot + body + '\nassert(#FP.db.errors == 0, "unexpected stored addon errors")\n', text=True, capture_output=True)
    print(("FAIL " if result.returncode else "PASS ") + name)
    if result.returncode:
        failed += 1
        print(result.stdout + result.stderr)

# The file tool, on fixtures written the way the release client writes them: CRLF, no indentation.
def client_lua(variable, rows):
    return ("\r\n" + variable + " = {\r\n" + "".join(row + "\r\n" for row in rows) + "}\r\n").encode()

ACCOUNT_ROWS = ['["settings"] = {', '["arrow"] = {', '["x"] = -410.5,', '["shown"] = true,', '},', '["autoNext"] = false,', '},',
                '["data"] = {', '["quests"] = {', '[1322] = {', '["t"] = "The Black Shield",', '},', '},', '},',
                '["meta"] = {', '["created"] = 77,', '["builds"] = {', '},', '["counters"] = {', '},', '},', '["version"] = 2,']
CHAR_ROWS = ['["waypoints"] = {', '{', '["id"] = 900,', '["mapID"] = 1413,', '["x"] = 0.5,', '["y"] = 0.68,', '["title"] = "Legacy waypoint",',
             '["persistent"] = false,', '["radius"] = 15,', '["t"] = 5,', '},', '},', '["completed"] = {', '[100] = true,', '},',
             '["nextId"] = 901,', '["activeId"] = 900,']
OUR_TOC = "## Title: ForeverPath\n## X-License: MIT\nAPI\\Adapter.lua\n"
with tempfile.TemporaryDirectory(prefix="foreverpath-rename-") as tmp:
    problems = []
    def tree(name, toc=OUR_TOC, char=client_lua("ForeverPathCharDB", CHAR_ROWS)):
        client = Path(tmp) / name
        account, character = client / "WTF/Account/ACCT/SavedVariables", client / "WTF/Account/ACCT/Realm/Hero/SavedVariables"
        addon = client / "Interface/AddOns/ForeverPath"
        for folder in (account, character, addon, client / "Interface/AddOns/Other"):
            folder.mkdir(parents=True)
        (account / "ForeverPath.lua").write_bytes(client_lua("ForeverPathDB", ACCOUNT_ROWS))
        (character / "ForeverPath.lua").write_bytes(char)
        (addon / "ForeverPath.toc").write_text(toc)
        return client, account, character, addon
    def tool(client, *extra):
        return subprocess.run(["python3", "tools/migrate-from-foreverpath.py", "--client", str(client), "--no-process-check", *extra], text=True, capture_output=True)

    client, account, character, addon = tree("ours")
    before = {p: p.read_bytes() for p in (account / "ForeverPath.lua", character / "ForeverPath.lua")}
    if tool(client, "--dry-run").returncode != 0 or any(p.read_bytes() != raw for p, raw in before.items()) or not addon.is_dir():
        problems.append("dry run changed something")
    result = tool(client)
    migrated = (account / "HearthAndHustle.lua", character / "HearthAndHustle.lua")
    if result.returncode != 0 or not all(p.is_file() for p in migrated):
        problems.append("migration did not produce both files: " + result.stdout)
    else:
        if migrated[0].read_bytes() != before[account / "ForeverPath.lua"].replace(b"ForeverPathDB = ", b"HearthAndHustleDB = "):
            problems.append("account file changed beyond its variable name")
        if migrated[1].read_bytes() != before[character / "ForeverPath.lua"].replace(b"ForeverPathCharDB = ", b"HearthAndHustleCharDB = "):
            problems.append("character file changed beyond its variable name")
        if (account / "ForeverPath.lua").exists() or (account / "ForeverPath.lua.pre-rename").read_bytes() != before[account / "ForeverPath.lua"]:
            problems.append("original account file was not kept as .pre-rename")
        if addon.exists() or not (client / "Interface/AddOns/Other").is_dir():
            problems.append("old addon folder handling is wrong")
        if tool(client).returncode != 0 or migrated[0].read_bytes().count(b"HearthAndHustleDB = ") != 1:
            problems.append("second run is not a clean no-op")
        boot = BOOT.replace('local FP = {}', 'dofile(%r); dofile(%r)\nlocal FP = {}' % (str(migrated[0]), str(migrated[1])))
        loaded = subprocess.run([LUA, "-"], input=boot + r"""
assert(FP.settings.arrow.x==-410.5 and FP.settings.autoNext==false and FP.data.quests[1322].t=="The Black Shield" and FP.db.meta.created==77)
assert(FP.cdb.nextId==901 and active() and active().title=="Legacy waypoint" and FP.migratedFrom==nil and #FP.db.errors==0)
""", text=True, capture_output=True)
        if loaded.returncode:
            problems.append("addon did not load the migrated files: " + (loaded.stderr.splitlines() or ["?"])[0])

    # A different addon owns the old name: neither its folder nor unrecognised data may be touched.
    client, account, character, addon = tree("foreign", toc="## Title: ForeverPath\n## X-License: GPL-3.0-only\nCore.lua\n",
                                              char=client_lua("ForeverPathCharDB", ['["step"] = 3,']))
    before = {p: p.read_bytes() for p in (account / "ForeverPath.lua", character / "ForeverPath.lua")}
    result = tool(client)
    if result.returncode == 0 or any(p.read_bytes() != raw for p, raw in before.items()) or not addon.is_dir() or (account / "HearthAndHustle.lua").exists():
        problems.append("unrecognised data or a foreign addon folder was changed: " + result.stdout)

    # An existing new file is never overwritten.
    client, account, character, addon = tree("existing")
    (account / "HearthAndHustle.lua").write_bytes(b"\r\nHearthAndHustleDB = {\r\n}\r\n")
    result = tool(client)
    if result.returncode != 0 or (account / "HearthAndHustle.lua").read_bytes() != b"\r\nHearthAndHustleDB = {\r\n}\r\n" or not (account / "ForeverPath.lua").exists():
        problems.append("an existing HearthAndHustle.lua was overwritten")
    print(("FAIL " if problems else "PASS ") + "rename_migration_tool_legacy_fixture")
    for problem in problems:
        print("  " + problem)
    failed += 1 if problems else 0

# Corrupt an actual XML file in an ephemeral copy; never change the real checkout.
with tempfile.TemporaryDirectory(prefix="foreverpath-gate-review-") as tmp:
    for name in ("HearthAndHustle", "HearthAndHustle_GearData", "tests", "tools"):
        shutil.copytree(name, Path(tmp) / name)
    (Path(tmp) / "HearthAndHustle/Nav/MapPins.xml").write_text("<Ui><broken></Ui>\n")
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
        for name in ("HearthAndHustle", "HearthAndHustle_GearData", "tests", "tools"):
            shutil.copytree(name, Path(tmp) / name)
        env = os.environ.copy()
        command = ["bash", "tools/check.sh"]
        if scenario == "missing_toc_file":
            with (Path(tmp) / "HearthAndHustle/HearthAndHustle.toc").open("a") as toc:
                toc.write("Missing.xml\n")
        elif scenario == "compiler_failure":
            env["LUAC"] = "/bin/false"
        else:
            addons = Path(tmp) / "AddOns"
            addons.mkdir()
            sentinel = addons / "HearthAndHustle"
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

print(f"{failed} failed / {len(CASES) + 13 + len(RENAME_CASES) + len(BAR_CASES) + len(SPARKLE_CASES) + len(ENEMY_CASES) + len(REVIEW_FIX_CASES) + 1} preflight regressions")
raise SystemExit(1 if failed else 0)
