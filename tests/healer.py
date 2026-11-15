"""Healer tools: heal rank table and the between-pull party check. Mock-only."""

# A level-50 restoration shaman's spellbook as the client would describe it.
HEAL = r'''
local HL=FP.Healer
M.class="SHAMAN";FP.cdb.gear.profile="healer"
local SP={
 [331]={n="Healing Wave",r=1,cost=25,cast=1500,d="Heals a friendly target for 34 to 44."},
 [332]={n="Healing Wave",r=2,cost=30,cast=2000,d="Heals a friendly target for 64 to 78."},
 [547]={n="Some Other Spell",r=3,cost=80,cast=2500,d="Heals a friendly target for 129 to 155."},
 [10395]={n="Healing Wave",r=8,cost=340,cast=3000,d="Heals a friendly target for 1,017 to 1,167."},
 [8004]={n="Lesser Healing Wave",r=1,cost=105,cast=1500,d="Heals a friendly target for 162 to 186."},
 [10466]={n="Lesser Healing Wave",r=4,cost=265,cast=1500,d="Heals a friendly target for 458 to 514."},
 [1064]={n="Chain Heal",r=1,cost=260,cast=2500,d="Heals the friendly target for 320 to 368, then jumps to heal additional nearby targets. Heals 3 total targets."},
}
M.known={[331]=true,[10395]=true,[10466]=true,[1064]=true}
M.bonus=350;M.range={};M.rangeCalls=0
C_Spell.GetSpellName=function(id) return SP[id] and SP[id].n end
C_Spell.GetSpellSubtext=function(id) return SP[id] and ("Rank "..SP[id].r) end
C_Spell.GetSpellInfo=function(id) local s=SP[id]; return s and {name=s.n,castTime=s.cast,spellID=id} end
C_Spell.GetSpellPowerCost=function(id) local s=SP[id]; return s and {{type=0,cost=s.cost,minCost=s.cost},{type=3,cost=999}} end
C_Spell.GetSpellDescription=function(id) return SP[id] and SP[id].d or "" end
C_Spell.IsSpellInRange=function(id,unit) M.rangeCalls=M.rangeCalls+1; assert(id==10395, "heal range is the top known rank of the main heal"); return M.range[unit] end
C_SpellBook={IsSpellKnown=function(id) return M.known[id] or false end}
GetSpellBonusHealing=function() return M.bonus end
IsInRaid=function() return M.raid or false end
UnitIsConnected=function(unit) local u=M.units[unit]; return u~=nil and u.offline~=true end
UnitIsVisible=function(unit) local u=M.units[unit]; return u~=nil and u.hidden~=true end
UnitAffectingCombat=function(unit) local u=M.units[unit]; return u and u.fighting or false end
local function member(i,name,info)
 info=info or {};info.name=name;info.player=true
 M.SetUnit("party"..i,info);M.range["party"..i]=info.far~=true
end
local function fresh() HL.memo,HL.range,HL.noted=nil,nil,nil end
local function has(rows,text) for _,r in ipairs(rows) do if tostring(r.text or r):find(text,1,true) then return true end end return false end
local function hud() local out={}; for _,r in ipairs(FP.PvP:Collect()) do out[#out+1]=r end return out end
'''


def cases(hub):
    return {
        'healer_rank_table_reads_the_tooltips_and_ranks_by_healing_per_mana': HEAL + r'''
local rows,bonus=HL:Rows(false)
assert(bonus==350 and #rows==4, "the four ranks this character knows: "..#rows)
local by={};for _,r in ipairs(rows) do by[r.id]=r end
local hw=by[10395]
assert(hw.rank==8 and hw.cost==340 and hw.cast==3 and hw.heal==1092, "mana, cast and the tooltip amount, with the thousands comma read")
assert(math.abs(hw.est-(1092+350*3/3.5))<.01 and math.abs(hw.perMana-hw.est/340)<1e-9 and math.abs(hw.perSecond-hw.est/3)<1e-9)
-- a rank learned before level 20 uses less of the bonus; a short cast uses less still
assert(math.abs(by[331].coeff-(1.5/3.5)*(1-19*.0375))<1e-9 and math.abs(by[10466].coeff-1.5/3.5)<1e-9)
assert(math.abs(by[1064].est-(344+350*2.5/3.5))<.01, "chain heal: the first target")
local best=0;for _,r in ipairs(rows) do if r.best then best=best+1;assert(r.id==10395) end end;assert(best==1)
assert(HL:RowLabel(hw):find("HW r8 · 340 mana · 3.0s · heals 1092 (est. 1392)",1,true) and HL:RowLabel(hw):find("per mana *",1,true), HL:RowLabel(hw))
assert(HL:RowDetails(hw):find("With your bonus healing: about 1392 (uses 86% of it)",1,true), HL:RowDetails(hw))
assert(HL:Macro(hw)=="/cast [@mouseover,help,nodead][help,nodead][@player] Healing Wave(Rank 8)" and HL:Macro(nil)=="")
-- every rank: the unlearned one is marked, and an id the client names differently is dropped, not mislabelled
fresh();rows=HL:Rows(true);by={};for _,r in ipairs(rows) do by[r.id]=r end
assert(#rows==6 and by[332] and not by[332].learned and HL:RowLabel(by[332]):find("not learned",1,true) and not by[547])
assert(by[332].perMana>by[10395].perMana and not by[332].best and by[10395].best, "the star is for a rank you can cast")
-- sorting
fresh();local order=HL:Sorted(false,"rank");assert(order[1].id==10395 and order[2].id==331 and order[3].id==10466 and order[4].id==1064)
order=HL:Sorted(false,"mana");for i=2,#order do assert(order[i-1].perMana>=order[i].perMana) end
order=HL:Sorted(false,"speed");for i=2,#order do assert(order[i-1].perSecond>=order[i].perSecond) end
assert(HL:NextSort("rank")=="mana" and HL:NextSort("speed")=="rank")
-- a rank the spellbook does not answer for still counts when it is on the remembered bars
M.known[10466]=nil;fresh();assert(#HL:Rows(false)==3)
FP.cdb.barGuard.specs[1]={slots={[5]={k="spell",id=10466},[6]={k="item",id=331}}};fresh();assert(#HL:Rows(false)==4)
-- bonus healing unreadable or secret: the tooltip amount alone, no estimate, no error
M.bonus=nil;fresh();rows=HL:Rows(false);for _,r in ipairs(rows) do assert(r.est==nil and r.perMana==r.heal/r.cost) end
assert(not HL:RowLabel(rows[1]):find("est.",1,true) and HL:BonusText():find("could not be read",1,true))
M.bonus=M.Secret();fresh();rows=HL:Rows(false);assert(#rows==4 and rows[1].est==nil)
-- a tooltip with no amount, a missing cost
SP[10395].d="Heals a friendly target.";SP[10466].cost=nil
C_Spell.GetSpellPowerCost=function(id) local s=SP[id]; return s and s.cost and {{type=0,cost=s.cost}} or nil end
M.bonus=350;fresh();rows=HL:Rows(false);by={};for _,r in ipairs(rows) do by[r.id]=r end
assert(by[10395].heal==nil and by[10395].perMana==nil and HL:RowLabel(by[10395]):find("amount: see tooltip",1,true))
assert(by[10466].cost==nil and by[10466].perMana==nil and HL:RowLabel(by[10466]):find("mana ?",1,true))
-- tooltip text
local d,h=HL.Parse("Heals the target of 45 damage over 15 sec.");assert(d==nil and h==45)
d,h=HL.Parse("Heals a friendly target for 84 to 99 and another 98 over 21 sec.");assert(d==91.5 and h==98)
assert(HL.Parse("")==nil and HL.Parse(nil)==nil)
-- the sample kept for reading later: main heal, amount and bonus
local kept=FP.db.healer.tooltip;assert(kept[1].id==10395 and kept[1].heal==1092 and kept[1].bonus==350 and #kept<=12)
assert(#FP.db.errors==0)
''',

        'healer_check_reports_party_state_only_between_pulls': HEAL + r'''
assert(HL:Check()==nil and select(2,HL:Check())=="Not in a party." and not has(hud(),"Healer check"))
M.inGroup=true
member(1,"Anna",{surname="Smith"});member(2,"Borg",{dead=true});member(3,"Cyd",{offline=true});member(4,"Dee",{far=true})
local c=HL:Check()
assert(c.problems==3 and c.alive==2 and c.size==4, c.problems)
assert(has(c.rows,"Borg: dead") and has(c.rows,"Cyd: offline") and has(c.rows,"Dee: out of heal range") and not has(c.rows,"Anna"))
assert(has(hud(),"Healer check (between pulls)") and has(hud(),"Borg: dead"), "shown on the HUD")
assert(M.rangeCalls>0)
-- nobody is asked about in combat, and nothing is shown
local calls=M.rangeCalls
M.combatLockdown=true;M.FireEvent("PLAYER_REGEN_DISABLED")
local none,why=HL:Check();assert(none==nil and why:find("In combat",1,true) and not has(hud(),"Healer check"))
assert(M.rangeCalls==calls, "no range read during a pull")
M.combatLockdown=false;M.FireEvent("PLAYER_REGEN_ENABLED");assert(HL:Check().problems==3)
-- still fighting, out of sight
member(2,"Borg",{fighting=true});member(4,"Dee",{hidden=true});member(3,"Cyd")
c=HL:Check();assert(has(c.rows,"Borg: still in combat") and has(c.rows,"Dee: out of heal range") and c.problems==2)
-- nothing wrong: silence in the open world, one line inside a dungeon
member(2,"Borg");member(4,"Dee")
c=HL:Check();assert(c.problems==0 and #c.rows==0 and not has(hud(),"Healer check"))
M.instance={name="Zul'Farrak"}
c=HL:Check();assert(#c.rows==1 and has(c.rows,"Party ready: 4 of 4 alive, in heal range"), c.rows[1].text)
-- a range the client will not give is not called "in range" and not called "out of range"
M.range.party2=nil
c=HL:Check();assert(c.problems==0 and has(c.rows,"Party ready: 4 of 4 alive") and not has(c.rows,"in heal range"))
M.range.party2=true
-- secret answers are not answers
local dead=UnitIsDeadOrGhost
UnitIsDeadOrGhost=function(unit) if unit=="party1" then return M.Secret() end return dead(unit) end
C_Spell.IsSpellInRange=function(id,unit) if unit=="party1" then return M.Secret() end return M.range[unit] end
c=HL:Check();assert(c.problems==0 and not has(c.rows,"Anna") and not has(c.rows,"in heal range"))
UnitIsDeadOrGhost=dead
-- who gets the check: healing role only, five-player parties only, and it can be switched off
M.raid=true;assert(HL:Check()==nil);M.raid=false
FP.cdb.gear.profile="melee";none,why=HL:Check();assert(none==nil and why:find("gear role is not Healing",1,true));FP.cdb.gear.profile="healer"
M.class="MAGE";none,why=HL:Check();assert(none==nil and why:find("no healing spells",1,true) and not HL:CanHeal());M.class="SHAMAN"
member(2,"Borg",{dead=true})
cmd("heal strip off");assert(FP.settings.healer.strip==false and #HL:Lines()==0 and not has(hud(),"Healer check") and HL:Check().problems==1, "off the HUD, still on the page")
cmd("heal strip on");assert(has(hud(),"Borg: dead"))
cmd("heal off");assert(HL:Check()==nil and not has(hud(),"Healer check"));cmd("heal on")
-- what was readable, and where, is kept for the next read of the saved file
local seen=0;for sig,rec in pairs(FP.db.healer.seen) do seen=seen+1;assert(rec.n>=1 and rec.v==FP.version) end
assert(seen>=2 and seen<=30)
local found;for sig in pairs(FP.db.healer.seen) do if sig:find("inst=party",1,true) and sig:find("range=boolean",1,true) and sig:find("dead=boolean",1,true) then found=true end end;assert(found)
assert(#FP.db.errors==0)
''',

        'healer_check_covers_drinks_ankh_imbue_and_the_marked_spec': HEAL + r'''
M.inGroup=true;M.instance={name="Zul'Farrak"}
member(1,"Anna");member(2,"Borg")
FP.ClassPrep.inventory={waterKnown=true,water=23,counts={},names={}}
M.known[20608]=true;M.itemCount=2
local c=HL:Check();assert(c.problems==0 and has(c.rows,"Party ready: 2 of 2 alive, in heal range · 23 drinks · 2 Ankh"), c.rows[1].text)
FP.ClassPrep.inventory.water=3;M.itemCount=0
c=HL:Check();assert(c.problems==2 and has(c.rows,"Drinks: 3 left") and has(c.rows,"No Ankh: Reincarnation needs one") and not has(c.rows,"Party ready"))
FP.ClassPrep.inventory.waterKnown=false;M.known[20608]=nil
c=HL:Check();assert(c.problems==0, "an unknown count and an unlearned spell say nothing")
-- weapon imbue: only for a shaman who has one, only when it is missing or running out
M.known[8017]=true;M.invIDs={[16]=1234};M.imbues={}
c=HL:Check();assert(has(c.rows,"Weapon imbue: none"))
M.imbues={[16]={remainingTimeMs=120000}};c=HL:Check();assert(has(c.rows,"Weapon imbue: 2m00s left"), c.rows[1].text)
M.imbues={[16]={remainingTimeMs=1500000}};c=HL:Check();assert(c.problems==0)
M.invIDs={};M.imbues={};c=HL:Check();assert(c.problems==0, "no weapon, no line")
-- the healing spec is whichever one the player marks; the other one is called out
assert(FP.cdb.healer.specGroup==nil and HL:StatusText():find("Healing spec: not marked",1,true))
M.specGroup=2;cmd("heal spec");assert(FP.cdb.healer.specGroup==2 and HL:Check().problems==0)
assert(HL:StatusText():find("Healing spec: spec 2 (active now)",1,true))
M.specGroup=1;c=HL:Check();assert(c.problems==1 and has(c.rows,"Not your healing spec (spec 1 is active)"))
cmd("heal spec clear");assert(FP.cdb.healer.specGroup==nil and HL:Check().problems==0)
-- chat
local n=#M.Chat();cmd("heal ranks");local said=false
for i=n+1,#M.Chat() do if tostring(M.Chat()[i]):find("HW r8",1,true) then said=true end end;assert(said)
n=#M.Chat();cmd("heal");assert(tostring(M.Chat()[n+1]):find("Party ready",1,true), tostring(M.Chat()[n+1]))
assert(#FP.db.errors==0)
''',

        'healing_page_lists_ranks_and_changes_nothing_until_a_click': hub + HEAL + r'''
M.inGroup=true;member(1,"Anna");member(2,"Borg",{dead=true})
local before,beforeChar=snapshot(FP.settings),snapshot(FP.cdb)
page("healing")
assert(H.selected=="healing" and #H.sections==17 and H.nav.healing, "listed for a class that heals")
-- seventeen buttons still end above the buttons under the list
local _,_,_,_,y=H.nav[H.sections[17][1]]:GetPoint();assert(y-24>=-530, "sidebar overflows: "..tostring(y))
for i,s in ipairs(H.sections) do page(s[1]);assert(H.pages[s[1]].body:GetHeight()>=432) end
page("healing")
assert(snapshot(FP.settings)==before and snapshot(FP.cdb)==beforeChar, "browsing changed something")
assert(H.controls.healStatus:GetText():find("1 thing to look at",1,true) and H.controls.healStatus:GetText():find("Borg: dead",1,true))
local list=H.controls.healRanks;assert(#list.items==4 and list.items[1].id==10395)
selectRow("healRanks",1)
assert(H.controls.healDetails:GetText():find("Healing Wave (Rank 8)",1,true) and H.controls.healDetails:GetText():find("the most per mana",1,true))
assert(H.controls.healMacro:GetText()=="/cast [@mouseover,help,nodead][help,nodead][@player] Healing Wave(Rank 8)")
click("healAll");assert(#list.items==6 and H.controls.healAll:GetText()=="Show only ranks I know")
click("healAll");click("healSort");assert(H.controls.healSort:GetText():find("per mana",1,true))
for i=2,#list.items do assert(list.items[i-1].perMana>=list.items[i].perMana) end
click("healCheck");assert(H.resultText:GetText():find("Borg: dead",1,true))
assert(not H.controls.healSpecClear:IsEnabled());M.specGroup=2;click("healSpec");assert(FP.cdb.healer.specGroup==2 and H.controls.healSpecClear:IsEnabled())
click("healSpecClear");assert(FP.cdb.healer.specGroup==nil)
check("healStrip",false);assert(FP.settings.healer.strip==false);check("healStrip",true);assert(FP.settings.healer.strip==true)
-- the HUD being hidden is said, not hidden
FP.settings.pvp.manual="hide";H:Refresh();assert(H.controls.healStatus:GetText():find("The HUD is hidden",1,true))
-- no macro was made and nothing was cast or targeted: the addon has no such calls to make
assert(CreateMacro==nil and EditMacro==nil and TargetUnit==nil and CastSpellByName==nil)
assert(#FP.db.errors==0)
''',

        'healing_page_is_not_listed_for_a_class_that_cannot_heal': hub + r'''
M.class="WARRIOR"
page("home")
assert(#H.sections==16 and H.nav.healing==nil and not FP.Healer:CanHeal())
H:Select("healing");assert(H.selected=="home" and H.pages.healing==nil)
M.inGroup=true;M.SetUnit("party1",{name="Anna",player=true,dead=true})
assert(FP.Healer:Check()==nil and #FP.Healer:Lines()==0)
cmd("heal ranks");cmd("heal");assert(#FP.db.errors==0)
''',
    }
