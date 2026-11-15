"""Enemy watch: the standing notice while enemy nameplates are off. Mock-only."""

# (preload, body): the nameplate settings and saved state must exist before login.
NAMEPLATE_HELPERS = r'''
local W=FP.EnemyWatch
local DB=FP.db.enemyWatch
local function said(text) local n=0; for _,l in ipairs(M.Chat()) do if tostring(l):find(text,1,true) then n=n+1 end end return n end
local function plateWrites() local n=0; for _,w in ipairs(M.cvarWrites) do if w.name:find("^nameplate") then n=n+1 end end return n end
local function rows() local out={}; for _,r in ipairs(W:Rows()) do out[#out+1]=r.text end return table.concat(out,"\n") end
'''


def nameplate_cases(hub):
    return {
        'enemy_nameplate_notice_stands_until_the_player_switches_them_on': (
            'M.cvars.nameplateShowAll="0"\nHearthAndHustleDB={settings={record=true,probe={enabled=true}},enemyWatch={nameplateHint=true}}\n',
            hub + NAMEPLATE_HELPERS + r'''
assert(said("nameplates only show in combat")==1, "said again this login: the one-time line was missed (client read 2026-11-15)")
assert(DB.nameplateState.always==false and DB.nameplateState.shown==true and DB.nameplateState.version==FP.version)
assert(plateWrites()==0, "telling is not switching")
assert(W:NameplateNotice():find("Nameplates only show in combat",1,true))
page("home");assert(H.controls.homeEnemyNotice:GetText():find("Open PvP for the button",1,true))
page("pvp")
assert(H.controls.enemySight:GetText():find("Nameplates only show in combat",1,true) and H.controls.enemySight:GetText():find("No enemy players seen yet",1,true))
assert(rows()=="", "an empty HUD stays empty: no standing nag on screen")
M.Enemy("target","Fetto","Vandike");M.Enemy("mouseover","Ann","Bee");H:Refresh()
assert(H.controls.enemySight:GetText():find("0 from nameplates, 2 from your target or mouseover",1,true), H.controls.enemySight:GetText())
assert(rows():find("nameplates off: only your target / mouseover",1,true), "beside the list it qualifies")
check("enemyWatchNotice",false);assert(not FP.settings.enemyWatch.nameplateNotice and not rows():find("nameplates off",1,true))
assert(H.controls.enemySight:GetText():find("Nameplates only show in combat",1,true), "the page still says what it can see")
check("enemyWatchNotice",true)
M.combatLockdown=true;click("enemyNameplates")
assert(plateWrites()==0 and DB.nameplates.result=="combat" and W:NameplateNotice(), "never in combat")
M.combatLockdown=false;click("enemyNameplates")
assert(M.cvars.nameplateShowAll=="1" and plateWrites()==1 and DB.nameplates.result=="on" and DB.nameplates.by=="click" and DB.nameplates.always==true)
H:Refresh()
assert(not W:NameplateNotice() and not H.controls.enemyNameplates:IsEnabled() and not rows():find("nameplates off",1,true))
assert(H.controls.enemySight:GetText():find("Enemy nameplates are on",1,true))
M.Enemy("nameplate1","Plate","Seen");H:Refresh()
assert(H.controls.enemySight:GetText():find("1 from nameplates, 2 from your target or mouseover",1,true))
page("home");assert(H.controls.homeEnemyNotice:GetText()=="")
for _,w in ipairs(M.cvarWrites) do assert(w.name=="nameplateShowAll" or w.name=="outlineModeShowLootEffectWhenDisabled", w.name) end
'''),
        'enemy_nameplate_reminder_can_be_switched_off_and_stays_quiet_when_not_needed': (
            'M.cvars.nameplateShowAll="0"\nHearthAndHustleDB={settings={record=true,probe={enabled=true},enemyWatch={nameplateNotice=false}}}\n',
            hub + NAMEPLATE_HELPERS + r'''
assert(said("nameplates only show in combat")==0 and DB.nameplateState.always==false, "reminder off: no login line, state still kept")
M.Enemy("target","Fetto","Vandike");assert(not rows():find("nameplates off",1,true))
page("pvp");assert(H.controls.enemyNameplates:IsEnabled(), "the button is still there")
-- watch switched off entirely: nothing to qualify
cmd("enemies off");assert(not W:NameplateNotice())
cmd("enemies on")
-- setting unreadable: no claim either way, no button
M.secretCVars=true;assert(not W:NameplateNotice());H:Refresh();assert(not H.controls.enemyNameplates:IsEnabled())
M.secretCVars=false
-- already on at login would say nothing
M.cvars.nameplateShowAll="1";assert(not W:NameplateNotice() and plateWrites()==0)
'''),
    }
