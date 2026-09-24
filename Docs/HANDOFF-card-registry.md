# Handoff: automatic card discovery for the SE (Card Registry)

> Written by the cloud session on 2026-09-24, from repo branch `claude/adoring-dijkstra-nvu17n`
> (HEAD `cd21742`). **Local session: this is your plan.** You have the game and the Toolkit; the cloud
> does not. Follow the phases in order, and stop at each ⛔ for an in-game check before going further.

---

## 0. The problem, in one paragraph

Until commit `1517840`, "this spell is a card" was answered by the cost `ArcanaHandCard` in `UseCosts`.
That cost came out (it blocked the collapse into the upcast variant), and **Stats/Khonsu** moved to the
marker `not HasPassive('ARCANA_IS_CARD', context.Source)` in `TargetConditions`, read by
`IsCardSpell()` via `HasStringInSpellConditions('ARCANA_IS_CARD')`. **The Lua never moved with it.**
The SE still decides what a card is by **name prefix** (`U.Category` + `C.DECK_CATEGORIES` in
`Server/Core/Pool.lua`) plus hand-maintained tables in `Server/Cards/CardDB.lua` (`containers`,
`parentOf`, `cost`). There are now two sources of truth that can drift apart. The goal: **the Lua reads
the same marker from the stats and discovers the cards on its own**, so a new card needs only the
marker in stats to enter the deck.

## 1. Divergences already found (offline, on the `mod/` mirror)

Comparing "has the marker" with "has a card prefix" (root entries only, no `_N`):

| Situation | Entries | What to do |
|---|---|---|
| **Card prefix without the marker** | `Shout_Arcana_Card_Spell_DEBUG_Fated` | add the marker (it's a card) |
| Card prefix without the marker | `Projectile_Arcana_Card_Ability_Fly_TheStarchild`, `..._Fly_Untethered` | `Card_Ability` isn't in the deck today (`DECK_CATEGORIES` = Card, Passive). Confirm that is intended; if so, leave them alone |
| Marker without a card prefix: `Arcana_Created_*` | Withdraw, MimicWithdraw, Mimic, MimicDistortion, MimicEtherealChains, MimicSigilofMalice, ZephyrStrike, FinalSpark_Recreate | expected: Created cards pay Threads, but **they don't go in the deck** |
| Marker without a card prefix: container children | the 6 `Target_Arcana_Created_Hemoplague_*` | expected: they belong to the parent card through `SpellContainerID` |
| Marker without a card prefix: clone | `Target/Shout/Projectile_Deceiver_Clone_Mirror*` (4) | these are the Deceiver clone's spells. **Decide:** should the clone pay Threads? If not, remove the marker. They never enter the deck either way (a summon isn't a `IsDeckUser`) |

### ⚠️ Probable syntax bug: marker after `;` (26 entries)

In 26 entries the marker was appended **after** a `;` that already closed the condition:

```
data "TargetConditions" "CanStand('') and not Self(); and not HasPassive('ARCANA_IS_CARD', context.Source)"
```

`HasStringInSpellConditions` will find the string (it's a text search), so `IsCardSpell()` may even
work, but a condition starting with `and` after the `;` is probably a **parse error**. Depending on how
the engine reacts, the spell can become **untargetable**, or the whole condition can be ignored. The
entries:

- Projectile: `Starcall`
- Shout: `DEBUG_Fleeting`, `DEBUG_Tangler`, `DEBUG_Unique`, `Passive_HollowImage`,
  `Passive_InstinctiveCharm`, `Passive_GaleDeflection`, `AstralFortitude`, `Ability_Untethered`,
  `EvasiveFlow`, `FlowState`, `StormFists`, `Thunderclap`, `WindWhispers`, `Indestructible`
- Target: `Distortion`, `EtherealChains`, `MirrorImage`, `Faceless_Copy_EX`, `AstralInfusion`,
  `LucentSingularity`, `SolarFlare`, `BloodReaper`, `Hemorrhage`, `RealmOfDeath`, `Transfusion`

(all `*_Arcana_Card_*`, except `Ability_Untethered`). The same 26 exist in `Editor/…/*.stats` (Shout 14,
Target 11, Projectile 1).

**Note:** Distortion and EtherealChains are **Deceiver** cards, and there's an open bug where "Cards in
Hand doesn't show on Deceiver". It's probably unrelated, but it's cheap to rule out after phase 1.

---

## Phase 1: fix the data (Stats), no Lua yet

1. Close the game and the Toolkit.
2. In the 26 entries, turn `X; and not HasPassive('ARCANA_IS_CARD', context.Source)` into
   `X and not HasPassive('ARCANA_IS_CARD', context.Source)`. If `X` has `or` at the top level, wrap it:
   `(X) and not HasPassive(...)`. **Both sides**: `Public/…/Spell_*.txt` and `Editor/…/*.stats`.
3. Add the marker to `Shout_Arcana_Card_Spell_DEBUG_Fated` (both sides).
4. Decide on the `Deceiver_Clone_Mirror*` (see the table above).
5. Regenerate variants and sort: `gen_upcast_variants.pl` then `sort_stats.pl`, so the `_N` inherit
   through `using` (the variants take their conditions from the base).
6. Create a **lint** in `Design/Rework/tools/check_cards.pl` (it gets mirrored to `tools/stats/`) that
   fails if:
   - an `*_Arcana_Card_Spell_*` / `*_Arcana_Card_Passive_*` root lacks the marker;
   - any condition contains `; and` / `; or`;
   - a marked root has an empty `Level` (the Toolkit has already blanked `Created_Withdraw` twice);
   - `Public` and `Editor` disagree about the marker set.
   Run it after every Toolkit publish, next to the SpellSlotsGroup UUID check.

⛔ **In game:** Distortion, EtherealChains, Starcall, Thunderclap and GaleDeflection still target/cast
normally out of combat, and in combat they cost Threads (i.e. `IsCardSpell()` still matches).

---

## Phase 2: `Server/Cards/Registry.lua`, the card list read from the stats

A new module, with `io` injectable like the others (`Sync`, `HandCards`, `CardDB`), so it can be
tested offline.

### What it does
Once per session (lazily on first use, and invalidated on `Ext.Events.ResetCompleted`, which is when
`reset` in the console reloads the stats), it walks every `SpellData` and builds:

```lua
R.byId[id] = {
    id      = id,
    root    = <RootSpellID if set, otherwise U.StripUpcast(id)>,
    marked  = <'ARCANA_IS_CARD' appears in TargetConditions (fallback: any *Conditions field)>,
    level   = tonumber(stat.Level),
    parent  = <SpellContainerID, or nil>,       -- container child
    kind    = "Card" | "Created" | "Child" | nil,
}
```

Classification rule (in this order):
1. not `marked` → `nil` (not a card; Util/vanilla keep going through the existing path);
2. `parent ~= nil` → `"Child"` (belongs to the parent card; the lighting comes from the parent);
3. `root` contains `Arcana_Created_` → `"Created"` (pays Threads, never enters the deck);
4. otherwise → `"Card"` (goes in the deck).

Public API: `R.IsCard(id)` (of the ROOT), `R.Kind(id)`, `R.RootOf(id)`, `R.ParentOf(id)`,
`R.ChildrenOf(root)`, `R.LevelOf(id)`, `R.All()`.

### SE APIs: **verify in the console before writing** (the cloud doesn't have the game)
```lua
_D(#Ext.Stats.GetStats("SpellData"))                           -- list of names? how many?
local s = Ext.Stats.Get("Target_Arcana_Card_Spell_Distortion_4")
_P(s.TargetConditions)  _P(s.RootSpellID)  _P(s.Level)          -- does `using` come back resolved?
_P(Ext.Stats.Get("Target_Arcana_Created_Hemoplague_Seizure").SpellContainerID)
_P(Ext.Stats.Get("Target_Arcana_Card_Spell_Hemoplague").ContainerSpells)
```
If `GetStats` doesn't exist or the field names differ, adjust `R.io` and write the correct names down
in `Docs/` (in the style of KHONSU.md: ✅ verified).

Cost: ~500 mod spells plus thousands of vanilla ones. Filter by `id:find("Arcana", 1, true) or
id:find("Deceiver_Clone", 1, true)` **only as an optimisation**. The decision is always the marker.
Build it once and cache it.

---

## Phase 3: switch the Lua over to the Registry

Surgical changes, each with a test:

| File | Today | After |
|---|---|---|
| `Server/Core/Pool.lua` `Po.Cards` | `C.DECK_CATEGORIES[U.Category(root)]` | `R.Kind(root) == "Card"` |
| `Server/Core/Pool.lua` `Po.Relevant` | `DECK_CATEGORIES[cat] or cat=="Created"` | `R.Kind(id) ~= nil` → relevant, with `root = R.RootOf(id)`; `Util`/`vanillaGranted` unchanged |
| `Server/Core/Sync.lua` | `D.containers` / `D.parentOf` by hand | `R.ChildrenOf` / `R.ParentOf`, with `CardDB` still able to add entries (Mimic isn't a stats container) |
| `Server/Cards/CardDB.lua` | `cost` in every entry | `cost` becomes the offline tests' fallback only (`D.CostOf` already reads `Level`); `D.cards` stays **only for behaviour**: keywords, conjures, reaction, tangle, unplayable |
| `Server/Core/Const.lua` | `C.DECK_CATEGORIES`, `C.RES_HAND_CARD` comment | `DECK_CATEGORIES` stays only for `U.Category` (sub-type Spell vs Passive, used by Reactions/Overhead); fix the comment "every card costs 1" |

Keep `U.Category` for the **sub-type**. It stops deciding **membership**.

**Transition safety:** in the first version, `Po.Cards` computes both (marker and prefix) and **logs
the difference** once per session (`[ArcanaDeck] registry: prefix-only X, marker-only Y`). Once the in-game
log comes back clean, remove the prefix path.

### Offline tests (target: 106 → ~115)
- `RegistryTest.lua` with fake stats: a marked root is Card; a `_3` variant points to the root; a child
  with `SpellContainerID` is Child; `Arcana_Created_` is Created; unmarked is nil; `; and` isn't
  needed to recognise the marker.
- `PoolTest`: an unmarked card with a card prefix **does not** enter the deck; a marked card with an
  arbitrary name **does**.
- `SyncTest`: a Hemoplague child lights up when the parent is in hand, without `D.containers`.
- Register it in `Tests/All.lua`.

```bash
lua tools/run_tests.lua "$BG3_DATA/Mods/AspectClass_<uuid>/ScriptExtender/Lua"
```

---

## Phase 4: console command and verification

New command `!arcanaregistry`: prints how many Card/Created/Child entries, the roots per subclass, and the
prefix × marker divergences. Add it to `Server/Debug/Commands.lua` and to the README's command list.

⛔ **In game, one character per subclass (Deceiver, Starchild, Unbound, Eternal):**
1. `!arcanaregistry` → no divergences; ~70 marked roots in total (the number the stats commit
   `1517840` reported).
2. `!arcanapool` / `!arcanadeck` → the same cards as before, including those that only exist as `_N`.
3. Start a fight: opening hand of 4, cards out of hand locked, cards in hand lit, Threads charged by
   level, Hemoplague offers the 6 diseases.
4. **Deceiver:** does the Cards in Hand resource show? If not, diagnose it apart from the registry:
   `_D(Ext.Entity.Get(GetHostCharacter()).ActionResources.Resources)` and look for `ArcanaHandCard`.
   Note: the only grant is `ActionResource(ArcanaHandCard,22,0)` in the `Arcana` progression, level 1
   (a max of 22, while `C.HAND_MAX` = 10). Check whether the Deceiver test character was created before
   that grant existed, and test it with a freshly created character.

---

## Rules that still apply

- **Never write to the mod with the game or the Toolkit open.** Reading is always fine.
- **Every stats change is two files** (`Public/…/*.txt` + `Editor/…/*.stats`).
- After every Toolkit publish, check: the `SpellSlotsGroup` UUID = `03b17647-161a-42e1-9660-5ba517e80ad2`,
  no `Level` blanked, and now also `check_cards.pl`.
- When you're done: `tools/sync-mod.sh`, run the tests, commit (one commit per phase), push to the
  branch.

## Definition of done
- [ ] 0 entries with `; and` / `; or` in conditions; lint passes
- [ ] `Registry.lua` + tests; suite green
- [ ] `Po.Cards` / `Po.Relevant` / `Sync` decide by marker; `D.containers` derived from the stats
- [ ] `!arcanaregistry` with no divergences in all 4 subclasses
- [ ] Deceiver bug diagnosed (fixed, or its cause written down)
