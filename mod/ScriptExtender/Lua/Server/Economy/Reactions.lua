-- Reactions are gated by an exclusive resource. Out of combat, and on the console edition, the
-- progression keeps that resource full and the reaction behaves as it always did. In SE combat
-- this module zeroes it, so the reaction is unavailable until its Arcana_Card_Passive_ activation
-- card is played -- the card itself gives the resource back, from its stats SpellProperties.
local C = Req("Server/Core/Const.lua")
local E = Req("Server/Core/Events.lua")
local D = Req("Server/Cards/CardDB.lua")
local Rs = Req("Server/Economy/Resources.lua")

local R = { io = { set = function(char, name, value) return Rs.Set(char, name, value) end } }

local KEY = "reactionsOn"

local function activated(st)
    local c = st.combat
    if not c then return nil end
    c.counters = c.counters or {}
    c.counters[KEY] = c.counters[KEY] or {}
    return c.counters[KEY]
end

-- every activation card in the CardDB, as { cardId, reaction }
function R.Each()
    local out = {}
    for id, card in pairs(D.cards) do
        if card.reaction then out[#out + 1] = { id = id, reaction = card.reaction } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function R.Zero(char, st)
    local on = activated(st)
    if not on then return 0 end
    local n = 0
    for _, e in ipairs(R.Each()) do
        if not on[e.id] then
            R.io.set(char, e.reaction.resource, 0)
            n = n + 1
        end
    end
    return n
end

-- resources that recharge per turn (Hollow Image) fill back up on their own, so they have to be
-- zeroed again every turn until the player pays for the activation
function R.OnTurnStart(char, st)
    local on = activated(st)
    if not on then return 0 end
    local n = 0
    for _, e in ipairs(R.Each()) do
        if e.reaction.perTurn and not on[e.id] then
            R.io.set(char, e.reaction.resource, 0)
            n = n + 1
        end
    end
    return n
end

function R.Activate(st, cardId)
    local on = activated(st)
    if not on then return false end
    local card = D.Get(cardId)
    if not card.reaction then return false end
    on[cardId] = true
    return true
end

function R.IsActive(st, cardId)
    local on = activated(st)
    return on ~= nil and on[cardId] == true
end

function R.RestoreAll(char)
    for _, e in ipairs(R.Each()) do
        R.io.set(char, e.reaction.resource, e.reaction.max or 1)
    end
end

E.On("CombatStarted", function(ctx) R.Zero(ctx.char, ctx.state) end)
E.On("TurnStarted", function(ctx) R.OnTurnStart(ctx.char, ctx.state) end)
E.On("CardPlayed", function(ctx)
    local id = ctx.entry and ctx.entry.id
    if id then R.Activate(ctx.state, id) end
end)
-- CombatEnded wipes st.combat before the handlers run, so the restore only needs the character
E.On("CombatEnded", function(ctx) R.RestoreAll(ctx.char) end)

return R
