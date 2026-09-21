local T = Req("Tests/T.lua")
local U = Req("Server/Core/Util.lua")
local E = Req("Server/Core/Events.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")

local function ID(x) return "Shout_Arcana_Card_Spell_" .. x end
local A, B, X, Y = ID("A"), ID("B"), ID("X"), ID("Y")

-- The suite is loaded at bootstrap now, so this must not listen until the suite actually runs --
-- otherwise the live game would keep appending to drawnLog on every draw, forever.
local drawnLog = {}
local listening = false

local function state(list)
    local st = S.New()
    st.list = list or {}
    return st
end

return {
    name = "Piles",
    before = function()
        P.rand = function(n) return n end
        for i = #drawnLog, 1, -1 do drawnLog[i] = nil end
        if not listening then
            listening = true
            E.On("CardDrawn", function(ctx)
                if listening then drawnLog[#drawnLog + 1] = ctx.entry.id end
            end)
        end
    end,
    after = function() P.rand = math.random end,
    cases = {
        ["BuildDeck lists cards in name order when not shuffled"] = function()
            local st = state({ [B] = 1, [A] = 2 })
            P.BuildDeck(st)
            T.list(st.deck, { A, A, B })
        end,
        ["Draw takes the top card and emits CardDrawn"] = function()
            local st = state({ [A] = 1, [B] = 1 })
            P.BuildDeck(st)
            T.eq(P.Draw("c", st, 1), 1)
            T.eq(st.hand[1].id, B)
            T.eq(st.hand[1].conjured, false)
            T.eq(#st.deck, 1)
            T.list(drawnLog, { B })
        end,
        ["Draw reshuffles Frayed into an empty deck"] = function()
            local st = state()
            st.frayed = { A }
            T.eq(P.Draw("c", st, 1), 1)
            T.eq(st.hand[1].id, A)
            T.eq(#st.frayed, 0)
        end,
        ["Draw stops when deck and Frayed are empty"] = function()
            T.eq(P.Draw("c", state(), 3), 0)
        end,
        ["AddToHand unravels cards past the hand limit"] = function()
            local st = state()
            for i = 1, 10 do P.AddToHand("c", st, ID(i)) end
            T.eq(P.AddToHand("c", st, X), nil)
            T.eq(#st.hand, 10)
            T.list(st.unraveled, { X })
        end,
        ["Play sends a deck card to Frayed"] = function()
            local st = state()
            P.AddToHand("c", st, A)
            T.eq(P.Play("c", st, A).id, A)
            T.eq(#st.hand, 0)
            T.list(st.frayed, { A })
        end,
        ["Play sends a Conjured card to Unravel"] = function()
            local st = state()
            P.AddToHand("c", st, X, { conjured = true })
            P.Play("c", st, X)
            T.eq(#st.frayed, 0)
            T.list(st.unraveled, { X })
        end,
        ["Play matches an upcast suffix"] = function()
            local st = state()
            P.AddToHand("c", st, A)
            T.ok(P.Play("c", st, A .. "_3"))
        end,
        ["Play ignores spells that are not in hand"] = function()
            T.eq(P.Play("c", state(), A), nil)
        end,
        ["ExpireConjured removes a card when its last turn ends"] = function()
            local st = state()
            P.AddToHand("c", st, X, { conjured = true, expiresOnTurn = 3 })
            P.ExpireConjured("c", st, 2)
            T.eq(#st.hand, 1)
            P.ExpireConjured("c", st, 3)
            T.eq(#st.hand, 0)
            T.list(st.unraveled, { X })
        end,
        ["ExpireConjured drops Conjured cards whose spell is gone"] = function()
            local st = state()
            P.AddToHand("c", st, X, { conjured = true })
            P.AddToHand("c", st, Y)
            P.ExpireConjured("c", st, nil, function() return false end)
            T.eq(#st.hand, 1)
            T.eq(st.hand[1].id, Y)
        end,
        ["ReturnHandToDeck keeps what the predicate protects"] = function()
            local st = state()
            P.AddToHand("c", st, A)
            P.AddToHand("c", st, B, { conjured = true })
            T.eq(P.ReturnHandToDeck("c", st, function(e) return e.conjured end), 1)
            T.eq(#st.hand, 1)
            T.eq(st.hand[1].id, B)
            T.list(st.deck, { A })
        end,
        ["PullFromDeck removes matching cards in order"] = function()
            local st = state()
            st.deck = { A, B, A }
            T.list(P.PullFromDeck(st, function(id) return id == A end), { A, A })
            T.list(st.deck, { B })
        end,
        ["ShuffleIntoDeck adds the card"] = function()
            local st = state()
            st.deck = { A }
            P.ShuffleIntoDeck("c", st, X)
            T.eq(#st.deck, 2)
            T.ok(U.IndexOf(st.deck, X), "tangle in deck")
        end,
    },
}
