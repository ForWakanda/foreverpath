-- HearthAndHustle / Data / DungeonTips_Stratholme.lua
-- Dungeon tips: Stratholme (Main Gate and Service Gate). Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 329, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local DUNGEONS = {
	{
		key = "stratholme-main-gate",
		name = "Stratholme: Main Gate",
		match = "stratholme",
		wing = "Main Gate",
		stops = {
			{
				key = "streets", kind = "trash", title = "Main gate streets",
				here = "Skeletal Guardians, Berserkers, Cadavers",
				threat = "Frost and arcane casts, disease, Cleave",
				act = {
					{ "Kill an Eye of Naxxramas the moment it shows", "An Eye of Naxxramas hangs invisible (Greater Invisibility) until it pulls, then stands still and casts Summon Rockwing Gargoyles. The cast can be interrupted; otherwise kill the Eye first." },
					{ "Stand back from Patchwork Horrors", "Patchwork Horrors walk the streets by Hearthsinger Forresten. Their Disease Cloud keeps hitting everyone around them for 25-29 nature damage, Knock Away throws the tank and Thrash gives extra attacks. Ranged and healers stand away. The cloud leaves nothing a totem can cleanse." },
				},
				watch = {
					{ "Mangled Cadaver: Cadaver Worms disease", "Mangled Cadavers carry Cadaver Worms: their hits can leave a disease that does 150 damage per tick and stops health regeneration. A priest, paladin or shaman removes it. Ravaged Cadavers leave a Broken Cadaver when they die." },
					{ "Plague Ghoul: Ghoul Plague, Enrage at 30%", "Plague Ghouls cast Ghoul Plague (a disease: slower movement, less damage done), a Cleave that hits up to 3 players, and Enrage at 30% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee packs, Cleave", "Skeletal Berserkers (Strike, Cleave, Hamstring), Ravaged Cadavers and Plague Ghouls all hit in melee. Nothing on these streets fears, charms or sleeps." },
					{ "water", "Disease Cleansing Totem", "Cadaver Worms, Ghoul Plague", "Cadaver Worms from Mangled Cadavers and Ghoul Plague from Plague Ghouls are both diseases." },
					{ "air", "Grounding Totem", "Guardian bolts", "Skeletal Guardians cast Frostbolt, Arcane Bolt or Shadow Bolt at one player and Grounding takes one. Their Cone of Cold and Arcane Explosion are area spells and cannot be eaten.", or_ = "Windfury Totem" },
				} },
				cite = { 16380, 16381, 16345, 16346, 10101, 16142, 16143, 16324, 16458, 8599, 15584, 15496, 9080, 9672, 13901, 9613, 12557, 11975 },
			},
			{
				key = "courier", kind = "boss", title = "Stratholme Courier", optional = true,
				names = { "Stratholme Courier" },
				threat = "Snap Kick stun, Pummel interrupt",
				act = {
					{ "Kill him: only a stun and a Pummel", "Snap Kick stuns his target and Pummel interrupts its cast. He has no area damage, no fear and nothing to cleanse." },
				},
				watch = {
					{ "Snap Kick: stuns his target", "Snap Kick stuns one player, normally the tank. The Courier is undead and cannot be feared, charmed or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee only", "Everything the Courier does is a melee ability on his target." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15618, 15615 },
			},
			{
				key = "postmaster", kind = "boss", title = "Postmaster Malown", optional = true,
				names = { "Postmaster Malown" },
				threat = "Fear, curses, 3 Undead Postmen per box",
				act = {
					{ "Open a third postbox to call him", "Every postbox your group opens summons 3 Undead Postmen next to the player who opened it. After two boxes, the next one also summons Postmaster Malown there. He is summoned once; later boxes do nothing." },
					{ "Interrupt his Fear", "Postmaster Malown casts Fear on one player. It has a cast time and can be interrupted; it is a magic effect (a priest or paladin dispels it) and Tremor Totem breaks it." },
				},
				watch = {
					{ "Postmaster: curses, Backhand stun, Thrash", "Curse of Weakness lands on everyone around him and Curse of Tongues slows the casting of a random mana user. A mage or a druid removes curses. Backhand stuns his target and Thrash gives him extra attacks. He cannot be feared or put to sleep." },
					{ "Undead Postman: Wailing Dead curse on all", "Undead Postmen cast Wailing Dead, a curse on everyone around them, and Call of the Grave (another curse) as they die. They are elite and cannot be feared or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "the Postmaster casts Fear", "Postmaster Malown's Fear is a fear on one player: Tremor Totem breaks it. Stoneskin while only Postmen are up." },
					{ "water", "Mana Spring Totem", "curses are not yours to remove", "Curse of Weakness, Curse of Tongues, Wailing Dead and Call of the Grave are curses: a mage or a druid removes them, a shaman cannot." },
					{ "air", "Grounding Totem", "eats his Fear or Tongues", "Fear and Curse of Tongues are each aimed at one player: Grounding takes one. Curse of Weakness and Wailing Dead are area curses and cannot be eaten." },
				} },
				cite = { 24627, 6253, 12542, 12741, 13338, 3417, 7713, 5137 },
			},
			{
				key = "skul", kind = "boss", title = "Skul", optional = true,
				names = { "Skul" },
				threat = "Frostbolt, Arcane Bolt, Frost Shock",
				act = {
					{ "Interrupt his Frostbolt and Arcane Bolt", "Skul is a caster who fights from range: Frostbolt (damage and a slow) or Arcane Bolt, both with a cast time and interruptible, plus an instant Frost Shock." },
				},
				watch = {
					{ "Rare: he is not there on every run", "Skul is a rare spawn in the main gate streets and may be absent. He cannot be feared or put to sleep." },
					{ "Frost Armor: Purge it off him", "He keeps Frost Armor on himself: more armor, and Chilled (slower attacks and movement) on whoever hits him. It is a magic buff, so a shaman's Purge removes it; he casts it again when it is gone." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "no fear to break", "Nothing he does is a fear, a charm or a sleep. Stoneskin by default, Strength of Earth for a melee group.", or_ = "Strength of Earth Totem" },
					{ "fire", "Frost Resistance Totem", "Frostbolt, Frost Shock", "Frost Resistance is a Fire totem. Frostbolt and Frost Shock are frost damage; Arcane Bolt is not." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "His slows are magic effects: a priest or paladin dispels them, a shaman cannot." },
					{ "air", "Grounding Totem", "eats a bolt or a Frost Shock", "Frostbolt, Arcane Bolt and Frost Shock are each aimed at one player. Grounding takes one of them." },
				} },
				cite = { 12544, 6136, 15499, 16799, 15230 },
			},
			{
				key = "forresten", kind = "boss", title = "Hearthsinger Forresten", optional = true,
				names = { "Hearthsinger Forresten" },
				threat = "Sleep, Multi-Shot, Demoralizing Shout",
				act = {
					{ "Interrupt Enchanting Lullaby", "Enchanting Lullaby puts one player to sleep. It has a cast time and can be interrupted. It is a magic effect (a priest or paladin dispels it) and Tremor Totem breaks sleep." },
				},
				watch = {
					{ "Rare: he is not there on every run", "Hearthsinger Forresten is a rare spawn in the main gate streets and may be absent. He cannot be feared, charmed or put to sleep." },
					{ "He shoots from range: Multi-Shot hits 3", "He fights from range with Shoot and a Multi-Shot that hits up to 3 players. Incorporeal Defense gives him 50% dodge and Demoralizing Shout lowers attack power around him." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Enchanting Lullaby is a sleep", "Enchanting Lullaby is a sleep on one player; Tremor Totem removes sleep." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. The Lullaby is magic: a priest or paladin dispels it." },
					{ "air", "Grounding Totem", "eats an Enchanting Lullaby", "Enchanting Lullaby is a spell aimed at one player: Grounding takes it. Shoot and Multi-Shot are weapon attacks and cannot be eaten." },
				} },
				cite = { 16798, 16331, 16244, 14443, 16100 },
			},
			{
				key = "ghosts", kind = "trash", title = "Ghost streets: citizens, phantoms",
				here = "Spectral and Ghostly Citizens, Plague Ghouls",
				threat = "Healing cut by 75%, stat drain, stealth",
				act = {
					{ "Remove Veil of Shadow from the tank", "Ghostly Citizens cast Veil of Shadow: a curse that cuts healing taken by 75%. A mage or a druid removes it; a shaman cannot, so call it out." },
				},
				watch = {
					{ "Spectral Citizen: Debilitating Touch", "Spectral Citizens stack Debilitating Touch (magic, up to 5 times, lowers stats) and cast Haunting Phantoms, a curse with a cast time that can be interrupted. Both kinds of citizen have Incorporeal Defense: 50% dodge." },
					{ "Vengeful Phantom: stealthed, Frost Shock", "Vengeful Phantoms wait in stealth and cast Frost Shock (damage and a slow). Four of them stand around The Unforgiven." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "citizens and ghouls melee", "The citizens and the Plague Ghouls (Cleave, Enrage at 30%) fight in melee. Nothing here fears, charms or sleeps." },
					{ "water", "Disease Cleansing Totem", "Plague Ghouls: Ghoul Plague", "Ghoul Plague is a disease. Veil of Shadow and Haunting Phantoms are curses and stay on." },
					{ "air", "Grounding Totem", "eats a Phantom Frost Shock", "Haunting Phantoms and the Phantoms' Frost Shock are each a spell aimed at one player: Grounding takes one of them. Veil of Shadow is an ability in the Classic data and goes through." },
				} },
				cite = { 22687, 16333, 16336, 16331, 15089, 22766, 16458, 8599 },
			},
			{
				key = "unforgiven", kind = "boss", title = "The Unforgiven", optional = true,
				names = { "The Unforgiven" },
				threat = "Stealthed boss, Frost Nova, 4 Phantoms",
				act = {
					{ "Clear the 4 Vengeful Phantoms with him", "Four Vengeful Phantoms stand in stealth around The Unforgiven and cast Frost Shock. They are not elite: area damage or a quick kill each." },
				},
				watch = {
					{ "He is stealthed until you come in sight", "The Unforgiven spawns in stealth and shows himself when a player crosses his line of sight. He cannot be feared or put to sleep." },
					{ "Frost Nova: roots everyone near him", "Frost Nova does light damage (28-32) and roots every player around him. It is a magic effect: a priest or paladin dispels it. Ranged and healers stand away." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "5 enemies in melee", "The Unforgiven and four Vengeful Phantoms are all on the group at once." },
					{ "fire", "Magma Totem", "Phantoms are not elite", "The four Vengeful Phantoms are level 56-57 and not elite: Magma Totem at the tank's feet wears them down." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Frost Nova and Frost Shock are magic effects: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Phantom Frost Shock", "Frost Shock is aimed at one player. The boss's Frost Nova is an area spell and cannot be eaten." },
				} },
				cite = { 22766, 8822, 14907, 15089 },
			},
			{
				key = "balzaphon", kind = "boss", title = "Balzaphon", optional = true,
				names = { "Balzaphon" },
				threat = "Frostbolt Volley, Cone of Cold, Fear",
				act = {
					{ "Stay out of his front: Cone of Cold", "Cone of Cold hits and slows everyone in a cone in front of him. Only the tank stands in front." },
					{ "Heal through Frostbolt Volley", "Frostbolt Volley hits and slows everyone around him (226-240). He is immune to interrupts, stuns and silence, so the cast cannot be stopped." },
				},
				watch = {
					{ "At 30%: Fear on one player", "At 30% health he casts Fear on one player. It is a magic effect (a priest or paladin dispels it) and Tremor Totem breaks it." },
					{ "Event boss: he may be absent", "Balzaphon is an event boss in the Classic data: he may be absent. His spot is the street next to The Unforgiven." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Fear at 30% health", "He casts Fear on one player at 30% health. Stoneskin until then if you like." },
					{ "fire", "Frost Resistance Totem", "all his damage is frost", "Frost Resistance is a Fire totem. Frostbolt, Frostbolt Volley and Cone of Cold are all frost." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "The slows and the Fear are magic effects: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Frostbolt or the Fear", "Frostbolt and Fear are aimed at one player. The Volley and Cone of Cold are area spells and cannot be eaten." },
				} },
				cite = { 12096, 12557, 8398, 16799 },
			},
			{
				key = "fras", kind = "boss", title = "Fras Siabi", optional = true,
				names = { "Fras Siabi" },
				threat = "Smoke Bomb area stun, Flame Breath cone",
				act = {
					{ "Stay out of his front: Flame Breath", "Flame Breath is a cone of fire in front of him. Only the tank stands in front. It has a cast time and can be interrupted." },
				},
				watch = {
					{ "Smoke Bomb: stuns everyone near him", "Smoke Bomb is instant and stuns every player around him. It is a magic effect: a priest or paladin dispels it. Ranged and healers stand away." },
					{ "Event boss: he may be absent", "Fras Siabi has no spawn of his own in the Classic data: he is summoned by an event and may be absent. He cannot be feared or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Smoke Bomb is a stun, not fear", "Smoke Bomb is a stun: Tremor Totem does nothing against it." },
					{ "water", "Fire Resistance Totem", "Flame Breath is fire", "Fire Resistance is a Water totem. Flame Breath is his only damage spell and it is fire." },
					{ "air", "Windfury Totem", "no casts to ground", "Flame Breath is a cone and Smoke Bomb an area effect: neither can be eaten. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 7964, 17294, 20712 },
			},
			{
				key = "trap", kind = "trash", title = "Gate trap: Scarlet side",
				here = "30 Plagued Rats, Maggots or Insects",
				threat = "Two gates shut, 30 plagued critters",
				act = {
					{ "Use area damage on the 30 critters", "All 30 are of one kind, level 55 and not elite: Plagued Rats, Plagued Maggots or Plagued Insects. Area spells, Magma Totem or Fire Nova Totem clear them." },
				},
				watch = {
					{ "Trap point: two gates shut for 20 s", "When a player or a pet comes within about 5 yards of the trap point, two gates close. 2 seconds later 30 plagued critters spawn at that point and attack. The gates open again after 20 seconds and the trap arms again 30 minutes later." },
					{ "Rats, Maggots: disease. Insects: poison", "Plagued Rats cast Black Rot (disease, less dodge), Plagued Maggots Maggot Slime (disease, less attack power), Plagued Insects Festering Bites (poison, less crit)." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "30 weak melee attackers", "Stoneskin takes a piece off every one of many small hits. Stoneclaw pulls critters off a healer for a moment.", or_ = "Stoneclaw Totem" },
					{ "fire", "Magma Totem", "30 non-elite critters", "Thirty level 55 critters in one spot: Magma Totem or a Fire Nova Totem in the middle of them.", or_ = "Fire Nova Totem" },
					{ "water", "Disease Cleansing Totem", "rats, maggots; insects: Poison", "Black Rot and Maggot Slime are diseases. If the swarm is Plagued Insects, Festering Bites is a poison: Poison Cleansing Totem instead." },
					{ "air", "Windfury Totem", "no casts to ground", "The critters only bite. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16448, 16449, 16460 },
			},
			{
				key = "courtyard", kind = "trash", title = "Bastion courtyard: barricades",
				here = "Crimson Guardsmen, Conjurors, Initiates",
				threat = "Heals, Frost Nova, Shield Charge, runners",
				act = {
					{ "Interrupt the Initiates' Flash Heal", "Crimson Initiates heal their friends with Flash Heal (584-712) and Renew, both with a cast time and interruptible, and cast Mind Blast. Kill them first." },
					{ "Stop runners: all flee at 15% health", "Guardsmen, Conjurors and Initiates all run at 15% health, and more Crimson packs stand at the next barricade. Slow or stun them; Earthbind Totem helps." },
				},
				watch = {
					{ "Conjuror: Water Elemental, Frost Nova", "Crimson Conjurors summon a Water Elemental (cast time, interruptible), root everyone near them with Frost Nova, and cast Scorch and Frostbolt. Guardsmen Shield Charge (knockback), Disarm, and Shield Bash a casting player." },
					{ "Last courtyard kill: Timmy the Cruel", "When the last Crimson defender in the courtyard dies, Timmy the Cruel is summoned close by. When the last barricade's group dies, up to 3 defenders still standing at the earlier barricades run to hold it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "runners at 15% health", "Stoneskin against the Guardsmen while they fight; Earthbind Totem when a pack gets low, because every Crimson soldier here runs at 15%.", or_ = "Earthbind Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison from the Crimson soldiers. Frost Nova and the Frostbolt slow are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Mind Blast or Scorch", "Mind Blast, Scorch and Frostbolt are each aimed at one player. Frost Nova is an area spell and cannot be eaten." },
				} },
				cite = { 17138, 8362, 17194, 17162, 12674, 17195, 12675, 15749, 6713, 11972 },
			},
			{
				key = "timmy", kind = "boss", title = "Timmy the Cruel", optional = true,
				names = { "Timmy the Cruel" },
				threat = "Ravenous Claw, Thrash, Enrage at 20%",
				act = {
					{ "Keep the tank topped: Ravenous Claw", "Ravenous Claw hits one player for 925-1075 and heals Timmy for it. Thrash gives him extra attacks, so tank damage comes in bursts." },
					{ "Save cooldowns for 20%: Enrage", "At 20% health he Enrages: more melee damage and faster attacks until he dies. He cannot be feared or put to sleep." },
				},
				watch = {
					{ "Summoned when the courtyard is clear", "Timmy is summoned near the courtyard when its last Crimson Initiate, Gallant, Guardsman, Conjuror or Battle Mage dies. Leave a pack alive and he does not come." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Thrash and Ravenous Claw", "All physical, all on the tank, and faster after the Enrage at 20%." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 12787, 17470, 8599 },
			},
			{
				key = "halls", kind = "trash", title = "Bastion entrance, Hall of Lights",
				here = "Crimson Conjurors, Guardsmen, Initiates",
				threat = "Same Crimson packs, plus reinforcements",
				act = {
					{ "Turn for 5 skeletons after the corridor", "When the Crimson group holding the entrance corridor dies, 5 Skeletal Guardians and Skeletal Berserkers spawn behind you, on the stairs side, and run into the corridor. Do not sit down to drink yet." },
				},
				watch = {
					{ "Hall of Lights cleared: 2 Gallants run in", "When the Hall of Lights group dies, 2 Crimson Gallants spawn and run to guard a door there. Gallants use Crusader Strike (stacks up to 5, each raising damage taken) and Holy Strike." },
					{ "Initiates heal, everyone runs at 15%", "Same packs as the courtyard: interrupt the Initiates' Flash Heal, expect a Conjuror's Frost Nova and Water Elemental, and stop runners at 15% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "runners at 15% health", "Stoneskin while they fight; Earthbind Totem when a pack gets low, because every Crimson soldier here runs at 15%.", or_ = "Earthbind Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Frost Nova, the Frostbolt slow and Crusader Strike are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Mind Blast or Scorch", "Mind Blast, Scorch and Frostbolt are each aimed at one player. The skeletons that run in add Frostbolt, Arcane Bolt and Shadow Bolt." },
				} },
				cite = { 17138, 12674, 17162, 14518, 17143, 17194, 17195, 9672 },
			},
			{
				key = "malor", kind = "boss", title = "Malor the Zealous",
				names = { "Malor the Zealous" },
				threat = "Area stun, heals himself",
				act = {
					{ "Interrupt Holy Light", "Malor casts Holy Light (467-541, cast time, interruptible) on a hurt friend and again at 20% health. Keep an interrupt ready for the last fifth of the fight." },
					{ "Stand back from him: Ground Smash", "Ground Smash damages and stuns everyone around him. Ranged and healers stay out of its reach; only melee should take it." },
				},
				watch = {
					{ "Lay on Hands: instant, cannot be stopped", "Malor has Lay on Hands, an instant heal as large as his full health, on himself or a friend, that no interrupt can stop. Keep mana for a second round." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee boss, no fear", "Ground Smash is a stun, not a fear: Tremor does nothing. Head Crack lowers a stat on the tank." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison, and his heals can make the fight long." },
					{ "air", "Windfury Totem", "no casts to ground", "Nothing he casts is aimed at a player as a spell. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 12734, 10310, 16172, 15493 },
			},
			{
				key = "wing", kind = "trash", title = "Willey's wing: Defenders, Priests",
				here = "Crimson Defenders, Priests, Sorcerers",
				threat = "Heals, Polymorph, stuns, Divine Shield",
				act = {
					{ "Interrupt Heal and Holy Light", "Crimson Priests cast Heal (879-1021) and Crimson Defenders cast Holy Light (467-541) on their friends. Both have a cast time and can be interrupted. Kill the Priest first." },
					{ "Interrupt the Sorcerers' Polymorph", "Crimson Sorcerers Polymorph one player (cast time, interruptible; a priest or paladin dispels it) and cast Fire Blast and Arcane Bolt." },
				},
				watch = {
					{ "Defender: Divine Shield, Hammer of Justice", "Crimson Defenders stun one player with Hammer of Justice (magic: dispel it) and use Divine Shield, which makes them immune to all damage while it lasts. Switch targets until it drops." },
					{ "Shaman: Purge Arcane Might and shields", "Crimson Sorcerers put Arcane Might on friends (more damage done) and Crimson Priests Power Word: Shield (absorbs 274). Both are magic buffs: Purge removes them. All three types run at 15% health. Two Crimson Gallants stand in this wing as well." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Defenders melee; no fear here", "Polymorph and Hammer of Justice are not fear, charm or sleep: Tremor does nothing against them." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Polymorph, Hammer of Justice and the Holy Fire burn are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Holy Fire or Fire Blast", "Holy Fire (304-386), Holy Smite, Fire Blast and Arcane Bolt are each a spell aimed at one player: Grounding takes one of them." },
				} },
				cite = { 15586, 15493, 13323, 14145, 15230, 17150, 13874, 13005, 17142, 15238, 17139 },
			},
			{
				key = "willey", kind = "boss", title = "Cannon Master Willey", optional = true,
				names = { "Cannon Master Willey" },
				threat = "Riflemen adds, Shoot, Knock Away",
				act = {
					{ "Kill the Crimson Riflemen as they come", "Willey summons Crimson Riflemen about 15 seconds into the fight and then every 30 seconds. They go for whoever Willey is attacking, so they pile onto the tank." },
					{ "Tank him with your back to a wall", "Knock Away throws his current target back (first at 11 seconds, then every 14). Pummel interrupts that player's cast (first at 7 seconds, then every 12)." },
				},
				watch = {
					{ "Shoot: a random player out of melee", "Every 3-4 seconds Willey Shoots a random player who is not in melee range for 215-289 physical damage. Ranged and healers take steady hits." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Knock Away, adds on the tank", "Willey's melee and Knock Away land on the tank, and each wave of Riflemen is sent at the same player." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect. Healing Stream if the Shoot damage on the back line adds up.", or_ = "Healing Stream Totem" },
					{ "air", "Windwall Totem", "Shoot is ranged physical", "Willey's Shoot is a physical ranged attack on players out of melee: Windwall lowers it. He casts no spell at a player, so there is nothing to ground." },
				} },
				cite = { 10101, 15615, 16496, 17279 },
			},
			{
				key = "inner", kind = "trash", title = "Inner Bastion: Gallants, Battle Mages",
				here = "Crimson Gallants, Battle Mages, Inquisitors",
				threat = "Mana Burn, area fire and arcane, kicks",
				act = {
					{ "Interrupt the Inquisitors' Mana Burn", "Crimson Inquisitors cast Mana Burn (363-401 mana) at a random mana user, plus Shadow Word: Pain and Mind Flay. Mana Burn has a cast time and can be interrupted. Their Shadow Barrier cuts damage taken: a magic buff, Purge it." },
					{ "Keep ranged away from Battle Mages", "Crimson Battle Mages hit everyone around them: Arcane Explosion (165-180, cast time, interruptible) and Blast Wave (161-187 fire and a slow). Their Immolate aura can set an attacker on fire (magic: a priest or paladin dispels it)." },
				},
				watch = {
					{ "Monk: Kick interrupts. Gallant: stacks", "Crimson Monks Kick (interrupts a cast) and Thrash for extra attacks. Crimson Gallants stack Crusader Strike on the tank up to 5 times, each raising damage taken; it is a magic effect a priest or paladin can dispel." },
					{ "Cleared corridors call reinforcements", "When the first inner corridor's group dies, 5 Skeletal Guardians and Berserkers run in. When the second corridor's group dies, a Crimson Monk and a Crimson Sorcerer spawn and take post at a door. The Crimson soldiers run at 15% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Gallants and Monks in melee", "Crusader Strike stacks raise the damage the tank takes, and Monks Thrash. Nothing here fears, charms or sleeps." },
					{ "water", "Mana Spring Totem", "Mana Burn; nothing to cleanse", "No disease or poison. Shadow Word: Pain is magic: a priest or paladin dispels it." },
					{ "air", "Grounding Totem", "eats a Mana Burn", "Mana Burn, Shadow Word: Pain and Mind Flay are each aimed at one player. Arcane Explosion and Blast Wave are area spells and cannot be eaten." },
				} },
				cite = { 15785, 17146, 17165, 17151, 15253, 17145, 15733, 15732, 11978, 8876, 14518, 17143 },
			},
			{
				key = "galford", kind = "boss", title = "Archivist Galford",
				names = { "Archivist Galford" },
				threat = "Pyroblast, Burning Winds stun, Fire Nova",
				act = {
					{ "Interrupt Pyroblast", "Pyroblast hits one player for 637-739 fire damage and leaves a burn. It has a cast time and can be interrupted." },
					{ "Dispel Burning Winds", "Burning Winds stuns one player and burns for 200 fire damage per tick. It has a cast time (interrupt it) and is a magic effect: a priest or paladin dispels it." },
				},
				watch = {
					{ "Fire Nova: hits everyone near him", "Fire Nova is instant fire damage to everyone around him (197-227; a second version in the Classic data does 555-645). Ranged and healers stand away." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "no fear; tank takes melee", "Burning Winds is a stun, not a fear: Tremor does nothing against it." },
					{ "water", "Fire Resistance Totem", "every spell he has is fire", "Fire Resistance is a Water totem. Fire Nova, Pyroblast and Burning Winds are all fire damage." },
					{ "air", "Grounding Totem", "eats Pyroblast or the stun", "Pyroblast and Burning Winds are each aimed at one player. Fire Nova is an area spell and cannot be eaten." },
				} },
				cite = { 17366, 17274, 17293, 23462 },
			},
			{
				key = "balnazzar", kind = "boss", title = "Dathrohan / Balnazzar",
				names = { "Grand Crusader Dathrohan", "Balnazzar" },
				threat = "Area stun, then fear, sleep, shadow",
				act = {
					{ "Hold cooldowns: at 40% he starts over", "Below 40% health Grand Crusader Dathrohan casts Balnazzar Transform: everyone around him is stunned and he becomes Balnazzar with full health and mana. The second form is the real fight." },
					{ "Interrupt Sleep and Mind Blast", "As Balnazzar he casts Sleep on a random player (magic: a priest or paladin dispels it) and Mind Blast on the tank for 370-430. Both have a cast time and can be interrupted." },
				},
				watch = {
					{ "Dathrohan: Crusader's Hammer area stun", "As Dathrohan: Crusader's Hammer stuns everyone around him (ranged and healers stand away), Crusader Strike stacks on the tank, Holy Strike, Mind Blast." },
					{ "Balnazzar: Psychic Scream, Shadow Shock", "As Balnazzar: Psychic Scream fears up to 5 players, Shadow Shock hits everyone around him for 210-242, and he casts Mind Control at the tank. When he dies, 5 skeletons run in from the corridor." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Psychic Scream and Sleep", "Balnazzar's Psychic Scream is a fear and Sleep is a sleep: Tremor Totem works on both. As Dathrohan he only stuns, so Stoneskin until 40%." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Sleep and Crusader's Hammer are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Sleep or Mind Blast", "Sleep and Mind Blast are each aimed at one player. Psychic Scream and Shadow Shock are area spells and cannot be eaten." },
				} },
				cite = { 17286, 17281, 17284, 17288, 17398, 17399, 17287, 13704, 12098, 15690 },
			},
			{
				key = "jariensothos", kind = "boss", title = "Jarien and Sothos", optional = true,
				names = { "Jarien", "Sothos" },
				threat = "Area fear, shadow volley, Mortal Strike",
				act = {
					{ "Interrupt Sothos's Fear", "Sothos casts Fear on everyone around him. It has a cast time and can be interrupted; it is a magic effect (a priest or paladin dispels it) and Tremor Totem breaks it." },
					{ "Stand away from Sothos: shadow volley", "Sothos's Shadow Bolt Volley is instant and hits everyone around him for 595-805. Ranged and healers stand away from him. He also Shield Charges (knockback) and stuns with Shield Slam." },
				},
				watch = {
					{ "Jarien: Mortal Strike halves heals", "Jarien: Mortal Strike (healing taken halved on his target), a Cleave that hits up to 3 players, Shadow Shock for 210-242 and Cripple, a magic slow that also slows attacks. When Jarien or Sothos dies a spirit with Vengeance (double damage, more health) is summoned by the body and fights on." },
					{ "Summoned only: not there by themselves", "Jarien and Sothos have no spawn of their own in the Classic data: an event summons them at a spot by Grand Crusader Dathrohan's room, and most runs never see them. Neither can be feared or put to sleep. With both dead a reward box is summoned." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Sothos casts an area Fear", "Sothos's Fear hits everyone around him; Tremor Totem breaks fear." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Fear and Cripple are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Shadow Shock or Cripple", "Jarien's Shadow Shock and Cripple are each aimed at one player: Grounding takes one. Sothos's Fear and Shadow Bolt Volley are area spells and cannot be eaten." },
				} },
				cite = { 27641, 27646, 15749, 15655, 12169, 16856, 15284, 22575, 20812, 27645, 27643, 27644, 27650 },
			},
		},
	},
	{
		key = "stratholme-service-gate",
		name = "Stratholme: Service Gate",
		match = "stratholme",
		wing = "Service Gate",
		stops = {
			{
				key = "service", kind = "trash", title = "Service Gate: Barthilas's street",
				here = "Skeletal Guardians, Berserkers, Cadavers",
				threat = "Casts, Cadaver Worms disease, Cleave",
				act = {
					{ "Expect Barthilas to run off", "When the Service Entrance gate is used and Magistrate Barthilas is alive and out of combat, he yells, runs for a door and 8 seconds later is moved further in on this side. You fight him later." },
				},
				watch = {
					{ "Mangled Cadaver: Cadaver Worms disease", "Mangled Cadavers carry Cadaver Worms: their hits can leave a disease that does 150 damage per tick and stops health regeneration. A priest, paladin or shaman removes it. Ravaged Cadavers leave a Broken Cadaver when they die." },
					{ "Aurius: Medallion quest, helps at Baron", "Aurius kneels close to where Barthilas stands. If someone hands in the Medallion of Faith quest to him, he appears next to Baron Rivendare 5 seconds into that fight and attacks the Baron." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee packs, Cleave", "Skeletal Berserkers (Strike, Cleave, Hamstring) and the Cadavers hit in melee. Nothing here fears, charms or sleeps." },
					{ "water", "Disease Cleansing Totem", "Cadaver Worms", "Cadaver Worms from the Mangled Cadavers is a disease." },
					{ "air", "Grounding Totem", "Guardian bolts", "Skeletal Guardians cast Frostbolt, Arcane Bolt or Shadow Bolt at one player and Grounding takes one. Their Cone of Cold and Arcane Explosion are area spells and cannot be eaten.", or_ = "Windfury Totem" },
				} },
				cite = { 16142, 16143, 16324, 15496, 9080, 9672, 13901, 9613, 12557, 11975 },
			},
			{
				key = "gauntlet", kind = "trash", title = "Gauntlet: ghouls, gargoyles, banshees",
				here = "Ghoul Raveners, Rockwing Screechers, Banshees",
				threat = "Area fear, area silence, big life leech",
				act = {
					{ "Mind the first gate: Baron's 45 minutes", "Using the first gauntlet gate puts The Baron's Ultimatum on the group and starts 45 minutes. Baron Rivendare must be engaged before they run out, then killed, or he kills Ysida. He yells at 10 and at 5 minutes left." },
					{ "Kill Rockwing Screechers first", "Rockwing Screechers cast Terrifying Howl, an instant fear on everyone around them, plus Gargoyle Strike and Demoralizing Shout. Tremor Totem breaks the fear." },
				},
				watch = {
					{ "Shrieking Banshee: silence around her", "Shrieking Banshees fight from range: Deafening Screech silences everyone around them, and Banshee Wail (128-172) can be interrupted. Healers keep their distance from them. An Eye of Naxxramas hangs invisible near Stonespine's spot: when it pulls it casts Summon Rockwing Gargoyles (interruptible)." },
					{ "Ghoul Ravener: Ravenous Claw 463-537", "Ghoul Raveners hit one player with Ravenous Claw for 463-537 and heal themselves for it. Fleshflayer Ghouls Rend (a bleed) and Thrash, Rockwing Gargoyles stack Sunder Armor up to 5 on the tank, Crypt Beasts root with Encasing Webs and their hits leave Virulent Poison." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Screechers: Terrifying Howl", "Rockwing Screechers cast Terrifying Howl, a fear on everyone around them." },
					{ "water", "Poison Cleansing Totem", "Crypt Beast: Virulent Poison", "Crypt Beasts leave Virulent Poison with their hits: a poison that stacks up to 3 times. Mana Spring on pulls without a Crypt Beast." },
					{ "air", "Grounding Totem", "eats a Wail or Gargoyle Strike", "Banshee Wail and Gargoyle Strike are each aimed at one player. Terrifying Howl and Deafening Screech are area effects and cannot be eaten." },
				} },
				cite = { 27861, 8715, 16997, 13730, 3589, 16868, 16553, 13738, 8876, 13444, 4962, 16428, 16427, 16380, 16381 },
			},
			{
				key = "stonespine", kind = "boss", title = "Stonespine", optional = true,
				names = { "Stonespine" },
				threat = "Vicious Rend bleed on the tank",
				act = {
					{ "Heal through Vicious Rend", "Vicious Rend is a bleed on one player that stacks up to 3 times (34 damage per tick). It is a bleed, not a magic effect, disease or poison: nobody removes it." },
				},
				watch = {
					{ "Rare: he is not there on every run", "Stonespine is a rare spawn in the gauntlet between Nerub'enkan's and Baroness Anastari's ziggurats and may be absent. He cannot be feared, charmed or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee boss, bleed on tank", "Vicious Rend and his melee are all he has: physical damage on the tank." },
					{ "water", "Mana Spring Totem", "a bleed cannot be cleansed", "Vicious Rend is a bleed. No disease or poison on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 14331 },
			},
			{
				key = "cultists", kind = "trash", title = "Ziggurats: Thuzadin cultists",
				here = "Thuzadin Shadowcasters, Necromancers, Acolytes",
				threat = "Shadow Bolts, Soul Tap, Cripple, webs",
				act = {
					{ "Kill every Acolyte behind each boss", "Killing a ziggurat boss opens the door behind it. Inside stand Thuzadin Acolytes, 5 by each boss. When all of one ziggurat's Acolytes are dead its crystal dies; all three ziggurats done opens the gates to the slaughterhouse square." },
					{ "Interrupt the Shadowcasters", "Thuzadin Shadowcasters cast Shadow Bolt (192-258), Cripple (magic: slows movement and attacks, lowers stats) and Piercing Shadow (a curse: 100 less shadow resistance). All three have a cast time and can be interrupted." },
				},
				watch = {
					{ "Necromancer: Soul Tap, Bone Armor", "Thuzadin Necromancers stand with a Skeletal Servant, drain health and mana with Soul Tap (350 of each per tick; magic, a priest or paladin dispels it) and shield a friend with Bone Armor (absorbs 1388-1612; a magic buff, Purge it)." },
					{ "Crypt Crawler: web that also silences", "Crypt Crawlers cast Enveloping Web on one player: rooted, silenced and unable to attack. Wailing Banshees cast Banshee Curse (less hit chance; a mage or druid removes it) and Anti-Magic Shield, which makes them immune to spells while it is up. Plague Ghouls stand by the Anastari and Maleki ziggurats: Ghoul Plague (a disease), Cleave, Enrage at 30%." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "no fear from the cultists", "Cripple, Soul Tap and the webs are not fear, charm or sleep: Tremor does nothing here." },
					{ "water", "Mana Spring Totem", "ghouls: disease", "The cultists leave nothing a shaman removes: Soul Tap and Cripple are magic, Piercing Shadow and Banshee Curse are curses. Disease Cleansing on a pull with Plague Ghouls: Ghoul Plague is a disease.", or_ = "Disease Cleansing Totem" },
					{ "air", "Grounding Totem", "eats a Shadow Bolt or Cripple", "Shadow Bolt, Cripple, Piercing Shadow and Soul Tap are each aimed at one player. Grounding takes one of them." },
				} },
				cite = { 15232, 11443, 16429, 16430, 16431, 12420, 15471, 17105, 19645, 16458, 8599, 15584, 7 },
			},
			{
				key = "anastari", kind = "boss", title = "Baroness Anastari",
				names = { "Baroness Anastari" },
				threat = "Mind control, area silence, Banshee Wail",
				act = {
					{ "Hit the possessed player to half health", "Possess takes over a random player other than her main target (first at 15 seconds, then every 30) and ends when that player drops below 50% health. The possessed player does double damage; the Baroness is invisible and immune meanwhile." },
					{ "Interrupt Silence", "Silence has a cast time and silences everyone around her (first at 25 seconds, then every 25). It is a magic effect: a priest or paladin dispels it. Banshee Wail (213-287 on a random player every 2-3 seconds) can be interrupted too." },
				},
				watch = {
					{ "Banshee Curse: less hit chance, all", "Banshee Curse lands on everyone around her (first at 10 seconds, then every 20): 10% less hit chance. It is a curse: a mage or a druid removes it." },
					{ "After her: Acolytes behind the door", "Her death opens the ziggurat door behind her. Kill every Thuzadin Acolyte inside, or the way to the slaughterhouse stays shut. She cannot be feared, charmed or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Tremor does not break Possess", "Tremor Totem does not remove Possess: the only way out is to bring the possessed player below half health. Stoneskin for her melee on the tank." },
					{ "water", "Mana Spring Totem", "curse is not yours to remove", "Banshee Curse is a curse and Silence is magic. No disease or poison on this fight." },
					{ "air", "Grounding Totem", "eats a Wail or a Possess", "Banshee Wail and Possess are each a spell aimed at one player: Grounding takes one of them. Banshee Curse and Silence are area spells and cannot be eaten." },
				} },
				cite = { 16565, 16867, 18327, 17244, 17246, 17250 },
			},
			{
				key = "nerubenkan", kind = "boss", title = "Nerub'enkan",
				names = { "Nerub'enkan" },
				threat = "Pierce Armor, web root, scarab adds",
				act = {
					{ "Kill the scarabs with area damage", "Crypt Scarabs summons Crypt Scarabs next to him and Raise Undead Scarab adds an Undead Scarab in front of him. Area damage keeps them off the healer." },
					{ "Watch the tank after Pierce Armor", "Pierce Armor halves the armor of one player, so his melee hits that player much harder. Encasing Webs roots one player and stops their attacks; it is not marked interruptible." },
				},
				watch = {
					{ "After him: Acolytes behind the door", "His death opens the ziggurat door behind him. Kill every Thuzadin Acolyte inside. He cannot be feared, charmed or put to sleep." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Pierce Armor on the tank", "Pierce Armor halves the tank's armor, so every melee hit after it is bigger." },
					{ "fire", "Magma Totem", "burns the scarab adds", "Crypt Scarabs and Undead Scarabs are summoned around him through the fight. Magma Totem at the tank's feet works on them as they arrive." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison on him: Pierce Armor and Encasing Webs are physical effects." },
					{ "air", "Windfury Totem", "nothing worth grounding", "Encasing Webs is a physical effect, not a spell Grounding can take. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 4962, 6016, 16418, 17235 },
			},
			{
				key = "trap", kind = "trash", title = "Gate trap: undead side",
				here = "30 Plagued Rats, Maggots or Insects",
				threat = "Two gates shut, 30 plagued critters",
				act = {
					{ "Use area damage on the 30 critters", "All 30 are of one kind, level 55 and not elite: Plagued Rats, Plagued Maggots or Plagued Insects. Area spells, Magma Totem or Fire Nova Totem clear them." },
				},
				watch = {
					{ "Trap point: two gates shut for 20 s", "When a player or a pet comes within about 5 yards of the trap point, two gates close. 2 seconds later 30 plagued critters spawn at that point and attack. The gates open again after 20 seconds and the trap arms again 30 minutes later." },
					{ "Rats, Maggots: disease. Insects: poison", "Plagued Rats cast Black Rot (disease, less dodge), Plagued Maggots Maggot Slime (disease, less attack power), Plagued Insects Festering Bites (poison, less crit)." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "30 weak melee attackers", "Stoneskin takes a piece off every one of many small hits. Stoneclaw pulls critters off a healer for a moment.", or_ = "Stoneclaw Totem" },
					{ "fire", "Magma Totem", "30 non-elite critters", "Thirty level 55 critters in one spot: Magma Totem or a Fire Nova Totem in the middle of them.", or_ = "Fire Nova Totem" },
					{ "water", "Disease Cleansing Totem", "rats, maggots; insects: Poison", "Black Rot and Maggot Slime are diseases. If the swarm is Plagued Insects, Festering Bites is a poison: Poison Cleansing Totem instead." },
					{ "air", "Windfury Totem", "no casts to ground", "The critters only bite. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16448, 16449, 16460 },
			},
			{
				key = "maleki", kind = "boss", title = "Maleki the Pallid",
				names = { "Maleki the Pallid" },
				threat = "Frostbolt, Ice Tomb, Drain Life and Mana",
				act = {
					{ "Interrupt Ice Tomb", "Ice Tomb stuns a random player other than his main target (first at 15 seconds, then every 15-20), and that player loses all threat on him. It has a cast time and can be interrupted." },
					{ "Interrupt Frostbolt when you can", "Frostbolt (167-225 and a slow) goes to a random player every 3-4 seconds. In the Classic data he is immune to charm and to nothing else." },
				},
				watch = {
					{ "Drain Life, Drain Mana: dispel them", "Drain Life (from 20 seconds in) leeches 96 health per tick from a random player; Drain Mana (from 30 seconds in) drains a random mana user. Both are magic effects: a priest or paladin dispels them." },
					{ "After him: Acolytes behind the door", "His death opens the ziggurat door behind him. Kill every Thuzadin Acolyte inside. With all three ziggurats done, the gates to the slaughterhouse square open." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "no fear; he also melees", "Ice Tomb is a stun, not a fear: Tremor does nothing against it." },
					{ "fire", "Frost Resistance Totem", "Frostbolt every 3-4 seconds", "Frost Resistance is a Fire totem. Frostbolt lands on a random player every 3-4 seconds for the whole fight." },
					{ "water", "Mana Spring Totem", "Drain Mana on mana users", "No disease or poison. Drain Life, Drain Mana and the Frostbolt slow are magic: a priest or paladin dispels them." },
					{ "air", "Grounding Totem", "eats a Frostbolt or Ice Tomb", "Frostbolt, Ice Tomb, Drain Life and Drain Mana are each a spell aimed at one player: Grounding takes one of them." },
				} },
				cite = { 12556, 17503, 17238, 17243, 16869 },
			},
			{
				key = "barthilas", kind = "boss", title = "Magistrate Barthilas", optional = true,
				names = { "Magistrate Barthilas" },
				threat = "Knockbacks, grows stronger over time",
				act = {
					{ "Kill him fast: Furious Anger stacks", "Furious Anger starts on the pull and stacks up to 25 times: each stack adds damage and attack speed and makes him bigger. The longer the fight, the harder he hits." },
					{ "Tank him with your back to a wall", "Mighty Blow knocks his target back. Crowd Pummel knocks back everyone around him and interrupts their casts: casters and healers stay out of melee range." },
				},
				watch = {
					{ "Draining Blow: heals him for 250", "Draining Blow hits one player and gives Barthilas the health (250). He cannot be feared, charmed or put to sleep." },
					{ "If he ran: fought later on this side", "If the Service Entrance gate was used while he was alive and out of combat, he was moved further in: the boss nearest his new spot is Maleki the Pallid. Otherwise he stands in his street near Aurius." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "his melee keeps growing", "Furious Anger adds melee damage and speed with every stack, up to 25." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect on this fight." },
					{ "air", "Windfury Totem", "kill him fast", "He casts no spells, and a short fight means fewer Furious Anger stacks. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16792, 16791, 16793, 10887, 14099 },
			},
			{
				key = "square", kind = "trash", title = "Slaughterhouse square: abominations",
				here = "Venom Belchers, Bile Spewers",
				threat = "Poison spit on all, slimes, a closed gate",
				act = {
					{ "Rest before the first pull: no pause after", "The first abomination you fight closes the gate behind you. From 20 seconds on, every 30-45 seconds another abomination that is not yet fighting walks to the middle. Ramstein comes when all 9 Venom Belchers and 4 Bile Spewers are dead." },
					{ "Interrupt Venom Spit", "Venom Belchers cast Venom Spit: nature damage and a poison on everyone around them, stacking up to 3 times. It has a cast time and can be interrupted. A druid, paladin or shaman removes the poison." },
				},
				watch = {
					{ "Bile Spewer: Bile Slimes, more on death", "Bile Spewers summon a Bile Slime during the fight and more Bile Slimes when they die, and Thrash for extra attacks. Venom Belchers' melee also leaves Slowing Poison: a poison that slows attacks and movement." },
					{ "After a wipe: the gate opens again", "If the group wipes, the gate opens again and the abominations stop walking in. The event starts again on the next pull." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Thrash: extra melee hits", "Bile Spewers Thrash, and a second abomination can walk in while the first still stands." },
					{ "fire", "Magma Totem", "Bile Slime adds", "Bile Spewers spawn Bile Slimes while alive and more when they die. Magma Totem at the tank's feet works on them." },
					{ "water", "Poison Cleansing Totem", "Venom Spit, Slowing Poison", "Venom Spit is a poison on everyone around the Belcher, stacking up to 3 times, and their melee procs Slowing Poison." },
					{ "air", "Windfury Totem", "no casts to ground", "Venom Spit is an area spell and cannot be eaten. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16866, 8601, 7992, 16809, 16865, 3417 },
			},
			{
				key = "ramstein", kind = "boss", title = "Ramstein the Gorger",
				names = { "Ramstein the Gorger" },
				threat = "Knockout stun and knockback, Trample",
				act = {
					{ "Tank him with your back to a wall", "Knockout hits his target very hard (weapon damage plus 300), knocks it back and stuns it. Keep the tank full before it lands." },
					{ "Keep ranged away from him: Trample", "Trample hits everyone around him. Ranged and healers stand away." },
				},
				watch = {
					{ "Comes when the last abomination dies", "When every Venom Belcher and Bile Spewer is dead the slaughterhouse door opens, Ramstein walks out into the square and the door shuts 10 seconds later. He cannot be feared or put to sleep." },
					{ "His death starts the undead rush", "The moment Ramstein dies a side gate opens and 30 Mindless Undead start running into the square. There is no pause: keep mana for area damage." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "all physical, hits hard", "Knockout, Trample and melee: nothing but physical damage." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 5568, 17307 },
			},
			{
				key = "rush", kind = "trash", title = "Undead rush after Ramstein",
				here = "30 Mindless Undead",
				threat = "30 weak undead at once",
				act = {
					{ "Use area damage on the Mindless Undead", "30 Mindless Undead are summoned one after another at the side gate, a few every second, and run to the middle of the square. They are level 56-57 and not elite: area spells, Magma Totem, Fire Nova Totem." },
				},
				watch = {
					{ "Last one dead: 60 seconds, then Guards", "When the last Mindless Undead dies you get 60 seconds before the slaughterhouse door opens and 5 Black Guard Sentries walk out. Drink." },
					{ "Mindless Undead: no fear, no sleep", "Mindless Undead cannot be feared or put to sleep. They have no spells: melee only." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "30 weak melee attackers", "Stoneskin takes a piece off every one of many small hits. Stoneclaw pulls a few off a healer for a moment.", or_ = "Stoneclaw Totem" },
					{ "fire", "Magma Totem", "30 non-elite undead", "Thirty non-elite undead run to one spot: Magma Totem or a Fire Nova Totem in the middle of them.", or_ = "Fire Nova Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison from the Mindless Undead. Healing Stream if the whole group is being hit.", or_ = "Healing Stream Totem" },
					{ "air", "Windfury Totem", "no casts to ground", "They only hit in melee. Windfury for a melee group, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 6788 },
			},
			{
				key = "guards", kind = "trash", title = "Black Guard Sentries",
				here = "5 Black Guard Sentries",
				threat = "5 elites: Cleave, Shadow Shock",
				act = {
					{ "Shackle or stun what you can: 5 elites", "The 5 Black Guard Sentries are level 58-59 elites and come out together. They cannot be feared or put to sleep; in the Classic data they are not immune to stuns, roots or a priest's shackle." },
				},
				watch = {
					{ "Sentry: Cleave, Shadow Shock", "Black Guard Sentries Cleave (hits a second player next to the tank) and cast Shadow Shock, an instant 158-182 shadow damage on one player." },
					{ "All 5 dead: the Baron's door opens", "When the fifth Sentry dies Baron Rivendare yells and the door to his room opens. A wipe here opens the gate behind you again." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "5 elites cleaving", "Five elites in melee at once, each with a Cleave." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic effect from the Sentries." },
					{ "air", "Grounding Totem", "eats a Shadow Shock", "Shadow Shock is an instant spell aimed at one player. Grounding takes one of them at a time." },
				} },
				cite = { 15623, 17439 },
			},
			{
				key = "baron", kind = "boss", title = "Baron Rivendare",
				names = { "Baron Rivendare" },
				threat = "Shadow aura, Mortal Strike, skeletons",
				act = {
					{ "Kill the Mindless Skeletons at once", "Raise Dead summons up to 6 Mindless Skeletons. Death Pact follows it: a health leech around the Baron. Area damage on the skeletons as soon as they stand up." },
					{ "Interrupt his Shadow Bolt", "Shadow Bolt hits one player for 288-388; it has a cast time and can be interrupted. Mortal Strike hits for triple weapon damage and halves healing on its target. Cleave hits up to 3 players near the tank, so melee stands behind him." },
				},
				watch = {
					{ "Unholy Aura: 150 shadow to all near him", "Unholy Aura is on him for the whole fight and keeps hitting everyone around him for 150 shadow damage. Ranged and healers stand away from him; the melee need steady healing." },
					{ "Door shuts on the pull; Aurius may join", "His door closes when the fight starts and opens on a wipe or a kill. If Aurius got the Medallion of Faith he appears 5 seconds in and attacks the Baron. Kill the Baron inside the 45 minutes and Ysida is freed, with extra Argent Dawn reputation." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Mortal Strike, Cleave", "He cannot be feared, charmed or put to sleep and casts no fear himself. His melee, Mortal Strike and Cleave are physical." },
					{ "fire", "Magma Totem", "burns the skeletons", "Up to 6 Mindless Skeletons come with each Raise Dead: Magma Totem or a Fire Nova Totem where they gather.", or_ = "Fire Nova Totem" },
					{ "water", "Healing Stream Totem", "Unholy Aura damage", "Unholy Aura hits everyone near him for 150 shadow damage again and again for the whole fight. Nothing here can be cleansed. Mana Spring if only the tank is in its reach.", or_ = "Mana Spring Totem" },
					{ "air", "Grounding Totem", "eats a Shadow Bolt", "Shadow Bolt is aimed at one player and Grounding takes it. Mortal Strike and Cleave are melee and cannot be eaten." },
				} },
				cite = { 17467, 17466, 15708, 15284, 17393, 17473, 17471, 17475, 17476, 17477, 17478, 17479, 17480, 27861, 27773 },
			},
		},
	},
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
