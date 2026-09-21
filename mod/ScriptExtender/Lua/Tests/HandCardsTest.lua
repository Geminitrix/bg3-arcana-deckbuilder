local T = Req("Tests/T.lua")
local C = Req("Server/Core/Const.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local F = Req("Server/Core/Flow.lua")
local Th = Req("Server/Economy/Threads.lua")
local H = Req("Server/Economy/HandCards.lua")

local CHAR = "char-handcards"
local CARD = "Shout_Arcana_Card_Spell_A"
local last, savedIo, savedThreadIo

local function inCombat(list)
    local st = S.New()
    st.list = list or {}
    st.combat = { id = "c1", turn = 0, binds = 0, leftover = 0, startBonus = 0, level = 1, counters = {} }
    st.hand, st.frayed, st.unraveled = {}, {}, {}
    return st
end

return {
    name = "HandCards",
    before = function()
        savedIo, savedThreadIo = H.io, Th.io
        last = nil
        H.io = { set = function(_, value) last = value; return true end }
        -- Threads reach for Ext.Entity, which the offline runner has no answer for
        local threads = 0
        Th.io = {
            get = function() return threads end,
            set = function(_, v) threads = v end,
            hasStatus = function() return false end,
        }
        P.rand = function(n) return n end
    end,
    after = function() H.io, Th.io = savedIo, savedThreadIo; P.rand = math.random end,
    cases = {
        ["The resource follows the hand card for card"] = function()
            local st = inCombat({ [CARD] = 3 })
            P.BuildDeck(st)
            P.Draw(CHAR, st, 2)
            T.eq(last, 2, "two drawn")
            P.Draw(CHAR, st, 1)
            T.eq(last, 3, "three in hand")
            P.Play(CHAR, st, CARD)
            T.eq(last, 2, "one played")
        end,
        ["An empty hand reads zero"] = function()
            T.eq(H.Sync(CHAR, inCombat()), 0)
            T.eq(last, 0)
        end,
        ["The end of combat hands the resource back in full"] = function()
            H.Release(CHAR)
            T.eq(last, C.HAND_MAX, "so a card is never blocked outside a fight")
        end,
        ["The flow wires it up"] = function()
            local st = S.New()
            st.list = { [CARD] = 6 }
            F.BeginCombat(CHAR, st, "c9", 1)
            T.eq(last, 0, "combat starts with an empty hand")
            F.StartTurn(CHAR, st, function() return true end, 1)
            T.eq(last, #st.hand, "the opening hand is counted")
            T.ok(last > 0, "and it is not zero")
            F.EndCombat(CHAR, st)
            T.eq(last, C.HAND_MAX, "released when the fight ends")
        end,
    },
}
