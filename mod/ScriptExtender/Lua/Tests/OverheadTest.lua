local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local O = Req("Server/Feedback/Overhead.lua")

local CHAR = "char-overhead"
local CARD = "Projectile_Arcana_Card_Spell_SigilofMalice"
local said, savedIo, savedOn

local function inCombat(list)
    local st = S.New()
    st.list = list or {}
    st.combat = { id = "c1", turn = 1, binds = 0, leftover = 0, startBonus = 0, level = 1, counters = {} }
    st.hand, st.frayed, st.unraveled = {}, {}, {}
    return st
end

return {
    name = "Overhead",
    before = function()
        savedIo, savedOn = O.io, O.on
        said = {}
        O.on = true
        O.io = { text = function(char, line) said[#said + 1] = { char = char, line = line } end }
    end,
    after = function() O.io, O.on = savedIo, savedOn end,
    cases = {
        ["Drawing a card announces it over the character"] = function()
            local st = inCombat({ [CARD] = 1 })
            P.BuildDeck(st)
            P.Draw(CHAR, st, 1)
            T.eq(#said, 1)
            T.eq(said[1].char, CHAR)
            T.ok(said[1].line:find("^Drawn: "), "says Drawn, got " .. said[1].line)
        end,
        ["Playing a card announces it"] = function()
            local st = inCombat({ [CARD] = 1 })
            P.BuildDeck(st)
            P.Draw(CHAR, st, 1)
            said = {}
            P.Play(CHAR, st, CARD)
            T.eq(#said, 1)
            T.ok(said[1].line:find("^Played: "), "says Played, got " .. said[1].line)
        end,
        ["Going over the hand limit announces the exile"] = function()
            local st = inCombat()
            P.Unravel(CHAR, st, CARD, "handlimit")
            T.eq(#said, 1)
            T.ok(said[1].line:find("^Unravelled: "), "says Unravelled, got " .. said[1].line)
        end,
        ["The switch turns it off"] = function()
            O.on = false
            local st = inCombat({ [CARD] = 1 })
            P.BuildDeck(st)
            P.Draw(CHAR, st, 1)
            T.eq(#said, 0)
        end,
        ["Without a localised name it still says something readable"] = function()
            T.ok(#O.NameOf(CARD) > 0, "never empty")
            T.ok(not O.NameOf(CARD):find("Arcana_Card_Spell"), "never the raw prefix")
        end,
    },
}
