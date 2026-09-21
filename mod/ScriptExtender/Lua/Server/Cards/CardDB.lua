local C = Req("Server/Core/Const.lua")

local D = {}
local EMPTY = {}

-- cost = Threads spent in combat. Rule: X = the card's level, no exceptions.
-- The engine is what actually charges it. Out of combat a card costs X points of ArcanaSpellSlot;
-- in combat ARCANA_WEAVING zeroes that and adds X Threads in its place, one boost per level. The
-- number here is the Lua's own bookkeeping (tests, !arcanahand, previews), so it has to match the
-- spell's UseCosts: when a card's level changes, both move together.
D.cards = {
    ["Target_Arcana_Card_Spell_Distortion"] = {
        aspect = "Deceiver",
        cost = 3,
        conjures = {
            { id = "Shout_Arcana_Created_Withdraw", lasts = 2 },
            { id = "Target_Arcana_Created_MimicDistortion", lasts = 1 },
        },
    },
    ["Target_Arcana_Created_MimicDistortion"] = {
        aspect = "Deceiver",
        cost = 2,
        conjures = { { id = "Shout_Arcana_Created_MimicWithdraw", lasts = 2 } },
    },
    ["Projectile_Arcana_Card_Spell_SigilofMalice"] = {
        aspect = "Deceiver",
        cost = 1,
        conjures = { { id = "Projectile_Arcana_Created_MimicSigilofMalice", lasts = 1 } },
    },
    ["Target_Arcana_Card_Spell_EtherealChains"] = {
        aspect = "Deceiver",
        cost = 2,
        conjures = { { id = "Target_Arcana_Created_MimicEtherealChains", lasts = 1 } },
    },
    ["Zone_Arcana_Card_Spell_FinalSpark"] = {
        aspect = "Starchild",
        cost = 6,
        conjures = { { id = "Zone_Arcana_Created_FinalSpark_Recreate", lasts = 2 } },
    },
    -- Choose: the engine's own spell container shows the 6 diseases, so there is no Lua for it.
    -- The children carry the cost (they inherit the parent's UseCosts) and are Created, so they
    -- never enter the deck; parentOf keeps them lit while the card itself is in hand.
    ["Target_Arcana_Card_Spell_Hemoplague"] = {
        aspect = "Eternal",
        cost = 4,
        keywords = { Choose = true },
    },

    ["Target_Arcana_Created_Mimic"] = { aspect = "Deceiver", cost = 2 },
    ["Projectile_Arcana_Created_MimicSigilofMalice"] = { aspect = "Deceiver", cost = 1 },
    ["Target_Arcana_Created_MimicEtherealChains"] = { aspect = "Deceiver", cost = 1 },
    ["Shout_Arcana_Created_Withdraw"] = { aspect = "Deceiver", cost = 1 },
    ["Shout_Arcana_Created_MimicWithdraw"] = { aspect = "Deceiver", cost = 1 },
    ["Zone_Arcana_Created_FinalSpark_Recreate"] = { aspect = "Starchild", cost = 2 },
    ["Target_Arcana_Created_ZephyrStrike"] = { aspect = "Unbound", cost = 1 },
    ["Shout_Arcana_Created_Reweave"] = { cost = 0 },

    -- A cantrip has no slot cost, so ARCANA_WEAVING has nothing to zero on it and only adds: it is
    -- the one case that tests the Add half of the mechanism on its own. 1 Thread, like any card.
    ["Target_Arcana_Card_Spell_MaliciousWhispers"] = { aspect = "Deceiver", cost = 1 },
    ["Shout_Arcana_Card_Spell_HowlOfTheDead"] = { aspect = "Eternal", cost = 1 },

    -- Reaction activation cards. The resource is given back by the spell's own SpellProperties,
    -- so the console edition needs none of this; the Lua only decides when to zero it.
    ["Shout_Arcana_Card_Passive_GaleDeflection"] = {
        aspect = "Unbound", cost = 2, keywords = { Unique = true },
        reaction = { resource = "ArcanaReactGaleDeflection" },
    },
    ["Shout_Arcana_Card_Passive_InstinctiveCharm"] = {
        aspect = "Deceiver", cost = 2, keywords = { Unique = true },
        reaction = { resource = "ArcanaReactInstinctiveCharm" },
    },
    ["Shout_Arcana_Card_Passive_HollowImage"] = {
        aspect = "Deceiver", cost = 3, keywords = { Unique = true },
        reaction = { resource = "ArcanaReactHollowImage", perTurn = true },
    },

    ["Shout_Arcana_Card_Spell_DEBUG_Fated"] = { keywords = { Fated = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Fleeting"] = { keywords = { Fleeting = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Unique"] = { keywords = { Unique = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Tangler"] = { cost = 2, tangle = "Shout_Arcana_Created_Tangle_DEBUG" },
    ["Shout_Arcana_Created_Tangle_DEBUG"] = { unplayable = true },
}

D.statusConjures = {
    ZEPHYR_STRIKE = { id = "Target_Arcana_Created_ZephyrStrike", lasts = 1 },
}

D.containers = {
    ["Target_Arcana_Created_Mimic"] = {
        "Projectile_Arcana_Created_MimicSigilofMalice",
        "Target_Arcana_Created_MimicEtherealChains",
        "Target_Arcana_Created_MimicDistortion",
    },
    ["Target_Arcana_Card_Spell_Hemoplague"] = {
        "Target_Arcana_Created_Hemoplague_BlindingSickness",
        "Target_Arcana_Created_Hemoplague_FilthFever",
        "Target_Arcana_Created_Hemoplague_FleshRot",
        "Target_Arcana_Created_Hemoplague_Mindfire",
        "Target_Arcana_Created_Hemoplague_Seizure",
        "Target_Arcana_Created_Hemoplague_SlimyDoom",
    },
}

-- A container and its children are one card: whichever side is in hand lights the other.
D.parentOf = {}
for parent, subs in pairs(D.containers) do
    for _, sub in ipairs(subs) do D.parentOf[sub] = parent end
end

-- Children of a container the deck does not care about. Faceless alone has 40-odd race/gender
-- variants: they flooded !arcanapool and cost 40 wasted lock boosts per combat. Locking them was
-- pointless anyway -- both the container and every child are already Requirements "!Combat".
-- Listed by prefix so that forgetting one only brings the noise back, never unlocks a card.
D.skipPrefixes = {
    "Shout_Arcana_Util_Faceless_",
    "Target_Arcana_Util_Faceless_",
    -- Familiars are out of the deck entirely and now carry Requirements "!Combat" in stats, so the
    -- game blocks them by itself, on console too. A lock boost on top would be redundant.
    "Target_Arcana_Util_ArcaneFamiliar_",
}

function D.Skipped(id)
    for _, p in ipairs(D.skipPrefixes) do
        if id:sub(1, #p) == p then return true end
    end
    return false
end

D.threadStartStatuses = {}

function D.Get(id)
    return D.cards[id] or EMPTY
end

function D.CostOf(id)
    return D.Get(id).cost or C.DEFAULT_COST
end

function D.Has(id, keyword)
    local k = D.Get(id).keywords
    return k ~= nil and k[keyword] == true
end

function D.ConjuresOn(id)
    return D.Get(id).conjures or EMPTY
end

return D
