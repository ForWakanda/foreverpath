"""Which dungeon next: dungeons ranked by what their drops add over the gear the character
carries, for its own role and a second spec. Mock-only; synthetic item reference on the
shipped dungeon catalogue."""

# A level-50 resto shaman with a Windfury second spec. Worn: healing pieces, a one-hand
# mace and a shield. In the bags: the two-hander of the second spec.
#   healing weights: int 1, spi .7, sta .3, heal 1, mp5 3   melee: str 2, agi 1, sta .3, ap 1, dps 6
#   owned for Healing: head 10, chest 20, hands 5+5      -> set 40
#   owned for melee:   head 0, chest 0, two-hander 260    -> set 260
NEXT = r'''
local G,DP=FP.Gear,FP.DungeonPlan
M.class="SHAMAN";M.level=50;FP.cdb.gear.profile="healer";FP.cdb.gear.second="melee"
local function piece(loc,stats,extra)
 local row={status="equipped",name="Owned "..loc,equipLoc=loc,stats=stats,classID=4,subclassID=3,minLevel=40}
 for k,v in pairs(extra or {}) do row[k]=v end
 return row
end
local worn={
 [1]=piece("INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10}),
 [5]=piece("INVTYPE_CHEST",{ITEM_MOD_INTELLECT_SHORT=20}),
 [16]=piece("INVTYPE_WEAPONMAINHAND",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30,ITEM_MOD_INTELLECT_SHORT=5},{classID=2,subclassID=4}),
 [17]=piece("INVTYPE_SHIELD",{ITEM_MOD_INTELLECT_SHORT=5},{subclassID=6}),
}
local bags={loading=0,piece("INVTYPE_2HWEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=40,ITEM_MOD_STRENGTH_SHORT=10},{classID=2,subclassID=5})}
FP.API.GetRewardEquipment=function(slot) return worn[slot] or {status="empty",stats={}} end
FP.API.GetBagGear=function() return bags end
local function drop(id,loc,stats,source,extra)
 local row={id=id,name="Drop "..id,equipLoc=loc,classID=4,subclassID=3,subtype="Mail",level=50,minLevel=45,stats=stats,
  sources={source},sourceTypes={"Dungeon"},bosses={"Boss "..id}}
 for k,v in pairs(extra or {}) do row[k]=v end
 return row
end
local RING={subclassID=0,subtype="Miscellaneous"}
FP.GearCatalog={date="fixture",items={
 drop(101,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=30},"Zul'Farrak"),
 drop(102,"INVTYPE_2HWEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=45,ITEM_MOD_STRENGTH_SHORT=20},"Zul'Farrak",{classID=2,subclassID=5,subtype="Mace"}),
 drop(201,"INVTYPE_CHEST",{ITEM_MOD_INTELLECT_SHORT=25,ITEM_MOD_STRENGTH_SHORT=5},"Maraudon"),
 drop(202,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=8},"Maraudon",RING),
 drop(203,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=6},"Maraudon",RING),
 drop(204,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=2},"Maraudon",RING),
 drop(205,"INVTYPE_SHIELD",{ITEM_MOD_INTELLECT_SHORT=12},"Maraudon",{subclassID=6,subtype="Shield"}),
 drop(301,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=38},"Blackrock Depths",{minLevel=52}),
 drop(302,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=90},"Blackrock Depths",{minLevel=53}),
 drop(401,"INVTYPE_WAIST",{ITEM_MOD_INTELLECT_SHORT=1},"Scarlet Monastery",{minLevel=30}),
 drop(501,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=99},"Stratholme",{minLevel=50}),
 drop(601,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5},"Uldaman",{minLevel=40}),
 drop(701,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=80},"Zul'Farrak",{subclassID=4,subtype="Plate"}),
}}
local function fresh() DP.nextMemo,DP.sources=nil,nil end
local function rank() fresh();return DP:Next() end
local function names(rows) local out={};for i,r in ipairs(rows) do out[i]=r.name end;return table.concat(out," > ") end
local function plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) end
local function near(a,b) return math.abs(a-b)<0.01 end
'''


def cases(hub):
    return {
        'dungeon_next_ranks_by_what_the_drops_add_for_both_specs': NEXT + r'''
local rows,info=rank()
-- Healing: BRD head +28 (70%), Maraudon chest +5, two rings +14, shield +7 (65%), Zul'Farrak head +20 (50%)
-- melee:   Zul'Farrak two-hander +50 against the one in the bags (19.2%), Maraudon chest +10 (3.8%)
assert(names(rows)=="Blackrock Depths > Zul'Farrak > Maraudon > Scarlet Monastery", names(rows))
local brd,zf,mar,sm=rows[1],rows[2],rows[3],rows[4]
assert(near(zf.roles[1].gain,20) and near(zf.roles[1].pct,50) and near(zf.roles[2].gain,50) and near(zf.roles[2].pct,50/260*100) and near(zf.total,50+50/260*100))
assert(near(mar.roles[1].gain,26) and #mar.roles[1].items==4 and near(mar.roles[2].gain,10) and near(brd.roles[1].gain,28) and brd.roles[2].gain==0)
assert(zf.roles[1].name=="Healing" and zf.roles[2].name=="Strength melee" and zf.lo==44 and zf.hi==54 and zf.key=="zul-farrak" and zf.fits and zf.wings==1)
-- the third ring is not counted (two ring slots), the shield is weighed with the hand it joins, and
-- another class's plate, a drop three levels away and a weaker drop count for nothing
local got={};for _,c in ipairs(mar.roles[1].items) do got[c.item.id]=c.delta end
assert(got[201]==5 and got[202]==8 and got[203]==6 and got[205]==7 and got[204]==nil, snapshot(got))
assert(#zf.roles[1].items==1 and zf.roles[1].items[1].item.id==101 and #brd.roles[1].items==1 and brd.roles[1].items[1].later==52)
-- the second spec changes the order: without it Zul'Farrak's two-hander counts for nothing
FP.cdb.gear.second=false
local solo,soloInfo=rank()
assert(names(solo)=="Blackrock Depths > Maraudon > Zul'Farrak > Scarlet Monastery" and #solo[1].roles==1 and #soloInfo.roles==1, names(solo))
FP.cdb.gear.second="melee";rows,info=rank();zf,mar,brd,sm=rows[2],rows[3],rows[1],rows[4]
-- rows, summary and details say it in words
assert(DP:NextLabel(zf)=="2. Zul'Farrak · 44-54 · Healing +50% · Strength melee +19%", DP:NextLabel(zf))
assert(DP:NextLabel(brd)=="1. Blackrock Depths · 52-60 · Healing +70% · Strength melee nothing better", DP:NextLabel(brd))
for _,row in ipairs(rows) do assert(#DP:NextLabel(row)<=82, "the list cuts a row at 82 characters: "..DP:NextLabel(row)) end
local summary=plain(DP:NextSummary(rows,info))
assert(summary:find("Ranked for Healing and Strength melee (second spec): 4 dungeons with drops better than what you carry, most to gain first.",1,true), summary)
-- wings share a row; a dungeon the reference has no drops for is named, not ranked; too high is counted; no gain is not listed
assert(sm.wings==4 and sm.lo==30 and sm.hi==46 and not sm.fits and FP.DungeonCatalog.dungeons[sm.key].name:find("Scarlet Monastery",1,true))
assert(summary:find("No drops in the item reference, so not ranked: Alcaz Prison, The Sunken Temple.",1,true), summary)
assert(info.tooHigh==1 and summary:find("1 higher-level dungeon not listed yet.",1,true) and info.nothing==1)
local d=plain(DP:NextDetails(zf,info))
for _,part in ipairs({"Zul'Farrak  (44-54)","Healing: +50% from 1 slot (score +20.0 on 40)","  Head: Drop 101 (Boss 101) +20.0",
 "Strength melee: +19% from 1 slot (score +50.0 on 260)","  Two-hand: Drop 102 (Boss 102) +50.0","Gear in the bank is not seen."}) do
 assert(d:find(part,1,true),part.." missing in:\n"..d)
end
d=plain(DP:NextDetails(brd,info))
assert(d:find("  Head: Drop 301 (Boss 301) +28.0, at level 52",1,true) and d:find("Strength melee: nothing listed here beats what you carry.",1,true), d)
assert(plain(DP:NextDetails(sm,info)):find("4 wings; the reference does not say which wing a drop is in",1,true))
assert(DP:NextDetails(nil,info):find("Select a dungeon",1,true))
-- a quest of that dungeon in the log is shown, and breaks ties
M.AddQuest({questID=7028,title="Maraudon quest",objectives={}});FP.Recorder.RescanLog("next")
rows=DP:Next();assert(rows[3].name=="Maraudon" and rows[3].inLog==1 and DP:NextLabel(rows[3]):find("· 1 in your log",1,true), DP:NextLabel(rows[3]))
-- the receipt for the next data pull
local r=FP.db.dungeonNext
assert(r.rows==4 and r.first=="Blackrock Depths" and r.own=="healer" and r.second=="melee" and r.bagsRead==true and r.unread==0 and r.level==50 and r.version==FP.version)
-- new gear is seen: the two-hander moves from the bags to the bank and the melee gain is against the mace
bags={loading=0};M.FireEvent("BAG_UPDATE_DELAYED")
rows=DP:Next();local z;for _,row in ipairs(rows) do if row.name=="Zul'Farrak" then z=row end end
assert(near(z.roles[2].gain,310-180), z.roles[2].gain)
''',

        'gain_counts_each_slot_once_and_weighs_a_two_hander_against_a_pair': NEXT + r'''
local function slot(key) for _,s in ipairs(G.slots) do if s[1]==key then return s end end end
local function cand(id,loc,key,stats) return {item={id=id,name="C"..id,equipLoc=loc,stats=stats},slot=slot(key)} end
local function ring(id,int) return cand(id,"INVTYPE_FINGER","FINGER",{ITEM_MOD_INTELLECT_SHORT=int}) end
local function owned(t) t.slots=t.slots or {};t.unknown=t.unknown or {};t.hands=t.hands or 0;t.base=t.base or 100;return t end
local function deltas(out) local list={};for i,c in ipairs(out.items) do list[i]=c.item.id..":"..string.format("%.2f",c.delta) end;return table.concat(list," ") end
-- two ring slots: the best two of what is owned and what drops, each new ring against the piece it replaces
local out=G:Gain(owned{slots={FINGER={10,5}}},"healer",{ring(1,12),ring(2,11),ring(3,1)})
assert(out.gain==8 and deltas(out)=="1:7.00 2:1.00" and near(out.pct,8), deltas(out))
out=G:Gain(owned{slots={FINGER={10,5}}},"healer",{ring(1,8),ring(2,7)});assert(out.gain==3 and deltas(out)=="1:3.00")
out=G:Gain(owned{slots={FINGER={10}}},"healer",{ring(1,4),ring(2,3)});assert(out.gain==4 and deltas(out)=="1:4.00", "an empty second slot takes one ring, not two")
out=G:Gain(owned{slots={FINGER={10,9}}},"healer",{ring(1,9),ring(2,2)});assert(out.gain==0 and #out.items==0, "equal is not better")
-- one head slot: only the best drop counts
out=G:Gain(owned{slots={HEAD={10}}},"healer",{cand(1,"INVTYPE_HEAD","HEAD",{ITEM_MOD_INTELLECT_SHORT=14}),cand(2,"INVTYPE_HEAD","HEAD",{ITEM_MOD_INTELLECT_SHORT=30})})
assert(out.gain==20 and deltas(out)=="2:20.00")
-- hands, scored for melee by attack power: a two-hander owned (300) against a main hand and shield that drop
local MAIN=cand(1,"INVTYPE_WEAPONMAINHAND","MAIN",{ITEM_MOD_ATTACK_POWER_SHORT=200})
local OFF=cand(2,"INVTYPE_SHIELD","OFF",{ITEM_MOD_ATTACK_POWER_SHORT=150})
local function two(id,ap) return cand(id,"INVTYPE_2HWEAPON","MAIN",{ITEM_MOD_ATTACK_POWER_SHORT=ap}) end
out=G:Gain(owned{two=300,hands=300},"melee",{MAIN,OFF})
assert(out.gain==50 and deltas(out)=="1:28.57 2:21.43", deltas(out))
-- one half of a pair alone does not beat the two-hander
assert(G:Gain(owned{two=300,hands=300},"melee",{MAIN}).gain==0)
-- a better two-hander is taken when it beats the pair, and passed over when the pair is better
out=G:Gain(owned{two=300,hands=300},"melee",{MAIN,OFF,two(3,360)});assert(out.gain==60 and deltas(out)=="3:60.00")
out=G:Gain(owned{two=300,hands=300},"melee",{MAIN,OFF,two(3,320)});assert(out.gain==50 and #out.items==2)
assert(G:Gain(owned{two=300,hands=300},"melee",{two(3,280)}).gain==0)
-- a shield joins the main hand already owned; only the new piece is named
out=G:Gain(owned{main=100,off=20,hands=120},"melee",{OFF});assert(out.gain==130 and deltas(out)=="2:130.00")
-- and a main hand joins the shield already owned
out=G:Gain(owned{main=100,off=20,hands=120},"melee",{MAIN});assert(out.gain==100 and deltas(out)=="1:100.00", deltas(out))
-- a slot whose worn piece could not be read is left out and counted
out=G:Gain(owned{unknown={HEAD=true,HANDS=true}},"melee",{cand(1,"INVTYPE_HEAD","HEAD",{ITEM_MOD_ATTACK_POWER_SHORT=9}),MAIN,two(3,400)})
assert(out.gain==0 and out.skipped==3 and #out.items==0)
-- nothing owned to compare with: a score, no share
out=G:Gain(owned{base=0},"healer",{ring(1,5)});assert(out.gain==5 and out.pct==nil)
''',

        'owned_gear_is_worn_plus_wearable_bag_items_and_unread_slots_are_said': NEXT + r'''
local own=G:Owned("healer")
assert(own.slots.HEAD[1]==10 and own.slots.CHEST[1]==20 and own.main==5 and own.off==5 and own.two==nil and own.hands==10 and own.base==40 and own.bagsRead and own.unread==0)
own=G:Owned("melee");assert(own.two==260 and own.main==180 and own.hands==260 and own.base==260)
-- both ring slots belong to the set a gain is a share of
worn[11]=piece("INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=4},{subclassID=0});worn[12]=piece("INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=3},{subclassID=0})
own=G:Owned("healer");assert(own.base==47 and own.slots.FINGER[1]==4 and own.slots.FINGER[2]==3, own.base)
worn[11]=nil;worn[12]=nil
-- bags: a piece for a higher level or another class is carried, not owned; one without class data is taken as wearable
bags={loading=2,
 piece("INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=50},{minLevel=55}),
 piece("INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=40},{subclassID=4}),
 piece("INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=15}),
 piece("INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=12},{classID=false,subclassID=false}),
 piece("INVTYPE_NON_EQUIP_IGNORE",{ITEM_MOD_INTELLECT_SHORT=99},{classID=false,subclassID=false}),
}
own=G:Owned("healer")
assert(#own.slots.HEAD==3 and own.slots.HEAD[1]==15 and own.slots.HEAD[2]==12 and own.slots.HEAD[3]==10 and own.loading==2, snapshot(own.slots.HEAD))
-- the best of the two owned heads is the bar: Zul'Farrak's head now adds 15, not 20
local rows,info=rank()
local zf;for _,row in ipairs(rows) do if row.name=="Zul'Farrak" then zf=row end end
assert(near(zf.roles[1].gain,15) and plain(DP:NextSummary(rows,info)):find("2 bag items still loading.",1,true))
-- worn pieces the client has not given yet: their slots are left out, and it is said in red
worn[5]={status="loading",link="item:1"};worn[16]={status="unknown"}
own=G:Owned("healer");assert(own.unread==2 and own.unknown.CHEST and own.unknown.HANDS and not own.unknown.HEAD)
rows,info=rank()
assert(info.unread==2 and DP:NextSummary(rows,info):find(FP.RED.."2 worn pieces could not be read; their slots are left out.",1,true))
for _,row in ipairs(rows) do for _,result in ipairs(row.roles) do for _,c in ipairs(result.items) do
 assert(c.slot[1]~="CHEST" and not G:HandOf(c.item.equipLoc), c.item.name.." was ranked against an unread slot")
end end end
local mar;for _,row in ipairs(rows) do if row.name=="Maraudon" then mar=row end end
assert(mar.roles[1].skipped==2 and plain(DP:NextDetails(mar,info)):find("2 drops left out: the piece you wear in that slot could not be read.",1,true))
worn[5]=piece("INVTYPE_CHEST",{ITEM_MOD_INTELLECT_SHORT=20});worn[16]=nil
-- bags unreadable: compared with what is worn, and it is said
FP.API.GetBagGear=function() return nil end
rows,info=rank();assert(info.bags==false and plain(DP:NextSummary(rows,info)):find("Your bags could not be read: compared with what you wear only.",1,true))
assert(FP.db.dungeonNext.bagsRead==false)
-- in combat nothing is read and nothing is ranked
M.combatLockdown=true
rows,info=rank();assert(#rows==0 and info.note=="The ranking resumes after combat." and G:Owned("healer")==nil and DP:NextSummary(rows,info)==info.note)
M.combatLockdown=false
-- no gear data
local saved=FP.GearCatalog;FP.GearCatalog=nil;FP.API.EnsureGearCatalog=function() return false end
rows,info=rank();assert(#rows==0 and info.note:find("Gear data unavailable",1,true))
''',

        'second_spec_follows_the_browsed_role_until_a_click_sets_it': NEXT + hub + r'''
FP.cdb.gear.second=nil;FP.cdb.gear.browse=nil
assert(G:Second()==nil, "no second spec until one is browsed or chosen")
-- looking up another role on the gear page is taken as the second spec
FP.cdb.gear.browse="melee";local key,profile=G:Second();assert(key=="melee" and profile.name=="Strength melee")
FP.cdb.gear.browse="healer";assert(G:Second()==nil, "the own role is not a second spec")
FP.cdb.gear.browse="ranged";assert(G:Second()==nil, "nor is a role the class does not have")
-- a click cycles: none -> the class's other roles -> none, and the choice outlives browsing
FP.cdb.gear.browse=nil
assert(G:CycleSecond()=="melee" and FP.cdb.gear.second=="melee")
assert(G:CycleSecond()=="caster" and G:CycleSecond()==nil and FP.cdb.gear.second==false)
FP.cdb.gear.browse="melee";assert(G:Second()==nil, "none was chosen: browsing must not bring it back")
assert(G:CycleSecond()=="melee" and FP.cdb.gear.profile=="healer" and G:Profile()=="healer")
-- the Dungeons page: ranking on top, the button says and sets the second spec
page("dungeons")
local list=H.controls.dungeonNext
assert(#list.items==4 and H.controls.dungeonSecond:GetText()=="Second spec: Strength melee")
assert(H.controls.dungeonNextSummary:GetText():find("Strength melee",1,true))
local it=H.controls.hubDungeons
-- one dungeon is chosen on the page (v0.32.0): the ranking opens on the itinerary's dungeon
assert(list.selected==it.selected and it.selected~=nil)
selectRow("dungeonNext",2)
assert(H.controls.dungeonNextDetails:GetText():find("Drop 102",1,true), H.controls.dungeonNextDetails:GetText())
-- the click itself picks that dungeon in the itinerary list, on the page that shows it
assert(it.selected=="zul-farrak" and H:Selected(it) and H:Selected(it).key=="zul-farrak")
local shown;for _,b in ipairs(it.rows) do if b.item and b.item.key=="zul-farrak" then shown=true end end
assert(shown and H.controls.dungeonSummary:GetText():find("Zul'Farrak",1,true))
-- ...also when that dungeon sits on another page of the itinerary list
selectRow("dungeonNext",4)
local wing=list.items[4].key
shown=false;for _,b in ipairs(it.rows) do if b.item and b.item.key==wing then shown=true end end
assert(it.selected==wing and shown and H.controls.dungeonSummary:GetText():find("Scarlet Monastery",1,true), "the chosen dungeon is not on the page shown")
-- changing the second spec re-ranks; the dungeon chosen stays chosen in both lists
click("dungeonSecond");assert(H.controls.dungeonSecond:GetText()=="Second spec: Spell damage" and FP.cdb.gear.second=="caster" and list.selected==wing and it.selected==wing)
click("dungeonSecond");assert(H.controls.dungeonSecond:GetText()=="Second spec: none" and #list.items==4 and not list.items[1].roles[2])
assert(not H.controls.dungeonNextSummary:GetText():find("second spec",1,true))
assert(FP.cdb.gear.profile=="healer", "the ranking never changes the character's own role")
-- /hh dungeon next prints the same ranking
M.chat={};cmd("dungeon next")
local chat=table.concat(M.Chat(),"\n")
assert(chat:find("Ranked for",1,true) and chat:find("1. Blackrock Depths · 52-60 · Healing +70%",1,true) and chat:find("4. Scarlet Monastery",1,true), chat)
-- a class with one role has nothing to choose
M.class="MAGE";FP.cdb.gear.profile=nil;FP.cdb.gear.second=nil;H:Refresh()
assert(not H.controls.dungeonSecond:IsEnabled() and H.controls.dungeonSecond:GetText()=="Second spec: none" and G:CycleSecond()==nil)
''',

        'bag_gear_read_returns_equippable_items_and_counts_what_is_loading': r'''
local items={
 [9001]={name="Mail Helm",loc="INVTYPE_HEAD",class=4,sub=3,min=40,stats={ITEM_MOD_INTELLECT_SHORT=12}},
 [9002]={name="Silk Cloth",loc="",class=7,sub=5,min=0,stats={}},
 [9003]={name="Big Mace",loc="INVTYPE_2HWEAPON",class=2,sub=5,min=45,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=40}},
}
C_Item.GetItemInfo=function(link)
 local it=items[tonumber(tostring(link):match("item:(%d+)"))]
 if not it then return nil end
 return it.name,link,2,45,it.min,"type","subtype",1,it.loc,134400,100,it.class,it.sub
end
C_Item.GetItemStats=function(link) local it=items[tonumber(link:match("item:(%d+)"))];return it and it.stats end
M.EnableBags({[0]={{9001,1},{9002,20},{9004,1}},[1]={{9003,1}}})
local bag=FP.API.GetBagGear()
assert(#bag==2 and bag.loading==1, #bag.." "..bag.loading)
assert(bag[1].name=="Mail Helm" and bag[1].equipLoc=="INVTYPE_HEAD" and bag[1].classID==4 and bag[1].subclassID==3 and bag[1].minLevel==40 and bag[1].stats.ITEM_MOD_INTELLECT_SHORT==12)
assert(bag[2].equipLoc=="INVTYPE_2HWEAPON" and bag[2].classID==2 and bag[2].subclassID==5)
-- never in combat, and unreadable bags are "unavailable", not "empty"
M.combatLockdown=true;assert(FP.API.GetBagGear()==nil);M.combatLockdown=false
local slots=C_Container.GetContainerNumSlots
C_Container.GetContainerNumSlots=function() return M.Secret() end;assert(FP.API.GetBagGear()==nil)
C_Container.GetContainerNumSlots=function() error("restricted") end;assert(FP.API.GetBagGear()==nil)
C_Container.GetContainerNumSlots=nil;assert(FP.API.GetBagGear()==nil)
C_Container.GetContainerNumSlots=slots
C_Container.GetContainerItemInfo=function() error("restricted") end;assert(FP.API.GetBagGear()==nil)
''',
    }
