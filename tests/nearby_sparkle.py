"""Nearby-object sparkles are retired (v0.27.1). What these cases hold is the undo:
a profile that switched the v0.27.0 mode on gets its game settings back, and
nothing can switch the mode on again.

Each case is (preload, body). The preload runs before the addon loads, so it
sets the saved profile and the client's settings as a login finds them.
"""

# The owner's account as saved on 2026-11-16 after the v0.27.0 session: the mode
# on, five of the seven settings changed, the earlier values written down by
# setup (the range as the client prints it, "10.000000").
OWNER_DB = r'''
HearthAndHustleDB={settings={record=true,probe={enabled=true},questSparkle={enabled=true,nearby=true}},
 questSparkle={ours=true,count=1,introduced=true,
  observed={outline=true,version="0.27.0",value="1",t=1794866576,reason="setting",build="70938"},
  nearby={attachments=4,
   last={state="no object",version="0.27.0",t=1794866709,build="70938"},
   lastAttached={state="display attached",version="0.27.0",t=1794866706,build="70938",
    name="Un'Goro Dirt Pile",guid="GameObject-0-6834-1-2-157936-18EB97D73E"},
   restore={
    {before="10.000000",name="SoftTargetInteractRange",applied="15"},
    {before="0",name="SoftTargetInteractArc",applied="2"},
    {before="0",name="SoftTargetNameplateInteract",applied="1"},
    {before="0",name="SoftTargetIconGameObject",applied="1"},
    {before="1",name="SoftTargetInteract",applied="3"},
   }}}}
'''
# The client as that session left it (WTF config-cache.wtf, same day).
OWNER_CLIENT = r'''
M.cvars.outlineModeShowLootEffectWhenDisabled="1"
M.cvars.SoftTargetInteractRange="15"; M.cvars.SoftTargetInteractArc="2"
M.cvars.SoftTargetInteractOnlyInRange="0"; M.cvars.SoftTargetNameplateInteract="1"
M.cvars.SoftTargetIconInteract="1"; M.cvars.SoftTargetIconGameObject="1"; M.cvars.SoftTargetInteract="3"
'''
OWNER = OWNER_DB + OWNER_CLIENT
# A client that never had the mode: the game's defaults.
DEFAULT_CLIENT = r'''
M.cvars.outlineModeShowLootEffectWhenDisabled="1"
M.cvars.SoftTargetInteractRange="10.000000"; M.cvars.SoftTargetInteractArc="0"
M.cvars.SoftTargetInteractOnlyInRange="0"; M.cvars.SoftTargetNameplateInteract="0"
M.cvars.SoftTargetIconInteract="1"; M.cvars.SoftTargetIconGameObject="0"; M.cvars.SoftTargetInteract="1"
'''

HELPERS = r'''
local N=FP.NearbySparkle
local function said(text) local n=0; for _,l in ipairs(M.Chat()) do if tostring(l):find(text,1,true) then n=n+1 end end return n end
local function soft() local out={}; for _,w in ipairs(M.cvarWrites) do if w.name:find("^SoftTarget") then out[#out+1]=w end end return out end
local function rows() return FP.db.questSparkle.nearby.restore end
local function num(name) return tonumber(M.cvars[name]) end
-- The mock runs timers that are due after one jump; a chain of looks needs several.
local function wait(steps) for _=1,(steps or 12) do M.RunTimers(11) end end
-- Everything the v0.27.0 setup changed is back where the player had it.
local function restored()
 assert(num("SoftTargetInteract")==1 and num("SoftTargetInteractRange")==10 and num("SoftTargetInteractArc")==0, "interact mode not put back")
 assert(num("SoftTargetNameplateInteract")==0 and num("SoftTargetIconGameObject")==0, "interact display not put back")
end
local function untouchedElsewhere()
 for _,w in ipairs(M.cvarWrites) do
  assert(not w.combat, "wrote "..w.name.." in combat")
  assert(w.name:find("^SoftTarget") or w.name=="outlineModeShowLootEffectWhenDisabled", "wrote "..w.name)
 end
 assert(M.cvars.outlineModeShowLootEffectWhenDisabled=="1", "the game's own sparkle setting changed")
 assert(M.cvars.graphicsOutlineMode=="2" and M.cvars.graphicsQuality=="6", "a graphics setting changed")
 assert(M.cvars.SoftTargetIconInteract=="1" and M.cvars.SoftTargetInteractOnlyInRange=="0", "a setting setup never changed was written")
end
'''

def cases():
    return {
        # The owner's real saved state: one login puts all five back, once.
        'nearby_retired_owner_profile_gets_its_settings_back_at_login': (OWNER, r'''
restored(); untouchedElsewhere()
local w=soft()
assert(#w==5, "five writes, got "..#w)
assert(w[1].name=="SoftTargetInteract" and w[1].value=="1", "the Interact Key mode goes back first")
assert(w[5].name=="SoftTargetInteractRange" and w[5].value=="10.000000", "the remembered value is written as remembered")
assert(#rows()==0 and FP.settings.questSparkle.nearby==nil and N:Pending()==0)
local r=FP.db.questSparkle.nearby.retired
assert(#r.restored==5 and #r.kept==0 and r.told and r.pending==0 and r.failed==nil and r.version==FP.version)
assert(r.restored[1].name=="SoftTargetInteract" and r.restored[1].from=="3" and r.restored[1].to=="1")
assert(said("nearby sparkle mode has been removed")==1 and said("Put back 5 game settings")==1 and said("quest sparkle is untouched")==1)
assert(FP.db.questSparkle.nearby.lastAttached.name=="Un'Goro Dirt Pile", "the v0.27.0 evidence stays")
assert(FP.db.questSparkle.ours==true and FP.settings.questSparkle.enabled==true, "the native sparkle feature is as it was")
-- Later events, a second look and a /reload write nothing more and say nothing more.
M.FireEvent("PLAYER_ENTERING_WORLD"); M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.FireEvent("PLAYER_REGEN_ENABLED")
N:OnEnable(); wait()
assert(#soft()==5 and said("nearby sparkle mode has been removed")==1)
cmd("sparkle"); assert(said("still to put back")==0)
'''),
        # The client may print "10" as "10.000000" or the reverse: compare as numbers.
        'nearby_retired_numeric_readback_either_way': (OWNER + r'''
local set=C_CVar.SetCVar
C_CVar.SetCVar=function(name,value)
 local ok=set(name,value)
 if name=="SoftTargetInteractRange" then M.cvars[name]="10" elseif name=="SoftTargetInteract" then M.cvars[name]="1.000000" end
 return ok
end
M.cvars.SoftTargetInteractRange="15.000000"
''', r'''
restored(); assert(#rows()==0 and #soft()==5 and said("Put back 5 game settings")==1)
'''),
        'nearby_retired_login_in_combat_waits_for_the_fight_to_end': (OWNER + "M.combatLockdown=true\n", r'''
wait()
assert(#soft()==0 and #rows()==5 and num("SoftTargetInteract")==3, "nothing is written in combat")
cmd("sparkle"); assert(said("5 game settings still to put back")==1)
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED")
restored(); untouchedElsewhere(); assert(#rows()==0 and #soft()==5 and said("Put back 5 game settings")==1)
'''),
        # A value the player changed after setup is theirs.
        'nearby_retired_setting_changed_since_stays_the_players': (OWNER + 'M.cvars.SoftTargetInteractRange="25"\n', r'''
assert(#soft()==4 and #rows()==1 and said("has been removed")==0, "the differing one is not let go at first sight")
M.RunTimers(11); assert(#rows()==1, "nor ten seconds later")
wait()
assert(M.cvars.SoftTargetInteractRange=="25" and #soft()==4 and #rows()==0)
local r=FP.db.questSparkle.nearby.retired
assert(#r.restored==4 and #r.kept==1 and r.kept[1].name=="SoftTargetInteractRange" and r.kept[1].value=="25" and r.kept[1].before=="10.000000")
assert(said("Put back 4 game settings")==1 and said("Left 1 alone that was changed since")==1)
untouchedElsewhere()
'''),
        # Account settings can arrive after the first look. A value that only
        # looked different must not cost the remembered list.
        'nearby_retired_settings_that_arrive_late_are_still_put_back': (OWNER_DB + DEFAULT_CLIENT, r'''
M.RunTimers(11)
assert(#soft()==0 and #rows()==5, "they look like the earlier values for now, and the list is kept")
for name,value in pairs({SoftTargetInteractRange="15",SoftTargetInteractArc="2",SoftTargetNameplateInteract="1",
 SoftTargetIconGameObject="1",SoftTargetInteract="3"}) do M.cvars[name]=value end
M.FireEvent("CVAR_UPDATE","SoftTargetInteract","3"); M.RunTimers(2)
restored(); untouchedElsewhere(); assert(#rows()==0 and #soft()==5 and said("Put back 5 game settings")==1)
'''),
        # The client refuses: bounded tries, the list is kept, the commands are handed over.
        'nearby_retired_refusal_keeps_the_list_and_gives_the_commands': (OWNER + 'M.cvarProtected="silent"\n', r'''
wait()
assert(#rows()==5 and num("SoftTargetInteract")==3 and N.stopped)
assert(#soft()==15, "three looks of five, then it stops: "..#soft())
assert(said("Could not put back 5 game settings")==1 and said("/console SoftTargetInteract 1")==1 and said("/console SoftTargetInteractRange 10.000000")==1)
assert(FP.db.questSparkle.nearby.retired.failed=="refused" and FP.settings.questSparkle.nearby==true)
M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.FireEvent("PLAYER_ENTERING_WORLD"); wait()
assert(#soft()==15 and said("Could not put back")==1, "no more tries and no more lines this session")
cmd("sparkle"); assert(said("the client refused; trying again at the next login")==1)
-- The next login, with a client that accepts it.
M.cvarProtected=nil; N.stopped,N.refusals,N.toldRefused,N.timer=nil,nil,nil,nil
N:OnEnable(); M.RunTimers(6)
restored(); assert(#rows()==0 and said("Put back 5 game settings")==1)
'''),
        'nearby_retired_blocked_write_counts_as_a_refusal': (OWNER + 'M.cvarProtected=true\n', r'''
wait()
assert(#rows()==5 and N.stopped and FP.db.questSparkle.nearby.retired.failed=="blocked" and said("Could not put back 5 game settings")==1)
FP.db.errors={}
'''),
        # v0.27.0's own unfinished off request (switch off, undo still owed).
        'nearby_retired_unfinished_off_request_is_completed': (OWNER.replace('nearby=true}}', 'nearby=false}}'), r'''
restored(); assert(#rows()==0 and FP.settings.questSparkle.nearby==nil and said("Put back 5 game settings")==1)
'''),
        # Switched on where every setting already had the setup value: nothing to undo.
        'nearby_retired_mode_on_with_nothing_changed_just_goes': (
            'HearthAndHustleDB={settings={questSparkle={enabled=true,nearby=true}},questSparkle={nearby={restore={}}}}\n' + OWNER_CLIENT, r'''
assert(#soft()==0 and FP.settings.questSparkle.nearby==nil and num("SoftTargetInteract")==3, "a setting the mode never changed is not the addon's to change")
assert(said("nearby sparkle mode has been removed")==1 and said("It had changed no game setting")==1)
'''),
        'nearby_retired_damaged_list_is_dropped_without_a_write': (
            'HearthAndHustleDB={settings={questSparkle={enabled=true,nearby=true}},questSparkle={nearby={restore={'
            + '"junk",{name="SoftTargetInteract",before="3",applied="3"},{name="SoftTargetInteractArc",before="x",applied="2"},'
            + '{name=7,before="0",applied="1"},{name="graphicsOutlineMode",before="0",applied="2"},{name="SoftTargetFriend",before="3",applied="0"}}}}}\n'
            + OWNER_CLIENT, r'''
wait()
assert(#M.cvarWrites==0, "wrote "..#M.cvarWrites)
assert(M.cvars.graphicsOutlineMode=="2" and M.cvars.SoftTargetFriend==nil)
assert(#rows()==0 and not N.stopped and said("Could not put back")==0, "rows that cannot be undone are dropped, not retried")
'''),
        # No profile ever had the mode: silent, and no way to get it.
        'nearby_retired_fresh_profile_has_no_mode_and_no_way_in': (DEFAULT_CLIENT, HUB_PLACEHOLDER + r'''
M.FireEvent("PLAYER_ENTERING_WORLD"); M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); wait()
assert(#soft()==0 and said("nearby sparkle")==0 and said("Nearby")==0)
assert(FP.settings.questSparkle.nearby==nil and FP.db.questSparkle.nearby==nil, "no leftover switch or store on a fresh profile")
assert(N.Enable==nil and N.Update==nil and N.CreateDisplay==nil and N.frame==nil, "the display and its setup are gone")
local API=FP.API
assert(API.NearbySparkleObject==nil and API.SetNearbySparkleSetting==nil and API.NearbySparkleSettings==nil and API.NearbySparkleAvailable==nil)
-- The adapter can only give a value back; the setup values and other settings are refused.
for name,value in pairs({SoftTargetInteract="3",SoftTargetInteractRange="15",SoftTargetInteractArc="2",SoftTargetNameplateInteract="1",
 SoftTargetIconGameObject="1"}) do
 local ok=API.RestoreRetiredNearbySetting(name,value); assert(ok==false, name.." accepted its setup value")
end
assert(not API.RestoreRetiredNearbySetting("graphicsOutlineMode","0") and not API.RestoreRetiredNearbySetting("SoftTargetFriend","3"))
assert(not API.RestoreRetiredNearbySetting("SoftTargetInteract","junk") and not API.RestoreRetiredNearbySetting("SoftTargetInteract",2))
assert(API.RetiredNearbySetting("graphicsOutlineMode")==nil and API.RetiredNearbySetting("SoftTargetInteract")=="1")
M.combatLockdown=true
local ok,why=API.RestoreRetiredNearbySetting("SoftTargetInteract","2"); assert(ok==false and why=="combat", "the adapter itself refuses in combat")
M.combatLockdown=false
assert(#M.cvarWrites==0)
-- The interact object is never read: these would throw.
UnitIsGameObject=function() error("read the interact object") end
C_NamePlate=C_NamePlate or {}; C_NamePlate.GetNamePlateForUnit=function() error("read a nameplate") end
M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED",M.Secret(),M.Secret()); M.FireEvent("NAME_PLATE_UNIT_ADDED","nameplate1"); M.RunTimers(5)
page("display")
assert(H.controls.questSparkleEnabled and not H.controls.nearbySparkleEnable and not H.controls.nearbySparkleDisable and not H.controls.nearbySparkleStatus)
cmd("sparkle"); assert(said("an addon cannot add it")==1 and said("optional nearby-object sparkle")==0)
'''),
    }

HUB_PLACEHOLDER = "--HUB--\n"
