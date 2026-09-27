local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")
local E = Req("Server/Core/Events.lua")
local L = Req("Server/Deck/List.lua")
Req("Server/Keywords/Fleeting.lua")
Req("Server/Keywords/Unique.lua")

-- The rule these cases pin down: a card that names its pile (`destination`) goes there, whatever
-- moved it. Keywords and mechanics only decide for cards that say nothing.
local PLAIN = "Shout_Arcana_Card_Spell_DestA"
local STAYS = "Shout_Arcana_Card_Spell_DestB"         -- names the discard
local GOES = "Shout_Arcana_Card_Spell_DestC"          -- names the exile
local FLEETING_STAYS = "Shout_Arcana_Card_Spell_DestD" -- Fleeting, but names the discard

local function combatState()
    local st = S.New()
    st.combat = { id = "c", turn = 1, binds = 0, leftover = 0, startBonus = 0, level = 1, counters = {} }
    return st
end

local function has(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end

return {
    name = "Destination",
    before = function()
        D.cards[STAYS] = { destination = D.PILE_FRAYED }
        D.cards[GOES] = { destination = D.PILE_UNRAVEL }
        D.cards[FLEETING_STAYS] = { keywords = { Fleeting = true }, destination = D.PILE_FRAYED }
    end,
    after = function()
        D.cards[STAYS], D.cards[GOES], D.cards[FLEETING_STAYS] = nil, nil, nil
    end,
    cases = {
        ["Played: the card's pile beats the default"] = function()
            local st = combatState()
            st.hand = { { id = PLAIN }, { id = GOES } }
            P.Play("c", st, PLAIN)
            P.Play("c", st, GOES)
            T.ok(has(st.frayed, PLAIN), "no attribute: the discard")
            T.ok(has(st.unraveled, GOES), "the card asked for the exile")
        end,
        ["Played conjured: the card's pile beats the conjured rule"] = function()
            local st = combatState()
            st.hand = { { id = STAYS, conjured = true } }
            P.Play("c", st, STAYS)
            T.ok(has(st.frayed, STAYS))
            T.eq(#st.unraveled, 0)
        end,
        ["Fleeting: the card's pile beats the keyword"] = function()
            local st = combatState()
            st.hand = { { id = FLEETING_STAYS } }
            E.Emit("TurnEnded", { char = "c", state = st, turn = 1 })
            T.eq(#st.hand, 0, "Fleeting still clears it from the hand")
            T.ok(has(st.frayed, FLEETING_STAYS), "but it goes where the card says")
            T.eq(#st.unraveled, 0)
        end,
        ["Mirrored Spell: Unique, and played straight to the exile"] = function()
            local id = "Shout_Arcana_Card_Passive_MirroredSpell"
            T.eq(L.MaxCopies(id), 1)
            T.eq(D.PlayedTo(id, false), D.PILE_UNRAVEL, "its status lasts until the long rest")
        end,
        ["Cards with a cooldown of their own are Unique"] = function()
            for _, id in ipairs({
                "Target_Arcana_Card_Spell_MentalPrison", "Target_Arcana_Card_Spell_Marionette",
                "Target_Arcana_Card_Spell_SolarPurge", "Teleportation_Arcana_Card_Spell_Starbreath",
                "Shout_Arcana_Card_Spell_StellarGrace", "Shout_Arcana_Card_Spell_Wish",
            }) do T.eq(L.MaxCopies(id), 1, id) end
        end,
        ["Solar Flare and Final Spark, with no cooldown, can run three copies"] = function()
            T.eq(L.MaxCopies("Target_Arcana_Card_Spell_SolarFlare"), 3)
            T.eq(L.MaxCopies("Zone_Arcana_Card_Spell_FinalSpark"), 3)
        end,
        ["Lunar Wisp: Unique, and played straight to the exile"] = function()
            local id = "Shout_Arcana_Card_Passive_LunarWisp"
            T.eq(L.MaxCopies(id), 1)
            T.eq(D.PlayedTo(id, false), D.PILE_UNRAVEL)
        end,
        ["A conjured card running out: the card's pile beats the default"] = function()
            local st = combatState()
            st.hand = { { id = STAYS, conjured = true, expiresOnTurn = 1 }, { id = PLAIN, conjured = true, expiresOnTurn = 1 } }
            P.ExpireConjured("c", st, 1)
            T.ok(has(st.frayed, STAYS), "named the discard")
            T.ok(has(st.unraveled, PLAIN), "no attribute: the exile, as before")
        end,
    },
}
