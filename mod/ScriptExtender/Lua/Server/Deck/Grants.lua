-- Spells that only exist for the deck, so only the SE edition grants them.
--
-- Until 2026-10-04 the level 1 progression granted Reweave (list "Arcana Deck Core"). The console
-- edition has no deck, hand or mulligan, so a progression grant handed it a spell it can never use.
-- Now nothing in the stats grants it: this module teaches it to every Arcana that uses the deck.
--
-- When: on load and on a new level or party member (so it is in the spellbook before any fight), and
-- again when a fight starts, which is the moment it is needed. Asking HasSpell first makes every call
-- after the first a no-op.
local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")
local Po = Req("Server/Core/Pool.lua")

local G = { io = {} }

G.SPELLS = { C.REWEAVE_TOKEN }

-- Osi is an empty table in the offline test runner; the tests replace io anyway.
function G.io.isDeckUser(char) return Po.IsDeckUser(char) end
function G.io.has(char, id) return Osi.HasSpell(char, id) == 1 end
function G.io.add(char, id) Osi.AddSpell(char, id, 0, 1) end
function G.io.players()
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if not ok or type(rows) ~= "table" then return {} end
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = U.Guid(row[1]) end
    return out
end

function G.Ensure(char)
    if not G.io.isDeckUser(char) then return end
    for _, id in ipairs(G.SPELLS) do
        if not G.io.has(char, id) then G.io.add(char, id) end
    end
end

function G.EnsureParty()
    for _, char in ipairs(G.io.players()) do G.Ensure(char) end
end

return G
