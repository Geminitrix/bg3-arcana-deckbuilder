local T = Req("Tests/T.lua")
local D = Req("Server/Cards/CardDB.lua")
local Th = Req("Server/Economy/Threads.lua")

local savedIo, value, statuses

local function combat(turn, leftover, binds, bonus)
    return { combat = { turn = turn, leftover = leftover or 0, binds = binds or 0, startBonus = bonus or 0 } }
end

return {
    name = "Threads",
    before = function()
        savedIo, value, statuses = Th.io, 0, {}
        Th.io = {
            get = function() return value end,
            set = function(_, v) value = v end,
            hasStatus = function(_, s) return statuses[s] == true end,
        }
    end,
    after = function()
        Th.io = savedIo
        D.threadStartStatuses.TEST_THREAD_BONUS = nil
    end,
    cases = {
        ["Compute follows the level band"] = function()
            T.eq(Th.Compute(combat(1).combat), 1, "level 1 turn 1")
            T.eq(Th.Compute(combat(5).combat), 1, "level 1 turn 5")
            local six = combat(1); six.combat.level = 6
            T.eq(Th.Compute(six.combat), 1, "level 6 turn 1")
            six.combat.turn = 3
            T.eq(Th.Compute(six.combat), 3, "level 6 turn 3")
            six.combat.turn = 9
            T.eq(Th.Compute(six.combat), 3, "level 6 turn 9")
            local thirteen = combat(1); thirteen.combat.level = 13
            T.eq(Th.Compute(thirteen.combat), 4, "level 13 turn 1")
            thirteen.combat.turn = 3
            T.eq(Th.Compute(thirteen.combat), 6, "level 13 turn 3")
        end,
        ["BandFor clamps outside the table"] = function()
            T.eq(Th.BandFor(nil).ceiling, 1)
            T.eq(Th.BandFor(99).ceiling, 6)
        end,
        ["Binds and bonuses go above the band ceiling"] = function()
            T.eq(Th.Compute(combat(1, 0, 2).combat), 3, "level 1, 2 binds")
            T.eq(Th.Compute(combat(1, 0, 0, 2).combat), 3, "level 1, start bonus 2")
        end,
        ["Compute adds at most two Spare Threads"] = function()
            local st = combat(2, 3); st.combat.level = 7
            T.eq(Th.Compute(st.combat), 5, "level 7 turn 2 + reserve 2")
        end,
        ["Compute never passes 6"] = function()
            local st = combat(3, 2, 2, 2); st.combat.level = 13
            T.eq(Th.Compute(st.combat), 6)
        end,
        ["Refill writes the value and consumes the start bonus"] = function()
            local st = combat(1, 0, 0, 2)
            T.eq(Th.Refill("c", st), 3)
            T.eq(value, 3)
            T.eq(st.combat.startBonus, 0)
        end,
        ["Refill adds start-of-turn statuses"] = function()
            D.threadStartStatuses.TEST_THREAD_BONUS = 1
            statuses.TEST_THREAD_BONUS = true
            T.eq(Th.Refill("c", combat(1)), 2)
        end,
        ["RememberLeftover stores the unspent amount"] = function()
            value = 2
            local st = combat(3)
            Th.RememberLeftover("c", st)
            T.eq(st.combat.leftover, 2)
        end,
        ["Gain is capped at 6"] = function()
            value = 5
            Th.Gain("c", 4)
            T.eq(value, 6)
        end,
    },
}
