# Khonsu (`.khn`) and Stats conditions — reference

Working reference for condition logic in the **Arcana** mod. Read this before touching any `.khn` file,
or any Stats field that evaluates a condition (`Conditions`, `BoostConditions`, `EnabledConditions`,
`RequirementConditions`, `TargetConditions`, `DescriptionParams`, `UnlockSpellVariant`…).

**Confidence markers:** ✅ verified against BG3 files · ⚠️ convention or strong inference ·
❗ hard-won project finding, learned through repeated crashes · ❓ unverified.

---

## 1. Two grammars, constantly confused

This is the single biggest source of wasted time. There are **two different condition languages**, and
they use opposite operators.

|  | **Stats condition mini-language** | **Khonsu (`.khn`)** |
|---|---|---|
| Lives in | a `data "Conditions" "…"` field inside a `.txt` stat entry | a `.khn` file |
| Boolean operators | `and` `or` `not` | `&` `\|` `~` |
| Grammar | simple expression, no variables, no control flow | full Lua: locals, `if/elseif`, `math.*`, string ops |
| Can call | native condition functions **and Khonsu functions by name** | native functions and other Khonsu functions |
| Returns | implicitly boolean | `ConditionResult(...)` or a plain number |

```
# Stats field — uses `and`, calls a Khonsu function by name
data "Conditions" "Combat() and IsArcanaSpell(context.Source);"
```

```lua
-- .khn file — uses & and ~
function IsArcanaAttackSpell()
    return IsArcanaSpell() & HasStringInSpellRoll('Attack')
end
```

Writing `and` inside a `.khn` boolean chain, or `&` inside a Stats field, silently misbehaves or fails
to parse. Check which file you're in before typing the operator.

> Plain Lua `and` / `or` **is** correct inside a `.khn` file when you're combining raw Lua values
> (`entity.IsValid and entity == entity2`). Use `&` / `\|` / `~` only when combining
> **ConditionResult** values. ✅ Vanilla does both, in the same function.

---

## 2. Where the files live and how to reload

- **This mod:** `Data\Mods\AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7\Scripts\thoth\helpers\*.khn`
- **Vanilla library:** packed at `Mods/Shared/Scripts/thoth/helpers/CommonConditions.khn` inside
  `Shared.pak` — **326 functions**, ~2 120 lines. Plus `CommonConditionsDev.khn` for dev-flagged extras. ✅
  Extract with `Divine.exe` (recipe in `CLAUDE.md` §4) and keep a copy in scratch to grep.

**There is no script editor in the Toolkit.** Author `.khn` externally as plain text (Lua syntax
highlighting helps), then **Main editor → Tools → Reload Stats** (or *Stats editor → File → Reload Stats
Files*). ✅

**All `.khn` files in `helpers/` share one global Lua environment.** ✅ A function in one file can call a
function defined in another with no import. This is confirmed working in this mod — use it to split a
long expression into several small, readable files.

`local __util = require 'larian.util'` is the only `require` vanilla uses. ✅

---

## 3. Function shape

```lua
function SizeEqualOrGreater(size, entity)
    entity = entity or context.Target          -- default-argument idiom
    return ConditionResult(entity.Size ~= Size.None and entity.Size.value >= size.value)
end
```

Conventions worth copying from vanilla: ✅

- **Default arguments** via `entity = entity or context.Target`. Vanilla defaults to `context.Target`
  for target-facing checks and `context.Source` for caster-facing ones, and comments the choice
  (`-- Default to Target, like cpp functions`). This mod's `IsArcanaSpell(entity)` follows it.
- **Guard against invalid entities** with `entity.IsValid` before reading properties.
- **`try … catch e then … end`** exists in Khonsu (it is *not* standard Lua). Vanilla uses it around
  `CalculateSpellDC`, which can throw. ✅ Use it when calling something that may fail on an entity that
  isn't fully initialised.

### Return shapes

| You want | Return |
|---|---|
| A condition (`Conditions`, `BoostConditions`, `EnabledConditions`, …) | `ConditionResult(...)`, or a `&`/`\|`/`~` combination of other condition results |
| A number for a tooltip (`DescriptionParams`) | a plain Lua number |
| A DC or computed value used by another function | a plain Lua number |

```lua
ConditionResult(boolean)
ConditionResult(boolean, errorsWhenFalse, errorsWhenTrue)
ConditionResult(boolean, errorsWhenFalse, errorsWhenTrue, chance)
```

✅ The error tables are what the UI shows as a greyed-out reason. Example from vanilla:

```lua
return ConditionResult(entity.IsValid and entity == entity2,
                       {ConditionError("IsNotSelf")}, {ConditionError("IsSelf")})
```

Errors can carry data:
`ConditionError("DistanceGreaterThan_True", {ConditionErrorData.MakeFromNumber(value, EErrorDataType.Distance)})`

**Custom error keys must be declared** in `Public/AspectClass_…/ErrorDescriptions/ConditionErrors.lsx`
with an `Identifier` and a localised `DisplayName`. This mod declares exactly one today: ✅

| Identifier | Text |
|---|---|
| `CE_ActionResource_Interrupt_ArcaneEssence_False` | *"Must take a Long Rest."* |

---

## 4. The `context` object

Everything Khonsu knows about the current evaluation. Field availability depends on **why** the
condition is being evaluated — reading `context.HitDescription` from a `BoostConditions` evaluation that
isn't a hit will not work.

Verified in use across vanilla `CommonConditions.khn`, roughly by frequency: ✅

| Field | Meaning |
|---|---|
| `context.Source` | The caster / owner / attacker |
| `context.Target` | The target being evaluated |
| `context.Observer` | The reacting entity, in interrupts |
| `context.HitDescription` | The hit being resolved (see below) |
| `context.AttackDescription` | The attack as a whole |
| `context.InterruptedRoll` | The roll an interrupt is reacting to |
| `context.SpellModificationDescription` | Used by metamagic-style spell variants |
| `context.SourcePosition` / `context.TargetPosition` | World positions |
| `context.Passive` | The passive currently being evaluated |
| `context.StatusEvent` | The status event that triggered evaluation |
| `context.PreferredCastingAbility` | The ability the current cast uses |
| `context.CheckedAbility` / `context.CheckedSkill` | For ability/skill check conditions |
| `context.AttackWeapon` | The weapon used |

### `context.HitDescription` ✅

```
AttackAbility      AttackType         DeathType          FirstAttack       LastAttack
HitWith            InflicterObject    IsCriticalHit      IsCriticalMiss    IsReaction
IsHitpointsDamaged SaveAbility        SpellLevel         SpellPowerLevel   SpellSchool
ThrownObject       TotalDamageDone    TotalHealDone
GetDamageDoneForType(...)             GetLastConditionRoll(...)
```

### `context.InterruptedRoll` ✅

`AdvantageState` · `Difficulty` · `NaturalRoll` · `RollCritical` · `RollType` · `Total`

### `context.AttackDescription` ✅

`AttackType` · `InitialHPPercentage` · `TotalDamageDone` · `GetDamageDoneForType(...)`

### `context.SpellModificationDescription` ✅

`NumberOfTargets` · `TargetRadius`

---

## 5. Entity properties

Read off `context.Source`, `context.Target` or an `entity` parameter. Confirmed in vanilla use: ✅

| Property | Notes |
|---|---|
| `.IsValid` | Always check before reading anything else |
| `.HP` · `.MaxHP` · `.TemporaryHP` | Integers |
| `.HPPercentage` · `.HPPercentageWithoutTemporaryHP` | The second is what most vanilla checks use |
| `.Strength` `.Dexterity` `.Constitution` `.Intelligence` `.Wisdom` `.Charisma` | Raw scores — wrap in `GetModifier()` for the modifier |
| `.ProficiencyBonus` · `.Level` | |
| `.Size` | Compare via `.value`, and guard `~= Size.None` |
| `.Weight` · `.ActionTypes` | |
| `.GetClassLevel(class)` | **The class-level accessor** — Osiris has no equivalent |
| `.GetPassiveSkill(...)` · `.GetDamageDoneForType(...)` | |
| `.HasAllResistances(...)` · `.HasAnyResistances(...)` | |

`GetModifier(value)` is the vanilla helper: `math.floor((value - 10) / 2)`. ✅

---

## 6. ❗ The BoostConditions crash — read this before writing any passive

**Custom Khonsu functions are unsafe inside `BoostConditions`. They are safe inside `Conditions`.**

A passive built on the `BoostContext` + `BoostConditions` + `Boosts` pattern that calls a **mod-defined**
`.khn` function in `BoostConditions` **reliably crashes the Toolkit** — `EXCEPTION_ACCESS_VIOLATION` deep
inside `ls::thoth::shared::Entity::HasAnyResistances` / `ls::khonsu::CallApi::Call`, within
`esv::PassiveSystem::UpdatePassivesBoosts`.

This was confirmed over many crash/fix cycles. It happens even with a trivially simple function built
only from native pieces and using no `context.Source` — one that mirrors vanilla's own `IsSpell()`
almost exactly. **Simplifying the function does not fix it.** Vanilla's own Khonsu functions in
`BoostConditions` worked fine in this same mod before being swapped for a custom one, so the trigger is
specifically mod-defined functions on that evaluation path. It was never root-caused further than this.

### The fix pattern

Rewrite the passive from the always-recalculated boost shape to the one-shot functor shape:

```diff
- data "BoostContext"     "OnCast"
- data "BoostConditions"  "IsArcanaSpell();"
- data "Boosts"           "ActionResource(ArcaneEssence,1,0)"
+ data "StatsFunctorContext" "OnCast"
+ data "Conditions"          "IsArcanaSpell();"
+ data "StatsFunctors"       "RestoreResource(SELF,ArcaneEssence,1,0)"
```

✅ Confirmed to stop the crash — this is exactly how `ArcaneOverflow` is written today.

**Rule of thumb:** if you need a custom condition function, pair it with `StatsFunctorContext` +
`Conditions` + `StatsFunctors`. Only use `BoostConditions` with **native** condition functions
(`HasActionResource(...)`, `not WearingArmor(...)`, `HasStatus(...)`) — which is exactly what the
`IND_*_EX_Glow` passives in this mod do, and they are stable.

---

## 7. Other confirmed traps

### ❗ `DescriptionParams` will not do arithmetic on bare tokens

`data "DescriptionParams" "8+ProficiencyBonus+SpellCastingAbilityModifier"` prints the literal token
names concatenated as text. The arithmetic must be inside an actual function call — either a real
Boost/functor name (`GainTemporaryHitPoints(ClassLevel(Arcana)*3)`) or a custom Khonsu function
returning the number. Vanilla number-returning helpers to copy: `GetModifier`, `SourceSpellDC`,
`ManeuverSaveDC`, `GenericSaveDC`, `DistanceToTarget`. ✅

### ❗ `Resistance(..., ResistantToMagical)` crashes

The `ResistanceBoostFlags` values (`ResistantToMagical`, `ImmuneToMagical`, …) are real and are used by
vanilla — but **only as dedicated per-damage-type fields on a `Character` stat entry**
(`data "BludgeoningResistance" "ResistantToNonMagical"`), never as the second argument of the generic
`Resistance(DamageType, Flag)` Boost. Used there they reliably crash the Toolkit, regardless of the
first argument or how many are combined. There is no confirmed-safe way to grant "resistant to magical
damage" dynamically via Boosts — fall back to plain `Resistant` per damage type, or change the design.

> This affects `ArcaneVeil`, which currently ships `Resistance(All,ResistantToMagical)`. If that passive
> starts crashing, this is why.

### ⚠️ Very long `|`-chains

A 60+ term `SpellId(...) | SpellId(...) | …` expression inside `UnlockSpellVariant`'s first argument was
suspected of crashing and stopped crashing once split into per-subclass functions combined by a small
5-term combiner. That test was confounded by other simultaneous changes and the `BoostConditions`
finding above is the likelier cause in that case — so **don't treat length alone as a proven root
cause**. Splitting is still good practice for readability. See `IsDeceiverOneTargetSpell.khn`.

### Schema-valid ≠ works

`LSLibDefinitions.xml` tells you an argument's *type*, not whether the engine accepts the combination.
Example: `Ability` and `SpellSaveDC` take a plain `Int`, so `Ability(Intelligence,ProficiencyBonus)`
fails to parse, while `RollBonus(Attack,ProficiencyBonus)` works because that argument is typed
differently. Passing the schema is necessary, not sufficient.

---

## 8. This mod's Khonsu functions

`Data\Mods\AspectClass_…\Scripts\thoth\helpers\`

| File | Function | Definition |
|---|---|---|
| `IsArcanaSpell.khn` | `IsArcanaSpell(entity)` | `HasSpellSpellLevel() & HasSpellFlag(SpellFlags.Spell) & HasUseCosts('ArcaneEssence', true, entity)` — defaults `entity` to `context.Source` |
| `IsArcanaAttackSpell.khn` | `IsArcanaAttackSpell()` | `IsArcanaSpell() & HasStringInSpellRoll('Attack')` |
| `IsArcanaSaveSpell.khn` | `IsArcanaSaveSpell()` | `IsArcanaSpell() & (HasStringInSpellRoll('SavingThrow') \| HasStringInFunctorConditions('SavingThrow'))` |
| `IsArcanaCantrip.khn` | `IsArcanaCantrip()` | Fixed `SpellId(...)` OR-chain over the 8 class cantrips |
| `IsDeceiverOneTargetSpell.khn` | `IsDeceiverOneTargetSpell()` | 9-term `SpellId(...)` OR-chain; drives **Mirrored Self** |
| `UseSpellSlot.khn` | `UseSpellSlot()` | Spell that costs a SpellSlot / WarlockSpellSlot / SpellSlotsGroup; drives **Mirrored Spell** |

> ⚠️ Known defect: `IsArcanaCantrip()` lists `SpellId('Target_Friends')`, but the mod's cantrip is
> `Target_IND_Friends`. That term never matches.

---

## 9. The vanilla library — searching it

326 functions in `CommonConditions.khn`. **Search it before writing your own** — most of what a class
mod needs already exists.

```bash
grep -n "^function " CommonConditions.khn | grep -i "resist"      # find by topic
grep -n -A6 "^function ExtraAttackSpellCheck" CommonConditions.khn # read one implementation
```

Families worth knowing they exist:

- **HP:** `HasHPLessThan` `HasHPMoreThan` `HasMaxHP` `HasTemporaryHP` `MissingHPGreaterThan`
  `HasHPPercentage{Equal,}Or{Less,More}Than` (+ `WithoutTemporaryHP` variants) `LethalHP`
- **Attack shape:** `IsMeleeAttack` `IsRangedAttack` `IsSpellAttack` `IsWeaponAttack` `IsUnarmedAttack`
  `IsMeleeUnarmedAttack` `IsMeleeSpellAttack` `IsRangedSpellAttack` `IsMainHandAttack` `IsOffHandAttack`
  `IsReactionAttack` `IsThrowAttackRoll`
- **Damage type:** `IsDamageType<Type>` for all 13 types, `IsPhysicalDamage`, `IsEnergyDamage`,
  `IsImmuneToDamageType`, `IsResistantToDamageType`, `HasDamageDoneForType`
- **Outcome:** `IsHit` `IsMiss` `IsCritical` `IsCriticalMiss` `IsKillingBlow` `IsHitpointsDamaged`
  `TotalDamageDoneGreaterThan` `HealDoneGreaterThan`
- **Spell classification:** `IsSpell` `IsCantrip` `IsSpellSchool` `SpellLevelEqualTo`
  `SpellLevelEqualOrLessThan` `SpellPowerLevelEqualTo` `HasSpellSpellLevel` `HasCantripSpellLevel`
  `IsMovementSpell` `IsRecastSpell` `IsSmiteSpells`
- **Status:** `StatusDuration{Equal,}Or{Less,More}Than` `StatusGroupDuration…`
  `MaximumHighStackableStatus` `IsStatusEvent` `CanSeeStatusSource` `HasLosToStatusSource`
- **Equipment:** `HasWeaponInMainHand` `WieldingFinesseWeapon` `HasMetalArmor` `HasHeavyArmor`
  `HasMediumArmor` `Unarmed` `IsEquipmentSlot` `HasInstrumentEquipped` `IsOffHandSlotEmpty`
- **Positioning:** `InMeleeRange` `InReachWeaponRange` `DistanceToTarget*` `YDistanceToTarget*`
  `HasAllyWithinRange` `HasEnemyWithinRange`
- **Rolls / interrupts:** `IsAbleToReact` `HasInterruptedAttack` `InterruptHasAdvantage`
  `IsSetInterruptInteresting` `IsFlatValueInterruptInteresting` `RollDieAgainstDC` `RollDieAgainstPercent`
- **Character:** `ClassLevelHigherOrEqualThan` `CharacterLevelGreaterThan` `AbilityGreaterThan`
  `<Ability>GreaterThan` `HasEvasion` `HasAnyExtraAttack` `IsCrowdControlled` `IsSneakingOrInvisible`
  `PlayableRace` `IsLivingBeing` `IsSummon` `UndeadOrFiend`
- **DC helpers (return numbers):** `SourceSpellDC` `ManeuverSaveDC` `GenericSaveDC`
  `HybridCasterWeaponActionDC` `GetModifier`

`CommonConditionsDev.khn` holds dev-flagged extras — `FreecastCheck`, `IsTadpolePower`, various
`*SpellCheck` toggles for Metamagic-style mechanics. Good templates for toggle passives.

### Reference sources, ranked by reliability

1. **`CommonConditions.khn` itself** — the real thing. Always prefer it.
2. **`Data\Editor\Mods\SharedDev\Stats\...`** (inside the game install) — real shipped-but-dev-flagged
   stat definitions. A proven-working template beats inventing from schema.
3. **`https://bg3.norbyte.dev/search?iid=<packaged/path>`** — full-text search over vanilla scripts and
   stats.
4. **`https://raw.githubusercontent.com/Norbyte/lslib/master/LSLibDefinitions.xml`** — argument-type
   schema for every Boost/Functor. Types only; see §7.
5. **`https://gist.github.com/Norbyte/5628f9787b39741bfbe0918be4c823c2`** — ~150 hardcoded C++ Thoth
   functions. **Explicitly incomplete** — absence from this list is *not* evidence a function doesn't
   exist (`FreecastCheck` and `HasAnyResistances` are real but missing from it).
6. **mod.io — "Adding Khonsu (.khn) condition scripts" by DPhKraken** — the authoritative how-to.
   Fetch it with the **Browser tool**, not WebFetch: WebFetch on mod.io and norbyte pages sometimes
   returns thin summarised results that drop detail or invent structure.

---

## 10. Debugging

There is no logger and no Script Extender. What you have:

**Toolkit logs** — under `C:\Program Files (x86)\Steam\steamapps\common\Baldurs Gate 3 Toolkit\`,
**not** under `Data\`:

- `CrashDump - <timestamp>.dmp.txt` — one per crash, with the exception type and a readable native
  stack trace. **Check this first after any crash** — sort by mtime, read the newest. Cheap, and it
  usually names the subsystem outright.
- `errors.<ISO-timestamp>.txt` — multi-MB rolling session log. A genuine Khonsu **syntax** error appears
  as `!CRITICAL!ASSERT!… <ls::khonsu::error::Syntax&>: Syntax error: …`. Grep for the function or
  passive name; never read the file whole.

⚠️ Worth internalising: across every crash investigated in this project, **not one** turned out to be a
parse error. They were all runtime issues. If there's no `khonsu::error::Syntax` line, stop re-reading
your syntax and look at *where* the function is being called from.

**In-game tracing:** apply a temporary status with `ForceOverhead` at each branch and watch which
appears. Slow, but console-safe.

---

## 11. Checklist before reloading stats

1. Right operators for the right file — `&`/`\|`/`~` in `.khn`, `and`/`or`/`not` in Stats fields.
2. Custom function used in a condition field? Confirm it is **`Conditions`, not `BoostConditions`** (§6).
3. Searched `CommonConditions.khn` before writing a new function.
4. Every entity access guarded by `.IsValid`, and every optional parameter defaulted.
5. Any new `ConditionError` key declared in `ErrorDescriptions/ConditionErrors.lsx` with loca.
6. `DescriptionParams` arithmetic wrapped in a real function call, not bare tokens (§7).
7. Reload Stats, then check for a fresh `CrashDump - *.dmp.txt` before assuming it worked.
