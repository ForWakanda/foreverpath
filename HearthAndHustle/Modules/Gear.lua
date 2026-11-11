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
function G:Weights()
 local key,p=self:Profile()
 local out={ranged=key=="ranged"}
 for _,s in ipairs(self.stats) do
  local custom=FP.cdb.gear.weights[key] and FP.cdb.gear.weights[key][s[1]]
  out[s[1]]=U.Finite(custom) and custom>=0 and custom<=100 and custom or p[s[1]] or 0
 end
 return out
end
function G:Score(stats,weights,slot)
 if type(stats)~="table" then return nil end
 local total=0
 for _,s in ipairs(self.stats) do
  -- Ranged DPS does not improve melee, and a hunter's melee DPS is not ranged DPS.
  local value=stats[s[3]] or 0
  if s[1]=="spell" then value=stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT or stats.ITEM_MOD_SPELL_POWER_SHORT or 0
  elseif s[1]=="heal" then value=stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT or stats.ITEM_MOD_SPELL_POWER_SHORT or 0 end
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
-- Quest rewards rarely list a required level and their item level tracks the
-- quest level; quests a few levels above the character are routinely done.
G.PROXY_MARGIN=5
function G:Rows(filter)
 local rows={}
 if API.InCombat() then return rows,"Gear browsing resumes after combat." end
 if not API.EnsureGearCatalog() then return rows,"Gear data unavailable. Install both Hearth & Hustle folders and restart WoW." end
 local char=API.GetCharInfo()
 if not U.Finite(char.level) or not armorMax[char.class] then return rows,"Character information unavailable." end
 local max=filter.level or char.level
 local query=U.Trim(filter.query or ""):lower()
 local weights=self:Weights()
 for _,item in ipairs(FP.GearCatalog.items) do
  local known=U.Finite(item.minLevel)
  local proxy=not known and U.Finite(item.level) and item.level or nil
  local source=filter.source or "All"
  if self:SlotMatches(item,filter.slot or "HEAD") and self:ClassMatches(item,char)
   and ((known and item.minLevel<=max) or (proxy and proxy<=max+(filter.unknown and G.PROXY_MARGIN or 0)) or (not known and not proxy and filter.unknown))
   and (source=="All" or contains(item.sourceTypes,source))
   and (query=="" or item.name:lower():find(query,1,true) or tostring(item.id)==query or table.concat(item.sources," "):lower():find(query,1,true)) then
   rows[#rows+1]={key=item.id,item=item,score=self:Score(item.stats,weights,filter.slot)}
  end
 end
 table.sort(rows,function(a,b) if a.score~=b.score then return (a.score or -1)>(b.score or -1) end return a.item.id<b.item.id end)
 for i,row in ipairs(rows) do row.rank=i end
 return rows,#rows==0 and "No matching items. Try another slot, source, level, or include unknown level requirements." or nil
end
function G:Details(row,slot)
 if API.InCombat() then return "Gear comparisons resume after combat." end
 if not row then return "Choose an item to see its stats, source and equipped comparison." end
 local item=row.item
 local lines={FP.GOLD..item.name.."|r  ·  #"..item.id,
  "Reference score: "..string.format("%.1f",row.score or 0).." · rank "..row.rank.." in this filtered list",
  "Requires level: "..tostring(item.minLevel or "unknown").." · "..item.subtype.." · item level "..tostring(item.level or "?"),
  "Source reference: "..table.concat(item.sources,", ")}
 if not item.minLevel and item.level then lines[#lines+1]="Level filter uses item level as an estimate; check the quest/source requirements before pursuing it." end
 if #item.bosses>0 then lines[#lines+1]="Boss / container: "..table.concat(item.bosses,", ") end
 if item.classes then lines[#lines+1]="Classes: "..item.classes end
 if item.restrictions then lines[#lines+1]="Check tooltip for additional skill, reputation, race or unique restrictions." end
 lines[#lines+1]="\nNumeric stats (reference / current client):"
 local live=API.GetRewardItem("item:"..item.id)
 for _,stat in ipairs(self.stats) do
  local a=item.stats[stat[3]]
  local b=live and live.stats and live.stats[stat[3]]
  if a or b then lines[#lines+1]=stat[2]..": "..tostring(a or 0).." / "..(live and live.stats and tostring(b or 0) or "loading") end
 end
 local liveScore=live and self:Score(live.stats,self:Weights(),slot)
 lines[#lines+1]="Current-client score: "..(liveScore and string.format("%.1f",liveScore) or "unavailable")
 for _,s in ipairs(self.slots) do if s[1]==slot then
  for i=3,#s do
   local gear=API.GetRewardEquipment(s[i]);local score=self:Score(gear.stats,self:Weights(),slot)
   lines[#lines+1]="Equipped "..s[2]..(#s>3 and " "..(i-2) or "")..": "..(gear.name or (gear.status=="empty" and "Empty" or "unavailable"))..
    (score and (" · "..string.format("%.1f",score)) or "")
   if liveScore and score and slot~="MAIN" and slot~="OFF" then lines[#lines+1]=string.format("Per-slot stat-score change: %+.1f",liveScore-score) end
  end
 end end
 if slot=="MAIN" or slot=="OFF" then lines[#lines+1]="Hand scores are individual. Two-hand swaps remove both hands; dual wield and weapon training require your own check." end
 lines[#lines+1]="\nEstimate only: procs, sets, hit/crit caps, weapon speed and unmodeled stats are not scored. A source in the database does not confirm that it is currently obtainable."
 return table.concat(lines,"\n")
end
function G:OnEnable()
 local function refresh()
  if FP.Hub and FP.Hub.frame and FP.Hub.frame:IsShown() and FP.Hub.selected=="gear" then
   FP.Throttle("gear-refresh",.25,function() if FP.Hub.selected=="gear" then FP.Hub:Refresh() end end)
  end
 end
 for _,event in ipairs({"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do FP:RegisterEvent(event,refresh) end
end
