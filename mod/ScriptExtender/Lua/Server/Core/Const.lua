local C = {}

C.TAG_ARCANA = "cbf560ac-282c-4a31-8630-7eeefb7fa67d"

C.HAND_MAX = 10
C.OPENING_HAND = 4
C.DRAW_PER_TURN = 1
C.MAX_COPIES = 3
C.UNIQUE_COPIES = 1

C.MIN_DECK_BANDS = {
    { maxLevel = 8, size = 10 },
    { maxLevel = 20, size = 15 },
}

-- energia(turno) = min(ceiling, turno + start); binds e bônus somam depois e passam do ceiling
C.THREAD_BANDS = {
    { maxLevel = 4, start = 0, ceiling = 1 },
    { maxLevel = 6, start = 0, ceiling = 3 },
    { maxLevel = 8, start = 1, ceiling = 4 },
    { maxLevel = 10, start = 2, ceiling = 5 },
    { maxLevel = 20, start = 3, ceiling = 6 },
}
C.THREAD_RESERVE_MAX = 2
C.THREAD_CAP = 6
C.DEFAULT_LEVEL = 1
C.DEFAULT_COST = 1

C.RES_THREAD = "ArcanaThread"
-- Visible counter of the hand; every card costs 1, so the engine enforces the hand on its own.
C.RES_HAND_CARD = "ArcanaHandCard"
-- UUID of the ArcanaThread ActionResourceDefinition; nil falls back to a name lookup.
C.RES_THREAD_UUID = "d6f4f7d5-b4b2-453c-b1bb-35b67d2d1547"

C.BOOST_SOURCE = "ArcanaDeck"
-- Engine syntax not yet verified in game: swap Replace for Override/Add here if the test fails.
C.LOCK_BOOST = "UnlockSpellVariant(SpellId('%s'),ModifyUseCosts(Add,ArcanaNotInHand,1,0),ModifyTooltipDescription())"
-- The Thread cost no longer rides on this boost. ARCANA_WEAVING (Status_BOOST.txt) converts the
-- slot cost of every Arcana spell into Threads generically, one boost per spell level, so this
-- one only marks the card as being in hand.
C.GLOW_BOOST = "UnlockSpellVariant(SpellId('%s'),ModifyIconGlow(),ModifyTooltipDescription())"

-- Applied while in combat; carries the slot->Thread conversion. Never granted on console.
C.WEAVING_STATUS = "ARCANA_WEAVING"

C.CATEGORY_ORDER = { "Card", "Passive", "Created", "Util", "Ability", "Reaction" }
C.PREFIX = {
    Card = "Arcana_Card_Spell_",
    Passive = "Arcana_Card_Passive_",
    Created = "Arcana_Created_",
    Util = "Arcana_Util_",
    Ability = "Arcana_Card_Ability_",
    -- Reaction spells are never touched by the deck; the category exists so they can be told apart.
    Reaction = "Arcana_Reaction_",
}

-- Categories that live in the deck and get lock/glow boosts.
C.DECK_CATEGORIES = { Card = true, Passive = true }

C.REWEAVE_TOKEN = "Shout_Arcana_Created_Reweave"

return C
