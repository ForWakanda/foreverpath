local _,FP=...
local P=FP:NewModule("GearPanel")
local G,API=FP.Gear,FP.API
local SOURCES={"All","Dungeon","Quest","Crafted","Vendor","Drop","Reputation","Raid","PvP"}
local function text(parent,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
 t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");return t
end
function P:Build(H,p)
 self.filter={slot="HEAD",source="All"}
 H:Actions(p,{
  {"gearProfile","Role",function()
   local key,_,keys=G:Profile();for i,k in ipairs(keys) do if key==k then FP.cdb.gear.profile=keys[i%#keys+1];break end end
   self.list.page=1;self.list.selected=nil
  end},
  {"gearSource","Source",function()
   for i,v in ipairs(SOURCES) do if v==self.filter.source then self.filter.source=SOURCES[i%#SOURCES+1];break end end
   self.list.page=1;self.list.selected=nil
  end},
  {"gearWeights","Edit stat weights",function() self:Weights(H) end},
 })
 local search=H:Field(p,"gearSearch","Search item / source","")
 local level=H:Field(p,"gearLevel","Maximum level / item-level estimate (1–60)",API.PlayerLevel() or 60)
 local function apply()
  local n=tonumber(level:GetText())
  if not n or n<1 or n>60 or n~=math.floor(n) then self.invalid=true else self.invalid=nil;self.filter.level=n end
  self.filter.query=search:GetText();self.list.page=1;self.list.selected=nil;H:Refresh()
 end
 search:SetScript("OnTextChanged",apply);level:SetScript("OnTextChanged",apply)
 for first=1,#G.slots,5 do
  local defs={}
  for i=first,math.min(first+4,#G.slots) do
   local slot=G.slots[i]
   defs[#defs+1]={"gearSlot"..slot[1],slot[2],function() self.filter.slot=slot[1];self.list.page=1;self.list.selected=nil end}
  end
  H:Actions(p,defs)
 end
 local top=p.y
 self.sourceIndex=1
 self.list=H:List(p,"gearItems",function()
  if self.invalid then self.message="Enter a whole level from 1 to 60.";return {} end
  local rows,message=G:Rows(self.filter);self.message=message
  if self.wishlist then
   local kept={};for _,r in ipairs(rows) do if FP.cdb.gear.wishlist[r.key] then kept[#kept+1]=r end end;rows=kept
   if #rows==0 then self.message="No wishlist items match these filters." end
  end
  local found=false;for _,r in ipairs(rows) do if r.key==self.list.selected then found=true end end
  if not found then self.list.selected=rows[1] and rows[1].key end
  return rows
 end,function(r) return (FP.cdb.gear.wishlist[r.key] and "* " or "")..r.item.name.." · "..string.format("%.1f",r.score or 0) end,{width=286,count=6})
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
 local scroll=CreateFrame("ScrollFrame",nil,p.body,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",304,-top);scroll:SetSize(278,202)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(270,202);scroll:SetScrollChild(body)
 self.details=text(body,0,0,266);self.detailScroll=scroll
 H:Actions(p,{
  {"gearSave","Save to wishlist",function()
   local row=H:Selected(self.list);if row then FP.cdb.gear.wishlist[row.key]=not FP.cdb.gear.wishlist[row.key] or nil end
  end,enabled=function() return H:Selected(self.list)~=nil and not API.InCombat() end},
  {"gearWishlist","Show wishlist",function() self.wishlist=not self.wishlist;self.list.page=1;self.list.selected=nil end},
  {"gearDungeon","Dungeon checklist",function()
   local row=H:Selected(self.list);if row then
    local choices=self:Dungeons(row);local choice=choices[self.dungeonIndex or 1];if choice then H.frame:Hide();FP.DungeonPanel:Open(choice.key) end
   end
  end,enabled=function() local r=H:Selected(self.list);return r and self:Dungeon(r)~=nil end},
 })
 H:Actions(p,{{"gearNextDungeon","Other dungeon wing",function()
  local row=H:Selected(self.list);local choices=row and self:Dungeons(row) or {}
  if #choices>0 then self.dungeonIndex=(self.dungeonIndex or 1)%#choices+1 end
 end,enabled=function() local row=H:Selected(self.list);return row and #self:Dungeons(row)>1 end}})
 H:Actions(p,{
  {"gearQuestSource","View quest source",function()
   local q=self.questSources and self.questSources[self.sourceIndex]
   if q then H:OpenQuestChain(q.id) end
  end,enabled=function() return self.questSources and self.questSources[self.sourceIndex]~=nil end},
  {"gearNextQuestSource","Next quest source",function() self.sourceIndex=self.sourceIndex%#self.questSources+1 end,
   enabled=function() return self.questSources and #self.questSources>1 end},
 })
 H:Check(p,"gearUnknown","No required level listed: allow 5 item levels above the limit",function() return self.filter.unknown end,function(v) self.filter.unknown=v;self.list.page=1 end)
 self.status=H:Text(p,"")
 p.y=p.y+32
 H:Text(p,"Rankings use editable stat weights and a dated Forever reference catalog. They are estimates, not a complete BiS simulation. Source labels do not guarantee current availability. Hover an item for its live tooltip.")
 table.insert(p.refreshers,function()
  local _,profile=G:Profile()
  H.controls.gearProfile:SetText("Role: "..profile.name)
  H.controls.gearSource:SetText("Source: "..self.filter.source)
  H.controls.gearWishlist:SetText(self.wishlist and "Show all gear" or "Show wishlist")
  for _,s in ipairs(G.slots) do H.controls["gearSlot"..s[1]]:SetText((s[1]==self.filter.slot and FP.GOLD.."> " or "")..s[2].."|r") end
  local row=H:Selected(self.list)
  H.controls.gearSave:SetText(row and FP.cdb.gear.wishlist[row.key] and "Remove from wishlist" or "Save to wishlist")
  local choices=row and self:Dungeons(row) or {}
  local choice=choices[self.dungeonIndex or 1]
  local details=G:Details(row,self.filter.slot)
  if choice then details=details.."\n\nDungeon source: "..choice.data.name..(#choices>1 and " (choose the appropriate wing with Other dungeon wing)." or "") end
  if #self.questSources>0 then
   local q=self.questSources[self.sourceIndex]
   details=details.."\n\nQuest source "..self.sourceIndex.."/"..#self.questSources..": "..q.name.." (#"..q.id..")\nQuest requires level "..tostring(q.requiredLevel or "unknown")..". Inspect its chain for restrictions and pickup guidance."
  end
  H.controls.gearQuestSource:SetText(#self.questSources>0 and ("View quest source "..self.sourceIndex.."/"..#self.questSources) or "Quest source unavailable")
  self.details:SetText(details);body:SetHeight(math.max(202,self.details:GetStringHeight()+12))
  local identity=tostring(row and row.key)..":"..self.filter.slot
  if identity~=self.detailIdentity then scroll:SetVerticalScroll(0);self.detailIdentity=identity end
  self.status:SetText(self.message or (#self.list.items.." matches · reference updated "..(FP.GearCatalog and FP.GearCatalog.date or "unavailable").." · best scored first"))
 end)
end
function P:Dungeons(row)
 local out,seen={},{}
 for i,kind in ipairs(row.item.sourceTypes) do
  if kind=="Dungeon" then
   local query=row.item.sources[i]:lower()
   if query=="temple of atal'hakkar" then query="sunken temple" end
   for _,d in ipairs(FP.Dungeons:List()) do
    if d.data.name:lower():find(query,1,true) and not seen[d.key] then out[#out+1]=d;seen[d.key]=true end
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
  text(f,18,-18,410):SetText("Stat weights · points per stat (0–100)\nStarting priorities are estimates. Zero ignores a stat.")
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
 self.weightProfile=G:Profile();local weights=G:Weights()
 for _,s in ipairs(G.stats) do self.weightFields[s[1]]:SetText(tostring(weights[s[1]] or 0)) end
 self.weightError:SetText("");self.weightsFrame:Show()
end
