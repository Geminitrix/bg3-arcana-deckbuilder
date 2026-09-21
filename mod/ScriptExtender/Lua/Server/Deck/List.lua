local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")

local L = { maxRules = {} }

function L.MaxCopies(id)
    for _, rule in ipairs(L.maxRules) do
        local m = rule(id)
        if m then return m end
    end
    return C.MAX_COPIES
end

function L.Size(list)
    local n = 0
    for _, count in pairs(list) do n = n + count end
    return n
end

function L.Default(ids)
    local list = {}
    for _, id in ipairs(ids) do list[id] = L.MaxCopies(id) end
    return list
end

function L.Refresh(st, ids)
    for _, id in ipairs(ids) do
        if st.list[id] == nil then st.list[id] = L.MaxCopies(id) end
    end
end

function L.MinDeck(level)
    level = level or C.DEFAULT_LEVEL
    for _, band in ipairs(C.MIN_DECK_BANDS) do
        if level <= band.maxLevel then return band.size end
    end
    return C.MIN_DECK_BANDS[#C.MIN_DECK_BANDS].size
end

function L.SetCount(st, poolIds, id, n, level)
    if st.combat then return false, "in combat" end
    if not U.IndexOf(poolIds, id) then return false, "not in pool" end
    n = math.max(0, math.min(L.MaxCopies(id), math.floor(n)))
    local minimum = L.MinDeck(level)
    local size = L.Size(st.list) - (st.list[id] or 0) + n
    if size < minimum then return false, "deck would drop below " .. minimum end
    st.list[id] = n
    return true, n
end

return L
