"""Transition regressions from the 2026-11-14 review. No client writes."""
REVIEW_FIX_CASES = {}

REVIEW_FIX_CASES['navigation_arrival_clears_after_continent_change'] = ('', '\nlocal q=addQuest(9001)\nFP.Planner.waiting={questID=9001,kind="objective",objIndex=1,mapID=1413,x=.6,y=.6,radius=35,title="Old objective"}\nM.mapID=1413;M.px=.6;M.py=.6;FP.Pos:Refresh(true)\nassert(FP.Planner:WaitingValid(),"control: at the objective")\nlocal world=C_Map.GetWorldPosFromMapPos\nC_Map.GetWorldPosFromMapPos=function(id,v) local _,p=world(id,v);return id==1413 and 1 or 2,p end\nM.mapID=1411;FP.Pos:Refresh(true)\nlocal d,_,same=FP.Pos:VectorTo(FP.Planner.waiting)\nprint("distance="..tostring(d).."; same continent="..tostring(same).."; waiting="..tostring(FP.Planner:WaitingValid()))\nassert(not FP.Planner:WaitingValid(),"arrival wait survives leaving the continent")\n')

REVIEW_FIX_CASES["arrival_wait_preserves_unavailable_position"] = ("", r'''
addQuest(9001)
FP.Planner.waiting={questID=9001,kind="objective",objIndex=1,mapID=1413,x=.6,y=.6,radius=35}
M.noPosition=true;FP.Pos:Refresh(true)
assert(FP.Planner:WaitingValid(),"unavailable position must not imply departure")
M.noPosition=false;M.px=.1;M.py=.1;FP.Pos:Refresh(true)
assert(not FP.Planner:WaitingValid(),"walking away still releases arrival")
''')
