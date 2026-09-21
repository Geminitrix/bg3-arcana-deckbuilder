local C = Req("Server/Core/Const.lua")
local D = Req("Server/Cards/CardDB.lua")

local Th = { io = {} }

local cachedUuid = C.RES_THREAD_UUID

local function threadUuid()
    if cachedUuid then return cachedUuid end
    for _, guid in ipairs(Ext.StaticData.GetAll("ActionResource")) do
        local def = Ext.StaticData.Get(guid, "ActionResource")
        if def and def.Name == C.RES_THREAD then
            cachedUuid = guid
            break
        end
    end
    return cachedUuid
end

local function resourceEntries(char)
    local entity = Ext.Entity.Get(char)
    local resources = entity and entity.ActionResources and entity.ActionResources.Resources
    local uuid = threadUuid()
    return entity, (resources and uuid) and resources[uuid] or nil
end

function Th.io.get(char)
    local _, list = resourceEntries(char)
    return (list and list[1]) and list[1].Amount or 0
end

function Th.io.set(char, value)
    local entity, list = resourceEntries(char)
    if not list then
        print("[ArcanaDeck] " .. tostring(char) .. " has no " .. C.RES_THREAD)
        return
    end
    for _, r in ipairs(list) do r.Amount = value end
    -- without Replicate the client keeps drawing the old value
    entity:Replicate("ActionResources")
end

function Th.io.hasStatus(char, status)
    return Osi.HasActiveStatus(char, status) == 1
end

function Th.BandFor(level)
    level = level or C.DEFAULT_LEVEL
    for _, band in ipairs(C.THREAD_BANDS) do
        if level <= band.maxLevel then return band end
    end
    return C.THREAD_BANDS[#C.THREAD_BANDS]
end

function Th.Compute(combat)
    local band = Th.BandFor(combat.level)
    -- binds are added after the band ceiling, so they can go past it
    local base = math.min(band.ceiling, combat.turn + band.start) + (combat.binds or 0)
    local reserve = math.min(C.THREAD_RESERVE_MAX, combat.leftover or 0)
    local total = math.min(C.THREAD_CAP, base + reserve + (combat.startBonus or 0))
    return total, base, reserve
end

function Th.StatusBonus(char)
    local bonus = 0
    for status, amount in pairs(D.threadStartStatuses) do
        if Th.io.hasStatus(char, status) then bonus = bonus + amount end
    end
    return bonus
end

function Th.Refill(char, st)
    local c = st.combat
    c.startBonus = (c.startBonus or 0) + Th.StatusBonus(char)
    local total = Th.Compute(c)
    c.startBonus = 0
    Th.io.set(char, total)
    return total
end

function Th.RememberLeftover(char, st)
    st.combat.leftover = Th.io.get(char)
end

function Th.Bind(st, n)
    st.combat.binds = (st.combat.binds or 0) + (n or 1)
end

function Th.AddNextTurn(st, n)
    st.combat.startBonus = (st.combat.startBonus or 0) + n
end

function Th.Gain(char, n)
    Th.io.set(char, math.min(C.THREAD_CAP, Th.io.get(char) + n))
end

return Th
