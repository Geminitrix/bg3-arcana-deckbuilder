local T = Req("Tests/T.lua")
local U = Req("Server/Core/Util.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local Th = Req("Server/Economy/Threads.lua")
local F = Req("Server/Core/Flow.lua")

local LIST = {
    Shout_Arcana_Card_Spell_A = 3, Shout_Arcana_Card_Spell_B = 3, Shout_Arcana_Card_Spell_C = 3,
    Shout_Arcana_Card_Spell_D = 3, Shout_Arcana_Card_Spell_E = 3,
}

local savedIo, value

local function yes() return true end

local function begin(level)
    local st = S.New()
    st.list = U.DeepCopy(LIST)
    F.BeginCombat("c", st, "combat-1", level)
    return st
end

local function drawnCount(st)
    local n = 0
    for _, e in ipairs(st.hand) do
        if not e.conjured then n = n + 1 end
    end
    return n
end

return {
    name = "Flow",
    before = function()
        savedIo, value = Th.io, 0
        Th.io = {
            get = function() return value end,
            set = function(_, v) value = v end,
            hasStatus = function() return false end,
        }
        P.rand = function(n) return n end
    end,
    after = function()
        Th.io = savedIo
        P.rand = math.random
    end,
    cases = {
        ["BeginCombat builds a full deck and an empty hand"] = function()
            local st = begin()
            T.eq(#st.deck, 15)
            T.eq(#st.hand, 0)
            T.eq(st.combat.turn, 0)
            T.eq(st.combat.id, "combat-1")
        end,
        ["Turn 1 draws 4 and gives the band's first value"] = function()
            local st = begin(7)
            F.StartTurn("c", st, yes)
            T.eq(st.combat.turn, 1)
            T.eq(st.combat.level, 7)
            T.eq(drawnCount(st), 4)
            T.eq(value, 2, "level 7 turn 1")
        end,
        ["Later turns draw 1 and carry two Spare Threads"] = function()
            local st = begin(7)
            F.StartTurn("c", st, yes)
            value = 2
            F.EndTurn("c", st)
            F.StartTurn("c", st, yes)
            T.eq(drawnCount(st), 5)
            T.eq(value, 5, "level 7 turn 2 + reserve 2")
        end,
        ["StartTurn refreshes the level"] = function()
            local st = begin(1)
            F.StartTurn("c", st, yes, 9)
            T.eq(st.combat.level, 9)
            T.eq(value, 3)
        end,
        ["Cast moves a hand card to Frayed"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            F.Cast("c", st, "Shout_Arcana_Card_Spell_E")
            T.eq(drawnCount(st), 3)
            T.list(st.frayed, { "Shout_Arcana_Card_Spell_E" })
        end,
        ["Cast out of combat touches no pile"] = function()
            local st = S.New()
            F.Cast("c", st, "Shout_Arcana_Card_Spell_A")
            T.eq(#st.frayed, 0)
            T.eq(#st.hand, 0)
        end,
        ["EndCombat clears the combat and the piles"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            F.EndCombat("c", st)
            T.eq(st.combat, nil)
            T.eq(#st.hand, 0)
            T.eq(#st.deck, 0)
        end,
    },
}
