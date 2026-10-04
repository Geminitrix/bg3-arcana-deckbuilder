local T = Req("Tests/T.lua")
local C = Req("Server/Core/Const.lua")
local G = Req("Server/Deck/Grants.lua")

local ARCANA, OTHER = "char-arcana", "char-other"
local book, added, savedIo

return {
    name = "Grants",
    before = function()
        savedIo = G.io
        book, added = {}, {}
        G.io = {
            isDeckUser = function(c) return c == ARCANA end,
            has = function(c, id) return book[c .. "|" .. id] == true end,
            add = function(c, id)
                book[c .. "|" .. id] = true
                added[#added + 1] = c .. "|" .. id
            end,
            players = function() return { ARCANA, OTHER } end,
        }
    end,
    after = function() G.io = savedIo end,
    cases = {
        ["Reweave is the deck-only spell granted"] = function()
            T.list(G.SPELLS, { C.REWEAVE_TOKEN })
        end,
        ["An Arcana without Reweave learns it"] = function()
            G.Ensure(ARCANA)
            T.list(added, { ARCANA .. "|" .. C.REWEAVE_TOKEN })
        end,
        ["Asking again never adds a second copy"] = function()
            G.Ensure(ARCANA)
            G.Ensure(ARCANA)
            T.eq(#added, 1)
        end,
        ["Someone who doesn't use the deck gets nothing"] = function()
            G.Ensure(OTHER)
            T.eq(#added, 0)
        end,
        ["The whole party is checked, only the Arcana learns it"] = function()
            G.EnsureParty()
            T.list(added, { ARCANA .. "|" .. C.REWEAVE_TOKEN })
        end,
    },
}
