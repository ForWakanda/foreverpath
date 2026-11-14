"""Quest guidance scenarios; source markers and approximate areas stay distinct."""

def cases(fixture, hub):
    return {
        'quest_guidance_area_does_not_invent_sources_or_progress': fixture + r'''
M.quests={};LibQuestieDB=nil
local area={questID=99001,title="Unknown quest",waypoint={1445,.7,.6},objectives={objective("Unknown target: 0/3","monster")}}
M.AddQuest(area);Q:Refresh(true)
assert(Q.matched==0 and Q.missing==1 and Q.areas==1 and #Q.groups==1)
assert(Q.groups[1].kind=="Area" and Q:Nearest(99001,1)==nil)
assert(#Q:WorldPins(1445)>0 and Q.coverage[99001].area)
FP.settings.questEventHints=false;assert(#Q:VisibleGroups()==0)
OpenWorldMap=function(map)WorldMapFrame:Show();WorldMapFrame:SetMapID(map) end
assert(Q:ShowQuest(99001) and FP.settings.questEventHints)
Q:Guide({entries={{group=Q.groups[1],point=Q.groups[1].points[1]}}})
assert(active().desc:find("not an exact target",1,true))
M.complete[99001]=true;Q:Refresh(true)
assert(Q.areas==0 and not active())
''',
        'quest_guidance_client_area_validates_poi_and_missing_coordinates': r'''
M.quests={};local q=addQuest(99001);q.waypoint=nil
C_QuestLog.GetNextWaypoint=function()return nil end
C_QuestLog.GetNextWaypointForMap=function()return nil end
FP.API.GetQuestsOnMap=function()return {{questID=99001,isQuestStart=true,x=.1,y=.2},{questID=99001,x=1.2,y=.3}} end
assert(FP.API.GetQuestArea(99001)==nil)
FP.API.GetQuestsOnMap=function()return {{questID=99001,x=.6,y=.7}} end
local m,x,y=FP.API.GetQuestArea(99001);assert(m==M.mapID and x==.6 and y==.7)
FP.API.GetQuestsOnMap=function()return {{questID=M.Secret(),x=M.Secret(),y=.7}} end
assert(FP.API.GetQuestArea(99001)==nil)
''',
        'quest_guidance_locations_ignore_filters_but_browsing_preserves_route': fixture + hub + r'''
M.mapID=1445;M.px=.34;M.py=.25;FP.Pos:Refresh(true)
cmd("way 60 60 Preserve");local before=active()
Q:ToggleHidden(9101);FP.settings.questWorldPins=false
local settings,character=snapshot(FP.settings),snapshot(FP.cdb)
FP.QuestLocationPanel:Open(9101)
assert(H.selected=="locations" and #H.controls.questSourceLocations.items>0)
assert(snapshot(FP.settings)==settings and snapshot(FP.cdb)==character and active()==before)
assert(Q:LocationSummary(9101):find("filters",1,true))
local count=#M.frames;H:Open("navigation");FP.QuestLocationPanel:Open(9101);assert(#M.frames>=count)
count=#M.frames;FP.QuestLocationPanel:Open(9101);assert(#M.frames==count)
M.AddQuest({questID=9102,title="Second",objectives={objective("Lost Key: 0/1","item")}});Q:Refresh(true)
FP.QuestLocationPanel:Open(9102);assert(FP.QuestLocationPanel.questID==9102)
FP.QuestLocationPanel:Open(9101);assert(FP.QuestLocationPanel.questID==9101)
OpenWorldMap=function(map)WorldMapFrame:Show();WorldMapFrame:SetMapID(map) end
click("showQuestMap")
assert(WorldMapFrame:GetMapID()==1445 and FP.settings.questWorldPins and not FP.cdb.questMapHidden[9101])
assert(Q.focusedQuest==9101 and active()==before and not H.frame:IsShown())
''',
        'quest_guidance_map_action_fails_without_mutating_filters': fixture + r'''
FP.settings.worldMapPins=false;Q:ToggleHidden(9101)
OpenWorldMap=nil
local before=snapshot(FP.settings)..snapshot(FP.cdb)
assert(not Q:ShowQuest(9101))
assert(snapshot(FP.settings)..snapshot(FP.cdb)==before)
WorldMapFrame:Hide();OpenWorldMap=function()end
assert(not Q:ShowQuest(9101) and snapshot(FP.settings)..snapshot(FP.cdb)==before)
local old=Q:Locations(9101)[1];M.quests={};Q:Refresh(true)
OpenWorldMap=function()error("stale selection opened a map")end
assert(not Q:ShowQuest(9101,old))
''',
        'quest_guidance_minimap_distant_cue_is_single_and_clears_near_source': fixture + r'''
M.mapID=1445;M.px=.7;M.py=.7;FP.Pos:Refresh(true);Q:Focus(9101)
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
local f=assert(FP.Pins.questDirection);assert(f:IsShown() and f.distance>FP.API.GetMinimapViewRadius())
local count=#M.frames
FP.Pins:UpdateQuestDirection(FP.Pos.cache);assert(#M.frames==count)
FP.API.IsMinimapRotating=function()return true end;FP.Pos.cache.facing=nil
FP.Pins:UpdateQuestDirection(FP.Pos.cache);assert(f:IsShown())
local p=f.entry.point;M.px=p.x;M.py=p.y;FP.Pos:Refresh(true)
FP.Pins.lastObjectiveMini=nil;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache)
assert(not f:IsShown() and #FP.Pins.objectiveMini>0)
M.px=.7;M.py=.7;FP.Pos:Refresh(true);Q:ToggleHidden(9101)
FP.Pins:UpdateQuestDirection(FP.Pos.cache);assert(not f:IsShown())
Q:Focus(9101);FP.Pins:UpdateQuestDirection(FP.Pos.cache);assert(f:IsShown())
FP.settings.questMinimapPins=false;FP.Pins:UpdateObjectiveMinimap(FP.Pos.cache);assert(not f:IsShown())
''',
        'quest_guidance_map_labels_and_render_receipt_follow_focus': fixture + r'''
Q:Focus(9101);FP.Pins.provider:RefreshAllData()
local labelled=0
for _,p in ipairs(WorldMapFrame._pins) do if p.point and p.point.attention==9101 then
 if p.sourceLabel:IsShown() then labelled=labelled+1 end
 assert(p:GetWidth()==22)
end end
assert(labelled>0 and labelled<=3)
assert(FP.db.questLocations.world.quests[9101]>0)
local old=FP.db.questLocations.world
WorldMapFrame:Hide();Q:Refresh(true);assert(FP.db.questLocations.world==old)
Q.focusedQuest=nil;FP.API.GetSelectedQuest=function()return nil end;FP.Waypoints:Clear();Q.worldCache={}
for _,pin in ipairs(Q:WorldPins(1445)) do assert(not pin.label) end
''',
        'quest_guidance_location_list_shows_progress_and_completes_cleanly': fixture + hub + r'''
FP.QuestLocationPanel:Open(9101);local items=H.controls.questSourceLocations.items
assert(#items>3)
local row=items[1];local previous=-1
for _,r in ipairs(items) do if r.distance then assert(r.distance>=previous);previous=r.distance end end
click("guideQuestSource");assert(active().source.questID==9101)
M.complete[9101]=true;Q:Refresh(true);H:Refresh()
assert(not active())
for _,r in ipairs(H.controls.questSourceLocations.items) do assert(r.group.kind=="Turnin") end
''',
    }
