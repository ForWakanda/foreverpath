"""Sea crossings, known flight points and the trip plan. Mock-only."""

# Two continents tiled from 10,000-yard zones. Continent 1 = Kalimdor, 0 = Eastern Kingdoms.
WORLD = r'''
local T=FP.Travel
local KAL={[1411]=true,[1413]=true,[1439]=true,[1444]=true,[1445]=true,[1446]=true,[1454]=true,[1456]=true}
local NAMES={[1411]="Durotar",[1413]="The Barrens",[1417]="Arathi Highlands",[1420]="Tirisfal Glades",[1424]="Hillsbrad Foothills",
 [1425]="The Hinterlands",[1434]="Stranglethorn Vale",[1437]="Wetlands",[1439]="Darkshore",[1444]="Feralas",[1445]="Dustwallow Marsh",
 [1446]="Tanaris",[1454]="Orgrimmar",[1456]="Thunder Bluff",[1458]="Undercity"}
-- {north, west} offset of each zone's south-east corner
local OFF={[1411]={20000,0},[1454]={30000,0},[1413]={0,0},[1444]={-20000,10000},[1446]={-30000,0},[1456]={0,10000},[1445]={-10000,-10000},[1439]={40000,10000},
 [1420]={30000,0},[1458]={30000,10000},[1424]={10000,0},[1425]={10000,-10000},[1417]={0,-10000},[1434]={-30000,0},[1437]={0,0}}
local SIZE=10000
C_Map.GetWorldPosFromMapPos=function(id,v) local o=OFF[id] or {0,0}; return KAL[id] and 1 or 0, M.vec(o[1]+SIZE-v.y*SIZE, o[2]+SIZE-v.x*SIZE) end
C_Map.GetMapInfo=function(id) return {mapID=id,name=NAMES[id] or ("Map "..id),mapType=3} end
for id,name in pairs(NAMES) do local info=FP.API.GetMapInfo(id); if info then info.name=name end end
local function world(id,x,y) local o=OFF[id]; return o[1]+SIZE-y*SIZE, o[2]+SIZE-x*SIZE end
local function stand(id,x,y) M.mapID=id;M.px=x;M.py=y;FP.Pos:Refresh(true) end
local function arrow() T.memo,T.hintMemo=nil,nil;FP.Arrow:OnUpdate(1);return FP.Arrow.dist:GetText() or "",FP.Arrow.leg:GetText() or "" end
local function quest(id,title,map,x,y,complete)
 M.AddQuest({questID=id,title=title,waypoint=map and {map,x,y} or nil,objectives={{text="0/1 Thing slain",type="monster",numFulfilled=0,numRequired=1,finished=false}}})
 M.complete[id]=complete
end
-- a flight map drawn to scale: map coordinates are an exact affine image of the world
local function taxi(id,x,y) local wx,wy=world(id,x,y); return .5-wy/100000, .5-wx/100000 end
local function flight(name,id,x,y,stood) local tx,ty=taxi(id,x,y); FP.cdb.flights[name]={t=1,tm=1463,tx=tx,ty=ty,m=stood and id or nil,x=stood and x or nil,y=stood and y or nil} end
FP.settings.autoNext=false;FP.Waypoints:Clear();FP.Planner.paused=nil
FP.cdb.flightsSeeded=true
'''


def cases(hub):
    return {
        'travel_arrow_leads_to_the_crossing_for_a_step_across_the_sea': WORLD + r'''
stand(1454,.5,.5)
local wp=FP.Waypoints:Add(1425,.24,.49,"Wildkin Muisek 0/10")
local d,leg=arrow()
assert(d:find("Zeppelin to Undercity",1,true) and d:find("yd",1,true), d)
assert(not d:find("other continent",1,true), "the bare dead end is gone")
assert(leg=="then The Hinterlands", leg)
local l=T:Leg(wp); assert(l.from.mapID==1411 and l.to.mapID==1420 and l.dist>0 and l.bearing)
assert(FP.Waypoints:GetActive()==wp and wp.mapID==1425, "the destination itself is untouched")
-- the nearest crossing for the destination, not a fixed one
wp.mapID,wp.x,wp.y=1434,.35,.2; assert(arrow():find("Zeppelin to Grom'gol",1,true))
stand(1413,.62,.40); wp.x,wp.y=.27,.75; assert(arrow():find("Ship to Booty Bay",1,true))
-- at the boarding point: say so, stop pointing
stand(1411,.5082,.1354); wp.mapID,wp.x,wp.y=1425,.24,.49
d=arrow(); assert(d:find("Board here: Zeppelin to Undercity",1,true), d)
-- and it works in reverse
stand(1458,.5,.5); wp.mapID,wp.x,wp.y=1446,.5,.5; assert(arrow():find("Zeppelin to Orgrimmar",1,true))
-- same continent: plain distance, no crossing
stand(1424,.5,.5); wp.mapID,wp.x,wp.y=1425,.24,.49
d=arrow(); assert(not d:find("Zeppelin",1,true) and d:find("yd",1,true) and not T:Leg(wp))
assert(FP.API.CaptureNavigation().arrowLeg~=nil)
''',

        'travel_crossings_respect_faction_and_admit_what_is_unconfirmed': WORLD + r'''
stand(1454,.5,.5)
local wp=FP.Waypoints:Add(1425,.24,.49,"Far objective")
T.faction="Alliance";T.memo=nil
local l=T:Leg(wp); assert(l.crossing.faction=="Alliance" and l.crossing.approximate and l.to.town=="Menethil Harbor")
assert(T:Describe(wp):find("not confirmed on Forever",1,true))
T.faction=false;T.memo=nil  -- faction unreadable: neutral ships only
l=T:Leg(wp); assert(l.crossing.faction==nil and l.to.town=="Booty Bay")
T.faction="Horde";T.memo=nil
assert(not T:Describe(wp):find("not confirmed",1,true) and T:Describe(wp):find("board at the zeppelin tower outside Orgrimmar",1,true))
for _,c in ipairs(T.crossings) do assert(c.faction~="Horde" or not c.approximate, "Horde positions come from the reference data") end
-- no crossing known: the old honest text, no invented route
local keep=T.crossings;T.crossings={}
local d,leg=arrow(); assert(d:find("other continent: The Hinterlands",1,true) and leg=="", d)
T.crossings=keep
-- no position (instance): nothing claimed
M.noPosition=true;FP.Pos:Refresh(true);T.memo=nil
assert(not T:Leg(wp) and not T:Hint(wp) and not T:Describe(wp))
''',

        'travel_hearthstone_is_offered_only_when_it_lands_on_the_right_continent': WORLD + r'''
stand(1458,.5,.5)
local wp=FP.Waypoints:Add(1446,.5,.5,"Tanaris step")
FP.cdb.bind={area="Thunder Bluff",m=1456,x=.5,y=.5}
assert(T:Describe(wp):find("Or use your Hearthstone to Thunder Bluff (ready)",1,true), T:Describe(wp))
C_Container.GetItemCooldown=function() return GetTime()-100,1900,1 end
assert(T:Describe(wp):find("ready in 30m00s",1,true), T:Describe(wp))
FP.cdb.bind={area="Undercity",m=1458,x=.6,y=.6}
assert(not T:Describe(wp):find("Hearthstone",1,true), "an inn on this side does not cross the sea")
M.itemCount=0;FP.cdb.bind={area="Thunder Bluff",m=1456,x=.5,y=.5}
assert(not T:Describe(wp):find("Hearthstone",1,true), "no stone, no offer")
''',

        'travel_flight_fit_checks_itself_and_names_the_nearest_known_point': WORLD + r'''
FP.cdb.flights={}
flight("Undercity, Tirisfal",1458,.63,.48,true);flight("Tarren Mill, Hillsbrad",1424,.10,.90,true)
flight("Grom'gol, Stranglethorn",1434,.33,.29,true);flight("Stonard, Swamp of Sorrows",1437,.46,.55,true)
flight("Hammerfall, Arathi",1417,.73,.33,false)          -- known, never stood there
flight("zzOLDBolder'ok, Riverglades",1425,.24,.49,false)  -- retired entry on the client's map
local target={mapID=1425,x=.24,y=.49}
local name,d=T:FlightFor(target)
local hx,hy=world(1417,.73,.33);local tx,ty=world(1425,.24,.49)
assert(name=="Hammerfall, Arathi", tostring(name))
assert(math.abs(d-FP.Util.Distance(hx,hy,tx,ty))<2, "placed by the fit: "..tostring(d))
local fit=FP.db.travel.fits["1463"]; assert(fit.ok and fit.n==4 and fit.rms<=1 and fit.version==FP.version)
-- the arrow names it only when it is a real shortcut
stand(1458,.5,.5);local wp=FP.Waypoints:Add(1425,.24,.49,"Wildkin Muisek 0/10")
local _,leg=arrow(); assert(leg=="flight point: Hammerfall, Arathi", leg)
assert(T:Describe(wp):find("Nearest flight point: Hammerfall, Arathi",1,true))
stand(1417,.70,.35); _,leg=arrow(); assert(leg=="", "already about as close as the flight point")
-- across the sea the same point is named after the crossing
stand(1454,.5,.5); _,leg=arrow(); assert(leg=="then The Hinterlands · fly to Hammerfall, Arathi", leg)
assert(T:Describe(wp):find("the nearest flight point you know is Hammerfall, Arathi",1,true))
-- three samples always fit exactly and prove nothing: not trusted
FP.cdb.flights["Stonard, Swamp of Sorrows"]=nil;T.fits=nil
assert(T:FlightFor(target)=="Tarren Mill, Hillsbrad", "only points with a real position are compared")
assert(FP.db.travel.fits["1463"].ok==false and FP.db.travel.fits["1463"].n==3)
assert(T:FlightFor({mapID=1417,x=.5,y=.5})=="Hammerfall", "a known point in the destination's own zone wins by name")
-- one bad sample: the fit distrusts itself rather than misplacing every point
flight("Stonard, Swamp of Sorrows",1437,.46,.55,true);FP.cdb.flights["Stonard, Swamp of Sorrows"].tx=.9;T.fits=nil
assert(T:FlightFor(target)=="Tarren Mill, Hillsbrad" and FP.db.travel.fits["1463"].ok==false and FP.db.travel.fits["1463"].rms>250)
FP.cdb.flights={};flight("Hammerfall, Arathi",1417,.73,.33,false);T.fits=nil
assert(T:FlightFor(target)==nil, "nothing placed, nothing named for that zone: no claim")
-- with enough samples one wrong place is dropped once, and a point on another continent is left out
flight("Undercity, Tirisfal",1458,.63,.48,true);flight("Tarren Mill, Hillsbrad",1424,.10,.90,true);flight("Grom'gol, Stranglethorn",1434,.33,.29,true)
flight("Stonard, Swamp of Sorrows",1437,.46,.55,true);flight("Kargath, Badlands",1417,.04,.95,true);flight("Light's Hope",1420,.8,.6,true)
flight("Wrong Place",1434,.9,.9,true);FP.cdb.flights["Wrong Place"].tx=.95
flight("Elsewhere, Instanced",1413,.5,.5,true)   -- stood on the other continent: not this map's geometry
T.fits=nil;name,d=T:FlightFor(target)
fit=FP.db.travel.fits["1463"]; assert(fit.ok and fit.dropped==1 and fit.n==6 and fit.rms<=1 and fit.continent==0, "n="..tostring(fit.n).." rms="..tostring(fit.rms))
assert(name=="Hammerfall, Arathi" and math.abs(d-FP.Util.Distance(hx,hy,tx,ty))<2)
''',

        'travel_flight_points_are_learned_from_the_flight_map_without_the_recorder': WORLD + r'''
FP.settings.record=false;FP.cdb.flights={}
local before=FP.Util.Count(FP.data.taxi.nodes)
stand(1413,.52,.30);M.FireEvent("TAXIMAP_OPENED")
local f=FP.cdb.flights
assert(f["Crossroads, The Barrens"] and f["Crossroads, The Barrens"].m==1413 and f["Crossroads, The Barrens"].x==.52, "where you stood")
assert(f["Orgrimmar"] and f["Orgrimmar"].tx==.4 and not f["Orgrimmar"].m, "reachable: known, position from the map only")
assert(not f["Ratchet"], "an undiscovered point is not a known one")
assert(FP.Util.Count(FP.data.taxi.nodes)==before, "the dataset recorder stays off")
-- the recorder's account-wide marks are adopted only for its one and only character
local key=FP.API.GetCharInfo().key
FP.data.taxi.nodes={a={n="Hammerfall, Arathi",known=true,m=1463,x=.6,y=.3},b={n="Revantusk Village, The Hinterlands",m=1463,x=.67,y=.29},
 c={n="zzOLDPowderfuse Port, Riverglades",known=true,m=1464,x=.6,y=.5}}
FP.data.chars={[key]={},["Alt-Realm"]={}};FP.cdb.flights={};FP.cdb.flightsSeeded=nil;T:Seed()
assert(next(FP.cdb.flights)==nil and FP.cdb.flightsSeeded, "two characters: whose marks are they?")
FP.data.chars={[key]={}};FP.cdb.flightsSeeded=nil;T:Seed()
assert(FP.cdb.flights["Hammerfall, Arathi"] and not FP.cdb.flights["Revantusk Village, The Hinterlands"] and FP.Util.Count(FP.cdb.flights)==1)
''',

        'trip_plan_orders_zones_then_the_crossing_and_changes_nothing': WORLD + r'''
stand(1413,.5,.5)
quest(1,"Near one",1413,.55,.55);quest(2,"Feralas A",1444,.5,.5);quest(3,"Feralas B",1444,.52,.5)
quest(4,"Tanaris ready",1446,.5,.5,true);quest(5,"Undercity ready",1458,.5,.5,true);quest(6,"Undercity ready 2",1458,.52,.5,true)
quest(7,"Jungle",1434,.4,.4);quest(8,"Nowhere");quest(9,"Later",1413,.2,.2)
FP.Planner.deferred={[9]=FP.API.Time()+600}
FP.Recorder.RescanLog("trip");FP.Planner:Build()
local steps=snapshot(FP.Planner.steps);local state=snapshot(FP.cdb)..snapshot(FP.settings)
local plan=T:Plan()
local order={};for _,r in ipairs(plan.rows) do order[#order+1]=r.type=="stop" and r.stop.zone or r.type end
assert(table.concat(order,">")=="The Barrens>Feralas>Tanaris>crossing>Stranglethorn Vale>Undercity", table.concat(order,">"))
assert(plan.stops==5 and plan.unknown==1 and plan.deferred==1)
local crossing=plan.rows[4]; assert(crossing.leg.from.town=="Ratchet" and crossing.leg.to.town=="Booty Bay", "the crossing that lands nearest a stop")
assert(plan.rows[2].stop.questCount==2 and plan.rows[6].stop.turnins==2)
assert(plan.rows[1].first and plan.rows[1].dist and plan.rows[5].dist, "distances run from the previous stop or landing")
for _,r in ipairs(plan.rows) do
 local label=T:RowLabel(r); assert(not label:find("|c",1,true) and #label<=82, label)
 assert(#T:RowDetails(r)>0)
end
assert(T:RowLabel(plan.rows[6]):find("2 quests · 2 ready to turn in",1,true), T:RowLabel(plan.rows[6]))
assert(T:RowDetails(plan.rows[6]):find("Turn in:",1,true))
local lines=T:Lines(); assert(#lines==8 and lines[#lines]:find("1 quest without a known location",1,true) and lines[#lines]:find("1 deferred quest left out",1,true))
assert(T:Summary(plan):find("Straight-line estimate",1,true))
assert(steps==snapshot(FP.Planner.steps) and state==snapshot(FP.cdb)..snapshot(FP.settings) and not active(), "reading the plan changes nothing")
-- a ready turn-in pulls a slightly farther zone forward, not an unlimited distance
quest(10,"Bluff ready",1456,.9,.3,true);quest(11,"Bluff ready 2",1456,.9,.3,true);quest(12,"Marsh errand",1445,.02,.02)
FP.Recorder.RescanLog("trip");FP.Planner:Build()
plan=T:Plan()
assert(plan.rows[2].stop.zone=="Thunder Bluff" and plan.rows[3].stop.zone=="Dustwallow Marsh", "two turn-ins outweigh the ~300 yards the marsh is nearer")
assert(plan.rows[3].dist<plan.rows[2].dist+7000 and plan.rows[4].stop.zone=="Feralas", "but not a zone-wide detour")
-- the Hearthstone is mentioned for the stop it reaches
FP.cdb.bind={area="Thunder Bluff",m=1456,x=.9,y=.3}
plan=T:Plan(); assert(plan.hearth and plan.hearth:find("reaches stop 2 (Thunder Bluff): ready now",1,true), tostring(plan.hearth))
M.itemCount=0; assert(not T:Plan().hearth)
-- nothing mapped at all
M.quests={};FP.Recorder.RescanLog("trip");FP.Planner:Build()
assert(#T:Plan().rows==0 and T:Summary():find("No quests with a known location",1,true))
''',

        'trip_plan_page_guides_only_on_the_click_and_only_to_a_stop': hub + WORLD + r'''
stand(1413,.5,.5)
quest(1,"Near one",1413,.55,.55);quest(5,"Undercity ready",1458,.5,.5,true);quest(6,"Undercity errand",1458,.7,.7)
FP.Recorder.RescanLog("trip")
page("home");click("homeTrip");assert(H.selected=="trip")
local list=H.controls.tripStops
assert(#list.items==3 and list.items[2].type=="crossing", "stop, crossing, stop")
assert(not H.controls.tripGuide:IsEnabled() and not active(), "opening the page starts nothing")
selectRow("tripStops",2);assert(not H.controls.tripGuide:IsEnabled(), "a crossing is not a destination")
assert(not T:Guide(list.items[2]) and not T:Guide(nil) and not active())
assert(H.controls.tripDetails:GetText():find("lands at",1,true))
selectRow("tripStops",3);click("tripGuide")
local wp=active();assert(wp and wp.mapID==1458 and wp.source.kind=="turnin" and wp.source.questID==5 and FP.Planner.pinned, "the ready turn-in first")
assert(FP.Arrow.dist and arrow():find("to Undercity",1,true), "and the arrow starts with the crossing")
cmd("trip");local said=0;for _,l in ipairs(M.Chat()) do if tostring(l):find("Trip plan",1,true) then said=said+1 end end;assert(said==1)
page("navigation");assert(H.controls.guidanceDetails:GetText():find("board at",1,true), "Navigation explains the trip")
for i,s in ipairs(H.sections) do local b=H.nav[s[1]];assert(b, s[1]) end
assert(#H.sections==16)
''',
    }
