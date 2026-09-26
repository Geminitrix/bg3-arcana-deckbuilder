-- Threads and the hand counter only exist during a fight, and only on the SE edition.
--
-- Until 2026-09-26 the level 1 progression granted both, so every Arcana carried 6 Threads and a
-- 22-card counter around outside combat -- and the console edition, which has no deck, showed two
-- resources it can never use. Now nothing in the stats grants them: this module adds them as boosts
-- when the character's combat starts and takes them away when it ends. Out of combat they are not
-- on the resource panel at all.
--
-- The engine applies a boost a tick after AddBoosts, so the resource may not exist yet when the
-- first turn refills it. Threads.lua and Resources.lua retry once for that reason.
local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")

local CR = { io = {} }

-- Osi is an empty table in the offline test runner; the tests replace io anyway.
function CR.io.add(char, boost)
    if Osi.AddBoosts then Osi.AddBoosts(char, boost, C.BOOST_SOURCE, char) end
end

function CR.io.remove(char, boost)
    if Osi.RemoveBoosts then Osi.RemoveBoosts(char, boost, 0, C.BOOST_SOURCE, char) end
end

function CR.Grant(char)
    for _, boost in ipairs(C.COMBAT_RESOURCES) do
        -- BeginCombat can run twice for one fight (EnteredCombat, then a TurnStarted that found no
        -- combat state); a second copy of the boost would double the maximum.
        CR.io.remove(char, boost)
        CR.io.add(char, boost)
    end
end

function CR.Revoke(char)
    for _, boost in ipairs(C.COMBAT_RESOURCES) do CR.io.remove(char, boost) end
end

E.On("CombatStarted", function(ctx) CR.Grant(ctx.char) end)
E.On("CombatEnded", function(ctx) CR.Revoke(ctx.char) end)

return CR
