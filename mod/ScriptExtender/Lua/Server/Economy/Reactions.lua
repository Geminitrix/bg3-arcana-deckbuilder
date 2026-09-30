-- Reaction cards on the SE edition: the card in hand IS the charge (D.reactions has the rule shared
-- with the console edition).
--
-- The card is never cast in a fight here. While a copy is in hand the reaction is ready: its _READY
-- status is on, and its resource holds min(copies in hand, what is left of the round's limit). The
-- player is asked when the trigger happens -- the interrupt's own Ask prompt -- so the choice is made
-- then, not on their turn. A reaction used applies its *_USED_TECH status; that discards one copy and
-- counts against the limit until the owner's next turn.
--
-- After a use the charge is left alone: the engine already took one, and the new value -- min(n - 1,
-- limit - used - 1) -- is exactly the old one minus one. Writing it here could land before the
-- engine's own subtraction and cost a second charge.
local E = Req("Server/Core/Events.lua")
local P = Req("Server/Core/Piles.lua")
local D = Req("Server/Cards/CardDB.lua")
local Rs = Req("Server/Economy/Resources.lua")

local R = { io = {} }

-- Osi is an empty table in the offline test runner; the tests replace io anyway.
function R.io.hasStatus(char, status)
    return Osi.HasActiveStatus ~= nil and Osi.HasActiveStatus(char, status) == 1
end
function R.io.apply(char, status)
    if Osi.ApplyStatus then Osi.ApplyStatus(char, status, -1, 1, char) end
end
function R.io.remove(char, status)
    if Osi.RemoveStatus then Osi.RemoveStatus(char, status) end
end
function R.io.get(char, resource) return Rs.Get(char, resource) end
function R.io.set(char, resource, value) return Rs.Set(char, resource, value) end

local function copies(st, id)
    local n = 0
    for _, e in ipairs(st.hand or {}) do
        if e.id == id then n = n + 1 end
    end
    return n
end

function R.Charges(st, id)
    local r = D.reactions[id]
    if not (r and st.combat) then return 0 end
    local used = (st.combat.reacted or {})[id] or 0
    return math.max(0, math.min(copies(st, id), r.perRound - used))
end

function R.Sync(char, st, keepCharges)
    for id, r in pairs(D.reactions) do
        local n = st.combat and copies(st, id) or 0
        -- a character that never had the card has nothing to switch off, and may not even own the
        -- resource (a Deceiver has no ArcanaReactGaleDeflection)
        if n > 0 or (st.list or {})[id] then
            local ready = R.io.hasStatus(char, r.ready)
            if n > 0 and not ready then
                R.io.apply(char, r.ready)
            elseif n == 0 and ready then
                R.io.remove(char, r.ready)
            end
            if not keepCharges then
                local want = R.Charges(st, id)
                if R.io.get(char, r.resource) ~= want then R.io.set(char, r.resource, want) end
            end
        end
    end
end

function R.Use(char, st, id)
    if not st.combat then return nil end
    st.combat.reacted = st.combat.reacted or {}
    st.combat.reacted[id] = (st.combat.reacted[id] or 0) + 1
    local entry = P.Play(char, st, id, { reaction = true })
    -- no copy left to discard (the hand changed under the prompt): still refresh the ready status
    if not entry then R.Sync(char, st, true) end
    return entry
end

for _, event in ipairs({ "CardDrawn", "CardAdded", "CardUnraveled", "CombatStarted", "TurnEnded", "CombatEnded" }) do
    E.On(event, function(ctx) R.Sync(ctx.char, ctx.state) end)
end

E.On("CardPlayed", function(ctx) R.Sync(ctx.char, ctx.state, ctx.reaction == true) end)

-- the round's limit runs from one of the owner's turns to the next, like the reaction itself
E.On("TurnStarted", function(ctx)
    ctx.state.combat.reacted = {}
    R.Sync(ctx.char, ctx.state)
end)

E.On("StatusApplied", function(ctx)
    local id = D.reactionByUsed[ctx.status]
    if id then R.Use(ctx.char, ctx.state, id) end
end)

return R
