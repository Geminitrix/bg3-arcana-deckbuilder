local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")
local F = Req("Server/Core/Flow.lua")
local R = Req("Server/Economy/Reactions.lua")

local GALE = "Shout_Arcana_Card_Passive_GaleDeflection"
local HOLLOW = "Shout_Arcana_Card_Passive_HollowImage"

local CHAR = "char-reactions"
local log, savedIo

local function inCombat()
    local st = S.New()
    st.combat = { id = "c1", turn = 0, binds = 0, leftover = 0, startBonus = 0, level = 11, counters = {} }
    return st
end

local function valueOf(resource)
    local last
    for _, e in ipairs(log) do if e.resource == resource then last = e.value end end
    return last
end

return {
    name = "Reactions",
    before = function()
        savedIo = R.io
        log = {}
        R.io = { set = function(char, resource, value)
            log[#log + 1] = { char = char, resource = resource, value = value }
            return true
        end }
    end,
    after = function() R.io = savedIo end,
    cases = {
        ["Combat zeroes every reaction resource"] = function()
            local st = inCombat()
            T.eq(R.Zero(CHAR, st), 3)
            T.eq(valueOf("ArcanaReactGaleDeflection"), 0)
            T.eq(valueOf("ArcanaReactInstinctiveCharm"), 0)
            T.eq(valueOf("ArcanaReactHollowImage"), 0)
        end,
        ["Only the per-turn resource is zeroed again each turn"] = function()
            local st = inCombat()
            R.Zero(CHAR, st)
            log = {}
            T.eq(R.OnTurnStart(CHAR, st), 1, "only Hollow Image recharges per turn")
            T.eq(valueOf("ArcanaReactHollowImage"), 0)
            T.eq(valueOf("ArcanaReactGaleDeflection"), nil, "the others are left alone")
        end,
        ["Playing the activation card stops the zeroing"] = function()
            local st = inCombat()
            T.eq(R.Activate(st, HOLLOW), true)
            T.eq(R.IsActive(st, HOLLOW), true)
            log = {}
            T.eq(R.OnTurnStart(CHAR, st), 0, "an activated reaction is left alone")
            T.eq(R.Zero(CHAR, st), 2, "and it is not re-zeroed either")
        end,
        ["A card that is not an activation card activates nothing"] = function()
            local st = inCombat()
            T.eq(R.Activate(st, "Target_Arcana_Card_Spell_Distortion"), false)
            T.eq(R.IsActive(st, "Target_Arcana_Card_Spell_Distortion"), false)
        end,
        ["The end of combat gives every reaction back"] = function()
            R.RestoreAll(CHAR)
            T.eq(valueOf("ArcanaReactGaleDeflection"), 1)
            T.eq(valueOf("ArcanaReactHollowImage"), 1)
            T.eq(#log, 3)
        end,
        ["Out of combat nothing is zeroed"] = function()
            T.eq(R.Zero(CHAR, S.New()), 0)
            T.eq(R.OnTurnStart(CHAR, S.New()), 0)
        end,
        ["The flow wires it up: combat zeroes, the end restores"] = function()
            local st = S.New()
            F.BeginCombat(CHAR, st, "c9", 11)
            T.eq(valueOf("ArcanaReactGaleDeflection"), 0, "zeroed by CombatStarted")
            F.EndCombat(CHAR, st)
            T.eq(valueOf("ArcanaReactGaleDeflection"), 1, "restored by CombatEnded")
        end,
    },
}
