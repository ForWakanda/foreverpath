-- HearthAndHustle / Data / DungeonTips_Scholomance.lua
-- Dungeon tips: Scholomance. Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 289, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local MELEE_AIR = "Nothing here casts a single-target spell worth eating. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat."

local DUNGEONS = {
	{
		key = "scholomance",
		name = "Scholomance",
		match = "scholomance",
		stops = {
			{
				key = "entry", kind = "trash", title = "Entry halls",
				here = "Risen Guards, Neophytes, Acolytes, Researchers",
				threat = "Fear, Mana Burn, shadow bolts",
				act = {
					{ "Interrupt Dark Mending, the Acolytes' heal", "Scholomance Acolyte casts Dark Mending, a heal of 591-685 on a friend, with a cast time: interrupt it or kill the Acolyte first. It also casts Mana Burn, Mind Flay and Cripple." },
				},
				watch = {
					{ "Blood Steward: Paralyzing Poison", "The Blood Steward of Kirtonos stands in these halls: Paralyzing Poison (a stun), Curse of Weakness, Curse of Impotence. A druid, paladin or shaman removes the poison; a mage or a druid removes the curses." },
					{ "Researchers: Wail of Souls hits all near", "Spectral Researcher: Wail of Souls hits everyone around it with shadow damage, a knockback and a mana burn, so ranged and healers stand away. Its Mana Burn is cast when its target uses mana." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Neophytes can cast Fear", "Scholomance Neophytes can cast Fear, besides Mind Flay and Shadow Bolt. They stand in the first halls and again on the way to Ras Frostwhisper. If nobody gets feared, Stoneskin: Risen Guards stack Sunder Armor and Shield Slam (a stun) on the tank.", or_ = "Stoneskin Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse yet", "No disease in these halls. The one poison is the Blood Steward's: Poison Cleansing Totem for that pull." },
					{ "air", "Grounding Totem", "eats a Fear or a Mana Burn", "Grounding takes one single-target spell at a time: a Neophyte's Fear or Shadow Bolt, an Acolyte's or Researcher's Mana Burn. Wail of Souls is an area and goes through." },
				} },
				cite = { 17613, 17615, 17165, 11443, 3609, 12493, 22371, 17630, 17631, 12542, 12739, 15572, 15655 },
			},
			{
				key = "second", kind = "trash", title = "Aberrations, ghouls, summoners",
				here = "Aberrations, Diseased Ghouls, Necrolytes",
				threat = "Disease, shadow bolts, Curse of Blood",
				act = {
					{ "Kill the Dark Summoners first", "Scholomance Dark Summoner summons a Frail Skeleton before the pull and casts Summon Risen Lackey during the fight. Every cast is one more add: kill the summoner first." },
					{ "Use weapons on Aberrations: spells fail", "Risen Aberrations are immune to fire, nature, frost, shadow and arcane damage. Only physical and holy damage hurts them: weapons, not spells or fire totems." },
				},
				watch = {
					{ "Dark Summoner: Curse of Blood, adds", "Scholomance Dark Summoner: Curse of Blood (more damage taken; a curse with a cast time, on one player) and Summon Risen Lackey. A mage or a druid removes the curse." },
					{ "Necrolytes: Shadow Barrier, shadow bolts", "Scholomance Necrolytes put Shadow Barrier on a friend (less damage taken; a magic buff: Purge it) and cast Shadow Shock and Shadow Bolt at one player. A Necrofiend patrols here: Deadly Poison (a poison) and Web Explosion, a root on everyone around it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "packs of melee on the tank", "Risen Aberrations and Diseased Ghouls come in packs and hit in melee; the Aberrations' Fixate speeds up their attacks. Strength of Earth if the tank is never in trouble." },
					{ "water", "Disease Cleansing Totem", "Wandering Plague", "Diseased Ghouls give Wandering Plague, a disease that raises the damage its victim takes and jumps to players nearby. Their Disease Cloud (16-20 damage to everyone around them) and the Cloud of Disease where they die are plain damage: nothing to cleanse, move out." },
					{ "air", "Grounding Totem", "Necrolyte Shadow Bolts", "Scholomance Necrolytes cast Shadow Bolt and Shadow Shock at one target, and the Dark Summoner's Curse of Blood is single-target too: Grounding takes any of them." },
				} },
				cite = { 12279, 17618, 16531, 17151, 17234, 12739, 10022, 3583, 15474, 12021, 8247, 3436, 3439, 12626, 17742 },
			},
			{
				key = "kirtonos", kind = "boss", title = "Kirtonos the Herald", optional = true,
				names = { "Kirtonos the Herald" },
				threat = "Knockback, mind control, Curse of Tongues",
				act = {
					{ "Tank him facing away, back to a wall", "Swoop stuns and Wing Flap knocks back everyone in a cone in front of him. Only the tank stands in front, with a wall behind." },
					{ "Interrupt Dominate Mind", "Dominate Mind is a mind control with a cast time and can be interrupted. He also drops his threat on the player he casts it at." },
				},
				watch = {
					{ "Gargoyle: Swoop, Wing Flap knockback", "As a gargoyle: Swoop (a stun) and Wing Flap (a knockback) on everyone in front of him, Pierce Armor (half the armor) and Disarm on the tank." },
					{ "Human: Shadow Bolt Volley, mind control", "As a human: Shadow Bolt Volley on everyone, Curse of Tongues (slower casts), and Dominate Mind, which also drops his threat on that player." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Dominate Mind is a charm", "Dominate Mind is a charm (mind control), and Tremor Totem removes charm as well as fear. While he is a gargoyle, Stoneskin: Pierce Armor halves the tank's armor.", or_ = "Stoneskin Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Tongues is a curse: a mage or a druid removes it, a shaman cannot." },
					{ "air", "Grounding Totem", "can eat Dominate Mind", "Dominate Mind is cast at one player, so Grounding can take it. Curse of Tongues and the Shadow Bolt Volley hit everyone around him and cannot be eaten." },
				} },
				cite = { 18144, 12882, 6016, 8379, 16467, 17228, 12889, 14515 },
			},
			{
				key = "crypt", kind = "trash", title = "Crypt: aberrations, corpses, ghouls",
				here = "Aberrations, Reanimated Corpses, Ghouls",
				threat = "Disease on every pull",
				act = {
					{ "Use weapons on Aberrations: spells fail", "Risen Aberrations are immune to fire, nature, frost, shadow and arcane damage. Only physical and holy damage hurts them: weapons, not spells or fire totems." },
				},
				watch = {
					{ "Reanimated Corpses get back up", "A Reanimated Corpse lies down at low health, heals and stands up again: kill it twice. It casts Dark Plague." },
					{ "Ghouls leave a disease cloud: step out", "Diseased Ghouls leave a Cloud of Disease where they die. Do not stand in it to loot or drink." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "big melee packs", "About thirty Risen Aberrations down here, pulled in packs, all melee." },
					{ "water", "Disease Cleansing Totem", "Dark Plague, Wandering Plague", "Dark Plague from the Reanimated Corpses and Wandering Plague from the Diseased Ghouls are both diseases. The ghouls' Disease Cloud and the Cloud of Disease where they die are plain damage and cannot be cleansed." },
					{ "air", "Windfury Totem", "weapons for Aberrations", "Risen Aberrations are immune to every kind of spell damage except holy, so weapon hits do the work. Dark Plague is cast at one player, but Disease Cleansing already answers it.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 18270, 23965, 17742, 8247, 3436, 12626, 12021 },
			},
			{
				key = "jandice", kind = "boss", title = "Jandice Barov", optional = true,
				names = { "Jandice Barov" },
				threat = "Curse of Blood, illusions, Banish",
				act = {
					{ "Interrupt Banish and Curse of Blood", "Both have a cast time and can be interrupted. Banish takes a random player other than her current target out of the fight; Curse of Blood makes everyone around her take more damage." },
					{ "Kill the illusions, then find Jandice", "She summons illusions of herself and turns invisible, and she and the illusions scatter. Kill the illusions and pick her up again when she shows." },
				},
				watch = {
					{ "Illusions: she vanishes among them", "The first illusions come about 15 seconds into the fight, then every 25 seconds. Each time she turns invisible, and she and the illusions run off in all directions." },
					{ "Banish takes one player out for a while", "Banish stuns one player and makes that player immune to everything. It goes to a random player who is not her current target, so not the tank. It is magic: a priest or a paladin can dispel it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Curse of Blood: more damage", "Curse of Blood raises the damage taken by everyone around her while she hits the tank in melee." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Blood is a curse: not yours to remove." },
					{ "air", "Grounding Totem", "eats a Banish", "Banish is cast at one random player who is not her current target, so Grounding can take it. Curse of Blood hits everyone around her and goes through." },
				} },
				cite = { 16098, 8994, 17772, 17773, 17774 },
			},
			{
				key = "ossuary", kind = "trash", title = "Great Ossuary: hatchlings, constructs",
				here = "Adepts, Necromancers, Hatchlings, Constructs",
				threat = "Disease, frost, heavy melee",
				act = {
					{ "Tank Constructs facing away: Arcing Smash", "Risen Construct: Arcing Smash hits everyone in a cone in front of it. Only the tank stands in front." },
					{ "Interrupt Silence and Shadow Bolt Volley", "In the hall before the Ossuary, Spectral Tutors cast Silence and Scholomance Necromancers cast Shadow Bolt Volley: both have a cast time and hit everyone around the caster. Tutors also Mana Burn, and with Image Projection they turn immune for a moment and summon Spectral Projections." },
				},
				watch = {
					{ "Hatchlings come in packs: area damage", "Plagued Hatchlings around the upper ring, with their Handlers (Blast Wave, Cone of Cold, Arcane Blast)." },
					{ "Risen Constructs frenzy at low health", "Risen Constructs guard the pit: Arcing Smash on everyone in front, Thrash, and Frenzy at 30%. Risen Protectors on the way here Silence." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Constructs hit very hard", "Risen Constructs: Thrash, Arcing Smash, Frenzy at 30% health. All of it is physical." },
					{ "water", "Disease Cleansing Totem", "Hatchlings: Diseased Spit", "Plagued Hatchlings cast Diseased Spit. In the Classic data it is a disease, not a poison." },
					{ "air", "Grounding Totem", "eats an Adept's Frostbolt", "Scholomance Adepts in the hall before the Ossuary: Frostbolt, Frost Shock, Cone of Cold. Grounding takes a Frostbolt or a Frost Shock." },
				} },
				cite = { 16169, 8876, 8269, 17745, 15043, 15499, 15244, 10833, 17145, 6726, 12528, 14887, 17630, 17651, 17653 },
			},
			{
				key = "blackwood", kind = "boss", title = "Lord Blackwood", optional = true,
				names = { "Lord Blackwood" },
				threat = "Arrows, Multi-Shot, Smoke Bomb stun",
				act = {
					{ "Ranged and healers stand away: Smoke Bomb", "Smoke Bomb stuns everyone around him. It is a magic effect: a priest or a paladin can dispel it." },
					{ "Do not try to interrupt him", "He cannot be interrupted, and his Shield Bash interrupts the spell his own target is casting." },
				},
				watch = {
					{ "Black Arrow, Multi-Shot on up to 5", "He fights at range: Shoot for 215-289, Black Arrow (200 shadow damage a tick on one player) and a Multi-Shot that hits up to 5 players." },
					{ "Necromancer: Shadow Bolt Volley, runs", "Most Scholomance Necromancers stand in his hall: Shadow Bolt Volley on everyone around them (it has a cast time: interrupt it), Call of the Grave at 30% health, Corpse Explosion when one kills a player, and they flee at 15% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Strength of Earth Totem", "he shoots: no fear to break", "Lord Blackwood attacks from range with Shoot, Black Arrow and Multi-Shot, so Stoneskin does little against him. Nothing he casts is a fear." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Smoke Bomb is magic and Black Arrow has no dispel type: nothing here for a shaman to remove." },
					{ "air", "Grounding Totem", "eats a Black Arrow", "Black Arrow is aimed at one player and Grounding can take it. Grounding does not take Multi-Shot or Shoot; Windwall Totem lowers ranged physical damage such as Shoot.", or_ = "Windwall Totem" },
				} },
				cite = { 7964, 11972, 20733, 21390, 16496, 14887, 12020, 17616 },
			},
			{
				key = "rattlegore", kind = "boss", title = "Rattlegore",
				names = { "Rattlegore" },
				threat = "Heavy melee, War Stomp stun, knockback",
				act = {
					{ "Tank him with your back to a wall", "Knock Away hits his current target and throws that player back." },
				},
				watch = {
					{ "War Stomp stuns everyone close to him", "War Stomp stuns everyone near him: heal from range. Knock Away throws the tank back." },
					{ "After the kill: Viewing Room key, respawns", "In the Classic data a dropped key opens the Viewing Room door, and the door stands open once he is dead. When he dies, the room before the Viewing Room is reset to four packs of four (Risen Aberrations, Diseased Ghouls, sometimes a Reanimated Corpse) and a patrolling Necrofiend." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "all physical: Strike, War Stomp", "Strike, Knock Away, War Stomp: nothing but physical damage." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
				} },
				cite = { 10101, 18368, 16727 },
			},
			{
				key = "viewing", kind = "boss", title = "Viewing Room: Marduk and Vectus", optional = true,
				names = { "Marduk Blackpool", "Vectus" },
				threat = "Fire on the ground, shadow volleys, Cleave",
				act = {
					{ "Interrupt Vectus's Flamestrike", "Flamestrike has a cast time and can be interrupted. If it lands it leaves burning ground under its target: move out." },
					{ "Kill the students with area damage", "Marduk, Vectus and the room's Scholomance Students turn hostile 12 seconds after the Dawn Gambit event is set off. The students transform as they turn: they keep 5% of their health and a quarter of their damage." },
				},
				watch = {
					{ "Vectus: Flamestrike, move out of it", "Vectus: Flamestrike on the ground, and Blast Wave, which hits and slows everyone around him." },
					{ "Marduk: aura cuts shadow resistance", "Marduk Blackpool: Defiling Aura lowers the shadow resistance of everyone around him by 100, and his Shadow Bolt Volley hits everyone around him. He also Cleaves up to three players in melee range and has a Shadow Shield you can Purge." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Marduk cleaves in melee", "Marduk Blackpool hits and cleaves in melee. The students in the room are weak." },
					{ "water", "Fire Resistance Totem", "Blast Wave, Flamestrike", "Fire Resistance is a Water totem. Vectus's spells are fire: Blast Wave and Flamestrike." },
					{ "air", "Windfury Totem", "volleys cannot be eaten", MELEE_AIR, or_ = "Tranquil Air Totem" },
				} },
				cite = { 16046, 18399, 17695, 17697, 17228, 15284, 12040, 18115 },
			},
			{
				key = "ras", kind = "boss", title = "Ras Frostwhisper", optional = true,
				names = { "Ras Frostwhisper" },
				threat = "Fear, frost on everyone, Freeze",
				act = {
					{ "Interrupt Freeze and Frostbolt Volley", "Both have a cast time and can be interrupted, and so does his Fear. Freeze stuns one player and deals 139-161 frost damage a tick; Frostbolt Volley hits and slows everyone around him." },
					{ "Keep your back to a wall: two knockbacks", "Chill Nova and Knock Away each knock back everyone around him, not only the tank. Chill Nova also slows." },
				},
				watch = {
					{ "Freeze holds a player in place", "Freeze stuns its target and deals frost damage while it lasts. It is magic: a priest or a paladin dispels it. Chill Nova and Knock Away throw back everyone near him." },
					{ "On the way: Mana Burn, one more Fear", "Three Spectral Teachers (Mana Burn on a mana user, Arcane Focus on a friend; they can also Banish), two Acolytes, two Necromancers, a Neophyte and an Adept stand in the rooms before him." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "he casts Fear", "Ras Frostwhisper casts Fear, and a Neophyte stands in the rooms before him." },
					{ "fire", "Frost Resistance Totem", "Frostbolt Volley, Chill Nova", "Frost Resistance is a Fire totem. Frostbolt Volley and Chill Nova hit the whole group." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Freeze and the frost slows are magic: not yours to remove." },
					{ "air", "Grounding Totem", "eats his Fear or his Freeze", "Grounding takes a single-target cast: his Fear or his Freeze, or a Spectral Teacher's Mana Burn on the way. Frostbolt Volley and Chill Nova are areas and go through." },
				} },
				cite = { 18763, 12096, 8398, 18099, 11130, 17630, 17633, 8994, 12542 },
			},
			{
				key = "kormok", kind = "boss", title = "Kormok", optional = true,
				names = { "Kormok" },
				threat = "Shadow volleys, bone adds, Frenzy at 20%",
				act = {
					{ "Purge or dispel his Bone Shield", "He comes with Bone Shield up: it absorbs 2500 damage. It is a magic buff, so Purge or a priest's dispel removes it." },
					{ "Kill the Bone Minions and Bone Mages", "He casts Summon Bone Minions during the fight and Summon Bone Mages at 26% health, and puts Bloodlust on his friends: twice the attack speed, a magic buff that can be purged." },
				},
				watch = {
					{ "Shadow Bolt Volley: 255-345 on all near", "Shadow Bolt Volley is instant and hits everyone around him for 255-345 shadow damage: no interrupt, no Grounding. Kormok is only here when a player summons him, in the room where Ras Frostwhisper stands." },
					{ "At 26%: Bone Mages. At 20%: Frenzy", "At 26% health he summons Bone Mages. At 20% he enrages: more damage and attacks that are 60% faster." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "bone adds, Frenzy at 20%", "Bloodlust doubles his friends' attack speed and he enrages at 20% health: more melee damage on the tank as the fight goes on." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Nothing he casts is a disease or a poison in the Classic data. Healing Stream if the melee keep taking Shadow Bolt Volley." },
					{ "air", "Windfury Totem", "volleys cannot be eaten", MELEE_AIR, or_ = "Tranquil Air Totem" },
				} },
				cite = { 27688, 20741, 27687, 27695, 8269, 27689 },
			},
			{
				key = "six", kind = "overview", title = "The six rooms before Gandling", group = "six",
				threat = "Six bosses in any order; all six open Gandling",
			},
			{
				key = "malicia", kind = "boss", title = "Instructor Malicia", group = "six",
				names = { "Instructor Malicia" }, short = "Malicia", room = "Upper", roomHint = "upper room, with Occultists",
				threat = "Heals herself, Slow, Call of the Grave",
				brief = { SHAMAN = "Earth Shock her heals; Purge Renew" },
				act = {
					{ "Interrupt Heal and Flash Heal", "She casts Heal at half health and Flash Heal on her friends; both have a cast time and can be interrupted. Renew is a magic buff: Purge or dispel it." },
				},
				watch = {
					{ "Slow, Corruption, curse: all around her", "Slow, Corruption and Call of the Grave land on everyone around her, not on one player: ranged and healers stand away. Slow and Corruption are magic (priest, paladin); Call of the Grave is a curse (mage, druid)." },
					{ "Occultists: Dark Shade at 40%, volleys", "Scholomance Occultists Counterspell their target when it casts, can Drain Mana, and put Bone Armor on a friend (Purge it). At 40% health they transform into a Dark Shade and cast Shadow Bolt Volley on everyone around them." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "nothing to break here", "No fear in this room. Strength of Earth is as good if the tank is safe." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Corruption and Slow are magic: a priest or a paladin removes them. Call of the Grave is a curse: a mage or a druid. None is a disease or a poison." },
					{ "air", "Windfury Totem", "her spells hit everyone", "Slow, Corruption and Call of the Grave each hit everyone around her, so Grounding absorbs none of them. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15586, 17843, 8362, 13747, 18376, 17831, 16431, 15122, 17682, 17228 },
			},
			{
				key = "ravenian", kind = "boss", title = "The Ravenian", group = "six",
				names = { "The Ravenian" }, short = "Ravenian", room = "Lower", roomHint = "lower room, with Splintered Skeletons",
				threat = "All melee: Cleave, Trample, knockback",
				brief = { SHAMAN = "Stoneskin; all melee, cleaves" },
				act = {
					{ "Ranged and healers stand away: Trample", "Trample hits everyone around him, and Cleave and Sundering Cleave each hit up to three players in melee range. Only the tank and the melee stand close." },
					{ "Tank him with your back to a wall", "Knock Away hits his current target and throws that player back." },
				},
				watch = {
					{ "Cleave and Trample hit all melee", "Cleave and Sundering Cleave (cuts armor, stacks up to 5 times) each hit up to three players in melee range. Trample hits everyone close, Knock Away throws his target." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Sundering Cleave cuts armor", "Everything he does is physical, and Sundering Cleave lowers the tank's armor." },
					{ "water", "Healing Stream Totem", "Trample hits all melee", "Trample and Cleave keep the melee damaged. Mana Spring if the group is ranged." },
					{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
				} },
				cite = { 17963, 15584, 15550, 18670 },
			},
			{
				key = "krastinov", kind = "boss", title = "Doctor Theolen Krastinov", group = "six",
				names = { "Doctor Theolen Krastinov" }, short = "Krastinov", room = "Upper", roomHint = "upper room, with Diseased Ghouls",
				threat = "Hard melee, Rend, enrage at 30%",
				brief = { SHAMAN = "Disease Cleansing for his ghouls" },
				act = {
					{ "Hold damage when Backhand stuns the tank", "Backhand stuns his target and lowers that player's threat, so he can turn on someone else. Give the tank a moment to take him back." },
				},
				watch = {
					{ "Enrages at 30% health", "At 30% he enrages: more damage and attacks that are 60% faster. Rend bleeds his target, Backhand stuns it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "hits harder after 30%", "Rend, Backhand, and an enrage at 30% health. All physical." },
					{ "water", "Disease Cleansing Totem", "the ghouls in his room", "Five Diseased Ghouls stand with him and give Wandering Plague, a disease that jumps to players nearby. Once they are dead the fight has no disease: Mana Spring." },
					{ "air", "Windfury Totem", "no casts to ground", MELEE_AIR, or_ = "Tranquil Air Totem" },
				} },
				cite = { 16509, 18103, 8269, 8247, 3436, 3439 },
			},
			{
				key = "alexei", kind = "boss", title = "Lord Alexei Barov", group = "six",
				names = { "Lord Alexei Barov" }, short = "Alexei Barov", room = "Lower", roomHint = "lower room, with Risen Guards",
				threat = "Shadow aura on all, healing curse",
				brief = { SHAMAN = "Healing Stream; shadow aura" },
				act = {
					{ "Interrupt Veil of Shadow", "Veil of Shadow has a cast time and can be interrupted. It cuts the healing taken by everyone around him by 75%. It is a curse: a mage or a druid removes it." },
				},
				watch = {
					{ "Veil of Shadow: a curse, heals do less", "Veil of Shadow cuts healing taken by three quarters on everyone around him, not on one target. Stand away from him and it does not land on you." },
					{ "Unholy Aura hurts everyone near him", "Unholy Aura hits everyone close to him for 150 shadow damage a pulse, all fight long. Ranged and healer stay back. He can also cast Immolate and Drain Life at one player." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Risen Guards and Warriors", "Two Risen Guards and two Risen Warriors stand with him, all melee." },
					{ "water", "Healing Stream Totem", "Unholy Aura never stops", "The aura pulses 150 shadow damage on everyone near him for the whole fight. There is no totem against shadow damage." },
					{ "air", "Windfury Totem", "the Veil cannot be eaten", "Veil of Shadow hits everyone around him, so Grounding cannot absorb it. Immolate and Drain Life, which he can also cast, go to one player: Grounding takes those. Windfury for a melee group otherwise.", or_ = "Grounding Totem" },
				} },
				cite = { 17467, 17466, 17820, 15572, 15655, 11428, 16509, 15588, 11668, 11700 },
			},
			{
				key = "polkelt", kind = "boss", title = "Lorekeeper Polkelt", group = "six",
				names = { "Lorekeeper Polkelt" }, short = "Polkelt", room = "Upper", roomHint = "upper room, full of corpses",
				threat = "Disease: his own and the corpses'",
				brief = { SHAMAN = "Disease Cleansing; corpse room" },
				act = {
					{ "Kill Unstable Corpses a few at a time", "Each Unstable Corpse sets off Disease Burst as it dies: 750 damage to everyone around it. A whole pack dying together is that many bursts at once." },
					{ "Interrupt Volatile Infection", "Volatile Infection, a disease on one player that pulses damage onto that player's party, has a cast time and can be interrupted. So can Corrosive Acid, which cuts the armor of everyone around him." },
				},
				watch = {
					{ "Unstable Corpses burst when they die", "About twenty Unstable Corpses and some Reanimated Corpses fill the room: Dark Plague, and a Disease Burst as each Unstable Corpse dies." },
					{ "He does not fear: no Tremor needed", "Polkelt casts Volatile Infection (a disease), Corrosive Acid and Noxious Catalyst. No fear." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "the corpses all hit in melee", "The room is pulled in large packs of corpses." },
					{ "water", "Disease Cleansing Totem", "corpses, Volatile Infection", "Dark Plague from the corpses, then Polkelt's own Volatile Infection." },
					{ "air", "Windfury Totem", "his diseases get cleansed", "Volatile Infection and Noxious Catalyst are cast at one player, so Grounding can take one of them, but Disease Cleansing already removes them. Windfury for a melee group.", or_ = "Grounding Totem" },
				} },
				cite = { 18149, 18150, 18151, 8245, 18270, 17689, 23965 },
			},
			{
				key = "illucia", kind = "boss", title = "Lady Illucia Barov", group = "six",
				names = { "Lady Illucia Barov" }, short = "Illucia Barov", room = "Lower", roomHint = "lower room, with Risen Bonewarders",
				threat = "Fear, mind control, Silence",
				brief = { SHAMAN = "Tremor + Grounding; she fears" },
				act = {
					{ "Interrupt Dominate Mind, Fear and Silence", "All three have a cast time and can be interrupted. Dominate Mind and Fear go to one player; Silence hits everyone around her." },
					{ "Healers and casters stand away: Silence", "Silence and Curse of Agony land on everyone around her. Stand away from her and neither lands on you." },
				},
				watch = {
					{ "Dominate Mind: a player turns on you", "Dominate Mind takes control of one player. It is a charm and a magic effect: Tremor Totem or a priest's dispel ends it. Shadow Shock hits one player; Curse of Agony is a curse (mage, druid)." },
					{ "Bonewarders: Drain Life, Bone Armor", "Four Risen Bonewarders stand with her: Drain Life, Consuming Shadows, Bone Armor." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "she casts Fear", "Lady Illucia Barov casts Fear and Dominate Mind." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Agony is a curse: not yours to remove." },
					{ "air", "Grounding Totem", "eats Fear or Dominate Mind", "Fear, Dominate Mind and Shadow Shock are each cast at one player, so Grounding can take them. Silence and Curse of Agony hit everyone around her and go through." },
				} },
				cite = { 12528, 17289, 18671, 12542, 14515, 17620, 17715, 16431 },
			},
			{
				key = "gandling", kind = "boss", title = "Darkmaster Gandling",
				names = { "Darkmaster Gandling" },
				threat = "Arcane Missiles, a curse, players sent away",
				act = {
					{ "Sent away: kill the Guardians to get out", "Shadow Portal puts you in one of the six rooms with 3-4 Risen Guardians. That room's door shuts and opens again only when every Guardian in it is dead." },
					{ "Interrupt Curse of the Darkmaster", "Curse of the Darkmaster has a cast time and can be interrupted. It goes to his current target, lowers two of that player's stats by 50 and transforms them. A mage or a druid removes it." },
				},
				watch = {
					{ "Shadow Portal sends one player away", "Shadow Portal sends a random player, the tank included, to one of the six rooms and wipes that player's threat. First about 16 seconds in, then every 20 to 35 seconds, but not once he is at 3% health or less." },
					{ "Risen Guardians: healing curse, Cripple", "Risen Guardians cast Veil of Shadow (a curse: 75% less healing taken), Shadow Shock, Shrink, Cripple and Wither Touch. They are not elite." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Stoneclaw if you get sent away", "Stoneskin for the tank. If Shadow Portal takes you, Stoneclaw Totem pulls the Risen Guardians off you for a moment while you kill them: the door is shut, nobody can come in to help." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison on Gandling himself in the Classic data." },
					{ "air", "Grounding Totem", "can eat Shadow Portal or his curse", "Shadow Portal, Curse of the Darkmaster and Arcane Missiles are each aimed at one player, so Grounding can take whichever comes next: a Portal it eats sends nobody away. He also shields himself with Shadow Shield: Purge it." },
				} },
				cite = { 15790, 15791, 12040, 18702, 17950, 7068, 16583, 7289, 4974, 11443 },
			},
		},
	},
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
