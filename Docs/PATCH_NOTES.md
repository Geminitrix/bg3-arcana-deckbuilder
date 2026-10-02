<!--
  UNRELEASED PATCH NOTES -- working copy, keep adding as things change.

  Format (keep it consistent):
    # Subclass                      one block per subclass, plus General / Aspect Awakening / Bug Fixes
    ## Ability:                     the card, passive or reaction, as the player sees its name
    ### Spell Level N: Stat old ⇒ new; Other Stat value
                                    "⇒" only when the value changed; unchanged values are written plain
    *Italic line under an ability*  the "why", in one or two short sentences (League-style context)
    **NEW** / **REMOVED** / **REWORKED** tags in front of the ability name when it applies

  "Old" values for spells that used to scale with character level are what the old scaling gave in the
  character levels that use each spell slot level (1-2 = Spell Level 1, 3-4 = 2, 5-6 = 3, 7-8 = 4,
  9-10 = 5, 11+ = 6). "1d6–2d6" means it changed inside that range.

  Before release:
    - [ ] Levels 13 / 15 / 17 / 19 no longer grant the EX abilities -- decide what goes there, then update "EX Abilities".
    - [ ] Unbound still scales by character level in: Gale Burst tooltip, Leap of Faith, Flowing Strikes.
    - [ ] Eternal Aspect Awakening has not been tested in game yet.
    - [ ] Fill in the patch number and date.
-->

# Arcana — Patch X.Y

*Release date: TBD*

## Patch Highlights

- **Aspect Awakening:** each subclass now awakens its Arcana in the middle of a fight. Meet the objective and you gain your Aspect's bonuses until combat ends, plus a powerful Aspect card. It grows in three tiers, at levels 3, 7 and 12.
- **Upcasting, the Baldur's Gate way:** Arcane spells now get stronger with the spell slot you cast them with, just like the base game's spells, instead of with your character level.
- **Reactions rework:** reaction cards now work on charges with a per-round limit. Gale Deflection can be used up to three times a round.
- **The EX abilities are gone.** Their power now lives in the Aspect Awakening and in upcasting.
- **Unbound:** Zephyr Strike is everywhere, Wind Whispers strikes back on its own, and a large pass on durations and upcast values.

---

# General

## **NEW** Upcasting
*Arcane spells used to scale with your character level. They now scale with the level of the spell slot you spend, as every spell in the base game does. Each spell shows its values for every spell level, and the card always uses the highest slot you have.*

- Damage and healing grow by one die for each spell level above the spell's own level, as with Magic Missile or Burning Hands.
- Effects that come from a condition (Ethereal Chains, Blood Offering, Storm Fists, Flow State) have one version per spell level. Casting a higher-level version replaces a lower one.
- Spell slots stop growing at level 6 (character level 11). Spells that kept growing up to level 20 with the old scaling now stop at their Spell Level 6 value. The exact values are listed under each subclass.
- Cantrips (Malicious Whispers, Heartbreak), Mirror Image copies and the Sigil mark still scale with character level, as cantrips do in the base game.

## **REWORKED** Reaction Cards
*Reaction cards gave one use each. With extra reactions you still couldn't use them more than once.*

- Every reaction card now has a **per-round limit**, and its charges stack up to that limit:
  - **Gale Deflection:** up to 3 uses per round.
  - **Hollow Image:** once per round.
  - **Instinctive Charm:** once per round.
- Each card you play grants one use. Every use also costs your reaction.
- The "Ready:" cards now say what they always did: the reaction lasts **until combat ends**. "Until your next Long Rest" was never true, because the cards only work in combat.
- **PC edition (deck building):** reaction cards are no longer cast. **Holding the card in your hand is the charge.** When the trigger happens, you are asked whether to use it, and using it discards one copy. Gale Deflection is no longer Unique, so you can hold up to three copies.

## **REMOVED** EX Abilities
*The EX versions are retired. Their role (getting stronger at high level) now belongs to the Aspect Awakening and to upcasting.*

- **Deceiver:** Faceless Copy EX (Level 13), Hostile Takeover EX (Level 15), Hollow Image: Final Veil (Level 17), Mirror Image EX (Level 19)
- **Starchild:** Starcall EX (Level 13), Star Radiance EX (Level 15), Astral Fortitude EX (Level 17), Lunar Aegis EX (Level 19)
- **Unbound:** Evasive Flow EX (Level 13), Flow State EX (Level 15), Storm Fists EX (Level 17), Gale Deflection: Tempest Riposte (Level 19)
- **Eternal:** Transfusion EX (Level 13), Death's Grasp EX (Level 15), Unbroken EX and Hemoplague EX (Level 17), Realm of Death EX (Level 19)

## Awakening Progress
- Each subclass shows its progress towards awakening as a condition called **Awakening Progress**.

---

# **NEW** Aspect Awakening

*Inspired by champion level-ups. Each subclass has an in-combat objective. Meet it and your Aspect awakens until the fight ends. The bonuses are cumulative: Tier I at level 3, Tier II at level 7, Tier III at level 12. The old level 20 capstones (0 - The Fool, 3 - The Empress, 17 - The Star, 13 - Death) are now part of Tier III.*

- Every subclass gets an **Awakening** passive at level 3 that explains its objective and its progression.
- While awakened, you can play your **Aspect card**. It costs nothing and can be played once per combat.

## 0 - The Fool (Unbound) — Aspect of Curiosity
**Objective:** strike different enemies with attacks within a single round.
- **Level 3:** 3 enemies. **Level 7:** 4 enemies. **Level 12:** 5 enemies.
- If fewer enemies are standing when your turn begins, hits on any enemy count instead.

### Tier I — Wanderlust (Level 3)
Your movement speed increases by 3m. You can move without provoking Opportunity Attacks, and your unarmed attacks deal an additional 1d4 Thunder damage.
### Tier II — Restless Wind (Level 7)
You have Advantage on Dexterity Saving Throws and an additional reaction. Once per turn, Zephyr Strike doesn't cost a bonus action.
### Tier III — Aspect of Curiosity (Level 12)
Your Dexterity increases by 3 and you have another additional reaction. **Fool's Luck:** once per round, the first attack against you misses.
### Aspect Card — Leap of Faith
Dash through the fray, striking every creature in your path with an unarmed attack that also deals Thunder damage. Afterwards, you can make a Zephyr Strike as a bonus action.

*While awakened, the Fool shows a condition for its current tier (Awakened I / II / III) that lists every active bonus. The bonuses only work without armour or a shield.*

## 3 - The Empress (Deceiver) — Aspect of Love
**Objective:** detonate 3 of your Sigils during a fight.

### Tier I — Obsession (Level 3)
Creatures marked with your Sigil have Disadvantage on Attack Rolls against you.
### Tier II — Devotion (Level 7)
Once per turn, when one of your Sigils detonates, the nearest unmarked enemy within 6m of it is marked with a Sigil.
### Tier III — Aspect of Love (Level 12)
Your Charisma increases by 3 and your Arcane spells add your Charisma Modifier to their damage. **Beloved:** once per round, when an enemy attacks you, it must succeed a Wisdom Saving Throw or its attack is stopped and it is Charmed for 1 turn.
### Aspect Card — Heartbreak
Break every heart that bears your Sigil. Each marked creature takes Psychic damage, and the marks detonate at once. Those still standing are Charmed for 1 turn.

## 17 - The Star (Starchild) — Aspect of Hope
**Objective:** heal your allies for a total of 5 × your level in hit points during a fight. Healing beyond an ally's maximum hit points doesn't count. Progress shows as a percentage.

### Tier I — Beacon (Level 3)
Allies you heal or target with an Arcane spell become **Moonlit**. Their next attack that hits deals an additional 1d4 Cold damage and reduces the target's movement speed.
### Tier II — Sunrise (Level 7)
Moonlit deals 2d4 Cold damage instead. Allies also become **Sunlit**: their next attack that hits deals an additional 1d4 Fire damage and sets the target Burning.
### Tier III — Aspect of Hope (Level 12)
Your Wisdom increases by 3 and Sunlit deals 2d4 Fire damage instead. Allies also gain **Eclipse**, becoming Resistant to Cold and Fire damage. **Undying Hope:** the first ally who would be downed during the fight instead regains half their hit points.
### Aspect Card — Wish Upon a Star
Grant your allies within 18m Advantage on their next Attack Roll.

## 13 - Death (Eternal) — Aspect of Sorrow
**Objective:** lose hit points equal to 30% of your hit point maximum during a fight. Healing doesn't undo the loss. Progress shows as a percentage.

### Tier I — Sorrow (Level 3)
You emanate **Darkness Rise**. Your movement speed increases by 50%. Each turn, enemies within the aura take Necrotic damage equal to 10% of your maximum hit points, and their movement speed is halved.
*Darkness Rise used to be a card. It is now the Eternal's Tier I, and Blood Offering takes its place in the spell list.*
### Tier II — Mourning (Level 7)
The first time you would drop to 0 hit points, you drop to 1 instead. An isolated enemy within 3m of you has Disadvantage on Attack Rolls against you.
### Tier III — Aspect of Sorrow (Level 12)
Your Constitution increases by 3. Once per turn, when a hostile creature dies within 9m of you, you gain an additional action.
### Aspect Card — The Final Toll
Turn your suffering on a foe. It takes Necrotic damage equal to the hit points you have lost this combat, up to half your hit point maximum. A creature killed this way rises as a zombie.

---

# Unbound

## Gale Burst:
### Spell Level 1: Thunder Damage 1d8 ⇒ 1d10
### Spell Level 2: Thunder Damage 1d8 ⇒ 1d10
### Spell Level 3: Thunder Damage 2d8 ⇒ 2d10
### Spell Level 4: Thunder Damage 2d8 ⇒ 2d10
### Spell Level 5: Thunder Damage 3d8 ⇒ 3d10
### Spell Level 6: Thunder Damage 3d8–5d8 ⇒ 3d10

## Flow State:
### Spell Level 2: Turn Duration 10 ⇒ 2; Additional Bonus Action 1
### Spell Level 3: Turn Duration 10 ⇒ 3; Additional Bonus Action 1
### Spell Level 4: Turn Duration 10 ⇒ 4; Additional Bonus Action 1
### Spell Level 5: Turn Duration 10 ⇒ 5; Additional Bonus Action 1 ⇒ 2
### Spell Level 6: Turn Duration 10 ⇒ 6; Additional Bonus Action 1 ⇒ 2
- Can only be used in combat, and ends when combat ends.
- No longer limited to once per combat.
- The tooltip showed temporary hit points equal to 3 × your Arcana level. You always gained 2 × your Arcana level, and the tooltip now says so.

## Evasive Flow:
### Spell Level 3: Turn Duration 1
### Spell Level 4: Turn Duration 1
### Spell Level 5: Turn Duration 1 ⇒ 2
### Spell Level 6: Turn Duration 1 ⇒ 3
- Can only be used in combat, and ends when combat ends.

## Storm Fists:
### Spell Level 4: Turn Duration 10 ⇒ 3; Bonus Thunder Damage 1d4
### Spell Level 5: Turn Duration 10 ⇒ 4; Bonus Thunder Damage 1d4 ⇒ 1d6
### Spell Level 6: Turn Duration 10 ⇒ 5; Bonus Thunder Damage 1d6–1d8 ⇒ 1d8
- Bonus Thunder Damage now adds your **Dexterity** Modifier instead of your Wisdom Modifier.
- No longer requires Concentration.
- Can only be used in combat, and ends when combat ends.

## Thunderclap:
### Spell Level 4: Turn Duration 10 ⇒ 3
### Spell Level 5: Turn Duration 10 ⇒ 4
### Spell Level 6: Turn Duration 10 ⇒ 5
- Can only be used in combat, and ends when combat ends.

## **REWORKED** Wind Whispers:
*The counterattack used to be a separate passive that rarely triggered on enemy turns.*
- Wind Whispers now lasts until the start of your next turn, so it covers every enemy turn in between.
- **NEW — Wind Riposte:** while Wind Whispers is active, when an enemy's melee attack misses you, you automatically use your reaction to strike back with an unarmed attack.
- Can only be used in combat, and ends when combat ends.

## Flowing Strikes: Zephyr / Zephyr Strike:
*Zephyr Strike is the Unbound's signature follow-up. It now follows everything the Unbound does.*
- Zephyr Strike is now granted after an unarmed attack, **any Arcane spell** or True Strike. Before, only unarmed attacks granted it.
- Zephyr Strike no longer costs a spell slot, only a bonus action. In the PC edition it costs 1 Thread.
- Every Unbound card that grants Zephyr Strike now says so: "Afterwards, you can make a Zephyr Strike as a bonus action."

## Gale Deflection:
- Can be used up to **3 times per round**: each card played stores one use, up to 3. See *Reaction Cards*.

## Empty State:
- No longer spends your reaction every time you take damage. It still halves the damage you take from attacks. Your reactions are now free for Gale Deflection and Wind Riposte.

## Untethered:
- Can still be cast outside combat, but you lose its flight when combat starts and when it ends.

---

# Deceiver

## Sigil of Malice:
### Spell Level 1: Force Damage 1d6
### Spell Level 2: Force Damage 2d6
### Spell Level 3: Force Damage 3d6
### Spell Level 4: Force Damage 4d6
### Spell Level 5: Force Damage 5d6
### Spell Level 6: Force Damage 6d6–10d6 ⇒ 6d6

## Mimic: Sigil of Malice:
### Spell Level 1: Force Damage 4d6
### Spell Level 2: Force Damage 5d6
### Spell Level 3: Force Damage 6d6
### Spell Level 4: Force Damage 7d6
### Spell Level 5: Force Damage 8d6
### Spell Level 6: Force Damage 9d6–13d6 ⇒ 9d6

## Ethereal Chains:
*Damage is dealt twice: when the chains bind and at the end of the target's turn.*
### Spell Level 2: Force Damage 1d6–2d6 ⇒ 1d6
### Spell Level 3: Force Damage 2d6
### Spell Level 4: Force Damage 3d6
### Spell Level 5: Force Damage 3d6–4d6 ⇒ 4d6
### Spell Level 6: Force Damage 4d6–7d6 ⇒ 5d6

## Mimic: Ethereal Chains:
### Spell Level 1: Force Damage 3d6
### Spell Level 2: Force Damage 3d6–4d6 ⇒ 4d6
### Spell Level 3: Force Damage 4d6 ⇒ 5d6
### Spell Level 4: Force Damage 5d6 ⇒ 6d6
### Spell Level 5: Force Damage 5d6–6d6 ⇒ 7d6
### Spell Level 6: Force Damage 6d6–9d6 ⇒ 8d6

## Distortion:
### Spell Level 3: Force Damage 3d8
### Spell Level 4: Force Damage 4d8
### Spell Level 5: Force Damage 5d8
### Spell Level 6: Force Damage 6d8–10d8 ⇒ 6d8

## Mimic: Distortion:
### Spell Level 2: Force Damage 4d8
### Spell Level 3: Force Damage 5d8
### Spell Level 4: Force Damage 6d8
### Spell Level 5: Force Damage 7d8
### Spell Level 6: Force Damage 8d8–12d8 ⇒ 8d8

## Hollow Image / Instinctive Charm:
- Once per round. Each card played grants one use. See *Reaction Cards*.

## **NEW** Friends: Faux Amis (Level 13)
Gain Advantage on Charisma Checks against a non-hostile creature. It doesn't change in higher difficulty modes, the target won't know you've enchanted them, and it doesn't require Concentration.

---

# Starchild

## Starcall:
### Spell Level 1: Radiant Damage 1d6
### Spell Level 2: Radiant Damage 2d6
### Spell Level 3: Radiant Damage 3d6
### Spell Level 4: Radiant Damage 4d6
### Spell Level 5: Radiant Damage 5d6
### Spell Level 6: Radiant Damage 6d6–10d6 ⇒ 6d6

## Astral Infusion:
### Spell Level 1: Healing 1d10
### Spell Level 2: Healing 2d10
### Spell Level 3: Healing 3d10
### Spell Level 4: Healing 4d10
### Spell Level 5: Healing 5d10
### Spell Level 6: Healing 6d10–10d10 ⇒ 6d10

## Wish:
### Spell Level 4: Healing 4d4
### Spell Level 5: Healing 5d4
### Spell Level 6: Healing 6d4–10d6 ⇒ 6d4

## Starbreath:
*Revives a fallen ally with a percentage of their maximum hit points.*
### Spell Level 3: Revive Health 5%–10% ⇒ 10%
### Spell Level 4: Revive Health 20%–30% ⇒ 30%
### Spell Level 5: Revive Health 40%–60% ⇒ 60%
### Spell Level 6: Revive Health 80%–100% ⇒ 100%

## Solar Flare:
### Spell Level 6: Fire Damage 8d6–10d6 ⇒ 8d6

## Final Spark:
### Spell Level 6: Radiant Damage 6d6–8d6 ⇒ 6d6

---

# Eternal

## Death's Grasp:
### Spell Level 2: Necrotic Damage 1d8
### Spell Level 3: Necrotic Damage 2d8
### Spell Level 4: Necrotic Damage 2d8 ⇒ 3d8
### Spell Level 5: Necrotic Damage 3d8 ⇒ 4d8
### Spell Level 6: Necrotic Damage 3d8–5d8 ⇒ 5d8

## **NEW** Blood Offering (Level 7):
*Takes Darkness Rise's place in the spell list. Darkness Rise is now the Eternal's Tier I Aspect bonus.*
Open your veins to the dark. Lose a tenth of your hit point maximum, and your Arcane spells deal additional Necrotic damage until the end of your turn.
### Spell Level 3: Bonus Necrotic Damage 2d8
### Spell Level 4: Bonus Necrotic Damage 2d8 ⇒ 3d8
### Spell Level 5: Bonus Necrotic Damage 3d8 ⇒ 4d8
### Spell Level 6: Bonus Necrotic Damage 3d8–5d8 ⇒ 5d8

## Obliterate:
### Spell Level 1: Bonus Necrotic Damage 1d8
### Spell Level 2: Bonus Necrotic Damage 1d8–2d8 ⇒ 2d8
### Spell Level 3: Bonus Necrotic Damage 2d8 ⇒ 3d8
### Spell Level 4: Bonus Necrotic Damage 3d8 ⇒ 4d8
### Spell Level 5: Bonus Necrotic Damage 3d8–4d8 ⇒ 5d8
### Spell Level 6: Bonus Necrotic Damage 4d8–7d8 ⇒ 6d8

## Transfusion:
### Spell Level 1: Necrotic Damage 1d6
### Spell Level 2: Necrotic Damage 2d6
### Spell Level 3: Necrotic Damage 3d6
### Spell Level 4: Necrotic Damage 4d6
### Spell Level 5: Necrotic Damage 5d6
### Spell Level 6: Necrotic Damage 6d6–10d6 ⇒ 6d6

## **NEW** Howl of the Dead (Level 13):
Let out a bone-chilling howl that Numbs all nearby creatures.

---

# Bug Fixes

- Ethereal Chains: the chains' visual effect no longer vanishes when the target is bound by Mimic: Ethereal Chains.
- Flow State: the tooltip now shows the temporary hit points you actually gain.
