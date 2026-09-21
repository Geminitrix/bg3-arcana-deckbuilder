local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

local function conjure(ctx, cards)
    local turn = ctx.state.combat.turn
    for _, card in ipairs(cards) do
        P.AddToHand(ctx.char, ctx.state, card.id, { conjured = true, expiresOnTurn = turn + card.lasts - 1 })
    end
end

E.On("SpellCast", function(ctx)
    if ctx.state.combat then conjure(ctx, D.ConjuresOn(ctx.spell)) end
end)

E.On("StatusApplied", function(ctx)
    local card = D.statusConjures[ctx.status]
    if card and ctx.state.combat then conjure(ctx, { card }) end
end)

return true
