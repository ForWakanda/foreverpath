-- HearthAndHustle / Data / DungeonTips_DireMaul.lua
-- Dungeon tips: Dire Maul (East, West, North). Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 429, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local DUNGEONS = {
  ---------------------------------------------------------------------------------------------------------------
  -- EAST
  ---------------------------------------------------------------------------------------------------------------
  {
    key = "dire-maul-east",
    name = "Dire Maul: East",
    match = "dire maul",
    wing = "East",
    stops = {
      {
        key = "entry", kind = "trash", title = "Entry: treants and lashers",
        here = "Warpwood Treants, Tanglers, Crushers, lashers",
        threat = "Stuns, roots, bleeds, area spells from lashers",
        act = {
          { "Interrupt the Tanglers' Lightning Bolt", "Warpwood Tangler casts Lightning Bolt, which has a cast time and can be interrupted, and Entangling Roots, a root with a cast time. The root is magic: a priest or a paladin removes it." },
          { "Stay clear of the lashers if you are ranged", "Phase Lasher opens with Shadow Bolt Volley and then picks one of Fireball Volley, Ice Nova, Slow or Thorn Volley. All of these hit everyone around the lasher, so only melee should be in reach." },
        },
        watch = {
          { "Treants: Knockdown stun, Vicious Rend bleed", "Warpwood Treant: Strike, Knockdown (a stun) and Vicious Rend, a bleed that stacks to 3. Warpwood Crusher: Crush Armor on its target, stacking to 5, and Trample on everyone near it; a Crusher cannot be rooted or snared." },
          { "Phase Lasher: Ice Nova, Thorn Volley stun", "Two of the Phase Lasher's area spells stun everyone around it: Ice Nova and Thorn Volley (150 nature damage). Its Slow cuts attack and move speed and is magic: a priest or a paladin removes it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "treants and Crushers only melee", "Warpwood Treants and Crushers do physical damage only: Strike, Vicious Rend, Crush Armor, Trample. Nothing here fears, charms or sleeps, so Tremor has no job." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease and no poison on these packs. Entangling Roots and Slow are magic: priest or paladin." },
          { "air", "Grounding Totem", "eats a Tangler's Lightning Bolt", "Warpwood Tangler's Lightning Bolt and Entangling Roots are aimed at one player, so Grounding takes one. The Phase Lasher's volleys and novas are area spells and cannot be eaten." },
        } },
        cite = { 22414, 22415, 18368, 11428, 14331, 22426, 15550, 17228, 15285, 22519, 22356, 21749 },
      },
      {
        key = "pusillin", kind = "boss", title = "Pusillin", optional = true,
        names = { "Pusillin" },
        threat = "Fire: Blast Wave, Fire Blast, Fireball",
        act = {
          { "Interrupt Fireball", "Pusillin fights at range. Fireball has a cast time and can be interrupted; Fire Blast is instant, 220-260 fire damage on one player." },
          { "Stand away if ranged: Blast Wave around him", "Blast Wave hits everyone around him for 161-187 fire damage and slows them. Ranged and healers stand away from him." },
        },
        watch = {
          { "Pull: a Treant and a Tangler stand close", "A Warpwood Treant and a Warpwood Tangler stand near his spot. He cannot be feared or charmed, and knockout effects do not work on him." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "He casts no fear, charm or sleep. Stoneskin for the tank; Strength of Earth if the tank is never in trouble." },
          { "water", "Fire Resistance Totem", "all three of his spells are fire", "Blast Wave, Fire Blast and Fireball are all fire damage. No disease and no poison on this fight." },
          { "air", "Grounding Totem", "eats a Fireball or a Fire Blast", "Fireball and Fire Blast are aimed at one player, so Grounding takes one. Blast Wave is an area spell and cannot be eaten." },
        } },
        cite = { 17145, 14145, 15242 },
      },
      {
        key = "satyrs", kind = "trash", title = "Satyr packs",
        here = "Wildspawn Satyrs, Rogues, Tricksters, Felsworn",
        threat = "Fear, poison stun, curses, stealthed stalkers",
        act = {
          { "Interrupt the Felsworn's Fear", "Wildspawn Felsworn fights at range: Fear and Shadow Bolt both have a cast time and can be interrupted, Shadow Word: Pain is instant. At 30% health it puts up Shadow Shield, a magic buff that Purge or Dispel Magic removes." },
          { "Remove Paralyzing Poison at once", "Wildspawn Trickster: Paralyzing Poison stuns one player and is a poison: a druid, paladin or shaman removes it. Curse of Weakness and Curse of Impotence are curses: a mage or a druid." },
        },
        watch = {
          { "Shadowstalkers: stealthed, Backstab", "Wildspawn Shadowstalkers walk in stealth (Sneak), see through stealth and invisibility themselves, and Backstab a player from behind. Their hits apply Slowing Poison, a poison that slows movement and attacks." },
          { "Betrayers shoot: Exploding Shot hits a group", "Wildspawn Betrayer fights at range: Shoot, Shadow Shot, Knockdown (a stun) and Exploding Shot, which also hits everyone next to its target. Wildspawn Satyrs Hamstring and Enrage at 30% health; Wildspawn Rogues Rupture (a bleed)." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Felsworn cast Fear", "Wildspawn Felsworn cast Fear on one player. It is the only fear on the trash of this wing; the Rogues, Tricksters and Shadowstalkers stand around Hydrospawn." },
          { "water", "Poison Cleansing Totem", "Trickster: Paralyzing Poison", "Paralyzing Poison from the Wildspawn Tricksters is a stun with the poison dispel type; Slowing Poison from the Shadowstalkers is a poison too. No disease here." },
          { "air", "Grounding Totem", "eats a Fear or a Shadow Bolt", "The Felsworn's Fear, Shadow Bolt and Shadow Word: Pain and the Trickster's curses are all aimed at one player. Grounding takes one of them at a time." },
        } },
        cite = { 12542, 15537, 15654, 22417, 3609, 12493, 22371, 22766, 18950, 22416, 8601, 7992, 7896, 18649, 16100, 11428, 9080, 8599, 15583 },
      },
      {
        key = "lethtendris", kind = "boss", title = "Lethtendris and Pimgib", optional = true,
        names = { "Lethtendris", "Pimgib" },
        threat = "Void Bolt, curses, fire from her imp Pimgib",
        act = {
          { "Interrupt Void Bolt", "Void Bolt hits one player for 925-1075 shadow damage and has a cast time: interrupt it. Her Immolate and Curse of Thorns have a cast time and can be interrupted too." },
          { "Kill Pimgib before Flame Buffet stacks up", "Pimgib fights at range: Flame Buffet stacks to 5 on one player and each stack raises the damage that player takes (magic: priest or paladin). He also casts Fireball (interruptible) and Blast Wave around himself, and Lethtendris casts Enlarge on him: more damage, a magic buff that can be purged." },
        },
        watch = {
          { "Curse of Tongues on a mana user", "Curse of Tongues goes on a random mana user and halves cast speed. Curse of Thorns hurts the cursed player for 38-82 each time it triggers. Both are curses: a mage or a druid removes them." },
          { "Shadow Bolt Volley: everyone near her", "Shadow Bolt Volley is instant and hits everyone around her for 128-172 shadow damage. Neither she nor Pimgib can be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "Neither of them casts a fear, charm or sleep. Stoneskin for whoever holds Pimgib and her." },
          { "water", "Mana Spring Totem", "curses: not yours to remove", "Curse of Tongues and Curse of Thorns need a mage or a druid; Immolate and Flame Buffet are magic. No disease, no poison." },
          { "air", "Grounding Totem", "eats a Void Bolt", "Void Bolt, Immolate, both curses, and Pimgib's Fireball and Flame Buffet are aimed at one player. Shadow Bolt Volley and Blast Wave are area spells and cannot be eaten." },
        } },
        cite = { 22709, 12742, 17228, 13338, 22710, 16247, 16248, 16046, 22713, 15228 },
      },
      {
        key = "imps", kind = "trash", title = "Imps, Hellcallers, Fel Lashes",
        here = "Wildspawn Imps, Hellcallers, Fel Lashes",
        threat = "Rain of Fire, Fire Blast, Arcane Explosion",
        act = {
          { "Move out of Rain of Fire", "Wildspawn Hellcaller fights at range: Rain of Fire is a ground effect, so step out of it. Its Fireball (192-258) has a cast time and can be interrupted." },
          { "Use area damage on the Imps", "Wildspawn Imps are level 56 non-elite demons that stand in groups: five near Hydrospawn with a Hellcaller, three near Zevrim Thornhoof." },
        },
        watch = {
          { "Imps: instant Fire Blast on one player", "Each Wildspawn Imp casts Fire Blast, instant, 110-130 fire damage on one player. The Hellcaller keeps Fire Shield, a magic buff, on a friend." },
          { "Fel Lash: Arcane Explosion around it", "Fel Lash fights at range: Arcane Bolt (138-186, cast time, interruptible) on one player and an instant Arcane Explosion (165-180) on everyone around it. Fel Lashes stand near Hydrospawn and again in Alzzin the Wildshaper's room." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "Imps and Hellcallers cast no fear, charm or sleep." },
          { "fire", "Magma Totem", "Imps stand in groups", "Wildspawn Imps are non-elite and come three to five at a time. Magma Totem at the tank's feet, or one Fire Nova Totem.", or_ = "Fire Nova Totem" },
          { "water", "Fire Resistance Totem", "Imps and Hellcallers: all fire", "Fire Blast, Fireball and Rain of Fire are all fire damage; only the Fel Lash casts arcane. No disease and no poison." },
          { "air", "Grounding Totem", "eats a Fireball or a Fire Blast", "Fireball, Fire Blast and the Fel Lash's Arcane Bolt are aimed at one player, so Grounding takes one. Rain of Fire and Arcane Explosion are area spells and cannot be eaten." },
        } },
        cite = { 20754, 15228, 13377, 13340, 15230, 22271 },
      },
      {
        key = "zevrim", kind = "boss", title = "Zevrim Thornhoof",
        names = { "Zevrim Thornhoof" },
        threat = "Sacrifice on one player, Intense Pain",
        act = {
          { "Interrupt Sacrifice", "Sacrifice has a cast time and can be interrupted. If it lands it moves one player to a fixed spot, stuns them and leeches 300 health a second: heal that player hard." },
          { "Kill him to free Old Ironbark", "When Zevrim Thornhoof dies, Old Ironbark turns into Ironbark the Redeemed, who can then open the Conservatory door on the way to Alzzin the Wildshaper." },
        },
        watch = {
          { "Intense Pain: shadow damage over time", "Intense Pain has a cast time and puts 200 shadow damage per tick on everyone in an area near him. It is magic: a priest or a paladin removes it." },
          { "Pull: three Imps stand close to him", "Three Wildspawn Imps stand near him. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "He casts no fear, charm or sleep. Sacrifice is a stun: Tremor does nothing for it." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Intense Pain is magic, not a disease or poison. Healing Stream helps a little with its ticks on the group.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats a Sacrifice", "Sacrifice is a shadow spell cast at one player: Grounding takes it. Intense Pain is an area spell and cannot be eaten." },
        } },
        cite = { 22478, 22651 },
      },
      {
        key = "hydrospawn", kind = "boss", title = "Hydrospawn", optional = true,
        names = { "Hydrospawn" },
        threat = "Riptide knockback and disarm, geysers",
        act = {
          { "Interrupt Massive Geyser", "Massive Geyser has a cast time and can be interrupted. If it finishes, a Massive Geyser appears where his target stands: move away from it." },
          { "Kill the Hydrolings at 25%", "At 25% health he casts Summon Hydroling and adds appear next to him. Hydrospawn himself is immune to frost damage: no Frostbolt, no Frost Shock." },
        },
        watch = {
          { "Riptide: knockback and disarm around him", "Riptide hits everyone around him: 85-115 frost damage, a knockback and a disarm. Ranged and healers stand away; melee keep a wall behind them." },
          { "Submersion: stacking debuff, up to 20", "Submersion puts a stat loss on everyone around him, 10 per stack, stacking to 20. It is magic: a priest or a paladin removes it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "He casts no fear, charm or sleep. Riptide's disarm and knockback cannot be prevented by a totem." },
          { "fire", "Frost Resistance Totem", "Riptide is frost damage", "Riptide is frost damage on everyone around him. Frost Resistance is a fire totem, and he is immune to frost, so keep Frost Shock for another fight." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Submersion and Riptide are magic: priest or paladin. No disease, no poison." },
          { "air", "Windfury Totem", "no casts to ground", "Riptide and Submersion are area spells and Massive Geyser is a summon: nothing for Grounding. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 22419, 22420, 22421, 22714 },
      },
      {
        key = "conservatory", kind = "trash", title = "Old Ironbark's door, lashers",
        here = "Whip Lashers, Death Lashes, Warpwood Guardians",
        threat = "Lasher swarms, poison, thorns, stun stomps",
        act = {
          { "Kill Zevrim first: Ironbark opens the door", "The Conservatory door is opened by Ironbark the Redeemed. Old Ironbark only becomes Ironbark the Redeemed when Zevrim Thornhoof dies." },
          { "Use area damage on the Whip Lashers", "Whip Lashers are level 54 non-elite and the wing holds well over a hundred of them: dozens around Old Ironbark and more in Alzzin the Wildshaper's room. They are immune to nature damage." },
        },
        watch = {
          { "Death Lash: poison, Thorns, extra attacks", "Death Lash carries Thrash (extra attacks), Thorns that hurt whoever hits it, and Virulent Poison on its hits: a poison that stacks to 3, removed by a druid, paladin or shaman." },
          { "Stomper: War Stomp stuns all near it", "Warpwood Stomper: Thrash and War Stomp, a stun on everyone around it. Warpwood Guardian heals its friends with Regrowth (cast time, interruptible), Pummels its target's casts and uses Head Crack." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "lasher swarms, all melee", "Whip Lashers only hit in melee (Lash of Pain) and come many at a time. Nothing here fears, charms or sleeps." },
          { "fire", "Magma Totem", "Whip Lasher swarms", "Whip Lashers are immune to nature damage: Lightning Bolt, Chain Lightning and Earth Shock do nothing to them. Fire totems work.", or_ = "Fire Nova Totem" },
          { "water", "Poison Cleansing Totem", "Death Lash: Virulent Poison", "Virulent Poison from the Death Lashes is a poison that stacks to 3 on whoever they hit. No disease here." },
          { "air", "Windfury Totem", "no casts to ground", "Nothing in this stretch casts a spell at one player. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 21987, 8876, 16428, 16427, 25640, 16727, 22373, 15615, 16172 },
      },
      {
        key = "alzzin", kind = "boss", title = "Alzzin the Wildshaper",
        names = { "Alzzin the Wildshaper" },
        threat = "Shapeshifts, disease, minion swarm at 40%",
        act = {
          { "Interrupt Wild Regeneration", "Wild Regeneration is his heal over time on himself: it has a cast time, can be interrupted, and is a magic buff that Purge or Dispel Magic removes. In Tree Form he casts Enervate, also interruptible: a poison that drains 200 power a second from one player." },
          { "Use area damage on the Minions at 40%", "At 40% health he drops his forms, calls for help and summons a swarm of Alzzin's Minions: level 56 non-elite demons whose threat resets (Hate to Zero), so they do not stay on the tank. Kill them with area damage and keep them off the healer." },
        },
        watch = {
          { "Wolf: fast and hard. Tree: Disarm, knockback", "Dire Wolf Form: 75% faster attacks, 50% more damage, Vicious Bite on two targets and Mangle (a slow with 200 damage per tick). Tree Form: 3000 more armor and 25% more damage, with Disarm, Knock Away (a knockback) and Enervate." },
          { "Wither: a disease on one player", "Wither: 740-860 nature damage, damage over time and a stat loss on one player. It is a disease: a priest, paladin or shaman removes it. When he dies the Felvine Shards appear." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "wolf form: fast, heavy melee", "In Dire Wolf Form he attacks 75% faster for 50% more damage. He casts no fear, charm or sleep." },
          { "fire", "Magma Totem", "Alzzin's Minions at 40%", "The Minions are non-elite and many. Drop Magma Totem, or a Fire Nova Totem, where they gather.", or_ = "Fire Nova Totem" },
          { "water", "Disease Cleansing Totem", "Wither is a disease", "Wither is a disease on one player. Enervate is a poison, so swap to Poison Cleansing if the mana drain hurts more than Wither." },
          { "air", "Grounding Totem", "eats a Wither", "Wither is a nature spell cast at one player: Grounding takes it. His Thorns is a magic buff: Purge it." },
        } },
        cite = { 22128, 22662, 7948, 22660, 22688, 19319, 22689, 22691, 22661, 10101, 10095 },
      },
      {
        key = "isalien", kind = "boss", title = "Isalien", optional = true,
        names = { "Isalien" },
        threat = "Shots, Starshards, a big heal, a pet",
        act = {
          { "Interrupt Regrowth", "At 80% health Isalien casts Regrowth: a 4625-5375 heal plus a heal over time. It has a cast time and can be interrupted; the heal over time is magic and can be purged or dispelled." },
          { "Pick up her pet Empyrean when it comes", "Shortly into the fight she casts Call Pet, which summons Empyrean. Tank it or kill it." },
        },
        watch = {
          { "Starshards: 500 a second on one player", "Starshards does 500 arcane damage every second to one player and cannot be dispelled: heal through it. Net roots one player; Multi-Shot hits up to three." },
          { "Event boss: summoned in Alzzin's room", "Isalien does not stand in the wing. She appears at a trigger in Alzzin the Wildshaper's room when a player uses the summoning spell there. She cannot be feared." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "She casts no fear, charm or sleep. Stoneskin helps against Empyrean and her melee." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease and no poison on this fight. Healing Stream if Starshards is hard to keep up with.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "Starshards, or her shots", "Starshards is an arcane spell aimed at one player: Grounding takes it. Windwall instead cuts the damage of her Shoot (215-289 physical).", or_ = "Windwall Totem" },
        } },
        cite = { 27639, 22907, 14443, 12024, 27636, 27637 },
      },
    },
  },

  ---------------------------------------------------------------------------------------------------------------
  -- WEST
  ---------------------------------------------------------------------------------------------------------------
  {
    key = "dire-maul-west",
    name = "Dire Maul: West",
    match = "dire maul",
    wing = "West",
    stops = {
      {
        key = "entry", kind = "trash", title = "Petrified treants, Ironbark Protectors",
        here = "Petrified Treants, Guardians, Ironbark Protectors",
        threat = "Harden Skin, a heal, roots, knockback",
        act = {
          { "Remove Harden Skin or finish with spells", "At 50% health a Petrified Treant casts Harden Skin: 10000 armor, so weapons barely hurt it. It is a magic buff: Purge or Dispel Magic removes it; otherwise finish the Treant with spells." },
          { "Interrupt the Guardian's Regrowth", "At 50% health a Petrified Guardian casts Regrowth: a 396-460 heal plus a heal over time, with a cast time, interruptible. Its Thorns (32 damage back per hit) is a magic buff that can be purged." },
        },
        watch = {
          { "Aberrations and Remnants: pylon guards", "Arcane Aberrations and Mana Remnants stand close to these treants. They guard the five pylons that hold the force field around Immol'thar: see the pylon stop before you pull them." },
          { "Ironbark Protector: root, knockback, Trample", "Ironbark Protector: Entangling Roots roots one player with damage over time, Knock Away knocks its target back and Trample hits everyone near it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "treants only melee", "Petrified Treants and Guardians only hit in melee, and the Ironbark Protector adds Trample and Knock Away. Nothing here fears, charms or sleeps." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease and no poison on these packs." },
          { "air", "Windfury Totem", "little worth grounding", "The only spell aimed at one player is the Ironbark Protector's Entangling Roots. Keep Purge for Harden Skin and Thorns. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 22693, 22696, 22695, 28858, 18670, 5568 },
      },
      {
        key = "tendris", kind = "boss", title = "Tendris Warpwood",
        names = { "Tendris Warpwood" },
        threat = "Grasping Vines area root, knockback, adds",
        act = {
          { "Clear the trash near him before the pull", "Tendris Warpwood calls for help on aggro, so enemies near him join the fight. His death opens the Warpwood door." },
          { "Stand away if ranged: Grasping Vines", "Grasping Vines has a cast time and hits everyone around him: 525-675 damage, a root and a Knockdown. The root is magic: a priest or a paladin removes it. Trample also hits everyone close to him." },
        },
        watch = {
          { "Entangle: pulls one player to him, rooted", "Entangle roots one player, damages them over time and teleports them to in front of him, where Trample and Grasping Vines land." },
          { "Uppercut: knockback on his target", "Uppercut knocks his target back: tank him with your back to a wall. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Trample, Uppercut, heavy melee", "Trample, Uppercut and his melee are all physical. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "The Grasping Vines root is magic, not a disease or poison. Healing Stream helps after a Grasping Vines.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats an Entangle", "Entangle is a nature spell aimed at one player: Grounding takes it. Grasping Vines and Trample are area effects and cannot be eaten." },
        } },
        cite = { 22994, 22916, 5568, 22924 },
      },
      {
        key = "eldreth", kind = "trash", title = "Eldreth undead: Sorcerers, Seethers",
        here = "Eldreth Seethers, Sorcerers, Darters, skeletons",
        threat = "Polymorph, Mana Burn, enrage, Sunder Armor",
        act = {
          { "Interrupt Polymorph and Mana Burn", "Eldreth Sorcerer fights at range with Polymorph and Chain Lightning; Eldreth Darter casts Mana Burn (363-401 mana, jumping to three players). All three have a cast time and can be interrupted. Polymorph is magic: a priest or a paladin removes it." },
        },
        watch = {
          { "Seether: Enrage at 30%, Crimson Fury", "Eldreth Seether: Fire Shield burns those around it, Crimson Fury is a magic buff that adds fire damage to its hits (Purge or Dispel Magic), and at 30% health it Enrages: 50% more damage, 60% faster attacks." },
          { "Skeletal Highborne: Sunder Armor stacks", "Skeletal Highborne are non-elite and stack Sunder Armor to 5 on their target; Rotting Highborne only hit in melee. Eldreth Darters put Power Word: Shield, a magic buff, on a friend. All the undead here are immune to fear and sleep." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Sunder Armor stacks on the tank", "Skeletal Highborne stack Sunder Armor and the Seethers Enrage at 30%. Nothing here fears, charms or sleeps." },
          { "water", "Mana Spring Totem", "Darters burn mana", "Eldreth Darters cast Mana Burn on mana users. No disease and no poison to cleanse." },
          { "air", "Grounding Totem", "eats a Mana Burn", "Mana Burn, Chain Lightning and Starshards are spells aimed at one player: Grounding takes one of them at a time." },
        } },
        cite = { 13323, 16006, 22823, 22947, 17139, 13376, 16843, 16844, 8269, 21081 },
      },
      {
        key = "illyanna", kind = "boss", title = "Illyanna Ravenoak and Ferra",
        names = { "Illyanna Ravenoak", "Ferra" },
        threat = "Volley on the ground, a trap, her bear Ferra",
        act = {
          { "Move out of Volley", "Volley is a ground effect: 300 arcane damage every second to everyone standing in it. Step out at once." },
          { "Avoid the Immolation Trap in front of her", "Immolation Trap places a fire trap on the ground in front of her. Concussive Shot slows everyone around her (magic) and its Improved Concussive Shot stuns them; Multi-Shot jumps to as many as ten players." },
        },
        watch = {
          { "Ferra the bear: Charge stuns, Maul", "Ferra stands with her: Charge (a charge with a stun on one player) and Maul. Ferra cannot be feared." },
          { "Pull: Eldreth undead stand close", "Eldreth Sorcerers, Seethers, Darters and Skeletal Highborne stand near the pair: clear them first. Illyanna fights at range and is undead: no fear, charm or sleep works on her." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Ferra's melee on the tank", "Ferra's Charge and Maul and Illyanna's shots are what the tank takes. Neither casts a fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Concussive Shot is magic, not a disease or poison. Healing Stream helps when Multi-Shot hits the whole group.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "Volley is a ground effect and Multi-Shot and Concussive Shot hit many players: nothing for Grounding. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 22908, 22910, 22914, 22915, 20735, 22911, 17156 },
      },
      {
        key = "ghosts", kind = "trash", title = "Ghosts: Apparitions, Spirits, Phantasms",
        here = "Eldreth Apparitions, Spirits, Phantasms, Spectres",
        threat = "Silence, frost roots and slows, curses",
        act = {
          { "Interrupt Shrink and Frostbolt", "Eldreth Phantasm casts Shrink, a curse with a cast time that lowers stats; Eldreth Apparition casts Frostbolt. Both can be interrupted. The Apparition's Chains of Ice also has a cast time." },
          { "Keep casters away from Spirits: silence", "Eldreth Spirit: Banshee Shriek silences everyone around it (magic) and Ribbon of Souls does 128-172 shadow damage to everyone around it. Casters and healers stay out of its reach." },
        },
        watch = {
          { "Apparition: Chains of Ice burns mana", "Chains of Ice roots one player and burns 350-450 of their mana every 2 seconds while it lasts. It is magic, like Frostbolt and Cone of Cold: a priest or a paladin removes it. The Apparition's Frost Armor chills whoever hits it." },
          { "Phantasm: Call of the Grave, a curse", "Call of the Grave curses everyone around the Phantasm and Shrink is its second curse: a mage or a druid removes them. Eldreth Spectres are invisible until they fight, heal friends with Dark Offering and dispel magic from them." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "None of the ghosts casts a fear, charm or sleep. Silence is not something Tremor removes." },
          { "fire", "Frost Resistance Totem", "Apparitions cast frost", "Frostbolt and Cone of Cold from the Eldreth Apparitions are frost damage. Frost Resistance is a fire totem." },
          { "water", "Mana Spring Totem", "Chains of Ice burns mana", "Chains of Ice burns 350-450 mana per tick from the rooted player. Call of the Grave and Shrink are curses, the frost effects and the silence are magic: no disease, no poison." },
          { "air", "Grounding Totem", "eats Frostbolt or Chains of Ice", "Frostbolt and Chains of Ice are frost spells aimed at one player: Grounding takes one. Cone of Cold, Banshee Shriek and Ribbon of Souls are area spells and cannot be eaten." },
        } },
        cite = { 15802, 16799, 22744, 22745, 16838, 22743, 15244, 18100, 18101, 17831, 16380, 7154, 17201 },
      },
      {
        key = "kalendris", kind = "boss", title = "Magister Kalendris",
        names = { "Magister Kalendris" },
        threat = "Mind control, Mind Flay, Shadowform",
        act = {
          { "Interrupt Dominate Mind", "Dominate Mind has a cast time and can be interrupted. It mind-controls one player and is magic, so a priest or a paladin can remove it. Mind Blast (370-430 shadow damage) can be interrupted too." },
        },
        watch = {
          { "60% to 30% health: Shadowform", "At 60% health he enters Shadowform: he takes 40% less melee damage and deals 40% more damage. It is removed at 30%. Spell damage is not reduced in between." },
          { "Mind Flay: up to three players, a slow", "Mind Flay does 240 shadow damage a second and slows, on up to three players. Shadow Word: Pain is magic: a priest or a paladin removes it. He fights at range and is undead: no fear, charm or sleep works on him." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Dominate Mind is a charm", "Dominate Mind is a mind control with the charm mechanic: Tremor Totem breaks it. He casts no fear." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Shadow Word: Pain and Dominate Mind are magic. Healing Stream helps with Mind Flay on three players.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats a Dominate Mind", "Dominate Mind, Mind Blast and Shadow Word: Pain are shadow spells aimed at one player: Grounding takes one of them at a time." },
        } },
        cite = { 22917, 22919, 17146, 7645, 17287 },
      },
      {
        key = "tsuzee", kind = "boss", title = "Tsu'zee", optional = true,
        names = { "Tsu'zee" },
        threat = "Gouge stun, Blind, fast melee",
        act = {
          { "Kill her: nothing to interrupt or dodge", "All three of her abilities are instant and aimed at one player: Sinister Strike, Gouge (a stun on a player facing her) and Blind (that player wanders, slowed)." },
        },
        watch = {
          { "Tank gouged or blinded: cannot act", "A gouged or blinded tank cannot hold her for that moment. She is undead: no fear, charm or sleep works on her." },
          { "Pull: ghosts stand close to her", "Eldreth Apparitions, Eldreth Spirits and an Eldreth Phantasm stand near her: clear them first." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "all her damage is melee", "Sinister Strike and her melee are physical. Gouge is a stun and Blind a confuse: Tremor removes neither." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "In the Classic data her Blind has no dispel type, so no totem removes it. Nothing else she does is a disease or a poison." },
          { "air", "Windfury Totem", "no spell to ground", "Blind is an ability, not a spell, in the Classic data: Grounding does not take it. Gouge and Sinister Strike are melee abilities too.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15581, 12540, 21060 },
      },
      {
        key = "revanchion", kind = "boss", title = "Revanchion", optional = true,
        names = { "Revanchion" },
        threat = "Frost Nova root, Shadow Bolt Volley",
        act = {
          { "Stand away if ranged: both spells are near him", "Frost Nova roots everyone around him (magic: priest or paladin) and Shadow Bolt Volley hits everyone around him for 128-172 shadow damage. Ranged and healers stand away." },
        },
        watch = {
          { "Immune to stun, root, snare, interrupt", "Revanchion cannot be stunned, rooted, snared, silenced, interrupted, disarmed, polymorphed, banished, shackled, feared or put to sleep. His Shadow Bolt Volley has a cast time but cannot be stopped." },
          { "Frost Armor: magic buff, chills attackers", "He keeps Frost Armor on himself: more armor, and whoever hits him is Chilled (slower attacks and movement, magic). Frost Armor is a magic buff: Purge or Dispel Magic removes it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "He casts no fear, charm or sleep. Earthbind does nothing: he cannot be snared." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "The Frost Nova root is magic, not a disease or poison. Healing Stream helps with the Shadow Bolt Volley.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "area spells: no ground", "Frost Nova and Shadow Bolt Volley are area spells, so Grounding has nothing to take. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 12544, 6136, 14907, 15245 },
      },
      {
        key = "pylons", kind = "trash", title = "The five pylons",
        here = "Arcane Aberrations, Mana Remnants",
        threat = "Mana Burn on death, Chain Lightning, arcane",
        act = {
          { "Kill every guard at each of the 5 pylons", "Five crystal generators hold the force field around Immol'thar. Each one is guarded by the Arcane Aberrations and Mana Remnants standing close to it; when all of a pylon's guards are dead that pylon shuts off, and with all five off the force field opens." },
          { "Step back from a dying Aberration: Mana Burn", "When an Arcane Aberration dies it casts Mana Burn: 726-802 mana from everyone in an area near it. Mana users step back before it dies." },
        },
        watch = {
          { "Both guards: immune to arcane damage", "Arcane Aberrations and Mana Remnants are immune to arcane damage. Aberrations fight at range with an Arcane Bolt that hits everyone around them; Mana Remnants Blink on aggro and cast Chain Lightning, interruptible, jumping to three players." },
          { "Torrents: Forked Lightning cone, a cloud", "Arcane Torrent: Forked Lightning (525-675 nature damage in a cone in front of it) and Lightning Cloud, a ground effect to step out of. Residual Monstrosity: Arcane Blast knocks back everyone around it, and Mana Bursts appear when it dies." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "None of the arcane elementals casts a fear, charm or sleep." },
          { "water", "Mana Spring Totem", "Mana Burn drains the casters", "A dying Arcane Aberration burns 726-802 mana from everyone near it. No disease and no poison to cleanse." },
          { "air", "Grounding Totem", "Chain Lightning", "A Mana Remnant's Chain Lightning is a nature spell aimed at one player: Grounding takes it. Nature Resistance instead if Arcane Torrents are in the pull: Forked Lightning and Lightning Cloud are nature damage.", or_ = "Nature Resistance Totem" },
        } },
        cite = { 22936, 15979, 14514, 15659, 22945, 22946, 22940, 22939 },
      },
      {
        key = "immolthar", kind = "boss", title = "Immol'thar",
        names = { "Immol'thar" },
        threat = "Trample, disease bite, Eyes, Enrage at 30%",
        act = {
          { "Kill the Eyes of Immol'thar", "Eye of Immol'thar summons an Eye of Immol'thar next to him. Kill the adds as they appear." },
          { "Stand away if ranged: Trample around him", "Trample hits everyone around him. Portal of Immol'thar teleports one player." },
        },
        watch = {
          { "Infected Bite: a disease on his target", "Infected Bite is a disease: damage over time and more damage taken. A priest, paladin or shaman removes it." },
          { "At 30%: Enrage", "At 30% health he Enrages: 50% more damage and 60% faster attacks. When the force field opens, the Highborne Summoners still alive attack him; when he dies, Prince Tortheldrin turns hostile." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Enrage at 30%, heavy melee", "Trample and his melee are physical and he Enrages at 30% health. He casts no fear, charm or sleep." },
          { "water", "Disease Cleansing Totem", "Infected Bite is a disease", "Infected Bite makes its target take more damage, so it should come off the tank quickly." },
          { "air", "Windfury Totem", "no casts to ground", "Infected Bite is a bite on his target and Trample hits an area: nothing worth a Grounding. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 5568, 16128, 22899, 22950, 8269 },
      },
      {
        key = "prince", kind = "boss", title = "Prince Tortheldrin",
        names = { "Prince Tortheldrin" },
        threat = "Whirlwind, Arcane Blast, Counterspell",
        act = {
          { "Kill Immol'thar first: then he fights", "Prince Tortheldrin cannot be attacked until Immol'thar is dead. On Immol'thar's death he yells and turns hostile." },
          { "Stand away if ranged: Whirlwind", "Whirlwind hits everyone around him for weapon damage plus 300. Ranged and healers stand away from him." },
        },
        watch = {
          { "Arcane Blast: 875-1125 and a knockback", "Arcane Blast hits one player for 875-1125 arcane damage and knocks them back. Summon teleports one player to in front of him." },
          { "Counterspell when his target casts", "He casts Counterspell when his current target is casting, and Thrash gives him extra attacks. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Thrash and Whirlwind", "Thrash (extra attacks), Whirlwind and his melee are all physical. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or curse on this fight. Healing Stream helps melee through Whirlwind.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats an Arcane Blast", "Arcane Blast is instant and aimed at one player: Grounding takes one. Whirlwind is a melee area attack and cannot be eaten." },
        } },
        cite = { 8876, 15589, 22920, 22995, 20537 },
      },
      {
        key = "helnurath", kind = "boss", title = "Lord Hel'nurath: ritual", optional = true,
        names = { "Lord Hel'nurath" },
        threat = "Demon waves, then Sleep and a heal curse",
        act = {
          { "Keep the Bell, Wheel and Candle switched on", "During the warlock's Dreadsteed ritual at Immol'thar's pedestal, demons come in waves 45 seconds apart. Every 30 to 45 seconds one of the Bell of Dethmoora, the Wheel of Black March and the Doomsday Candle switches off until a player uses it again; with all three off the ritual fails." },
          { "Interrupt Veil of Shadow", "Lord Hel'nurath's Veil of Shadow cuts the healing one player takes by 75%. It has a cast time and can be interrupted, and it is a curse: a mage or a druid removes it." },
        },
        watch = {
          { "Hel'nurath: Sleep on one player", "Sleep puts one player out. It is magic (priest or paladin) and has the sleep mechanic: Tremor Totem breaks it. Knock Away knocks his target back and Shadow Word: Pain is magic." },
          { "Bell heals, Wheel shields, Candle burns", "While switched on, the Bell heals friends around it for 150 and restores 150 of their power, the Wheel's Black March Blessing lowers the damage they take, and the Candle burns enemies near it for 250 a second. Xorothian Imps and Dread Guards belong to this event; a Dread Guard uses Shadow Shock and Cleave." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Lord Hel'nurath casts Sleep", "Sleep is the one sleep effect in the wing, and he casts it on one player. He himself cannot be feared or charmed." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Veil of Shadow is a curse, Sleep and Shadow Word: Pain are magic. Healing Stream helps during the waves.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats a Sleep or a Pain", "Sleep and Shadow Word: Pain are shadow spells aimed at one player: Grounding takes one of them at a time. Veil of Shadow is an ability in the Classic data and goes through." },
        } },
        cite = { 23120, 23226, 23117, 17146, 23224, 18670, 20989, 18663, 15284 },
      },
    },
  },

  ---------------------------------------------------------------------------------------------------------------
  -- NORTH
  ---------------------------------------------------------------------------------------------------------------
  {
    key = "dire-maul-north",
    name = "Dire Maul: North",
    match = "dire maul",
    wing = "North",
    stops = {
      {
        key = "entry", kind = "trash", title = "Entry: Mastiffs and first ogres",
        here = "Gordok Mastiffs, Brutes, Mage-Lords",
        threat = "Dog packs, Rend bleed, Polymorph, Flamestrike",
        act = {
          { "Use area damage on the Mastiffs", "Gordok Mastiffs are non-elite beasts in packs, most of them around Guard Mol'dar. Rend is a bleed and Tendon Rip a slow." },
        },
        watch = {
          { "Tribute run: six named ogres stay alive", "The instance script counts how many of six ogres are still alive for the Gordok Tribute chest: Guard Mol'dar, Guard Fengus, Guard Slip'kik, Stomper Kreeg, Captain Kromcrush and Cho'Rush the Observer. Decide before the first guard whether you kill them or leave them." },
          { "Brutes, Mage-Lords: also before Mol'dar", "Gordok Brutes and Gordok Mage-Lords stand around Guard Mol'dar too: Polymorph and Flamestrike from the Mage-Lords (both interruptible), Uppercut and an Enrage at 30% health from the Brutes." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "packs of dogs on the tank", "Gordok Mastiffs and Gordok Brutes only hit in melee. Nothing here fears, charms or sleeps." },
          { "fire", "Magma Totem", "Mastiff packs", "Mastiffs are non-elite and come many at a time. Magma Totem at the tank's feet, or one Fire Nova Totem.", or_ = "Fire Nova Totem" },
          { "water", "Mana Spring Totem", "bleeds: no cleanse", "Rend is a bleed and Tendon Rip a physical slow: no disease, no poison. Healing Stream helps against the bleeds.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "Grounding vs Mage-Lords", "Dogs cast nothing. On a pull with a Gordok Mage-Lord, Grounding Totem takes a Frostbolt or a Fire Blast instead.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 3604, 13738, 13323, 16102, 15530, 14145, 18072, 15716 },
      },
      {
        key = "moldar", kind = "boss", title = "Guard Mol'dar", optional = true,
        names = { "Guard Mol'dar" },
        threat = "Shield Charge, knockbacks, Enrage at 40%",
        act = {
          { "Tank him with your back to a wall", "Shield Charge on the pull and Knock Away both knock his target back. Strike is his plain attack." },
          { "Leave him alive on a tribute run", "Guard Mol'dar is one of the six ogres the instance script counts alive for the Gordok Tribute chest. Killing him takes one off that count." },
        },
        watch = {
          { "Shield Bash: interrupts his target's casts", "Shield Bash interrupts a cast, and he also uses it when his target starts casting. A caster who pulls threat gets interrupted." },
          { "At 40%: Enrage and a call for help", "At 40% health he Enrages (50% more damage, 60% faster attacks) and calls for help. Seven Gordok Mastiffs stand near him: clear them first. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Enrage at 40%, all melee", "Everything he does is physical and he hits 50% harder after 40% health. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15749, 15580, 11972, 10101, 8269 },
      },
      {
        key = "brutes", kind = "trash", title = "Brutes and Mage-Lords",
        here = "Gordok Brutes, Gordok Mage-Lords",
        threat = "Polymorph, Flamestrike, Bloodlust, knockback",
        act = {
          { "Interrupt the Mage-Lord's Polymorph", "Gordok Mage-Lord fights at range: Polymorph, Flamestrike and Frostbolt have a cast time and can be interrupted, Fire Blast is instant. Polymorph is magic: a priest or a paladin removes it." },
          { "Move out of Flamestrike", "Flamestrike hits an area for 228-264 fire damage and leaves a burning ground effect there. Step out of it." },
        },
        watch = {
          { "Mage-Lord: Bloodlust on a friend", "Bloodlust gives one ogre 60% faster attacks. It is a magic buff: a shaman's Purge or a priest's Dispel Magic removes it." },
          { "Brute: Uppercut knockback, Enrage at 30%", "Gordok Brute: Uppercut knocks its target back, Pummel interrupts its target's casts, Enrage at 30% health and a Backhand stun at 15%." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Brutes hit hard, Enrage at 30%", "Gordok Brutes are all physical and Enrage at 30% health. These packs stand around Guard Mol'dar, Stomper Kreeg and, most of all, Guard Fengus; none of them fears, charms or sleeps." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Polymorph and the Frostbolt slow are magic: priest or paladin. No disease, no poison." },
          { "air", "Grounding Totem", "eats a Frostbolt or Fire Blast", "Frostbolt and Fire Blast are spells aimed at one player: Grounding takes one. Flamestrike is an area spell and cannot be eaten." },
        } },
        cite = { 13323, 16170, 16102, 14145, 15530, 6253, 15716, 18072, 15615 },
      },
      {
        key = "kreeg", kind = "boss", title = "Stomper Kreeg", optional = true,
        names = { "Stomper Kreeg" },
        threat = "Whirlwind, Booze Spit cone, threat resets",
        act = {
          { "Tank faces him away: Booze Spit", "Booze Spit is a cone in front of him: 75% less chance to hit, and drunk. Only the tank stands in front of him." },
          { "Stand away if ranged: Whirlwind, War Stomp", "Whirlwind (weapon damage plus 200) and War Stomp (a knockback) hit everyone around him. Ranged and healers stand away." },
        },
        watch = {
          { "At 30%: Enrage. At 15%: Drunken Rage", "At 30% health he Enrages: 50% more damage, 60% faster attacks. At 15% Drunken Rage doubles his speed and makes him drop his threat, so he can turn on anyone." },
          { "Tribute run: leave Kreeg alive", "Stomper Kreeg is one of the six ogres the instance script counts alive for the Gordok Tribute chest. A Gordok Brute and a Gordok Mage-Lord stand near him." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Whirlwind and Enrage", "Whirlwind and his melee are physical and he Enrages at 30% health. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "In the Classic data Booze Spit has no dispel type, and nothing here is a disease or poison.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "Booze Spit is a cone and the rest is melee: nothing for Grounding. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15577, 22833, 16740, 8269, 22835 },
      },
      {
        key = "fengus", kind = "boss", title = "Guard Fengus", optional = true,
        names = { "Guard Fengus" },
        threat = "Shield Charge, knockbacks, Enrage at 40%",
        act = {
          { "Tank him with your back to a wall", "Shield Charge on the pull and Knock Away both knock his target back. Strike is his plain attack." },
          { "Leave him alive on a tribute run", "Guard Fengus is one of the six ogres the instance script counts alive for the Gordok Tribute chest. Killing him takes one off that count." },
        },
        watch = {
          { "Shield Bash: interrupts his target's casts", "Shield Bash interrupts a cast, and he also uses it when his target starts casting. A caster who pulls threat gets interrupted." },
          { "At 40%: Enrage and a call for help", "At 40% health he Enrages (50% more damage, 60% faster attacks) and calls for help. A Gordok Brute and a Gordok Mage-Lord stand near him: clear them first. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Enrage at 40%, all melee", "Everything he does is physical and he hits 50% harder after 40% health. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15749, 15580, 11972, 10101, 8269 },
      },
      {
        key = "warlocks", kind = "trash", title = "Warlocks, Swarmers, the Eye",
        here = "Gordok Warlocks, Carrion Swarmers, Kilrogg Eye",
        threat = "Banish, curses, Doomguards, poison swarms",
        act = {
          { "Stop the Eye's Summon Netherwalker cast", "A Wandering Eye of Kilrogg stops when it sees you and casts Summon Netherwalker, which has a cast time and can be interrupted. Kill or interrupt the Eye before the Netherwalker arrives." },
          { "Interrupt Banish and Shadow Bolt", "Gordok Warlock fights at range: Banish (takes one player out of the fight; magic), Immolate and Shadow Bolt all have a cast time and can be interrupted. Curse of Tongues goes on a random mana user: a mage or a druid removes it." },
        },
        watch = {
          { "Each Warlock keeps a Doomguard Minion", "Out of combat a Gordok Warlock casts Summon Doomguard, so a Doomguard Minion stands with it. Demon Armor on the Warlock is a magic buff." },
          { "Carrion Swarmers: Venom Sting, a poison", "Carrion Swarmers are non-elite beasts in swarms; four stand near Guard Slip'kik. Venom Sting stacks to 3 and is a poison: a druid, paladin or shaman removes it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor; default", "Gordok Warlocks cast no fear here: Banish is a stun-type effect that Tremor does not remove." },
          { "fire", "Magma Totem", "Carrion Swarmer swarms", "Carrion Swarmers are non-elite and come several at a time.", or_ = "Fire Nova Totem" },
          { "water", "Poison Cleansing Totem", "Swarmers: Venom Sting", "Venom Sting from the Carrion Swarmers is a poison that stacks to 3. No disease here." },
          { "air", "Grounding Totem", "eats a Banish or a Shadow Bolt", "Banish, Immolate, Shadow Bolt and Curse of Tongues are spells aimed at one player: Grounding takes one of them at a time." },
        } },
        cite = { 22876, 8994, 13338, 17883, 15232, 22865, 13787, 5416 },
      },
      {
        key = "slipkik", kind = "boss", title = "Guard Slip'kik", optional = true,
        names = { "Guard Slip'kik" },
        threat = "Shield Charge, knockbacks, Enrage at 40%",
        act = {
          { "Tank him with your back to a wall", "Shield Charge on the pull and Knock Away both knock his target back. Strike is his plain attack." },
          { "Leave him alive on a tribute run", "Guard Slip'kik is one of the six counted ogres. A fixed trap reacts only to him: when he reaches it he drops out of combat and players can no longer attack him." },
        },
        watch = {
          { "Shield Bash: interrupts his target's casts", "Shield Bash interrupts a cast, and he also uses it when his target starts casting. A caster who pulls threat gets interrupted." },
          { "At 40%: Enrage and a call for help", "At 40% health he Enrages (50% more damage, 60% faster attacks) and calls for help. Two Gordok Warlocks and Carrion Swarmers stand near him: clear them first. He cannot be feared or charmed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Enrage at 40%, all melee", "Everything he does is physical and he hits 50% harder after 40% health. He casts no fear, charm or sleep." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic on this fight.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "He casts no spells. Windfury for melee, Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15749, 15580, 11972, 10101, 8269 },
      },
      {
        key = "captains", kind = "trash", title = "Captains and Reavers",
        here = "Gordok Captains, Gordok Reavers",
        threat = "Fear, Mortal Strike, Cleave, Shadow Shock",
        act = {
          { "Interrupt the Captain's Fear", "Gordok Captain casts Fear on one player: it has a cast time and can be interrupted, and it is magic (priest or paladin). It also uses Shadow Shock, Dark Strike and Demoralizing Shout." },
        },
        watch = {
          { "Reaver: Mortal Strike halves healing", "Gordok Reaver: Mortal Strike cuts healing on its target by 50%, Cleave hits up to three players standing together, and Sunder Armor stacks to 5." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Captains cast Fear", "Gordok Captains cast Fear on one player. Captains and Reavers stand around Captain Kromcrush; Stoneskin instead when a pull has only Reavers." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Fear is magic, the rest is physical or instant shadow damage. No disease, no poison." },
          { "air", "Grounding Totem", "eats a Fear or a Shadow Shock", "The Captain's Fear and Shadow Shock are shadow spells aimed at one player: Grounding takes one." },
        } },
        cite = { 12096, 22575, 22574, 16244, 16145, 15284, 13737 },
      },
      {
        key = "kromcrush", kind = "boss", title = "Captain Kromcrush", optional = true,
        names = { "Captain Kromcrush" },
        threat = "Fear shout, Mortal Cleave, Reavers at 50%",
        act = {
          { "Pick up the Gordok Reavers at 50%", "At 50% health he casts Call Reavers and Gordok Reavers join the fight: Cleave, Mortal Strike, Sunder Armor. Tank or kill the adds." },
          { "Leave him alive on a tribute run", "Captain Kromcrush is one of the six ogres the instance script counts alive for the Gordok Tribute chest. If he is alive when King Gordok dies, he turns friendly." },
        },
        watch = {
          { "Intimidating Shout: fear around him", "Intimidating Shout stuns his target in place and fears the other players around him. Tremor Totem breaks the fear; he himself cannot be feared or charmed." },
          { "Mortal Cleave: healing on tank halved", "Mortal Cleave does 150% weapon damage and cuts healing on his target by 50%. Retaliation gives him extra weapon strikes, and at 30% health he Enrages." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Intimidating Shout is a fear", "Intimidating Shout has the fear mechanic on everyone it hits around him: Tremor Totem breaks it." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or curse. Healing Stream helps a tank whose healing is halved by Mortal Cleave.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "Intimidating Shout is an area effect and the rest is melee: nothing for Grounding. Tranquil Air for a caster group.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 22859, 22857, 22858, 19134, 29544, 22860, 8599 },
      },
      {
        key = "gordok", kind = "boss", title = "King Gordok and Cho'Rush",
        names = { "King Gordok", "Cho'Rush the Observer" },
        threat = "Mortal Strike, War Stomp stun, a caster add",
        act = {
          { "Interrupt Cho'Rush: Healing Wave first", "Cho'Rush the Observer is one of three kinds, picked when he spawns: a shaman (Healing Wave, Chain Lightning, Lightning Bolt, Earthgrab Totem), a mage (Fireball, Arcane Explosion, Frost Nova) or a priest (Mind Blast, Psychic Scream, Power Word: Shield). His bolts, Arcane Explosion and Healing Wave have a cast time and can be interrupted; Healing Wave heals a friend for 694-806." },
          { "Kill only the King on a tribute run", "When King Gordok dies, Cho'Rush (if alive) stops fighting and turns friendly, and Mizzle the Crafty walks in. Cho'Rush is one of the six ogres counted alive for the Gordok Tribute chest." },
        },
        watch = {
          { "King: War Stomp stuns all near him", "King Gordok: War Stomp stuns everyone around him, Mortal Strike does 300% weapon damage and cuts healing on his target by 50%, Sunder Armor stacks to 5, and Berserker Charge charges one player and knocks them back." },
          { "Cho'Rush: Bloodlust on a friend, magic", "Bloodlust gives a friend, King Gordok above all, 60% faster attacks and is a magic buff: Purge or Dispel Magic removes it. The priest kind casts Psychic Scream, a fear on up to five players around him; the mage kind roots those around him with Frost Nova." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Tremor if he Psychic Screams", "King Gordok is all physical. Swap to Tremor Totem if this Cho'Rush is the priest kind: Psychic Scream is a fear.", or_ = "Tremor Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison or curse. Healing Stream helps a tank whose healing is halved by Mortal Strike.", or_ = "Healing Stream Totem" },
          { "air", "Grounding Totem", "eats one of Cho'Rush's bolts", "Chain Lightning, Lightning Bolt, Fireball and Mind Blast are aimed at one player. Arcane Explosion, Frost Nova and Psychic Scream are area spells and cannot be eaten." },
        } },
        cite = { 15572, 22886, 15708, 16727, 16170, 15305, 8376, 15982, 15531, 13745, 17139, 22884, 15234, 17290, 17194 },
      },
    },
  },
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
