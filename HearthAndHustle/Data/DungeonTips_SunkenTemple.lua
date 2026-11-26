-- HearthAndHustle / Data / DungeonTips_SunkenTemple.lua
-- Dungeon tips: The Sunken Temple (The Temple of Atal'Hakkar). Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 109, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local SIX = "Gasher, Loro, Zolo, Hukku, Zul'Lor and Mijan each guard a balcony. When the last of the six dies the barrier in front of Jammal'an the Prophet opens and he and Ogom the Wretched can be attacked; until then they cannot."
local PLACES = " The Classic data lists six possible places for each of them, so who stands on which balcony changes from run to run."
local NO_GROUND = "Nothing here casts a single-target spell worth eating. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat."
local DRAGON_FIRE = "In the Classic data this dragon is IMMUNE to nature damage: Lightning Bolt and Earth Shock do nothing. It is not marked immune to fire, so Searing Totem and Flame Shock still work."

local DUNGEONS = {
	{
		key = "sunken-temple",
		name = "The Sunken Temple",
		match = { "sunken temple", "atal'hakkar" },
		stops = {
			{
				key = "upperring", kind = "trash", title = "Upper ring: Atal'ai trolls",
				here = "Warriors, Witch Doctors, Unliving, Slaves",
				threat = "Hex, Chain Lightning, heals, Enrage at 30%",
				act = {
					{ "Interrupt the Witch Doctors' Healing Wave", "Atal'ai Witch Doctor casts Healing Wave on a hurt friend (235-280) and Chain Lightning, which jumps to 3 players. Both have a cast time and can be interrupted." },
					{ "Slow or stun Witch Doctors: they flee", "Atal'ai Witch Doctors run at 15% health. Slow, stun or finish them before they reach the next pack." },
				},
				watch = {
					{ "Witch Doctor: Hex on one player", "Hex is instant: one player is transformed and confused. Its dispel type is MAGIC, so a priest or a paladin removes it." },
					{ "Unliving Atal'ai: Enrage at 30%", "Unliving Atal'ai carry Thrash and Wandering Plague from the start and Enrage at 30% health: 50 more damage and much faster swings. Atal'ai Warriors add Strike and Rend, a bleed." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Warriors, Unliving hit in melee", "Atal'ai Warriors (Strike, Rend) and Unliving Atal'ai (Thrash, Enrage at 30%) are all melee. Earthbind Totem instead if the Witch Doctors keep getting away at 15%." },
					{ "fire", "Magma Totem", "Atal'ai Slaves are not elite", "Atal'ai Slaves are level 46-47 and not elite, and the Classic data gives them no abilities: area damage clears them. They cannot be feared." },
					{ "water", "Disease Cleansing Totem", "Unliving: Wandering Plague", "Unliving Atal'ai spread Wandering Plague, a DISEASE that raises damage taken, lowers a stat and jumps to players nearby. The totem, a priest or a paladin removes it." },
					{ "air", "Grounding Totem", "eats a Hex or a Lightning Bolt", "Hex, Lightning Bolt and Chain Lightning from the Atal'ai Witch Doctors are each aimed at one player, so Grounding can take one." },
				} },
				cite = { 11641, 11986, 12058, 9532, 8247, 3436, 8876, 8269, 13446, 13445 },
			},
			{
				key = "gasherloro", kind = "boss", title = "Gasher and Loro",
				names = { "Gasher", "Loro" },
				threat = "Melee, Shield Slam stun, threat drop",
				act = {
					{ "Kill all six trolls: opens Jammal'an", SIX .. PLACES },
				},
				watch = {
					{ "Loro: Shield Slam stun, Hate to Zero", "Loro stuns one player with Shield Slam and carries Hate to Zero, a proc that by its name empties his threat list: he can turn on anyone. Gasher only uses Strike." },
					{ "Loro: Shield Spike, blocks most hits", "Loro's Shield Spike procs 45-75 damage back and Improved Blocking raises his block by 85. Both trolls are undead: no fear, no sleep. They are not marked immune to stun." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "all melee: Strike, Shield Slam", "Gasher's Strike and Loro's Shield Slam are physical. Nothing here is a fear, a charm or a sleep." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff on these two." },
					{ "air", "Tranquil Air Totem", "Loro's Hate to Zero", "Hate to Zero resets Loro's threat, and a healer is the first thing he sees after it. Windfury if the tank picks him back up without trouble.", or_ = "Windfury Totem" },
				} },
				cite = { 15580, 12782, 9205, 8242, 3639, 13540 },
			},
			{
				key = "zolohukku", kind = "boss", title = "Zolo and Hukku",
				names = { "Zolo", "Hukku" },
				threat = "Shadow Bolt Volley, Chain Lightning, demons",
				act = {
					{ "Interrupt Hukku's Shadow Bolt Volley", "Hukku's Shadow Bolt Volley hits everyone around him and has a cast time: interrupt it, and Zolo's Chain Lightning (jumps to 3 players) too. Neither is marked immune to interrupts or stuns." },
					{ "Kill Zolo's totem; kill all six trolls", "Zolo plants an Atal'ai Skeleton Totem (an Atal'ai Totem appears): kill it. " .. SIX },
				},
				watch = {
					{ "Hukku: Voidwalker, Succubus and Imp", "Hukku's Guardians stand with him before the pull: Hukku's Voidwalker, Hukku's Succubus and Hukku's Imp. Plan for four enemies, not one." },
					{ "Hukku: Curse of Blood on one player", "Curse of Blood raises the damage that player takes. It is a CURSE: a mage or a druid removes it. He also casts Shadow Bolt at one player." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Hukku brings three guardians", "The Voidwalker, Succubus and Imp come with Hukku, and Curse of Blood raises damage taken. Nothing here is a fear, a charm or a sleep." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Blood is a curse: a mage or a druid removes it, a shaman cannot." },
					{ "air", "Grounding Totem", "eats a bolt or Curse of Blood", "Hukku's Shadow Bolt and Curse of Blood and Zolo's Chain Lightning are each aimed at one player. The Shadow Bolt Volley hits everyone and cannot be eaten." },
				} },
				cite = { 12058, 12506, 12790, 12279, 9081, 12471, 13540 },
			},
			{
				key = "zullormijan", kind = "boss", title = "Zul'Lor and Mijan",
				names = { "Zul'Lor", "Mijan" },
				threat = "Cleave, Frailty, a healer with a ward",
				act = {
					{ "Interrupt Mijan's heals, kill his ward", "Mijan casts Healing Wave (477-553) at 50% health, Renew on a hurt friend and a Healing Ward totem. All three have a cast time and can be interrupted; kill the ward if it lands." },
					{ "Kill all six trolls: opens Jammal'an", SIX .. PLACES },
				},
				watch = {
					{ "Zul'Lor: Frailty on all near him", "Frailty lowers the stats of everyone around Zul'Lor and stacks up to 10 times: ranged and healers stand away. It is MAGIC: a priest or a paladin removes it. His Cleave hits up to 3 players in melee." },
					{ "Mijan: Thorns Aura hurts attackers", "Thorns Aura is a damage shield of 20 on Mijan and his party. Renew is a MAGIC buff: Purge takes it off." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Zul'Lor's Cleave", "Zul'Lor's Cleave hits up to 3 players in melee range. Nothing here is a fear, a charm or a sleep." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Frailty is magic: a priest or a paladin removes it. No disease or poison." },
					{ "air", "Windfury Totem", "no casts to ground", "Frailty is an area effect and Mijan's spells go to his friends, so Grounding has nothing to take. Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15584, 12530, 8148, 8362, 11899, 12492, 13540 },
			},
			{
				key = "pit", kind = "trash", title = "The pit: slimes, worms, oozes",
				here = "Slime Maggots, Murk Worms, Oozes, Deep Lurkers",
				threat = "Slowing Poison, Trample, swarms of maggots",
				act = {
					{ "Use area damage on the Slime Maggots", "Slime Maggots are level 45-46, not elite, and the most common creature in the temple. The Classic data gives them no abilities." },
					{ "Interrupt Acid of Hakkar", "The Spawn of Hakkar, one elite down here, casts Acid of Hakkar on one player: damage over time that stacks up to 100 times. It has a cast time and can be interrupted." },
				},
				watch = {
					{ "Saturated Ooze: splits into Oozelings", "A Saturated Ooze summons an Oozeling during the fight and again when it dies. Oozelings are level 40 and not elite." },
					{ "Deep Lurker: Trample hits all near it", "Deep Lurker's Trample hits everyone around it: ranged and healers stand away. Murk Worms carry Slowing Poison: slower attacks and slower movement." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "everything here is melee", "Slime Maggots, Murk Worms, Saturated Oozes and Deep Lurkers only hit in melee." },
					{ "fire", "Magma Totem", "Slime Maggots, Oozelings", "Slime Maggots and Oozelings are not elite: area fire damage clears them." },
					{ "water", "Poison Cleansing Totem", "Murk Worm Slowing Poison", "Slowing Poison from the Murk Worms is a POISON that slows attacks (25) and movement (30). The totem, a druid or a paladin removes it." },
					{ "air", "Windfury Totem", "only cast: Acid of Hakkar", "The Spawn of Hakkar's Acid of Hakkar is the only spell aimed at one player down here: Grounding for that pull, Windfury for the rest.", or_ = "Grounding Totem" },
				} },
				cite = { 12280, 8601, 7992, 12018, 12250, 5568 },
			},
			{
				key = "atalalarion", kind = "boss", title = "Atal'alarion", optional = true,
				names = { "Atal'alarion" },
				threat = "Knockback cone, stun around him",
				act = {
					{ "Use the statues: S, N, SW, SE, NW, NE", "Six statues must be activated in order: south, north, south-west, south-east, north-west, north-east (the order in the Classic data). A right statue lights green, a wrong one sets off a trap; after the sixth Atal'alarion and the Idol of Hakkar appear at the bottom of the pit." },
					{ "Tank him with your back to a wall", "Sweeping Slam hits everyone in front of him and knocks them back a long way. Only the tank stands in front." },
				},
				watch = {
					{ "Ground Tremor: stuns all around him", "Ground Tremor stuns everyone around Atal'alarion. Ranged and healers stand away so a stunned tank still gets healed." },
					{ "Wrong statue: a trap goes off", "Each statue is checked against the order, and a mistake sets off the nearest trap. The Altar of Hakkar is there to show the order." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Sweeping Slam on the tank", "Sweeping Slam and Ground Tremor are physical. Ground Tremor is a stun, not a fear: Tremor Totem does nothing for it." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", NO_GROUND, or_ = "Tranquil Air Totem" },
				} },
				cite = { 12887, 6524 },
			},
			{
				key = "dragonkin", kind = "trash", title = "Dragonkin halls",
				here = "Scalebanes, Wyrmkin, Wanderers, Whelps",
				threat = "Sleep, Pierce Armor, Acid Spit",
				act = {
					{ "Interrupt the Wyrmkin's Sleep", "Nightmare Wyrmkin cast Sleep on one player and Acid Spit from range. Both have a cast time and can be interrupted. Sleep is MAGIC: a priest or a paladin removes it." },
				},
				watch = {
					{ "Wanderer: Pierce Armor, armor -75%", "Nightmare Wanderer's Pierce Armor cuts its target's armor by 75%, and it adds Strike. Kill Wanderers before they wear the tank down." },
					{ "Scalebane: Shield Spike, blocks a lot", "Nightmare Scalebanes carry Shield Spike, a damage proc, and raise their block with Improved Blocking. Nightmare Whelps are not elite." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Wyrmkin cast Sleep", "Nightmare Wyrmkin put one player to sleep; the spell has the sleep mechanic, which Tremor Totem breaks." },
					{ "fire", "Magma Totem", "Nightmare Whelps are not elite", "Nightmare Whelps are level 49-50 and not elite: area fire damage clears them. The halls' dragonkin are not marked immune to fire." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Sleep is magic. No disease or poison in these halls: Acid Spit is plain nature damage." },
					{ "air", "Grounding Totem", "eats a Sleep or an Acid Spit", "Sleep and Acid Spit are each aimed at one player, so Grounding can take one." },
				} },
				cite = { 12098, 9591, 12097, 11976, 12099, 3248, 15653 },
			},
			{
				key = "hakkari", kind = "trash", title = "Hakkari Frostwings and Sappers",
				here = "Hakkari Frostwings, Hakkari Sappers",
				threat = "Frostbolt Volley, Mana Burn, knockback",
				act = {
					{ "Interrupt Frostbolt Volley", "Hakkari Frostwing's Frostbolt Volley hits everyone around it for 226-240 frost damage and slows them. It has a cast time and can be interrupted." },
					{ "Interrupt the Sappers' Mana Burn", "Hakkari Sapper burns mana from one player with Mana Burn. It has a cast time and can be interrupted." },
				},
				watch = {
					{ "Frostwing: Frost Nova roots, Swoop stuns", "Frost Nova roots everyone around the Frostwing and Swoop stuns whoever is in front of it. The root and the Volley's slow are MAGIC: a priest or a paladin removes them." },
					{ "Sapper: Wing Flap knocks back in front", "Wing Flap knocks back everyone in front of the Hakkari Sapper. Tank it with your back to a wall. The Classic data lists six Frostwings and six Sappers." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Swoop and melee on the tank", "No fear, charm or sleep from these two: Swoop is a stun and Frost Nova a root, which Tremor Totem does not break." },
					{ "fire", "Frost Resistance Totem", "Frostbolt Volley 226-240", "Frostbolt Volley hits the whole group for 226-240 frost damage and Frost Nova adds more." },
					{ "water", "Mana Spring Totem", "Sappers burn mana", "Mana Burn drains casters. Nothing here is a disease or a poison." },
					{ "air", "Grounding Totem", "eats a Mana Burn", "Mana Burn is aimed at one player, so Grounding can take it. Frostbolt Volley and Frost Nova are area effects and cannot be eaten." },
				} },
				cite = { 8398, 5708, 11831, 11981, 12882 },
			},
			{
				key = "avatar", kind = "boss", title = "Avatar of Hakkar", optional = true,
				names = { "Avatar of Hakkar", "Shade of Hakkar" },
				threat = "Waves of adds, mind control, curse",
				act = {
					{ "Loot Bloodkeepers, douse the 4 flames", "Hakkari Bloodkeepers carry the Hakkari blood that puts out the Eternal Flames. Each flame can be used once; when the fourth is doused the Shade of Hakkar becomes the Avatar of Hakkar and the waves stop." },
					{ "Kill each Nightmare Suppressor fast", "15-45 seconds after a flame is doused a Nightmare Suppressor comes in through one of the two doors and walks to the Shade. If its Suppression is still on the Shade 20 seconds after it lands, the event fails: the Shade leaves and the flames reset." },
				},
				watch = {
					{ "Waves: a Minion at every circle", "The Shade of Hakkar appears and the two doors are used as combat doors. The first wave is a Hakkari Minion on every circle plus one Hakkari Bloodkeeper; 50 seconds later 1-3 more come every 3-15 seconds. Another Bloodkeeper can only come after a Suppressor has died." },
					{ "Avatar: Cause Insanity = mind control", "Cause Insanity charms one player and speeds them up; it is MAGIC, so a priest or a paladin removes it. Lash stuns its target and disarms them (Dropped Weapon). Curse of Tongues slows casting by 50 for everyone around him: a mage or a druid removes it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Tremor will not break the charm", "Cause Insanity is a mind control, but in the Classic data it does not carry the charm type that Tremor Totem removes (Tremor removes fear, charm and sleep by type). It is MAGIC: a priest or a paladin dispels it, or Grounding eats the cast." },
					{ "fire", "Magma Totem", "Hakkari Minions are not elite", "Hakkari Minions are level 45-46, not elite, and keep coming until the fourth flame is out. Hakkari Bloodkeepers and Nightmare Suppressors are elite." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Tongues is a curse and Cause Insanity and Corruption are magic: none is a shaman's to remove. A long event, so mana matters." },
					{ "air", "Grounding Totem", "can eat Cause Insanity", "Cause Insanity and the Bloodkeepers' Shadow Bolt and Corruption are each aimed at one player. Curse of Tongues is an area effect and cannot be eaten." },
				} },
				cite = { 12623, 12639, 12889, 6607, 12888, 12471, 11671, 7741 },
			},
			{
				key = "jammalanhall", kind = "trash", title = "Jammal'an's hall",
				here = "Deathwalkers, Corpse Eaters, High Priest",
				threat = "Fear, Heal, Shadow Word: Pain, skeletons",
				act = {
					{ "Interrupt the High Priest's Heal", "Atal'ai High Priest heals a friend for 590-684 with Heal and casts Renew and Shadow Bolt. All three have a cast time and can be interrupted." },
					{ "Interrupt the Deathwalkers' Fear", "Atal'ai Deathwalkers cast Fear on one player (it has a cast time) and Shadow Word: Pain. Both are MAGIC: a priest or a paladin removes them." },
				},
				watch = {
					{ "Deathwalker dies: its Spirit appears", "A dying Atal'ai Deathwalker summons an Atal'ai Deathwalker's Spirit next to its body. Five Deathwalkers stand near Jammal'an." },
					{ "High Priest: Shadow Shield at 30%", "At 30% health the Atal'ai High Priest puts up Shadow Shield, an absorb. It and Renew are MAGIC buffs: Purge takes them off. It can also summon an Atal'ai Skeleton." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Deathwalkers cast Fear", "Atal'ai Deathwalkers cast Fear on one player. Deathwalkers and Atal'ai Corpse Eaters are undead and cannot be feared or slept themselves." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Fear and Shadow Word: Pain are magic. No disease or poison in this hall." },
					{ "air", "Grounding Totem", "eats a Fear or a Shadow Bolt", "The Deathwalkers' Fear and Shadow Word: Pain and the High Priest's Shadow Bolt are each aimed at one player." },
				} },
				cite = { 12096, 11639, 12095, 12039, 8362, 12040, 12151, 9613, 12134 },
			},
			{
				key = "jammalan", kind = "boss", title = "Jammal'an and Ogom",
				names = { "Jammal'an the Prophet", "Ogom the Wretched" },
				threat = "Hex of Jammal'an, Flamestrike, shadow",
				act = {
					{ "Clear the hall first: he calls for help", "Jammal'an yells and calls for help when he is pulled. Atal'ai Deathwalkers, Corpse Eaters and a High Priest stand near him, and Ogom the Wretched is at his side." },
					{ "Move out of Flamestrike", "Flamestrike hits an area and leaves fire burning on the ground there. Jammal'an is marked immune to interrupts, silence and stun, so the cast cannot be stopped: step out." },
				},
				watch = {
					{ "Hex of Jammal'an: mind control after a delay", "Jammal'an marks one player with Hex of Jammal'an. When the mark runs out that player is transformed, deals more damage, is slowed and is charmed: they fight for him. The transform is a CURSE: a mage or a druid removes it. The charm has no dispel type in the Classic data and not the type Tremor Totem removes." },
					{ "Ogom: Shadow Bolt, Curse of Weakness", "Ogom the Wretched casts Shadow Bolt (can be interrupted), Curse of Weakness and Shadow Word: Pain, and unlike Jammal'an is not marked immune to stun or silence. Jammal'an also plants an Earthgrab Totem and casts Healing Wave (477-553) at 50% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "the tank holds two elites", "Jammal'an and Ogom are pulled together. Jammal'an cannot be feared, stunned, silenced or interrupted." },
					{ "water", "Mana Spring Totem", "curses, magic: not yours", "Hex of Jammal'an and Curse of Weakness are curses (mage, druid); Shadow Word: Pain is magic (priest, paladin). Fire Resistance Totem instead if the group keeps standing in Flamestrike." },
					{ "air", "Grounding Totem", "eats the Hex or a Shadow Bolt", "The Hex of Jammal'an mark and Ogom's Shadow Bolt, Curse of Weakness and Shadow Word: Pain are each aimed at one player. Flamestrike is an area spell and cannot be eaten." },
				} },
				cite = { 12479, 12480, 12468, 8376, 12492, 12493, 11639, 12471, 13540 },
			},
			{
				key = "dreamscythe", kind = "boss", title = "Dreamscythe and Weaver", optional = true,
				names = { "Dreamscythe", "Weaver" },
				threat = "Acid Breath cone, Wing Flap knockback",
				act = {
					{ "Tank faces them away: Acid Breath", "Acid Breath hits everyone in front of the dragon and stacks up to 10 times. Only the tank stands in front." },
					{ "Tank with your back to a wall", "Wing Flap knocks back everyone in front of the dragon. With a wall behind them the tank is not thrown across the room." },
				},
				watch = {
					{ "They appear when Jammal'an dies", "Dreamscythe and Weaver have no place of their own in the Classic data: Jammal'an the Prophet's death spawns them. Expect them after that fight, not before." },
					{ "Immune to nature, stuns, interrupts", "Both are IMMUNE to nature damage and cannot be stunned, slowed, rooted, silenced, slept, feared or interrupted." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee and breath on the tank", "Nothing they do is a fear, a charm or a sleep. Wing Flap is a knockback." },
					{ "fire", "Searing Totem", "nature immune, fire works", DRAGON_FIRE },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Acid Breath has no dispel type in the Classic data: it is not marked a poison or a disease, so no cleansing totem helps." },
					{ "air", "Windfury Totem", "breath is nature", "No single-target casts to ground. Acid Breath is nature damage in a cone: Nature Resistance Totem if more than the tank keeps getting hit.", or_ = "Nature Resistance Totem" },
				} },
				cite = { 12884, 12882, 16359 },
			},
			{
				key = "morphaz", kind = "boss", title = "Morphaz and Hazzas", optional = true,
				names = { "Morphaz", "Hazzas" },
				threat = "Two dragons: Acid Breath, Wing Flap",
				act = {
					{ "Tank faces them away: Acid Breath", "Morphaz and Hazzas stand together and both use Acid Breath on everyone in front of them; it stacks up to 10 times. Only the tank stands in front." },
					{ "Tank with your back to a wall", "Both use Wing Flap, a knockback on everyone in front. With a wall behind them the tank is not thrown across the room." },
				},
				watch = {
					{ "Two at once: they stand side by side", "Morphaz and Hazzas are a few yards apart and have the same two abilities. Plan for both on the tank." },
					{ "Immune to nature, stuns, interrupts", "Both are IMMUNE to nature damage and cannot be stunned, slowed, rooted, silenced, slept, feared or interrupted." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "two dragons on the tank", "Nothing they do is a fear, a charm or a sleep. Wing Flap is a knockback." },
					{ "fire", "Searing Totem", "nature immune, fire works", DRAGON_FIRE },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Acid Breath has no dispel type in the Classic data: it is not marked a poison or a disease, so no cleansing totem helps." },
					{ "air", "Windfury Totem", "breath is nature", "No single-target casts to ground. Acid Breath is nature damage in a cone: Nature Resistance Totem if more than the tank keeps getting hit.", or_ = "Nature Resistance Totem" },
				} },
				cite = { 12884, 12882 },
			},
			{
				key = "eranikus", kind = "boss", title = "Shade of Eranikus",
				names = { "Shade of Eranikus" },
				threat = "Deep Slumber, War Stomp stun, Acid Breath",
				act = {
					{ "Tank faces him away: Acid Breath", "Acid Breath hits everyone in front of the Shade and stacks up to 10 times. Only the tank stands in front." },
					{ "Stand away from him: War Stomp stuns", "War Stomp stuns and hits everyone around the Shade. Ranged and healers stand away so the group is not stunned together." },
				},
				watch = {
					{ "Deep Slumber: one player out cold", "Deep Slumber stuns one player and makes them immune to damage while it lasts. Its dispel type is MAGIC (priest, paladin). The Shade is marked immune to interrupts, so do not count on stopping the cast." },
					{ "He sleeps until Jammal'an is dead", "The Shade lies asleep and cannot be attacked until Jammal'an the Prophet is dead. He is IMMUNE to nature damage and cannot be stunned, slowed, rooted, silenced or feared, and he carries Thrash." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Thrash and melee on the tank", "Deep Slumber is a stun in the Classic data, not a sleep, and War Stomp is a stun too: Tremor Totem breaks neither." },
					{ "fire", "Searing Totem", "nature immune, fire works", DRAGON_FIRE },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Deep Slumber is magic: a priest or a paladin removes it. Acid Breath has no dispel type." },
					{ "air", "Grounding Totem", "can eat Deep Slumber", "Deep Slumber is cast at one player, so Grounding can take it. Acid Breath and War Stomp are area effects and cannot be eaten." },
				} },
				cite = { 12890, 11876, 12891, 8876, 12535 },
			},
		},
	},
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
