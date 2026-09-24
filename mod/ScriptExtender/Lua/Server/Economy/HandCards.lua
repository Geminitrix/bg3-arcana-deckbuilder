-- ArcanaHandCard is the hand made visible: a resource next to the spell slots whose value is how
-- many cards you are holding. Every card costs 1 of it, so the engine itself refuses a card once the
-- hand is empty, and the count is on screen instead of buried in !arcana.
--
-- The engine no longer spends it: ArcanaHandCard left the cards' UseCosts on 2026-09-24, because an
-- extra resource in the cost stopped the engine from collapsing a card into its upcast variant. So
-- this module is the only writer, and always was in practice: after anything that changes the hand,
-- the value is set to exactly #hand. What refuses a card that is not in hand is the lock boost
-- (ArcanaNotInHand), not the cost.
local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")
local Rs = Req("Server/Economy/Resources.lua")

local H = { io = { set = function(char, value) return Rs.Set(char, C.RES_HAND_CARD, value) end } }

function H.Sync(char, st)
    local n = st and st.hand and #st.hand or 0
    H.io.set(char, n)
    return n
end

-- Out of combat there is no hand, so the resource goes back to full: it must never be what stops a
-- card from being cast outside a fight, and on the console edition nothing else would refill it.
function H.Release(char)
    H.io.set(char, C.HAND_MAX)
end

for _, event in ipairs({ "CardDrawn", "CardAdded", "CardPlayed", "CardUnraveled", "CombatStarted", "TurnStarted" }) do
    E.On(event, function(ctx) H.Sync(ctx.char, ctx.state) end)
end

E.On("CombatEnded", function(ctx) H.Release(ctx.char) end)

return H
