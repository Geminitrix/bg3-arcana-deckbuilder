# The Arcana — a deck-building class for Baldur's Gate 3

A full custom class for Baldur's Gate 3 whose combat runs on a **deck of cards**: you build a deck out
of camp, draw a hand when a fight starts, spend a per-turn energy to play cards, and discard what you
do not use. Baldur's Gate 3 has no card system and no concept of a hand — every part of this is built
out of engine primitives that were meant for other things.

We know of no other BG3 mod that does this, so most of what is written down here is a record of what
the engine actually allows, found by trying it.

> **Status: in development.** The class itself ships and is playable. The deck layer is written, has
> 99 offline tests, and is being verified in game. See [Where it stands](#where-it-stands).

---

## The idea

The class is **The Arcana**, a weaver of Mystra's Weave, with four subclasses (Deceiver, Starchild,
Unbound, Eternal). Its spells are **cards**.

| | Out of combat | In combat |
|---|---|---|
| What you spend | **Woven Spell Slots** — leveled, refill on a short rest, Warlock-style | **Threads** — flat, refill every turn, do not carry over |
| What you can cast | anything you know | only what is **in your hand** |
| How much it costs | one slot of the card's level | Threads equal to the card's level |

A fight starts with an opening hand of 4, you draw 1 a turn, the hand holds 10, and Threads ramp with
character level (1/turn early, up to 6 late) with 2 carried over at most.

Design vocabulary, roughly borrowed from Legends of Runeterra: cards are **Created**, **Fleeting**,
**Fated**, **Attuned**; played cards go to the **Frayed** pile and exiled ones to **Unravel**; the
opening hand can be traded once with **Reweave**.

---

## Why it is unusual, technically

The engine gives no way to add, remove or hide a spell per turn without wrecking the spellbook. So the
deck never touches the spellbook at all. Every card the character knows is always there, in the same
place on the hotbar, and the deck only changes **how each one looks and what it costs**:

- **A card not in your hand is locked by making it unpayable.** It gains a cost in `ArcanaNotInHand`,
  an action resource nobody is ever granted. The engine greys it out and refuses every route to
  casting it — hotbar, character sheet, keyboard shortcut — with a tooltip that says why.
- **The hand is an action resource.** `ArcanaHandCard` sits next to the spell slots and holds how many
  cards you are holding. Every card costs 1 of it, so the engine itself enforces an empty hand, the
  count is on screen, and "is this a card?" becomes a question about cost rather than a list of names
  someone has to maintain.
- **The slot cost turns into Threads through spell variants.** A status applied for the duration of a
  fight carries one `UnlockSpellVariant` per spell level that zeroes the card's slot cost and adds the
  Thread cost. The console edition never gets that status, so the same card data feeds both editions.
- **Choices reuse the game's own spell containers.** Hemoplague offering six diseases is a vanilla
  `SpellContainer`, not custom UI — so it works without the Script Extender, on console too.
- **Reactions are gated by an exclusive resource.** Out of combat and on console the character simply
  has it and the reaction behaves normally; in a fight it is zeroed, and a card gives it back.

---

## Two editions, one set of data

The mod ships twice, which shapes every decision:

- **Nexus / PC** — uses [Norbyte's Script Extender](https://github.com/Norbyte/bg3se). Lua owns the
  deck: the pool, the hand, the piles, which card is locked or lit.
- **Console** — no Script Extender at all. No deck, no hand: the same cards are cast normally with
  Woven Spell Slots.

So **gameplay effects live in Stats, Osiris and Khonsu**, which both editions share, and Lua only ever
manages the deck. A rule that only exists in Lua is a rule console players do not get.

---

## Layout

This repository is **the deck system, not the whole mod**. The class's own content — summon
templates, Osiris goals, localisation, icons, VFX — is not part of how the deck works and is kept out.

```
mod/                              mirror of the source (see tools/sync-mod.sh)
  ScriptExtender/Lua/             the deck, in Lua — PC edition only
    Server/Core/                  pool, hand, piles, state, the lock/glow boosts
    Server/Economy/               Threads, the hand resource, reactions, the combat status
    Server/Cards/CardDB.lua       per-card data: cost, keywords, containers, what it creates
    Server/Keywords/              one file per keyword
    Tests/                        99 tests that run without the game
  Scripts/thoth/                  Khonsu conditions the boosts ask questions with
  Public/Stats/                   spell costs, and the status that converts them
  Public/ActionResource*/         Threads, the hand, the class's own spell-slot group
  Public/{Lists,Progressions}/    where cards and resources are granted
  Editor/…                        the Toolkit's copy of the same data — must match Public/
Docs/                             OSIRIS.md and KHONSU.md — what the engine actually does
tools/sync-mod.sh                 copies the source out of the game directory into mod/
tools/run_tests.lua               the offline test runner
```

**The game directory is authoritative.** The mod is installed loose, so the game and the Toolkit read
and write the real files in `…/Baldur's Gate 3/Data/`; `mod/` here is a one-way mirror for history.
Never edit `mod/` expecting the game to notice.

---

## Working on it

```bash
# refresh the mirror after changing anything in the game directory
tools/sync-mod.sh

# run the deck's offline test suite (Lua 5.4, no game needed)
lua tools/run_tests.lua "$BG3_DATA/Mods/AspectClass_<uuid>/ScriptExtender/Lua"
```

In game, with the Script Extender console: `!arcanatest` runs the same suite, `!arcanahand` prints the
hand with costs, `!arcanapool` the tracked spells, `!arcanathreads` the energy, `!arcanadeck` what is
left to draw.

Two rules worth repeating:

1. **Never write to mod files while the game or the Toolkit is open.** Reading is always fine.
2. **Every stats change is two files** — the generated `Public/…/*.txt` the game reads and the
   `Editor/…/*.stats` the Toolkit owns. They must agree, or the next Toolkit save silently reverts you.

---

## Where it stands

Working and verified in game: Threads and their per-turn refill, the reserve carried between turns,
the opening hand, Reweave.

Written, tested offline, not yet confirmed in game: the slot-to-Thread conversion, the hand resource,
the reaction gates, the Hemoplague container.

Open questions, the design specs and the in-game test scripts live in the project folder alongside
this repository and are not published here.

---

## Credits and licence

Built by **Lumox**. The Arcana's art, text and design are the author's. The mod depends on
[Norbyte's BG3 Script Extender](https://github.com/Norbyte/bg3se) for the PC edition and on
[LSLib](https://github.com/Norbyte/lslib) for converting the game's file formats.

Baldur's Gate 3 is © Larian Studios. This is an unofficial fan modification, not affiliated with or
endorsed by Larian.
