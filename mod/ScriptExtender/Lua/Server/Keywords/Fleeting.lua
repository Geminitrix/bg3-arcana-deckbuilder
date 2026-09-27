local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

E.On("TurnEnded", function(ctx)
    local hand = ctx.state.hand
    for i = #hand, 1, -1 do
        if D.Has(hand[i].id, "Fleeting") then
            -- the keyword's pile is only the default: a card that names its own wins
            P.RemoveFromHand(ctx.char, ctx.state, i, D.DestinationOf(hand[i].id, D.PILE_UNRAVEL), "fleeting")
        end
    end
end)

return true
