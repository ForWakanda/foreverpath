-- Estimated item rankings, deliberately separate from true simulated BiS.
local _,FP=...
local G=FP:NewModule("Gear")
local API,U=FP.API,FP.Util
G.slots={{"HEAD","Head",1},{"NECK","Neck",2},{"SHOULDER","Shoulder",3},{"CLOAK","Back",15},
 {"CHEST","Chest",5},{"WRIST","Wrist",9},{"HAND","Hands",10},{"WAIST","Waist",6},
 {"LEGS","Legs",7},{"FEET","Feet",8},{"FINGER","Rings",11,12},{"TRINKET","Trinkets",13,14},
 {"MAIN","Main hand",16},{"OFF","Off hand",17},{"RANGED","Ranged / relic",18}}
G.stats={{"str","Strength","ITEM_MOD_STRENGTH_SHORT"},{"agi","Agility","ITEM_MOD_AGILITY_SHORT"},
 {"sta","Stamina","ITEM_MOD_STAMINA_SHORT"},{"int","Intellect","ITEM_MOD_INTELLECT_SHORT"},
 {"spi","Spirit","ITEM_MOD_SPIRIT_SHORT"},{"spell","Spell power","ITEM_MOD_SPELL_POWER_SHORT"},
 {"heal","Healing","ITEM_MOD_SPELL_HEALING_DONE_SHORT"},{"ap","Attack power","ITEM_MOD_ATTACK_POWER_SHORT"},
 {"mp5","Mana / 5 sec","ITEM_MOD_MANA_REGENERATION_SHORT"},{"armor","Armor","RESISTANCE0_NAME"},
 {"dps","Weapon DPS","ITEM_MOD_DAMAGE_PER_SECOND_SHORT"}}
G.quality={[0]={"poor","|cff9d9d9d"},[1]={"common","|cffffffff"},[2]={"uncommon","|cff1eff00"},[3]={"rare","|cff3f9bff"},
 [4]={"epic","|cffc060ff"},[5]={"legendary","|cffff8000"},[6]={"artifact","|cffe6cc80"}}
-- Starting priorities, not simulation-derived EP values; always visible/editable.
G.profiles={
 melee={name="Strength melee",str=2,agi=1,sta=.3,ap=1,dps=6},
 agility={name="Agility melee",str=1,agi=2,sta=.3,ap=1,dps=6},
 ranged={name="Ranged damage",agi=2,sta=.3,int=.2,ap=1,dps=6},
 caster={name="Spell damage",int=1,spi=.3,sta=.3,spell=1.5,mp5=2},
 healer={name="Healing",int=1,spi=.7,sta=.3,heal=1,mp5=3},
 tank={name="Survival / tank",sta=2,str=.5,agi=.7,armor=.03,dps=1},
}
G.classProfiles={WARRIOR={"melee","tank"},PALADIN={"melee","healer","tank"},HUNTER={"ranged"},
 ROGUE={"agility"},PRIEST={"caster","healer"},SHAMAN={"melee","caster","healer"},
 MAGE={"caster"},WARLOCK={"caster"},DRUID={"agility","tank","caster","healer"}}
local armorMax={WARRIOR=4,PALADIN=4,HUNTER=3,ROGUE=2,PRIEST=1,SHAMAN=3,MAGE=1,WARLOCK=1,DRUID=2}
local weapons={WARRIOR={0,1,2,3,4,5,6,7,8,10,13,15,16,18},PALADIN={0,1,4,5,6,7,8},
 HUNTER={0,1,2,3,6,7,8,10,13,15,18},ROGUE={2,3,4,7,13,15,16,18},
 PRIEST={4,10,15,19},SHAMAN={0,1,4,5,10,13,15},MAGE={7,10,15,19},WARLOCK={7,10,15,19},DRUID={4,5,10,13,15}}
local function contains(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end return false end
function G:Profile()
 local class=API.GetCharInfo().class
 local keys=self.classProfiles[class] or {"caster"}
 local key=FP.cdb.gear.profile
 if not contains(keys,key) then key=keys[1] end
 return key,self.profiles[key],keys
end
-- The role being browsed on the gear page. It is separate from the character's
-- own role (G:Profile), which the Healing page and the dungeon drop lists follow:
-- looking up weapons for a second spec must not switch those to another role.
function G:Browse()
 local own,_,keys=self:Profile()
 local key=FP.cdb.gear.browse
 if not contains(keys,key) then key=own end
 return key,self.profiles[key],keys,own
end
-- The role of a second spec, for lists that weigh both (the dungeon ranking).
-- Chosen by a click (`gear.second`: a role, or false for none). Until then it
-- is the role last browsed on the gear page, when that is not the own role.
function G:Second()
 local own,_,keys=self:Profile()
 local key=FP.cdb.gear.second
 if key==false then return nil end
 if key==nil then key=FP.cdb.gear.browse end
 if key~=own and contains(keys,key) then return key,self.profiles[key] end
end
-- none -> each of the class's other roles -> none
function G:CycleSecond()
 local own,_,keys=self:Profile()
 local others={}
 for _,key in ipairs(keys) do if key~=own then others[#others+1]=key end end
 local current=self:Second()
 local nextKey=others[1]
 for i,key in ipairs(others) do if key==current then nextKey=others[i+1] end end
 if current==nil then nextKey=others[1] end
 FP.cdb.gear.second=nextKey or false
 return self:Second()
end
-- Weights of one of the character's roles; its own role when none (or an unknown one) is named.
function G:Weights(role)
 local key,p,keys=self:Profile()
 if role~=nil and contains(keys,role) then key,p=role,self.profiles[role] end
 local out={ranged=key=="ranged"}
 for _,s in ipairs(self.stats) do
  local custom=FP.cdb.gear.weights[key] and FP.cdb.gear.weights[key][s[1]]
  out[s[1]]=U.Finite(custom) and custom>=0 and custom<=100 and custom or p[s[1]] or 0
 end
 return out
end
-- One stat of an item as the score reads it: plain spell power counts for both
-- spell damage and healing unless the item names them separately.
local function statValue(stats,s)
 if s[1]=="spell" then return stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT or stats.ITEM_MOD_SPELL_POWER_SHORT or 0 end
 if s[1]=="heal" then return stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT or stats.ITEM_MOD_SPELL_POWER_SHORT or 0 end
 return stats[s[3]] or 0
end
function G:Score(stats,weights,slot)
 if type(stats)~="table" then return nil end
 local total=0
 for _,s in ipairs(self.stats) do
  -- Ranged DPS does not improve melee, and a hunter's melee DPS is not ranged DPS.
  local value=statValue(stats,s)
  if s[1]=="dps" then
   if (weights.ranged and slot~="RANGED") or (not weights.ranged and slot=="RANGED") then value=0 end
  end
  if not U.Finite(value) then return nil end
  total=total+value*(weights[s[1]] or 0)
 end

 return total
end
function G:SlotMatches(item,slot)
 local loc=item.equipLoc
 if slot=="MAIN" then return loc=="INVTYPE_WEAPON" or loc=="INVTYPE_WEAPONMAINHAND" or loc=="INVTYPE_2HWEAPON" end
 if slot=="OFF" then return loc=="INVTYPE_SHIELD" or loc=="INVTYPE_HOLDABLE" or (API.CanDualWield() and (loc=="INVTYPE_WEAPON" or loc=="INVTYPE_WEAPONOFFHAND")) end
 if slot=="RANGED" then return loc=="INVTYPE_RANGED" or loc=="INVTYPE_RANGEDRIGHT" or loc=="INVTYPE_THROWN" or loc=="INVTYPE_RELIC" end
 return loc=="INVTYPE_"..slot or (slot=="CHEST" and loc=="INVTYPE_ROBE")
end
function G:ClassMatches(item,char)
 if not armorMax[char.class] then return false end
 if item.classes and not item.classes:upper():find(char.class,1,true) then return false end
 if item.classID==2 then return contains(weapons[char.class],item.subclassID) end
 if item.classID~=4 then return false end
 local sub=item.subclassID
 if item.equipLoc=="INVTYPE_CLOAK" then return true end
 if sub>=1 and sub<=4 then
  local max=armorMax[char.class]
  if (char.class=="WARRIOR" or char.class=="PALADIN" or char.class=="HUNTER" or char.class=="SHAMAN") and (char.level or 0)<40 then max=max-1 end
  return sub<=max
 end
 if sub==6 then return char.class=="WARRIOR" or char.class=="PALADIN" or char.class=="SHAMAN" end
 if sub==7 then return char.class=="PALADIN" end
 if sub==8 then return char.class=="DRUID" end
 if sub==9 then return char.class=="SHAMAN" end
 return sub<=0
end
-- What the character has for a role: every worn piece and every equippable item
-- in its bags, scored for that role. The bank is not seen. Per slot group a
-- list of scores, best first; the hands are kept apart because a two-hander
-- stands against a main hand and an off hand together.
--   owned.slots[KEY] = {scores}, owned.two / owned.main / owned.off = best score,
--   owned.unknown[KEY] = true when a worn piece of that group could not be read.
local MAIN_LOC={INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true}
local OFF_LOC={INVTYPE_SHIELD=true,INVTYPE_HOLDABLE=true,INVTYPE_WEAPONOFFHAND=true}
function G:HandOf(equipLoc)
 if equipLoc=="INVTYPE_2HWEAPON" then return "two" end
 if MAIN_LOC[equipLoc] then return "main" end
 if OFF_LOC[equipLoc] then return "off" end
end
function G:Owned(role)
 if API.InCombat() then return nil end
 local weights=self:Weights(role)
 local owned={slots={},unknown={},unread=0,bagsRead=false,loading=0}
 for _,s in ipairs(self.slots) do if s[1]~="MAIN" and s[1]~="OFF" then owned.slots[s[1]]={} end end
 local function place(item)
  local hand=self:HandOf(item.equipLoc)
  if hand then
   local score=self:Score(item.stats,weights,hand=="off" and "OFF" or "MAIN")
   if score and score>(owned[hand] or 0) then owned[hand]=score end
   return
  end
  for key,list in pairs(owned.slots) do
   if self:SlotMatches(item,key) then
    local score=self:Score(item.stats,weights,key)
    if score then list[#list+1]=score end
    return
   end
  end
 end
 for _,s in ipairs(self.slots) do
  for i=3,#s do
   local gear=API.GetRewardEquipment(s[i])
   if gear.status=="equipped" and gear.stats and gear.equipLoc then place(gear)
   elseif gear.status~="empty" then
    owned.unread=owned.unread+1
    owned.unknown[(s[1]=="MAIN" or s[1]=="OFF") and "HANDS" or s[1]]=true
   end
  end
 end
 local bags=API.GetBagGear()
 if bags then
  owned.bagsRead,owned.loading=true,bags.loading or 0
  local char=API.GetCharInfo()
  for _,item in ipairs(bags) do
   -- carried is not owned for this purpose unless it can be worn: not a higher-level piece, not another class's
   local wearable=not (U.Finite(item.minLevel) and U.Finite(char.level) and item.minLevel>char.level)
   if wearable and U.Finite(item.classID) and U.Finite(item.subclassID) then wearable=self:ClassMatches(item,char) end
   if wearable then place(item) end
  end
 end
 for _,list in pairs(owned.slots) do table.sort(list,function(a,b) return a>b end) end
 owned.hands=math.max(owned.two or 0,(owned.main or 0)+(owned.off or 0))
 -- the whole set's score: what an upgrade is a share of
 local base=owned.hands
 for _,s in ipairs(self.slots) do
  local list=owned.slots[s[1]]
  if list then for i=1,#s-2 do base=base+(list[i] or 0) end end
 end
 owned.base=base
 return owned
end
-- What a set of candidate items would add for a role over what is owned: the
-- gain in score and the items that make it. Each slot group counts once (two
-- for rings and trinkets); for the hands the better of a two-hander or a main
-- and off hand pair. items: {item=, slot={KEY,label,...}, boss=} already
-- filtered to what the character can use.
function G:Gain(owned,role,items)
 local weights=self:Weights(role)
 local out={gain=0,items={},skipped=0}
 local perSlot,hands={}, {}
 for _,c in ipairs(items) do
  local hand=self:HandOf(c.item.equipLoc)
  local key=hand and "HANDS" or c.slot[1]
  if owned.unknown[key] then out.skipped=out.skipped+1
  else
   local score=self:Score(c.item.stats,weights,hand and (hand=="off" and "OFF" or "MAIN") or key)
   if score then
    local row={item=c.item,slot=c.slot,boss=c.boss,score=score,later=c.later}
    if hand then
     if not hands[hand] or score>hands[hand].score then hands[hand]=row end
    else
     perSlot[key]=perSlot[key] or {}
     table.insert(perSlot[key],row)
    end
   end
  end
 end
 for _,s in ipairs(self.slots) do
  local cands=perSlot[s[1]]
  if cands then
   table.sort(cands,function(a,b) if a.score~=b.score then return a.score>b.score end return a.item.id<b.item.id end)
   local have=owned.slots[s[1]] or {}
   -- the n best of what is owned and what drops, against the n best owned
   local n,taken,ci,hi=#s-2,0,1,1
   while taken<n do
    local c,h=cands[ci],have[hi] or 0
    if c and c.score>h then
     -- it takes the place of the weakest piece still counted
     local replaced=have[n-(ci-1)] or 0
     c.delta=c.score-replaced
     if c.delta>0 then out.gain=out.gain+c.delta;out.items[#out.items+1]=c end
     ci=ci+1
    else hi=hi+1 end
    taken=taken+1
   end
  end
 end
 -- hands
 if next(hands) then
  local two=hands.two and hands.two.score or -1
  local main=math.max(hands.main and hands.main.score or 0,owned.main or 0)
  local off=math.max(hands.off and hands.off.score or 0,owned.off or 0)
  local pair=main+off
  if two>owned.hands and two>=pair then
   hands.two.delta=two-owned.hands
   out.gain=out.gain+hands.two.delta;out.items[#out.items+1]=hands.two
  elseif pair>owned.hands then
   -- the pair's gain, shared out between the pieces that are new
   local gain=pair-owned.hands
   local newMain=hands.main and hands.main.score>(owned.main or 0) and hands.main or nil
   local newOff=hands.off and hands.off.score>(owned.off or 0) and hands.off or nil
   if newMain and newOff then
    local a,b=newMain.score-(owned.main or 0),newOff.score-(owned.off or 0)
    newMain.delta,newOff.delta=gain*a/(a+b),gain*b/(a+b)
   elseif newMain then newMain.delta=gain
   elseif newOff then newOff.delta=gain end
   for _,row in ipairs({newMain or false,newOff or false}) do if row then out.items[#out.items+1]=row end end
   if newMain or newOff then out.gain=out.gain+gain end
  end
 end
 table.sort(out.items,function(a,b) if a.delta~=b.delta then return a.delta>b.delta end return a.item.id<b.item.id end)
 out.pct=owned.base>0 and out.gain/owned.base*100 or nil
 return out
end
-- Does a reference source name mean this dungeon (or one of its wings)? The
-- item reference says "The Temple of Atal'Hakkar", "Blackrock Spire",
-- "Scarlet Monastery"; the dungeon list says "The Sunken Temple", "Lower
-- Blackrock Spire", "Scarlet Monastery: Library".
function G:SourceIsDungeon(source,dungeonName)
 if type(source)~="string" or type(dungeonName)~="string" then return false end
 local s=source:lower():gsub("^the ","")
 if s=="temple of atal'hakkar" then s="sunken temple" end
 return s~="" and dungeonName:lower():find(s,1,true)~=nil
end
-- The boss an item drops from in this dungeon, true when no boss is recorded,
-- nil when the item is not listed for it.
function G:DropsIn(item,dungeonName)
 for i,kind in ipairs(item.sourceTypes) do
  if kind=="Dungeon" and self:SourceIsDungeon(item.sources[i],dungeonName) then return item.bosses[1] or true end
 end
end
-- Quest rewards rarely list a required level and their item level tracks the
-- quest level; quests a few levels above the character are routinely done.
G.PROXY_MARGIN=5
-- Source types in the order the page offers them, and the names it uses. The
-- reference files every creature drop without a listed dungeon under "Drop":
-- world drops, rare creatures and raid bosses alike. Next to "Dungeon" the bare
-- word reads as "anything that drops", so the page names what it covers.
G.sourceOrder={"Dungeon","Raid","Drop","Quest","Crafted","Vendor","Reputation","PvP"}
G.sourceLabels={Drop="World / raid drop"}
function G:SourceLabel(kind) return self.sourceLabels[kind] or kind end
-- Only the source types the loaded reference has: a choice that can never match reads as "nothing drops".
function G:Sources()
 local catalog=FP.GearCatalog
 if type(catalog)~="table" or type(catalog.items)~="table" then return {"All"} end
 if self.sourceCatalog~=catalog then
  local seen={}
  for _,item in ipairs(catalog.items) do for _,kind in ipairs(item.sourceTypes) do seen[kind]=true end end
  local out={"All"}
  for _,kind in ipairs(self.sourceOrder) do if seen[kind] then out[#out+1]=kind;seen[kind]=nil end end
  local rest={};for kind in pairs(seen) do rest[#rest+1]=kind end;table.sort(rest)
  for _,kind in ipairs(rest) do out[#out+1]=kind end
  self.sourceCatalog,self.sourceList=catalog,out
 end
 return self.sourceList
end
-- Which side an item belongs to, when the reference lets us tell: a reputation
-- it asks for, or an honor-rank title in its name ("High Warlord's Battle Axe";
-- the reference lists no requirement on the Horde rank items). The reputation
-- sides and rank titles are the Classic ones plus Forever's Darkspear Raiders
-- (Horde) and Theramore Expeditionary Force (Alliance), unverified in the
-- client: the page can always show the other side's items on request.
local SIDE={["The League of Arathor"]="Alliance",["Silverwing Sentinels"]="Alliance",["Stormpike Guard"]="Alliance",["Theramore Expeditionary Force"]="Alliance",
 ["The Defilers"]="Horde",["Warsong Outriders"]="Horde",["Frostwolf Clan"]="Horde",["Darkspear Raiders"]="Horde"}
local RANKS={Alliance={"Master Sergeant","Sergeant Major","Knight","Knight-Lieutenant","Knight-Captain","Knight-Champion","Lieutenant Commander","Commander","Marshal","Field Marshal","Grand Marshal"},
 Horde={"Senior Sergeant","First Sergeant","Stone Guard","Blood Guard","Legionnaire","Centurion","Champion","Lieutenant General","General","Warlord","High Warlord"}}
local RANK_SIDE={}
for side,list in pairs(RANKS) do for _,rank in ipairs(list) do RANK_SIDE[rank]=side end end
function G:Side(item)
 -- an item that asks for one reputation per side is open to both
 local found
 for _,need in ipairs(type(item.requires)=="table" and item.requires or {}) do
  local side=SIDE[need:match("^(.-) %- ") or need] or RANK_SIDE[need]
  if side then
   if found and found~=side then return nil end
   found=side
  end
 end
 if found then return found end
 -- a rank title only means the honor reward when a vendor or the honor system hands it out
 if type(item.name)=="string" and (contains(item.sourceTypes,"PvP") or contains(item.sourceTypes,"Vendor")) then
  return RANK_SIDE[item.name:match("^(.-)'s ") or ""]
 end
end
G.hands={"any","two","one"}
G.handLabels={any="Any",two="Two-hand",one="One-hand"}
G.sorts={"score","dps","hit"}
G.sortLabels={score="Best score",dps="Weapon DPS",hit="Biggest hits",wf="Windfury burst"}
function G:IsWeaponSlot(slot) return slot=="MAIN" or slot=="OFF" or slot=="RANGED" end
-- Average damage of one swing: what a slow weapon is chosen for.
function G:HitSize(item)
 if U.Finite(item.dmgMin) and U.Finite(item.dmgMax) then return (item.dmgMin+item.dmgMax)/2 end
end
-------------------------------------------------------------------------------
-- Windfury burst (shaman, melee role, main hand). An estimate of what one
-- Windfury Weapon proc lands at once: the swing that set it off plus the extra
-- attacks, each extra one with the spell's bonus attack power.
--   burst = (1+extra) x average weapon damage
--         + speed x ((1+extra) x attack power + extra x Windfury bonus) / 14
-- then x (1 + the weapon's own crit% and hit%) as an expected value. Attack
-- power / 14 per second of weapon speed, 2 attack power per Strength and the
-- fallback bonus per rank are the Classic rules, not confirmed on Forever; the
-- bonus is read from the client's own spell tooltip when it can be. Sustained
-- Windfury damage follows weapon DPS, not speed; this ranks the size of the hit.
-------------------------------------------------------------------------------
G.WINDFURY={ids={8232,8235,10486,16362},learn={30,40,50,60},classic={104,119,249,333},extra=2,apPerSpeed=14,apPerStr=2}
function G:WindfuryFor(slot,role)
 return slot=="MAIN" and role=="melee" and API.GetCharInfo().class=="SHAMAN"
end
-- The sorts a slot offers; the Windfury one only where it means something.
function G:Sorts(slot,role)
 if not self:WindfuryFor(slot,role) then return self.sorts end
 return {"score","dps","hit","wf"}
end
local function weaponAP(stats)
 if type(stats)~="table" then return nil end
 local ap,str=stats.ITEM_MOD_ATTACK_POWER_SHORT or 0,stats.ITEM_MOD_STRENGTH_SHORT or 0
 if not (U.Finite(ap) and U.Finite(str)) then return nil end
 return ap+G.WINDFURY.apPerStr*str
end
-- What the estimate stands on, and where each number came from.
function G:WindfuryContext()
 local now=API.Time()
 if self.wfMemo and now-self.wfMemo.t<2 then return self.wfMemo.ctx end
 local W=self.WINDFURY
 local level=API.PlayerLevel()
 local ctx={extra=W.extra}
 -- the bonus: the highest rank the character knows, else the rank for its level
 local rank
 for i=#W.ids,1,-1 do if API.KnowsSpell(W.ids[i])==true then rank=i;ctx.rankSource="the rank you know";break end end
 if not rank then
  rank=1
  for i=1,#W.ids do if U.Finite(level) and level>=W.learn[i] then rank=i end end
  ctx.rankSource="the rank for your level"
 end
 ctx.rank=rank
 local desc=API.GetSpellDescription(W.ids[rank])
 local read=type(desc)=="string" and desc:match("(%d[%d,]*) extra attack power")
 read=read and tonumber((read:gsub(",","")))
 if U.Finite(read) and read>0 and read<10000 then ctx.bonus,ctx.bonusSource=read,"your client's Windfury Weapon tooltip"
 else ctx.bonus,ctx.bonusSource=W.classic[rank],"the Classic value, not read from your client" end
 -- attack power: the character's own without the weapons it wears (a candidate brings its own)
 local ap=API.GetAttackPower()
 if ap then
  local main,off=weaponAP(API.GetRewardEquipment(16).stats),weaponAP(API.GetRewardEquipment(17).stats)
  ctx.ap=math.max(0,ap-(main or 0))
  ctx.apTwoHand=math.max(0,ctx.ap-(off or 0))
  ctx.apSource=(main and off) and "yours, without the weapons you wear" or "yours; a worn weapon could not be read, so its Strength may be counted twice"
 else
  ctx.ap=U.Finite(level) and level*10 or 500
  ctx.apTwoHand=ctx.ap
  ctx.apSource="assumed from your level, because your client did not give yours"
 end
 self.wfMemo={t=now,ctx=ctx}
 -- kept for the next data pull: could the client's numbers be read?
 if FP.db then
  FP.db.windfury={t=U.Now(),version=FP.version,build=FP.clientBuild,rank=rank,rankSource=ctx.rankSource,bonus=ctx.bonus,bonusSource=ctx.bonusSource,
   ap=ctx.ap,apRead=ap~=nil}
 end
 return ctx
end
-- burst, and the parts it was made of; nil for an item without damage or speed.
function G:Windfury(item,ctx)
 local avg=self:HitSize(item)
 if not avg or not U.Finite(item.speed) or item.speed<=0 or item.classID~=2 then return nil end
 ctx=ctx or self:WindfuryContext()
 local W=self.WINDFURY
 local own=weaponAP(item.stats) or 0
 local ap=(item.equipLoc=="INVTYPE_2HWEAPON" and ctx.apTwoHand or ctx.ap)+own
 local swings=1+ctx.extra
 local chance=1+((U.Finite(item.crit) and item.crit or 0)+(U.Finite(item.hit) and item.hit or 0))/100
 local burst=(swings*avg+item.speed*(swings*ap+ctx.extra*ctx.bonus)/W.apPerSpeed)*chance
 return burst,{avg=avg,ap=ap,own=own,swings=swings,chance=chance}
end
-------------------------------------------------------------------------------
-- Live items: gear the bundled reference does not have. The reference is a
-- snapshot of the items a website had a Forever tooltip for; it misses about a
-- fifth of the quest rewards the quest database knows, and most dungeon and
-- raid drops it lists. Three places name such an item:
--   the quest log   every reward and reward choice of a quest the character is on
--   the quest database   weapons and armor with a source (quest, creature, object, vendor)
--   a search   by name, also the ones the database gives no source for
-- What the item IS (slot, quality, stats, damage) is read from the client by
-- item id, a few per tick, out of combat, and kept for the session. An id the
-- client does not know, or never loads, is simply not listed. Nothing is saved
-- but a small receipt (HearthAndHustleDB.gearLive) for the next data pull.
-------------------------------------------------------------------------------
G.LEVEL_CAP=60
G.LIVE={scan=2500,load=40,tick=.1,retry=1.5,tries=4,search=200,minQuality=2}
local SLOTLESS={INVTYPE_TABARD=true,INVTYPE_BODY=true,INVTYPE_BAG=true,INVTYPE_AMMO=true,INVTYPE_QUIVER=true,INVTYPE_NON_EQUIP_IGNORE=true}
function G:LiveState()
 if not self.live then
  self.live={cands={},items={},list={},queue={},head=1,wait={},logDirty=true,revision=0,
   counts={asked=0,immediate=0,later=0,gaveUp=0,unknown=0,notGear=0,lowQuality=0,noStats=0,listed=0,noSwing=0},keys={}}
 end
 return self.live
end
-- ids the reference already has; live items never repeat one
function G:CatalogIds()
 local catalog=FP.GearCatalog
 if type(catalog)~="table" or type(catalog.items)~="table" then return {} end
 if self.idCatalog~=catalog then
  local ids,names={},{}
  for _,item in ipairs(catalog.items) do
   ids[item.id]=true
   local key=tostring(item.classID)..":"..tostring(item.subclassID)
   if type(item.subtype)=="string" and names[key]==nil then names[key]=item.subtype end
  end
  self.idCatalog,self.idSet,self.subtypeNames=catalog,ids,names
 end
 return self.idSet
end
-- The reference's own word for an item type ("Mace" for both one- and two-handed
-- maces), so the Type filter treats a live item like its neighbours.
function G:SubtypeName(classID,subclassID,fallback)
 self:CatalogIds()
 local name=self.subtypeNames and self.subtypeNames[tostring(classID)..":"..tostring(subclassID)]
 if name~=nil then return name end
 if classID==4 and subclassID==0 then return "" end
 return type(fallback)=="string" and fallback or ""
end
-- The slot group an item goes in: "HEAD", "MAIN", ... (a one-hander counts as main hand).
function G:SlotOf(item)
 for _,s in ipairs(self.slots) do if self:SlotMatches(item,s[1]) then return s[1],s end end
end
local function liveUsable(self,cand,char)
 return self:ClassMatches({classID=cand.classID,subclassID=cand.subclassID,equipLoc=cand.equipLoc},char)
end
local function liveEnqueue(L,cand,front)
 if cand.queued or L.items[cand.id]~=nil then return end
 cand.queued=true
 if front then table.insert(L.queue,L.head,cand.id) else L.queue[#L.queue+1]=cand.id end
end
-- Rewards of the quests in the log: always wanted, read first.
function G:LiveReadLog()
 local L=self:LiveState()
 local log=API.GetLogRewardItems()
 if not log then return end
 L.logDirty=false
 L.log={quests=log.quests,withItems=log.withItems,ignored=log.ignored,items=#log.items}
 local ids=self:CatalogIds()
 local seen={}
 for _,row in ipairs(log.items) do
  seen[row.id]=row
  if not ids[row.id] then
   local cand=L.cands[row.id]
   if not cand then cand={id=row.id};L.cands[row.id]=cand end
   cand.log={questID=row.questID,title=row.title,kind=row.kind}
   local item=L.items[row.id]
   if item then
    if not item.logQuest then L.revision=L.revision+1 end
    item.logQuest=cand.log
   elseif item==nil then liveEnqueue(L,cand,true) end
  end
 end
 -- a quest handed in or dropped: its reward is no longer "in your log"
 for id,cand in pairs(L.cands) do
  if cand.log and not seen[id] then
   cand.log=nil
   if L.items[id] then L.items[id].logQuest=nil;L.revision=L.revision+1 end
  end
 end
 L.logById=seen
end
-- A reference-shaped record from what the client gave. nil + the reason it is not listed.
function G:LiveAdopt(cand,read)
 local L=self:LiveState()
 if type(read.equipLoc)~="string" or read.equipLoc=="" or SLOTLESS[read.equipLoc] then return nil,"notGear" end
 local classID,subclassID=read.classID or cand.classID,read.subclassID or cand.subclassID
 if not (U.Finite(classID) and U.Finite(subclassID)) or (classID~=2 and classID~=4) then return nil,"notGear" end
 if not cand.log and (read.quality or 0)<self.LIVE.minQuality then return nil,"lowQuality" end
 if type(read.stats)~="table" then return nil,"noStats" end
 local stats={}
 for key,value in pairs(read.stats) do stats[key]=value;if U.Count(L.keys)<60 then L.keys[key]=true end end
 -- one name per stat: the client may call mana regeneration by its power-type name
 if stats.ITEM_MOD_MANA_REGENERATION_SHORT==nil and stats.ITEM_MOD_POWER_REGEN0_SHORT~=nil then stats.ITEM_MOD_MANA_REGENERATION_SHORT=stats.ITEM_MOD_POWER_REGEN0_SHORT end
 local item={id=cand.id,name=read.name,equipLoc=read.equipLoc,classID=classID,subclassID=subclassID,
  subtype=self:SubtypeName(classID,subclassID,read.subtype),level=read.level or cand.level,
  minLevel=(U.Finite(read.minLevel) and read.minLevel>0) and read.minLevel or cand.minLevel,
  quality=read.quality,bind=read.bind,stats=stats,live=true,restrictions=false,logQuest=cand.log}
 local where=API.DescribeReferenceGear(cand.id)
 item.sourceTypes,item.sources,item.bosses,item.droppedBy=where.sourceTypes,where.sources,where.bosses,where.droppedBy
 if cand.log then
  local listed=false
  for _,kind in ipairs(item.sourceTypes) do if kind=="Quest" then listed=true end end
  if not listed then table.insert(item.sourceTypes,1,"Quest");table.insert(item.sources,1,"Quest Rewards") end
 end
 if #item.sourceTypes==0 then item.sourceTypes,item.sources,item.unsourced={"Unknown"},{"Source not known"},true end
 if classID==2 then
  local swing=API.GetWeaponSwing(cand.id)
  if swing then item.dmgMin,item.dmgMax,item.speed=swing.dmgMin,swing.dmgMax,swing.speed else L.counts.noSwing=L.counts.noSwing+1 end
 end
 return item
end
local function liveResolve(self,L,id,now,entry)
 local cand=L.cands[id]
 if not cand or L.items[id]~=nil then return end
 local c=L.counts
 if not entry then
  c.asked=c.asked+1
  if API.ItemExists(id)==false then L.items[id]=false;c.unknown=c.unknown+1;return end
 end
 local read=API.GetRewardItem("item:"..id,true)
 if not read then
  local tries=(entry and entry.tries or 0)+1
  if tries>self.LIVE.tries then L.items[id]=false;c.gaveUp=c.gaveUp+1;return end
  if not entry then API.RequestItemData(id) end
  L.wait[#L.wait+1]={id=id,at=now+self.LIVE.retry*tries,tries=tries}
  return
 end
 if entry then c.later=c.later+1 else c.immediate=c.immediate+1 end
 local item,why=self:LiveAdopt(cand,read)
 if not item then L.items[id]=false;c[why]=(c[why] or 0)+1;return end
 -- the database's guess at who can use it was made without a slot; the client's record decides
 L.items[id]=item;L.list[#L.list+1]=item;c.listed=c.listed+1;L.revision=L.revision+1
end
function G:LiveStep()
 local L=self:LiveState()
 L.timer=nil
 if API.InCombat() then L.paused=true;return end
 L.paused=nil
 if not API.EnsureGearCatalog() then return end
 local now=API.Time()
 L.started=L.started or now
 if L.logDirty then self:LiveReadLog() end
 local char=API.GetCharInfo()
 if not L.scan or not L.scan.done then
  local from=L.scan and #L.scan.rows or 0
  L.scan=API.ScanReferenceGear(L.scan,self.LIVE.scan)
  local ids=self:CatalogIds()
  for i=from+1,#L.scan.rows do
   local row=L.scan.rows[i]
   if not ids[row.id] then
    local cand=L.cands[row.id]
    if cand then for k,v in pairs(row) do if cand[k]==nil then cand[k]=v end end
    else cand=row;L.cands[row.id]=cand end
    L.known=(L.known or 0)+1
    if cand.sourced and liveUsable(self,cand,char) then liveEnqueue(L,cand) end
   end
  end
 end
 -- items asked for earlier whose turn has come, then new ones
 local budget=self.LIVE.load
 local due=L.wait
 L.wait={}
 for _,entry in ipairs(due) do
  if entry.at<=now and budget>0 then budget=budget-1;liveResolve(self,L,entry.id,now,entry) else L.wait[#L.wait+1]=entry end
 end
 while budget>0 and L.head<=#L.queue do
  local id=L.queue[L.head];L.queue[L.head]=false;L.head=L.head+1
  budget=budget-1
  if id then liveResolve(self,L,id,now) end
 end
 local busy=L.head<=#L.queue or #L.wait>0 or not (L.scan and L.scan.done) or L.logDirty
 if busy then
  self:LiveSchedule()
  if now-(L.shown or 0)>=1 then L.shown=now;self:LiveRefreshPage() end
 else
  L.finished=L.finished or now
  self:LiveReceipt()
  self:LiveRefreshPage()
 end
end
function G:LiveSchedule()
 local L=self:LiveState()
 if L.timer then return end
 L.timer=true
 FP.After(self.LIVE.tick,function() self:LiveStep() end)
end
-- Asked for by the pages that show gear; cheap to call on every refresh.
function G:LiveStart()
 local L=self:LiveState()
 if API.InCombat() then L.paused=true;return L end
 local idle=L.scan and L.scan.done and L.head>#L.queue and #L.wait==0 and not L.logDirty
 if not idle then self:LiveSchedule() end
 return L
end
function G:LiveRefreshPage()
 local H=FP.Hub
 local page=H and H.frame and H.frame:IsShown() and H.selected
 if page=="gear" or page=="rewards" then H:Refresh() end
end
-- What the page says about it: how many are listed, how many still to read.
function G:LiveStatus()
 local L=self:LiveState()
 local pending=(#L.queue-L.head+1)+#L.wait
 local scanning=not (L.scan and L.scan.done)
 return {listed=L.counts.listed,pending=math.max(0,pending),scanning=scanning,busy=scanning or pending>0 or L.logDirty,
  unavailable=L.scan and L.scan.unavailable or false,paused=L.paused or false}
end
function G:LiveReceipt()
 if not FP.db then return end
 local L=self:LiveState()
 local keys={};for key in pairs(L.keys) do keys[#keys+1]=key end;table.sort(keys)
 FP.db.gearLive={t=U.Now(),version=FP.version,build=FP.clientBuild,seconds=L.finished and L.started and U.Round(L.finished-L.started,1) or nil,
  database=L.scan and not L.scan.unavailable or false,scanned=L.scan and L.scan.scanned or 0,missing=L.known or 0,
  counts=U.Copy(L.counts),log=L.log and U.Copy(L.log) or nil,statKeys=keys}
end
-- A search also reaches items the quest database names no source for: the ones
-- whose name matches are read from the client like the rest.
function G:LiveSearch(query)
 local L=self:LiveState()
 if #query<3 or L.searched==query or not (L.scan and L.scan.done) or API.InCombat() then return end
 L.searched=query
 local char=API.GetCharInfo()
 local added=0
 for id,cand in pairs(L.cands) do
  if added>=self.LIVE.search then break end
  if not cand.queued and L.items[id]==nil and type(cand.name)=="string" and cand.name:lower():find(query,1,true) and (cand.classID==nil or liveUsable(self,cand,char)) then
   liveEnqueue(L,cand,true);added=added+1
  end
 end
 if added>0 then self:LiveSchedule() end
end
-- The same list the gear page ranks, cached briefly: where one item stands in it.
function G:RankedRows(slot,role,level)
 local L=self:LiveState()
 local key=slot..":"..tostring(role)..":"..tostring(level)
 self.rankMemo=self.rankMemo or {}
 local memo=self.rankMemo[key]
 local now=API.Time()
 if memo and now-memo.t<5 and memo.revision==L.revision and memo.catalog==FP.GearCatalog then return memo.rows end
 local rows=self:Rows({slot=slot,role=role,level=level,source="All"})
 self.rankMemo[key]={t=now,revision=L.revision,catalog=FP.GearCatalog,rows=rows}
 return rows
end
-- Where an item stands for a role among everything the character could wear in
-- that slot at its level, from any source: score, rank, out of how many, and
-- the piece at the top. nil when it has no slot here or cannot be scored.
function G:Standing(item,role)
 local slot,def=self:SlotOf(item)
 local level=API.PlayerLevel()
 if not slot or not U.Finite(level) then return nil end
 local score=self:Score(item.stats,self:Weights(role),slot)
 if not score then return nil end
 local rows=self:RankedRows(slot,role,level)
 local rank,listed=1,false
 for _,row in ipairs(rows) do
  if row.key==item.id then listed=true
  elseif (row.score or -1)>score then rank=rank+1 end
 end
 local top=rows[1]
 if top and top.key==item.id then top=rows[2] end
 return {slot=slot,label=def[2],score=score,rank=rank,of=#rows+(listed and 0 or 1),listed=listed,level=level,
  top=top and top.item.name or nil,topScore=top and top.score or nil}
end
-- filter: slot, level, unknown, source, query as before; role (one of the
-- character's roles, default its own), hands ("two"/"one", main hand only),
-- subtype ("Mace"), sort ("dps"/"hit", default score), otherFaction (keep the
-- other side's items).
-- Returns rows, a message, the item types the other filters leave to choose
-- from, how many matching items were left out as the other side's, and, for a
-- search, how many matches sit in each other slot ({HAND=1}).
function G:Rows(filter)
 local rows,types,elsewhere={},{},{}
 if API.InCombat() then return rows,"Gear browsing resumes after combat.",types,0,elsewhere end
 if not API.EnsureGearCatalog() then return rows,"Gear data unavailable. Install both Hearth & Hustle folders and restart WoW.",types,0,elsewhere end
 local char=API.GetCharInfo()
 if not U.Finite(char.level) or not armorMax[char.class] then return rows,"Character information unavailable.",types,0,elsewhere end
 local max=filter.level or char.level
 local query=U.Trim(filter.query or ""):lower()
 local weights=self:Weights(filter.role)
 local slot=filter.slot or "HEAD"
 local hands=(slot=="MAIN") and filter.hands or nil
 local side=(char.faction=="Horde" or char.faction=="Alliance") and not filter.otherFaction and char.faction or nil
 local source=filter.source or "All"
 -- at the level cap nothing can ask for more: an item with no listed requirement is wearable
 local capped=max>=G.LEVEL_CAP
 local seen,hidden={},0
 local live=self:LiveStart()
 if query~="" then self:LiveSearch(query) end
 local function consider(item)
  local inSlot=self:SlotMatches(item,slot)
  if not inSlot and query=="" then return end
  -- an item no source is known for only answers a search
  if item.unsourced and query=="" then return end
  local known=U.Finite(item.minLevel)
  local proxy=not known and U.Finite(item.level) and item.level or nil
  if not (self:ClassMatches(item,char)
   and ((known and item.minLevel<=max) or (not known and (capped or (proxy and proxy<=max+(filter.unknown and G.PROXY_MARGIN or 0)) or (not proxy and filter.unknown))))
   and (source=="All" or contains(item.sourceTypes,source))
   and (query=="" or item.name:lower():find(query,1,true) or tostring(item.id)==query or table.concat(item.sources," "):lower():find(query,1,true)
    or (item.logQuest and item.logQuest.title:lower():find(query,1,true)))) then return end
  local theirs=side and self:Side(item)
  if not inSlot then
   if not (theirs and theirs~=side) then
    local key=self:SlotOf(item)
    if key then elsewhere[key]=(elsewhere[key] or 0)+1 end
   end
   return
  end
  if not ((hands~="two" or item.equipLoc=="INVTYPE_2HWEAPON") and (hands~="one" or item.equipLoc~="INVTYPE_2HWEAPON")) then return end
  if theirs and theirs~=side then
   if not filter.subtype or item.subtype==filter.subtype then hidden=hidden+1 end
  else
   if type(item.subtype)=="string" and item.subtype~="" and not seen[item.subtype] then seen[item.subtype]=true;types[#types+1]=item.subtype end
   if not filter.subtype or item.subtype==filter.subtype then
    rows[#rows+1]={key=item.id,item=item,score=self:Score(item.stats,weights,slot)}
   end
  end
 end
 for _,item in ipairs(FP.GearCatalog.items) do consider(item) end
 for _,item in ipairs(live.list) do consider(item) end
 table.sort(types)
 local sort=filter.sort
 -- a Windfury sort left over from another slot or role means nothing here
 if sort=="wf" then
  local own,_,keys=self:Profile()
  if not self:WindfuryFor(filter.slot,contains(keys,filter.role) and filter.role or own) then sort=nil end
 end
 if sort=="wf" then
  local ctx=self:WindfuryContext()
  for _,row in ipairs(rows) do row.wf=self:Windfury(row.item,ctx) end
 end
 local function measure(row)
  if sort=="dps" then return row.item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or -1 end
  if sort=="wf" then return row.wf or -1 end
  return self:HitSize(row.item) or -1
 end
 table.sort(rows,function(a,b)
  if sort=="dps" or sort=="hit" or sort=="wf" then local x,y=measure(a),measure(b);if x~=y then return x>y end end
  if a.score~=b.score then return (a.score or -1)>(b.score or -1) end
  return a.item.id<b.item.id
 end)
 for i,row in ipairs(rows) do row.rank=i end
 local message
 if #rows==0 then
  local found=self:Elsewhere(elsewhere)
  local status=self:LiveStatus()
  if found~="" then message="Nothing in this slot matches \""..U.Trim(filter.query or "").."\". The search found it under: "..found.."."
  elseif query~="" and status.busy then message="No match yet. Still reading items from your client: the list fills in as they arrive."
  elseif query~="" then message="Nothing called \""..U.Trim(filter.query or "").."\" that you could wear at this level: not in the item reference, the quest database or your quest log. Check the spelling, the level and the source."
  else message="No matching items. Try another slot, hands, type, source or level, or include unknown level requirements." end
 end
 return rows,message,types,hidden,elsewhere
end
-- "Hands 1, Chest 2" in the page's slot order.
function G:Elsewhere(counts)
 local parts={}
 for _,s in ipairs(self.slots) do if counts and counts[s[1]] then parts[#parts+1]=s[2].." "..counts[s[1]] end end
 return table.concat(parts,", ")
end
-- What an item is, in the words a player searches by: "2H Mace", "Mail", "Shield".
local HANDS={INVTYPE_2HWEAPON="2H",INVTYPE_WEAPON="1H",INVTYPE_WEAPONMAINHAND="MH",INVTYPE_WEAPONOFFHAND="OH"}
function G:Kind(item)
 local subtype=type(item.subtype)=="string" and item.subtype~="" and item.subtype or nil
 if item.classID==2 then
  local hand=HANDS[item.equipLoc]
  return (hand and hand.." " or "")..(subtype or "weapon")
 end
 return subtype
end
-- Where it comes from, short: the dungeon by name, a drop by its creature when
-- the reference names one, everything else by kind.
function G:Where(item)
 local out,seen={},{}
 if item.logQuest then out[1]="Your quest: "..item.logQuest.title;seen.Quest=true end
 for i,kind in ipairs(item.sourceTypes) do
  local text=kind=="Dungeon" and item.sources[i] or (kind=="Drop" and (item.droppedBy and ("Drop: "..item.droppedBy) or "Drop"))
   or (kind=="Unknown" and "source not known") or self:SourceLabel(kind)
  if text and not seen[text] then seen[text]=true;out[#out+1]=text end
 end
 return table.concat(out," / ")
end
local SHORT={str="Str",agi="Agi",sta="Sta",int="Int",spi="Spi",spell="spell",heal="healing",ap="AP",mp5="mp5"}
local function amount(v) return v==math.floor(v) and string.format("%d",v) or string.format("%.1f",v) end
-- The stats this role is scored on, largest contribution first: "+20 Str, +14 Sta".
function G:StatSummary(item,weights,limit)
 local parts={}
 for _,s in ipairs(self.stats) do
  local v=SHORT[s[1]] and statValue(item.stats,s) or 0
  local w=weights[s[1]] or 0
  if U.Finite(v) and v>0 and w>0 then parts[#parts+1]={v*w,"+"..amount(v).." "..SHORT[s[1]]} end
 end
 table.sort(parts,function(a,b) if a[1]~=b[1] then return a[1]>b[1] end return a[2]<b[2] end)
 local out={}
 for i=1,math.min(limit or 3,#parts) do out[i]=parts[i][2] end
 return table.concat(out,", ")
end
function G:QualityColor(item) local q=self.quality[item.quality or -1];return q and q[2] or nil end
-- Characters as the player sees them (a "·" is one, though two bytes).
local function chars(s) local n=0;for i=1,#s do local b=s:byte(i);if b<128 or b>=192 then n=n+1 end end;return n end
G.ROW_CHARS=80
-- One list row: enough to choose without opening the item.
-- "2. Taran Icebreaker · 2H Mace · 49.7 dps · speed 3.80 · L47 · Drop · +14 Sta"
function G:RowText(row,weights)
 local item=row.item
 local parts={}
 local kind=self:Kind(item)
 if kind then parts[#parts+1]=kind end
 if item.classID==2 then
  local dps=item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  if U.Finite(dps) then parts[#parts+1]=string.format("%.1f dps",dps) end
  if U.Finite(item.speed) then parts[#parts+1]=string.format("speed %.2f",item.speed) end
  if row.wf then parts[#parts+1]=string.format("WF %d",math.floor(row.wf+.5)) end
 end
 parts[#parts+1]=U.Finite(item.minLevel) and ("L"..amount(item.minLevel)) or (U.Finite(item.level) and ("ilvl "..amount(item.level)) or "L?")
 local rank,facts=tostring(row.rank or "?")..". ",table.concat(parts," · ")
 -- the facts are kept whole, then the name, and the source takes the room that is left (the details carry it in full)
 local text=rank..U.Truncate(item.name,math.max(20,self.ROW_CHARS-chars(rank)-chars(facts)-3)).." · "..facts
 local where=self:Where(item)
 local room=self.ROW_CHARS-chars(text)-3
 if where~="" and room>=6 then text=text.." · "..U.Truncate(where,room) end
 -- as many of the role's stats as fit whole: a cut-off "+2…" says nothing
 for count=3,1,-1 do
  local stats=self:StatSummary(item,weights or self:Weights(),count)
  if stats~="" and chars(text)+3+chars(stats)<=self.ROW_CHARS then return text.." · "..stats end
 end
 return text
end
local BIND={pickup="binds when picked up",equip="binds when equipped"}
local function percent(v) return (string.format("%.2f",v):gsub("%.?0+$","")) end
-- role: the role the list was ranked for (default: the character's own).
function G:Details(row,slot,role)
 if API.InCombat() then return "Gear comparisons resume after combat." end
 if not row then return "Choose an item to see its stats, source and equipped comparison." end
 local item=row.item
 local own,_,keys=self:Profile()
 if not contains(keys,role) then role=own end
 local weights=self:Weights(role)
 local q=self.quality[item.quality or -1]
 local lines={(q and q[2] or FP.GOLD)..item.name.."|r  ·  #"..item.id}
 -- what it is
 local what=self:Kind(item) or "Item"
 if item.classID==2 then
  if U.Finite(item.dmgMin) and U.Finite(item.dmgMax) then what=what.." · "..amount(item.dmgMin).." - "..amount(item.dmgMax).." damage" end
  if U.Finite(item.speed) then what=what..string.format(" · speed %.2f",item.speed) end
  local dps=item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  if U.Finite(dps) then what=what..string.format(" · %.1f dps",dps) end
 end
 lines[#lines+1]=what
 lines[#lines+1]="Requires level "..tostring(item.minLevel and amount(item.minLevel) or "unknown").." · item level "..tostring(item.level and amount(item.level) or "?")
  ..(q and (" · "..q[1]) or "")..(BIND[item.bind or ""] and (" · "..BIND[item.bind]) or "")
 if not item.minLevel and item.level then lines[#lines+1]="Level filter uses item level as an estimate; check the quest/source requirements before pursuing it." end
 local stats={}
 for _,stat in ipairs(self.stats) do
  local v=item.stats[stat[3]]
  if U.Finite(v) and v~=0 and stat[1]~="dps" then stats[#stats+1]=(stat[1]=="armor" and "" or "+")..amount(v).." "..stat[2] end
 end
 if #stats>0 then lines[#lines+1]="Stats: "..table.concat(stats,", ") end
 local unscored={}
 if U.Finite(item.crit) then unscored[#unscored+1]="+"..percent(item.crit).."% critical strike" end
 if U.Finite(item.hit) then unscored[#unscored+1]="+"..percent(item.hit).."% hit" end
 if item.effects then unscored[#unscored+1]="a proc, use or set effect (hover the item)" end
 if item.live then unscored[#unscored+1]="any \"Equip:\", \"Use:\", proc or set line (hover the item)" end
 if #unscored>0 then lines[#lines+1]="Not in the score: "..table.concat(unscored,", ") end
 if self:WindfuryFor(slot,role) then
  local ctx=self:WindfuryContext()
  local burst,parts=self:Windfury(item,ctx)
  if burst then
   lines[#lines+1]=string.format("\nWindfury burst (estimate): %d. One proc lands the swing and %d extra attacks at once:",math.floor(burst+.5),ctx.extra)
   lines[#lines+1]=string.format("%d x %s average damage + speed %.2f x (%d x %d attack power + %d x %d Windfury bonus) / 14%s",
    parts.swings,amount(math.floor(parts.avg*10+.5)/10),item.speed,parts.swings,math.floor(parts.ap+.5),ctx.extra,ctx.bonus,
    parts.chance>1 and string.format(", x %.2f for its crit and hit",parts.chance) or "")
   local base=item.equipLoc=="INVTYPE_2HWEAPON" and ctx.apTwoHand or ctx.ap
   lines[#lines+1]=string.format("Attack power %d: ",math.floor(base+.5))..ctx.apSource..(parts.own>0 and string.format("; plus %d from this weapon",math.floor(parts.own+.5)) or "").."."
   lines[#lines+1]=string.format("Windfury bonus %d (rank %d, %s): ",ctx.bonus,ctx.rank,ctx.rankSource)..ctx.bonusSource.."."
   lines[#lines+1]="It ranks the size of the hit. Damage over time follows weapon DPS, whatever the speed."
  end
 end
 -- where it comes from
 local where={}
 for i,kind in ipairs(item.sourceTypes) do
  where[#where+1]=kind=="Dungeon" and ("Dungeon: "..tostring(item.sources[i])) or (kind=="Drop" and "Drop with no dungeon listed (world, rare creature or raid)")
   or (kind=="Unknown" and "not known (the quest database names no source)") or self:SourceLabel(kind)
 end
 if item.logQuest then
  lines[#lines+1]="\n"..FP.GOLD.."In your quest log:|r "..(item.logQuest.kind=="choice" and "one of the reward choices of \"" or "a reward of \"")..item.logQuest.title.."\"."
  lines[#lines+1]="Where: "..table.concat(where," / ")
 else lines[#lines+1]="\nWhere: "..table.concat(where," / ") end
 if item.live then
  lines[#lines+1]="Not in the bundled item reference: what it is and its numbers were read from your client just now."
   ..(item.logQuest and "" or " Where it comes from is what the quest database lists (Classic data with Forever corrections).")
 end
 if type(item.requires)=="table" and #item.requires>0 then lines[#lines+1]="Requires: "..table.concat(item.requires," / ") end
 local theirs=self:Side(item)
 if theirs then
  local mine=API.GetCharInfo().faction
  lines[#lines+1]=theirs.." item"..((mine=="Horde" or mine=="Alliance") and mine~=theirs and (": not obtainable on a "..mine.." character.") or ".")
 end
 if #item.bosses>0 then lines[#lines+1]="Boss / container: "..table.concat(item.bosses,", ") end
 if item.droppedBy then
  lines[#lines+1]="Dropped by: "..item.droppedBy..(U.Finite(item.dropChance) and (" ("..percent(item.dropChance).."% listed drop chance)") or "")
 end
 if item.classes then lines[#lines+1]="Classes: "..item.classes end
 if item.restrictions then lines[#lines+1]="Check tooltip for additional skill, reputation, race or unique restrictions." end
 -- how it ranks, and against what is worn
 lines[#lines+1]="\nScore for "..self.profiles[role].name..": "..string.format("%.1f",row.score or 0).." · #"..tostring(row.rank).." in this list"
 local live=item.live and item or API.GetRewardItem("item:"..item.id)
 local liveScore=live and self:Score(live.stats,weights,slot)
 if item.live then -- the numbers are the client's already
 elseif not (live and live.stats) then lines[#lines+1]="Your client has not loaded this item yet: numbers are the reference's. Hover the row to load it."
 else
  local differs={}
  for _,stat in ipairs(self.stats) do
   local a,b=item.stats[stat[3]] or 0,live.stats[stat[3]] or 0
   if math.abs(a-b)>0.05 then differs[#differs+1]=stat[2].." "..amount(a).." -> "..amount(b) end
  end
  lines[#lines+1]=#differs==0 and "Reference stats match your client." or ("Your client shows other numbers (reference -> client): "..table.concat(differs,", "))
  if liveScore and #differs>0 then lines[#lines+1]="Current-client score: "..string.format("%.1f",liveScore) end
 end
 local candidate=liveScore or row.score
 local worn={}
 for _,s in ipairs(self.slots) do if s[1]==slot then
  for i=3,#s do
   local gear=API.GetRewardEquipment(s[i]);local score=self:Score(gear.stats,weights,slot)
   worn[s[i]]={gear=gear,score=score}
   lines[#lines+1]="Equipped "..s[2]..(#s>3 and " "..(i-2) or "")..": "..(gear.name or (gear.status=="empty" and "Empty" or "unavailable"))..
    (score and (" · "..string.format("%.1f",score)) or "")
   if liveScore and score and slot~="MAIN" and slot~="OFF" then lines[#lines+1]=string.format("Per-slot stat-score change: %+.1f",liveScore-score) end
  end
 end end
 if slot=="MAIN" and item.equipLoc=="INVTYPE_2HWEAPON" then
  -- A two-hander is weighed against everything it displaces.
  local main=worn[16]
  local off=API.GetRewardEquipment(17);local offScore=self:Score(off.stats,weights,"OFF")
  lines[#lines+1]="Equipped Off hand: "..(off.name or (off.status=="empty" and "Empty" or "unavailable"))..(offScore and (" · "..string.format("%.1f",offScore)) or "")
  if candidate and main and main.score and offScore then
   lines[#lines+1]=string.format("Two-hander takes both hands. Against the pair you wear: %+.1f",candidate-main.score-offScore)..(liveScore and "" or " (reference stats)")
  else lines[#lines+1]="Two-hander takes both hands: the off hand goes empty." end
  lines[#lines+1]="Weapon training for this type is your own check."
 elseif slot=="MAIN" or slot=="OFF" then
  lines[#lines+1]="Hand scores are individual. Two-hand swaps remove both hands; dual wield and weapon training require your own check."
 end
 lines[#lines+1]="\nEstimate only: procs, sets, hit/crit, weapon speed and unmodeled stats are not scored. A source in the reference does not confirm that the item is obtainable now."
 return table.concat(lines,"\n")
end
function G:OnEnable()
 local function refresh()
  local page=FP.Hub and FP.Hub.frame and FP.Hub.frame:IsShown() and FP.Hub.selected
  if page=="gear" or page=="dungeons" then
   FP.Throttle("gear-refresh",.25,function() if FP.Hub.selected==page then FP.Hub:Refresh() end end)
  end
 end
 for _,event in ipairs({"PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do FP:RegisterEvent(event,refresh) end
 -- while the live loader is reading items it refreshes the page itself, once a second
 FP:RegisterEvent("GET_ITEM_INFO_RECEIVED",function() if not (self.live and self.live.timer) then refresh() end end)
 -- a quest taken, handed in or dropped changes which rewards are "in your log"
 FP:RegisterEvent("QUEST_LOG_UPDATE",function()
  if not self.live then return end
  FP.Throttle("gear-live-log",2,function()
   self.live.logDirty=true
   local H=FP.Hub
   local page=H and H.frame and H.frame:IsShown() and H.selected
   if page=="gear" or page=="rewards" then self:LiveStart() end
  end)
 end)
 FP:RegisterEvent("PLAYER_REGEN_ENABLED",function() if self.live and self.live.paused then self:LiveStart() end end)
end
