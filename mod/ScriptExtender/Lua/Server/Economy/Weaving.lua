-- ARCANA_WEAVING is what turns slot costs into Thread costs, generically, for the whole combat.
-- It only ever exists on the SE edition: the console build has no Lua to apply it, so its cards
-- keep paying ArcanaSpellSlotsGroup from their own UseCosts, exactly as written.
local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")

local W = { io = {} }

function W.io.apply(char)
    Osi.ApplyStatus(char, C.WEAVING_STATUS, -1, 1, char)
end

function W.io.remove(char)
    Osi.RemoveStatus(char, C.WEAVING_STATUS)
end

E.On("CombatStarted", function(ctx) W.io.apply(ctx.char) end)
E.On("CombatEnded", function(ctx) W.io.remove(ctx.char) end)

return W
