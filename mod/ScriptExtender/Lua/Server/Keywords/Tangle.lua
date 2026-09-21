local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

E.On("SpellCast", function(ctx)
    local tangle = D.Get(ctx.spell).tangle
    if tangle and ctx.state.combat then P.ShuffleIntoDeck(ctx.char, ctx.state, tangle) end
end)

return true
