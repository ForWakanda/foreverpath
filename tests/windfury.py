"""Windfury burst: an estimate of one Windfury Weapon proc for ranking a shaman's main-hand
weapons. Formula, where its numbers come from, where the sort is offered. Mock-only."""

WF = r'''
local G=FP.Gear
M.class="SHAMAN";M.level=52;FP.cdb.gear.profile="healer";FP.cdb.gear.browse="melee"
M.known={};C_SpellBook={IsSpellKnown=function(id) return M.known[id] or false end}
local DESC={}
C_Spell.GetSpellDescription=function(id) return DESC[id] or "" end
local function weapon(id,loc,lo,hi,speed,stats,extra)
 stats=stats or {};stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT=(lo+hi)/2/speed
 local row={id=id,name="Weapon "..id,equipLoc=loc,classID=2,subclassID=5,subtype="Mace",level=50,minLevel=45,dmgMin=lo,dmgMax=hi,speed=speed,
  stats=stats,sources={"Drops"},sourceTypes={"Drop"},bosses={},quality=3}
 for k,v in pairs(extra or {}) do row[k]=v end
 return row
end
-- the same 50 dps three ways, a harder-hitting slow one, and a one-hander
local FAST=weapon(1,"INVTYPE_2HWEAPON",90,110,2.0)
local SLOW=weapon(2,"INVTYPE_2HWEAPON",171,209,3.8)
local STRONG=weapon(3,"INVTYPE_2HWEAPON",171,209,3.8,{ITEM_MOD_STRENGTH_SHORT=20,ITEM_MOD_ATTACK_POWER_SHORT=14})
local SHARP=weapon(4,"INVTYPE_2HWEAPON",171,209,3.8,nil,{crit=1,hit=1})
local ONE=weapon(5,"INVTYPE_WEAPON",60,80,2.8,nil,{subclassID=4})
local CLOTH={id=6,name="Hat",equipLoc="INVTYPE_HEAD",classID=4,subclassID=1,subtype="Cloth",level=50,minLevel=45,stats={},sources={"Drops"},sourceTypes={"Drop"},bosses={}}
FP.GearCatalog={date="fixture",items={FAST,SLOW,STRONG,SHARP,ONE,CLOTH}}
FP.API.GetRewardItem=function() return nil end
local worn={}
FP.API.GetRewardEquipment=function(slot) return worn[slot] or {status="empty",stats={}} end
local function fresh() G.wfMemo=nil end
local function near(a,b) return math.abs(a-b)<0.01 end
local function ids(rows) local out={};for i,r in ipairs(rows) do out[i]=r.key end;return table.concat(out," ") end
'''


def cases(hub):
    return {
        'windfury_burst_follows_its_formula_and_puts_slow_hard_hitters_first': WF + r'''
-- no attack power from the client, no tooltip: level x 10 and the Classic bonus for the level's rank (50 -> rank 3)
local ctx=G:WindfuryContext()
assert(ctx.ap==520 and ctx.apTwoHand==520 and ctx.bonus==249 and ctx.rank==3 and ctx.extra==2)
assert(ctx.apSource:find("assumed from your level",1,true) and ctx.bonusSource:find("Classic value",1,true) and ctx.rankSource=="the rank for your level")
-- one proc = the swing and two extra attacks: 3 x average + speed x (3 x AP + 2 x bonus) / 14
local fast,slow=G:Windfury(FAST,ctx),G:Windfury(SLOW,ctx)
assert(near(fast,3*100+2.0*(3*520+2*249)/14) and near(slow,3*190+3.8*(3*520+2*249)/14), fast.." "..slow)
assert(slow>fast*1.8, "same DPS: the slow weapon must hit far harder")
-- the weapon's own Strength (2 attack power each) and attack power count
local strong,parts=G:Windfury(STRONG,ctx)
assert(parts.own==54 and near(strong,3*190+3.8*(3*(520+54)+2*249)/14))
-- its own crit and hit are an expected-value factor
local sharp,sp=G:Windfury(SHARP,ctx)
assert(near(sp.chance,1.02) and near(sharp,slow*1.02))
-- nothing to estimate without damage or speed, or for armor
assert(G:Windfury({classID=2,stats={},speed=3},ctx)==nil and G:Windfury({classID=2,stats={},dmgMin=1,dmgMax=2},ctx)==nil and G:Windfury(CLOTH,ctx)==nil)
assert(G:Windfury({classID=2,stats={},dmgMin=1,dmgMax=2,speed=0},ctx)==nil)
assert(G:Windfury({classID=4,stats={},dmgMin=1,dmgMax=2,speed=2},ctx)==nil, "only weapons swing")
-- sorted by it: stats first, then crit/hit, then the plain slow one. The fast two-hander is last:
-- even a one-hander with a longer swing lands a bigger burst (621.6 against 594)
local rows=G:Rows({slot="MAIN",level=60,role="melee",sort="wf"})
assert(ids(rows)=="3 4 2 5 1", ids(rows))
assert(near(G:Windfury(ONE,ctx),621.6) and near(fast,594))
assert(near(rows[1].wf,strong) and rows[1].rank==1)
-- ...which is not the DPS order (all the two-handers tie there) nor a role-score order
assert(ids(G:Rows({slot="MAIN",level=60,role="melee",sort="dps"}))~="3 4 2 5 1")
-- the row says the number; rows from another sort do not carry one
local text=G:RowText(rows[1],G:Weights("melee"))
assert(text:find("WF "..math.floor(strong+.5),1,true) and text:find("speed 3.80",1,true), text)
assert(not G:RowText(G:Rows({slot="MAIN",level=60,role="melee"})[1],G:Weights("melee")):find("WF ",1,true))
-- the hands filter composes with it
assert(ids(G:Rows({slot="MAIN",level=60,role="melee",sort="wf",hands="two"}))=="3 4 2 1")
''',

        'windfury_numbers_come_from_the_client_when_it_gives_them': WF + r'''
-- attack power from the client: base + buffs + debuffs, less what the worn weapons give
UnitAttackPower=function(unit) assert(unit=="player");return 600,40,-10 end
worn[16]={status="equipped",name="Old mace",stats={ITEM_MOD_STRENGTH_SHORT=10,ITEM_MOD_ATTACK_POWER_SHORT=6}}
worn[17]={status="equipped",name="Old shield",stats={ITEM_MOD_STRENGTH_SHORT=5}}
assert(FP.API.GetAttackPower()==630)
local ctx=G:WindfuryContext()
assert(ctx.ap==604 and ctx.apTwoHand==594 and ctx.apSource=="yours, without the weapons you wear", ctx.ap.." "..ctx.apTwoHand)
-- a two-hander replaces both hands, a one-hander only the main hand
local _,two=G:Windfury(SLOW,ctx);local _,one=G:Windfury(ONE,ctx)
assert(two.ap==594 and one.ap==604)
-- a worn weapon still loading: the number is used and the caveat is said
worn[16]={status="loading"};fresh();ctx=G:WindfuryContext()
assert(ctx.ap==630 and ctx.apSource:find("counted twice",1,true))
worn[16]=nil;worn[17]=nil
-- hidden in combat, hidden as a secret, or not a number: assumed, never zero
M.combatLockdown=true;fresh();assert(FP.API.GetAttackPower()==nil and G:WindfuryContext().ap==520);M.combatLockdown=false
UnitAttackPower=function() return M.Secret(),0,0 end;fresh();assert(FP.API.GetAttackPower()==nil and G:WindfuryContext().apSource:find("assumed",1,true))
UnitAttackPower=function() error("restricted") end;fresh();assert(G:WindfuryContext().ap==520)
UnitAttackPower=function() return 250000,0,0 end;fresh();assert(G:WindfuryContext().ap==520)
UnitAttackPower=nil;fresh();assert(G:WindfuryContext().ap==520)
-- the bonus: the highest rank the character knows, read from that rank's own tooltip
DESC[10486]="Imbue the Shaman's weapon with wind. Each hit has a 20% chance of dealing additional damage equal to two extra attacks with 315 extra attack power. Lasts 5 minutes."
DESC[8235]="...two extra attacks with 1,119 extra attack power."
M.known[8232]=true;M.known[8235]=true;fresh();ctx=G:WindfuryContext()
assert(ctx.rank==2 and ctx.bonus==1119 and ctx.rankSource=="the rank you know" and ctx.bonusSource:find("your client's Windfury Weapon tooltip",1,true))
M.known[10486]=true;fresh();ctx=G:WindfuryContext();assert(ctx.rank==3 and ctx.bonus==315)
-- a tooltip that does not say it, or says nonsense: the Classic value, and it is called that
DESC[10486]="Imbue the Shaman's weapon with wind.";fresh();ctx=G:WindfuryContext()
assert(ctx.bonus==249 and ctx.bonusSource:find("Classic value",1,true))
DESC[10486]="two extra attacks with 0 extra attack power";fresh();assert(G:WindfuryContext().bonus==249)
-- nothing known (lookup unavailable or untrained): the rank for the level, each rank at its own level
M.known={}
for level,rank in pairs({[20]=1,[30]=1,[39]=1,[40]=2,[50]=3,[59]=3,[60]=4}) do
 M.level=level;fresh();ctx=G:WindfuryContext()
 assert(ctx.rank==rank and ctx.rankSource=="the rank for your level", level.." -> "..ctx.rank)
end
M.level=60;fresh();assert(G:WindfuryContext().bonus==333)
-- the receipt for the next data pull says what could be read
M.level=52;UnitAttackPower=function() return 700,0,0 end;fresh();G:WindfuryContext()
local r=FP.db.windfury
assert(r.apRead==true and r.ap==700 and r.rank==3 and r.bonus==249 and r.version==FP.version and r.bonusSource:find("Classic",1,true))
UnitAttackPower=nil;fresh();G:WindfuryContext();assert(FP.db.windfury.apRead==false)
''',

        'windfury_sort_is_only_offered_to_a_shaman_browsing_melee_main_hand': WF + hub + r'''
local function has(list,v) for _,x in ipairs(list) do if x==v then return true end end end
assert(has(G:Sorts("MAIN","melee"),"wf") and #G:Sorts("MAIN","melee")==4)
assert(not has(G:Sorts("MAIN","healer"),"wf") and not has(G:Sorts("OFF","melee"),"wf") and not has(G:Sorts("HEAD","melee"),"wf"))
assert(not has(G.sorts,"wf"), "the shared list must stay free of it")
-- asked for where it means nothing, the list falls back to the role score and carries no burst
local healer=G:Rows({slot="MAIN",level=60,role="healer",sort="wf"})
assert(ids(healer)==ids(G:Rows({slot="MAIN",level=60,role="healer"})) and healer[1].wf==nil)
-- another class never gets it, whatever it asks for
M.class="WARRIOR";FP.cdb.gear.profile="melee"
assert(not has(G:Sorts("MAIN","melee"),"wf"))
local warrior=G:Rows({slot="MAIN",level=60,role="melee",sort="wf"})
assert(#warrior>0 and warrior[1].wf==nil and ids(warrior)==ids(G:Rows({slot="MAIN",level=60,role="melee"})))
M.class="SHAMAN";FP.cdb.gear.profile="healer"
-- the page: the preset is one click, changes the view and never the character's role
page("gear")
local P=FP.GearPanel
assert(H.controls.gearWindfury, "a shaman gets the Windfury button")
FP.cdb.gear.browse=nil;P.filter.slot="HEAD";P.wishlist=true
click("gearWindfury")
assert(FP.cdb.gear.browse=="melee" and FP.cdb.gear.profile=="healer" and G:Profile()=="healer")
assert(P.filter.slot=="MAIN" and P.filter.hands=="two" and P.filter.sort=="wf" and P.filter.source=="All" and not P.wishlist)
assert(ids(P.rows)=="3 4 2 1" and H.controls.gearSort:GetText()=="Sort: Windfury burst", ids(P.rows))
assert(P.status:GetText():find("biggest Windfury burst first",1,true) and P.status:GetText():find("two-hand only",1,true), P.status:GetText())
-- the details explain the number and where its parts came from
local d=P.details:GetText()
for _,part in ipairs({"Windfury burst (estimate): 1173. One proc lands the swing and 2 extra attacks at once:",
 "3 x 190 average damage + speed 3.80 x (3 x 574 attack power + 2 x 249 Windfury bonus) / 14",
 "Attack power 520: assumed from your level, because your client did not give yours; plus 54 from this weapon.",
 "Windfury bonus 249 (rank 3, the rank for your level): the Classic value, not read from your client.",
 "Damage over time follows weapon DPS"}) do
 assert(d:find(part,1,true),part.." missing in:\n"..d)
end
-- the Sort button cycles through it and back
click("gearSort");assert(P:Sort()=="score");click("gearSort");click("gearSort");click("gearSort");assert(P:Sort()=="wf")
-- switching what the page is ranked for drops the sort without an error, and the details lose the estimate
click("gearProfile")
assert(FP.cdb.gear.browse~="melee" and P:Sort()=="score" and H.controls.gearSort:GetText()=="Sort: Best score")
assert(not P.details:GetText():find("Windfury burst",1,true) and not P.status:GetText():find("Windfury",1,true))
-- another slot never shows it either
FP.cdb.gear.browse="melee";P.filter.sort="wf";P.filter.slot="OFF";H:Refresh()
assert(P:Sort()=="score")
''',

        'windfury_button_is_not_built_for_other_classes': WF + hub + r'''
M.class="WARRIOR";FP.cdb.gear.profile="melee";FP.cdb.gear.browse=nil
page("gear")
assert(H.controls.gearWindfury==nil and H.controls.gearSort and #FP.GearPanel.rows>=0)
FP.GearPanel.filter.slot="MAIN";FP.GearPanel.filter.sort="wf";H:Refresh()
assert(FP.GearPanel:Sort()=="score" and not FP.GearPanel.details:GetText():find("Windfury",1,true))
''',
    }
