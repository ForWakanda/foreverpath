"""Dungeon itinerary: pickups in order, entrance, inside, drops for the role. Mock-only."""
from travel import WORLD

# Zul'Farrak from the shipped catalogue, with a quest database that places its givers
# on the two-continent test world: two in Tanaris, one in Feralas, one across the sea
# in Stranglethorn, one inside the dungeon.
PLAN = WORLD + r'''
local DP,D=FP.DungeonPlan,FP.Dungeons
M.class="SHAMAN";M.level=50;FP.cdb.gear.profile="healer"
local NPC={
 [7406]={name="Chief Engineer Bilgewhizzle",spawns={[440]={{67,22}}}},
 [7407]={name="Wizzle Brassbolts",spawns={[357]={{50,50}}}},
 [6546]={name="Tabetha",spawns={[33]={{30,30}}}},
 [7804]={name="Tran'rek",spawns={[440]={{51,27}}}},
 [7771]={name="Marvon Rivetseeker",spawns={[1176]={{-1,-1}}}},
 [7572]={name="Master Gadrin",spawns={[14]={{56,74}}}},
}
NPC[5648]={name="Sandfury Blood Drinker",spawns={[1176]={{-1,-1}}}}
local START={[2768]=7406,[2770]=7407,[2846]=6546,[2865]=7804,[3042]=7771,[2936]=7572,[2937]=7572}
local ITEMSTART,ITEM={},{[9240]={name="Mallet of Zul'Farrak",npcDrops={5648}}}
local support={private={areaIdToUiMapId="return {[440]=1446,[357]=1444,[33]=1434,[14]=1411,[15]=1445}",dungeons={
 [1176]={"Zul'Farrak",nil,440,{{440,38.7,20.1}}},
}}}
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function()return true end,
 Support={Get=function()return support end},
 Quest={Get=function(qid,key) if key=="startedBy" then if START[qid] then return {{START[qid]}} elseif ITEMSTART[qid] then return {nil,nil,{ITEMSTART[qid]}} end end end,GetAllIds=function()return {} end},
 Npc={Get=function(id,key) return NPC[id] and NPC[id][key] end},
 Item={Get=function(id,key) return ITEM[id] and ITEM[id][key] end},Object={Get=function()end}}
local done={}
C_QuestLog.IsQuestFlaggedCompleted=function(id) return done[id] or false end
local function fresh() DP.memo,DP.gearMemo=nil,nil;FP.QuestChains.starters={} end
local function build(key) fresh();return DP:Build(key or "zul-farrak") end
local function kinds(plan) local out={};for _,r in ipairs(plan.rows) do out[#out+1]=r.type end;return table.concat(out," ") end
local function row(plan,kind,n) local seen=0;for i,r in ipairs(plan.rows) do if r.type==kind then seen=seen+1;if seen==(n or 1) then return r,i end end end end
local function log(id,title,complete) M.AddQuest({questID=id,title=title,objectives={{text="0/1 Thing",type="item",numFulfilled=0,numRequired=1,finished=false}}});M.complete[id]=complete;FP.Recorder.RescanLog("plan") end
stand(1446,.5,.5)
'''


def cases(hub):
    return {
        'dungeon_plan_orders_pickups_by_zone_with_the_crossing_and_ends_at_the_entrance': PLAN + r'''
local plan=build()
assert(plan.pickups==4 and plan.zones==3 and plan.inside==1 and plan.chain==4 and plan.later==0 and plan.turnins==0 and plan.hidden==4, kinds(plan))
-- before you enter: Tanaris (two givers, by name), Feralas, the crossing, Stranglethorn, the crossing back, the entrance
local i=select(2,row(plan,"header"))
local order={}
for n=i+1,i+8 do order[#order+1]=plan.rows[n] end
assert(plan.rows[i].text=="— Before you enter —")
assert(order[1].text:find("1. Tanaris — pick up: Divino-matic Rod (Chief Engineer Bilgewhizzle)",1,true) and order[1].dist, order[1].text)
assert(order[2].text:find("1. Tanaris — pick up: Scarab Shells (Tran'rek)",1,true) and not order[2].dist, "one distance per stop")
assert(order[3].text:find("2. Feralas — pick up: Gahz'rilla",1,true) and order[3].text:find("+",1,true))
assert(order[4].type=="crossing" and order[4].leg.to.mapID==1434, order[4].text)
assert(order[5].text:find("3. Stranglethorn Vale — pick up: Tiara of the Deep (Tabetha)",1,true))
assert(order[6].type=="crossing" and order[6].leg.from.mapID==1434, "and back for the entrance")
assert(order[7].type=="entrance" and order[7].text:find("Entrance: Tanaris 38.7, 20.1",1,true) and order[7].index==1, order[7].text)
assert(order[8].type=="header" and order[8].text=="— Inside —")
assert(row(plan,"pickup-inside").text=="Pick up inside: Troll Temper (Marvon Rivetseeker)")
-- quests behind a chain are listed apart with the step that opens them, never as pickups
local behind=0;for _,r in ipairs(plan.rows) do if r.type=="chain" then behind=behind+1;assert(r.text:find(" — first: ",1,true) and r.first and not r.text:find("Check prerequisite",1,true), r.text) end end;assert(behind==4)
assert(not row(plan,"later"))
assert(DP:Summary(plan):find("4 pickups before you enter in 3 zones · 1 inside · 4 behind a quest chain.",1,true), DP:Summary(plan))
-- the nearest zone leads: standing in Feralas reverses the first two stops
stand(1444,.5,.5);plan=build()
assert(row(plan,"pickup").text:find("1. Feralas",1,true) and row(plan,"pickup",2).text:find("2. Tanaris",1,true))
-- starting across the sea: that side first, one crossing, then the rest and the entrance
stand(1434,.3,.3);plan=build()
assert(row(plan,"pickup").text:find("1. Stranglethorn Vale",1,true) and row(plan,"crossing").leg.from.mapID==1434 and not row(plan,"crossing",2))
-- no position (inside an instance): still the whole list, with no distance from where you stand
M.noPosition=true;plan=build()
assert(plan.pickups==4 and plan.zones==3 and not row(plan,"pickup").dist and row(plan,"entrance") and not row(plan,"gap"))
M.noPosition=nil;stand(1446,.5,.5)
-- a giver the reference cannot place is listed apart, with what the catalogue says
NPC[7407].spawns=nil;plan=build()
assert(plan.pickups==3 and plan.unplaced==1 and row(plan,"pickup-unplaced").text=="Pick up (place not in the reference): Gahz'rilla — Wizzle Brassbolts, Thousand Needles")
assert(DP:Summary(plan):find("4 pickups before you enter in 2 zones",1,true))
-- no quest database: nothing is placed and the page says why
LibQuestieDB=nil;plan=build()
assert(plan.pickups==0 and plan.unplaced==5 and not plan.entrance and DP:Summary(plan):find("need QuestieDB",1,true))
assert(#FP.db.errors==0)
''',

        'dungeon_plan_follows_the_quest_log_and_the_checklist_states': PLAN + r'''
log(2768,"Divino-matic Rod",true);log(2865,"Scarab Shells");done[2846]=true
local plan=build()
assert(kinds(plan):find("^header turnin header pickup entrance header active pickup%-inside header chain chain chain chain"), kinds(plan))
assert(plan.rows[1].text=="— Turn in first —" and row(plan,"turnin").text=="Turn in: Divino-matic Rod")
assert(row(plan,"active").text=="In your log: Scarab Shells" and plan.done==1 and plan.pickups==1)
assert(DP:Summary(plan):find("1 ready to turn in · 1 pickup before you enter in 1 zone · 2 inside · 4 behind a quest chain · 1 completed.",1,true), DP:Summary(plan))
-- a finished prerequisite opens the next step as a pickup
done[2935]=true;plan=build()
local opened;for _,r in ipairs(plan.rows) do if r.type=="pickup" and r.quest.id==2936 then opened=r end end
assert(opened and opened.text:find("Durotar — pick up: The Spider God (Master Gadrin)",1,true) and plan.chain==3)
-- a quest the database starts from an item that drops inside belongs inside, with what drops it
START[3042]=nil;ITEMSTART[3042]=9240;plan=build()
assert(row(plan,"drop").text=="Drops inside: Troll Temper — from Sandfury Blood Drinker" and not row(plan,"pickup-inside"), row(plan,"drop") and row(plan,"drop").text)
ITEMSTART[3042]=nil;START[3042]=7771
-- quest state the client will not give is "not available yet", not a pickup
C_QuestLog.IsQuestFlaggedCompleted=function() error("unavailable") end;plan=build()
assert(plan.pickups==0 and plan.later>=5 and row(plan,"later").text:find("Quest state unavailable",1,true))
C_QuestLog.IsQuestFlaggedCompleted=function(id) return done[id] or false end
-- which dungeon the page opens on
assert(DP:Default()=="zul-farrak", "the one with quests in the log")
M.quests={};M.complete={};FP.Recorder.RescanLog("plan")
FP.cdb.dungeonChecklist.selected="uldaman";assert(DP:Default()=="uldaman", "else the last one opened")
FP.cdb.dungeonChecklist.selected="alcaz-prison";assert(DP:Default()=="maraudon", "but not one without a quest list: the range you are in the middle of")
M.level=20;FP.cdb.dungeonChecklist.selected=nil;local key=DP:Default();assert(DP:Fits(FP.DungeonCatalog.dungeons[key],20) and #FP.DungeonCatalog.dungeons[key].quests>0)
M.level=50
for _,r in ipairs(DP:List()) do if r.key=="zul-farrak" then assert(r.fits and DP:ListLabel(r)=="Zul'Farrak · 44-54 · your level") elseif r.key=="alcaz-prison" then assert(DP:ListLabel(r):find("no quest list",1,true)) elseif r.key=="scholomance" then assert(not r.fits) end end
-- a dungeon with no catalogued quests says so and claims nothing
plan=build("alcaz-prison");assert(DP:Summary(plan):find("Quest coverage is not catalogued",1,true) and DP:Summary(plan):find("Entrance not in the reference",1,true))
for _,r in ipairs(plan.rows) do assert(r.type=="header" or r.type=="gear") end
assert(DP:Build("no-such-dungeon")==nil and #FP.db.errors==0)
''',

        'dungeon_plan_lists_drops_that_beat_what_is_worn_for_the_chosen_role': PLAN + r'''
local G=FP.Gear
assert(G:SourceIsDungeon("The Temple of Atal'Hakkar","The Sunken Temple") and G:SourceIsDungeon("Blackrock Spire","Lower Blackrock Spire"))
assert(G:SourceIsDungeon("Scarlet Monastery","Scarlet Monastery: Library") and G:SourceIsDungeon("The Deadmines","The Deadmines") and G:SourceIsDungeon("Zul'Farrak","Zul'Farrak"))
assert(not G:SourceIsDungeon("Zul'Farrak","Maraudon") and not G:SourceIsDungeon("","Maraudon") and not G:SourceIsDungeon(nil,"Maraudon"))
local plan=build()
local gear=plan.gear;assert(#gear>0 and #gear<=8 and gear.role=="Healing" and not plan.gearNote)
for i,r in ipairs(gear) do
 assert(r.type=="gear" and r.delta>0 and G:DropsIn(r.item,"Zul'Farrak") and G:ClassMatches(r.item,FP.API.GetCharInfo()))
 assert(r.text:find("Upgrade: "..r.item.name,1,true) and r.text:find(r.slot[2],1,true))
 if i>1 then assert(gear[i-1].delta>=r.delta, "best first") end
 assert(not r.item.minLevel or r.item.minLevel<=52, "nothing far above your level")
end
for _,r in ipairs(build("blackrock-depths").gear) do assert(not r.item.minLevel or r.item.minLevel<=52, r.item.name.." needs "..tostring(r.item.minLevel)) end
assert(plan.rows[#plan.rows].type=="gear" and DP:Summary(plan):find("Drops for Healing: "..#gear.." possible upgrade",1,true), DP:Summary(plan))
-- the role decides: a melee shaman is shown different drops
FP.cdb.gear.profile="melee";local melee=build().gear;assert(melee.role=="Strength melee" and melee[1].item.id~=gear[1].item.id);FP.cdb.gear.profile="healer"
-- the Temple's drops were never linked to the Sunken Temple before
local temple=build("sunken-temple").gear;assert(#temple>0)
assert(FP.GearPanel:Dungeons({item=temple[1].item})[1].key=="sunken-temple")
-- a saved drop leads the list and stays listed
local pick=gear[#gear];assert(DP:ToggleWish(pick) and FP.cdb.gear.wishlist[pick.item.id]==true)
plan=build();assert(plan.gear[1].item.id==pick.item.id and plan.gear[1].wished and plan.gear[1].text:find("Wishlist: ",1,true))
assert(DP:Summary(plan):find("1 on your wishlist",1,true) and DP:RowDetails(plan,plan.gear[1]):find("Drops from:",1,true))
-- wearing something better: no upgrade claimed, the saved one still shown
local worn=FP.API.GetRewardEquipment
FP.API.GetRewardEquipment=function() return {status="equipped",stats={ITEM_MOD_SPELL_HEALING_DONE_SHORT=5000}} end
plan=build();assert(#plan.gear==1 and plan.gear[1].wished and plan.gear[1].delta<0)
assert(DP:ToggleWish(plan.gear[1]) and FP.cdb.gear.wishlist[pick.item.id]==nil)
plan=build();assert(#plan.gear==0 and DP:Summary(plan):find("No listed drop here beats what you wear for Healing.",1,true))
-- worn items not readable yet: no comparison, so no upgrade claimed
FP.API.GetRewardEquipment=function() return {status="loading"} end
plan=build();assert(#plan.gear==0)
FP.API.GetRewardEquipment=worn
-- cloth-only class: no mail or leather offered
M.class="MAGE";FP.cdb.gear.profile="caster";for _,r in ipairs(build().gear) do assert(r.item.classID~=4 or r.item.subclassID<=1 or r.item.equipLoc=="INVTYPE_CLOAK", r.item.name) end
M.class="SHAMAN";FP.cdb.gear.profile="healer"
-- in combat the comparison waits and nothing is toggled
M.combatLockdown=true;plan=build();assert(#plan.gear==0 and plan.gearNote:find("after combat",1,true) and not DP:ToggleWish(pick));M.combatLockdown=false
assert(#FP.db.errors==0)
''',

        'dungeon_plan_page_guides_only_on_the_click': hub + PLAN + r'''
log(2865,"Scarab Shells")
local before,beforeChar=snapshot(FP.settings),snapshot(FP.cdb)
page("dungeons")
local list,steps=H.controls.hubDungeons,H.controls.dungeonPlan
assert(list.selected=="zul-farrak", "opens on the dungeon you have quests for: "..tostring(list.selected))
local onPage=false;for _,b in ipairs(list.rows) do if b.item and b.item.key=="zul-farrak" then onPage=true end end;assert(onPage, "and on the page that shows it")
assert(#steps.items>8 and H.controls.dungeonSummary:GetText():find("Zul'Farrak",1,true))
assert(not H.controls.dungeonGuide:IsEnabled() and not H.controls.dungeonWish:IsEnabled() and not active())
assert(snapshot(FP.settings)==before and snapshot(FP.cdb)==beforeChar, "browsing changed something")
local function pick(kind,n)
 local seen=0
 for i,r in ipairs(steps.items) do if r.type==kind then seen=seen+1;if seen==(n or 1) then
  steps.page=math.ceil(i/8);H:Refresh();selectRow("dungeonPlan",(i-1)%8+1);return r end end end
 error("no row of type "..kind)
end
pick("header");assert(not H.controls.dungeonGuide:IsEnabled())
pick("crossing");assert(not H.controls.dungeonGuide:IsEnabled() and H.controls.dungeonPlanDetails:GetText():find("lands at",1,true))
-- a quest behind a chain: the button leads to the step that opens it; with no place known for that step nothing is set
pick("chain");assert(H.controls.dungeonGuide:IsEnabled() and not active());click("dungeonGuide");assert(not active())
-- a pickup: the click, and only the click, sets the destination
local r=pick("pickup");assert(H.controls.dungeonPlanDetails:GetText():find("Known pickup place: Tanaris 67.0, 22.0",1,true), H.controls.dungeonPlanDetails:GetText())
assert(not active());click("dungeonGuide")
local wp=active();assert(wp and wp.source.type=="chain-pickup" and wp.source.questID==r.quest.id and wp.mapID==1446)
-- the giver inside: guided to the entrance
pick("pickup-inside");click("dungeonGuide");wp=active();assert(wp.source.type=="chain-pickup" and wp.source.entrance and wp.x==.387)
pick("entrance");click("dungeonGuide");wp=active();assert(wp.source.type=="dungeon-entrance" and wp.source.dungeon=="zul-farrak")
-- inside an instance the entrance is not offered
M.instance={name="Zul'Farrak"};H:Refresh();assert(not H.controls.dungeonGuide:IsEnabled());M.instance=nil;H:Refresh()
-- a drop: saved and removed by the same button
local g=pick("gear");assert(H.controls.dungeonWish:IsEnabled() and H.controls.dungeonWish:GetText()=="Save drop to wishlist")
click("dungeonWish");assert(FP.cdb.gear.wishlist[g.item.id]==true and H.controls.dungeonWish:GetText()=="Remove from wishlist")
click("dungeonWish");assert(FP.cdb.gear.wishlist[g.item.id]==nil)
assert(not DP:Guide(DP:Build("zul-farrak"),g) and not DP:Guide(nil,nil))
-- another dungeon: the step list starts over
steps.page=2
for n,b in ipairs(list.rows) do if b.item and b.item.key~="zul-farrak" then selectRow("hubDungeons",n);break end end
assert(list.selected~="zul-farrak" and steps.page==1 and steps.selected==nil)
-- the full checklist is one click away, on the dungeon chosen here
local key=list.selected;click("openDungeonChecklist");assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==key)
-- chat
local n=#M.Chat();cmd("dungeon plan zul");local said=false
for i=n+1,#M.Chat() do if tostring(M.Chat()[i]):find("Before you enter",1,true) then said=true end end;assert(said)
n=#M.Chat();cmd("dungeon plan nosuchplace");assert(tostring(M.Chat()[#M.Chat()]):find("No matching dungeon",1,true))
cmd("dungeon plan scarlet");assert(tostring(M.Chat()[#M.Chat()]):find("Several dungeons match",1,true))
assert(#FP.db.errors==0)
''',
    }
