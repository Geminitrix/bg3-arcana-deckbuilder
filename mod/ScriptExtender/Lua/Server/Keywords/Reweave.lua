local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

E.On("TurnStarted", function(ctx)
    if ctx.turn == 1 then
        P.AddToHand(ctx.char, ctx.state, C.REWEAVE_TOKEN, { conjured = true, expiresOnTurn = 1 })
    end
end)

E.On("CardPlayed", function(ctx)
    if ctx.entry.id ~= C.REWEAVE_TOKEN then return end
    local returned = P.ReturnHandToDeck(ctx.char, ctx.state, function(e)
        return e.conjured or D.Has(e.id, "Fated")
    end)
    P.Draw(ctx.char, ctx.state, returned)
end)

return true
