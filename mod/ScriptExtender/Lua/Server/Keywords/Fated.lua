local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")

E.On("CombatStarted", function(ctx)
    local fated = P.PullFromDeck(ctx.state, function(id) return D.Has(id, "Fated") end)
    for _, id in ipairs(fated) do P.AddToHand(ctx.char, ctx.state, id) end
end)

return true
