local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")
local E = Req("Server/Core/Events.lua")

local P = { rand = math.random }

local function ctx(char, st, extra)
    local c = { char = char, state = st }
    for k, v in pairs(extra) do c[k] = v end
    return c
end

function P.BuildDeck(st)
    local deck = {}
    for _, id in ipairs(U.SortedKeys(st.list)) do
        for _ = 1, st.list[id] do deck[#deck + 1] = id end
    end
    st.deck = U.Shuffle(deck, P.rand)
end

function P.ResetForCombat(char, st)
    st.hand, st.frayed, st.unraveled = {}, {}, {}
    P.BuildDeck(st)
end

function P.Unravel(char, st, id, reason)
    st.unraveled[#st.unraveled + 1] = id
    E.Emit("CardUnraveled", ctx(char, st, { id = id, reason = reason }))
end

function P.AddToHand(char, st, id, opts)
    opts = opts or {}
    if #st.hand >= C.HAND_MAX then
        P.Unravel(char, st, id, "overflow")
        return nil
    end
    local entry = { id = id, conjured = opts.conjured == true, expiresOnTurn = opts.expiresOnTurn }
    st.hand[#st.hand + 1] = entry
    E.Emit(opts.event or "CardAdded", ctx(char, st, { entry = entry }))
    return entry
end

local function refillDeck(st)
    if #st.deck == 0 and #st.frayed > 0 then
        st.deck, st.frayed = U.Shuffle(st.frayed, P.rand), {}
    end
end

function P.Draw(char, st, n)
    local drawn = 0
    for _ = 1, n or 1 do
        refillDeck(st)
        if #st.deck == 0 then break end
        local id = table.remove(st.deck)
        if P.AddToHand(char, st, id, { event = "CardDrawn" }) then drawn = drawn + 1 end
    end
    return drawn
end

function P.ShuffleIntoDeck(char, st, id)
    table.insert(st.deck, P.rand(#st.deck + 1), id)
end

function P.PullFromDeck(st, pred)
    local out = {}
    for i = #st.deck, 1, -1 do
        if pred(st.deck[i]) then table.insert(out, 1, table.remove(st.deck, i)) end
    end
    return out
end

function P.RemoveFromHand(char, st, index, dest, reason)
    local entry = table.remove(st.hand, index)
    if not entry then return nil end
    if dest == "unravel" then
        P.Unravel(char, st, entry.id, reason)
    elseif dest == "deck" then
        st.deck[#st.deck + 1] = entry.id
    else
        st.frayed[#st.frayed + 1] = entry.id
    end
    return entry
end

function P.FindInHand(st, id)
    for i, e in ipairs(st.hand) do
        if e.id == id then return i end
    end
    return nil
end

function P.Play(char, st, spell)
    local index = P.FindInHand(st, spell)
    if not index then
        local base = U.StripUpcast(spell)
        if base ~= spell then index = P.FindInHand(st, base) end
    end
    if not index then return nil end
    local entry = st.hand[index]
    P.RemoveFromHand(char, st, index, entry.conjured and "unravel" or "frayed", "played")
    E.Emit("CardPlayed", ctx(char, st, { entry = entry, spell = spell }))
    return entry
end

function P.ExpireConjured(char, st, endedTurn, hasSpell)
    for i = #st.hand, 1, -1 do
        local e = st.hand[i]
        if e.conjured then
            local timedOut = endedTurn ~= nil and e.expiresOnTurn ~= nil and e.expiresOnTurn <= endedTurn
            local gone = hasSpell ~= nil and not hasSpell(e.id)
            if timedOut or gone then P.RemoveFromHand(char, st, i, "unravel", "expired") end
        end
    end
end

function P.ReturnHandToDeck(char, st, keep)
    local returned = 0
    for i = #st.hand, 1, -1 do
        if not keep(st.hand[i]) then
            P.RemoveFromHand(char, st, i, "deck")
            returned = returned + 1
        end
    end
    U.Shuffle(st.deck, P.rand)
    return returned
end

return P
