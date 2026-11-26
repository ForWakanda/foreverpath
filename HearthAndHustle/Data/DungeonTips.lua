-- HearthAndHustle / Data / DungeonTips.lua
-- What to do and what to use inside a dungeon, stop by stop. This file holds
-- the frame; each instance has its own file, Data/DungeonTips_<Instance>.lua.
-- Read by Modules/DungeonTips.lua.
--
-- Where it comes from: Classic (1.12) creature data, not the Forever client.
-- Which creature stands where is from the spawn positions in the open CMaNGOS
-- Classic world database; what each creature casts is from its ability scripts
-- there (creature_ai_scripts, creature_spell_list, creature_template_spells)
-- and the ScriptDevAI boss and instance scripts; what a spell does (its
-- targets, whether it is a disease or a curse, whether it leaves something on
-- the ground, whether it has a cast time) is from that database's spell table.
-- Read 2026-11-25. Only the facts were taken, no text. Forever may have changed
-- a room or an ability: the card says so, and a stop that is wrong in play gets
-- corrected in its file.
--
-- A dungeon:  key, name, match (part of the instance name, lower case, or a
--             list of such parts), wing (the label of one run inside an
--             instance that holds several: wings share their first match and
--             the player picks one on the card), stops in the order a group
--             usually meets them.
-- A stop:     key, kind (trash | boss | overview), title, here (who stands
--             there), threat (one short line for every class), names (boss
--             names as the game announces the fight), optional, group (a set
--             of bosses done in any order, listed by the overview stop), room
--             (shown beside the boss on the overview), act (what to do, for
--             every class: { short, long }), watch (what the enemies do, for
--             every class: { short, long }), classes (lines for one class),
--             cite (the spell ids in that database the stop was written from;
--             kept so a line can be traced, read by nothing in the game).
-- A class line: { element, totem, say, why, or_ = second choice }.
--             `say` is what fits on the card; `why` is the hover text.
-- The card cuts a line that is too long, so tests/dungeon_tips.py holds every
-- visible line to FP.DungeonTipsData.LINE characters.
local ADDON, FP = ...

local D = { LINE = 50, dungeons = {}, order = {} }
FP.DungeonTipsData = D

D.source = "From Classic creature data. Forever may differ: tell me what is wrong."

-- An instance file adds its dungeons in the order they are listed.
function D.Add(dungeon)
	D.order[#D.order + 1] = dungeon.key
	D.dungeons[dungeon.key] = dungeon
end

-- Totems by name: element and the Classic rank 1 spell id, used only for the
-- icon, and only when the client gives that id the same name.
D.totems = {
	["Stoneskin Totem"] = { element = "earth", id = 8071 },
	["Strength of Earth Totem"] = { element = "earth", id = 8075 },
	["Tremor Totem"] = { element = "earth", id = 8143 },
	["Stoneclaw Totem"] = { element = "earth", id = 5730 },
	["Earthbind Totem"] = { element = "earth", id = 2484 },
	["Magma Totem"] = { element = "fire", id = 8190 },
	["Fire Nova Totem"] = { element = "fire", id = 1535 },
	["Searing Totem"] = { element = "fire", id = 3599 },
	["Flametongue Totem"] = { element = "fire", id = 8227 },
	["Frost Resistance Totem"] = { element = "fire", id = 8181 },
	["Mana Spring Totem"] = { element = "water", id = 5675 },
	["Healing Stream Totem"] = { element = "water", id = 5394 },
	["Disease Cleansing Totem"] = { element = "water", id = 8170 },
	["Poison Cleansing Totem"] = { element = "water", id = 8166 },
	["Fire Resistance Totem"] = { element = "water", id = 8184 },
	["Grounding Totem"] = { element = "air", id = 8177 },
	["Windfury Totem"] = { element = "air", id = 8512 },
	["Tranquil Air Totem"] = { element = "air", id = 25908 },
	["Nature Resistance Totem"] = { element = "air", id = 10595 },
	["Grace of Air Totem"] = { element = "air", id = 8835 },
	["Windwall Totem"] = { element = "air", id = 15107 },
}
D.elements = { "earth", "fire", "water", "air" }
D.elementNames = { earth = "Earth", fire = "Fire", water = "Water", air = "Air" }
