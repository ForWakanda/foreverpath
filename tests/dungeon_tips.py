"""Dungeon tips card: the stop you are at inside a dungeon and what to use there. Mock-only."""

TIPS = r'''
local T=FP.DungeonTips
local D=FP.DungeonTipsData
local S=D.dungeons.scholomance
M.class="SHAMAN"
local function enter(name) M.instance={name=name or "Scholomance",type="party",mapID=289}; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2) end
local function leave() M.instance=nil; M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2) end
local function at() local _,_,run=T:Active(); return run and run.stop end
local function shown() return T.frame:IsShown() end
local function line(rows,label) for _,r in ipairs(rows) do if r.label==label then return r end end end
local function texts() local out={}; for _,r in ipairs(T.rows) do if r:IsShown() then out[#out+1]=T.Plain((r.label:GetText() or "").." "..(r.text:GetText() or "")) end end return table.concat(out,"\n") end
local function idx(key) return T:IndexOf(S,key) end
'''


def cases(hub):
    return {
        'dungeon_tips_every_line_fits_the_card_and_names_a_real_totem': TIPS + r'''
-- the card cuts a long line, so the data is held to what fits; both a class with lines and one without
local seen=0
for _,key in ipairs(D.order) do
 local dungeon=D.dungeons[key]
 local keys={}
 for i,stop in ipairs(dungeon.stops) do
  assert(not keys[stop.key], "stop key used twice: "..stop.key); keys[stop.key]=true
  assert(stop.kind=="trash" or stop.kind=="boss" or stop.kind=="overview", stop.key)
  assert(type(stop.threat)=="string" and #stop.threat>0, stop.key.." says what the enemies do")
  if stop.kind=="boss" then assert(type(stop.names)=="table" and #stop.names>0, stop.key.." names its fight") end
  for _,class in ipairs({"SHAMAN","MAGE"}) do
   local rows=T:Rows(dungeon,i,class,{killed={}})
   assert(#rows>=2 and #rows<=#T.rows, stop.key.." has "..#rows.." lines for "..class.."; the card holds "..#T.rows)
   for _,row in ipairs(rows) do
    seen=seen+1
    local text=T.Plain(row.text)
    local chars=select(2,text:gsub("[^\128-\191]",""))   -- characters, not bytes: the dash is three bytes
    assert(chars<=D.LINE, class.." "..stop.key..": "..chars.." characters: "..text)
    assert(type(row.tip)=="table" and type(row.tip[1])=="string" and #row.tip[1]>0, "every line has hover text: "..text)
   end
  end
  for class,lines in pairs(stop.classes or {}) do
   local used={}
   for _,l in ipairs(lines) do
    local def=assert(D.totems[l[2]], stop.key..": unknown totem "..tostring(l[2]))
    assert(def.element==l[1], stop.key..": "..l[2].." is a "..def.element.." totem, listed under "..l[1])
    assert(not used[l[1]], stop.key..": two "..l[1].." totems; only one of an element stands at a time"); used[l[1]]=true
    if l.or_ then assert(D.totems[l.or_] and D.totems[l.or_].element==l[1], stop.key..": the second choice must be the same element") end
    assert(type(l[3])=="string" and type(l[4])=="string" and #l[4]>#l[3], stop.key..": a short reason and a longer one")
   end
  end
 end
end
assert(seen>1500, seen)
-- every end-game dungeon is there under the dungeon list's own key and name (the hub previews by that name)
local want={"sunken-temple","blackrock-depths","lower-blackrock-spire","upper-blackrock-spire","dire-maul-east","dire-maul-west","dire-maul-north","scholomance","stratholme-main-gate","stratholme-service-gate"}
assert(table.concat(D.order," ")==table.concat(want," "), table.concat(D.order," "))
local stops,bosses,fights=0,0,{}
for _,key in ipairs(D.order) do
 local dungeon=D.dungeons[key]
 assert(dungeon.key==key and FP.DungeonCatalog.dungeons[key] and FP.DungeonCatalog.dungeons[key].name==dungeon.name, key.." is not the dungeon list's "..tostring(dungeon.name))
 assert(T:Find(dungeon.name)==key, "the hub previews "..dungeon.name.." by its name")
 local instance=type(dungeon.match)=="table" and dungeon.match[1] or dungeon.match
 for i,stop in ipairs(dungeon.stops) do
  stops=stops+1
  if stop.kind=="boss" then
   bosses=bosses+1
   -- what to do, for every class, on every boss; and where the lines came from
   assert(type(stop.act)=="table" and #stop.act>=1 and #stop.act<=2, key.."/"..stop.key.." says what to do")
   for _,name in ipairs(stop.names) do
    -- a fight belongs to one stop of an instance: a pull must not be claimed by two wings
    assert(not fights[instance..":"..name], name.." is named by two stops of "..instance); fights[instance..":"..name]=key
    local found=T:StopForFight(dungeon,name);assert(found==i, name.." leads to stop "..tostring(found).." of "..key..", not "..i)
   end
  end
  if stop.kind~="overview" then
   assert(type(stop.cite)=="table" and #stop.cite>0, key.."/"..stop.key.." names the spells it was written from")
   for _,l in ipairs(stop.act or {}) do assert(#l[2]>#l[1]) end
   assert(stop.classes and stop.classes.SHAMAN and #stop.classes.SHAMAN>=3, key.."/"..stop.key.." has totems")
  end
 end
 -- wings of one instance: each is offered from the others
 if dungeon.wing then local wings=T:Wings(key);assert(#wings>=2 and T:NextWing(key)~=key, key.." has no other wing") else assert(#T:Wings(key)==1) end
end
assert(stops==168 and bosses==110, stops.." stops, "..bosses.." boss stops")
assert(#T:Wings("dire-maul-west")==3 and #T:Wings("stratholme-main-gate")==2 and #T:Wings("upper-blackrock-spire")==2)
-- Scholomance as checked against the Classic data: the stops this card exists for
local function totem(key,element) for _,l in ipairs(S.stops[idx(key)].classes.SHAMAN) do if l[1]==element then return l[2] end end end
assert(totem("entry","earth")=="Tremor Totem" and totem("ras","earth")=="Tremor Totem" and totem("illucia","earth")=="Tremor Totem", "the three places something fears")
assert(totem("kirtonos","earth")=="Tremor Totem" and totem("polkelt","earth")=="Stoneskin Totem", "Kirtonos mind controls (a charm); Polkelt does not fear")
-- what the spell data corrected on 2026-11-25: area spells are not offered to Grounding
assert(totem("malicia","air")=="Windfury Totem" and totem("alexei","air")=="Windfury Totem" and totem("ravenian","air")=="Windfury Totem")
assert(S.stops[idx("krastinov")].threat:find("30%",1,true), "Krastinov enrages at 30%, not at half")
assert(totem("ras","fire")=="Frost Resistance Totem" and totem("viewing","water")=="Fire Resistance Totem", "resistance totems under their own element")
assert(totem("ossuary","water")=="Disease Cleansing Totem" and totem("polkelt","water")=="Disease Cleansing Totem" and totem("crypt","water")=="Disease Cleansing Totem")
assert(#FP.db.errors==0)
''',

        'dungeon_tips_card_appears_inside_the_dungeon_and_steps_on_a_click': TIPS + r'''
assert(not shown() and T:Active()==nil, "nothing outside a dungeon")
enter("Razorfen Downs");assert(not shown(), "a dungeon without tips shows no card")
leave();enter()
assert(shown() and T.inside=="scholomance" and at()=="entry")
local chat=table.concat(M.Chat(),"\n");assert(chat:find("Scholomance tips are on the card",1,true) and chat:find("Classic",1,true), "one line says what it is and where the text comes from")
local t=texts()
assert(T.title:GetText():find("Scholomance · 1/"..#S.stops,1,true) and not T.title:GetText():find("preview",1,true))
assert(t:find("Entry halls",1,true) and t:find("Earth Tremor or Stoneskin — Neophytes can cast Fear",1,true) and t:find("Air Grounding — eats a Fear or a Mana Burn",1,true), t)
assert(t:find("Watch Blood Steward: Paralyzing Poison",1,true) and t:find("Next Aberrations, ghouls, summoners",1,true), t)
-- what to do comes first, above the totems
assert(t:find("Do Interrupt Dark Mending, the Acolytes' heal\nEarth ",1,true), t)
-- hover text is the long version
local rows=T:Rows(S,1,"SHAMAN",{killed={}})
assert(line(rows,"Earth").tip[1]=="Tremor Totem or Stoneskin Totem" and line(rows,"Earth").tip[2]:find("Scholomance Neophytes can cast Fear",1,true))
assert(line(rows,"Do").tip[2]:find("Dark Mending",1,true) and #line(rows,"Do").tip[2]>#line(rows,"Do").text)
-- the arrows, the Next line and the command all step
T.forward:GetScript("OnClick")(T.forward);assert(at()=="second" and texts():find("Water Disease Cleansing — Wandering Plague",1,true), texts())
T.back:GetScript("OnClick")(T.back);assert(at()=="entry")
M.chat={};T.back:GetScript("OnClick")(T.back);cmd("tips prev");assert(at()=="entry", "the first stop is the first stop")
assert(not table.concat(M.Chat(),"\n"):find("No dungeon card",1,true), "stepping at the first stop is not an error")
local nextRow;for _,r in ipairs(T.rows) do if r:IsShown() and r.data.label=="Next" then nextRow=r end end
nextRow:GetScript("OnMouseUp")(nextRow);assert(at()=="second")
cmd("tips next");assert(at()=="kirtonos" and texts():find("Kirtonos the Herald (optional)",1,true))
cmd("tips go ras");assert(at()=="ras");cmd("tips 1");assert(at()=="entry");cmd("tips go nowhere");assert(at()=="entry")
cmd("tips go gandling");M.chat={};cmd("tips next");assert(at()=="gandling", "the last stop is the last stop")
assert(not table.concat(M.Chat(),"\n"):find("No dungeon card",1,true), "stepping at the last stop is not an error")
leave();M.chat={};cmd("tips next");assert(table.concat(M.Chat(),"\n"):find("No dungeon card to step",1,true));enter();assert(at()=="gandling")
assert(not texts():find("\nNext ",1,true), "nothing after the last boss")
-- icons: only when the client gives the id the totem's own name; a lookup that throws or answers hidden costs the icon, never the line
local names={[8143]="Tremor Totem",[5675]="Some Other Spell"}
C_Spell.GetSpellName=function(id) if id==8071 then return M.Secret() end return names[id] end
local realName=FP.API.GetSpellName;FP.API.GetSpellName=function(id) if id==8177 then error("a hidden value was compared") end return realName(id) end
C_Spell.GetSpellTexture=function(id) return "icon"..id end
rows=T:Rows(S,1,"SHAMAN",{killed={}})
assert(line(rows,"Earth").icon=="icon8143" and line(rows,"Water").icon==nil and line(rows,"Air").icon==nil and line(rows,"Air").text:find("Grounding",1,true))
assert(T.Icon("Stoneskin Totem")==nil and T.Icon("No Such Totem")==nil)
names[8177]="Grounding Totem";FP.API.GetSpellName=realName;C_Spell.GetSpellName=function(id) return names[id] end
assert(T.Icon("Grounding Totem")=="icon8177", "a failed lookup is asked again") ; assert(T.Icon("Mana Spring Totem")==nil)
cmd("tips 1");local earthRow;for _,r in ipairs(T.rows) do if r:IsShown() and r.data.label=="Earth" then earthRow=r end end
assert(earthRow.icon:IsShown() and earthRow.icon:GetTexture()=="icon8143")
-- another class sees what the enemies do, not totems
M.class="MAGE";cmd("tips go ras");t=texts()
assert(t:find("Watch Fear, frost on everyone, Freeze",1,true) and not t:find("Tremor",1,true) and t:find("Watch Freeze holds a player in place",1,true), t)
M.class="SHAMAN"
-- hide, automatic, off
T.close:GetScript("OnClick")(T.close);assert(not shown() and FP.settings.dungeonTips.manual=="hide")
cmd("tips auto");assert(shown() and at()=="ras", "hiding the card does not lose the place")
cmd("tips off");assert(not shown() and T.inside==nil);cmd("tips on");assert(shown() and at()=="ras")
leave();assert(not shown())
assert(FP.db.dungeonTips.counts.entered==2 and FP.db.dungeonTips.counts.manual>=6 and FP.db.dungeonTips.last.stop=="ras")
assert(#FP.db.errors==0)
''',

        'dungeon_tips_follow_a_boss_pull_and_kill_when_the_game_names_the_fight': TIPS + r'''
enter()
M.FireEvent("ENCOUNTER_START",451,"Rattlegore",1,5)
assert(at()=="rattlegore" and texts():find("Earth Stoneskin — all physical: Strike, War Stomp",1,true) and texts():find("Do Tank him with your back to a wall",1,true), texts())
M.FireEvent("ENCOUNTER_END",451,"Rattlegore",1,5,0);assert(at()=="rattlegore", "a wipe moves nothing")
M.FireEvent("ENCOUNTER_END",451,"Rattlegore",1,5,1);assert(at()=="viewing", "a kill moves on")
M.FireEvent("BOSS_KILL",451,"Rattlegore");assert(at()=="viewing", "the second announcement of the same kill does not move it again")
-- a fight the game names differently still finds its stop; two bosses share one stop
M.FireEvent("ENCOUNTER_START",2,"The Lich, Ras Frostwhisper",1,5);assert(at()=="ras")
M.FireEvent("ENCOUNTER_START",3,"Vectus",1,5);assert(at()=="viewing")
M.FireEvent("ENCOUNTER_START",4,"Marduk Blackpool",1,5);assert(at()=="viewing")
-- the six rooms: a kill returns to the list, which marks it; the sixth kill leads to Gandling
M.FireEvent("ENCOUNTER_START",5,"Lady Illucia Barov",1,5)
local t=texts();assert(at()=="illucia" and t:find("Earth Tremor — she casts Fear",1,true) and t:find("Room Lower room, with Risen Bonewarders",1,true) and t:find("Back The six rooms before Gandling",1,true), t)
M.FireEvent("ENCOUNTER_END",5,"Lady Illucia Barov",1,5,1)
t=texts();assert(at()=="six" and t:find("Lower Illucia Barov: done",1,true) and t:find("Upper Polkelt: Disease Cleansing; corpse room",1,true) and t:find("Next Darkmaster Gandling",1,true), t)
-- a line of the list is a click to that boss
local polkelt;for _,r in ipairs(T.rows) do if r:IsShown() and r.data.go==idx("polkelt") then polkelt=r end end
polkelt:GetScript("OnMouseUp")(polkelt);assert(at()=="polkelt")
for _,name in ipairs({"Lorekeeper Polkelt","Instructor Malicia","The Ravenian","Doctor Theolen Krastinov"}) do
 M.FireEvent("ENCOUNTER_START",9,name,1,5);M.FireEvent("ENCOUNTER_END",9,name,1,5,1);assert(at()=="six", name)
end
M.FireEvent("ENCOUNTER_START",9,"Lord Alexei Barov",1,5);M.FireEvent("BOSS_KILL",9,"Lord Alexei Barov");assert(at()=="gandling", "all six down")
-- he stepped elsewhere during a fight: the kill is marked, the card stays where he put it
cmd("tips newrun");assert(at()=="entry")
M.FireEvent("ENCOUNTER_START",7,"Jandice Barov",1,5);cmd("tips go crypt");M.FireEvent("ENCOUNTER_END",7,"Jandice Barov",1,5,1)
assert(at()=="crypt");cmd("tips next");assert(texts():find("Jandice Barov (optional) · done",1,true), texts())
-- an unknown fight, a secret name, a fight in a dungeon without tips: recorded or counted, nothing moves, no error
M.FireEvent("ENCOUNTER_START",8,"Some Unlisted Fight",1,5);assert(at()=="jandice")
M.FireEvent("ENCOUNTER_START",8,M.Secret(),1,5);assert(at()=="jandice" and FP.db.dungeonTips.counts.secretName==1)
local seen=FP.db.dungeonTips.encounters
assert(seen["Scholomance: Rattlegore"].id==451 and seen["Scholomance: Rattlegore"].stop=="rattlegore" and seen["Scholomance: Rattlegore"].n==4)
assert(seen["Scholomance: Some Unlisted Fight"].stop==false and seen["Scholomance: The Lich, Ras Frostwhisper"].stop=="ras", "what the game called each fight is kept for the next read")
leave();enter("Razorfen Downs");M.FireEvent("ENCOUNTER_START",11,"Amnennar the Coldbringer",1,5)
assert(seen["Razorfen Downs: Amnennar the Coldbringer"].stop==false and not shown())
leave();M.FireEvent("ENCOUNTER_START",12,"World Boss",1,40);assert(seen["The Barrens: World Boss"]==nil and U.Count(seen)==13, "a fight outside an instance is not kept")
-- switched off: fights are still noted, the card stays away
enter();cmd("tips off");M.FireEvent("ENCOUNTER_START",451,"Rattlegore",1,5);assert(not shown() and T.inside==nil and FP.cdb.dungeonTips.runs.scholomance.stop~="rattlegore" and seen["Scholomance: Rattlegore"].n==5)
assert(#FP.db.errors==0)
'''.replace("U.Count", "FP.Util.Count"),

        'dungeon_tips_keep_the_place_through_a_wipe_and_start_over_on_a_new_run': TIPS + r'''
-- a preview outside the dungeon: same card, marked, and its place is not a run
cmd("tips show schol");assert(shown() and T.title:GetText():find("preview",1,true) and at()=="entry")
cmd("tips next");cmd("tips next");assert(at()=="kirtonos")
cmd("tips show deadmines");assert(table.concat(M.Chat(),"\n"):find("No tips for \"deadmines\" yet. Dungeons with tips: The Sunken Temple, Blackrock Depths, Blackrock Spire (Lower, Upper), Dire Maul (East, West, North), Scholomance, Stratholme (Main Gate, Service Gate).",1,true))
enter();assert(at()=="entry" and not T.title:GetText():find("preview",1,true), "walking in starts at the first stop, not where the preview was left")
M.FireEvent("ENCOUNTER_START",1,"Jandice Barov",1,5);M.FireEvent("ENCOUNTER_END",1,"Jandice Barov",1,5,1);cmd("tips go ossuary")
-- a wipe: out and back in
leave();assert(shown() and T.title:GetText():find("preview",1,true), "shown by hand, it stays as a preview outside")
cmd("tips auto");assert(not shown())
enter();assert(shown() and at()=="ossuary" and FP.cdb.dungeonTips.runs.scholomance.killed.jandice, "the run is kept")
-- a reload inside
T.inside=nil;M.FireEvent("PLAYER_ENTERING_WORLD");M.RunTimers(2);assert(at()=="ossuary")
-- hours later it is another run
leave();FP.cdb.dungeonTips.runs.scholomance.t=FP.Util.Now()-4*3600;enter()
assert(at()=="entry" and not FP.cdb.dungeonTips.runs.scholomance.killed.jandice)
-- a saved place whose stop no longer exists falls back to the first stop
FP.cdb.dungeonTips.runs.scholomance.stop="removed-stop";T:Refresh();assert(at()=="entry" and shown())
FP.cdb.dungeonTips.runs.scholomance="broken";T:Refresh();assert(at()=="entry")
-- the list, in chat
M.chat={};cmd("tips list");local chat=table.concat(M.Chat(),"\n")
assert(chat:find("Scholomance — "..#S.stops.." stops",1,true) and chat:find(idx("ras")..". Ras Frostwhisper (optional): Tremor · Frost Resistance · Mana Spring · Grounding",1,true), chat)
assert(chat:find("Fear, frost on everyone, Freeze",1,true) and chat:find(idx("six")..". The six rooms before Gandling",1,true))
assert(T.Plain(chat):find("Do Interrupt Freeze and Frostbolt Volley",1,true), "the list carries what to do")
M.chat={};cmd("tips list nothing");assert(table.concat(M.Chat(),"\n"):find("No tips for \"nothing\" yet",1,true))
-- position and size
cmd("tips scale 1.5");assert(FP.settings.dungeonTips.scale==1.5 and T.frame:GetScale()==1.5)
cmd("tips reset");assert(FP.settings.dungeonTips.scale==1 and FP.settings.dungeonTips.point=="TOPLEFT")
cmd("tips lock");T.frame:GetScript("OnDragStart")(T.frame);assert(not T.frame._moving);cmd("tips unlock");T.rows[2]:GetScript("OnDragStart")(T.rows[2]);assert(T.frame._moving, "a line drags the card too")
assert(#FP.db.errors==0)
''',

        'dungeon_tips_follow_a_named_room_and_keep_what_the_game_calls_it': TIPS + r'''
-- a dungeon whose rooms the game names: the room moves the card; Scholomance has none in the reference data
D.order[#D.order+1]="testkeep"
D.dungeons.testkeep={name="Test Keep",match="test keep",stops={
 {key="gate",kind="trash",title="Gate",threat="Arrows",subzones={"The Gatehouse"}},
 {key="hall",kind="trash",title="Great hall",threat="Fear",subzones={"Hall of Echoes","The Long Gallery"}},
 {key="lord",kind="boss",title="Lord Test",threat="Cleave",names={"Lord Test"},subzones={"Throne Room"}},
}}
local sub="";GetSubZoneText=function() return sub end
local function walk(name) sub=name;M.FireEvent("ZONE_CHANGED_INDOORS");M.RunTimers(2) end
M.instance={name="Test Keep",type="party",mapID=999};M.FireEvent("PLAYER_ENTERING_WORLD");M.RunTimers(2)
assert(shown() and T.inside=="testkeep" and at()=="gate")
walk("The Long Gallery");assert(at()=="hall" and FP.db.dungeonTips.last.how=="room")
walk("Somewhere Unlisted");assert(at()=="hall")
walk("Throne Room");assert(at()=="lord")
M.FireEvent("ENCOUNTER_END",1,"Lord Test",1,5,1);cmd("tips go hall")
walk("Throne Room");assert(at()=="hall", "a room whose boss is dead does not pull the card back")
walk(M.Secret());assert(at()=="hall")
local rooms=FP.db.dungeonTips.subzones.testkeep
assert(rooms["The Long Gallery"].n==1 and rooms["Somewhere Unlisted"].n==1 and rooms["Throne Room"].n==2, "room names are kept for the next read")
assert(T:Rows(D.dungeons.testkeep,3,"SHAMAN",{killed={}})[2].label=="Watch", "a stop with no lines for the class still says what the enemies do")
for i=1,80 do walk("Room "..i) end;assert(FP.Util.Count(rooms)==60, "bounded")
assert(#FP.db.errors==0)
''',

        'dungeon_tips_do_lines_and_wings_inside_one_instance': TIPS + r'''
-- fixture: an instance with three wings, and a dungeon matched by either of two names
local function stop(key,kind,title,extra) local st={key=key,kind=kind,title=title,threat="Things"}; for k,v in pairs(extra or {}) do st[k]=v end return st end
D.Add({key="test-maul-east",name="Test Maul: East",match="test maul",wing="East",stops={
 stop("gate","trash","East gate",{here="Satyrs",act={{"Kill the healer first","Long text about the healer."}},watch={{"Satyrs: Mana Burn","Long."}}}),
 stop("alz","boss","Alz the Shaper",{names={"Alz the Shaper"},act={{"Move out of the thorns","Long text."},{"Interrupt his heal","Long text."}},watch={{"At half: bear form","Long."}},
  classes={SHAMAN={{"earth","Stoneskin Totem","hits hard","Longer reason."},{"water","Poison Cleansing Totem","his poison","Longer reason."},{"air","Grounding Totem","eats a bolt","Longer reason."}}}}),
}})
D.Add({key="test-maul-west",name="Test Maul: West",match="test maul",wing="West",stops={
 stop("yard","trash","West yard",{here="Ghosts"}), stop("prince","boss","Prince Test",{names={"Prince Test"}}) }})
D.Add({key="test-maul-north",name="Test Maul: North",match="test maul",wing="North",stops={
 stop("ramp","trash","North ramp",{here="Ogres"}), stop("king","boss","King Test",{names={"King Test"}}) }})
D.Add({key="test-temple",name="The Test Temple",match={"test temple","atal'test"},stops={ stop("ring","trash","Ring",{here="Trolls"}) }})
local E=D.dungeons["test-maul-east"]
-- Do lines come before the totems, for every class, with their hover text
local rows=T:Rows(E,2,"SHAMAN",{killed={}})
local labels={};for i,r in ipairs(rows) do labels[i]=r.label or "head" end
assert(table.concat(labels," ")=="head Wing Do Do Earth Water Air Watch", table.concat(labels," "))
assert(rows[3].text=="Move out of the thorns" and rows[3].tip[2]=="Long text." and rows[4].text=="Interrupt his heal")
rows=T:Rows(E,2,"MAGE",{killed={}});labels={};for i,r in ipairs(rows) do labels[i]=r.label or "head" end
assert(table.concat(labels," ")=="head Wing Do Do Watch Watch", "another class gets the Do lines too: "..table.concat(labels," "))
-- an instance whose name the game gives for several wings: the first wing, and a line that says so
enter("Test Maul")
assert(shown() and T.inside=="test-maul-east" and at()=="gate")
local chat=table.concat(M.Chat(),"\n");assert(chat:find("several wings",1,true) and chat:find("the card shows East",1,true), chat)
assert(texts():find("Wing East · click for West",1,true) and texts():find("Do Kill the healer first",1,true), texts())
assert(T.title:GetText():find("Tips|r · Test Maul: East · 1/2",1,true), T.title:GetText())
-- a click on the Wing line shows the next wing, at its first stop; the last wing leads back to the first
local function wingRow() for _,r in ipairs(T.rows) do if r:IsShown() and r.data.label=="Wing" then return r end end end
wingRow():GetScript("OnMouseUp")(wingRow());assert(T.inside=="test-maul-west" and at()=="yard" and texts():find("Wing West · click for North",1,true), texts())
wingRow():GetScript("OnMouseUp")(wingRow());assert(T.inside=="test-maul-north" and texts():find("Wing North · click for East",1,true))
-- the choice is kept for this instance: out and in again, and after a reload
leave();enter("Test Maul");assert(T.inside=="test-maul-north" and at()=="ramp")
T.inside=nil;M.FireEvent("PLAYER_ENTERING_WORLD");M.RunTimers(2);assert(T.inside=="test-maul-north")
assert(FP.cdb.dungeonTips.wings["test maul"]=="test-maul-north")
-- /hh tips wing: by name, the next one, and a wrong name
cmd("tips wing east");assert(T.inside=="test-maul-east")
cmd("tips wing");assert(T.inside=="test-maul-west")
M.chat={};cmd("tips wing south");assert(T.inside=="test-maul-west" and table.concat(M.Chat(),"\n"):find("This instance has: East, West, North.",1,true))
-- a boss pull the game names settles the wing: the fight is another wing's
cmd("tips next");assert(at()=="prince")
M.FireEvent("ENCOUNTER_START",1,"Alz the Shaper",1,5)
assert(T.inside=="test-maul-east" and at()=="alz" and FP.cdb.dungeonTips.wings["test maul"]=="test-maul-east", "the card follows the fight into its wing")
assert(FP.db.dungeonTips.encounters["Test Maul: Alz the Shaper"].wing=="test-maul-east" and FP.db.dungeonTips.counts.wingFight==1)
M.FireEvent("ENCOUNTER_END",1,"Alz the Shaper",1,5,1);assert(FP.cdb.dungeonTips.runs["test-maul-east"].killed.alz)
-- a fight of the wing shown changes nothing about the wing
M.FireEvent("ENCOUNTER_START",1,"Alz the Shaper",1,5);assert(T.inside=="test-maul-east" and FP.db.dungeonTips.counts.wingFight==1)
-- each wing keeps its own place in the run; a place left in a wing hours ago is not this run
cmd("tips wing west");assert(at()=="prince", "the west wing is where it was left")
FP.cdb.dungeonTips.runs["test-maul-north"]={stop="king",killed={king=true},inside=true,t=FP.Util.Now()-4*3600}
cmd("tips wing north");assert(at()=="ramp" and not FP.cdb.dungeonTips.runs["test-maul-north"].killed.king)
-- switched off: a fight of another wing is noted and moves nothing
cmd("tips off");M.FireEvent("ENCOUNTER_START",1,"Prince Test",1,5);assert(FP.cdb.dungeonTips.wings["test maul"]=="test-maul-north" and T.inside==nil);cmd("tips on")
-- an instance name that names the wing itself needs no choice
leave();enter("Test Maul: West");assert(T.inside=="test-maul-west")
leave();enter("Test Maul - East Wing");assert(T.inside=="test-maul-east")
-- a dungeon without wings has no Wing line and nothing to choose
leave();enter("Scholomance");assert(not wingRow());M.chat={};cmd("tips wing");assert(table.concat(M.Chat(),"\n"):find("Scholomance has no wings to choose from.",1,true))
-- a dungeon the game may call by either of two names
leave();enter("The Test Temple");assert(T.inside=="test-temple");leave();enter("Temple of Atal'Test");assert(T.inside=="test-temple");leave()
-- previews: the wing line switches the preview too, and the status names an instance once
cmd("tips show test maul");assert(shown() and T:Active()=="test-maul-east" and T.title:GetText():find("preview",1,true))
wingRow():GetScript("OnMouseUp")(wingRow());assert(T:Active()=="test-maul-west" and FP.cdb.dungeonTips.preview=="test-maul-west")
assert(table.concat(T:Names(),"; "):find("Test Maul (East, West, North)",1,true), table.concat(T:Names(),"; "))
-- the stop list in chat carries the Do lines
M.chat={};cmd("tips list test maul: east");chat=T.Plain(table.concat(M.Chat(),"\n"));assert(chat:find("Do Move out of the thorns",1,true), chat)
assert(#FP.db.errors==0)
''',

        'dungeon_tips_end_game_dungeons_on_the_shipped_text': TIPS + r'''
local function wingRow() for _,r in ipairs(T.rows) do if r:IsShown() and r.data.label=="Wing" then return r end end end
local function pull(name) M.FireEvent("ENCOUNTER_START",1,name,1,5) end
-- one run per instance: no Wing line, a boss pull leads to its stop and says what to do there
enter("Blackrock Depths");assert(shown() and T.inside=="blackrock-depths" and not wingRow())
pull("Lord Incendius");local t=texts()
assert(at()=="incendius" and t:find("Do Move out of Fire Storm",1,true) and t:find("Water Fire Resistance — Fire Storm, Fiery Burst",1,true), t)
assert(not t:find("Magma",1,true) and not t:find("Searing",1,true), "no fire damage totem against a boss that is immune to fire")
pull("Emperor Dagran Thaurissan");assert(at()=="emperor" and texts():find("Do Interrupt the Princess's Heal",1,true), texts())
leave()
-- the temple under either of the names the game may give it
enter("Sunken Temple");assert(T.inside=="sunken-temple");pull("Shade of Eranikus");assert(at()=="eranikus");leave()
enter("The Temple of Atal'Hakkar");assert(T.inside=="sunken-temple");leave()
-- three wings under one instance name: East first, a named pull settles it, and the choice is kept
enter("Dire Maul");assert(T.inside=="dire-maul-east" and texts():find("Wing East · click for West",1,true), texts())
pull("King Gordok");assert(T.inside=="dire-maul-north" and at()=="gordok" and texts():find("Wing North · click for East",1,true), texts())
pull("Immol'thar");assert(T.inside=="dire-maul-west" and at()=="immolthar")
leave();enter("Dire Maul");assert(T.inside=="dire-maul-west", "the wing last played is the one shown next time")
cmd("tips wing north");assert(T.inside=="dire-maul-north");leave()
-- Stratholme by its two gates
enter("Stratholme");assert(T.inside=="stratholme-main-gate" and texts():find("Wing Main Gate · click for Service Gate",1,true), texts())
pull("Baron Rivendare");assert(T.inside=="stratholme-service-gate" and at()=="baron" and texts():find("Do Kill the Mindless Skeletons at once",1,true), texts())
leave()
-- Blackrock Spire, lower and upper; a name that names the run needs no choice
enter("Blackrock Spire");assert(T.inside=="lower-blackrock-spire")
pull("General Drakkisath");assert(T.inside=="upper-blackrock-spire" and at()=="drakkisath")
leave();enter("Lower Blackrock Spire");assert(T.inside=="lower-blackrock-spire");leave()
enter("Upper Blackrock Spire");assert(T.inside=="upper-blackrock-spire");leave()
-- previews by the dungeon list's names, the way the Dungeons page asks
for _,name in ipairs({"Stratholme: Service Gate","Dire Maul: North","Upper Blackrock Spire","The Sunken Temple","Blackrock Depths","Scholomance"}) do
 cmd("tips show "..name);local key=T:Active();assert(D.dungeons[key].name==name and T.title:GetText():find(name,1,true), name.." previews "..tostring(key))
end
-- a mage sees the same Do and Watch lines, and no totems
M.class="MAGE";cmd("tips show Stratholme: Service Gate");cmd("tips go baron");t=texts()
assert(t:find("Do Kill the Mindless Skeletons at once",1,true) and t:find("Watch Unholy Aura",1,true) and not t:find("Earth ",1,true), t)
assert(#FP.db.errors==0)
''',

        'dungeon_tips_controls_on_the_dungeons_page': TIPS + hub + r'''
page("dungeons")
assert(H.controls.tipsStatus:GetText():find("The card appears by itself inside a dungeon that has tips",1,true) and H.controls.tipsStatus:GetText():find("Dungeons with tips: The Sunken Temple, Blackrock Depths, Blackrock Spire (Lower, Upper), Dire Maul (East, West, North), Scholomance, Stratholme (Main Gate, Service Gate).",1,true))
assert(not H.controls.tipsNewRun:IsEnabled())
click("tipsShow");assert(shown() and FP.settings.dungeonTips.manual=="show")
click("tipsHide");assert(not shown());click("tipsAuto");assert(FP.settings.dungeonTips.manual==nil)
check("tipsEnabled",false);assert(FP.settings.dungeonTips.enabled==false);check("tipsEnabled",true)
check("tipsLock",true);assert(FP.settings.dungeonTips.locked==true)
enter();H:Refresh()
assert(T.Plain(H.controls.tipsStatus:GetText()):find("Inside Scholomance: stop 1 of "..#S.stops..", Entry halls.",1,true), H.controls.tipsStatus:GetText())
cmd("tips go ras");click("tipsNewRun");assert(at()=="entry")
click("tipsList");assert(T.Plain(table.concat(H.pages.dungeons.results,"\n")):find(#S.stops..". Darkmaster Gandling: Stoneskin · Mana Spring · Grounding",1,true), table.concat(H.pages.dungeons.results,"\n"))
assert(#FP.db.errors==0)
''',
    }
