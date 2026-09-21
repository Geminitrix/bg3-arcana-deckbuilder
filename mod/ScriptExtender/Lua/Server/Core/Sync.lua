local C = Req("Server/Core/Const.lua")
local D = Req("Server/Cards/CardDB.lua")

local Sy = {}

Sy.io = {
    add = function(char, boost) Osi.AddBoosts(char, boost, C.BOOST_SOURCE, char) end,
    remove = function(char, boost) Osi.RemoveBoosts(char, boost, 0, C.BOOST_SOURCE, char) end,
    relevant = function() return {} end,
}

function Sy.LockFor(id)
    return string.format(C.LOCK_BOOST, id)
end

-- The Thread cost comes from ARCANA_WEAVING now, so this boost only lights the card up.
function Sy.GlowFor(id)
    return string.format(C.GLOW_BOOST, id)
end

function Sy.Desired(st, relevant)
    local want = {}
    if not st.combat then return want end
    local inHand = {}
    for _, e in ipairs(st.hand) do inHand[e.id] = true end
    for _, s in ipairs(relevant) do
        if s.cat == "Util" then
            want[s.id] = Sy.LockFor(s.id)
        elseif C.DECK_CATEGORIES[s.cat] or s.cat == "Created" then
            local lit = inHand[s.id] == true
            for _, sub in ipairs(D.containers[s.id] or {}) do
                if inHand[sub] then lit = true end
            end
            local parent = D.parentOf[s.id]
            if parent and inHand[parent] then lit = true end
            if lit and not D.Get(s.id).unplayable then
                want[s.id] = Sy.GlowFor(s.id)
            else
                want[s.id] = Sy.LockFor(s.id)
            end
        end
    end
    return want
end

function Sy.Apply(char, st)
    local want = Sy.Desired(st, Sy.io.relevant(char))
    for id, boost in pairs(st.applied) do
        if want[id] ~= boost then
            Sy.io.remove(char, boost)
            st.applied[id] = nil
        end
    end
    for id, boost in pairs(want) do
        if st.applied[id] == nil then
            Sy.io.add(char, boost)
            st.applied[id] = boost
        end
    end
end

function Sy.ClearAll(char, st)
    for _, boost in pairs(st.applied) do Sy.io.remove(char, boost) end
    st.applied = {}
end

return Sy
