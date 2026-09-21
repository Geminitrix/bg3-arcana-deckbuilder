local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")
local Sy = Req("Server/Core/Sync.lua")

local CARD, TOKEN, UTIL = "Shout_Arcana_Card_Spell_A", "Shout_Arcana_Created_B", "Shout_Arcana_Util_C"
local MIMIC, MIMIC_SUB = "Target_Arcana_Created_Mimic", "Target_Arcana_Created_MimicDistortion"
local TANGLE = "Shout_Arcana_Created_Tangle_DEBUG"
local RELEVANT = { { id = CARD, cat = "Card" }, { id = TOKEN, cat = "Created" }, { id = UTIL, cat = "Util" } }

local savedIo, calls

local function inCombat(handIds)
    local st = S.New()
    st.combat = { turn = 1 }
    for _, id in ipairs(handIds or {}) do st.hand[#st.hand + 1] = { id = id, conjured = false } end
    return st
end

return {
    name = "Sync",
    before = function()
        savedIo, calls = Sy.io, {}
        Sy.io = {
            add = function(_, b) calls[#calls + 1] = "+" .. b end,
            remove = function(_, b) calls[#calls + 1] = "-" .. b end,
            relevant = function() return RELEVANT end,
        }
    end,
    after = function() Sy.io = savedIo end,
    cases = {
        ["Nothing is wanted out of combat"] = function()
            T.eq(next(Sy.Desired(S.New(), RELEVANT)), nil)
        end,
        ["Util spells are always locked in combat"] = function()
            T.eq(Sy.Desired(inCombat({ UTIL }), RELEVANT)[UTIL], Sy.LockFor(UTIL))
        end,
        ["Cards in hand only glow -- the cost is ARCANA_WEAVING's job"] = function()
            local boost = Sy.Desired(inCombat({ CARD }), RELEVANT)[CARD]
            T.eq(boost, Sy.GlowFor(CARD))
            T.ok(boost:find("ModifyIconGlow()", 1, true), "glow lights the icon")
            T.ok(not boost:find("ArcanaThread", 1, true), "the glow boost carries no cost")
        end,
        ["Cards and Tokens out of hand are locked"] = function()
            local want = Sy.Desired(inCombat(), RELEVANT)
            T.eq(want[CARD], Sy.LockFor(CARD))
            T.eq(want[TOKEN], Sy.LockFor(TOKEN))
            T.ok(want[CARD]:find("ArcanaNotInHand", 1, true), "lock uses the unpayable resource")
        end,
        ["The Mimic container glows when one of its cards is in hand"] = function()
            local rel = { { id = MIMIC, cat = "Created" } }
            T.eq(Sy.Desired(inCombat({ MIMIC_SUB }), rel)[MIMIC], Sy.GlowFor(MIMIC))
            T.eq(Sy.Desired(inCombat(), rel)[MIMIC], Sy.LockFor(MIMIC))
        end,
        ["Unplayable cards stay locked in hand"] = function()
            local rel = { { id = TANGLE, cat = "Created" } }
            T.eq(Sy.Desired(inCombat({ TANGLE }), rel)[TANGLE], Sy.LockFor(TANGLE))
        end,
        ["Apply only touches what changed"] = function()
            local st = inCombat()
            Sy.Apply("c", st)
            T.eq(#calls, 3)
            calls = {}
            Sy.Apply("c", st)
            T.eq(#calls, 0)
            st.hand = { { id = CARD, conjured = false } }
            Sy.Apply("c", st)
            T.list(calls, { "-" .. Sy.LockFor(CARD), "+" .. Sy.GlowFor(CARD) })
        end,
        ["Apply clears everything when combat ends"] = function()
            local st = inCombat()
            Sy.Apply("c", st)
            calls = {}
            st.combat = nil
            Sy.Apply("c", st)
            T.eq(#calls, 3)
            T.eq(next(st.applied), nil)
        end,
        ["ClearAll removes every applied boost"] = function()
            local st = inCombat()
            Sy.Apply("c", st)
            calls = {}
            Sy.ClearAll("c", st)
            T.eq(#calls, 3)
            T.eq(next(st.applied), nil)
        end,
    },
}
