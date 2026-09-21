local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")
local L = Req("Server/Deck/List.lua")
Req("Server/Keywords/Unique.lua")

local POOL = {
    "Shout_Arcana_Card_Spell_A", "Shout_Arcana_Card_Spell_B", "Shout_Arcana_Card_Spell_C",
    "Shout_Arcana_Card_Spell_D", "Shout_Arcana_Card_Spell_E", "Shout_Arcana_Card_Spell_F",
}
local UNIQUE = "Shout_Arcana_Card_Spell_DEBUG_Unique"

-- 4 titles x 3 copies = 12 cards
local function fullDeck()
    local st = S.New()
    st.list = L.Default({ table.unpack(POOL, 1, 4) })
    st.list[POOL[5]] = 0
    st.list[POOL[6]] = 0
    return st
end

return {
    name = "List",
    cases = {
        ["MaxCopies is 3, or 1 for Unique cards"] = function()
            T.eq(L.MaxCopies(POOL[1]), 3)
            T.eq(L.MaxCopies(UNIQUE), 1)
        end,
        ["Fated cards are always Unique"] = function()
            T.eq(L.MaxCopies("Shout_Arcana_Card_Spell_DEBUG_Fated"), 1)
        end,
        ["Default gives every card its maximum"] = function()
            local list = L.Default({ POOL[1], UNIQUE })
            T.eq(list[POOL[1]], 3)
            T.eq(list[UNIQUE], 1)
            T.eq(L.Size(list), 4)
        end,
        ["Refresh adds new cards and keeps edited counts"] = function()
            local st = S.New()
            st.list[POOL[1]] = 1
            L.Refresh(st, { POOL[1], POOL[2] })
            T.eq(st.list[POOL[1]], 1)
            T.eq(st.list[POOL[2]], 3)
        end,
        ["MinDeck is 10 up to level 8 and 15 from 9"] = function()
            T.eq(L.MinDeck(1), 10)
            T.eq(L.MinDeck(8), 10)
            T.eq(L.MinDeck(9), 15)
            T.eq(L.MinDeck(nil), 10)
            T.eq(L.MinDeck(99), 15)
        end,
        ["SetCount clamps to the card maximum"] = function()
            local st = fullDeck()
            local ok, n = L.SetCount(st, POOL, POOL[5], 9, 1)
            T.eq(ok, true)
            T.eq(n, 3)
            T.eq(st.list[POOL[5]], 3)
        end,
        ["SetCount refuses to go below the minimum deck"] = function()
            local st = fullDeck()
            T.eq((L.SetCount(st, POOL, POOL[1], 0, 1)), false, "would leave 9 at level 1")
            T.eq(st.list[POOL[1]], 3)
            T.eq((L.SetCount(st, POOL, POOL[1], 1, 1)), true, "10 is allowed at level 1")
        end,
        ["The minimum is stricter from level 9"] = function()
            local st = fullDeck()
            T.eq((L.SetCount(st, POOL, POOL[5], 3, 9)), true, "15 at level 9")
            T.eq((L.SetCount(st, POOL, POOL[5], 2, 9)), false, "14 is refused at level 9")
        end,
        ["SetCount refuses cards outside the pool"] = function()
            T.eq((L.SetCount(fullDeck(), POOL, "Shout_Arcana_Card_Spell_Z", 1)), false)
        end,
        ["SetCount refuses during combat"] = function()
            local st = fullDeck()
            st.combat = { turn = 1 }
            T.eq((L.SetCount(st, POOL, POOL[6], 1)), false)
        end,
    },
}
