"""Nearby world-object display: real adapter boundaries under a mocked client."""
HELPERS = r'''
local N=FP.NearbySparkle
local baseline={SoftTargetInteractRange="10",SoftTargetInteractArc="0",SoftTargetInteractOnlyInRange="1",
 SoftTargetNameplateInteract="0",SoftTargetIconInteract="1",SoftTargetIconGameObject="0",SoftTargetInteract="0"}
for k,v in pairs(baseline) do M.cvars[k]=v end
local plate=M.NewFrame("Frame")
plate.IsForbidden=function() return false end
M.sparkObject={guid="GameObject-0-1-1-1-157936-0001",name="Un'Goro Dirt Pile",gameObject=true,plate=plate}
UnitIsGameObject=function(unit) assert(unit=="softinteract"); return M.sparkObject and M.sparkObject.gameObject end
local oldName,oldGUID=UnitName,UnitGUID
UnitName=function(unit) if unit=="softinteract" then return M.sparkObject and M.sparkObject.name end return oldName(unit) end
UnitGUID=function(unit) if unit=="softinteract" then return M.sparkObject and M.sparkObject.guid end return oldGUID(unit) end
C_NamePlate={GetNamePlateForUnit=function(unit,forbidden)
 assert(unit=="softinteract" and forbidden==false); return M.sparkObject and M.sparkObject.plate end}
-- These calls are never an acceptable shortcut for a purely visual effect.
TargetUnit=function() error("targeted") end
InteractUnit=function() error("interacted") end
CastSpellByName=function() error("cast") end
LootSlot=function() error("looted") end
local function shown() return N.frame and N.frame:IsShown() end
local function settingsUnchanged()
 for k,v in pairs(baseline) do assert(M.cvars[k]==v,k.." changed") end
 assert(M.cvars.graphicsOutlineMode=="2")
end
local function enable() assert(N:Enable()); assert(FP.settings.questSparkle.nearby) end
'''

def cases(hub):
    return {
        'nearby_sparkle_default_does_not_enable_interaction': HELPERS+r'''
local writes=#M.cvarWrites
M.FireEvent("PLAYER_ENTERING_WORLD"); M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED",M.Secret(),M.Secret()); M.RunTimers(3)
assert(not FP.settings.questSparkle.nearby and not shown() and #M.cvarWrites==writes)
settingsUnchanged()
assert(FP.db.questSparkle.observed.value=="1" and FP.db.questSparkle.observed.reason=="world", "native observations must refresh even without a write")
''',
        'nearby_sparkle_dirt_and_other_objects_without_a_quest_list': HELPERS+r'''
enable(); assert(shown() and N.plate==plate)
assert(N.frame:IsMouseClickEnabled()==false and N.frame:IsMouseMotionEnabled()==false)
assert(FP.db.questSparkle.nearby.last.name=="Un'Goro Dirt Pile")
for i,name in ipairs({"Quest Chest","Crate","Herb","Unknown quest object"}) do
 M.sparkObject.name=name; M.sparkObject.guid="GameObject-0-1-1-1-"..(800000+i).."-0001"
 M.FireEvent("PLAYER_SOFT_INTERACT_CHANGED",M.Secret(),M.Secret())
 assert(shown() and FP.db.questSparkle.nearby.last.name==name)
end
assert(#N.frame.stars==6)
N.frame:GetScript("OnUpdate")(N.frame,.3)
assert(N.frame.stars[1]._alpha>0 and N.frame.stars[1]:GetTexture():find("star4",1,true))
assert(M.cvars.graphicsOutlineMode=="2" and M.cvars.outlineModeShowLootEffectWhenDisabled=="1")
''',
        'nearby_sparkle_no_living_unit_corpse_or_secret_overlay': HELPERS+r'''
enable(); assert(shown())
for _,value in ipairs({false,M.Secret()}) do
 M.sparkObject.gameObject=value; N:Update(); assert(not shown())
end
M.sparkObject.gameObject=true
for _,guid in ipairs({"Creature-0-1-1-1-123-0001","Player-1-0001",M.Secret()}) do
 M.sparkObject.guid=guid; N:Update(); assert(not shown())
end
UnitIsGameObject=function() error("unavailable") end
N:Update(); assert(not shown())
''',
        'nearby_sparkle_combat_and_plate_recycling_hide_promptly': HELPERS+r'''
enable(); local writes=#M.cvarWrites
M.combatLockdown=true; M.FireEvent("PLAYER_REGEN_DISABLED"); assert(not shown())
local old=UnitIsGameObject; UnitIsGameObject=function() error("unit read in combat") end
N:Update(); assert(not N:Enable() and #M.cvarWrites==writes)
UnitIsGameObject=old; M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED"); assert(shown())
M.FireEvent("NAME_PLATE_UNIT_REMOVED","nameplate1"); assert(not shown())
M.sparkObject=nil; N:Update(); assert(not shown())
''',
        'nearby_sparkle_forbidden_hidden_missing_nameplates_fail_closed': HELPERS+r'''
enable(); assert(shown())
plate.IsForbidden=function() return true end; N:Update(); assert(not shown())
plate.IsForbidden=function() return M.Secret() end; N:Update(); assert(not shown())
plate.IsForbidden=function() return false end; plate:Hide(); N:Update(); assert(not shown())
plate:Show(); N:Update(); assert(shown())
M.sparkObject.plate=nil; N:Update(); assert(not shown())
''',
        'nearby_sparkle_explicit_off_restores_only_owned_settings': HELPERS+r'''
enable()
M.cvars.SoftTargetInteractRange="12" -- newer deliberate change belongs to the player
assert(N:Disable() and not shown() and not FP.settings.questSparkle.nearby)
assert(M.cvars.SoftTargetInteractRange=="12")
M.cvars.SoftTargetInteractRange=baseline.SoftTargetInteractRange
settingsUnchanged()
assert(#FP.db.questSparkle.nearby.restore==0)
assert(M.cvars.outlineModeShowLootEffectWhenDisabled=="1", "native sparkle stays on")
''',
        'nearby_sparkle_preset_and_login_never_reapply': HELPERS+r'''
enable(); local writes=#M.cvarWrites
M.cvars.SoftTargetInteract="0"; M.FireEvent("CVAR_UPDATE","graphicsQuality","6"); M.RunTimers(1)
assert(not shown() and #M.cvarWrites==writes)
N:OnEnable(); M.FireEvent("PLAYER_ENTERING_WORLD"); M.RunTimers(2)
assert(not shown() and #M.cvarWrites==writes and N:Lines()[1]:find("set up again",1,true))
''',
        'nearby_sparkle_partial_setup_rolls_back_and_retains_failed_undo': HELPERS+r'''
local original=C_CVar.SetCVar
C_CVar.SetCVar=function(name,value)
 if name=="SoftTargetNameplateInteract" then return false end
 return original(name,value)
end
assert(not N:Enable() and not FP.settings.questSparkle.nearby)
settingsUnchanged(); assert(#FP.db.questSparkle.nearby.restore==0)
C_CVar.SetCVar=original; enable()
C_CVar.SetCVar=function() return false end
assert(not N:Disable() and #FP.db.questSparkle.nearby.restore>0 and not shown())
C_CVar.SetCVar=original
N:OnEnable(); settingsUnchanged(); assert(#FP.db.questSparkle.nearby.restore==0)
''',
        'nearby_sparkle_deferred_off_completes_after_combat': HELPERS+r'''
enable(); local writes=#M.cvarWrites
M.combatLockdown=true; M.FireEvent("PLAYER_REGEN_DISABLED")
assert(not N:Disable() and #M.cvarWrites==writes and #FP.db.questSparkle.nearby.restore>0)
M.combatLockdown=false; M.FireEvent("PLAYER_REGEN_ENABLED")
settingsUnchanged(); assert(#FP.db.questSparkle.nearby.restore==0 and not shown())
for _,row in ipairs(M.cvarWrites) do assert(not row.combat) end
''',
        'nearby_sparkle_missing_settings_and_allow_list': HELPERS+r'''
local writes=#M.cvarWrites
M.cvars.SoftTargetInteractRange=nil
assert(not N:Enable() and #M.cvarWrites==writes)
M.cvars.SoftTargetInteractRange="10"; M.secretCVars=true
assert(not N:Enable() and #M.cvarWrites==writes)
M.secretCVars=nil
local objects=UnitIsGameObject; UnitIsGameObject=nil
assert(not N:Enable() and #M.cvarWrites==writes)
UnitIsGameObject=objects
assert(not FP.API.SetNearbySparkleSetting("graphicsOutlineMode","0"))
assert(not FP.API.SetNearbySparkleSetting("SoftTargetFriend","3"))
assert(not FP.API.SetNearbySparkleSetting("SoftTargetInteract","junk"))
assert(#M.cvarWrites==writes)
''',
        'nearby_sparkle_gui_explains_setup_and_can_undo': HELPERS+hub+r'''
page("display"); local writes=#M.cvarWrites
click("nearbySparkleEnable")
assert(H.pending and #M.cvarWrites==writes)
assert(H.confirmText:GetText():find("Untargeted heals/buffs",1,true))
H:CancelConfirm(); assert(not FP.settings.questSparkle.nearby)
click("nearbySparkleEnable"); H.confirmYes:GetScript("OnClick")(H.confirmYes)
assert(FP.settings.questSparkle.nearby and shown())
assert(H.controls.nearbySparkleStatus:GetText():find("one",1,true) or H.controls.nearbySparkleStatus:GetText():find("One",1,true))
click("nearbySparkleDisable"); assert(not shown()); settingsUnchanged()
''',
    }
