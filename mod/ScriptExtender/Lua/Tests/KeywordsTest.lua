local T = Req("Tests/T.lua")
local C = Req("Server/Core/Const.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local Th = Req("Server/Economy/Threads.lua")
local F = Req("Server/Core/Flow.lua")
for _, kw in ipairs({ "Fated", "Fleeting", "Unique", "Conjured", "Reweave", "Tangle" }) do
    Req("Server/Keywords/" .. kw .. ".lua")
end

local FATED = "Shout_Arcana_Card_Spell_DEBUG_Fated"
local FLEETING = "Shout_Arcana_Card_Spell_DEBUG_Fleeting"
local TANGLER = "Shout_Arcana_Card_Spell_DEBUG_Tangler"
local TANGLE = "Shout_Arcana_Created_Tangle_DEBUG"
local DISTORTION = "Target_Arcana_Card_Spell_Distortion"
local WITHDRAW = "Shout_Arcana_Created_Withdraw"
local MIMIC_DISTORTION = "Target_Arcana_Created_MimicDistortion"
local ZEPHYR = "Target_Arcana_Created_ZephyrStrike"

local savedIo

local function yes() return true end

local function begin(extra)
    local st = S.New()
    st.list = {
        Shout_Arcana_Card_Spell_A = 3, Shout_Arcana_Card_Spell_B = 3, Shout_Arcana_Card_Spell_C = 3,
        Shout_Arcana_Card_Spell_D = 3, Shout_Arcana_Card_Spell_E = 3,
    }
    for id, n in pairs(extra or {}) do st.list[id] = n end
    F.BeginCombat("c", st, "combat-1")
    return st
end

local function count(list, id)
    local n = 0
    for _, v in ipairs(list) do
        if (type(v) == "table" and v.id or v) == id then n = n + 1 end
    end
    return n
end

local function nextTurn(st)
    F.EndTurn("c", st)
    F.StartTurn("c", st, yes)
end

return {
    name = "Keywords",
    before = function()
        savedIo = Th.io
        Th.io = { get = function() return 0 end, set = function() end, hasStatus = function() return false end }
        P.rand = function(n) return n end
    end,
    after = function()
        Th.io = savedIo
        P.rand = math.random
    end,
    cases = {
        ["Fated cards start in hand, outside the draw"] = function()
            local st = begin({ [FATED] = 1 })
            T.eq(count(st.hand, FATED), 1)
            T.eq(count(st.deck, FATED), 0)
            F.StartTurn("c", st, yes)
            T.eq(#st.hand, 6, "fated + 4 drawn + reweave")
        end,
        ["Fleeting cards unravel at the end of the turn"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            P.AddToHand("c", st, FLEETING)
            F.EndTurn("c", st)
            T.eq(count(st.hand, FLEETING), 0)
            T.eq(count(st.unraveled, FLEETING), 1)
        end,
        ["Distortion conjures Withdraw and Mimic Distortion"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            F.Cast("c", st, DISTORTION)
            T.eq(count(st.hand, WITHDRAW), 1)
            T.eq(count(st.hand, MIMIC_DISTORTION), 1)
            T.eq(st.hand[#st.hand].conjured, true)
        end,
        ["Conjured cards last for their number of turns"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            F.Cast("c", st, DISTORTION)
            nextTurn(st)
            T.eq(count(st.hand, MIMIC_DISTORTION), 0, "lasts 1: gone after its own turn")
            T.eq(count(st.hand, WITHDRAW), 1, "lasts 2: still there on turn 2")
            nextTurn(st)
            T.eq(count(st.hand, WITHDRAW), 0, "lasts 2: gone after turn 2")
        end,
        ["A status can conjure a card"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            F.StatusApplied("c", st, "ZEPHYR_STRIKE")
            T.eq(count(st.hand, ZEPHYR), 1)
        end,
        ["Nothing is conjured out of combat"] = function()
            local st = S.New()
            F.Cast("c", st, DISTORTION)
            F.StatusApplied("c", st, "ZEPHYR_STRIKE")
            T.eq(#st.hand, 0)
        end,
        ["Reweave is offered on turn 1 only"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            T.eq(count(st.hand, C.REWEAVE_TOKEN), 1)
            nextTurn(st)
            T.eq(count(st.hand, C.REWEAVE_TOKEN), 0)
            T.eq(count(st.unraveled, C.REWEAVE_TOKEN), 1)
        end,
        ["Reweave swaps the whole hand"] = function()
            local st = begin()
            F.StartTurn("c", st, yes)
            local deckBefore = #st.deck
            F.Cast("c", st, C.REWEAVE_TOKEN)
            T.eq(count(st.hand, C.REWEAVE_TOKEN), 0)
            T.eq(#st.hand, 4)
            T.eq(#st.deck, deckBefore)
        end,
        ["Casting a Tangle source shuffles a Tangle into the deck"] = function()
            local st = begin({ [TANGLER] = 1 })
            F.StartTurn("c", st, yes)
            local before = #st.deck
            F.Cast("c", st, TANGLER)
            T.eq(#st.deck, before + 1)
            T.eq(count(st.deck, TANGLE), 1)
        end,
    },
}
