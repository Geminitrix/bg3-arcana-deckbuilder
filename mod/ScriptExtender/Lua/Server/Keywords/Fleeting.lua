local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

E.On("TurnEnded", function(ctx)
    local hand = ctx.state.hand
    for i = #hand, 1, -1 do
        if D.Has(hand[i].id, "Fleeting") then
            P.RemoveFromHand(ctx.char, ctx.state, i, "unravel", "fleeting")
        end
    end
end)

return true
