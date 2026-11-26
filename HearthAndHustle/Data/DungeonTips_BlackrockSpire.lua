-- HearthAndHustle / Data / DungeonTips_BlackrockSpire.lua
-- Dungeon tips: Blackrock Spire (Lower and Upper). Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 229, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local DUNGEONS = {
	{
		key = "lower-blackrock-spire",
		name = "Lower Blackrock Spire",
		match = "blackrock spire",
		wing = "Lower",
		stops = {
			{
				key = "entry", kind = "trash", title = "Entry: Scarshield Legion",
				here = "Scarshield Legionnaires, Acolytes, Spellbinders",
				threat = "Heals, runners, Warlock portals, a net root",
				act = {
					{ "Interrupt the Acolytes' Heal", "Scarshield Acolyte casts Heal on a friend (590-684, it has a cast time) at 75% health, and Renew. Interrupt Heal or kill the Acolyte first." },
					{ "Kill Warlocks first: Scarshield Portal", "Scarshield Warlock casts Scarshield Portal, which summons a portal creature next to it, and Shadow Bolt. The portal cast has a cast time." },
				},
				watch = {
					{ "Acolytes and casters run at 15% health", "Scarshield Acolytes, Spellbinders and Warlocks flee at 15% health. Slow them or finish them before they run off." },
					{ "Legionnaire: Shield Bash stops your cast", "Scarshield Legionnaire: Shield Bash interrupts a spell being cast, and Cleave hits a second player next to the tank. Scarshield Raiders root one player with Hooked Net (104-120 damage)." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee packs; runners", "Legionnaires, Raiders and Scarshield Worgs hit in melee. Earthbind slows the Acolytes, Spellbinders and Warlocks that flee at 15% health.", or_ = "Earthbind Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison here. The Acolytes' Shadow Word: Pain is magic: a priest or paladin removes it." },
					{ "air", "Windfury Totem", "only small bolts to eat", "Spellbinders cast Arcane Bolt (92-124) and Warlocks Shadow Bolt (96-128) at one player. Grounding takes one of them, but nothing here is worth giving up Windfury for.", or_ = "Grounding Totem" },
				} },
				cite = { 12039, 8362, 14032, 15125, 12471, 13748, 11972, 15496, 14030 },
			},
			{
				key = "ogres", kind = "trash", title = "Ogres: Spirestone",
				here = "Reavers, Mystics, Ogre Magi, Battle Mages",
				threat = "War Stomp stun, heals, Slow, Chain Lightning",
				act = {
					{ "Interrupt the Mystics' Healing Wave", "Spirestone Mystic: Healing Wave (694-806 on a friend, it has a cast time) and an instant Rejuvenation. Interrupt the wave. Rejuvenation and the Ogre Magi's Bloodlust are magic buffs: a shaman can Purge them." },
					{ "Interrupt Battle Mages' Chain Lightning", "Spirestone Battle Mages and Warlords stand near the Spirestone Lord Magus' spot and on the side toward the Scarshield entry. Battle Mage: Chain Lightning (278-322, up to 5 players, interruptible) and Bloodlust on a friend, a magic buff to Purge. Warlord: Enrage at 30% health." },
				},
				watch = {
					{ "Reaver: War Stomp stuns all near it", "Spirestone Reaver: War Stomp stuns everyone around it and Cleave hits up to 3 players. Ranged and healers stand away from the Reavers." },
					{ "Ogre Magus: Slow on everyone near it", "Spirestone Ogre Magus: Slow (attacks 54% slower, movement 60% slower) on everyone around it; a priest or paladin removes it. Its Arcane Bolt also hits everyone around it, and at 40% health it casts Bloodlust on a friend." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "ogre melee and Cleave", "Reavers Cleave, Enforcers add Puncture (a stacking bleed) and Warlords enrage at 30% health. Tremor does nothing against War Stomp: it is a stun." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Slow is magic: a priest or paladin removes it." },
					{ "air", "Grounding Totem", "eats a Chain Lightning", "Spirestone Mystics (139-161, up to 3 players) and Battle Mages (278-322, up to 5) cast Chain Lightning at one player; Grounding can take the cast aimed at a party member. The Ogre Magi's Arcane Bolt hits an area and cannot be eaten." },
				} },
				cite = { 15982, 15981, 6742, 11876, 15284, 13747, 15979, 15659, 15978, 15976, 14516, 15305, 16170, 8269 },
			},
			{
				key = "ogrerares", kind = "boss", title = "Spirestone rares", optional = true,
				names = { "Spirestone Butcher", "Spirestone Battle Lord", "Spirestone Lord Magus" },
				threat = "Rares, may be absent: Polymorph, Bloodlust",
				act = {
					{ "Interrupt the Lord Magus' Polymorph", "Spirestone Lord Magus: Polymorph on one player and Arcane Bolt (138-186), both with a cast time and interruptible. A priest or paladin removes Polymorph." },
					{ "Purge Bloodlust and Enlarge", "At 30% health the Lord Magus casts Bloodlust on a friend (faster attacks), and he casts Enlarge on friends that lack it. Both are magic buffs: a shaman's Purge removes them." },
				},
				watch = {
					{ "Any of the three rares may be absent", "The Spirestone Butcher stands among the ogre packs on Highlord Omokk's floor. The Spirestone Battle Lord and the Lord Magus stand side by side a short way from Omokk, a little higher up. All three are rare spawns." },
					{ "Butcher, Battle Lord: no listed spells", "The Classic data lists no abilities for the Spirestone Butcher or the Spirestone Battle Lord: expect plain melee. A Reaver, a Mystic and an Ogre Magus stand near each of them." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee rares, ogre guards", "The Butcher and the Battle Lord have no listed spells, and the Reavers beside them Cleave and War Stomp." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Polymorph is magic: a priest or paladin removes it." },
					{ "air", "Grounding Totem", "eats an Arcane Bolt", "The Lord Magus casts Arcane Bolt (138-186) at one player: Grounding takes one. Against the Butcher or the Battle Lord there is nothing to eat: Windfury." },
				} },
				cite = { 13323, 15230, 6742, 8365, 11876 },
			},
			{
				key = "omokk", kind = "boss", title = "Highlord Omokk",
				names = { "Highlord Omokk" },
				threat = "Knock Away on the tank, Enrage at 20%",
				act = {
					{ "Tank him with your back to a wall", "Knock Away hits his target for extra weapon damage and throws it back. With a wall behind the tank he stays in reach." },
					{ "Clear the ogres beside him first", "A Spirestone Mystic, a Reaver and an Ogre Magus stand within 40 yards of him: the Mystic heals with Healing Wave, the Reaver stuns with War Stomp." },
				},
				watch = {
					{ "At 20%: Enrage", "At 20% health he enrages: he hits harder and attacks 60% faster. Keep the tank topped up from there." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "all melee; Enrage at 20%", "Everything he does is physical, and at 20% health he attacks 60% faster." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or magic on this fight. Healing Stream if mana is fine." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell at all. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 10101, 8269, 15982, 11876 },
			},
			{
				key = "trolls", kind = "trash", title = "Trolls: Smolderthorn",
				here = "Shadow Priests, Mystics, Axe Throwers",
				threat = "Hex, Mana Burn, Chain Heal, stuns",
				act = {
					{ "Interrupt Mana Burn and Chain Heal", "Smolderthorn Shadow Priest: Mana Burn (354-410 mana from everyone around it), cast with a mana user as target. Smolderthorn Mystic: Chain Heal on up to 3 friends. Both have a cast time and can be interrupted." },
				},
				watch = {
					{ "Shadow Priest: Hex on one player", "Smolderthorn Shadow Priests cast Hex, an instant polymorph on one player; it is magic, so a priest or paladin removes it. They also cast Dispel Magic." },
					{ "Axe Thrower: Knockdown stun, runs at 15%", "Smolderthorn Axe Thrower: Throw from range, Knockdown (a stun on one player) and Thrash; it flees at 15% health. Smolderthorn Shadow Hunters Gouge and Kick, which interrupts a cast." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Tremor does not break Hex", "Hex is a polymorph, not a fear, charm or sleep: Tremor Totem does nothing against it. Stoneskin for the Axe Throwers and Shadow Hunters." },
					{ "water", "Mana Spring Totem", "Mana Burn; nothing to cleanse", "Shadow Priests burn 354-410 mana from everyone around them. No disease or poison in these packs." },
					{ "air", "Grounding Totem", "eats a Hex", "Hex is cast at one player, so Grounding can take it; so can a Mystic's Chain Lightning (185-215). Mana Burn hits an area and cannot be eaten." },
				} },
				cite = { 15800, 15799, 11641, 15090, 11428, 15795, 8876, 12540, 15614, 16006 },
			},
			{
				key = "voshgajin", kind = "boss", title = "Shadow Hunter Vosh'gajin",
				names = { "Shadow Hunter Vosh'gajin" },
				threat = "Curse of Blood on all near her, Hex",
				act = {
					{ "Interrupt Curse of Blood", "Curse of Blood has a cast time and lands on everyone around her: more damage taken. Interrupt it; a mage or druid removes the curse." },
				},
				watch = {
					{ "Hex: one player polymorphed", "Her Hex is instant: one player is transformed and loses control. It is magic: a priest or paladin removes it. She cannot be feared or charmed." },
					{ "Near her: 3 Shadow Priests, a Mystic", "Three Smolderthorn Shadow Priests (Mana Burn, Hex), a Mystic (Chain Heal), a Shadow Hunter and a Seer stand within 40 yards of her. Clear them before the pull." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Curse of Blood: more damage", "Curse of Blood raises the damage players take. Tremor does nothing against Hex: it is a polymorph." },
					{ "water", "Mana Spring Totem", "a curse is not yours", "Curse of Blood is a curse (mage, druid) and Hex is magic (priest, paladin). Nothing here for a cleansing totem." },
					{ "air", "Grounding Totem", "can eat her Hex", "Hex is aimed at one player, so Grounding can take it. Curse of Blood is cast on everyone around her and cannot be eaten." },
				} },
				cite = { 16098, 16708, 15800, 11641, 15799 },
			},
			{
				key = "trollstwo", kind = "trash", title = "Trolls: Headhunters, Witch Doctors",
				here = "Headhunters, Witch Doctors, Seers, Berserkers",
				threat = "Healing wards, Pierce Armor, Mortal Strike",
				act = {
					{ "Interrupt the Seers' Healing Wave", "Smolderthorn Seer: Healing Wave (477-553 on a friend), Lightning Bolt and Shrink (a curse) all have a cast time and can be interrupted. Its Lightning Shield is a magic buff: Purge it. It flees at 15% health." },
					{ "Kill the Witch Doctors' wards", "Smolderthorn Witch Doctor: Superior Healing Ward (a summoned ward, the cast can be interrupted), Flame Buffet Totem and Elemental Protection Totem. Kill the ward and the totems, or the Witch Doctor first." },
				},
				watch = {
					{ "Headhunter: Pierce Armor, Impale", "Smolderthorn Headhunter: Pierce Armor halves its target's armor, Impale is a stacking bleed (40 every 3 seconds, up to 3 stacks), and it Throws from range. It flees at 15% health." },
					{ "Berserker: Mortal Strike, Enrage at 30%", "Smolderthorn Berserker: Mortal Strike (double weapon damage, healing on the target halved) and Enrage at 30% health. Shadow Priests with Hex and Mana Burn stand here too." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Pierce Armor, Mortal Strike", "Headhunters halve the tank's armor and Berserkers Mortal Strike, then enrage at 30% health." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Impale is a bleed and Shrink is a curse (mage, druid). No disease or poison." },
					{ "air", "Grounding Totem", "eats a Seer's Lightning Bolt", "Seers cast Lightning Bolt (128-172) at one player and the Shadow Priests Hex: Grounding takes one of them." },
				} },
				cite = { 12492, 15801, 15802, 13585, 15869, 15867, 8262, 6016, 16001, 17547, 8269, 11641, 15800 },
			},
			{
				key = "voone", kind = "boss", title = "War Master Voone",
				names = { "War Master Voone" },
				threat = "Mortal Strike, Throw Axe 1750, knockback",
				act = {
					{ "Tank him with your back to a wall", "Uppercut throws his target back. With a wall behind the tank he stays in reach. Snap Kick also stuns his target." },
					{ "Melee: do not stand beside the tank", "His Cleave hits up to 3 players, and Pummel interrupts a spell cast in his reach." },
				},
				watch = {
					{ "Throw Axe: 1750 damage and a stun", "Throw Axe has a cast time and hits one player for 1750 physical damage with a stun. The cast is not interruptible in the Classic data, and he cannot be feared or charmed." },
					{ "Mortal Strike: healing on tank halved", "Mortal Strike hits for triple weapon damage and halves healing on its target. Heal the tank early, not late." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "all physical, hits hard", "Mortal Strike, Cleave, Uppercut, Snap Kick, Throw Axe: every one of them is physical." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight. Healing Stream if mana is fine." },
					{ "air", "Windfury Totem", "no spells to ground", "Throw Axe is a physical throw, not a spell. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15615, 10966, 15284, 15708, 15618, 16075 },
			},
			{
				key = "grayhoof", kind = "boss", title = "Mor Grayhoof (summoned)", optional = true,
				names = { "Mor Grayhoof" },
				threat = "Hurricane, huge heals, bear and cat forms",
				act = {
					{ "Interrupt Healing Touch", "In his caster form he casts Healing Touch (7400-8600, it has a cast time, interruptible) or an instant Rejuvenation (1000 every 3 seconds). Interrupt the first; Rejuvenation is a magic buff a shaman can Purge." },
					{ "Move out of Hurricane", "Hurricane is a ground effect: 500 damage a second and much slower attacks for everyone standing in it. His Moonfire hits everyone around him (438-562, then 150 every 3 seconds)." },
				},
				watch = {
					{ "80% bear, 50% cat, 25% faerie dragon", "Bear Form at 80%: Swipe (875-1125 on up to 3), Maul with a stun, Demoralizing Roar. Cat Form at 50%: twice as fast, Shred (armor -75%), Rake, Ferocious Bite (1750-2250). If a form drops he goes back to casting." },
					{ "At 25%: Reflection sends spells back", "In Faerie Dragon Form he takes half damage, casts Chain Lightning (185-215) and Reflection, which reflects spells. Reflection is a magic buff: Purge it. He only appears when a player summons him beside War Master Voone's spot." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Swipe, Maul, Ferocious Bite", "From 80% to 25% he fights in bear and cat form: all physical, and Shred cuts the tank's armor by 75%." },
					{ "water", "Healing Stream Totem", "Moonfire ticks on everyone", "Moonfire lands on everyone around him and burns for 150 every 3 seconds. It is magic (priest, paladin); there is no disease or poison." },
					{ "air", "Windfury Totem", "Grounding for the last 25%", "Moonfire and Hurricane hit an area. Only the Chain Lightning of his last form is aimed at one player, where Grounding can take it.", or_ = "Grounding Totem" },
				} },
				cite = { 27527, 27532, 27530, 27737, 27543, 27554, 27553, 27551, 27545, 27555, 27556, 27557, 27546, 27564, 27567 },
			},
			{
				key = "firebrand", kind = "trash", title = "Orcs: Firebrand Legion",
				here = "Firebrand Grunts, Invokers, Darkweavers",
				threat = "Mark of Flames, Flamestrike, shadow volleys",
				act = {
					{ "Move out of Flamestrike", "Firebrand Invoker: Flamestrike (114-132) leaves fire on the ground that burns every 2 seconds; the cast can be interrupted. Its Fire Nova hits everyone around it, so ranged and healers stand away. It flees at 15% health." },
					{ "Interrupt the Darkweavers' volley", "Firebrand Darkweaver: Shadow Bolt Volley (96-128 on everyone around it) has a cast time and can be interrupted. It also casts Dispel Magic and flees at 15% health." },
				},
				watch = {
					{ "Mark of Flames: far more damage taken", "Every Firebrand orc casts Mark of Flames on one player: a magic debuff that raises the damage that player takes (by 1000 in the Classic data). The cast can be interrupted; a priest or paladin removes it." },
					{ "Darkweaver: Curse of the Firebrand", "Curse of the Firebrand is a curse on one player that does 657-843 damage; a mage or druid removes it. Firebrand Dreadweavers also cast it, plus Plague Cloud, a disease that lowers stats: a priest, paladin or shaman cures it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Grunts: Mortal Strike, Enrage", "Firebrand Grunts Mortal Strike (healing on the target halved) and enrage at 30% health. Legionnaires Shield Bash a cast." },
					{ "water", "Fire Resistance Totem", "Invokers: fire on everyone", "Invokers cast Flamestrike, Fire Nova and Fireball (160-216); Pyromancers Flame Shock. Swap to Disease Cleansing on a pack with a Firebrand Dreadweaver: Plague Cloud is a disease." },
					{ "air", "Grounding Totem", "eats a Mark of Flames", "Mark of Flames, Curse of the Firebrand, Fireball and Shadow Bolt are each cast at one player: Grounding takes one of them. The volley and the Fire Nova cannot be eaten." },
				} },
				cite = { 12468, 12470, 15242, 14887, 15090, 15128, 16071, 15728, 13737, 8269, 11972, 15096, 12471 },
			},
			{
				key = "bannok", kind = "boss", title = "Bannok Grimaxe", optional = true,
				names = { "Bannok Grimaxe" },
				threat = "Rare, may be absent: Mortal Strike",
				act = {
					{ "Clear the Firebrand orcs near him first", "Four Firebrand Grunts, four Invokers and three Darkweavers stand within 40 yards of him. Pull them before him." },
				},
				watch = {
					{ "Rare spawn: he may not be there", "Bannok Grimaxe is a rare spawn among the Firebrand orcs, on the same floor as War Master Voone." },
					{ "Mortal Strike: healing on tank halved", "His only ability is Mortal Strike: extra weapon damage and healing on the target halved." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "plain melee, Mortal Strike", "Mortal Strike is his only ability: plain melee apart from it." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic from him." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 13737 },
			},
			{
				key = "spiders", kind = "trash", title = "Spiders",
				here = "Spire Spiders, Spire Spiderlings",
				threat = "Crystallize cone stun, spiderling swarms",
				act = {
					{ "Tank faces spiders away: Crystallize", "Spire Spider: Crystallize stuns everyone in a cone in front of it. Only the tank stands there. It is magic: a priest or paladin removes it." },
					{ "Use area damage on the Spiderlings", "Spire Spiderlings are not elite and come in groups. A dying Spire Spider summons another one." },
				},
				watch = {
					{ "A dying Spire Spider summons a Spiderling", "Every Spire Spider casts Summon Spire Spiderling when it dies. Do not relax until the Spiderlings are dead too." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "many small melee hits", "Spiders and Spiderlings only hit in melee, several at once. Tremor does nothing against Crystallize: it is a stun." },
					{ "fire", "Magma Totem", "Spiderlings are not elite", "Area fire damage on the Spiderling groups. Fire Nova Totem for a single burst.", or_ = "Fire Nova Totem" },
					{ "water", "Mana Spring Totem", "no poison on these spiders", "Spire Spiders and Spiderlings have no poison and no disease in the Classic data. The one poison is Mother Smolderweb's." },
					{ "air", "Windfury Totem", "no casts to ground", "Nothing here casts a spell at one player. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16104, 16103 },
			},
			{
				key = "crystalfang", kind = "boss", title = "Crystal Fang", optional = true,
				names = { "Crystal Fang" },
				threat = "Rare, may be absent: spawns Spiderlings",
				act = {
					{ "Kill the Spiderlings it spawns", "Crystal Fang's one ability is to spawn Spire Spiderlings. Burn them with area damage and stay on the boss." },
				},
				watch = {
					{ "Rare spawn: it may not be there", "Crystal Fang is a rare spawn among the spiders, with four Spire Spiderlings and two Spire Spiders near it." },
					{ "Spire Spiders near it: Crystallize", "The Spire Spiders within 40 yards stun everyone in a cone in front of them with Crystallize and summon a Spiderling when they die." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee boss with a swarm", "Crystal Fang and its Spiderlings only hit in melee." },
					{ "fire", "Magma Totem", "Spiderlings are not elite", "Area fire damage for the Spire Spiderlings it spawns.", or_ = "Fire Nova Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Crystal Fang has no poison and no disease in the Classic data." },
					{ "air", "Windfury Totem", "no casts to ground", "It casts no spell. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16103, 16104 },
			},
			{
				key = "smolderweb", kind = "boss", title = "Mother Smolderweb",
				names = { "Mother Smolderweb" },
				threat = "Poison on all near her, cone stun",
				act = {
					{ "Tank faces her away: Crystallize", "Crystallize stuns everyone in a cone in front of her. Only the tank stands there; a priest or paladin removes it (magic)." },
					{ "Cure Mother's Milk: it is a poison", "Mother's Milk lands on everyone around her and stays until it is removed. A druid, paladin or shaman cures it. Ranged and healers stand away from her." },
				},
				watch = {
					{ "On death: she summons a Spiderling", "She casts Summon Spire Spiderling when she dies. Eight Spire Spiderlings and four Spire Spiders stand within 40 yards of her: clear them first." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee boss; stun is no fear", "She only hits in melee. Tremor does nothing against Crystallize: it is a stun." },
					{ "fire", "Magma Totem", "Spiderlings near her", "Area fire damage for the Spire Spiderlings around her and the one she summons on death.", or_ = "Fire Nova Totem" },
					{ "water", "Poison Cleansing Totem", "Mother's Milk is a poison", "Mother's Milk is a poison on everyone around her and it does not wear off by itself. The totem clears the players in its range." },
					{ "air", "Windfury Totem", "no casts to ground", "Both her abilities hit an area. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16468, 16104, 16103 },
			},
			{
				key = "urok", kind = "boss", title = "Urok Doomhowl (summoned)", optional = true,
				names = { "Urok Doomhowl" },
				threat = "Fear on all near him, bleeds, ogre adds",
				act = {
					{ "Ranged, healers: stay out of the Roar", "Intimidating Roar fears everyone around Urok and roots his target in place. Stand away from him so the fear does not reach you." },
					{ "Interrupt the Urok Ogre Magus' Arcane Bolt", "Urok Ogre Magus: Arcane Bolt (92-124 on everyone around it, interruptible) and Slow on everyone around it (attacks 54% slower, movement 60% slower; magic). At 30% health it casts Bloodlust on a friend: a magic buff to Purge." },
				},
				watch = {
					{ "Only there if the group summons him", "Urok Doomhowl is not in the instance until he is summoned. Urok Enforcers and Urok Ogre Magi are summoned in the same event." },
					{ "Urok Enforcer: Puncture, a stacking bleed", "Urok Enforcers Strike and stack Puncture, a bleed of 10 every 2 seconds per stack, up to 20 stacks. Urok himself adds Rend, a bleed of 27 every 3 seconds, and Strike." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Intimidating Roar is a fear", "Intimidating Roar is a fear on everyone around Urok. Keep Tremor near the tank and melee for the whole fight." },
					{ "water", "Mana Spring Totem", "bleeds: nothing to cleanse", "Rend and Puncture are bleeds and Slow is magic (priest, paladin). No disease or poison." },
					{ "air", "Windfury Totem", "no casts to ground", "The Urok Ogre Magus' Arcane Bolt and Slow hit an area, and Urok and the Enforcers cast no spell at a player. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16508, 16509, 15580, 15978, 15976, 14516, 6742, 13747, 15979 },
			},
			{
				key = "bloodaxe", kind = "trash", title = "Orcs and worgs: Bloodaxe Legion",
				here = "Bloodaxe Warmongers, Summoners, Evokers, Veterans",
				threat = "Flamecrack 1250, Frost Nova, calls for help",
				act = {
					{ "Interrupt the Evokers' Flamecrack", "Bloodaxe Evoker: Flamecrack has a cast time and hits an area near the Evoker for 1250 fire damage with a knockback. Interrupt it. Its Blast Wave slows everyone around it, and it flees at 15% health." },
					{ "Fight Warmongers away from other packs", "Bloodaxe Warmonger calls for help at 50% health and enrages at 30%. Its Uppercut throws its target back." },
				},
				watch = {
					{ "Summoner: Frost Nova root, Summon", "Bloodaxe Summoner: Frost Nova roots everyone around it (magic), Arcane Missiles on one player, and Summon, a spell with a cast time that teleports one player to the front of the Summoner." },
					{ "Veteran: Snap Kick stun, Pummel", "Bloodaxe Veteran: Snap Kick stuns its target and Pummel interrupts a cast. Raiders Cleave up to 3 players and Sunder Armor. Bloodaxe Worgs and Worg Pups are not elite." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Warmongers enrage at 30%", "Warmongers, Veterans, Raiders and Worgs all hit in melee, and Warmongers enrage at 30% health." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison. Frost Nova is magic: a priest or paladin removes it." },
					{ "air", "Grounding Totem", "eats an Arcane Bolt", "Evokers cast Arcane Bolt (92-124) and Summoners Arcane Missiles (112 a missile) at one player: Grounding takes one such cast. Flamecrack hits an area and cannot be eaten." },
				} },
				cite = { 15743, 15744, 13748, 8269, 10966, 15532, 15734, 15790, 15791, 15618, 15615, 15284, 15572 },
			},
			{
				key = "zigris", kind = "boss", title = "Quartermaster Zigris", optional = true,
				names = { "Quartermaster Zigris" },
				threat = "Shoots from range, Stun Bomb, net root",
				act = {
					{ "Spread out: Stun Bomb hits an area", "Stun Bomb has a cast time and stuns everyone in an area around its target. Players standing apart are not stunned together." },
					{ "Melee: expect Hooked Net around him", "Hooked Net has a cast time: it roots everyone around him and does 139-161 damage. He fights at range with Shoot (215-289)." },
				},
				watch = {
					{ "Rare in Classic data: he may be absent", "The Classic data lists Quartermaster Zigris as a rare spawn. Seven Bloodaxe Warmongers and three Summoners stand within 40 yards of him." },
					{ "He drinks a healing potion: 590-684", "Drink Healing Potion heals him for 590-684. It is instant: it cannot be interrupted." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "nothing to tremor", "A stun and a root, no fear. Stoneskin for the Bloodaxe orcs that come with him; Strength of Earth if he is alone.", or_ = "Strength of Earth Totem" },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight." },
					{ "air", "Windwall Totem", "he fights with Shoot", "Shoot is ranged physical damage (215-289 a shot): Windwall lowers it. It is not a spell, so Grounding does nothing." },
				} },
				cite = { 16497, 15609, 16496, 15504 },
			},
			{
				key = "ghok", kind = "boss", title = "Ghok Bashguud", optional = true,
				names = { "Ghok Bashguud" },
				threat = "Rare, may be absent: Enrage at 30%",
				act = {
					{ "Clear the Bloodaxe Veterans near him", "Three Bloodaxe Veterans, two Worgs, a Raider and a Summoner stand within 40 yards of him. Pull them first." },
				},
				watch = {
					{ "Rare spawn: he may not be there", "Ghok Bashguud is a rare spawn among the Bloodaxe orcs. At 30% health he enrages: he hits harder and attacks 60% faster." },
					{ "Shield Bash when his target casts", "He uses Shield Bash when the player he is fighting casts a spell: it interrupts the cast. It matters to a tank or healer who has his attention." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee; Enrage at 30%", "Plain melee until 30% health, then 60% faster attacks." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic from him." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 8269, 11972 },
			},
			{
				key = "halycon", kind = "boss", title = "Halycon, then Gizrul the Slavener",
				names = { "Halycon", "Gizrul the Slavener" },
				threat = "Bleed, worg pups, then a diseased bite",
				act = {
					{ "Stay ready: Gizrul comes when Halycon dies", "Gizrul the Slavener is summoned the moment Halycon dies. Do not sit down to drink or loot before he is dead too." },
					{ "Cure Infected Bite: it is a disease", "Gizrul's Infected Bite is a disease on one player: damage over time and more damage taken. A priest, paladin or shaman cures it." },
				},
				watch = {
					{ "Halycon: Thrash, Rend bleed, 10 pups", "Halycon has Thrash and Rend, a bleed on the tank. Ten Bloodaxe Worg Pups, not elite, stand within 40 yards, with two Worgs and two Warmongers." },
					{ "Gizrul: Fatal Bite, Enrage at 20%", "Fatal Bite drains health from his target. At 20% health he enrages: he hits harder and attacks 60% faster." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "two melee bosses in a row", "Halycon and Gizrul only bite: Thrash, Rend, Fatal Bite, and Gizrul's Enrage at 20% health." },
					{ "fire", "Magma Totem", "ten Worg Pups, not elite", "Area fire damage for the Bloodaxe Worg Pups around Halycon.", or_ = "Fire Nova Totem" },
					{ "water", "Disease Cleansing Totem", "Gizrul: Infected Bite", "Infected Bite is a disease. Put the totem down when Halycon dies; before that there is nothing to cleanse." },
					{ "air", "Windfury Totem", "no casts to ground", "Neither casts a spell. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 8876, 13738, 16128, 16495, 8269 },
			},
			{
				key = "wyrmthalak", kind = "boss", title = "Overlord Wyrmthalak",
				names = { "Overlord Wyrmthalak" },
				threat = "Knockback on all near him, 2 guards at 50%",
				act = {
					{ "Fight with your back to a wall", "Two Knock Away abilities throw back everyone around him, one every 14 seconds and one every 20. Tank and melee keep a wall behind them; ranged and healers stand away from him." },
					{ "At 50%: pick up the two guards", "Just under 51% health two guards are summoned and run in: each is a Bloodaxe Veteran, a Smolderthorn Berserker or a Spirestone Warlord at random. Each attacks a random player." },
				},
				watch = {
					{ "Guards go for a random player at 50%", "Each guard picks a random player when it arrives: one may come straight for the healer. Berserkers and Warlords enrage at 30% health; Veterans Snap Kick and Pummel." },
					{ "Cleave: up to 5 players near the tank", "His Cleave comes every 7 seconds and hits up to 5 players. Demoralizing Shout lowers attack power for everyone around him every 10 seconds." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Cleave on up to 5; guards", "All his damage is physical. Stoneclaw Totem can hold the two guards for a moment when they run in at 50%." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight." },
					{ "air", "Windfury Totem", "no casts to ground", "Everything he does hits an area or the tank. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 11130, 20686, 20691, 23511, 8269, 15618, 15615 },
			},
		},
	},
	{
		key = "upper-blackrock-spire",
		name = "Upper Blackrock Spire",
		match = "blackrock spire",
		wing = "Upper",
		stops = {
			{
				key = "runes", kind = "trash", title = "Rune rooms: Blackhand orcs",
				here = "Blackhand Veterans, Summoners, Dreadweavers",
				threat = "Portals, runners, Veil of Shadow curse",
				act = {
					{ "Kill every Veteran and Summoner", "Seven rooms, each with a rune. A room's rune switches when all its Blackhand Veterans and Summoners are dead; when all seven have switched, the door to Pyroguard Emberseer opens." },
					{ "Kill Summoners first: Summoning Portal", "Blackhand Summoner casts Summoning Portal: the portal brings a Summoned Blackhand Dreadweaver or a Summoned Blackhand Veteran every 5 seconds. Summoners also Frost Nova (a root on everyone around them) and cast Fireball." },
				},
				watch = {
					{ "Dreadweaver: Veil of Shadow, heals -75%", "Blackhand Dreadweaver: Veil of Shadow is a curse on one player that cuts healing taken by 75%. The cast can be interrupted; a mage or druid removes it. Its Shadow Bolt hits for 128-172." },
					{ "All three run at 15% health", "Blackhand Veterans, Summoners and Dreadweavers flee at 15% health. A Veteran or Summoner that ran away still has to die for its room's rune." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Veterans; runners at 15%", "Blackhand Veterans Shield Charge (a knockback) and Strike. Earthbind slows the orcs that flee at 15% health.", or_ = "Earthbind Totem" },
					{ "water", "Mana Spring Totem", "the curse is not yours", "Veil of Shadow is a curse: mage or druid. Frost Nova is magic. No disease or poison." },
					{ "air", "Grounding Totem", "eats a Shadow Bolt or Fireball", "Shadow Bolt and the Summoners' Fireball are each cast at one player: Grounding takes one of them. Veil of Shadow is an ability in the Classic data and goes through." },
				} },
				cite = { 16136, 16139, 15794, 15792, 15532, 12466, 7068, 12739, 15749, 11972, 14516 },
			},
			{
				key = "emberseer", kind = "boss", title = "Pyroguard Emberseer",
				names = { "Pyroguard Emberseer" },
				threat = "7 jailers first, then Fire Nova, Pyroblast",
				act = {
					{ "Kill the 7 Incarcerators as he grows", "Using the altar frees the seven Blackhand Incarcerators to fight, and the door shuts once one of them is in combat. Emberseer cannot be attacked until he has grown 20 times, one step every 3 seconds." },
					{ "Ranged, healers: stand away from him", "Fire Nova (555-645, every 6 seconds) and Flame Buffet hit everyone around him. Flame Buffet stacks, and each stack raises the damage its target takes." },
				},
				watch = {
					{ "Incarcerator: Encage stuns one player", "Blackhand Incarcerators cast Encage (a stun on one player) and Strike, and flee at 15% health. If they reset, Emberseer resets too and all seven come back." },
					{ "Pyroblast: 1388-1612 on a random player", "About every 15 seconds he throws Pyroblast at a random player: 1388-1612 fire damage and 200 every 3 seconds after. He is immune to fire damage, stuns and silence: no Searing or Magma Totem." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Incarcerators, then his melee", "Seven Incarcerators Strike in melee before he joins. Tremor does nothing against Encage: it is a stun." },
					{ "water", "Fire Resistance Totem", "Fire Nova, Pyroblast, Buffet", "All his damage spells are fire: Fire Nova on everyone around him every 6 seconds, Flame Buffet, Pyroblast." },
					{ "air", "Windfury Totem", "nothing to ground", "Pyroblast is aimed at one random player, but in the Classic data it is flagged so that it cannot be redirected: Grounding does not take it. Fire Nova and Flame Buffet hit an area.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15281, 16048, 16049, 16045, 15580, 23462, 23341, 20228 },
			},
			{
				key = "rookery", kind = "trash", title = "Rookery: Father Flame waves", optional = true,
				here = "Rookery Hatchers, Rookery Guardians",
				threat = "6 waves of 2, eggs opened, then Solakar",
				act = {
					{ "Kill Hatchers first: they open eggs", "A Rookery Hatcher breaks off every 8 to 10 seconds, runs to the nearest untouched egg within 20 yards and casts Disturb Rookery Egg on it. Kill Hatchers before Guardians." },
					{ "Keep every add in the fight", "If a Hatcher or a Guardian resets, the event fails and the waves stop. Father Flame has to be used again, and they start over from the first wave." },
				},
				watch = {
					{ "Using Father Flame starts the waves", "Six waves of two adds: two Hatchers first, then Hatchers or Guardians at random. Waves 2 to 5 each come 30 seconds after the one before; wave 6 and then Solakar Flamewreath come after 40 seconds each." },
					{ "Hatcher, Guardian: Sunder Armor, Strike", "Both Strike and stack Sunder Armor on their target, up to 5 times. The event runs once per instance and no longer starts after General Drakkisath is dead." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Sunder Armor on the tank", "Hatchers and Guardians stack Sunder Armor and Strike. Earthbind near the eggs slows the Hatchers running to them.", or_ = "Earthbind Totem" },
					{ "water", "Mana Spring Totem", "long event; nothing to cleanse", "More than three minutes of waves before the boss. No disease, poison or magic from the Hatchers and Guardians." },
					{ "air", "Windfury Totem", "no casts to ground", "Hatchers and Guardians cast no spell at a player. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15746, 15580, 15572 },
			},
			{
				key = "solakar", kind = "boss", title = "Solakar Flamewreath", optional = true,
				names = { "Solakar Flamewreath" },
				threat = "War Stomp stun, opens eggs instantly",
				act = {
					{ "Ranged, healers: stay out of War Stomp", "War Stomp stuns everyone around him and hits for extra weapon damage. Only the tank and melee stand next to him." },
					{ "Kill him fast: he opens eggs at once", "Solakar casts Disturb Rookery Egg (FAST): unlike the Hatchers' version it is instant, so it cannot be interrupted." },
				},
				watch = {
					{ "He comes 40 seconds after wave six", "Solakar Flamewreath only appears at the end of the Father Flame event, 40 seconds after the sixth wave. The event runs once per instance." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee boss; a stun, no fear", "He hits in melee. Tremor does nothing against War Stomp: it is a stun." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic from him." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell at a player. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16727, 16556, 15746 },
			},
			{
				key = "halls", kind = "trash", title = "Upper halls: orcs and dragonspawn",
				here = "Rage Talon Dragonspawn, Flamescales, Veterans",
				threat = "Fire on the ground, Enrage, portals",
				act = {
					{ "Move out of Flamestrike", "Rage Talon Flamescale: Flamestrike (228-264) leaves fire on the ground that burns every 2 seconds. The cast can be interrupted." },
					{ "Kill Summoners first: Summoning Portal", "Blackhand Summoners stand here too: their Summoning Portal brings a Summoned Blackhand Dreadweaver or a Summoned Blackhand Veteran every 5 seconds. Veterans, Summoners and Dreadweavers flee at 15% health." },
				},
				watch = {
					{ "Flamescale: fire on everyone near it", "Fireball Volley (128-172) and Fire Nova (148-170) are instant and hit everyone around the Flamescale. Ranged and healers stand away from it." },
					{ "Dragonspawn: Fixate, Enrage at 30%", "Rage Talon Dragonspawn: Fixate on one player with 50% faster attacks, Sunder Armor on its target, and Enrage at 30% health." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Dragonspawn enrage at 30%", "Rage Talon Dragonspawn and Blackhand Veterans hit in melee; the Dragonspawn Sunder Armor and enrage. The Blackhand Elites near Jed Runewatcher's spot stun with Backhand." },
					{ "water", "Fire Resistance Totem", "Flamescales: 3 fire spells", "Flamestrike, Fireball Volley and Fire Nova from every Rage Talon Flamescale. No disease or poison here." },
					{ "air", "Grounding Totem", "eats a Dreadweaver Shadow Bolt", "Blackhand Dreadweavers cast Shadow Bolt at one player: Grounding takes it. Their Veil of Shadow (healing taken -75%) is an ability in the Classic data and goes through; it is a curse, for a mage or a druid. The Flamescales' fire hits an area." },
				} },
				cite = { 16102, 15285, 12470, 12021, 15572, 8269, 16136, 16139, 15794, 15792, 7068, 12739, 6253 },
			},
			{
				key = "jed", kind = "boss", title = "Jed Runewatcher", optional = true,
				names = { "Jed Runewatcher" },
				threat = "Rare, may be absent: Shield Charge",
				act = {
					{ "Clear the Blackhand orcs around him", "Blackhand Veterans, two Dreadweavers, two Elites and a Summoner stand within 40 yards of him, next to Goraluk Anvilcrack. Pull them first." },
				},
				watch = {
					{ "Rare spawn: he may not be there", "Jed Runewatcher is a rare spawn. He stands a few yards from Goraluk Anvilcrack." },
					{ "Shield Charge: knockback on one player", "Shield Charge: he charges a player, hits for extra weapon damage and knocks them back. Shield Bash interrupts a cast." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee; Shield Charge", "Strike, Shield Charge and Shield Bash: all physical." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic from him." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 15749, 11972, 14516 },
			},
			{
				key = "goraluk", kind = "boss", title = "Goraluk Anvilcrack", optional = true,
				names = { "Goraluk Anvilcrack" },
				threat = "Backhand stun, Head Crack, orc guards",
				act = {
					{ "Pull the orcs around him first", "Blackhand Veterans, two Dreadweavers, a Summoner and an Elite stand within 40 yards of him. Kill the Summoner before its Summoning Portal brings more." },
				},
				watch = {
					{ "Backhand: a stun on one player", "Backhand stuns one player. With the tank stunned, hold your damage for a moment." },
					{ "Head Crack lowers a stat on one player", "Head Crack is a debuff on one player that lowers a stat. It has no dispel type: nothing removes it. Strike adds weapon damage." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "melee; a stun, no fear", "Strike, Backhand and Head Crack are all physical. Tremor does nothing against a stun." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "Head Crack has no dispel type: it cannot be cleansed. No disease or poison." },
					{ "air", "Windfury Totem", "no casts to ground", "He casts no spell. Windfury for a melee group; Tranquil Air if the group is casters or your heals pull threat.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 6253, 16172, 15580, 16136 },
			},
			{
				key = "arena", kind = "trash", title = "Arena: seven waves",
				here = "Chromatic Whelps, Dragonspawn, Dragon Handlers",
				threat = "7 waves: caster whelps, Cleave, a healer",
				act = {
					{ "Kill Dragon Handlers first: Mend Dragon", "From the third wave on, every wave has a Blackhand Dragon Handler. Its Mend Dragon heals its target for 1000 every 2 seconds." },
					{ "Use area damage on the whelps", "Chromatic Whelps are not elite, two or three a wave. They cast Frostbolt (a slow) and Lightning Bolt at one player and Fireball Volley on everyone around them; all three casts can be interrupted." },
				},
				watch = {
					{ "Next wave: last one dead, or 60 seconds", "Stepping into the arena shuts the door and starts the event. The next wave comes as soon as the last is dead, and in any case 60 seconds after the one before. If the group wipes, everything despawns and the event starts over." },
					{ "Dragonspawn Cleave; 2 in waves 6 and 7", "Chromatic Dragonspawn Cleave up to 3 players and Strike. Waves 1 and 2: three whelps and a Dragonspawn. Waves 6 and 7: two whelps, two Dragonspawn and a Handler." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Dragonspawn Cleave, Strike", "One or two Chromatic Dragonspawn a wave hit the tank and Cleave up to 3 players." },
					{ "fire", "Magma Totem", "whelps are not elite", "Area fire damage for the two or three Chromatic Whelps of each wave. They are casters: drop it where they stop.", or_ = "Fire Nova Totem" },
					{ "water", "Mana Spring Totem", "seven waves, no breaks", "Waves come back to back. Frostbolt's slow is magic (priest, paladin); no disease or poison." },
					{ "air", "Grounding Totem", "eats a Frostbolt or a bolt", "Whelps cast Frostbolt (72-96) and Lightning Bolt (96-128) at one player: Grounding takes one of them. Fireball Volley hits an area." },
				} },
				cite = { 16637, 16249, 16250, 12167, 15284, 15580 },
			},
			{
				key = "gyth", kind = "boss", title = "Gyth and Warchief Rend Blackhand",
				names = { "Gyth", "Warchief Rend Blackhand" },
				threat = "Breath cones, Freeze stun, Whirlwind",
				act = {
					{ "Tank faces Gyth away: three breaths", "Corrosive Acid Breath (armor down, stacks to 10), Freeze (740-860 frost damage and a stun) and Flame Breath all hit a cone in front of Gyth. Only the tank stands there; Knock Away throws the tank back." },
					{ "Melee: get out of Rend's Whirlwind", "Rend's Whirlwind hits everyone around him every 2 seconds for heavy weapon damage. Mortal Strike halves healing on his target, Cleave hits up to 3 players, and he enrages at 20% health." },
				},
				watch = {
					{ "Gyth at 11%: Rend dismounts and fights", "Gyth arrives about half a minute after the last wave dies and cannot die until Rend is knocked off, just under 11% health. From then both are in the fight; the exit opens when both are dead." },
					{ "Gyth at 50%: Purge Chromatic Chaos", "Below 50% health Nefarius casts Chromatic Chaos on Gyth: 25% less melee damage taken. It is a magic buff on an enemy: a shaman's Purge removes it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "acid strips the tank's armor", "Corrosive Acid Breath lowers armor with every stack, then Rend arrives with Mortal Strike, Cleave and Whirlwind. Neither casts a fear." },
					{ "fire", "Frost Resistance Totem", "Gyth's Freeze is frost", "Freeze does 740-860 frost damage and more every 3 seconds to everyone in the cone in front of Gyth. Stand the totem near the tank." },
					{ "water", "Mana Spring Totem", "Freeze is magic: not yours", "Freeze is magic: a priest or paladin removes the stun. No disease or poison." },
					{ "air", "Windfury Totem", "no casts to ground", "Every breath is a cone and Rend only uses weapon attacks. Windfury for a melee group; Tranquil Air if the group is casters.", or_ = "Tranquil Air Totem" },
				} },
				cite = { 16359, 16350, 16390, 10101, 16337, 16328, 16167, 13736, 15589, 15708, 15284, 8269 },
			},
			{
				key = "elites", kind = "trash", title = "To The Beast: Blackhand elites",
				here = "Elites, Iron Guards, Assassins, Dragon Guards",
				threat = "Stuns on the tank, stealthed Assassins",
				act = {
					{ "Switch off an Iron Guard in Shield Wall", "Blackhand Iron Guard: Shield Wall cuts the damage it takes by 75%. Kill something else while it is up." },
					{ "Interrupt a Fire Tongue's Flame Buffet", "A few Rage Talon Fire Tongues stand on this stretch: Flame Buffet (555-645 on one player, stacking to 5) has a cast time and can be interrupted. Blackhand Summoners and Dreadweavers stand here too: kill a Summoner before its Summoning Portal brings more." },
				},
				watch = {
					{ "Assassins sneak: Gouge, then Backstab", "Blackhand Assassins stay in stealth until they attack. Gouge stuns the player facing them, Backstab hits from behind, and Slice and Dice speeds up their attacks." },
					{ "Elite, Iron Guard, Dragon Guard: stuns", "Blackhand Elites Backhand, Iron Guards and Rage Talon Dragon Guards Shield Slam: each is a stun on one player. Dragon Guards also Cleave up to 3 players and Sunder Armor." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "hard melee, tank stunned", "Level 60-61 elites that all hit in melee and stun their target. Tremor does nothing against stuns." },
					{ "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison in these packs. Flame Buffet is magic: a priest or paladin removes it." },
					{ "air", "Windfury Totem", "Grounding on Fire Tongues", "The orcs and Dragon Guards cast no spell. On a pack with a Rage Talon Fire Tongue, Grounding takes a Flame Buffet or a Fire Blast (360) aimed at one player.", or_ = "Grounding Totem" },
				} },
				cite = { 15062, 15655, 12540, 15582, 6434, 6253, 16172, 15284, 16145, 16168, 16144, 16136 },
			},
			{
				key = "beast", kind = "boss", title = "The Beast",
				names = { "The Beast" },
				threat = "Fear around him, fire knockback, charge",
				act = {
					{ "Stand with your back to a wall", "Flamebreak (232-268 fire damage) knocks back everyone around him, and Berserker Charge throws one player a long way. A wall behind you keeps you in place." },
					{ "Ranged, healers: stay out of the Roar", "Terrifying Roar fears everyone around him. Stand away from him so the fear and the Flamebreak do not reach you." },
				},
				watch = {
					{ "Terrifying Roar: fear on all near him", "Terrifying Roar is an instant fear on everyone around him. He cannot be stunned, feared, rooted or slowed himself." },
					{ "Berserker Charge: one player thrown far", "Berserker Charge: he charges one player for heavy weapon damage and a long knockback. Fireball (193-259) on one player has a cast time. If his target stands where he cannot reach, Summon Player teleports them to the front of him." },
				},
				classes = { SHAMAN = {
					{ "earth", "Tremor Totem", "Terrifying Roar is a fear", "Terrifying Roar fears everyone around him. Keep Tremor near the tank and melee for the whole fight." },
					{ "water", "Fire Resistance Totem", "Flamebreak and Fireball", "Flamebreak burns everyone around him, Fireball one player, and his Immolate aura sets a player on fire (144, then 42 every 3 seconds; magic). No disease or poison." },
					{ "air", "Grounding Totem", "eats a Fireball", "Fireball (193-259) is aimed at one player, so Grounding can take it. Flamebreak and the Roar hit an area; Berserker Charge is not a spell." },
				} },
				cite = { 14100, 16785, 16636, 16788, 20477, 15506, 15570 },
			},
			{
				key = "valthalak", kind = "boss", title = "Lord Valthalak (summoned)", optional = true,
				names = { "Lord Valthalak" },
				threat = "Assassin adds, Shadow Wrath, Enrage at 40%",
				act = {
					{ "Kill the Spectral Assassins", "From the pull until 40% health he casts Summon Spectral Assassin. Kill each add as it comes." },
					{ "Save cooldowns for the last 15%", "At 40% he enrages: harder hits and 60% faster attacks. At 15% he starts a Shadow Bolt Volley that hits everyone around him for 128-172 every 2 seconds." },
				},
				watch = {
					{ "Shadow Wrath: 500 shadow, up to 10 hit", "Shadow Wrath hits one player for 500 shadow damage and jumps on, up to 10 players. He is immune to stun, fear, root, snare and polymorph." },
					{ "Only there if a player summons him", "Lord Valthalak is not in the instance until a player summons him, at a spot close to The Beast's room. It can be done once per instance." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Enrage at 40%", "From 40% health he hits harder and 60% faster. He casts no fear." },
					{ "water", "Healing Stream Totem", "shadow volleys at 15%", "Shadow Wrath jumps through the group and the last 15% is a Shadow Bolt Volley every 2 seconds. Nothing to cleanse." },
					{ "air", "Grounding Totem", "can eat a Shadow Wrath", "Shadow Wrath is aimed at one player before it jumps, so Grounding can take that cast. The Shadow Bolt Volley cannot be eaten." },
				} },
				cite = { 27249, 27286, 8269, 27382, 27383 },
			},
			{
				key = "guard", kind = "trash", title = "To Drakkisath: Rage Talon guard",
				here = "Rage Talon Captains, Fire Tongues, Elites",
				threat = "Flame Buffet stacks, knockback, cone smash",
				act = {
					{ "Interrupt the Fire Tongues' Flame Buffet", "Rage Talon Fire Tongue: Flame Buffet has a cast time, hits one player for 555-645 and raises the damage that player takes, stacking to 5. Interrupt it; it is magic, so a priest or paladin removes it." },
					{ "Tank Captains facing away: Arcing Smash", "Rage Talon Captain: Arcing Smash hits a cone in front of it. Knock Away throws the tank back and Mortal Strike (triple weapon damage) halves healing on its target." },
				},
				watch = {
					{ "Fire Tongue: Fire Nova, Fire Blast 360", "Fire Nova (148-170) hits everyone around the Fire Tongue and Fire Blast hits one player for 360. Ranged and healers stand away from it." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Captains: Mortal Strike", "Level 62 Rage Talon Captains Mortal Strike and knock the tank away; Blackhand Elites and Iron Guards stun." },
					{ "water", "Fire Resistance Totem", "Fire Tongues: 3 fire spells", "Flame Buffet, Fire Blast and Fire Nova from every Rage Talon Fire Tongue. No disease or poison." },
					{ "air", "Grounding Totem", "eats a Flame Buffet", "Flame Buffet and Fire Blast are each aimed at one player: Grounding takes one of them. Fire Nova hits an area." },
				} },
				cite = { 16168, 16144, 16635, 16169, 10101, 15708, 6253, 15655 },
			},
			{
				key = "drakkisath", kind = "boss", title = "General Drakkisath",
				names = { "General Drakkisath" },
				threat = "Conflagration, Flamestrike, 2 elite guards",
				act = {
					{ "Move out of Flamestrike", "Flamestrike (342-396) leaves fire on the ground that burns every 2 seconds. It has a cast time, but he cannot be interrupted: move." },
					{ "Put a tank on the 2 Elite Guards", "Two Chromatic Elite Guards stand with him: Mortal Strike (healing halved), Knockdown (a stun on up to 3 players) and Strike. They cannot be feared, polymorphed or interrupted." },
				},
				watch = {
					{ "Conflagration: 300 fire a second, confused", "Conflagration burns one player for 300 fire damage a second and leaves them confused, unable to act. Every second it also does 300 fire damage to the players standing around the burning one: keep apart from each other." },
					{ "Pierce Armor: tank's armor -75%", "Pierce Armor cuts his target's armor by 75%. Thunderclap slows everyone around him, Cleave hits up to 3 players, and Rage makes him hit harder and 50% faster. He cannot be stunned or feared." },
				},
				classes = { SHAMAN = {
					{ "earth", "Stoneskin Totem", "Pierce Armor: armor -75%", "With the tank's armor cut by 75%, his melee and Cleave hit much harder, and the Guards add Mortal Strike. He casts no fear." },
					{ "water", "Fire Resistance Totem", "Conflagration, Flamestrike", "Conflagration is 300 fire damage a second and Flamestrike burns on the ground. No disease or poison; Thunderclap is magic." },
					{ "air", "Grounding Totem", "can eat a Conflagration", "Conflagration is aimed at one player, so Grounding can take it. Flamestrike and Thunderclap hit an area and cannot be eaten." },
				} },
				cite = { 16805, 16806, 16419, 12097, 15548, 15284, 16789, 15708, 16790, 15580 },
			},
		},
	},
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
