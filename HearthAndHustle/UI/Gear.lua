local _,FP=...
local P=FP:NewModule("GearPanel")
local G,API,U=FP.Gear,FP.API,FP.Util
local W=600
local function text(parent,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
 t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");return t
end
-- The choice after `current` in a cycle; the first one when `current` is not in it.
local function after(list,current)
 for i,v in ipairs(list) do if v==current then return list[i%#list+1] end end
 return list[1]
end
function P:Reset() self.list.page=1;self.list.selected=nil end
-- Everything the page shows comes from one pass, so the buttons, the summary
-- line and the list always describe the same filter.
function P:Compute()
 self.role=G:Browse()
 self.filter.role=self.role
 self.weights=G:Weights(self.role)
 self.hidden=0
 if self.invalid then self.rows,self.message,self.types={}, "Enter a whole level from 1 to 60.",{};return end
 local rows,message,types,hidden=G:Rows(self.filter)
 self.hidden=hidden or 0
 if self.wishlist then
  local kept={};for _,r in ipairs(rows) do if FP.cdb.gear.wishlist[r.key] then kept[#kept+1]=r end end;rows=kept
  if #rows==0 then message="No wishlist items match these filters." end
 end
 self.rows,self.message,self.types=rows,message,types or {}
end
-- "87 items · Main hand · two-hand · Mace · up to level 60 · World drop · ranked for Strength melee"
function P:Summary()
 local f=self.filter
 local parts={FP.GOLD..#self.rows.." item"..(#self.rows==1 and "" or "s").."|r"}
 for _,s in ipairs(G.slots) do if s[1]==f.slot then parts[#parts+1]=s[2] end end
 if f.slot=="MAIN" and f.hands and f.hands~="any" then parts[#parts+1]=G.handLabels[f.hands]:lower().." only" end
 if f.subtype then parts[#parts+1]=f.subtype end
 parts[#parts+1]="up to level "..tostring(f.level or API.PlayerLevel() or "?")
 parts[#parts+1]=f.source=="All" and "any source" or G:SourceLabel(f.source):lower()
 if self.wishlist then parts[#parts+1]="wishlist only" end
 if U.Trim(f.query or "")~="" then parts[#parts+1]="matching \""..U.Trim(f.query).."\"" end
 local _,profile=G:Browse()
 parts[#parts+1]="ranked for "..FP.GOLD..profile.name.."|r"
 local sort=f.sort or "score"
 parts[#parts+1]=sort=="score" and "best score first" or (sort=="dps" and "highest weapon DPS first" or "biggest hits first")
 if self.hidden>0 then parts[#parts+1]=self.hidden.." of the other faction's left out" end
 return table.concat(parts," · ")
end
function P:Build(H,p)
 self.filter={slot="HEAD",source="All"}
 self.rows,self.types={},{}
 table.insert(p.refreshers,function() self:Compute() end)
 H:Actions(p,{
  {"gearProfile","Ranked for",function()
   local key,_,keys=G:Browse();FP.cdb.gear.browse=after(keys,key);self:Reset()
  end,enabled=function() local _,_,keys=G:Browse();return #keys>1 end},
  {"gearSource","Source",function() self.filter.source=after(G:Sources(),self.filter.source);self:Reset() end},
  {"gearSort","Sort",function() self.filter.sort=after(G.sorts,self.filter.sort or "score");self:Reset() end,
   enabled=function() return G:IsWeaponSlot(self.filter.slot) end},
 })
 H:Actions(p,{
  {"gearHands","Hands",function() self.filter.hands=after(G.hands,self.filter.hands or "any");self:Reset() end,
   enabled=function() return self.filter.slot=="MAIN" end},
  {"gearType","Type",function()
   local choices={"any"};for _,t in ipairs(self.types) do choices[#choices+1]=t end
   local pick=after(choices,self.filter.subtype or "any")
   self.filter.subtype=pick~="any" and pick or nil;self:Reset()
  end,enabled=function() return #self.types>1 or self.filter.subtype~=nil end},
  {"gearWeights","Edit stat weights",function() self:Weights(H) end},
 })
 -- search and level share one line
 local function field(id,label,x,labelWidth,width,value)
  text(p.body,x,-p.y-7,labelWidth):SetText(label)
  local e=CreateFrame("EditBox",nil,p.body,"InputBoxTemplate")
  e:SetSize(width,24);e:SetPoint("TOPLEFT",x+labelWidth+8,-p.y);e:SetAutoFocus(false)
  e:SetMaxLetters(64);e:SetText(tostring(value));e:ClearFocus()
  e:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
  e:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
  H.controls[id]=e;p.fields[#p.fields+1]=e
  return e
 end
 local search=field("gearSearch","Search name / source",0,124,196,"")
 local level=field("gearLevel","Up to level (1-60)",356,112,56,API.PlayerLevel() or 60)
 p.y=p.y+32
 local function apply()
  local n=tonumber(level:GetText())
  if not n or n<1 or n>60 or n~=math.floor(n) then self.invalid=true else self.invalid=nil;self.filter.level=n end
  self.filter.query=search:GetText();self:Reset();H:Refresh()
 end
 search:SetScript("OnTextChanged",apply);level:SetScript("OnTextChanged",apply)
 for first=1,#G.slots,5 do
  local defs={}
  for i=first,math.min(first+4,#G.slots) do
   local slot=G.slots[i]
   defs[#defs+1]={"gearSlot"..slot[1],slot[2],function()
    -- hands, type and a weapon sort belong to the slot they were chosen for
    if self.filter.slot~=slot[1] then self.filter.subtype=nil;self.filter.hands=nil;self.filter.sort=nil end
    self.filter.slot=slot[1];self:Reset()
   end}
  end
  H:Actions(p,defs);p.y=p.y-6
 end
 p.y=p.y+8
 self.status=H:Text(p,"",nil,30)
 self.sourceIndex=1
 self.list=H:List(p,"gearItems",function()
  local found=false;for _,r in ipairs(self.rows) do if r.key==self.list.selected then found=true end end
  if not found then self.list.selected=self.rows[1] and self.rows[1].key end
  return self.rows
 end,function(r) return (FP.cdb.gear.wishlist[r.key] and "* " or "")..G:RowText(r,self.weights) end,
  {count=6,color=function(r) return G:QualityColor(r.item) end})
 for _,b in ipairs(self.list.rows) do
  b:SetScript("OnEnter",function(btn)
   if not btn.item then return end
   GameTooltip:SetOwner(btn,"ANCHOR_RIGHT")
   if GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("item:"..btn.item.key) else GameTooltip:AddLine(btn.item.item.name,1,1,1,true) end
   GameTooltip:Show()
  end)
 end
 table.insert(p.refreshers,function()
  local row=H:Selected(self.list)
  if self.sourceItem~=(row and row.key) then self.sourceItem=row and row.key;self.sourceIndex=1;self.dungeonIndex=1 end
  self.questSources=row and API.GetGearQuestSources(row.key) or {}
  self.sourceIndex=math.min(self.sourceIndex,math.max(1,#self.questSources))
 end)
 -- the selected item, directly under the list
 local scroll=CreateFrame("ScrollFrame",nil,p.body,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",0,-p.y);scroll:SetSize(W-28,172)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(W-36,172);scroll:SetScrollChild(body)
 self.details=text(body,0,0,W-40);self.detailScroll=scroll
 p.y=p.y+182
 H:Actions(p,{
  {"gearSave","Save to wishlist",function()
   local row=H:Selected(self.list);if row then FP.cdb.gear.wishlist[row.key]=not FP.cdb.gear.wishlist[row.key] or nil end
  end,enabled=function() return H:Selected(self.list)~=nil and not API.InCombat() end},
  {"gearWishlist","Show wishlist",function() self.wishlist=not self.wishlist;self:Reset() end},
  {"gearDungeon","Dungeon checklist",function()
   local row=H:Selected(self.list);if row then
    local choices=self:Dungeons(row);local choice=choices[self.dungeonIndex or 1];if choice then H.frame:Hide();FP.DungeonPanel:Open(choice.key) end
   end
  end,enabled=function() local r=H:Selected(self.list);return r and self:Dungeon(r)~=nil end},
  {"gearNextDungeon","Other dungeon wing",function()
   local row=H:Selected(self.list);local choices=row and self:Dungeons(row) or {}
   if #choices>0 then self.dungeonIndex=(self.dungeonIndex or 1)%#choices+1 end
  end,enabled=function() local row=H:Selected(self.list);return row and #self:Dungeons(row)>1 end},
 })
 H:Actions(p,{
  {"gearQuestSource","View quest source",function()
   local q=self.questSources and self.questSources[self.sourceIndex]
   if q then H:OpenQuestChain(q.id) end
  end,enabled=function() return self.questSources and self.questSources[self.sourceIndex]~=nil end},
  {"gearNextQuestSource","Next quest source",function() self.sourceIndex=self.sourceIndex%#self.questSources+1 end,
   enabled=function() return self.questSources and #self.questSources>1 end},
  -- The one place the character's own role changes; browsing never does it.
  {"gearMyRole","My role",function() FP.cdb.gear.profile=G:Browse() end,
   enabled=function() local key,_,_,own=G:Browse();return key~=own and not API.InCombat() end},
 })
 H:Check(p,"gearUnknown","No required level listed: allow 5 item levels above the limit",function() return self.filter.unknown end,function(v) self.filter.unknown=v;self.list.page=1 end)
 H:Check(p,"gearOtherFaction","Show the other faction's reputation and honor-rank items too",function() return self.filter.otherFaction end,function(v) self.filter.otherFaction=v or nil;self.list.page=1 end)
 self.note=H:Text(p,"",nil,76)
 table.insert(p.refreshers,function()
  local key,profile,keys,own=G:Browse()
  local f=self.filter
  H.controls.gearProfile:SetText("Ranked for: "..profile.name)
  H.controls.gearSource:SetText("Source: "..(f.source=="All" and "Any" or G:SourceLabel(f.source)))
  H.controls.gearSort:SetText("Sort: "..G.sortLabels[f.sort or "score"])
  H.controls.gearHands:SetText("Hands: "..G.handLabels[f.slot=="MAIN" and f.hands or "any"])
  H.controls.gearType:SetText("Type: "..(f.subtype or "Any"))
  H.controls.gearMyRole:SetText(key==own and ("My role: "..profile.name) or ("Make "..profile.name.." my role"))
  H.controls.gearWishlist:SetText(self.wishlist and "Show all gear" or "Show wishlist")
  for _,s in ipairs(G.slots) do H.controls["gearSlot"..s[1]]:SetText((s[1]==f.slot and FP.GOLD.."> " or "")..s[2].."|r") end
  local row=H:Selected(self.list)
  H.controls.gearSave:SetText(row and FP.cdb.gear.wishlist[row.key] and "Remove from wishlist" or "Save to wishlist")
  local choices=row and self:Dungeons(row) or {}
  local choice=choices[self.dungeonIndex or 1]
  local details=G:Details(row,f.slot,key)
  if choice then details=details.."\n\nDungeon source: "..choice.data.name..(#choices>1 and " (choose the appropriate wing with Other dungeon wing)." or "") end
  if #self.questSources>0 then
   local q=self.questSources[self.sourceIndex]
   details=details.."\n\nQuest source "..self.sourceIndex.."/"..#self.questSources..": "..q.name.." (#"..q.id..")\nQuest requires level "..tostring(q.requiredLevel or "unknown")..". Inspect its chain for restrictions and pickup guidance."
  end
  H.controls.gearQuestSource:SetText(#self.questSources>0 and ("View quest source "..self.sourceIndex.."/"..#self.questSources) or "Quest source unavailable")
  self.details:SetText(details);body:SetHeight(math.max(172,self.details:GetStringHeight()+12))
  local identity=tostring(row and row.key)..":"..f.slot
  if identity~=self.detailIdentity then scroll:SetVerticalScroll(0);self.detailIdentity=identity end
  self.status:SetText(self.message and (self.message..(self.hidden>0 and (" "..self.hidden.." of the other faction's were left out.") or "")) or self:Summary())
  local mine=G.profiles[own].name
  self.note:SetText((#keys>1 and ("Your own role is "..FP.GOLD..mine.."|r: the Healing page and the dungeon drop lists follow it. \"Ranked for\" only changes what this page shows"
   ..(key~=own and ("; use \"Make "..profile.name.." my role\" to switch for good.") or ".").."\n") or "")
   .."Rows are tinted by item quality. Rankings use editable stat weights and a reference catalog dated "..(FP.GearCatalog and FP.GearCatalog.date or "unavailable")
   ..": estimates, not a simulation, and a listed source does not guarantee the item is obtainable now. Hover a row for the live tooltip.")
 end)
end
function P:Dungeons(row)
 local out,seen={},{}
 for i,kind in ipairs(row.item.sourceTypes) do
  if kind=="Dungeon" then
   for _,d in ipairs(FP.Dungeons:List()) do
    if G:SourceIsDungeon(row.item.sources[i],d.data.name) and not seen[d.key] then out[#out+1]=d;seen[d.key]=true end
   end
  end
 end
 return out
end
function P:Dungeon(row)
 local choices=self:Dungeons(row)
 return choices[1] and choices[1].data.name
end
function P:Weights(H)
 if not self.weightsFrame then
  local f=CreateFrame("Frame",nil,H.frame,"BackdropTemplate");self.weightsFrame=f
  f:SetSize(450,480);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:EnableMouse(true)
  f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
  f:SetBackdropColor(.035,.045,.065,1)
  self.weightTitle=text(f,18,-18,410)
  self.weightFields={}
  for i,s in ipairs(G.stats) do
   text(f,20,-62-(i-1)*29,240):SetText(s[2])
   local e=CreateFrame("EditBox",nil,f,"InputBoxTemplate");e:SetSize(120,24);e:SetPoint("TOPLEFT",280,-56-(i-1)*29);e:SetAutoFocus(false);e:ClearFocus();e:SetMaxLetters(8)
   e:SetScript("OnEscapePressed",function() f:Hide() end);self.weightFields[s[1]]=e
  end
  local function button(label,x,fn)
   local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(125,26);b:SetPoint("TOPLEFT",x,-400);b:SetText(label);b:SetScript("OnClick",fn)
   return b
  end
  self.weightError=text(f,20,-441,410)
  self.weightApply=button("Save weights",20,function()
   local values={}
   for _,s in ipairs(G.stats) do
    local n=tonumber(self.weightFields[s[1]]:GetText())
    if not FP.Util.Finite(n) or n<0 or n>100 then self.weightError:SetText("Enter a number from 0 to 100 for "..s[2]..".");return end
    values[s[1]]=n
   end
   FP.cdb.gear.weights[self.weightProfile]=values;f:Hide();H:Refresh()
  end)
  self.weightReset=button("Reset preset",160,function() FP.cdb.gear.weights[self.weightProfile]=nil;f:Hide();H:Refresh() end)
  button("Cancel",300,function() f:Hide() end)
  f:SetScript("OnHide",function() for _,e in pairs(self.weightFields) do e:ClearFocus() end end)
 end
 -- the weights of the role on screen, which is the one the list is ranked for
 local key,profile=G:Browse()
 self.weightProfile=key;local weights=G:Weights(key)
 self.weightTitle:SetText("Stat weights for "..profile.name.." · points per stat (0–100)\nStarting priorities are estimates. Zero ignores a stat.")
 for _,s in ipairs(G.stats) do self.weightFields[s[1]]:SetText(tostring(weights[s[1]] or 0)) end
 self.weightError:SetText("");self.weightsFrame:Show()
end
