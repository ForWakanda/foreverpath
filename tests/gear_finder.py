"""Gear finder: browse a role without becoming it, two-hand / type / sort filters,
rows and details that say what an item is. Uses the shipped reference catalog. Mock-only."""

# A level-50 restoration shaman with a second spec: the reported case
# ("best two-hander for Windfury" while the gear role is Healing).
SHAMAN = r'''
local G=FP.Gear
M.class="SHAMAN";M.level=50;FP.cdb.gear.profile="healer"
assert(FP.API.EnsureGearCatalog())
local function find(rows,id) for i,r in ipairs(rows) do if r.key==id then return i,r end end end
local function byId(id) for _,item in ipairs(FP.GearCatalog.items) do if item.id==id then return item end end end
local JORDAN=873 -- Staff of Jordan: a caster staff, world drop
'''


def cases(hub):
    return {
        'gear_browsing_another_role_ranks_for_it_without_changing_the_characters_role': SHAMAN + r'''
-- what the player saw: healing role, level 60, world drops -> a caster staff at #6
local healing=G:Rows({slot="MAIN",level=60,source="Drop"})
assert(find(healing,JORDAN)==6, "reported case no longer reproduces: "..tostring(find(healing,JORDAN)))
-- the same list ranked for melee: the staff is nowhere near the top, a real two-hander leads
local melee=G:Rows({slot="MAIN",level=60,source="Drop",role="melee"})
assert(#melee==#healing and find(melee,JORDAN)>50)
assert(melee[1].item.equipLoc=="INVTYPE_2HWEAPON" and melee[1].item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT>byId(JORDAN).stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
-- browsing is a view: the role the Healing page and the dungeon drops follow is untouched
FP.cdb.gear.browse="melee"
local key,profile,keys,own=G:Browse();assert(key=="melee" and profile.name=="Strength melee" and own=="healer" and #keys==3)
assert(G:Profile()=="healer" and FP.Healer:IsHealer())
assert(G:Weights().heal==1 and G:Weights("melee").dps==6 and G:Weights("melee").heal==0)
-- a role the class does not have falls back to its own, for the view and for weights
FP.cdb.gear.browse="ranged";assert(G:Browse()=="healer" and G:Weights("ranged").heal==1)
assert(#G:Rows({slot="MAIN",level=60,role="ranged"})==#G:Rows({slot="MAIN",level=60}))
-- custom weights belong to the role they were saved for
FP.cdb.gear.weights.melee={dps=0,str=1};assert(G:Weights("melee").dps==0 and G:Weights("healer").heal==1)
''',

        'gear_two_hand_and_type_filters_narrow_the_main_hand_list': SHAMAN + r'''
local all,_,types=G:Rows({slot="MAIN",level=60,role="melee"})
local two=G:Rows({slot="MAIN",level=60,role="melee",hands="two"})
local one=G:Rows({slot="MAIN",level=60,role="melee",hands="one"})
assert(#two>20 and #one>20 and #two+#one==#all)
for _,r in ipairs(two) do assert(r.item.equipLoc=="INVTYPE_2HWEAPON",r.item.name) end
for _,r in ipairs(one) do assert(r.item.equipLoc~="INVTYPE_2HWEAPON",r.item.name) end
assert(#G:Rows({slot="MAIN",level=60,role="melee",hands="any"})==#all)
-- types on offer are the ones a shaman can use, and follow the hands filter
local function has(list,v) for _,x in ipairs(list) do if x==v then return true end end end
assert(has(types,"Axe") and has(types,"Mace") and has(types,"Staff") and has(types,"Dagger") and not has(types,"Sword") and not has(types,"Polearm"))
local _,_,twoTypes=G:Rows({slot="MAIN",level=60,role="melee",hands="two"})
assert(has(twoTypes,"Mace") and has(twoTypes,"Staff") and not has(twoTypes,"Dagger") and not has(twoTypes,"Fist Weapon"))
local maces,_,stillAll=G:Rows({slot="MAIN",level=60,role="melee",hands="two",subtype="Mace"})
assert(#maces>5 and #maces<#two and #stillAll==#twoTypes, "choosing a type must not shrink the choice of types")
for i,r in ipairs(maces) do assert(r.item.subtype=="Mace" and r.rank==i) end
-- the hands filter is a main-hand idea: it never empties another slot
assert(#G:Rows({slot="HEAD",level=60,hands="two"})==#G:Rows({slot="HEAD",level=60}) and #G:Rows({slot="HEAD",level=60})>0)
local none,why=G:Rows({slot="MAIN",level=60,hands="two",subtype="Dagger"});assert(#none==0 and why:find("hands",1,true))
''',

        'gear_weapon_sorts_order_by_dps_or_by_hit_size': SHAMAN + r'''
local f={slot="MAIN",level=60,role="melee",hands="two"}
local score=G:Rows(f)
for i=2,#score do assert(score[i-1].score>=score[i].score) end
f.sort="dps";local dps=G:Rows(f)
for i=2,#dps do assert(dps[i-1].item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT>=dps[i].item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) end
f.sort="hit";local hit=G:Rows(f)
for i=2,#hit do assert(G:HitSize(hit[i-1].item)>=G:HitSize(hit[i].item)) end
assert(#dps==#score and #hit==#score)
-- the three orders really differ on this list, and rank is the position in the order shown
assert(score[1].key~=hit[1].key or score[2].key~=hit[2].key or score[3].key~=hit[3].key)
assert(hit[1].rank==1 and G:HitSize(hit[1].item)==(hit[1].item.dmgMin+hit[1].item.dmgMax)/2)
-- an item without a damage range sorts last instead of failing
assert(G:HitSize({})==nil)
FP.GearCatalog={date="fixture",items={
 {id=1,name="No range",equipLoc="INVTYPE_2HWEAPON",classID=2,subclassID=5,subtype="Mace",level=20,minLevel=10,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=90},sources={"Drops"},sourceTypes={"Drop"},bosses={}},
 {id=2,name="Slow",equipLoc="INVTYPE_2HWEAPON",classID=2,subclassID=5,subtype="Mace",level=20,minLevel=10,dmgMin=10,dmgMax=30,speed=4,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=5},sources={"Drops"},sourceTypes={"Drop"},bosses={}}}}
local rows=G:Rows({slot="MAIN",level=60,role="melee",sort="hit"});assert(rows[1].key==2 and rows[2].key==1)
rows=G:Rows({slot="MAIN",level=60,role="melee",sort="dps"});assert(rows[1].key==1)
''',

        'gear_sources_offer_only_what_the_reference_has_and_name_world_drops': SHAMAN + r'''
local sources=G:Sources()
assert(table.concat(sources,",")=="All,Dungeon,Drop,Quest,Crafted,Vendor,PvP", table.concat(sources,","))
for _,kind in ipairs(sources) do if kind~="All" then assert(#G:Rows({slot="MAIN",level=60,source=kind})>0,kind) end end
assert(G:SourceLabel("Drop")=="World / raid drop" and G:SourceLabel("Dungeon")=="Dungeon" and G:SourceLabel("PvP")=="PvP")
-- a reference that gains raids offers them, in the page's order, with unknown kinds last
FP.GearCatalog={date="fixture",items={{id=1,sourceTypes={"Zeta","Raid","Drop"},sources={"a","b","c"}}}}
assert(table.concat(G:Sources(),",")=="All,Raid,Drop,Zeta")
FP.GearCatalog=nil;assert(table.concat(G:Sources(),",")=="All")
''',

        'gear_rows_and_details_say_what_the_item_is_and_where_it_drops': SHAMAN + r'''
local staff=byId(JORDAN)
assert(staff.quality==4 and staff.speed==3.7 and staff.dmgMin==88 and staff.dmgMax==133 and staff.bind=="equip" and staff.hit==1.5)
local row=G:RowText({item=staff,rank=6},G:Weights("healer"))
for _,part in ipairs({"6. Staff of Jordan","2H Staff","29.9 dps","speed 3.70","L35"," · Drop · ","+60 healing"}) do assert(row:find(part,1,true),part.." missing in: "..row) end
-- the second stat would not fit whole on this weapon row, so it is left off rather than cut
assert(not row:find("Int",1,true) and row:sub(-11)=="+60 healing")
-- an armour row has the room and lists the role's stats, biggest contribution first
local hat=G:RowText({item={name="Hat",classID=4,subtype="Mail",minLevel=40,stats={ITEM_MOD_INTELLECT_SHORT=9,ITEM_MOD_SPELL_HEALING_DONE_SHORT=30,ITEM_MOD_STAMINA_SHORT=10,ITEM_MOD_STRENGTH_SHORT=50},sourceTypes={"Quest"},sources={"Quest Rewards"}},rank=1},G:Weights("healer"))
assert(hat=="1. Hat · Mail · L40 · Quest · +30 healing, +9 Int, +10 Sta", hat)
-- a long name gives way before the facts do
local long=G:RowText({item={name="An Extraordinarily Long Weapon Name Of The Ages",classID=2,equipLoc="INVTYPE_2HWEAPON",subtype="Mace",minLevel=60,speed=3.8,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=80.3},sourceTypes={"Dungeon"},sources={"Lower Blackrock Spire Annex"}},rank=12},G:Weights("melee"))
assert(long=="12. An Extraordinarily Long Weapon Name… · 2H Mace · 80.3 dps · speed 3.80 · L60", long)
-- with a shorter name the source takes what room is left
long=G:RowText({item={name="Long Enough Weapon Name",classID=2,equipLoc="INVTYPE_WEAPONMAINHAND",subtype="Mace",minLevel=60,speed=3.8,stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=80.3},sourceTypes={"Dungeon"},sources={"Lower Blackrock Spire Annex"}},rank=12},G:Weights("melee"))
assert(long=="12. Long Enough Weapon Name · MH Mace · 80.3 dps · speed 3.80 · L60 · Lower Bla…", long)
assert(G:QualityColor(staff)==G.quality[4][2] and G:QualityColor({})==nil)
assert(G:Kind(byId(2015))=="2H Axe" and G:Kind({classID=4,subtype="Mail"})=="Mail" and G:Kind({classID=4,subtype=""})==nil)
-- a dungeon item is located by the dungeon, not by the word "Dungeon"
local dungeon;for _,item in ipairs(FP.GearCatalog.items) do if item.sourceTypes[1]=="Dungeon" and #item.sourceTypes==1 then dungeon=item;break end end
assert(G:Where(dungeon)==dungeon.sources[1] and G:Where(staff)=="Drop" and G:Where(byId(2015))=="Drop: Brain Eater")
-- the reference files raid bosses under the same "Drop": the row names the creature instead of claiming a world drop
local edge=byId(21134);assert(edge.droppedBy=="C'Thun" and G:Where(edge)=="Drop: C'Thun")
-- every row fits the list without the list cutting it, whatever the item
local U=FP.Util
for _,item in ipairs(FP.GearCatalog.items) do
 local text=G:RowText({item=item,rank=317},G:Weights("melee"))
 assert(U.Truncate("* "..text,82)=="* "..text, text)
 assert(not text:find("%+%d+…") and not text:find(", …",1,true), text)
end
-- no required level: the row says it is an item level, not a requirement
assert(G:RowText({item={name="Quest thing",classID=4,subtype="Mail",level=44,stats={},sourceTypes={"Quest"},sources={"Quest Rewards"}},rank=1},G:Weights()):find("ilvl 44",1,true))
FP.API.GetRewardItem=function() return nil end
FP.API.GetRewardEquipment=function(slot)
 if slot==16 then return {status="equipped",name="Old mace",stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=20}} end
 if slot==17 then return {status="equipped",name="Old shield",stats={ITEM_MOD_STRENGTH_SHORT=5}} end
 return {status="unknown"}
end
local d=G:Details({item=staff,score=179.2,rank=3},"MAIN","melee")
for _,part in ipairs({"2H Staff · 88 - 133 damage · speed 3.70 · 29.9 dps","Requires level 35 · item level 40 · epic · binds when equipped",
 "+20 Intellect","Not in the score: +1.5% hit","Where: Drop with no dungeon listed (world, rare creature or raid)","Score for Strength melee: 179.2 · #3 in this list","not loaded this item yet",
 "Equipped Main hand: Old mace · 120.0","Equipped Off hand: Old shield · 10.0","Against the pair you wear: +49.2 (reference stats)"}) do
 assert(d:find(part,1,true),part.." missing in:\n"..d)
end
-- a listed creature and its drop chance are shown where the reference has them
local axe=G:Details({item=byId(2015),score=1,rank=1},"MAIN","melee")
assert(axe:find("Dropped by: Brain Eater (0.89% listed drop chance)",1,true) and axe:find("uncommon",1,true))
-- an unreadable hand gives no number rather than a wrong one
FP.API.GetRewardEquipment=function(slot) return {status="unknown"} end
d=G:Details({item=staff,score=179.2,rank=3},"MAIN","melee")
assert(not d:find("Against the pair",1,true) and d:find("the off hand goes empty",1,true))
-- the client disagreeing with the reference is said in numbers
FP.API.GetRewardItem=function() return {stats={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=29.86,ITEM_MOD_INTELLECT_SHORT=25,ITEM_MOD_SPIRIT_SHORT=10,ITEM_MOD_SPELL_POWER_SHORT=60}} end
d=G:Details({item=staff,score=87,rank=1},"MAIN","healer")
assert(d:find("Intellect 20 -> 25",1,true) and d:find("Current-client score: 92.0",1,true) and d:find("Score for Healing",1,true))
FP.API.GetRewardItem=function() return {stats=staff.stats} end
assert(G:Details({item=staff,score=87,rank=1},"MAIN","healer"):find("Reference stats match your client.",1,true))
''',

        'gear_other_factions_reputation_and_rank_items_are_left_out': SHAMAN + r'''
assert(FP.API.GetCharInfo().faction=="Horde")
local f={slot="MAIN",level=60,role="melee",hands="two"}
local rows,_,types,hidden=G:Rows(f)
assert(hidden>5)
for _,r in ipairs(rows) do assert(G:Side(r.item)~="Alliance",r.item.name) end
assert(find(rows,18831) and not find(rows,18830), "High Warlord's Battle Axe stays, Grand Marshal's Sunderer goes")
f.otherFaction=true
local all,_,_,none=G:Rows(f);assert(#all==#rows+hidden and none==0 and find(all,18830))
-- the count follows the type filter, like the rows do
f.otherFaction=nil;f.subtype="Axe";local axes,_,_,hiddenAxes=G:Rows(f)
f.otherFaction=true;assert(#G:Rows(f)==#axes+hiddenAxes and hiddenAxes>0 and hiddenAxes<hidden)
-- an Alliance character gets the mirror image; a character whose side is unreadable loses nothing
local real=FP.API.GetCharInfo
FP.API.GetCharInfo=function() local c=real();c.faction="Alliance";return c end
local theirs=G:Rows({slot="MAIN",level=60,role="melee",hands="two"});assert(find(theirs,18830) and not find(theirs,18831))
for _,r in ipairs(theirs) do assert(G:Side(r.item)~="Horde",r.item.name) end
FP.API.GetCharInfo=function() local c=real();c.faction=nil;return c end
local unknown,_,_,left=G:Rows({slot="MAIN",level=60,role="melee",hands="two"});assert(#unknown==#all and left==0)
FP.API.GetCharInfo=real
-- how a side is told: one reputation, never two; a rank title only on a vendor or honor item
assert(G:Side({requires={"Darkspear Raiders - Revered"},sourceTypes={"Vendor"}})=="Horde")
assert(G:Side({requires={"The League of Arathor - Exalted"},sourceTypes={"Vendor"}})=="Alliance")
assert(G:Side({requires={"Silverwing Sentinels - Exalted","Warsong Outriders - Exalted"},sourceTypes={"Vendor"}})==nil)
assert(G:Side({requires={"Engineering (250)"},sourceTypes={"Crafted"}})==nil and G:Side({requires={"Everlook - Friendly"},sourceTypes={"Vendor"}})==nil)
assert(G:Side({name="Knight's Colors",sourceTypes={"Drop"}})==nil and G:Side({name="Knight's Colors",sourceTypes={"Vendor"}})=="Alliance")
assert(G:Side({name="Sergeant's Cape",sourceTypes={"PvP"}})==nil and G:Side({name="Warlord's Axe",sourceTypes={"PvP"}})=="Horde" and G:Side({sourceTypes={}})==nil)
-- the reference's own both-sides items are never hidden from either side
local both=0
for _,item in ipairs(FP.GearCatalog.items) do if item.requires and #item.requires>1 and item.requires[1]:find("Silverwing",1,true) then both=both+1;assert(G:Side(item)==nil,item.name) end end
assert(both>0)
-- the item says what it asks for and whose it is
FP.API.GetRewardItem=function() return nil end;FP.API.GetRewardEquipment=function() return {status="unknown"} end
local d=G:Details({item=byId(18830),score=1,rank=1},"MAIN","melee");assert(d:find("Alliance item: not obtainable on a Horde character.",1,true))
d=G:Details({item=byId(272080),score=1,rank=1},"MAIN","melee");assert(d:find("Requires: Darkspear Raiders - Revered",1,true) and d:find("Horde item.",1,true))
''',

        'gear_catalog_weapon_facts_are_complete_and_consistent': SHAMAN + r'''
local weapons,dropped=0,0
for _,item in ipairs(FP.GearCatalog.items) do
 assert(item.quality and item.quality>=0 and item.quality<=6 and G.quality[item.quality],item.name)
 assert(item.bind==nil or item.bind=="pickup" or item.bind=="equip")
 if item.classID==2 then
  weapons=weapons+1
  assert(item.speed and item.speed>0 and item.dmgMin and item.dmgMax and item.dmgMax>=item.dmgMin,item.name)
  local dps=item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  assert(dps and math.abs((item.dmgMin+item.dmgMax)/2/item.speed-dps)<0.6,item.name)
 else assert(item.speed==nil and item.dmgMin==nil,item.name) end
 if item.droppedBy then dropped=dropped+1;assert(item.droppedBy~="" and (item.dropChance==nil or (item.dropChance>0 and item.dropChance<=100))) end
 assert(item.crit==nil or (item.crit>0 and item.crit<=10));assert(item.hit==nil or (item.hit>0 and item.hit<=10))
end
assert(weapons>1300 and dropped>900)
''',

        'gear_page_finds_two_handers_for_a_second_spec': hub + SHAMAN + r'''
local P=FP.GearPanel
local before=snapshot(FP.Waypoints.list)
page("gear")
local list=H.controls.gearItems
assert(H.controls.gearProfile:GetText()=="Ranked for: Healing" and H.controls.gearMyRole:GetText()=="My role: Healing" and not H.controls.gearMyRole:IsEnabled())
-- armour slot: the weapon controls say so by being unavailable
assert(not H.controls.gearHands:IsEnabled() and not H.controls.gearSort:IsEnabled())
click("gearSlotMAIN");field("gearLevel",60);H.controls.gearLevel:GetScript("OnTextChanged")()
assert(H.controls.gearHands:IsEnabled() and H.controls.gearSort:IsEnabled() and H.controls.gearType:IsEnabled())
-- "Ranked for" walks the shaman's roles and never changes the character's own
click("gearProfile");assert(H.controls.gearProfile:GetText()=="Ranked for: Strength melee" and FP.cdb.gear.browse=="melee")
assert(FP.cdb.gear.profile=="healer" and FP.Healer:IsHealer())
assert(H.controls.gearMyRole:IsEnabled() and H.controls.gearMyRole:GetText()=="Make Strength melee my role")
assert(P.note:GetText():find("Your own role is",1,true) and P.note:GetText():find("Healing",1,true))
local any=#list.items
click("gearHands");assert(H.controls.gearHands:GetText()=="Hands: Two-hand" and #list.items<any and #list.items>20)
for _,r in ipairs(list.items) do assert(r.item.equipLoc=="INVTYPE_2HWEAPON") end
-- the line above the list states the whole filter, and the rows carry the facts
local status=P.status:GetText()
for _,part in ipairs({#list.items.." items","Main hand","two-hand only","up to level 60","any source","Strength melee","best score first"}) do assert(status:find(part,1,true),part.." missing in: "..status) end
local first=list.rows[1]:GetText()
assert(first:find("> 1. ",1,true) and first:find("2H ",1,true) and first:find(" dps",1,true) and first:find("speed ",1,true), first)
local second=list.rows[2]:GetText();assert(second:sub(1,4)=="|cff" and second:find("2. ",1,true), second)
assert(P.details:GetText():find("Score for Strength melee",1,true) and P.details:GetText():find(" damage · speed ",1,true))
-- type walks the types on offer and back to Any; sort relabels and reorders
click("gearType");local picked=P.filter.subtype;assert(picked and H.controls.gearType:GetText()=="Type: "..picked)
for _,r in ipairs(list.items) do assert(r.item.subtype==picked) end
assert(P.status:GetText():find(picked,1,true))
for _=1,#P.types do click("gearType") end;assert(P.filter.subtype==nil and H.controls.gearType:GetText()=="Type: Any")
click("gearSort");assert(H.controls.gearSort:GetText()=="Sort: Weapon DPS" and P.status:GetText():find("highest weapon DPS first",1,true))
click("gearSort");assert(H.controls.gearSort:GetText()=="Sort: Biggest hits")
for i=2,#list.items do assert(G:HitSize(list.items[i-1].item)>=G:HitSize(list.items[i].item)) end
-- source names: world drops are called that, and no choice is empty
click("gearSource");click("gearSource");assert(H.controls.gearSource:GetText()=="Source: World / raid drop" and #list.items>0 and P.status:GetText():find("world / raid drop",1,true))
for _=1,#G:Sources()-2 do click("gearSource");assert(#list.items>0 or P.filter.source~="All") end
assert(H.controls.gearSource:GetText()=="Source: Any")
-- weights edited here are the browsed role's
click("gearWeights");assert(P.weightProfile=="melee" and P.weightTitle:GetText():find("Strength melee",1,true) and P.weightFields.dps:GetText()=="6")
P.weightFields.dps:SetText("9");P.weightApply:GetScript("OnClick")();assert(FP.cdb.gear.weights.melee.dps==9 and FP.cdb.gear.weights.healer==nil)
-- the other side's honor weapons are left out, said so, and one tick away
local shown=#list.items;assert(P.hidden>0 and P.status:GetText():find(P.hidden.." of the other faction's left out",1,true))
for _,r in ipairs(list.items) do assert(not r.item.name:find("^Grand Marshal's"),r.item.name) end
local left=P.hidden;check("gearOtherFaction",true);assert(#list.items==shown+left and P.hidden==0 and not P.status:GetText():find("left out",1,true))
check("gearOtherFaction",false);assert(#list.items==shown and P.filter.otherFaction==nil)
-- another slot drops the weapon-only choices instead of silently keeping them
click("gearSlotHEAD");assert(P.filter.hands==nil and P.filter.sort==nil and P.filter.subtype==nil and H.controls.gearHands:GetText()=="Hands: Any" and #list.items>0)
-- only this button changes the character's role
click("gearMyRole");assert(FP.cdb.gear.profile=="melee" and not FP.Healer:IsHealer() and H.controls.gearMyRole:GetText()=="My role: Strength melee" and not H.controls.gearMyRole:IsEnabled())
assert(snapshot(FP.Waypoints.list)==before and #FP.db.errors==0)
''',

        'gear_page_role_button_is_idle_for_a_single_role_class': hub + r'''
M.class="MAGE";M.level=30
page("gear")
assert(not H.controls.gearProfile:IsEnabled() and H.controls.gearProfile:GetText()=="Ranked for: Spell damage")
assert(not H.controls.gearMyRole:IsEnabled() and not FP.GearPanel.note:GetText():find("Your own role",1,true))
assert(#H.controls.gearItems.items>0 and #FP.db.errors==0)
''',
    }
