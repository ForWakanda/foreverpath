"""Gear the bundled reference does not have: rewards of the quests in the log and
items the quest database names, read from the client; a search that looks in
every slot; and items with no required level at the level cap. Mock-only: nothing here proves what the game
client answers (HearthAndHustleDB.gearLive is the receipt for that).

The report: a level-60 restoration shaman about to hand in "The Darkreaver
Menace" (#8258), which offers Skyfury Helm or Skyfury Gauntlets, found neither
on the Best in slot page. The item numbers below are fixtures, except the
helm's, which are the Classic ones."""

LIVE = r'''
local G,A,R=FP.Gear,FP.API,FP.QuestRewards
M.class="SHAMAN";M.level=60;FP.cdb.gear.profile="healer"
local CLIENT={
 [20134]={name="Skyfury Helm",q=4,ilvl=62,min=0,loc="INVTYPE_HEAD",class=4,sub=3,bind=1,
  stats={RESISTANCE0_NAME=324,ITEM_MOD_STRENGTH_SHORT=13,ITEM_MOD_STAMINA_SHORT=14,ITEM_MOD_SPIRIT_SHORT=12}},
 [20133]={name="Skyfury Gauntlets",q=4,ilvl=62,min=0,loc="INVTYPE_HAND",class=4,sub=3,bind=1,
  stats={RESISTANCE0_NAME=249,ITEM_MOD_INTELLECT_SHORT=14,ITEM_MOD_STAMINA_SHORT=10,ITEM_MOD_SPELL_HEALING_DONE_SHORT=26}},
 [13944]={name="Tombstone Breastplate",q=3,ilvl=62,min=57,loc="INVTYPE_CHEST",class=4,sub=3,bind=1,stats={ITEM_MOD_STRENGTH_SHORT=10,ITEM_MOD_STAMINA_SHORT=10}},
 [50001]={name="Outdoor Axe",q=3,ilvl=58,min=53,loc="INVTYPE_2HWEAPON",class=2,sub=1,sname="Two-Handed Axes",bind=2,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=50,ITEM_MOD_STRENGTH_SHORT=20}},
 [50002]={name="Vendor Ring",q=2,ilvl=40,min=35,loc="INVTYPE_FINGER",class=4,sub=0,sname="Miscellaneous",stats={ITEM_MOD_INTELLECT_SHORT=6,ITEM_MOD_POWER_REGEN0_SHORT=3}},
 [50003]={name="Plate Helm",q=3,ilvl=60,min=55,loc="INVTYPE_HEAD",class=4,sub=4,stats={ITEM_MOD_STRENGTH_SHORT=30}},
 [50004]={name="Plain Mail Cap",q=1,ilvl=60,min=55,loc="INVTYPE_HEAD",class=4,sub=3,stats={RESISTANCE0_NAME=200}},
 [50006]={name="Never Loads",q=3,ilvl=60,min=55,loc="INVTYPE_HEAD",class=4,sub=3,stats={},late=true,never=true},
 [50007]={name="Late Mail Belt",q=3,ilvl=60,min=55,loc="INVTYPE_WAIST",class=4,sub=3,stats={ITEM_MOD_INTELLECT_SHORT=9},late=true},
 [50008]={name="Guild Tabard",q=2,ilvl=1,min=0,loc="INVTYPE_TABARD",class=4,sub=0,stats={}},
 [50009]={name="Skyfury Idol of Nothing",q=3,ilvl=60,min=0,loc="INVTYPE_TRINKET",class=4,sub=0,stats={ITEM_MOD_STAMINA_SHORT=5}},
 [50010]={name="Statless Mail Boots",q=3,ilvl=60,min=55,loc="INVTYPE_FEET",class=4,sub=3},
 -- worn
 [301]={name="Worn Healing Cap",q=3,ilvl=55,min=50,loc="INVTYPE_HEAD",class=4,sub=3,stats={ITEM_MOD_INTELLECT_SHORT=10,ITEM_MOD_STAMINA_SHORT=10}},
 [302]={name="Worn Gloves",q=2,ilvl=50,min=45,loc="INVTYPE_HAND",class=4,sub=3,stats={ITEM_MOD_INTELLECT_SHORT=5}},
}
local requested,asked={},{}
local function idOf(link) return type(link)=="number" and link or tonumber(tostring(link):match("item:(%d+)")) end
C_Item.GetItemInfo=function(link)
 local id=idOf(link);local it=CLIENT[id];asked[id]=(asked[id] or 0)+1
 if not it or (it.late and not it.arrived) then return nil end
 return it.name,"|Hitem:"..id.."|h["..it.name.."]|h",it.q,it.ilvl,it.min,it.class==2 and "Weapon" or "Armor",it.sname or "Mail",1,it.loc,134400,1000,it.class,it.sub,it.bind
end
C_Item.GetItemStats=function(link) local it=CLIENT[idOf(link)];return it and it.stats end
C_Item.DoesItemExistByID=function(id) return CLIENT[id]~=nil end
C_Item.RequestLoadItemDataByID=function(id) requested[id]=(requested[id] or 0)+1;local it=CLIENT[id];if it and it.late and not it.never then it.arrived=true end end
C_TooltipInfo={GetItemByID=function(id)
 if id==50001 then return {lines={{leftText="Outdoor Axe"},{leftText="Two-Hand",rightText="Axe"},{leftText="142 - 214 Damage",rightText="Speed 3.60"},{leftText="(49.4 damage per second)"}}} end
 return {lines={{leftText="x"}}}
end}
local worn={}
GetInventoryItemID=function(_,slot) return worn[slot] end
GetInventoryItemLink=function(_,slot) return worn[slot] and ("item:"..worn[slot]) end
-- the quest database: names and where from, never a slot or a stat
local ITEM={
 [20134]={name="Skyfury Helm",class=4,subClass=3,itemLevel=62,requiredLevel=0,questRewards={8258}},
 [20133]={name="Skyfury Gauntlets",class=4,subClass=3,itemLevel=62,requiredLevel=0},
 [13944]={name="Tombstone Breastplate",class=4,subClass=3,itemLevel=62,requiredLevel=57,npcDrops={1853}},
 [50001]={name="Outdoor Axe",class=2,subClass=1,itemLevel=58,requiredLevel=53,npcDrops={900,901}},
 [50002]={name="Vendor Ring",class=4,subClass=0,itemLevel=40,requiredLevel=35,vendors={77}},
 [50003]={name="Plate Helm",class=4,subClass=4,itemLevel=60,requiredLevel=55,questRewards={1}},
 [50004]={name="Plain Mail Cap",class=4,subClass=3,itemLevel=60,requiredLevel=55,vendors={77}},
 [50005]={name="Gone From The Client",class=4,subClass=3,itemLevel=60,requiredLevel=55,questRewards={2}},
 [50006]={name="Never Loads",class=4,subClass=3,itemLevel=60,requiredLevel=55,questRewards={3}},
 [50007]={name="Late Mail Belt",class=4,subClass=3,itemLevel=60,requiredLevel=55,objectDrops={5}},
 [50008]={name="Guild Tabard",class=4,subClass=0,itemLevel=1,requiredLevel=0,vendors={77}},
 [50009]={name="Skyfury Idol of Nothing",class=4,subClass=0,itemLevel=60,requiredLevel=0},
 [50010]={name="Statless Mail Boots",class=4,subClass=3,itemLevel=60,requiredLevel=55,vendors={77}},
 [60001]={name="Quest Trophy",class=12,subClass=0,itemLevel=1,requiredLevel=0,questRewards={4}},
 [647]={name="Destiny",class=2,subClass=8,itemLevel=57,requiredLevel=52,npcDrops={900}},
 [873]={name="Staff of Jordan",class=2,subClass=10,itemLevel=40,requiredLevel=35,npcDrops={900}},
}
local NPC={[1853]={name="Darkmaster Gandling",zoneID=2057},[900]={name="Winterfall Shaman",zoneID=618},[901]={name="Winterfall Ursa",zoneID=618}}
local support={private={areaIdToUiMapId="return {[618]=1452}",dungeons={[2057]={"Scholomance",nil,28,{{28,69.7,73.2}}}}}}
local function reader(t) return {Get=function(id,key) return t[id] and t[id][key] end} end
local scans=0
LibQuestieDB={flavor={expansion="Forever"},readMode="baked",RequireContract=function()return true end,
 Support={Get=function()return support end},Quest=reader({[8258]={name="The Darkreaver Menace",requiredLevel=60,questLevel=60}}),Npc=reader(NPC),Item=reader(ITEM),Object=reader({})}
LibQuestieDB.Item.GetAllIds=function() scans=scans+1;local ids={};for id in pairs(ITEM) do ids[#ids+1]=id end;table.sort(ids);return ids end
-- the quest log, read by quest id
local LOG={[8258]={choice={20134,20133}},[5341]={reward={50002}}}
local selected=5341
C_QuestLog.GetSelectedQuest=function() return selected end
local honoursId=true
local function entry(id) return LOG[honoursId and id or selected] or {} end
GetNumQuestLogChoices=function(id) return #(entry(id).choice or {}) end
GetNumQuestLogRewards=function(id) return #(entry(id).reward or {}) end
GetQuestLogChoiceInfo=function(i,id) local item=(entry(id).choice or {})[i];if item then return CLIENT[item].name,nil,1,CLIENT[item].q,true,item end end
GetQuestLogRewardInfo=function(i,id) local item=(entry(id).reward or {})[i];if item then return CLIENT[item].name,nil,1,CLIENT[item].q,true,item end end
M.quests={}
M.AddQuest({questID=8258,title="The Darkreaver Menace",level=60,objectives={}})
M.AddQuest({questID=5341,title="Barov Family Fortune",level=60,objectives={}})
local function pump(n) for _=1,(n or 40) do M.RunTimers(.5) end end
-- what opening the gear page does: start reading, then let the timers run
local function load() G:LiveStart();pump() end
local function find(rows,id) for i,r in ipairs(rows) do if r.key==id then return i,r end end end
local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) end
assert(A.EnsureGearCatalog())
'''

# A small reference, for cases that count ranks.
SMALL = r'''
local function ref(id,name,loc,sub,stats,extra)
 local row={id=id,name=name,equipLoc=loc,classID=4,subclassID=sub,subtype=sub==3 and "Mail" or "",level=60,minLevel=58,stats=stats,sources={"Drops"},sourceTypes={"Drop"},bosses={}}
 for k,v in pairs(extra or {}) do row[k]=v end
 return row
end
FP.GearCatalog={date="fixture",items={
 ref(1,"Top Healing Helm","INVTYPE_HEAD",3,{ITEM_MOD_INTELLECT_SHORT=30,ITEM_MOD_SPELL_HEALING_DONE_SHORT=40}),
 ref(2,"Weak Helm","INVTYPE_HEAD",3,{ITEM_MOD_INTELLECT_SHORT=2}),
 ref(3,"Weak Gloves","INVTYPE_HAND",3,{ITEM_MOD_INTELLECT_SHORT=1}),
 ref(4,"Unlisted Level Trinket","INVTYPE_TRINKET",-4,{ITEM_MOD_INTELLECT_SHORT=7},{level=63,minLevel=false,sourceTypes={"Quest"},sources={"Quest Rewards"}}),
 ref(5,"Far Above Trinket","INVTYPE_TRINKET",-4,{ITEM_MOD_INTELLECT_SHORT=9},{level=71,minLevel=false}),
}}
for _,item in ipairs(FP.GearCatalog.items) do if item.minLevel==false then item.minLevel=nil end end
'''


def cases(hub):
    return {
        # the report itself
        'gear_reported_quest_reward_choices_missing_from_the_reference_are_listed': LIVE + r'''
-- the reference has neither item: that is what the player saw
for _,item in ipairs(FP.GearCatalog.items) do assert(not item.name:find("Skyfury",1,true),item.name) end
local first=G:Rows({slot="HEAD",query="skyfury"});assert(#first==0, "nothing has been read from the client yet")
pump()
local head=G:Rows({slot="HEAD",query="skyfury"})
local _,helm=find(head,20134);assert(#head==1 and helm, "the helm is not listed")
-- what it is came from the client, not from a table shipped with the addon
assert(helm.item.live and helm.item.equipLoc=="INVTYPE_HEAD" and helm.item.subtype=="Mail" and helm.item.quality==4 and helm.item.bind=="pickup")
assert(helm.item.stats.ITEM_MOD_STRENGTH_SHORT==13 and helm.item.stats.ITEM_MOD_SPIRIT_SHORT==12 and helm.item.minLevel==nil and helm.item.level==62)
assert(math.abs(helm.score-(14*.3+12*.7))<1e-9, "healing score "..tostring(helm.score))
assert(helm.item.logQuest.questID==8258 and helm.item.logQuest.kind=="choice")
-- the gauntlets: the quest database names no source for them at all; the quest log does
local hands=G:Rows({slot="HAND",query="skyfury"})
local _,gloves=find(hands,20133);assert(#hands==1 and gloves and gloves.item.logQuest.title=="The Darkreaver Menace")
assert(gloves.item.sourceTypes[1]=="Quest" and not gloves.item.unsourced)
-- and they rank in the plain slot list, with no search typed
local all=G:Rows({slot="HAND"});local at=find(all,20133);assert(at and all[at].rank==at and at<=#all)
assert(find(G:Rows({slot="HEAD"}),20134))
-- the row and the details say which quest, and that the numbers are the client's
assert(G:Where(helm.item):find("Your quest: The Darkreaver Menace",1,true))
local text=plain(G:Details(helm,"HEAD","healer"))
assert(text:find('In your quest log: one of the reward choices of "The Darkreaver Menace".',1,true), text)
assert(text:find("Not in the bundled item reference: what it is and its numbers were read from your client just now.",1,true), text)
assert(text:find("Stats: +13 Strength, +14 Stamina, +12 Spirit, 324 Armor",1,true), text)
assert(not text:find("has not loaded this item",1,true) and not text:find("Reference stats match",1,true), text)
-- searching by the quest's name finds its rewards too
assert(find(G:Rows({slot="HEAD",query="darkreaver"}),20134))
''',

        'gear_search_names_the_other_slots_it_found_the_item_in': LIVE + r'''
load()
local rows,message,_,_,elsewhere=G:Rows({slot="HEAD",query="skyfury gauntlets"})
assert(#rows==0 and elsewhere.HAND==1 and G:Elsewhere(elsewhere)=="Hands 1", G:Elsewhere(elsewhere))
assert(message=='Nothing in this slot matches "skyfury gauntlets". The search found it under: Hands 1.', message)
-- a match here and elsewhere: the list shows this slot, the count names the rest
rows,message,_,_,elsewhere=G:Rows({slot="HEAD",query="skyfury"})
assert(#rows==1 and message==nil and elsewhere.HAND==1 and elsewhere.HEAD==nil)
-- reference items are counted the same way (Staff of Jordan is a main-hand staff)
rows,message,_,_,elsewhere=G:Rows({slot="HEAD",query="staff of jordan"})
assert(#rows==0 and elsewhere.MAIN==1 and message:find("Main hand 1",1,true), message)
-- no search, no counting: the plain slot list never reports other slots
rows,message,_,_,elsewhere=G:Rows({slot="HEAD"});assert(#rows>0 and next(elsewhere)==nil)
-- nothing anywhere says so, and names the three places that were looked in
-- (once the items the searches above asked the client for have arrived)
pump(6)
rows,message=G:Rows({slot="HEAD",query="zzqx no such thing"})
assert(#rows==0 and message:find("not in the item reference, the quest database or your quest log",1,true), message)
-- an item of another class is not "found" for this one
rows,message,_,_,elsewhere=G:Rows({slot="HAND",query="plate helm"});assert(#rows==0 and next(elsewhere)==nil)
''',

        'gear_search_reaches_items_the_quest_database_names_no_source_for': LIVE + r'''
load()
-- unsourced: not read from the client, not in the slot list
assert(not asked[50009] and not find(G:Rows({slot="TRINKET"}),50009))
-- two letters are not a search worth reading the client for
G:Rows({slot="TRINKET",query="id"});pump(4);assert(not asked[50009] and G:LiveState().items[50009]==nil)
-- a search by name asks for it
local rows=G:Rows({slot="TRINKET",query="idol of nothing"});assert(#rows==0)
local _,message=G:Rows({slot="TRINKET",query="idol of nothing"});assert(message:find("Still reading items from your client",1,true), message)
pump(4)
rows=G:Rows({slot="TRINKET",query="idol of nothing"})
local _,idol=find(rows,50009);assert(idol and idol.item.unsourced and idol.item.sourceTypes[1]=="Unknown")
assert(G:Where(idol.item)=="source not known" and plain(G:Details(idol,"TRINKET","healer")):find("Where: not known (the quest database names no source)",1,true))
-- still only an answer to a search: it never joins the plain list
assert(not find(G:Rows({slot="TRINKET"}),50009))
''',

        'gear_live_items_carry_the_source_the_quest_database_lists': LIVE + r'''
load()
local function live(slot,id) local _,row=find(G:Rows({slot=slot,level=60}),id);return row end
-- a boss inside a dungeon: that dungeon's drop, with the boss
local chest=live("CHEST",13944)
assert(chest and chest.item.sourceTypes[1]=="Dungeon" and chest.item.sources[1]=="Scholomance" and chest.item.bosses[1]=="Darkmaster Gandling")
assert(G:Where(chest.item)=="Scholomance" and G:DropsIn(chest.item,"Scholomance")=="Darkmaster Gandling")
assert(find(G:Rows({slot="CHEST",level=60,source="Dungeon"}),13944) and not find(G:Rows({slot="CHEST",level=60,source="Quest"}),13944))
assert(plain(G:Details(chest,"CHEST","healer")):find("Where it comes from is what the quest database lists (Classic data with Forever corrections).",1,true))
-- creatures outdoors: a drop that names them
local axe=live("MAIN",50001)
assert(axe and axe.item.sourceTypes[1]=="Drop" and axe.item.droppedBy=="Winterfall Shaman and 1 more", axe and axe.item.droppedBy)
-- the type is the reference's word, so the Type filter keeps it with its neighbours
assert(axe.item.subtype=="Axe" and find(G:Rows({slot="MAIN",level=60,subtype="Axe",hands="two"}),50001))
-- damage and speed come from the client's tooltip lines
assert(axe.item.dmgMin==142 and axe.item.dmgMax==214 and axe.item.speed==3.6 and G:HitSize(axe.item)==178)
assert(G:Windfury(axe.item,{ap=500,apTwoHand=500,bonus=333,extra=2}))
-- a chest or object, a vendor
local belt=live("WAIST",50007);assert(belt and belt.item.droppedBy=="a chest, object or container")
-- a vendor; this ring is also a reward of a quest in the log, and says both
local ring=live("FINGER",50002);assert(ring and ring.item.sourceTypes[1]=="Quest" and ring.item.sourceTypes[2]=="Vendor" and G:Where(ring.item)=="Your quest: Barov Family Fortune / Vendor", G:Where(ring.item))
-- mana regeneration under the client's other name is scored like the reference's
assert(ring.item.stats.ITEM_MOD_MANA_REGENERATION_SHORT==3 and math.abs(ring.score-(6+3*3))<1e-9, ring.score)
-- never listed: another class's armor, a common-quality item, a tabard, an item the client
-- does not know, one that never loads, one with no stat table, a non-gear item
for _,id in ipairs({50003,50004,50005,50006,50008,50010,60001}) do
 for _,s in ipairs(G.slots) do assert(not find(G:Rows({slot=s[1],level=60,otherFaction=true}),id), id.." listed under "..s[2]) end
end
-- an id the reference has is the reference's: one row, the reference's numbers
local destiny=0
M.class="WARRIOR";for _,r in ipairs(G:Rows({slot="MAIN",level=60,query="destiny"})) do if r.key==647 then destiny=destiny+1;assert(not r.item.live) end end;M.class="SHAMAN"
assert(destiny==1)
''',

        'gear_live_loader_asks_only_for_usable_items_and_leaves_a_receipt': LIVE + r'''
local L=G:LiveState()
G:Rows({slot="HEAD"})
assert(next(asked)==nil, "nothing is read inside the call that draws the page")
pump()
-- armor the class cannot wear and non-gear are never asked of the client
assert(not asked[50003] and not asked[60001] and not requested[50003])
-- an item the client says does not exist is dropped without waiting for it
assert(not requested[50005] and L.items[50005]==false)
-- one that was not loaded is asked for once, then read when it arrives
assert(requested[50007]==1 and L.items[50007] and L.items[50007].name=="Late Mail Belt")
-- one that never arrives is given up after a bounded number of looks
assert(requested[50006]==1 and L.items[50006]==false and asked[50006]==G.LIVE.tries+1, asked[50006])
local status=G:LiveStatus();assert(not status.busy and status.pending==0 and status.listed==L.counts.listed)
-- the database is walked once per session
assert(scans==1);G:Rows({slot="HEAD"});G:LiveStart();pump(3);assert(scans==1)
local c=FP.db.gearLive.counts
assert(c.unknown==1 and c.gaveUp==1 and c.lowQuality==1 and c.notGear==1 and c.noStats==1 and c.later==1, snapshot(c))
assert(c.listed==6 and c.asked==c.immediate+c.later+c.gaveUp+c.unknown, snapshot(c))
local r=FP.db.gearLive
assert(r.database==true and r.scanned==16 and r.missing==13 and r.log.quests==2 and r.log.withItems==2 and r.log.ignored==false and r.version==FP.version)
local keys=table.concat(r.statKeys,",");assert(keys:find("ITEM_MOD_POWER_REGEN0_SHORT",1,true) and keys:find("RESISTANCE0_NAME",1,true), keys)
-- in combat nothing is read; it resumes afterwards
G.live=nil;asked={};requested={}
M.combatLockdown=true;G:LiveStart();pump(3);assert(next(asked)==nil and G:LiveStatus().paused)
M.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED");pump()
assert(G:LiveState().items[20134] and G:LiveStatus().listed==6)
-- combat that starts while the list is being read stops it at once
G.live=nil;asked={};G:LiveStart();M.RunTimers(.5)
M.combatLockdown=true;local seen=snapshot(asked);pump(6)
assert(snapshot(asked)==seen and G:LiveStatus().paused and G:LiveStatus().busy, "items were read in combat")
M.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED");pump();assert(not G:LiveStatus().busy and G:LiveStatus().listed==6)
-- the client is asked to load an item once, and only so many in a session
local calls=0;local keep=C_Item.RequestLoadItemDataByID;C_Item.RequestLoadItemDataByID=function() calls=calls+1 end
assert(A.RequestItemData(70001)==true and A.RequestItemData(70001)==false and calls==1)
assert(A.RequestItemData(0)==false and A.RequestItemData(1.5)==false and A.RequestItemData(nil)==false and calls==1)
local limit=A.ITEM_DATA_REQUEST_LIMIT;A.ITEM_DATA_REQUEST_LIMIT=0;assert(A.RequestItemData(70002)==false and calls==1);A.ITEM_DATA_REQUEST_LIMIT=limit
C_Item.RequestLoadItemDataByID=keep
-- no quest database: the quest log's rewards are still read and listed
G.live=nil;LibQuestieDB=nil;G:LiveStart();pump()
assert(G:LiveStatus().unavailable and G:LiveState().items[20134] and G:LiveState().items[20133] and G:LiveStatus().listed==3)
assert(FP.db.gearLive.database==false and FP.db.gearLive.missing==0)
''',

        'gear_log_rewards_follow_the_quest_log': LIVE + r'''
load()
local L=G:LiveState()
assert(L.items[20134].logQuest and L.items[50002].logQuest.title=="Barov Family Fortune" and L.items[50002].logQuest.kind=="reward")
-- the quest is handed in: its rewards stay as items, no longer "in your log"
M.RemoveQuest(8258);M.FireEvent("QUEST_LOG_UPDATE");H=FP.Hub;H:Open("gear");pump(8)
assert(L.items[20134] and L.items[20134].logQuest==nil and L.items[20133].logQuest==nil)
assert(not G:Where(L.items[20134]):find("Your quest",1,true))
-- the helm keeps the quest database's source; the gauntlets had only the log
assert(L.items[20134].sourceTypes[1]=="Quest")
H.frame:Hide()
''',

        'log_reward_read_detects_a_client_that_ignores_the_quest_id': LIVE + r'''
local log=A.GetLogRewardItems()
assert(log.quests==2 and log.withItems==2 and #log.items==3 and not log.ignored)
assert(log.items[1].id==20134 and log.items[1].questID==8258 and log.items[1].kind=="choice" and log.items[1].title=="The Darkreaver Menace")
assert(log.items[3].id==50002 and log.items[3].questID==5341 and log.items[3].kind=="reward")
-- a client that answers every quest id with the selected quest's rewards
honoursId=false
log=A.GetLogRewardItems()
assert(log.ignored and log.quests==2 and #log.items==1 and log.items[1].id==50002 and log.items[1].questID==5341, snapshot(log))
selected=8258;log=A.GetLogRewardItems();assert(log.ignored and #log.items==2 and log.items[1].questID==8258)
-- nothing selected: such a client answers with nothing, and nothing is listed
selected=nil;log=A.GetLogRewardItems();assert(not log.ignored and #log.items==0)
honoursId=true
-- never in combat, and a missing function is "cannot read", not "no rewards"
M.combatLockdown=true;assert(A.GetLogRewardItems()==nil);M.combatLockdown=false
local keep=GetQuestLogChoiceInfo;GetQuestLogChoiceInfo=nil;assert(A.GetLogRewardItems()==nil);GetQuestLogChoiceInfo=keep
-- unreadable counts and item ids are skipped, not guessed
GetNumQuestLogChoices=function() return M.Secret() end
log=A.GetLogRewardItems();assert(#log.items==1 and log.items[1].id==50002)
''',

        'gear_at_the_level_cap_lists_items_with_no_required_level': LIVE + SMALL + r'''
LibQuestieDB=nil;G.live=nil
-- item level 63 and 71, no requirement listed: at 60 nothing can ask for more
local rows=G:Rows({slot="TRINKET",level=60})
assert(find(rows,4) and find(rows,5) and #rows==2, #rows)
-- below the cap the item level stays the guide, and the tick allows five above it
assert(#G:Rows({slot="TRINKET",level=59})==0)
rows=G:Rows({slot="TRINKET",level=59,unknown=true});assert(#rows==1 and find(rows,4))
assert(#G:Rows({slot="TRINKET",level=66,unknown=false})==2)
-- a listed requirement is still a requirement at the cap
FP.GearCatalog.items[4].minLevel=61;G.rankMemo=nil
assert(not find(G:Rows({slot="TRINKET",level=60}),4))
''' + r'''
-- the shipped reference: quest rewards above item level 60 are there at 60 without a tick
FP.GearCatalog=nil;assert(A.EnsureGearCatalog())
local hidden,shown=0,0
local at60={}
for _,s in ipairs(G.slots) do for _,r in ipairs(G:Rows({slot=s[1],level=60,otherFaction=true})) do at60[r.key]=true end end
local char=A.GetCharInfo()
for _,item in ipairs(FP.GearCatalog.items) do
 if not item.minLevel and item.level and item.level>60 and G:ClassMatches(item,char) and G:SlotOf(item) then
  if at60[item.id] then shown=shown+1 else hidden=hidden+1 end
 end
end
assert(hidden==0 and shown>60, hidden.." hidden, "..shown.." shown")
''',

        'gear_page_shows_live_items_and_where_else_a_search_matched': hub + LIVE + r'''
local P=FP.GearPanel
worn={[1]=301,[10]=302}
page("gear");pump()
field("gearSearch","skyfury");H.controls.gearSearch:GetScript("OnTextChanged")()
local list=H.controls.gearItems
assert(#list.items==1 and list.items[1].key==20134, #list.items)
-- the search also asked the client for a same-named item the database has no source for
assert(P.status:GetText():find("still reading 1 more from your client",1,true), P.status:GetText())
pump(6)
local status=P.status:GetText()
for _,part in ipairs({"1 item","Head","matching \"skyfury\"","same search in other slots: Hands 1, Trinkets 1","1 read from your client"}) do assert(status:find(part,1,true),part.." missing in: "..status) end
assert(not status:find("still reading",1,true), status)
assert(list.rows[1]:GetText():find("Skyfury Helm",1,true) and list.rows[1]:GetText():find("Your quest",1,true), list.rows[1]:GetText())
assert(P.details:GetText():find("In your quest log",1,true))
assert(P.note:GetText():find("read from your client (7 so far)",1,true), P.note:GetText())
-- the slot the search pointed at
click("gearSlotHAND");assert(#list.items==1 and list.items[1].key==20133 and P.status:GetText():find("same search in other slots: Head 1, Trinkets 1",1,true))
-- a live item can be put on the wishlist like any other
click("gearSave");assert(FP.cdb.gear.wishlist[20133]);click("gearWishlist");assert(#list.items==1);click("gearWishlist")
-- the quest source button reaches the quest database for it
click("gearSlotHEAD");assert(H.controls.gearQuestSource:GetText():find("quest source",1,true))
-- nothing in the slot: the line above the list says where the search did find it
field("gearSearch","skyfury gauntlets");H.controls.gearSearch:GetScript("OnTextChanged")()
assert(#list.items==0 and P.status:GetText():find("The search found it under: Hands 1.",1,true), P.status:GetText())
-- browsing never changed the character's role or wrote anything but the wishlist and the receipt
assert(FP.cdb.gear.profile=="healer" and FP.db.gearLive.counts.listed==7 and #FP.db.errors==0)
''',
    }
