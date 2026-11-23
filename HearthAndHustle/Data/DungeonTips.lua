-- HearthAndHustle / Data / DungeonTips.lua
-- What to use where inside a dungeon, stop by stop. Read by Modules/DungeonTips.lua.
--
-- Where it comes from: Classic (1.12) creature data, not the Forever client.
-- Which creature stands in which room was worked out from the spawn positions
-- in the open CMaNGOS Classic world database (map 289), and what each creature
-- casts from its ability scripts (ACID) and the VMaNGOS boss scripts, read on
-- 2026-11-22. Only the facts were taken, no text. Forever may have changed a
-- room or an ability: the card says so, and a stop that is wrong in play gets
-- corrected here.
--
-- A dungeon:  name, match (part of the instance name, lower case), stops in the
--             order a group usually meets them.
-- A stop:     key, kind (trash | boss | overview), title, here (who stands
--             there), threat (one short line for every class), names (boss
--             names as the game announces the fight), optional, group (a set
--             of bosses done in any order, listed by the overview stop), room
--             (shown beside the boss on the overview), watch (lines for every
--             class: { short, long }), classes (lines for one class).
-- A class line: { element, totem, say, why, or_ = second choice }.
--             `say` is what fits on the card; `why` is the hover text.
-- The card cuts a line that is too long, so tests/dungeon_tips.py holds every
-- visible line to FP.DungeonTipsData.LINE characters.
local ADDON, FP = ...

local D = { LINE = 50, dungeons = {}, order = {} }
FP.DungeonTipsData = D

D.source = "From Classic creature data. Forever may differ: tell me what is wrong."

-- Totems by name: element and the Classic rank 1 spell id, used only for the
-- icon, and only when the client gives that id the same name.
D.totems = {
	["Stoneskin Totem"] = { element = "earth", id = 8071 },
	["Strength of Earth Totem"] = { element = "earth", id = 8075 },
	["Tremor Totem"] = { element = "earth", id = 8143 },
	["Stoneclaw Totem"] = { element = "earth", id = 5730 },
	["Magma Totem"] = { element = "fire", id = 8190 },
	["Fire Nova Totem"] = { element = "fire", id = 1535 },
	["Frost Resistance Totem"] = { element = "fire", id = 8181 },
	["Mana Spring Totem"] = { element = "water", id = 5675 },
	["Healing Stream Totem"] = { element = "water", id = 5394 },
	["Disease Cleansing Totem"] = { element = "water", id = 8170 },
	["Poison Cleansing Totem"] = { element = "water", id = 8166 },
	["Fire Resistance Totem"] = { element = "water", id = 8184 },
	["Grounding Totem"] = { element = "air", id = 8177 },
	["Windfury Totem"] = { element = "air", id = 8512 },
	["Tranquil Air Totem"] = { element = "air", id = 25908 },
}
D.elements = { "earth", "fire", "water", "air" }
D.elementNames = { earth = "Earth", fire = "Fire", water = "Water", air = "Air" }

local MELEE_AIR = "Nothing here casts a single-target spell worth eating. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat."

D.order[#D.order + 1] = "scholomance"
D.dungeons.scholomance = {
	name = "Scholomance",
	match = "scholomance",
	stops = {
		{
			key = "entry", kind = "trash", title = "Entry halls",
			here = "Risen Guards, Neophytes, Acolytes, Researchers",
			threat = "Fear, Mana Burn, shadow bolts",
			watch = {
				{ "Blood Steward: Paralyzing Poison", "The Blood Steward of Kirtonos walks these halls: Paralyzing Poison, Curse of Weakness, Curse of Impotence. Swap Water to Poison Cleansing for that pull, or use Cure Poison." },
				{ "Acolytes heal their friends: interrupt", "Scholomance Acolyte: Dark Mending (a heal on its friends), Mana Burn, Mind Flay, Cripple. Spectral Researcher: Mana Burn, Wail of Souls. Mana Burn goes for mana users first." },
			},
			classes = { SHAMAN = {
				{ "earth", "Tremor Totem", "Neophytes cast Fear", "Scholomance Neophytes cast Fear, Mind Flay and Shadow Bolt. They stand in the first halls and again on the way to Ras Frostwhisper." },
				{ "water", "Mana Spring Totem", "nothing to cleanse yet", "No disease in these halls. The one poison is the Blood Steward's." },
				{ "air", "Grounding Totem", "eats a Fear or a Mana Burn", "Grounding takes one single-target spell every 10 seconds: a Neophyte's Fear or Shadow Bolt, an Acolyte's or Researcher's Mana Burn." },
			} },
		},
		{
			key = "second", kind = "trash", title = "Aberrations, ghouls, summoners",
			here = "Aberrations, Diseased Ghouls, Necrolytes",
			threat = "Disease, shadow bolts, Curse of Blood",
			watch = {
				{ "Dark Summoner: Curse of Blood, adds", "Scholomance Dark Summoner: Curse of Blood (more physical damage taken) and Summon Risen Lackey. Kill the summoner first." },
				{ "Necromancer: Shadow Bolt Volley, runs", "Scholomance Necromancer: Shadow Bolt Volley on everyone, Call of the Grave, Corpse Explosion, and it runs at low health. Necrofiends add Deadly Poison and a web." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "packs of melee on the tank", "Risen Aberrations and Diseased Ghouls come in packs and only hit in melee. Strength of Earth if the tank is never in trouble." },
				{ "water", "Disease Cleansing Totem", "Wandering Plague", "Diseased Ghouls: a Disease Cloud around them, Wandering Plague on a pull, and a Cloud of Disease where they die." },
				{ "air", "Grounding Totem", "Necrolyte Shadow Bolts", "Scholomance Necrolytes cast Shadow Bolt and Shadow Shock at one target. The Necromancers' Shadow Bolt Volley hits everyone and cannot be eaten." },
			} },
		},
		{
			key = "kirtonos", kind = "boss", title = "Kirtonos the Herald", optional = true,
			names = { "Kirtonos the Herald" },
			threat = "Knockback, mind control, Curse of Tongues",
			watch = {
				{ "Gargoyle: Swoop, Wing Flap knockback", "As a gargoyle: Swoop, Wing Flap (knocks back), Pierce Armor and Disarm on the tank." },
				{ "Human: Shadow Bolt Volley, mind control", "As a human: Shadow Bolt Volley on everyone, Curse of Tongues (slower casts), and Dominate Mind, which also drops his threat on that player." },
				{ "He does not fear: no Tremor needed", "Summoned on the porch with the Blood of Innocents. Nothing he casts is a fear, a disease or a poison." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Pierce Armor on the tank", "Pierce Armor cuts the tank's armor, so his melee hits harder as the fight goes on." },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Tongues is a curse: a mage or a druid removes it, a shaman cannot." },
				{ "air", "Grounding Totem", "can eat Dominate Mind", "Dominate Mind and Curse of Tongues are cast at one player, so Grounding can take them. The Shadow Bolt Volley cannot be eaten." },
			} },
		},
		{
			key = "crypt", kind = "trash", title = "Crypt: aberrations, corpses, ghouls",
			here = "Aberrations, Reanimated Corpses, Ghouls",
			threat = "Disease on every pull",
			watch = {
				{ "Reanimated Corpses get back up", "A Reanimated Corpse lies down at low health, heals and stands up again: kill it twice. It casts Dark Plague." },
				{ "Ghouls leave a disease cloud: step out", "Diseased Ghouls leave a Cloud of Disease where they die. Do not stand in it to loot or drink." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "big melee packs", "About thirty Risen Aberrations down here, pulled in packs, all melee." },
				{ "water", "Disease Cleansing Totem", "Dark Plague, Wandering Plague", "Dark Plague from the Reanimated Corpses, Wandering Plague and disease clouds from the Diseased Ghouls." },
				{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "jandice", kind = "boss", title = "Jandice Barov", optional = true,
			names = { "Jandice Barov" },
			threat = "Curse of Blood, illusions, Banish",
			watch = {
				{ "Illusions: any area damage kills them", "She splits into many illusions. They have almost no health: one area spell clears them." },
				{ "Banish takes one player out for a while", "Banish removes one player from the fight for some seconds. If it is the tank, the illusions and Jandice run loose." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Curse of Blood on the tank", "Curse of Blood raises the physical damage a player takes, and everything she and her illusions do is physical." },
				{ "fire", "Magma Totem", "burns the illusions down", "Magma Totem or a Fire Nova Totem at her feet kills the illusions as they appear.", or_ = "Fire Nova Totem" },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Blood is a curse: not yours to remove." },
				{ "air", "Tranquil Air Totem", "illusions come for the healer", "Fresh illusions go for whoever has threat on them, and your heals are the first threat they see." },
			} },
		},
		{
			key = "ossuary", kind = "trash", title = "Great Ossuary: hatchlings, constructs",
			here = "Adepts, Hatchlings, Handlers, Constructs",
			threat = "Disease, frost, heavy melee",
			watch = {
				{ "Hatchlings come in packs: area damage", "Plagued Hatchlings around the upper ring, with their Handlers (Blast Wave, Cone of Cold, Arcane Blast)." },
				{ "Risen Constructs frenzy at low health", "Risen Constructs guard the pit: Arcing Smash on everyone in front, Thrash, and Frenzy at 30%. Risen Protectors on the way here Silence." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Constructs hit very hard", "Risen Constructs: Thrash, Arcing Smash, Frenzy at 30% health. All of it is physical." },
				{ "water", "Disease Cleansing Totem", "Hatchlings: Diseased Spit", "Plagued Hatchlings cast Diseased Spit. In the Classic data it is a disease, not a poison." },
				{ "air", "Grounding Totem", "eats an Adept's Frostbolt", "Scholomance Adepts in the hall before the Ossuary: Frostbolt, Frost Shock, Cone of Cold. Grounding takes a Frostbolt or a Frost Shock." },
			} },
		},
		{
			key = "rattlegore", kind = "boss", title = "Rattlegore",
			names = { "Rattlegore" },
			threat = "Heavy melee, War Stomp stun, knockback",
			watch = {
				{ "War Stomp stuns everyone close to him", "War Stomp stuns everyone near him: heal from range. Knock Away throws the tank back." },
				{ "Classic: he drops the Viewing Room Key", "In Classic he drops the key to the Viewing Room, where Marduk Blackpool and Vectus stand." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "all physical, hardest hitter", "Strike, Knock Away, War Stomp: nothing but physical damage, and more of it than any other boss here." },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic on this fight." },
				{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "viewing", kind = "boss", title = "Viewing Room: Marduk and Vectus", optional = true,
			names = { "Marduk Blackpool", "Vectus" },
			threat = "Fire on the ground, shadow volleys, Cleave",
			watch = {
				{ "Vectus: Flamestrike, move out of it", "Vectus: Blast Wave around him, Flamestrike on the ground, a Fire Shield that burns attackers." },
				{ "Marduk: shadow aura, do not stand on him", "Marduk Blackpool: Defiling Aura hurts everyone near him, Cleave, Shadow Bolt Volley, and a Shadow Shield you can Purge." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Marduk cleaves in melee", "Marduk Blackpool hits and cleaves in melee. The students in the room are weak." },
				{ "water", "Fire Resistance Totem", "Blast Wave, Flamestrike", "Fire Resistance is a Water totem. Vectus does only fire damage: Blast Wave, Flamestrike, Fire Shield." },
				{ "air", "Windfury Totem", "volleys cannot be eaten", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "ras", kind = "boss", title = "Ras Frostwhisper", optional = true,
			names = { "Ras Frostwhisper" },
			threat = "Fear, frost on everyone, Freeze",
			watch = {
				{ "Freeze holds a player in place", "Freeze roots and stuns its target for a few seconds. Chill Nova hits everyone near him, Knock Away throws the tank." },
				{ "On the way: Mana Burn, one more Fear", "Spectral Teachers (Mana Burn, Arcane Focus), an Acolyte, Necromancers and a Neophyte stand in the rooms before him." },
			},
			classes = { SHAMAN = {
				{ "earth", "Tremor Totem", "he casts Fear", "Ras Frostwhisper casts Fear, and a Neophyte stands in the rooms before him." },
				{ "fire", "Frost Resistance Totem", "Frostbolt Volley, Chill Nova", "Frost Resistance is a Fire totem. Frostbolt Volley and Chill Nova hit the whole group." },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "Freeze and the frost slows are magic: not yours to remove." },
				{ "air", "Grounding Totem", "eats his Fear or a Mana Burn", "Grounding takes a single-target cast: his Fear, or a Spectral Teacher's Mana Burn on the way. The volleys go through." },
			} },
		},
		{
			key = "six", kind = "overview", title = "The six rooms before Gandling", group = "six",
			threat = "Six bosses in any order; all six open Gandling",
		},
		{
			key = "malicia", kind = "boss", title = "Instructor Malicia", group = "six",
			names = { "Instructor Malicia" }, short = "Malicia", room = "Upper", roomHint = "upper room, with Occultists",
			threat = "Heals herself, Slow, Call of the Grave",
			brief = { SHAMAN = "Grounding; interrupt her heals" },
			watch = {
				{ "Interrupt Heal and Flash Heal", "She casts Heal at half health and Flash Heal on her friends: Earth Shock them. Renew can be Purged." },
				{ "Occultists: a Shade at 40%, spells only", "Scholomance Occultists Counterspell, Drain Mana and cast Shadow Bolt Volley. At 40% they turn into a Dark Shade that weapons cannot hurt." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "nothing to break here", "No fear in this room. Strength of Earth is as good if the tank is safe." },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "Corruption, Slow and Call of the Grave are magic: a priest or a paladin removes them." },
				{ "air", "Grounding Totem", "eats Slow or Call of the Grave", "Slow, Corruption and Call of the Grave are cast at one player. Call of the Grave ends in a large hit, so eating it is worth a totem." },
			} },
		},
		{
			key = "ravenian", kind = "boss", title = "The Ravenian", group = "six",
			names = { "The Ravenian" }, short = "Ravenian", room = "Lower", roomHint = "lower room, with Splintered Skeletons",
			threat = "All melee: Cleave, Trample, knockback",
			brief = { SHAMAN = "Stoneskin; all melee, cleaves" },
			watch = {
				{ "Cleave and Trample hit all melee", "Cleave, Sundering Cleave (cuts armor), Trample on everyone close, Knock Away. Melee stand behind him." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Sundering Cleave cuts armor", "Everything he does is physical, and Sundering Cleave lowers the tank's armor." },
				{ "water", "Healing Stream Totem", "Trample hits all melee", "Trample and Cleave keep the melee damaged. Mana Spring if the group is ranged." },
				{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "krastinov", kind = "boss", title = "Doctor Theolen Krastinov", group = "six",
			names = { "Doctor Theolen Krastinov" }, short = "Krastinov", room = "Upper", roomHint = "upper room, with Diseased Ghouls",
			threat = "Hard melee, Rend, enrage at half health",
			brief = { SHAMAN = "Disease Cleansing for his ghouls" },
			watch = {
				{ "Enrages at half health", "At 50% he enrages and hits much harder until he dies. Rend bleeds the tank, Backhand stuns." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "hits harder after 50%", "Rend, Backhand, and an enrage at half health. All physical." },
				{ "water", "Disease Cleansing Totem", "the ghouls in his room", "Five Diseased Ghouls stand with him. Once they are dead the fight has no disease: Mana Spring." },
				{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "alexei", kind = "boss", title = "Lord Alexei Barov", group = "six",
			names = { "Lord Alexei Barov" }, short = "Alexei Barov", room = "Lower", roomHint = "lower room, with Risen Guards",
			threat = "Shadow aura on all, healing curse",
			brief = { SHAMAN = "Healing Stream; shadow aura" },
			watch = {
				{ "Veil of Shadow: a curse, heals do less", "Veil of Shadow cuts the healing its target takes by three quarters for a few seconds. It is a curse: a mage or a druid removes it." },
				{ "Unholy Aura hurts everyone near him", "Unholy Aura deals shadow damage to everyone close, all fight long. Ranged and healer stay back. He also casts Immolate." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Risen Guards and Warriors", "Two Risen Guards and two Risen Warriors stand with him, all melee." },
				{ "water", "Healing Stream Totem", "Unholy Aura never stops", "The aura ticks on everyone in melee range for the whole fight. There is no totem against shadow damage." },
				{ "air", "Grounding Totem", "can eat Veil of Shadow", "Veil of Shadow and Immolate are cast at one player, so Grounding can take them." },
			} },
		},
		{
			key = "polkelt", kind = "boss", title = "Lorekeeper Polkelt", group = "six",
			names = { "Lorekeeper Polkelt" }, short = "Polkelt", room = "Upper", roomHint = "upper room, full of corpses",
			threat = "Disease: his own and the corpses'",
			brief = { SHAMAN = "Disease Cleansing; corpse room" },
			watch = {
				{ "Unstable Corpses burst when they die", "About twenty Unstable Corpses and some Reanimated Corpses fill the room: Dark Plague, and a Disease Burst as each Unstable Corpse dies." },
				{ "He does not fear: no Tremor needed", "Polkelt casts Volatile Infection (a disease), Corrosive Acid and Noxious Catalyst. No fear." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "the corpses all hit in melee", "The room is pulled in large packs of corpses." },
				{ "water", "Disease Cleansing Totem", "corpses, Volatile Infection", "Dark Plague from the corpses, then Polkelt's own Volatile Infection." },
				{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
			} },
		},
		{
			key = "illucia", kind = "boss", title = "Lady Illucia Barov", group = "six",
			names = { "Lady Illucia Barov" }, short = "Illucia Barov", room = "Lower", roomHint = "lower room, with Risen Bonewarders",
			threat = "Fear, mind control, Silence",
			brief = { SHAMAN = "Tremor + Grounding; she fears" },
			watch = {
				{ "Silence stops your heals for seconds", "Silence, Shadow Shock and Curse of Agony. Keep the tank high so a Silence on you is not a death." },
				{ "Bonewarders: Drain Life, Bone Armor", "Four Risen Bonewarders stand with her: Drain Life, Consuming Shadows, Bone Armor." },
			},
			classes = { SHAMAN = {
				{ "earth", "Tremor Totem", "she casts Fear", "Lady Illucia Barov casts Fear and Dominate Mind." },
				{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Agony is a curse: not yours to remove." },
				{ "air", "Grounding Totem", "eats Fear, Silence, mind control", "Fear, Silence and Dominate Mind are each cast at one player, so Grounding can take them." },
			} },
		},
		{
			key = "gandling", kind = "boss", title = "Darkmaster Gandling",
			names = { "Darkmaster Gandling" },
			threat = "Arcane Missiles, a curse, players sent away",
			watch = {
				{ "Shadow Portal sends one player away", "Shadow Portal puts one player in a side room with Risen Guardians (Shadow Shock, Veil of Shadow, Cripple). Kill them to come back." },
				{ "Sent away: Stoneclaw holds the guards", "If it is you: Stoneclaw Totem in that room pulls the Risen Guardians off you while you kill them or wait for help." },
			},
			classes = { SHAMAN = {
				{ "earth", "Stoneskin Totem", "Stoneclaw if you get sent away", "Stoneskin for the tank. Keep Stoneclaw Totem ready for the side room: see the Watch line." },
				{ "water", "Mana Spring Totem", "a long fight", "No disease or poison on Gandling himself in the Classic data." },
				{ "air", "Grounding Totem", "eats Arcane Missiles or his curse", "Arcane Missiles and Curse of the Darkmaster are cast at one player. He also shields himself with Shadow Shield: Purge it." },
			} },
		},
	},
}
