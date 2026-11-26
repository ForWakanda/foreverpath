-- HearthAndHustle / Data / DungeonTips_BlackrockDepths.lua
-- Dungeon tips: Blackrock Depths. Format, sources and limits: Data/DungeonTips.lua.
-- Classic 1.12 reference data (CMaNGOS world database, instance map 230, and
-- the ScriptDevAI scripts for it), read 2026-11-25; `cite` lists the spell ids
-- each stop was written from. Not the Forever client: a stop that is wrong in
-- play gets corrected here.
local ADDON, FP = ...
local D = FP.DungeonTipsData

local DUNGEONS = {
  {
    key = "blackrock-depths",
    name = "Blackrock Depths",
    match = "blackrock depths",
    stops = {
      ------------------------------------------------------------------ Detention Block
      {
        key = "detention", kind = "trash", title = "Detention Block",
        here = "Wardens, Guardsmen, Torturers, Bloodhounds",
        threat = "Runners, Hooked Net, Shadow Word: Pain",
        act = {
          { "Kill runners before they reach more dwarves", "Anvilrage Wardens, Anvilrage Guardsmen and Twilight's Hammer Torturers all flee at 15% health. Slow, stun or burst them before they get away." },
        },
        watch = {
          { "Warden: Hooked Net root, Shield Bash", "Anvilrage Warden: Hooked Net (a root with a cast time) and Shield Bash, which interrupts a player who is casting. Anvilrage Guardsman: Sunder Armor and Disarm on the tank, Shield Block." },
          { "Torturer: Shadow Word: Pain", "Twilight's Hammer Torturer: Shadow Word: Pain, 36 shadow damage every 3 seconds on one player (magic: a priest or paladin removes it), and their hits can apply Wracking Pains, a curse (a mage or druid). Bloodhounds: Rend (a bleed) and Dire Growl." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "melee packs; runners", "Everything here hits in melee: Strike, Sunder Armor, Rend. Earthbind Totem slows the Wardens, Guardsmen and Torturers that run at 15% health.", or_ = "Earthbind Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease or poison here. Shadow Word: Pain is magic, Wracking Pains is a curse and Rend is a bleed: none is yours to remove." },
          { "air", "Grounding Totem", "eats a Shadow Word: Pain", "Shadow Word: Pain, Wracking Pains and the Bloodhounds' Dire Growl are each aimed at one player, so Grounding Totem takes one of them. Windfury Totem if the group is melee.", or_ = "Windfury Totem" },
        } },
        cite = { 14030, 11972, 11971, 6713, 14032, 13616, 13619, 13445, 13692 },
      },
      {
        key = "gerstahn", kind = "boss", title = "High Interrogator Gerstahn", optional = true,
        names = { "High Interrogator Gerstahn" },
        threat = "Psychic Scream fear, Mana Burn, shadow",
        act = {
          { "Interrupt Mana Burn", "Mana Burn has a cast time and can be interrupted. She aims it at a random player who uses mana and burns 272-300 of it." },
          { "Purge her Shadow Shield", "Shadow Shield is a magic buff on her: it absorbs 200 damage and hurts whoever hits her. A shaman's Purge removes it; she puts it up again later in the fight." },
        },
        watch = {
          { "About 30 s in: Psychic Scream, a fear", "Psychic Scream comes 32 seconds into the fight and every 30 seconds after: a fear on up to 5 players around her. Tremor Totem breaks it." },
          { "Shadow Word: Pain on a random player", "Shadow Word: Pain goes on a random player every 7 seconds: magic, so a priest or paladin removes it. Bloodhounds, Anvilrage Wardens and Torturers stand near her: clear them first." },
        },
        classes = { SHAMAN = {
          { "earth", "Tremor Totem", "Psychic Scream is a fear", "Psychic Scream fears up to 5 players around her, first after 32 seconds and then every 30. She herself cannot be feared." },
          { "water", "Mana Spring Totem", "Mana Burn drains casters", "Nothing to cleanse: Shadow Word: Pain is magic. Mana Burn takes 272-300 mana from one caster each time it lands." },
          { "air", "Grounding Totem", "eats Mana Burn or Pain", "Mana Burn and Shadow Word: Pain are each cast at one player, so Grounding Totem takes one of them. Psychic Scream is an area effect and goes through." },
        } },
        cite = { 14032, 14033, 13704, 12040 },
      },
      ------------------------------------------------------------------ Halls to the Ring of Law
      {
        key = "halls", kind = "trash", title = "Halls to the Ring of Law",
        here = "Footmen, Guardsmen, Fireguards, Bloodhounds",
        threat = "Fireballs, Kick, runners",
        act = {
          { "Interrupt the Fireguards' Fireball", "Fireguards stay at range and cast Fireball at one player. It has a cast time and can be interrupted." },
        },
        watch = {
          { "Footman: Kick when you cast", "Anvilrage Footman: Kick on a target that is casting (an interrupt), Strike, and it flees at 15% health. Anvilrage Guardsman: Sunder Armor, Disarm, also a runner." },
          { "Fireguards: IMMUNE to fire damage", "Fireguards are fire elementals and immune to fire damage: no fire spells, no Searing or Magma Totem on them. Bloodhounds: Rend, a bleed." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "melee packs; runners", "Footmen, Guardsmen and Bloodhounds all hit in melee. Earthbind Totem slows the Footmen and Guardsmen that run at 15% health.", or_ = "Earthbind Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, no poison. Fire Resistance Totem is the swap for a pull with several Fireguards: their only attack is Fireball." },
          { "air", "Grounding Totem", "eats a Fireguard's Fireball", "Fireball is cast at one player, so Grounding Totem takes it. Kick and Strike are melee abilities and cannot be grounded." },
        } },
        cite = { 14034, 11978, 11976, 11971, 6713, 13445 },
      },
      {
        key = "roccor", kind = "boss", title = "Lord Roccor", optional = true,
        names = { "Lord Roccor" },
        threat = "Ground Tremor stun, Flame and Earth Shock",
        act = {
          { "Keep ranged and healers away from him", "Ground Tremor stuns everyone in the area around him. Only the tank and melee should be inside it." },
        },
        watch = {
          { "Earth Shock: interrupts a cast", "Earth Shock (110-120 nature) interrupts the cast of the player it hits. Flame Shock burns one player: it is magic, a priest or paladin removes it." },
          { "Rare: he may not be up", "Lord Roccor is a rare spawn. If he is not here, skip this stop." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor", "Ground Tremor is a stun, not a fear: Tremor Totem does nothing against it. He cannot be feared himself." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Flame Shock is magic: not yours to remove. No disease or poison." },
          { "air", "Grounding Totem", "eats a Flame or Earth Shock", "Flame Shock and Earth Shock are each cast at one player, so Grounding Totem takes one. Ground Tremor is an area effect and goes through." },
        } },
        cite = { 13729, 13728, 6524 },
      },
      {
        key = "grebmar", kind = "boss", title = "Houndmaster Grebmar", optional = true,
        names = { "Houndmaster Grebmar" },
        threat = "Bloodhound pack, Bloodlust, Pummel",
        act = {
          { "Clear the Bloodhounds before him", "Fourteen Bloodhounds stand around him. They are level 49-50 and not elite, so area damage works, but each one puts Rend (a bleed) on what it bites." },
          { "Purge Bloodlust", "Bloodlust is a magic buff he casts on a friend: 30% faster melee attacks. A shaman's Purge removes it." },
        },
        watch = {
          { "Grebmar: Pummel interrupts a cast", "Pummel interrupts the cast of the player it hits. Demoralizing Shout lowers the attack power of everyone around him." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "a pack of hounds, all melee", "Bloodhounds only bite and Rend, Grebmar only melees and Pummels. He cannot be feared." },
          { "fire", "Magma Totem", "the Bloodhound pack", "The Bloodhounds are not elite: Magma Totem or a Fire Nova Totem in the pack wears them down. Nothing here is immune to fire.", or_ = "Fire Nova Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Rend is a bleed: nobody removes it. No disease, poison or curse here." },
          { "air", "Windfury Totem", "no casts to ground", "Nobody here casts a spell at a player. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 13730, 15615, 21049, 13445 },
      },
      ------------------------------------------------------------------ Ring of Law
      {
        key = "ringwaves", kind = "trash", title = "Ring of Law: the two waves",
        here = "Two waves of one random beast type",
        threat = "Area debuffs on the pull, then a boss",
        act = {
          { "Kill wave 1 fast: wave 2 comes 16 s later", "Walking into the arena starts the event. One beast type, picked at random, comes out of the East gate, and a second wave of the same beasts follows 16 seconds after the first." },
          { "Cleanse the opening debuff", "Each beast opens with an area debuff. Disease: Dredge Sickness (Dredge Worm), Putrid Enzyme (Borer Beetle, 50% more damage taken). Poison: Barbed Sting (Deep Stinger), Creeper Venom (Cave Creeper, 30% more damage taken)." },
        },
        watch = {
          { "Dark Screechers: Sonic Burst silences", "Dark Screecher, 5 per wave: Aural Shock, a curse that slows casting by 35%, and Sonic Burst, a silence on everyone around it. Burrowing Thundersnout, 3 per wave: Disjunction (magic, 50% more damage taken) and Thunderclap." },
          { "After both waves: one of six bosses", "When every beast is dead the North gate opens and one boss comes out, picked at random from six. The next six stops are those bosses; a boss pull jumps the card to the right one." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "2 to 7 beasts per wave, melee", "Per wave: 4 Dredge Worms, 2 Deep Stingers, 5 Dark Screechers, 3 Burrowing Thundersnouts, 3 Cave Creepers or 7 Borer Beetles. Borer Beetles also halve the tank's armor with Pierce Armor." },
          { "fire", "Magma Totem", "weak beasts in a pack", "The beasts are level 50-52 and not elite. Magma Totem or a Fire Nova Totem where the tank holds them.", or_ = "Fire Nova Totem" },
          { "water", "Disease Cleansing Totem", "by beast", "Disease Cleansing Totem for Dredge Worms (Dredge Sickness) and Borer Beetles (Putrid Enzyme). Poison Cleansing Totem for Deep Stingers (Barbed Sting), Cave Creepers (Creeper Venom, Poison) and the Dredge Worms' Poison and Venom Spit.", or_ = "Poison Cleansing Totem" },
          { "air", "Windfury Totem", "debuffs are area spells", "The opening debuffs are area effects and cannot be grounded. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 14535, 14539, 14534, 14532, 14538, 8281, 14533, 15548, 6016, 13298, 6917 },
      },
      {
        key = "gorosh", kind = "boss", title = "Ring: Gorosh the Dervish", optional = true,
        names = { "Gorosh the Dervish" },
        threat = "Whirlwind on all near, Mortal Strike",
        act = {
          { "Step out of Whirlwind unless you tank", "Whirlwind strikes everyone around him every 2 seconds while it lasts, each hit weapon damage plus 300. Melee step out until it ends; ranged and healers never stand next to him." },
          { "Purge Bloodlust off him", "Bloodlust is a magic buff: 30% faster melee attacks. A shaman's Purge removes it." },
        },
        watch = {
          { "Mortal Strike: big hit, halves healing", "Mortal Strike hits for 300% weapon damage and halves the healing its target receives while the effect lasts. He is one of six Ring of Law bosses, picked at random: he may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Mortal Strike, Whirlwind", "Everything he does is a physical melee attack: Mortal Strike for 300% weapon damage, Whirlwind on everyone around him every 2 seconds. He cannot be feared." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "The Mortal Strike healing debuff is not a disease, poison, curse or magic effect: nobody removes it." },
          { "air", "Windfury Totem", "no casts to ground", "He casts no spell at a player: his attacks are all physical. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15708, 13736, 15589, 21049 },
      },
      {
        key = "grizzle", kind = "boss", title = "Ring: Grizzle", optional = true,
        names = { "Grizzle" },
        threat = "Ground Tremor stun, Frenzy",
        act = {
          { "Keep ranged and healers away from him", "Ground Tremor stuns everyone in the area around him. Only the tank and melee should be inside it." },
        },
        watch = {
          { "Frenzy: he hits harder and faster", "His Frenzy (the spell is named Enrage) raises his damage by 50% and his attack speed by 60%. The Classic data gives no health mark for it: keep the tank topped up throughout." },
          { "One of six ring bosses, picked at random", "The Ring of Law sends one of six bosses. Grizzle may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Frenzy: 50% more damage", "All his damage is melee, and Frenzy adds 50% damage and 60% attack speed. Ground Tremor is a stun: Tremor Totem does not help." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff in this fight." },
          { "air", "Windfury Totem", "no casts to ground", "He casts nothing at a single player. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 6524, 8269 },
      },
      {
        key = "eviscerator", kind = "boss", title = "Ring: Eviscerator", optional = true,
        names = { "Eviscerator" },
        threat = "Shadow Bolt Volley, bleed, spell immunity",
        act = {
          { "Interrupt Shadow Bolt Volley", "Shadow Bolt Volley hits everyone around him for 128-172 shadow damage. It has a cast time and can be interrupted." },
          { "Stop casting into Anti-Magic Shield", "While Anti-Magic Shield is up he is immune to all six magic schools (holy, fire, nature, frost, shadow, arcane). Physical attacks still land: casters wait it out, melee keep going." },
        },
        watch = {
          { "Vicious Rend: a bleed that stacks to 3", "Vicious Rend bleeds its target for 34 every 3 seconds per stack, up to 3 stacks. A bleed cannot be cleansed. He is one of six ring bosses and may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Vicious Rend, melee", "His melee and the Vicious Rend bleed land on the tank. He cannot be feared." },
          { "water", "Healing Stream Totem", "Shadow Bolt Volley", "Shadow Bolt Volley hits every player near him for 128-172 when it is not interrupted. Nothing to cleanse: the bleed stays.", or_ = "Mana Spring Totem" },
          { "air", "Windfury Totem", "volley: not groundable", "Shadow Bolt Volley is an area spell around him and cannot be grounded. Windfury Totem for melee, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 14331, 15245, 7121 },
      },
      {
        key = "okthor", kind = "boss", title = "Ring: Ok'thor the Breaker", optional = true,
        names = { "Ok'thor the Breaker" },
        threat = "No spell data for him in Classic",
        act = {
          { "Watch his cast bar: no spell data", "The Classic data lists no spells for Ok'thor the Breaker, so this card has no mechanic to name. Interrupt what you can and move out of anything on the ground." },
        },
        watch = {
          { "Ok'thor: cannot be feared", "He is immune to fear and horror; nothing else is listed. He is one of six Ring of Law bosses, picked at random, and may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "no spell data: the default", "Nothing in the Classic data calls for Tremor Totem or any other earth totem. Stoneskin Totem for the tank." },
          { "water", "Mana Spring Totem", "nothing known to cleanse", "No disease or poison is listed for him." },
          { "air", "Windfury Totem", "no spell data", "No single-target spell is listed, so there is no reason to prefer Grounding Totem. Windfury Totem for melee, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15740 },
      },
      {
        key = "anubshiah", kind = "boss", title = "Ring: Anub'shiah", optional = true,
        names = { "Anub'shiah" },
        threat = "Shadow Bolt, Banish, curses, web",
        act = {
          { "Interrupt Shadow Bolt and Banish", "Shadow Bolt (255-345 shadow) and Banish both have a cast time and can be interrupted. Banish takes one player out of the fight: stunned and immune to everything until it ends." },
          { "Remove Curse of Tongues", "Curse of Tongues hits everyone around him and halves casting speed. A mage or druid removes curses; his Curse of Weakness (less damage done) is one too." },
        },
        watch = {
          { "Enveloping Web: root and silence", "Enveloping Web roots one player, silences them and stops their melee swings. A webbed healer cannot cast until it ends. He is one of six ring bosses and may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor", "He casts no fear, charm or sleep. Demon Armor gives him 210 armor and is a magic buff: Purge it." },
          { "water", "Mana Spring Totem", "curses: not yours to remove", "Curse of Tongues and Curse of Weakness are curses: a mage or druid removes them. No disease or poison." },
          { "air", "Grounding Totem", "eats a Shadow Bolt or Banish", "Shadow Bolt and Banish are each cast at one player, so Grounding Totem takes one. His Curse of Tongues is an area effect and goes through." },
        } },
        cite = { 13787, 15472, 15471, 12493, 15470, 8994 },
      },
      {
        key = "hedrum", kind = "boss", title = "Ring: Hedrum the Creeper", optional = true,
        names = { "Hedrum the Creeper" },
        threat = "Poison on everyone near, stun, web",
        act = {
          { "Remove poison at once", "Paralyzing Poison is a poison that stuns one player. Baneful Poison hits everyone around him for 510-690 and leaves a poison that stacks to 3. A druid, paladin or shaman removes poison." },
          { "Keep ranged and healers away from him", "Baneful Poison and Web Explosion both hit the area around him. Only the tank and melee should be inside it." },
        },
        watch = {
          { "Web Explosion roots everyone near him", "Web Explosion roots every player around him. He cannot be slowed or feared. He is one of six ring bosses and may not be the one you get." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor", "He casts no fear, charm or sleep. Paralyzing Poison is a stun and Web Explosion a root: Tremor Totem removes neither." },
          { "water", "Poison Cleansing Totem", "Paralyzing, Baneful Poison", "Both are poisons. Poison Cleansing Totem frees a paralyzed player and strips Baneful Poison stacks from the melee." },
          { "air", "Nature Resistance Totem", "Baneful Poison", "Baneful Poison is 510-690 nature damage to everyone around him. Nature Resistance is an Air totem; Windfury Totem if nobody but the tank stands near him.", or_ = "Windfury Totem" },
        } },
        cite = { 3609, 15474, 15475 },
      },
      ------------------------------------------------------------------ Shadowforge City
      {
        key = "city", kind = "trash", title = "Shadowforge City",
        here = "Spectators, Peasants, Citizens, Emissaries",
        threat = "Random roles: healers, casters, runners",
        act = {
          { "Interrupt Heal: any of them can be a healer", "Arena Spectators, Shadowforge Peasants and Shadowforge Citizens each get a random role when they spawn: fighter, shooter, caster or healer. The healers cast Heal (394-456 on a friend); Anvilrage Medics up here heal for 879-1021. Both heals can be interrupted." },
          { "Leave the arena crowd alone after the win", "Once the Ring of Law is won, the crowd in the stands above the arena turns neutral. They no longer attack: do not hit them." },
        },
        watch = {
          { "Twilight Emissary: Blizzard, move out", "Twilight Emissaries are elite and take one of three roles: Fireball; Blizzard on the ground with Frost Nova and Frostbolt; or Arcane Explosion around them with Arcane Bolt. Move out of Blizzard." },
          { "Bridge: 2 Guardsmen run at you", "Stepping onto the Shadowforge bridge makes two Anvilrage Guardsmen spawn and run at the player who triggered it, once per run. It only happens in a run where Pyromancer Loregrain has spawned." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "weak packs; runners", "Most of the city is not elite. Earthbind Totem slows the Spectators, Peasants, Citizens and Emissaries that run at 15% health.", or_ = "Earthbind Totem" },
          { "fire", "Magma Totem", "non-elite packs", "Arena Spectators, Shadowforge Peasants and Shadowforge Citizens are not elite and none of them is immune to fire." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Tongues from a caster Spectator is a curse, the frost slows are magic: not yours to remove. No disease or poison." },
          { "air", "Grounding Totem", "eats a bolt or a curse", "Fireball, Shadow Bolt, Frostbolt, Arcane Bolt and Curse of Tongues are each cast at one player. Blizzard and Arcane Explosion are area spells and go through." },
        } },
        cite = { 11642, 15586, 13338, 9053, 9613, 8364, 15063, 13745, 13748, 12466, 15043, 7978, 6713 },
      },
      {
        key = "loregrain", kind = "boss", title = "Pyromancer Loregrain", optional = true,
        names = { "Pyromancer Loregrain" },
        threat = "Molten Blast, Flame Shock, a fire totem",
        act = {
          { "Interrupt Molten Blast", "Molten Blast (121-139 fire on one player) has a cast time and can be interrupted." },
          { "Kill his Scorching Totem", "He summons a Scorching Totem. Target it and kill it each time he plants one." },
        },
        watch = {
          { "Rare: he may not be up", "Pyromancer Loregrain is a rare spawn. Flame Shock (96 fire, then 26 every 3 seconds) is magic: a priest or paladin removes it. His Fire Ward is a magic buff: Purge it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor", "He casts no fear, charm or sleep and cannot be feared himself. Stoneskin Totem for the tank." },
          { "water", "Fire Resistance Totem", "all his damage is fire", "Fire Resistance is a Water totem. Molten Blast and Flame Shock are both fire damage." },
          { "air", "Grounding Totem", "eats Molten Blast, Flame Shock", "Molten Blast and Flame Shock are each cast at one player, so Grounding Totem takes one of them." },
        } },
        cite = { 15041, 15095, 15616, 15038 },
      },
      ------------------------------------------------------------------ Vault, Darkvire, Incendius
      {
        key = "firehalls", kind = "trash", title = "Halls to the Vault and Incendius",
        here = "Blazing Fireguards, Constructs, Craftsmen",
        threat = "Fire damage, stuns, bombs, Blizzard",
        act = {
          { "Use no fire on Blazing Fireguards", "Blazing Fireguards are immune to fire damage. Fire mages, warlocks and shamans switch school; Searing and Magma Totem do nothing to them." },
          { "Move out of Blizzard", "Twilight Emissaries stand around the vault, each with one of three roles: Fireball; Blizzard on the ground with Frost Nova and Frostbolt; or Arcane Explosion around them. They are elite and run at 15% health." },
        },
        watch = {
          { "Warbringer Construct: Skull Crack stun", "Warbringer Constructs stun their target with Skull Crack. Twilight Bodyguards stun with Fist of Ragnaros and Pummel a player who is casting. Bloodhound Mastiffs near the vault leech 278-322 health with Ravenous Claw." },
          { "Blazing Fireguard: Fire Blast, Immolate", "Blazing Fireguards cast Immolate and Scorch (both can be interrupted) and an instant Fire Blast for 165-195. Doomforge Craftsmen throw a Bomb that hits an area; they and the Shadowforge Peasants around the vault are not elite and run at 15% health." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Constructs hit in melee", "Warbringer Constructs, Twilight Bodyguards and Bloodhound Mastiffs all fight in melee. Earthbind Totem slows the Craftsmen, Peasants and Emissaries that run at 15% health.", or_ = "Earthbind Totem" },
          { "water", "Fire Resistance Totem", "Fire Blast, Immolate, Scorch", "Fire Resistance is a Water totem. Everything a Blazing Fireguard casts is fire, and the Craftsmen's Bomb is fire too." },
          { "air", "Grounding Totem", "eats Fire Blast or Immolate", "Fire Blast, Scorch, Immolate, an Emissary's Fireball or Frostbolt and a Bodyguard's Fist of Ragnaros stun are each aimed at one player, so Grounding Totem takes one. Blizzard and Arcane Explosion are area spells and go through." },
        } },
        cite = { 13341, 20787, 13878, 15621, 9143, 13902, 15615, 8364, 15063, 15043, 12466, 13745, 15608, 7140 },
      },
      {
        key = "vault", kind = "boss", title = "The Vault: Stilgiss and Verek", optional = true,
        names = { "Warder Stilgiss", "Verek" },
        threat = "Frostbolt, Frost Nova root, Enrage",
        act = {
          { "Interrupt Stilgiss's Frostbolt", "Warder Stilgiss fights from range. Frostbolt (143-193 frost and a slow) has a cast time and can be interrupted; Frost Nova roots everyone around him." },
          { "Stop Stilgiss at 15%: he runs", "Warder Stilgiss flees at 15% health. Slow, stun or burst him before he gets away." },
        },
        watch = {
          { "Verek at 30%: Enrage", "Verek enrages at 30% health and attacks 30% faster. He also casts Curse of Blood (more damage taken): a mage or druid removes it." },
          { "Both are rare: either may be missing", "Warder Stilgiss and Verek are rare spawns that stand together in the vault. You may find both, one or neither." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Verek's melee and Enrage", "Verek only melees, and faster under 30% health. Earthbind Totem is the swap for Stilgiss's run at 15%.", or_ = "Earthbind Totem" },
          { "fire", "Frost Resistance Totem", "Frostbolt, Frost Nova", "Frost Resistance is a Fire totem. All of Warder Stilgiss's damage is frost: Frostbolt and Frost Nova." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "The frost slows are magic and Curse of Blood is a curse: not yours to remove. Purge takes off Stilgiss's Frost Ward and his Frost Armor, which chills whoever hits him (25% slower attacks, 30% slower movement)." },
          { "air", "Grounding Totem", "eats a Frostbolt", "Stilgiss's Frostbolt and Verek's Curse of Blood are each cast at one player, so Grounding Totem takes one. Frost Nova is an area spell and goes through." },
        } },
        cite = { 12544, 15044, 12674, 12675, 15042, 8599 },
      },
      {
        key = "doomgrip", kind = "boss", title = "Vault event: Watchman Doomgrip", optional = true,
        names = { "Watchman Doomgrip" },
        threat = "Doomgrip and four constructs at once",
        act = {
          { "Rest before the 12th coffer door", "Opening the twelfth relic coffer door wakes the stoned Warbringer Constructs in the vault and summons Watchman Doomgrip, all at once. Be at full health and mana first." },
          { "Kill them all to open the secret door", "When Doomgrip and every vault construct are dead, the secret door opens and the safe behind it can be used." },
        },
        watch = {
          { "Doomgrip: Sunder Armor, healing potion", "Watchman Doomgrip stacks Sunder Armor on the tank up to 5 times and drinks a healing potion for 590-684. The Warbringer Constructs stun with Skull Crack." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Sunder Armor on the tank", "Five enemies in melee and Sunder Armor stacking on the tank. Doomgrip cannot be feared." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff. Healing Stream Totem if the stuns leave the group short of healing.", or_ = "Healing Stream Totem" },
          { "air", "Windfury Totem", "no casts to ground", "Nobody here casts a spell at a player. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 11971, 15504, 15621, 10255 },
      },
      {
        key = "fineous", kind = "boss", title = "Fineous Darkvire", optional = true,
        names = { "Fineous Darkvire" },
        threat = "Heals himself at 60% and 40%, Kick",
        act = {
          { "Interrupt Holy Light at 60% and 40%", "He casts Holy Light at 60% and again at 40% health: 467-541 healed. It has a cast time and can be interrupted: save an interrupt for each." },
        },
        watch = {
          { "Kick: he interrupts his target", "He Kicks his target when it casts. A paladin or druid tank gets its own casts interrupted; so does anyone who pulls him off the tank." },
          { "At 20%: Seal of Reckoning", "At 20% health he puts Seal of Reckoning on himself: a magic buff whose procs heal him for 24. A shaman's Purge removes it. Doomforge Craftsmen and Warbringer Constructs stand near him." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "melee and Holy Strike", "He fights in melee with Holy Strike under a Devotion Aura. He casts no fear and cannot be feared." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff in this fight." },
          { "air", "Windfury Totem", "no casts to ground", "He casts nothing at a player except his own heal. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 8258, 13953, 11978, 15493, 15346, 15347 },
      },
      {
        key = "incendius", kind = "boss", title = "Lord Incendius", optional = true,
        names = { "Lord Incendius" },
        threat = "Fire on the ground, Fiery Burst, curse",
        act = {
          { "Move out of Fire Storm", "Fire Storm hits an area for 324-376 and leaves fire on the ground that burns for 185-215 every 3 seconds. It has a cast time: interrupt it or step out." },
          { "Interrupt Fiery Burst", "Fiery Burst hits everyone in its target area for 510-690 fire damage. It has a cast time and can be interrupted." },
        },
        watch = {
          { "Curse of the Elemental Lord: decurse", "Curse of the Elemental Lord hits everyone around him: 100 less fire resistance per stack, up to 3 stacks. A mage or druid removes it." },
          { "Mighty Blow knocks the tank back", "Mighty Blow knocks its target back: tank him with your back to a wall. He is immune to fire damage and cannot be stunned or feared." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Mighty Blow, melee", "His melee and Mighty Blow land on the tank. Nothing to tremor." },
          { "water", "Fire Resistance Totem", "Fire Storm, Fiery Burst", "Fire Resistance is a Water totem. His curse strips 100 fire resistance per stack, so get it removed. He is immune to fire damage: no Searing or Magma Totem." },
          { "air", "Windfury Totem", "no single-target casts", "Fire Storm and Fiery Burst are area spells and cannot be grounded. Windfury Totem for melee, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 26977, 13900, 14099, 13899 },
      },
      ------------------------------------------------------------------ Bael'Gar, Angerforge
      {
        key = "garrison", kind = "trash", title = "Anvilrage army: Bael'Gar to Angerforge",
        here = "Soldiers, Officers, Medics, Marshals",
        threat = "Healers, stuns, Cleave, runners",
        act = {
          { "Kill the Medics first; interrupt Heal", "Anvilrage Medics cast Heal (879-1021 on a friend) and Prayer of Healing (374-434 on their whole group). Both have a cast time and can be interrupted. Medics run at 15% health." },
          { "Interrupt Holy Light", "Anvilrage Officers and Anvilrage Marshals cast Holy Light on a hurt friend (234-270). Officers put up Divine Shield at 20% health: switch target until it ends." },
        },
        watch = {
          { "Officer: Backhand stuns the tank", "Anvilrage Officers stun with Backhand and open with Battle Shout. Anvilrage Soldiers Cleave up to 3 players and Hamstring. Medics also cast Mind Blast (139-161 shadow) at one player." },
          { "Fireguard Destroyer: Fireball Volley", "Fireguard Destroyers stand near General Angerforge: Fireball Volley is 96-128 fire damage to everyone around them, instant, so it cannot be interrupted. They are immune to fire damage." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "melee packs; runners", "Soldiers, Officers and Marshals all hit in melee. Earthbind Totem slows the Medics and Marshals that run at 15% health.", or_ = "Earthbind Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff from these packs. Fire Resistance Totem is the swap for a pull with a Fireguard Destroyer." },
          { "air", "Grounding Totem", "eats a Medic's Mind Blast", "Mind Blast is cast at one player, so Grounding Totem takes it. Windfury Totem instead if there is no Medic in the pull.", or_ = "Windfury Totem" },
        } },
        cite = { 15586, 15585, 15587, 13952, 13874, 6253, 15284, 9080, 9128, 15243 },
      },
      {
        key = "baelgar", kind = "boss", title = "Bael'Gar",
        names = { "Bael'Gar" },
        threat = "Adds at 80/60/40/20%, Magma Splash",
        act = {
          { "Kill each Spawn of Bael'Gar", "At 80%, 60%, 40% and 20% health he casts Summon Spawn of Bael'Gar and an add appears. In the Classic data each summon also burns the area where it lands for 1388-1612 fire damage." },
        },
        watch = {
          { "Magma Splash: fire burn, stacks to 3", "Magma Splash is on him from the start and triggers on one player at a time: 70-80 fire damage, then 50 every 3 seconds, stacking up to 3 times. It has no dispel type: nobody removes it." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "boss and adds in melee", "He and each Spawn of Bael'Gar hit in melee. He casts no fear and cannot be feared." },
          { "water", "Fire Resistance Totem", "Magma Splash burns, stacks 3", "Fire Resistance is a Water totem. Magma Splash is 70-80 fire damage and a 50-per-3-seconds burn that stacks to 3; the summon is fire as well." },
          { "air", "Windfury Totem", "no casts to ground", "He casts no spell at a single player that Grounding Totem can take: Magma Splash is a proc of his aura. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 23378, 23379, 13895 },
      },
      {
        key = "angerforge", kind = "boss", title = "General Angerforge",
        names = { "General Angerforge" },
        threat = "Ten adds below 30%, Sunder Armor",
        act = {
          { "Save cooldowns for 30%: 10 adds", "Below 30% health he sounds the alarm: 8 Anvilrage Reservists and 2 Anvilrage Medics spawn and go for his target. It repeats after 3 minutes if he is still alive, so finish him fast." },
          { "Kill or interrupt the 2 Medics", "The Medics cast Heal (879-1021 on a friend, the General included) and Prayer of Healing. Both can be interrupted. Reservists are not elite: area damage." },
        },
        watch = {
          { "Sunder Armor stacks on the tank", "Sunder Armor every 5-15 seconds, up to 5 stacks. From the pull he also has Flurry and Enrage procs, each 30% faster attacks. No stun, fear, root, slow or silence works on him." },
          { "By him: 4 Reservists, 2 Marshals", "Four Anvilrage Reservists and two Anvilrage Marshals stand beside him, and two Fireguard Destroyers are close by. Marshals cast Holy Light on a hurt friend: clear them before the pull." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Sunder Armor, Flurry", "Sunder Armor stacks to 5 on the tank while Flurry and Enrage each make him attack 30% faster. He casts no fear." },
          { "fire", "Magma Totem", "8 Reservists at 30%", "The 8 Anvilrage Reservists are not elite. Drop Magma Totem or a Fire Nova Totem at the tank's feet when the alarm sounds.", or_ = "Fire Nova Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff. The Reservists' Hamstring is a physical slow." },
          { "air", "Windfury Totem", "no casts to ground", "Only the Medics' Mind Blast is aimed at a player. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15088, 17687, 15097, 15061, 15572, 15586, 15585, 15587, 13952, 9128, 9080 },
      },
      ------------------------------------------------------------------ Golems and forge
      {
        key = "forge", kind = "trash", title = "Golems and the forge",
        here = "Ragereaver Golems, Wrath Hammers, Technicians",
        threat = "Flame Cannon, knockback, golem Frenzy",
        act = {
          { "Interrupt Flame Cannon", "Wrath Hammer Constructs fight from range with Flame Cannon (128-172 fire, can be interrupted) and knock their target back with Uppercut." },
        },
        watch = {
          { "Ragereaver Golem at 15%: Frenzy", "Ragereaver Golems stand stoned until pulled, have Flurry procs (30% faster attacks), and at 15% health enrage for another 30%. Finish a low golem quickly." },
          { "Technicians shoot, Arcanasmiths cast", "Weapon Technicians use one of Exploding Shot (hits an area), Frost Shot (a magic slow) or Multi-Shot (up to 3 players). Doomforge Arcanasmiths cast Arcane Bolt. Both are not elite, stay at range and run at 15% health." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "golem Flurry and Frenzy", "Ragereaver Golems are pure melee with Flurry, and faster still under 15% health." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Frost Shot is a magic slow: not yours to remove. Fire Resistance Totem is the swap for a pull with several Wrath Hammer Constructs." },
          { "air", "Grounding Totem", "eats Flame Cannon, Arcane Bolt", "Flame Cannon and Arcane Bolt are each cast at one player, so Grounding Totem takes one. Uppercut is a melee ability." },
        } },
        cite = { 15088, 17687, 12795, 10966, 15575, 7896, 12551, 14443, 13748, 10255 },
      },
      {
        key = "argelmach", kind = "boss", title = "Golem Lord Argelmach",
        names = { "Golem Lord Argelmach" },
        threat = "Chain Lightning, Shock, two golems",
        act = {
          { "Interrupt Chain Lightning", "Chain Lightning hits for 278-322 nature damage and jumps to up to 5 players. It has a cast time and can be interrupted. He cannot be silenced or stunned, so use a real interrupt." },
        },
        watch = {
          { "Lightning Shield: Purge it, he recasts", "Lightning Shield is a magic buff with a damage proc. A shaman's Purge removes it; he puts it back whenever it is missing." },
          { "A Ragereaver and a Wrath Hammer by him", "A Ragereaver Golem (Frenzy at 15% health) and a Wrath Hammer Construct (Uppercut knockback, Flame Cannon) stand beside him. Plan the pull for all three." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "golems and boss in melee", "The Ragereaver Golem's Flurry and his own melee land on the tank. Nothing to tremor." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff: his spells are direct nature damage." },
          { "air", "Grounding Totem", "his nature spells", "Grounding Totem takes a Shock (273-293) whole, and the first hit of a Chain Lightning, which can still jump on from the totem. Nature Resistance Totem instead if Chain Lightning keeps hurting the group.", or_ = "Nature Resistance Totem" },
        } },
        cite = { 15507, 15305, 15605, 12795, 10966, 15575 },
      },
      ------------------------------------------------------------------ Grim Guzzler
      {
        key = "hurley", kind = "boss", title = "Grim Guzzler: Hurley Blackbreath", optional = true,
        names = { "Hurley Blackbreath" },
        threat = "Flame Breath cone, three cronies, rage",
        act = {
          { "Tank faces him away: Flame Breath", "Flame Breath is a cone of fire in front of him, 7 seconds in and every 10 seconds after. It has a cast time and can be interrupted. Only the tank stands in front." },
          { "Rest before breaking the 3rd keg", "Breaking the third beer keg summons Hurley Blackbreath and 3 Blackbreath Cronies. They run to the kegs and only then can be fought." },
        },
        watch = {
          { "Below 31%: Drunken Rage", "Under 31% health he casts Drunken Rage once: 50% more damage and 50% faster attacks. Keep the tank full and finish him." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "4 in melee, Drunken Rage", "Hurley and his three cronies (Sinister Strike) all hit in melee, and he hits half again as hard under 31% health. He cannot be feared." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "No disease, poison, curse or magic debuff. Flame Breath is fire and only reaches players in front of him." },
          { "air", "Windfury Totem", "no casts to ground", "Flame Breath is a cone, not a spell aimed at one player. Windfury Totem for melee, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 9573, 14872, 15581 },
      },
      {
        key = "ribbly", kind = "boss", title = "Grim Guzzler: Ribbly Screwspigot", optional = true,
        names = { "Ribbly Screwspigot" },
        threat = "Gouge, runs at 15%, poison cronies",
        act = {
          { "Stop him at 15%: he runs", "Ribbly Screwspigot flees at 15% health. Slow, stun or burst him. He Gouges the player in front of him and Hamstrings." },
        },
        watch = {
          { "Three Cronies: elite, poison", "Three Ribbly's Cronies stand with him: Sinister Strike and a Poison on their hits (24 nature damage every 3 seconds). A druid, paladin or shaman removes poison." },
          { "His death opens the back door + patrol", "When Ribbly dies the bar's back door opens and a patrol walks in: one Fireguard Destroyer and two Anvilrage Officers. It does not happen if Plugger's event has already started." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "4 in melee; he runs", "Ribbly and three elite cronies all hit in melee. Earthbind Totem slows him when he runs at 15% health.", or_ = "Earthbind Totem" },
          { "water", "Poison Cleansing Totem", "the Cronies' Poison", "Ribbly's Cronies poison on hit: 24 nature damage every 3 seconds per target. Poison Cleansing Totem keeps it off the melee." },
          { "air", "Windfury Totem", "just a poison proc", "The Cronies' Poison proc is the only thing here Grounding Totem can take, and it is small. Windfury Totem for a melee group, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 12540, 9080, 13299, 13298, 15581 },
      },
      {
        key = "plugger", kind = "boss", title = "Grim Guzzler: Plugger Spazzring", optional = true,
        names = { "Plugger Spazzring" },
        threat = "Banish, shadow bolts; bar turns hostile",
        act = {
          { "Finish bar quests before killing him", "When Plugger dies every patron in the Grim Guzzler turns hostile, Private Rocknot and Mistress Nagmara leave, and Phalanx walks to guard the back door." },
          { "Heal through his casts: no interrupts", "He turns hostile when a player takes a third ale mug from the tables or pickpockets him. He cannot be interrupted, stunned or feared: Shadow Bolt (128-172) and Immolate land on the tank regardless." },
        },
        watch = {
          { "Banish: one random player is out", "Banish hits a random player 8-12 seconds in and every 26-28 seconds after: stunned and immune to everything until it ends. Curse of Tongues (half cast speed) goes on a mana user: a mage or druid removes it." },
          { "After he dies: every patron attacks", "Grim Patrons Kick casters, Guzzling Patrons cast Curse of Agony and Shadow Bolt from range, Hammered Patrons (elite) stun with Backhand. They are weak but there are dozens: area damage." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "patron packs after he dies", "Plugger himself mostly casts. The Grim and Hammered Patrons that turn hostile at his death hit in melee, many at once." },
          { "fire", "Magma Totem", "weak patrons in packs", "Grim Patrons and Guzzling Patrons are not elite. Magma Totem or a Fire Nova Totem where the tank gathers them.", or_ = "Fire Nova Totem" },
          { "water", "Mana Spring Totem", "curses: not yours to remove", "Curse of Tongues and the Guzzling Patrons' Curse of Agony are curses: a mage or druid removes them. Immolate is magic. No disease or poison." },
          { "air", "Grounding Totem", "eats Banish or a Shadow Bolt", "Banish, Shadow Bolt, Immolate and Curse of Tongues are each cast at one player, so Grounding Totem takes one of them." },
        } },
        cite = { 8994, 13338, 13787, 12742, 12739, 11978, 14868, 20825, 6253, 15341 },
      },
      {
        key = "phalanx", kind = "boss", title = "Grim Guzzler: Phalanx", optional = true,
        names = { "Phalanx" },
        threat = "Knockback, Thunderclap, Fireball Volley",
        act = {
          { "Tank him with your back to a wall", "Mighty Blow knocks his target back, first after 15 seconds and then every 10." },
          { "Keep ranged and healers away from him", "Thunderclap hits everyone around him every 10 seconds: 71-79 nature damage, slower movement and 33% slower attacks. It is magic: a priest or paladin removes it." },
        },
        watch = {
          { "Below 51%: Fireball Volley on all near", "Under 51% health he adds Fireball Volley every 15 seconds: 128-172 fire damage to everyone around him. It is instant and cannot be interrupted." },
          { "Horde: he attacks after Plugger dies", "He stands idle until a bar event starts. When Private Rocknot has been given his ale three times he smashes a keg and the back door, and Phalanx attacks everyone. After Plugger's death Phalanx is hostile to Horde players only." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Mighty Blow, melee", "His melee and Mighty Blow land on the tank. He casts no fear and cannot be feared." },
          { "water", "Fire Resistance Totem", "Fireball Volley under 51%", "Fire Resistance is a Water totem. Above 51% health nothing he does is fire: Mana Spring Totem until then." },
          { "air", "Nature Resistance Totem", "Thunderclap", "Thunderclap is nature damage on everyone near him every 10 seconds and cannot be grounded. Windfury Totem if only the tank stands in it.", or_ = "Windfury Totem" },
        } },
        cite = { 15588, 14099, 15285, 14872 },
      },
      ------------------------------------------------------------------ Flamelash, Panzor
      {
        key = "flamelash", kind = "boss", title = "Ambassador Flamelash",
        names = { "Ambassador Flamelash" },
        threat = "Burning Spirits from 7 runes, Fire Blast",
        act = {
          { "Kill Burning Spirits before they reach him", "Seven runes each send a Burning Spirit at him every 15-30 seconds. A spirit that reaches him casts Burning Spirit on him and dies. They are level 30, not elite, and immune to fire damage." },
          { "Purge his Fire Blast buff", "On the pull he puts a Fire Blast aura on himself: his hits then trigger Fire Blast for 220-260 fire damage on their target. It is a magic buff: a shaman's Purge removes it." },
        },
        watch = {
          { "On pull: 4 Fireguard Destroyers spawn", "Pulling him also spawns four Fireguard Destroyers. They cast Fireball Volley (96-128 fire damage to everyone around them) and are immune to fire damage." },
        },
        classes = { SHAMAN = {
          { "earth", "Earthbind Totem", "slows the Burning Spirits", "Burning Spirits walk from the runes to him; Earthbind Totem beside him slows them so they die before they arrive. Stoneskin Totem if the group kills them easily.", or_ = "Stoneskin Totem" },
          { "water", "Fire Resistance Totem", "Fire Blast on his hits", "Fire Resistance is a Water totem. Fire Blast adds 220-260 fire damage to his hits until the aura is purged. Burning Spirits and Fireguard Destroyers are immune to fire damage: no Searing, Magma or Fire Nova Totem for them." },
          { "air", "Grounding Totem", "takes a Fire Blast proc", "Fire Blast is fire damage aimed at one player, so Grounding Totem takes one. Windfury Totem instead once the aura is purged: it helps melee cut down the spirits.", or_ = "Windfury Totem" },
        } },
        cite = { 15573, 15574, 13489, 15243 },
      },
      {
        key = "panzor", kind = "boss", title = "Panzor the Invincible", optional = true,
        names = { "Panzor the Invincible" },
        threat = "No spell data; Arcanasmiths around him",
        act = {
          { "Clear the Arcanasmiths around him first", "Six Doomforge Arcanasmiths and three Molten War Golems stand within reach of his spot. Arcanasmiths cast Arcane Bolt from range, are not elite and run at 15% health." },
        },
        watch = {
          { "Rare: he may not be up", "Panzor the Invincible is a rare spawn. The Classic data lists no spells for him or for the Molten War Golems, so this card has no mechanic to name. He cannot be feared." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "no spell data: the default", "Nothing in the Classic data calls for Tremor Totem or another earth totem. Stoneskin Totem for the tank against him and the golems." },
          { "water", "Mana Spring Totem", "nothing known to cleanse", "No disease or poison is listed for him or for the packs around him." },
          { "air", "Grounding Totem", "eats an Arcane Bolt", "The Arcanasmiths' Arcane Bolt is cast at one player. Windfury Totem once they are dead: nothing is listed for Panzor to ground.", or_ = "Windfury Totem" },
        } },
        cite = { 13748, 13745 },
      },
      ------------------------------------------------------------------ Summoners' Tomb
      {
        key = "seven", kind = "boss", title = "Summoners' Tomb: the Seven",
        names = { "Anger'rel", "Seeth'rel", "Dope'rel", "Gloom'rel", "Vile'rel", "Hate'rel", "Doom'rel" },
        threat = "A new dwarf every 30 s; heals, Mana Burn",
        act = {
          { "Kill each dwarf inside 30 seconds", "Talking to Doom'rel starts it; a wipe resets all seven. The next dwarf joins when the current one dies or 30 seconds after it joined, whichever comes first. Order: Anger'rel, Seeth'rel, Dope'rel, Gloom'rel, Vile'rel, Hate'rel, Doom'rel." },
          { "Interrupt Vile'rel's heals", "Vile'rel (fifth) casts Heal (879-1021 on a friend) and Prayer of Healing on all of them. Hate'rel (sixth) casts Mana Burn at a mana user. All three casts can be interrupted." },
        },
        watch = {
          { "Doom'rel, last: Voidwalkers and a volley", "Doom'rel summons Voidwalker Minions when he joins and casts Shadow Bolt Volley on everyone around him (it can be interrupted), Immolate and Curse of Weakness. His death ends the event." },
          { "Gloom'rel: Mortal Strike halves healing", "Gloom'rel (fourth) Cleaves up to 3 players and uses Mortal Strike: healing on its target is halved. Seeth'rel (second) roots with Frost Nova; Anger'rel's Shield Wall cuts the damage he takes by 75%." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Mortal Strike, Backstab, Cleave", "Anger'rel, Dope'rel and Gloom'rel are melee fighters. None of the seven casts a fear, and none can be feared or slept." },
          { "water", "Mana Spring Totem", "long fight, Mana Burn", "Seven dwarves back to back and Hate'rel's Mana Burn (272-300 mana). The frost slows and Immolate are magic, Curse of Weakness is a curse: not yours to remove." },
          { "air", "Grounding Totem", "eats a Mana Burn or Frostbolt", "Seeth'rel's Frostbolt, Hate'rel's Mana Burn and Shadow Bolt, and Vile'rel's Mind Blast are each cast at one player. Doom'rel's Shadow Bolt Volley is an area spell and goes through." },
        } },
        cite = { 15062, 11971, 12674, 15244, 12675, 15583, 12540, 15582, 13737, 15284, 15585, 15586, 15587, 14033, 15232, 12040, 15092, 15245, 12742, 12493 },
      },
      ------------------------------------------------------------------ Lyceum, Magmus
      {
        key = "lyceum", kind = "trash", title = "The Lyceum",
        here = "Flame Keepers, Anvilrage Reservists",
        threat = "Swarms of weak dwarves, Hamstring, shots",
        act = {
          { "Light both Shadowforge braziers", "Using the two Shadowforge braziers opens the way to Magmus: the first starts it, the second opens both doors of his hall." },
          { "Use area damage on the packs", "Shadowforge Flame Keepers and Anvilrage Reservists are not elite. They open with Battle Shout, Hamstring and Strike in melee and Shoot from range; Reservists run at 15% health." },
        },
        watch = {
          { "Hamstring: a slowed player falls behind", "Hamstring slows its target's movement by 60%. A slowed healer drops out of range of a group that keeps moving: wait for them." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "many weak melee hits", "Strike and Hamstring from many weak dwarves at once. Nothing here fears." },
          { "fire", "Magma Totem", "non-elite packs", "Flame Keepers and Reservists are not elite and not immune to fire. Magma Totem or a Fire Nova Totem in each pack.", or_ = "Fire Nova Totem" },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Hamstring is a physical slow: nobody removes it. No disease, poison, curse or magic." },
          { "air", "Windfury Totem", "packs Shoot from range", "Flame Keepers and Reservists Shoot (36-48 physical) when they are not in melee. Windwall Totem cuts that; Windfury Totem if the group is melee.", or_ = "Windwall Totem" },
        } },
        cite = { 9128, 9080, 11976, 6660 },
      },
      {
        key = "magmus", kind = "boss", title = "Magmus",
        names = { "Magmus" },
        threat = "War Stomp stun, Fiery Burst, fire statues",
        act = {
          { "Interrupt Fiery Burst", "Fiery Burst hits everyone in its target area for 255-345 fire damage. It has a cast time and can be interrupted." },
          { "Fight away from the Ironhand Guardians", "Pulling Magmus wakes the Ironhand Guardian statues. Each casts Gout of Flame every 20-40 seconds: 160-240 fire damage a second to everyone around that statue while it lasts. They cannot be attacked and keep firing after he dies." },
        },
        watch = {
          { "War Stomp stuns everyone near him", "War Stomp stuns and hits everyone in the area around him: ranged and healers stay out of it. He cannot be slowed or feared." },
          { "His death opens the throne room", "The hall doors move when he is pulled and again when he dies; his death also opens the door to the throne room." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "War Stomp, melee", "War Stomp is a stun with weapon damage on everyone near him, not a fear: Tremor Totem does not help." },
          { "water", "Fire Resistance Totem", "Fiery Burst, Gout of Flame", "Fire Resistance is a Water totem. Fiery Burst is 255-345 fire to an area, and each Ironhand Guardian's Gout of Flame burns for 160-240 a second around it." },
          { "air", "Windfury Totem", "no casts to ground", "Fiery Burst and Gout of Flame are area spells and cannot be grounded. Windfury Totem for melee, Tranquil Air Totem for casters.", or_ = "Tranquil Air Totem" },
        } },
        cite = { 15593, 15668, 15529, 15538, 15533 },
      },
      ------------------------------------------------------------------ Throne room
      {
        key = "throne", kind = "trash", title = "Throne room: Senators and Ambassadors",
        here = "Senators, Ambassadors, Doomforge Dragoons",
        threat = "Curses, shocks, Amplify Damage, shots",
        act = {
          { "Clear the room before the Emperor", "Emperor Dagran Thaurissan calls for help when he is pulled: every Senator, Ambassador and Dragoon still alive within sight joins the fight." },
          { "Dispel Amplify Damage", "Twilight's Hammer Ambassadors take a random role. One casts Amplify Damage (50% more damage taken by one player; magic, a priest or paladin removes it) with Curse of Weakness. The others use Frost Shock, Flame Shock, or Earth Shock with Bloodlust." },
        },
        watch = {
          { "Senators: a random role each", "Shadowforge Senators pick a role when pulled: Fireball with Fire Shield III, Curse of Agony with Shadow Bolt, Frost Nova, Slow (magic: slower attacks and movement) or Holy Smite. They are not elite." },
          { "Dragoons: Explosive Shot hits an area", "Doomforge Dragoons are elite and shoot from range; Explosive Shot damages everyone near its target. They run at 15% health. An Anvilrage Captain stands near the Emperor: Mortal Strike (healing taken halved) and Shield Bash on a caster." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "Dragoon Cleave; runners", "Doomforge Dragoons Cleave in melee and run at 15% health: Earthbind Totem slows them. Nothing here fears.", or_ = "Earthbind Totem" },
          { "fire", "Magma Totem", "non-elite Senators", "Shadowforge Senators and Twilight's Hammer Ambassadors are not elite and not immune to fire." },
          { "water", "Mana Spring Totem", "nothing to cleanse", "Curse of Agony and Curse of Weakness are curses; Slow, Amplify Damage and the shocks are magic. No disease or poison." },
          { "air", "Grounding Totem", "eats a shock, bolt or curse", "Fireball, Shadow Bolt, Holy Smite, the shocks, Slow and Amplify Damage are each cast at one player. Purge takes Bloodlust and Fire Shield III off them." },
        } },
        cite = { 12248, 11980, 15499, 15096, 6742, 15500, 15501, 2601, 14034, 14868, 12471, 11831, 11436, 15498, 15495, 15496, 13737, 11972 },
      },
      {
        key = "emperor", kind = "boss", title = "Emperor Dagran Thaurissan",
        names = { "Emperor Dagran Thaurissan", "Princess Moira Bronzebeard", "High Priestess of Thaurissan" },
        threat = "Random stuns, the Princess heals him",
        act = {
          { "Interrupt the Princess's Heal", "Princess Moira Bronzebeard heals the Emperor for 879-1021 about every 10 seconds once he is hurt. Heal has a cast time: interrupt it every time. She stands at range and does not melee." },
          { "Kill the Emperor, leave the Princess", "When the Emperor dies the Princess stops fighting and turns neutral. If every player has already finished her quest, the High Priestess of Thaurissan stands there instead: she heals him too (Heal, Renew) and is an enemy to kill." },
        },
        watch = {
          { "Hand of Thaurissan: random stun", "Hand of Thaurissan hits a random player for 240 fire damage and stuns them, first after 4 seconds and then every 5-10. A stunned healer cannot heal: keep everyone topped up." },
          { "Avatar of Flame: immune to spells", "25 seconds in and every 18 after he casts Avatar of Flame. While it lasts he is immune to all six magic schools (holy, fire, nature, frost, shadow, arcane) and his hits add Flames, 170-230 fire damage. Physical attacks still land." },
        },
        classes = { SHAMAN = {
          { "earth", "Stoneskin Totem", "nothing to tremor", "He casts no fear, charm or sleep, and cannot be feared, stunned or slowed himself. Stoneskin Totem for his melee." },
          { "water", "Fire Resistance Totem", "Hand of Thaurissan, Flames", "Fire Resistance is a Water totem. Hand of Thaurissan is 240 fire damage on a random player, and Avatar of Flame adds Flames (170-230 fire) to his hits." },
          { "air", "Grounding Totem", "eats a Hand of Thaurissan stun", "Hand of Thaurissan is aimed at one random player, so Grounding Totem takes the hit and the stun. The Princess's Mind Blast, Smite and Shadow Word: Pain are single-target too." },
        } },
        cite = { 17492, 15636, 15643, 15586, 15587, 15654, 10934, 15537, 8362, 13912 },
      },
    },
  },
}

for _, dungeon in ipairs(DUNGEONS) do D.Add(dungeon) end
