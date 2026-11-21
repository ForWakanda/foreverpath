"""Routes and roaming areas of quest targets (v0.30.0). Mock-only.

The report: "Spear of the Skylord" on Mount Hyjal. The quest needs one item from one
named creature, Zarrat Wormwing, which never stands still; the addon sent the player
hunting for it with no idea where it moves. The quest database stores a walked route
for some creatures (`waypoints`) and, for others, only the many places they were seen.
Nothing read the routes, and the sightings were shown as unrelated markers.
The fixture uses the shapes of the real records: Zarrat's first 30 places from
QuestieDB 1.1.3, and a route with a gap in it.
"""

PATHS = r'''
local Q,Pins=FP.QuestObjectives,FP.Pins
local ZARRAT={{46.45,59},{46.74,56.59},{47.21,56.92},{47.28,54.92},{47.32,55.56},{47.42,57.63},{47.46,56.07},{47.73,58.42},{47.79,58.94},{47.84,55.32},
 {48.03,56.67},{48.14,57.58},{48.16,54.84},{48.25,55.64},{48.25,58.7},{48.65,59.29},{48.8,55.4},{48.83,57.32},{48.86,54.83},{48.98,58.49},
 {49.5,56.34},{49.53,55.74},{49.58,56.74},{49.61,58.12},{49.63,59.47},{49.86,57.43},{50.04,58.41},{50.12,56.12},{50.52,59.03},{50.54,56.53}}
local data={
 Quest={
  [91883]={name="Spear of the Skylord",objectives={nil,nil,{{268998}}}},
  [104]={name="The Coastal Menace",objectives={nil,nil,{{3636}}}},
  [9201]={name="Thin the Flock",objectives={{{41027}}}},
  [9202]={name="Two Suspects",objectives={nil,nil,{{9302}}}},
  [9203]={name="Far Apart",objectives={{{9403}}}},
  [9204]={name="Kill the Walker",objectives={{{391}}}},
 },
 Npc={
  [260826]={name="Zarrat Wormwing",spawns={[616]=ZARRAT}},
  [263919]={name="Searshrike Wormwing"},
  [391]={name="Old Murk-Eye",spawns={[40]={{30,80}}},
   waypoints={[40]={{{30,80},{32,82},{34,81},{-1,-1},{36,80},{38,79},{40,78}},{{50,50}},{{60,10},{"x",11},{62,12},{64,14}}},[718]={{{10,10},{20,20}}}}},
  [41027]={name="Wormwing Screecher",spawns={[616]=ZARRAT}},
  [9401]={name="First Suspect",spawns={[616]={{20,20},{20.5,20},{21,20.4},{20.2,21},{21,21}}}},
  [9402]={name="Second Suspect",spawns={[616]={{22,20},{22.5,20},{23,20.4},{22.2,21},{23,21}}}},
  [9403]={name="Wandering Rare",spawns={[616]={{10,10},{50,50},{90,90},{10,90},{90,10}}}},
 },
 Object={},
 Item={[268998]={name="Omnuron's Spear",npcDrops={260826,263919}},[3636]={name="Scale of Old Murk-Eye",npcDrops={391}},
  [9302]={name="Stolen Ledger",npcDrops={9401,9402}}},
}
local support={private={areaIdToUiMapId="return {[616]=2482,[40]=1436,[718]=279}",dungeons={[718]={"Wailing Caverns",nil,17,{{17,46,36}}}}}}
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function(v)return v==1 end,Support={Get=function()return support end}}
for _,kind in ipairs({"Quest","Npc","Object","Item"}) do local k=kind;LibQuestieDB[k]={Get=function(id,key) return data[k][id] and data[k][id][key] end} end
local function log(id,text,kind,required)
 M.AddQuest({questID=id,title=data.Quest[id].name,objectives={{text=text,type=kind,finished=false,numFulfilled=0,numRequired=required}}})
end
local function stand(id,x,y) M.mapID=id;M.px=x;M.py=y;FP.Pos:Refresh(true) end
local function map(id) WorldMapFrame:Show();WorldMapFrame.mapID=nil;WorldMapFrame:SetMapID(id);Pins.provider:RefreshAllData();return FP.db.questLocations.world end
local function lines() local out={};for _,l in ipairs(Pins.routeLayer and Pins.routeLayer.lines or {}) do if l:IsShown() then out[#out+1]=l end end;return out end
local function group(id) for _,g in ipairs(Q.groups) do if g.questID==id then return g end end end
local function near(a,b) return math.abs(a-b)<1e-6 end
M.tooltipLines={}
GameTooltip.SetOwner=function(self,owner) self._owner=owner;M.tooltipLines={} end
GameTooltip.AddLine=function(_,text) M.tooltipLines[#M.tooltipLines+1]=tostring(text) end
M.quests={}
'''


def cases(hub):
    return {
        # the report itself
        'mob_paths_a_roaming_single_target_gets_an_outline_and_says_so': PATHS + r'''
log(91883,"0/1 Omnuron's Spear","item",1);stand(2482,.6,.6);Q:Refresh(true)
local g=assert(group(91883));assert(#g.points==30 and #g.paths==0)
local move=Q:Movement(g);assert(#move.routes==0 and #move.areas==1)
local area=move.areas[1]
assert(area.name=="Zarrat Wormwing" and area.count==30 and area.mapID==2482)
local ring=area.points
assert(#ring>=4 and ring[1].x==ring[#ring].x and ring[1].y==ring[#ring].y,"the outline closes")
-- every recorded place lies inside the outline: same turn direction along every edge
for _,p in ipairs(g.points) do
 local sign
 for i=1,#ring-1 do
  local a,b=ring[i],ring[i+1]
  local c=(b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x)
  assert(c~=0,"a place sits on the outline");sign=sign or (c>0);assert((c>0)==sign,"a recorded place is outside the outline")
 end
end
local report=map(2482)
assert(report.paths.areas==1 and report.paths.routes==0 and report.paths.lines==#ring-1)
assert(report.paths.names[1]=="Zarrat Wormwing (area, 30 places)",report.paths.names[1])
assert(#lines()==#ring-1 and report.questPins>0)
local labelled=0
for _,pin in ipairs(Q:WorldPins(2482)) do if pin.label then labelled=labelled+1;assert(pin.label=="Zarrat Wormwing: roams this area",pin.label) end end
assert(labelled==1)
local pin=Q:WorldPins(2482)[1];Q:Tooltip(pin,WorldMapFrame)
local text=table.concat(M.tooltipLines or {},"\n");assert(text:find("Moves around inside the outlined area",1,true),text)
local m,x,y,how=FP.Planner:ResolveObjective(91883,1);assert(m==2482 and how=="roaming area: Zarrat Wormwing",how)
assert(Q:Guide(pin) and FP.Waypoints:GetActive().desc:find("moves around inside the area outlined",1,true))
''',
        'mob_paths_a_stored_route_is_drawn_stroke_by_stroke': PATHS + r'''
log(104,"0/1 Scale of Old Murk-Eye","item",1);stand(1436,.5,.5);Q:Refresh(true)
local g=assert(group(104));assert(#g.points==1)
-- the gap splits one path in two, the single point is no route, the bad vertex ends a stroke, the dungeon zone is left out
assert(#g.paths==3,#g.paths)
local sizes={};for _,p in ipairs(g.paths) do assert(p.mapID==1436 and p.entityID==391 and p.name=="Old Murk-Eye");sizes[#sizes+1]=#p.points end
table.sort(sizes);assert(table.concat(sizes,",")=="2,3,3",table.concat(sizes,","))
local move=Q:Movement(g);assert(#move.routes==3 and #move.areas==0,"a creature with a route gets no outline")
local report=map(1436)
assert(report.paths.routes==3 and report.paths.areas==0 and report.paths.lines==5,report.paths.lines)
local canvas=WorldMapFrame:GetCanvas();local r,gg,b=Q:Style(104)
local ends={}
for _,l in ipairs(lines()) do
 assert(l._start[2]==canvas and l._finish[2]==canvas and l._start[1]=="TOPLEFT")
 assert(near(l._color[1],r) and near(l._color[2],gg) and near(l._color[3],b) and l._thickness==12,"3 pixels on a canvas at quarter scale")
 ends[#ends+1]=string.format("%.0f,%.0f>%.0f,%.0f",l._start[3],l._start[4],l._finish[3],l._finish[4])
end
table.sort(ends)
assert(table.concat(ends," ")=="1200,-1920>1280,-1968 1280,-1968>1360,-1944 1440,-1920>1520,-1896 1520,-1896>1600,-1872 2480,-288>2560,-336",table.concat(ends," "))
for _,pin in ipairs(Q:WorldPins(1436)) do assert(pin.label=="Old Murk-Eye: walks the line",tostring(pin.label)) end
Q:Tooltip(Q:WorldPins(1436)[1],WorldMapFrame);assert(table.concat(M.tooltipLines,"\n"):find("Walks the route drawn on the map",1,true))
''',
        'mob_paths_arrow_goes_to_the_nearest_stretch_of_the_route': PATHS + r'''
log(9204,"0/1 Old Murk-Eye slain","monster",1);stand(1436,.4,.77);Q:Refresh(true)
local p,moving=Q:Nearest(9204,1)
assert(p.role=="path" and moving=="route" and near(p.x,.40) and near(p.y,.78),p.role)
local m,x,y,how=FP.Planner:ResolveObjective(9204,1)
assert(m==1436 and near(x,.40) and how=="patrol route: Old Murk-Eye",how)
stand(1436,.3,.8);p,moving=Q:Nearest(9204,1);assert(near(p.x,.30) and moving=="route")
FP.settings.autoNext=false;FP.Waypoints:Clear();FP.Planner.waiting={kind="objective",title="Kill the Walker",how=how,mapID=1436,x=.4,y=.78}
FP.Arrow:OnUpdate(1);assert(FP.Arrow.dist:GetText()=="On its route — it walks the line on your map",FP.Arrow.dist:GetText())
FP.Planner.waiting.how="roaming area: Zarrat Wormwing";FP.Arrow:OnUpdate(1);assert(FP.Arrow.dist:GetText():find("It roams here",1,true))
FP.Planner.waiting.how="known source: Cave Spider";FP.Arrow:OnUpdate(1);assert(FP.Arrow.dist:GetText()=="Objective area — search nearby")
''',
        'mob_paths_no_outline_for_many_kills_two_creatures_or_scattered_places': PATHS + r'''
log(9201,"0/8 Wormwing Screecher slain","monster",8)
log(9202,"0/1 Stolen Ledger","item",1)
log(9203,"0/1 Wandering Rare slain","monster",1)
stand(2482,.5,.5);Q:Refresh(true)
for _,id in ipairs({9201,9202,9203}) do
 local g=assert(group(id),id);assert(#g.points>=5)
 local move=Q:Movement(g);assert(#move.areas==0 and #move.routes==0,id)
end
local report=map(2482);assert(report.paths.lines==0 and report.questPins>0 and #lines()==0)
for _,pin in ipairs(Q:WorldPins(2482)) do assert(not pin.label) end
-- the same places, needed once: now it is one creature to find
M.quests={};log(9203,"0/1 Wormwing Screecher slain","monster",1);data.Quest[9203].objectives={{{41027}}};Q:Refresh(true)
assert(#Q:Movement(group(9203)).areas==1)
-- once the reference stores its route, the route is the answer: no outline around the same places
data.Npc[41027].waypoints={[616]={{{46,55},{48,57},{50,59}}}};Q:Refresh(true)
local move=Q:Movement(group(9203));assert(#move.routes==1 and #move.areas==0)
report=map(2482);assert(report.paths.routes==1 and report.paths.areas==0 and report.paths.lines==2)
''',
        'mob_paths_lines_are_reused_rescaled_and_hidden_off_the_map': PATHS + r'''
log(104,"0/1 Scale of Old Murk-Eye","item",1);log(91883,"0/1 Omnuron's Spear","item",1);stand(1436,.5,.5);Q:Refresh(true)
map(1436);local made=#Pins.routeLayer.lines;assert(made==5 and #lines()==5)
local function made_lines() local n=0;for _,f in ipairs(M.frames) do if f._kind=="Line" then n=n+1 end end;return n end
assert(made_lines()==5);map(1436);map(1436);assert(made_lines()==5 and #Pins.routeLayer.lines==made,"lines are pooled, not made again")
local layer=Pins.routeLayer
assert(layer._parent==WorldMapFrame:GetCanvas() and not layer:IsMouseClickEnabled() and not layer:IsMouseMotionEnabled())
local levels=WorldMapFrame:GetPinFrameLevelsManager()
assert(layer:GetFrameLevel()==levels:GetFrameLevelStart(Pins.questPinLevel)-1 and not levels.writes,"under the markers; the level manager is only read")
WorldMapFrame:GetCanvas():SetScale(.5);Pins.provider:OnCanvasScaleChanged()
for _,l in ipairs(lines()) do assert(l._thickness==6) end
WorldMapFrame:GetCanvas():SetScale(.25)
local report=map(2482);assert(report.paths.areas==1 and #lines()==report.paths.lines and #lines()>=3)
for _,l in ipairs(lines()) do assert(l._thickness==8,"an outline is 2 pixels") end
report=map(1413);assert(report.paths.lines==0 and #lines()==0 and not layer:IsShown())
M.complete[104]=true;M.complete[91883]=true;Q:Refresh(true);report=map(1436);assert(report.paths.lines==0 and #lines()==0)
''',
        'mob_paths_setting_off_draws_nothing_and_guides_to_the_spawn': PATHS + hub + r'''
log(9204,"0/1 Old Murk-Eye slain","monster",1);log(91883,"0/1 Omnuron's Spear","item",1);stand(1436,.4,.77);Q:Refresh(true)
assert(map(1436).paths.lines==5)
page("display");check("displayquestPaths",false);assert(FP.settings.questPaths==false)
local report=map(1436);assert(report.paths.lines==0 and #lines()==0)
assert(#Q:Routes(1436)==0 and #Q:Routes(2482)==0,"nothing to draw is offered either")
local p,moving=Q:Nearest(9204,1);assert(p.role=="kill" and moving==nil and near(p.x,.30))
for _,pin in ipairs(Q:WorldPins(1436)) do assert(not pin.label) end
assert(map(2482).paths.lines==0);for _,pin in ipairs(Q:WorldPins(2482)) do assert(not pin.label) end
check("displayquestPaths",true);assert(map(1436).paths.lines==5)
FP.settings.questWorldPins=false;assert(map(1436).paths.lines==0 and #lines()==0)
''',
        'mob_paths_a_client_without_lines_keeps_its_markers': PATHS + r'''
local make,asked=CreateFrame,0;CreateFrame=function(...) local f=make(...);f.CreateLine=false;asked=asked+1;return f end
log(104,"0/1 Scale of Old Murk-Eye","item",1);stand(1436,.5,.5);Q:Refresh(true)
local report=map(1436)
assert(report.paths.unsupported and report.paths.lines==0, "unsupported "..tostring(report.paths.unsupported).." lines "..tostring(report.paths.lines).." failed "..tostring(report.paths.failed))
assert(report.questPins==1 and not Pins.routeLayer, report.questPins)
local before=asked;report=map(1436);report=map(1436);assert(report.paths.unsupported and asked==before,"asked once, not on every redraw")
CreateFrame=make;Pins.routeUnsupported=nil;WorldMapFrame.GetCanvas=false;report=map(1436);assert(report.paths.lines==0 and report.questPins==1)
''',
        'mob_paths_bad_route_records_are_ignored_not_fatal': PATHS + r'''
data.Npc[391].waypoints={[40]="broken",[616]={{{1,1}},"x",{{-5,3},{120,4}}},[999]={{{1,1},{2,2}}}}
log(104,"0/1 Scale of Old Murk-Eye","item",1);stand(1436,.5,.5);Q:Refresh(true)
local g=assert(group(104));assert(#g.points==1 and #g.paths==0)
data.Npc[391].waypoints=nil;Q:Refresh(true);assert(#group(104).paths==0 and map(1436).paths.lines==0)
-- a very long route is thinned, never cut short: first and last vertex stay
local long={};for i=0,397 do long[#long+1]={10+i*.2,50} end
data.Npc[391].waypoints={[40]={long}};Q:Refresh(true)
local report=map(1436);assert(report.paths.routes==1 and report.paths.lines<=150 and report.paths.lines>=100,report.paths.lines)
local first,last=math.huge,-math.huge
for _,l in ipairs(lines()) do first=math.min(first,l._start[3]);last=math.max(last,l._finish[3]) end
assert(near(first,.10*4000) and near(last,.894*4000),last)
''',
    }
