"""Dungeon quests: one dungeon chosen on the page, a quest held under its other number,
and a list that says what to pick up now and where (v0.32.0). Mock-only.

The report (level 60 shaman, 2026-11-22): he clicked Scholomance under "Which dungeon
next", scrolled down, pressed "Open quest checklist" and got Dire Maul: East; the
Scholomance list then sent him to Orgrimmar to pick up The Darkreaver Menace, which was
already in his log; and the list did not say what to pick up next or where.
Causes: the page kept two dungeon selections; the bundled list knows that quest as 7668
while the game gave him 8258 (the quest database marks the two exclusive to each other);
and the list mixed today's pickups with quests many steps away.
These cases use the shipped catalogue with a quest database shaped like the real one.
"""
from dungeon_next import NEXT


def cases(hub):
    return {
        # report 1: clicked Scholomance in the ranking, "Open quest checklist" showed another dungeon
        'which_dungeon_next_click_chooses_the_dungeon_for_the_whole_page': NEXT + hub + r'''
page("dungeons")
local nextList,it=H.controls.dungeonNext,H.controls.hubDungeons
-- the page opens with both lists on the same dungeon
assert(it.selected~=nil and nextList.selected==it.selected)
-- pick one in the ranking that is not the one the itinerary opened on
local n;for i,b in ipairs(nextList.rows) do if b.item and b.item.key~=it.selected then n=i;break end end
local key=nextList.rows[n].item.key
selectRow("dungeonNext",n)
-- the itinerary below is that dungeon's, on the page of the list that shows it, with no further click
assert(it.selected==key and H:Selected(it) and H:Selected(it).key==key, "the itinerary kept the other dungeon")
local shown;for _,b in ipairs(it.rows) do if b.item and b.item.key==key then shown=true end end
assert(shown and H.controls.dungeonSummary:GetText():find(FP.DungeonCatalog.dungeons[key].name,1,true))
-- and the checklist button at the bottom opens that dungeon, not the one the page opened on
click("openDungeonChecklist")
assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==key, "opened "..tostring(FP.DungeonPanel.settings.selected).." instead of "..key)
assert(FP.DungeonPanel.heading:GetText():find(FP.DungeonCatalog.dungeons[key].name,1,true))
-- the button under the ranking does the same
FP.DungeonPanel.frame:Hide();page("dungeons")
local other;for i,b in ipairs(nextList.rows) do if b.item and b.item.key~=key then other=i;break end end
local otherKey=nextList.rows[other].item.key
selectRow("dungeonNext",other);assert(H.controls.dungeonNextOpen:GetText()=="Open its quest checklist")
click("dungeonNextOpen");assert(FP.DungeonPanel.frame:IsShown() and FP.DungeonPanel.settings.selected==otherKey and not H.frame:IsShown())
-- choosing in the itinerary list moves the ranking's mark too: the two never name different dungeons
FP.DungeonPanel.frame:Hide();page("dungeons")
for i,b in ipairs(it.rows) do if b.item and b.item.key~=it.selected then selectRow("hubDungeons",i);break end end
assert(nextList.selected==it.selected)
local marked=H:Selected(nextList)
assert(marked==nil or marked.key==it.selected)
-- a dungeon the ranking does not list: nothing is marked there, and its button is off
if not marked then assert(not H.controls.dungeonNextOpen:IsEnabled() and H.controls.dungeonNextDetails:GetText():find("Select a dungeon",1,true)) end
click("openDungeonChecklist");assert(FP.DungeonPanel.settings.selected==it.selected)
assert(#FP.db.errors==0)
''',
    }
