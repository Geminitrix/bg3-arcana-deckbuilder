local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local Th = Req("Server/Economy/Threads.lua")

local F = {}

function F.BeginCombat(char, st, combatId, level)
    st.combat = { id = combatId, turn = 0, binds = 0, leftover = 0, startBonus = 0,
                  level = level or C.DEFAULT_LEVEL, counters = {} }
    P.ResetForCombat(char, st)
    E.Emit("CombatStarted", { char = char, state = st })
end

function F.StartTurn(char, st, hasSpell, level)
    local c = st.combat
    if level then c.level = level end
    c.turn = c.turn + 1
    Th.Refill(char, st)
    P.ExpireConjured(char, st, nil, hasSpell)
    P.Draw(char, st, c.turn == 1 and C.OPENING_HAND or C.DRAW_PER_TURN)
    E.Emit("TurnStarted", { char = char, state = st, turn = c.turn })
end

function F.EndTurn(char, st)
    Th.RememberLeftover(char, st)
    P.ExpireConjured(char, st, st.combat.turn)
    E.Emit("TurnEnded", { char = char, state = st, turn = st.combat.turn })
end

function F.Cast(char, st, spell)
    if st.combat then P.Play(char, st, spell) end
    E.Emit("SpellCast", { char = char, state = st, spell = spell })
end

function F.StatusApplied(char, st, status)
    E.Emit("StatusApplied", { char = char, state = st, status = status })
end

function F.EndCombat(char, st)
    st.combat = nil
    st.hand, st.deck, st.frayed, st.unraveled = {}, {}, {}, {}
    E.Emit("CombatEnded", { char = char, state = st })
end

return F
