local C = Req("Server/Core/Const.lua")

local D = {}
local EMPTY = {}

-- The two piles a card can go to (see D.DestinationOf): the discard and the exile.
D.PILE_FRAYED, D.PILE_UNRAVEL = "frayed", "unravel"

-- cost = Threads spent in combat. Rule: X = the card's level, no exceptions.
-- The engine is what actually charges it. Out of combat a card costs one SpellSlotsGroup slot of its own level (the group now holds ArcanaSpellSlot);
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
    -- level 1 and no slot since 2026-09-27: one Thread in combat, free outside
    ["Zone_Arcana_Created_FinalSpark_Recreate"] = { aspect = "Starchild", cost = 1 },
    ["Target_Arcana_Created_ZephyrStrike"] = { aspect = "Unbound", cost = 1 },
    ["Shout_Arcana_Created_Reweave"] = { cost = 0 },

    -- A cantrip has no slot cost, so ARCANA_WEAVING has nothing to zero on it and only adds: it is
    -- the one case that tests the Add half of the mechanism on its own. 1 Thread, like any card.
    ["Target_Arcana_Card_Spell_MaliciousWhispers"] = { aspect = "Deceiver", cost = 1 },
    ["Shout_Arcana_Card_Spell_HowlOfTheDead"] = { aspect = "Eternal", cost = 1 },

    -- Reaction cards: see D.reactions. Gale Deflection can be used up to 3 times a round, so it takes
    -- three copies.
    ["Shout_Arcana_Card_Passive_GaleDeflection"] = { aspect = "Unbound", cost = 2 },

    -- Spells with a cooldown of their own: a second copy would only ever be drawn dead.
    ["Target_Arcana_Card_Spell_VeiledPrison"] = { aspect = "Deceiver", keywords = { Unique = true } },
    ["Target_Arcana_Card_Spell_Marionette"] = { aspect = "Deceiver", keywords = { Unique = true } },
    ["Shout_Arcana_Card_Spell_GrandDeception"] = { aspect = "Deceiver", keywords = { Unique = true } },
    ["Target_Arcana_Card_Spell_SolarPurge"] = { aspect = "Starchild", keywords = { Unique = true } },
    ["Teleportation_Arcana_Card_Spell_Starbreath"] = { aspect = "Starchild", keywords = { Unique = true } },
    ["Shout_Arcana_Card_Spell_StellarGrace"] = { aspect = "Starchild", keywords = { Unique = true } },
    -- once per combat, not per rest: still a dead second copy in the same fight
    ["Shout_Arcana_Card_Spell_Wish"] = { aspect = "Starchild", keywords = { Unique = true } },
    -- Solar Flare and Final Spark lost their cooldowns on 2026-09-27 so they can run three copies;
    -- their damage is to be tuned down for it.

    -- Their status lasts until the next long rest, so once played they have nothing left to do in
    -- this fight: straight to the exile.
    ["Shout_Arcana_Card_Passive_MirroredSpell"] = {
        aspect = "Deceiver", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Shout_Arcana_Card_Passive_LunarWisp"] = {
        aspect = "Starchild", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Shout_Arcana_Card_Passive_ImmortalBlood"] = {
        aspect = "Eternal", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Shout_Arcana_Card_Passive_InescapableDestruction"] = {
        aspect = "Eternal", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Shout_Arcana_Card_Passive_Unbroken"] = {
        aspect = "Eternal", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Shout_Arcana_Card_Passive_InuredToUndeath"] = {
        aspect = "Eternal", keywords = { Unique = true }, destination = D.PILE_UNRAVEL,
    },
    ["Target_Arcana_Card_Spell_DeathWard"] = { aspect = "Eternal", keywords = { Unique = true } },
    -- Blood Offering replaced the Darkness Rise card on 2026-09-28: Darkness Rise is now Tier I of the
    -- Eternal's Aspect. A normal spell card, so it goes back to the discard.
    ["Shout_Arcana_Card_Spell_BloodOffering"] = { aspect = "Eternal" },

    -- Aspect cards (2026-09-28): created when the subclass awakens its Aspect (ASPECT_AWAKENED_*, see
    -- D.statusConjures). Level 0 and no slot, so they cost no Threads; being conjured sends them to the
    -- exile, and the engine's own OncePerCombat cooldown does the same job on the console.
    ["Rush_Arcana_Created_Aspect_LeapOfFaith"] = { aspect = "Unbound" },
    ["Shout_Arcana_Created_Aspect_Heartbreak"] = { aspect = "Deceiver" },
    ["Shout_Arcana_Created_Aspect_WishUponAStar"] = { aspect = "Starchild" },
    ["Target_Arcana_Created_Aspect_FinalToll"] = { aspect = "Eternal" },

    ["Shout_Arcana_Card_Spell_DEBUG_Fated"] = { keywords = { Fated = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Fleeting"] = { keywords = { Fleeting = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Unique"] = { keywords = { Unique = true } },
    ["Shout_Arcana_Card_Spell_DEBUG_Tangler"] = { cost = 2, tangle = "Shout_Arcana_Created_Tangle_DEBUG" },
    ["Shout_Arcana_Created_Tangle_DEBUG"] = { unplayable = true },
}

D.statusConjures = {
    ZEPHYR_STRIKE = { id = "Target_Arcana_Created_ZephyrStrike", lasts = 1 },
    -- the Aspect card stays playable for the rest of the fight
    ASPECT_AWAKENED_FOOL = { id = "Rush_Arcana_Created_Aspect_LeapOfFaith", lasts = 99 },
    ASPECT_AWAKENED_EMPRESS = { id = "Shout_Arcana_Created_Aspect_Heartbreak", lasts = 99 },
    ASPECT_AWAKENED_STAR = { id = "Shout_Arcana_Created_Aspect_WishUponAStar", lasts = 99 },
    ASPECT_AWAKENED_DEATH = { id = "Target_Arcana_Created_Aspect_FinalToll", lasts = 99 },
}

-- Reaction cards (2026-09-30). Both editions share one rule: a reaction has a limit of uses per round,
-- which is also the maximum of its own resource, and every use takes one charge.
--   * console: the card is cast as a Shout. It applies `ready` (which unlocks the interrupt) and adds
--     one charge, up to the limit.
--   * SE: the card is never cast (its RequirementConditions refuse it under ARCANA_WEAVING). Holding it
--     IS the charge: Economy/Reactions.lua keeps `ready` on while a copy is in hand and sets the
--     resource to the copies in hand, capped by what is left of the round's limit. Using the reaction
--     applies `used` (from the interrupt's own Properties), which discards one copy.
D.reactions = {
    ["Shout_Arcana_Card_Passive_GaleDeflection"] = {
        ready = "GALE_DEFLECTION_READY", resource = "ArcanaReactGaleDeflection",
        used = "GALE_DEFLECTION_USED_TECH", perRound = 3,
    },
}

-- `used` status -> the card it belongs to
D.reactionByUsed = {}
for id, r in pairs(D.reactions) do D.reactionByUsed[r.used] = id end

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

-- Magias do jogo base que as listas da classe concedem. Nao sao cartas -- nao tem a marca
-- ARCANA_IS_CARD e nao entram no baralho --, mas em combate so se joga carta, entao elas sao
-- trancadas junto com as utilitarias. Fonte: as entradas sem prefixo proprio em
-- Public/<Mod>/Lists/SpellLists.lsx; conferir esta lista ao mexer nas listas de magia.
D.vanillaGranted = {
    ["Target_Light"]       = true,
    ["Target_TrueStrike"]  = true,
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

-- Quem cobra de verdade e o ARCANA_WEAVING, e ele cobra IsSpellLevel(n) Threads -- ou seja, o Level
-- da magia. Ler o Level e a unica forma de a previsao nao mentir: a tabela abaixo estava dizendo 1
-- para o Olhar Hipnotico, que e nivel 2. A tabela fica so como rede para o que os testes offline
-- rodam sem Ext.
D.io = {
    spellLevel = function(id)
        local ok, stat = pcall(function() return Ext.Stats.Get(id) end)
        if not ok or stat == nil then return nil end
        local lvl = tonumber(stat.Level)
        if lvl == nil or lvl < 0 then return nil end
        return lvl
    end,
    -- SpellFlags comes back as a list of names; a string is accepted too, to be safe
    spellFlags = function(id)
        local ok, flags = pcall(function()
            local stat = Ext.Stats.Get(id)
            return stat and stat.SpellFlags
        end)
        if not ok then return nil end
        return flags
    end,
}

-- Asked for every spell in the spellbook on every sync, and a spell's flags never change during a
-- session, so the answer is kept.
local weaponAction = {}

function D.IsWeaponAction(id)
    local known = weaponAction[id]
    if known ~= nil then return known end
    local flags, yes = D.io.spellFlags(id), false
    if type(flags) == "string" then
        yes = flags:find(C.WEAPON_ACTION_FLAG, 1, true) ~= nil
    elseif flags ~= nil then
        for _, f in ipairs(flags) do
            if f == C.WEAPON_ACTION_FLAG then yes = true; break end
        end
    end
    weaponAction[id] = yes
    return yes
end

-- for the tests, which swap D.io between cases
function D.ForgetWeaponActions() weaponAction = {} end

function D.CostOf(id)
    -- A weapon action already costs its action or bonus action; the card in hand is the limit.
    if D.IsWeaponAction(id) then return 0 end
    local lvl = D.io.spellLevel(id)
    if lvl ~= nil then return lvl end
    return D.Get(id).cost or C.DEFAULT_COST
end

-- Where a card goes when it leaves the hand for a pile: "frayed" (the discard, shuffled back into
-- the deck when it runs out) or "unravel" (the exile, gone for the rest of the fight).
--
-- THE CARD WINS. A card that names its pile with `destination` in D.cards goes there, whatever put
-- it in motion: being played, a keyword that clears it from the hand (Fleeting at the end of the
-- turn), or a conjured card running out of turns. Keywords and mechanics only supply the default
-- for cards that say nothing. Every move from hand to a pile asks here -- none may hard-code one.
--
-- Two moves are not destinations and stay outside this: a card that overflows the hand never
-- entered it (always exiled), and Reweave returns the hand to the deck (a mulligan, not a pile).
-- (D.PILE_FRAYED / D.PILE_UNRAVEL are defined at the top, before D.cards uses them.)

function D.DestinationOf(id, default)
    return D.Get(id).destination or default
end

-- Default when played:
--   * a weapon action goes to the exile: the game's own cooldown (once per short rest) means it
--     could not be cast again this fight, so shuffling it back would only hand over a dead card;
--   * a conjured card goes to the exile;
--   * everything else goes to the discard.
function D.PlayedTo(id, conjured)
    local default = (conjured or D.IsWeaponAction(id)) and D.PILE_UNRAVEL or D.PILE_FRAYED
    return D.DestinationOf(id, default)
end

function D.Has(id, keyword)
    local k = D.Get(id).keywords
    return k ~= nil and k[keyword] == true
end

function D.ConjuresOn(id)
    return D.Get(id).conjures or EMPTY
end

return D
