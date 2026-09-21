# Osiris reference — BG3 (Patch 8)

Working reference for writing and debugging Osiris story scripts in the **Arcana** mod.
Read this before touching anything under `Data\Mods\AspectClass_…\Story\`.

**Dialect warning.** Most Osiris material online is **Divinity: Original Sin 2**. The syntax is close but
the API is not — DOS2 call names, `CharacterStatusText`, `ItemTemplate*` helpers and the old `DB_` library
largely do not exist in BG3. Only trust: this document, `story_header.div`, and real vanilla BG3 goals.

**Confidence markers used below:** ✅ verified against BG3 files this project · ⚠️ convention or strong
inference, not directly proven · ❓ unverified, check before relying on it.

---

## 1. The three scripting layers — pick the right one first

This is the highest-leverage decision. Osiris is the **last** resort, not the first.

| Layer | Runs where | Good at | Bad at |
|---|---|---|---|
| **Stats** (`Passive.txt`, `Spell_*.txt`, `Status_*.txt`) | Engine, per-entity | Boosts, functors, statuses, spell behaviour, everything declarative | Cross-entity bookkeeping, sequencing, "N times within M turns" |
| **Khonsu** (`.khn`) | Engine, inside a Stats field | Reusable named conditions and computed numbers | Doing anything — it only answers questions |
| **Osiris** (`Story\RawFiles\Goals\*.txt`) | Global story VM | Persistent state, timers, reacting to world events, orchestrating across entities | Anything the engine already does; it is coarse, global and can't read Stats fields |

**Reach for Osiris only when the effect needs memory across events or across entities.**
In this mod that's exactly four things: counting necrotic hits (Darkness Rise), banking damage
(Hemorrhage), copying a spell from another caster (Mirrored Spell), and post-processing a summoned
clone (Mirror Image). Everything else is Stats.

**Osiris cannot:** read a Stats field, read a Boost, know a spell's level or cost, evaluate a Khonsu
function, or see anything the Stats layer computes. ✅ There is **no `ClassLevel` query** — verified,
`story_header.div` has none. If Osiris needs a class level, use `GetLevel` (character level, not class
level) or push the value in from Stats via a status.

---

## 2. File anatomy

Every goal file needs the full skeleton or the Story Editor refuses it. ✅

```
Version 1
SubGoalCombiner SGC_AND
INITSECTION

// database declarations go here (optional)

KBSECTION

// IF / PROC / QRY rules go here

EXITSECTION

ENDEXITSECTION
```

- The blank line between `EXITSECTION` and `ENDEXITSECTION` is part of the shape vanilla always emits. ✅
- An optional trailing `ParentTargetEdge "<OtherGoalName>"` attaches this goal as a subgoal of another.
  Vanilla uses it (`ParentTargetEdge "__Start"`); this mod's goals are all root goals and don't. ✅
- `INITSECTION` runs once when the goal is activated. `EXITSECTION` runs when it completes — this mod
  never uses it.
- Comments are `//`. Vanilla wraps blocks in `//REGION Name` … `//END_REGION`; this mod follows that. ✅

### One file per feature

`IND_<Kind>_<Feature>.txt` — `IND_Passive_DarknessRise`, `IND_Status_Hemorrhage`, `IND_Spell_MirrorImage`.
Keep a feature's rules together; the story VM doesn't care about file boundaries, but you will.

---

## 3. Databases (`DB_`)

Osiris has no variables. **All persistent state is a database** — a set of tuples, like a tiny Prolog
fact table. A DB is declared implicitly by first use; its **name plus arity plus argument types** form
its identity, so `DB_Foo(_A)` and `DB_Foo(_A,_B)` are two unrelated databases.

```
DB_Hemorrhage_Pos_Damage(_TheEternal, _Defender, 0);   // insert a fact
NOT DB_Hemorrhage_Pos_Damage(_TheEternal, _Defender, _Old);  // delete a fact
```

`NOT` means *delete* in the action half of a rule, and *absence* in the condition half. Same keyword,
two meanings, decided by position. ✅

### The INITSECTION declare-then-delete idiom

```
INITSECTION
DB_IND_MirroredSpell((CHARACTER)NULL_00000000-0000-0000-0000-000000000000, "");
NOT DB_IND_MirroredSpell((CHARACTER)NULL_00000000-0000-0000-0000-000000000000, "");
```

This inserts a dummy row purely to pin the database's arity and column types at compile time, then
deletes it. Without it, the compiler infers types from first use, and a later rule that binds a
differently-typed variable into the same DB fails with a type mismatch. Vanilla and this mod both do
this. ✅ Use it for every DB whose columns aren't obviously typed at every use site.

### DB hygiene — a real leak class

A DB row you insert and never delete lives in the save file forever. Every insert needs a matching
delete path, including the abnormal ones: the entity died, the status was dispelled early, combat ended,
the player reloaded, the player respecced. This mod handles it with dedicated `PROC_*_Clear*` procedures
(`PROC_Hemorrhage_ClearTotal`, `PROC_IND_MirroredSpell_Clear`) — copy that shape. ✅

⚠️ Databases persist inside the save game. Recompiling the story does not retroactively clean rows that
an old build wrote, so a save made against a buggy build can carry stale rows into a fixed build. When
debugging something that "still happens after the fix", test on a **fresh save** before re-theorising.

---

## 4. The three rule kinds

### `IF` — reacts to an event

```
IF
StatusApplied(_Defender, "HEMORRHAGE", _TheEternal, _)
AND
GetHitpoints(_Defender, _HP)
THEN
DB_Hemorrhage_LastHP(_Defender, _HP);
```

The **first line after `IF` must be an event or a DB fact** — the trigger. Everything after `AND` is a
condition or a query that binds more variables. Actions after `THEN` each end with `;`.

### `PROC` — a callable procedure

```
PROC
PROC_Hemorrhage_Burst((GUIDSTRING)_TheEternal, (GUIDSTRING)_Defender, (INTEGER)_TotalDamage)
AND
_TotalDamage > 0
THEN
ApplyDamage(_Defender, _TotalDamage, "Necrotic", _TheEternal);
```

Parameters are **explicitly typed in the definition**. Call it like an action: `PROC_Foo(_A, _B);`

**Multiple definitions of the same PROC all run**, each gated by its own conditions. ⚠️ This mod's
Darkness Rise escalation depends on it — four `PROC_IND_DarknessRise_Escalate` definitions with
mutually exclusive guards, so exactly one fires. Write the guards to be genuinely exclusive; if two can
both match, both bodies execute.

### `QRY` — a reusable boolean

```
QRY
QRY_ShouldTrackCombat((GUIDSTRING)_Object)
AND
CanFight(_Object,1)
THEN
DB_NOOP(1);
```

`DB_NOOP(1);` is the conventional no-op body — a query's body is never meant to do work, it just has to
be non-empty. ✅

**Multiple definitions of the same QRY act as OR.** ✅ Verified in vanilla: `__Combat.txt` defines
`QRY_ShouldTrackCombat` twice, once guarded by `CanFight` and once by `IsCharacter`. The query succeeds
if any definition succeeds. This is how you express disjunction — Osiris has no `OR` keyword.

A QRY can bind out-parameters, which is how vanilla writes "find me the closest available X" helpers.

---

## 5. Types and casting

Osiris is statically typed with an alias hierarchy rooted at `GUIDSTRING`:

```
GUIDSTRING → CHARACTER, ITEM, TRIGGER, SPLINE, LEVELTEMPLATE, DIALOGRESOURCE,
             EFFECTRESOURCE, ANIMATION, TAG, FLAG, FACTION, ROOT (→ CHARACTERROOT, ITEMROOT),
             SHAPESHIFTRULE, DIFFICULTYCLASS, …
```

Primitives: `INTEGER`, `INTEGER64`, `REAL`, `STRING`. Enums exist too (`DEATHTYPE.Chasm`,
`TAGCATEGORY.Class`) and are compared with `!=` / `==`. ✅

### The casting rule that bites

**A variable's type is fixed the first time it's bound.** If an event gives you a `GUIDSTRING` but that
variable also flows into a predicate already typed `CHARACTER`, you must cast explicitly:

```
StatusRemoved((CHARACTER)_Caster, "X", _, _)     // StatusRemoved's param is natively GUIDSTRING
```

Otherwise the Story Editor reports *"parameter N type mismatch"* and silently skips the rule. ✅
Cast at the **binding site**, not at the use site. Casting down (`GUIDSTRING` → `CHARACTER`) is what you
normally need; the reverse is implicit.

### Variables and wildcards

- `_Name` — a variable. Bound on first appearance, matched thereafter.
- `_` — anonymous wildcard, "any value, don't care". Each `_` is independent.
- Comparison operators in conditions: `==` `!=` `<` `<=` `>` `>=` ✅
- `NULL_00000000-0000-0000-0000-000000000000` is the null GUID; compare against it to reject
  "no killer" / "no source" cases. ✅

---

## 6. Calls vs queries

Both look like function invocations; they behave differently.

- **Call** — an action. Goes after `THEN`, ends with `;`. All parameters are inputs.
  `ApplyStatus(_Target, "SIGIL", -6.0, 1, _Caster);`
- **Query** — a condition. Goes after `AND`. Has `[in]` and `[out]` parameters; the `[out]` ones **bind
  variables**, and the query **fails** (aborting the rule) if it can't produce a value.
  `GetHitpoints(_Defender, _NewHP)` — `_NewHP` is an output.

A boolean query's output is an `INTEGER`, and you assert it by passing the literal you want:
`HasActiveStatus(_Char, "SIGIL", 1)` means "has it", `…, 0)` means "doesn't". ✅ This is the idiom the
mod uses everywhere; it's cleaner than binding then comparing.

### Status duration units

`ApplyStatus(_Object, _Status, _Duration, _Force, _Source)` — duration is in **seconds**, and
**6 seconds = 1 combat turn**. ✅ Cross-checked two ways inside this mod: Darkness Rise applies its
stages with `18.0` and its description says *"within 3 turns"*, and Mirrored Spell's
`ObjectTimerLaunch(…, 18000, 1)` (18 000 ms) backs a *"for 3 turns"* description.

✅ **A negative duration means permanent, whatever its magnitude.** `-6.0` behaves exactly like `-1`,
which is the value the Toolkit's status editor uses for a permanent status. It does **not** mean
"6 turns".

✅ This mod passes `-6.0` in two places — `ApplyStatus(_Target, "SIGIL", -6.0, …)` in
`IND_Status_Sigil.txt` and the `*_LAST_CASTED` markers in `IND_Spell_Mimic_Last_Casted.txt`. Both are
therefore **permanent, by design**. Sigil is meant to stay on the target until a Deceiver Arcane spell
clears it; the `*_LAST_CASTED` markers are overwritten via their shared `StackId` (`MIMIC_LAST_CAST`)
rather than expiring.

Still: don't write `-6.0` when you mean a turn count. Use `-1` for permanent, and `36.0` for 6 turns.

---

## 7. Timers

Three families, all in `story_header.div`: ✅

| Call | Unit | Notes |
|---|---|---|
| `TimerLaunch(_Timer, _Time)` | ms | Global, unnamed owner. Fires `TimerFinished(_Timer)` |
| `ObjectTimerLaunch(_Entity, _Timer, _Time, _ShouldTickOnTurnStart)` | ms | Per-entity. Fires `ObjectTimerFinished(_Object, _Timer)` |
| `RealtimeObjectTimerLaunch(_Entity, _Timer, _Time)` | ms | Per-entity, **real time** — keeps running in turn-based combat |

Cancels: `TimerCancel`, `ObjectTimerCancel`, `RealtimeObjectTimerCancel`.
Existence checks: `TimerExists`, `ObjectTimerExists`.
Also `TurnBasedTimerLaunch` and `ObjectQuestTimerLaunch` (both take a localised text key, for
player-visible countdowns).

**Always cancel before relaunching.** Re-launching a live timer's behaviour is unspecified; the mod's
Mirrored Spell explicitly does `ObjectTimerCancel(...)` then `ObjectTimerLaunch(...)`. ✅

Timer names are plain strings and share a namespace per entity — **prefix them** so you can't collide
with vanilla or another mod. ✅ Every timer in this mod is `IND_`-prefixed as of 2026-08-18:

`IND_MirroredSpell_Timer` · `IND_FacelessCopy_Timer` · `IND_FacelessCopyEX_Timer` ·
`IND_FacelessCopyEX_Timer2` · `IND_Withdraw_Timer` · `IND_MimicWithdraw_Timer` ·
`IND_MirrorWithdraw_Timer` · `IND_MirrorImage_Summon` · `IND_MirrorImage_Delay`

To check the invariant still holds:

```bash
cd ".../Story/RawFiles/Goals" && grep -hoE 'Timer(Launch|Cancel|Finished|Exists)\([^,]*, *"[^"]+"' *.txt \
  | grep -oE '"[^"]+"' | grep -v '"IND_'     # must print nothing
```

---

## 8. Finding the right function — do this, don't guess

`story_header.div` in the mod's `Story\RawFiles\` is the **complete, authoritative** API surface:
**320 events, 425 queries, 558 calls, 5 syscalls, 11 sysqueries** for this game version. ✅
It is auto-generated — never edit it.

```bash
H="C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data/Mods/AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7/Story/RawFiles/story_header.div"

grep -iE "^event .*Status" "$H"          # every status-related event
grep -iE "^(call|query) .*Hitpoint" "$H" # everything about HP
grep -inE "^query GetLevel" "$H"         # exact signature of one thing
```

If it isn't in that file, **it does not exist** in vanilla BG3 Osiris. That is a definitive negative —
unlike the community Khonsu lists, which are incomplete. Only then consider a Stats-layer solution.

Second source when you need a *usage* example rather than a signature: extract a vanilla goal and read
how Larian actually calls it (§4 of `CLAUDE.md` has the `Divine.exe` recipes).
`Mods/Shared/Story/RawFiles/Goals/__PROC.txt` (~103 KB) and `__AAA_FirstGoal.txt` (~88 KB) are the
densest pattern libraries.

---

## 9. Signature index for this mod's domain

Extracted verbatim from `story_header.div`. ✅ Return/out parameters marked `[out]`.

### Status and passive

```
call  ApplyStatus((GUIDSTRING)_Object, (STRING)_Status, (REAL)_Duration, (INTEGER)_Force, (GUIDSTRING)_Source)
call  RemoveStatus((GUIDSTRING)_Target, (STRING)_Status, (GUIDSTRING)_Cause)
call  RemoveStatusesWithGroup((GUIDSTRING)_Target, (STRING)_StatusGroup, (GUIDSTRING)_Cause)
call  RemoveHarmfulStatuses((GUIDSTRING)_Target)
call  AddPassive((GUIDSTRING)_Entity, (STRING)_PassiveID)
call  RemovePassive((GUIDSTRING)_Entity, (STRING)_PassiveID)
call  TogglePassive((GUIDSTRING)_Entity, (STRING)_PassiveID)
query HasActiveStatus([in](GUIDSTRING)_Target, [in](STRING)_Status, [out](INTEGER)_Bool)
query HasPassive([in](GUIDSTRING)_Entity, [in](STRING)_PassiveID, [out](INTEGER)_BoolHasPassive)
event StatusApplied((GUIDSTRING)_Object, (STRING)_Status, (GUIDSTRING)_Causee, (INTEGER)_StoryActionID)
event StatusRemoved((GUIDSTRING)_Object, (STRING)_Status, (GUIDSTRING)_Causee, (INTEGER)_ApplyStoryActionID)
event StatusAttempt / StatusAttemptFailed   — same shape as StatusApplied
event StatusTagSet / StatusTagCleared((GUIDSTRING)_Target, (TAG)_Tag, (GUIDSTRING)_SourceOwner, (GUIDSTRING)_Source, (INTEGER)_StoryActionID)
```

### Spells

```
call  AddSpell((CHARACTER)_Character, (STRING)_Spell, (INTEGER)_ShowNotification, (INTEGER)_AddContainerSpells)
call  RemoveSpell((CHARACTER)_Character, (STRING)_Spell, (INTEGER)_RemoveContainerSpells)
call  UseSpell((GUIDSTRING)_Caster, (STRING)_SpellID, (GUIDSTRING)_Target, (GUIDSTRING)_Target2, (INTEGER)_WithoutMove)
call  UseSpellAtPosition((GUIDSTRING)_Caster, (STRING)_SpellID, (REAL)_X, (REAL)_Y, (REAL)_Z, (INTEGER)_WithoutMove)
call  CreateExplosion((GUIDSTRING)_Target, (STRING)_SpellID, (INTEGER)_CasterLevel, (GUIDSTRING)_Caster)
query HasSpell([in](CHARACTER)_Character, [in](STRING)_Spell, [out](INTEGER)_Bool)
query SpellHasSpellFlag([in](STRING)_SpellID, [in](STRING)_SpellFlag, [out](INTEGER)_HasFlag)
event CastSpell / CastedSpell / CastSpellFailed / UsingSpell((GUIDSTRING)_Caster, (STRING)_Spell, (STRING)_SpellType, (STRING)_SpellElement, (INTEGER)_StoryActionID)
event UsingSpellOnTarget((GUIDSTRING)_Caster, (GUIDSTRING)_Target, (STRING)_Spell, …)
event UsingSpellAtPosition((GUIDSTRING)_Caster, (REAL)_X, (REAL)_Y, (REAL)_Z, (STRING)_Spell, …)
event LearnedSpell((CHARACTER)_Character, (STRING)_Spell)
```

**Which cast event to use.** `CastSpell` fires on cast start, `CastedSpell` after it resolves, `UsingSpell`
during use. ⚠️ The mod uses `CastSpell` to stamp `*_LAST_CASTED` markers (fire immediately) and
`CastedSpell` for Mirrored Spell (must observe a completed cast). Pick deliberately — the difference
matters when the spell can be interrupted or countered.

### HP and damage

```
call  ApplyDamage((GUIDSTRING)_Object, (INTEGER)_Damage, (STRING)_DamageType, (GUIDSTRING)_Source)
call  SetHitpoints((GUIDSTRING)_Entity, (INTEGER)_HP, (STRING)_HealTypes)
call  SetHitpointsPercentage((GUIDSTRING)_Entity, (REAL)_Percentage, (STRING)_HealTypes)
query GetHitpoints([in](GUIDSTRING)_Entity, [out](INTEGER)_HP)
query GetHitpointsPercentage([in](GUIDSTRING)_Entity, [out](REAL)_Percentage)
query GetMaxHitpoints([in](GUIDSTRING)_Entity, [out](INTEGER)_MaxHP)
event HitpointsChanged((GUIDSTRING)_Entity, (REAL)_Percentage)
event AttackedBy((GUIDSTRING)_Defender, (GUIDSTRING)_AttackerOwner, (GUIDSTRING)_Attacker,
                 (STRING)_DamageType, (INTEGER)_DamageAmount, (STRING)_DamageCause, (INTEGER)_StoryActionID)
```

### Entity, world and combat

```
query GetLevel([in](GUIDSTRING)_Object, [out](INTEGER)_Level)          // character level, NOT class level
query GetPosition([in](GUIDSTRING)_Target, [out](REAL)_X, [out](REAL)_Y, [out](REAL)_Z)
query GetDistanceTo([in](GUIDSTRING)_O1, [in](GUIDSTRING)_O2, [out](REAL)_Dist)
query GetAbility([in](CHARACTER)_Character, [in](STRING)_Attribute, [out](INTEGER)_Value)
query IsCharacter / IsItem([in](GUIDSTRING)_Object, [out](INTEGER)_Bool)
query IsPlayer / IsSummon([in]…, [out](INTEGER)_Bool)
query IsPartyMember([in](CHARACTER)_Character, [in](INTEGER)_IncludeNotControlable, [out](INTEGER)_Bool)
query IsAlly / IsEnemy([in](CHARACTER)_A, [in](CHARACTER)_B, [out](INTEGER)_Bool)
query IsInCombat([in](GUIDSTRING)_Entity, [out](INTEGER)_Bool)
query IsTagged([in](GUIDSTRING)_Target, [in](TAG)_Tag, [out](INTEGER)_Bool)
call  SetTag / ClearTag((GUIDSTRING)_Target, (TAG)_Tag)
call  Transform((GUIDSTRING)_Object, (GUIDSTRING)_TargetTemplate, (SHAPESHIFTRULE)_ShapeshiftRules)
call  CopyCharacterEquipment((CHARACTER)_Target, (CHARACTER)_Source)
call  TeleportTo((GUIDSTRING)_Source, (GUIDSTRING)_Target, (STRING)_Event, …5 INTEGER flags)
event Died((CHARACTER)_Character)
event LeveledUp((CHARACTER)_Character)
event RespecCompleted((CHARACTER)_Character)
event EnteredCombat / LeftCombat / CombatStarted / CombatEnded / CombatRoundStarted
event TurnStarted / TurnEnded((GUIDSTRING)_Object)
event ShortRested((CHARACTER)_Character) / LongRestFinished() / UserCharacterLongRested((CHARACTER)_C, (INTEGER)_IsFullRest)
```

### Action resources — the thin spot

```
query GetActionResourceValuePersonal([in](CHARACTER)_Player, [in](STRING)_ResourceName, [in](INTEGER)_ResourceLevel, [out](REAL)_Amount)
query PartyGetActionResourceValue([in](CHARACTER)_Player, [in](STRING)_ResourceName, [out](REAL)_Amount)
call  PartyIncreaseActionResourceValue((CHARACTER)_Player, (STRING)_ResourceName, (REAL)_Delta)
```

✅ Note what's missing: there is **no per-character setter**. Osiris can read one character's resource
and increase it party-wide, but cannot set a single character's `ArcaneEssence`. To change one
character's resource, apply a status whose `Boosts` carry `ActionResource(...)`, or use a Stats functor
(`RestoreResource` / `UseActionResource`) — that's what the mod does.

### Arithmetic and strings

```
query IntegerSum / IntegerSubtract / IntegerProduct / IntegerDivide / IntegerMin / IntegerMax / IntegerModulo
query RealSum / RealSubtract / RealProduct / RealDivide / RealMin / RealMax / RealSqrRoot
query RealToInteger / IntegerToReal
query Random([in](INTEGER)_Modulo, [out](INTEGER)_Random)
```

There is no infix arithmetic. `a + b` must be written `IntegerSum(_A, _B, _Sum)` as a condition — which
means **all maths happens in the condition half of a rule**, before `THEN`. This forces the awkward
shape you see in `IND_Status_Hemorrhage.txt`, where subtraction and summation are conditions.

---

## 10. Pattern cookbook

### Guarded state machine (Darkness Rise)

Escalate through stages with mutually exclusive guards, and refresh once at the top.

```
IF
AttackedBy(_, _, _Attacker, "Necrotic", _, _, _)
AND
HasPassive(_Attacker, "DarknessRise", 1)
THEN
PROC_IND_DarknessRise_Escalate(_Attacker);

PROC
PROC_IND_DarknessRise_Escalate((GUIDSTRING)_Attacker)
AND
HasActiveStatus(_Attacker, "DARKNESS_RISE_TECH_1", 0)
AND
HasActiveStatus(_Attacker, "DARKNESS_RISE_TECH_2", 0)
AND
HasActiveStatus(_Attacker, "DARKNESS_RISE_AURA", 0)
THEN
ApplyStatus(_Attacker, "DARKNESS_RISE_TECH_1", 18.0, 1, _Attacker);
```

Why a PROC rather than four `IF` rules: the trigger is written once, and the stage logic is reusable and
testable on its own. Note every guard checks **all three** stage statuses — a guard that only checks the
one it cares about would let two stages fire at once.

### Accumulator with cleanup (Hemorrhage)

Track a running total in a DB, keyed by (source, target), plus a second DB holding the last-seen HP:

1. On `StatusApplied` — clear any stale rows first (**idempotent init**), then seed total = 0 and
   last-HP = current HP.
2. On `HitpointsChanged` — if HP went down, add the delta to the total; if it went up, only update the
   reference. Guard with `HasActiveStatus(_Defender, "HEMORRHAGE", 1)`.
3. On `StatusRemoved` — delete both rows, then apply the banked damage.

The idempotent init is the important part: statuses can be reapplied before the old one expires, and
without the clear you'd double-count. ✅

### Delayed post-processing of a summon (Mirror Image)

The engine finishes creating a summon after the status lands, so acting immediately fails. The pattern
is: stamp a technical status → record what you need → `RealtimeObjectTimerLaunch(…, 300)` → do the work
on `ObjectTimerFinished` → chain a second short timer for anything that depends on the first step
(`Transform` then `CopyCharacterEquipment` 200 ms later) → clean the DBs. ✅

⚠️ Those 300/200 ms delays are empirical, not guaranteed. On a slower machine or a heavier scene they
could be too short. If clone setup ever misbehaves intermittently, suspect these first.

### Disjunction

Osiris has no `OR`. Write two `QRY` definitions with the same name and signature (§4).

### Marker statuses as a bridge

Osiris can't read Stats. To let a Stats condition depend on something only Osiris knows, have Osiris
apply a technical status and have the Stats side test `HasStatus('…')`. The `*_LAST_CASTED` markers that
gate the Deceiver's Mimic container are exactly this. ✅

---

## 11. Risks and blind spots

| Risk | Why it matters | What to do |
|---|---|---|
| **DB leaks** | Rows persist in the save forever | Every insert needs a delete path for every exit, including death, dispel, reload and respec |
| **Stale saves** | Old builds' DB rows survive a recompile | Reproduce on a fresh save before concluding a fix failed |
| **`HitpointsChanged` fires constantly** | It's a global event on every entity | Gate it *first* on a cheap `HasActiveStatus(...)` check, as Hemorrhage does. Never put expensive queries before the guard |
| **`AttackedBy` also fires for DoT and environment** | `_DamageCause` distinguishes them | Filter on `_DamageCause` if the effect should only count direct hits ❓ (the mod currently doesn't) |
| **Timer name collisions** | Timer names are a flat per-entity namespace | Always prefix `IND_` |
| **Type mismatch skips the rule silently** | The rule simply never fires | Read `log.txt` — the compiler does report it |
| **Multiplayer** ❓ | Osiris runs server-side; `context`-free code is usually fine, but per-user assumptions aren't | If a rule assumes one player, revisit it before release |
| **No debugger, no Script Extender** | You cannot log at runtime | Debug by making state **visible in game**: apply a temporary status with `ForceOverhead` and read it off the character |

### Debugging without a logger

The one channel you have is the game itself. To trace an Osiris rule, apply a throwaway status with
`ForceOverhead` and a distinct name at each branch point, then watch which ones appear. Remove them
before shipping. This is slow but it is the only console-safe method available.

---

## 12. Checklist before compiling

1. Skeleton present and exact (`Version 1` … `ENDEXITSECTION`).
2. Every new DB declared in `INITSECTION` with the declare-then-`NOT` idiom.
3. Every DB insert has a matching delete on all exit paths.
4. Every variable that crosses a type boundary is cast at its binding site.
5. Every timer is prefixed `IND_` and cancelled before relaunch.
6. Every function used was grepped out of `story_header.div`, not recalled from memory.
7. Compile, then **read `Story\log.txt`** — confirm `0 error(s)` and read the warnings.
8. Test on a **fresh save**.
