local _, FP = ...
local D, API = FP.Dungeons, FP.API
local P = FP:NewModule("DungeonPanel")
local DUNGEON_ROWS, QUEST_ROWS = 17, 6

local function label(parent, x, y, width, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); text:SetJustifyH("LEFT")
    return text
end
local function button(parent, x, y, w, text, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, y); b:SetText(text); b:SetScript("OnClick", fn)
    return b
end

function P:OnInit()
    FP.cdb.dungeonChecklist = FP.cdb.dungeonChecklist or {}
    self.settings = FP.cdb.dungeonChecklist
    self.list, self.dungeonPage, self.questPage = D:List(), 1, 1
    local f = CreateFrame("Frame", "ForeverPathDungeons", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(820, 620); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
    f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=4,right=4,top=4,bottom=4}})
    f:SetBackdropColor(.04,.04,.07,.97)
    label(f, 16, -14, 730, "GameFontNormalLarge"):SetText("ForeverPath - Dungeon quests")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0); close:SetScript("OnClick", function() f:Hide() end)
    label(f, 16, -45, 210):SetText("Choose a dungeon (reference levels)")
    self.heading = label(f, 240, -43, 560, "GameFontNormal")
    self.summary = label(f, 240, -65, 560)
    self.dungeonButtons = {}
    for i=1,DUNGEON_ROWS do
        local b = button(f, 14, -74-(i-1)*25, 210, "", function(btn)
            if btn.key then self:Select(btn.key) end
        end)
        self.dungeonButtons[i] = b
    end
    self.dungeonPageLabel = label(f, 75, -507, 105)
    self.dungeonPrev = button(f, 14, -502, 50, "<", function() self.dungeonPage=math.max(1,self.dungeonPage-1); self:Refresh() end)
    self.dungeonNext = button(f, 174, -502, 50, ">", function() self.dungeonPage=math.min(math.ceil(#self.list/DUNGEON_ROWS),self.dungeonPage+1); self:Refresh() end)
    self.filter = button(f, 14, -539, 210, "", function()
        self.settings.all = not self.settings.all; self.questPage=1; self:Refresh()
    end)
    label(f, 16, -572, 210):SetText("Includes item starts and follow-ups.\nClick a quest for pickup and chain details.")
    self.questButtons = {}
    for i=1,QUEST_ROWS do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(560, 45); b:SetPoint("TOPLEFT", 240, -94-(i-1)*46)
        local hl = b:CreateTexture(nil,"HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,.08)
        b.title = label(b, 0, 0, 560, "GameFontHighlightSmall"); b.title:SetWordWrap(false)
        b.pickup = label(b, 0, -17, 560); b.pickup:SetWordWrap(false)
        b:SetScript("OnClick", function(btn)
            if btn.row then self.selectedQuest=btn.row.id; self:RefreshDetails(true) end
        end)
        b:SetScript("OnEnter", function(btn)
            if not btn.row then return end
            GameTooltip:SetOwner(btn,"ANCHOR_LEFT")
            GameTooltip:AddLine(btn.row.quest.name, 1,.82,0)
            GameTooltip:AddLine(D:Pickup(btn.row.quest),1,1,1,true)
            GameTooltip:AddLine("Click for prerequisites and full details.",.5,.8,1,true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.questButtons[i] = b
    end
    self.questPageLabel = label(f, 305, -379, 420)
    self.questPrev = button(f, 240, -374, 50, "<", function() self.questPage=math.max(1,self.questPage-1); self.selectedQuest=nil; self:Refresh() end)
    self.questNext = button(f, 750, -374, 50, ">", function() self.questPage=math.min(math.max(1,math.ceil(#self.rows/QUEST_ROWS)),self.questPage+1); self.selectedQuest=nil; self:Refresh() end)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    self.scroll = scroll
    scroll:SetPoint("TOPLEFT", 240, -412); scroll:SetSize(536, 155)
    local child = CreateFrame("Frame", nil, scroll); child:SetSize(530,155); scroll:SetScrollChild(child)
    self.detailChild, self.details = child, label(child, 0, 0, 525)
    label(f, 240, -584, 560):SetText("Reference list, not a guarantee of all current Forever quests or eligibility.")
    f:Hide()
end

function P:OnEnable()
    local function refresh()
        if not self.frame:IsShown() then return end
        FP.Throttle("dungeon-checklist", .3, function() self:Refresh() end)
    end
    for _, event in ipairs({"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "QUEST_POI_UPDATE"}) do
        FP:RegisterEvent(event, refresh)
    end
    FP:On("QUESTLOG_SCANNED", refresh)
end

function P:Select(key)
    if not FP.DungeonCatalog.dungeons[key] then return end
    self.settings.selected, self.questPage, self.selectedQuest = key, 1, nil
    self:Refresh()
end

function P:Open(query)
    local key = self.settings.selected
    if query and query ~= "" then
        local found = {}
        query = query:lower()
        for _, item in ipairs(self.list) do
            if item.key == query or item.data.name:lower() == query then found={item.key}; break end
            if item.data.name:lower():find(query,1,true) then found[#found+1]=item.key end
        end
        if #found ~= 1 then FP:Print(#found == 0 and "No matching dungeon. Choose one in the list." or "Several dungeons match. Choose a wing in the list.")
        else key=found[1] end
    end
    if not FP.DungeonCatalog.dungeons[key or ""] then
        local char = API.GetCharInfo()
        key = char.faction == "Alliance" and "hall-of-thanes" or "ragefire-chasm"
    end
    for i,item in ipairs(self.list) do if item.key == key then self.dungeonPage=math.ceil(i/DUNGEON_ROWS) end end
    self.frame:Show(); self:Select(key)
end

function P:RefreshDetails(reset)
    local selected
    for _, row in ipairs(self.rows or {}) do if row.id == self.selectedQuest then selected=row; break end end
    if not selected then selected=self.rows[(self.questPage-1)*QUEST_ROWS+1]; reset=true end
    self.selectedQuest = selected and selected.id
    local dungeon = FP.DungeonCatalog.dungeons[self.settings.selected]
    local empty = #dungeon.quests == 0 and "Quest coverage is not yet catalogued for this dungeon. This does not mean it has no quests."
        or "No quests match this faction/class filter. Use Show all factions/classes to inspect the reference list."
    self.details:SetText(selected and D:Details(selected,self.context) or empty)
    self.detailChild:SetHeight(math.max(155,self.details:GetStringHeight()+16))
    if reset then self.scroll:SetVerticalScroll(0) end
end

function P:Refresh()
    if not self.frame:IsShown() then return end
    local key = self.settings.selected
    local dungeon = FP.DungeonCatalog.dungeons[key or ""]
    if not dungeon then return end
    self.rows, self.counts, self.context = D:Rows(key,self.settings.all)
    self.questPage=math.max(1,math.min(self.questPage,math.ceil(#self.rows/QUEST_ROWS)))
    for i,b in ipairs(self.dungeonButtons) do
        local item=self.list[(self.dungeonPage-1)*DUNGEON_ROWS+i]
        if item then
            b.key=item.key
            b:SetText((item.key==key and FP.GOLD or "") .. item.data.name .. (#item.data.quests == 0 and " (?)" or "") .. "|r")
            b:Show()
        else b.key=nil; b:Hide() end
    end
    self.dungeonPageLabel:SetText("Page " .. self.dungeonPage .. "/" .. math.ceil(#self.list/DUNGEON_ROWS))
    self.filter:SetText(self.settings.all and "Filter to my faction/class" or "Show all factions/classes")
    self.heading:SetText(dungeon.name .. "  (" .. (dungeon.recommendedLevel or "level range unknown") .. ")")
    local c=self.counts
    self.summary:SetText(#dungeon.quests == 0 and "Coverage missing - quest list not yet catalogued"
        or (c.active .. " in log | " .. c.done .. " completed | " .. c.check .. " to check | " .. c.hidden .. " filtered"))
    for i,b in ipairs(self.questButtons) do
        local row=self.rows[(self.questPage-1)*QUEST_ROWS+i]; b.row=row
        if row then
            b.title:SetText(row.color .. row.label .. "|r - " .. row.quest.name)
            b.pickup:SetText(FP.GREY .. D:Pickup(row.quest) .. "|r"); b:Show()
        else b:Hide() end
    end
    self.questPageLabel:SetText(#self.rows .. " quests | Page " .. self.questPage .. "/" .. math.max(1,math.ceil(#self.rows/QUEST_ROWS)) .. " | Details below (scroll)")
    self:RefreshDetails()
end
