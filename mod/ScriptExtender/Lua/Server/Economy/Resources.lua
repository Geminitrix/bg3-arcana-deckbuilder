-- Read and write any action resource by name. Threads.lua keeps its own fast path for
-- ArcanaThread; this is for the reaction gates, which are one-off lookups.
local Rs = { io = {} }

local uuids = {}

-- Ext is absent in the offline test runner; every entry point has to survive that.
local function entityApi()
    return Ext and Ext.Entity and Ext.Entity.Get and Ext.Entity or nil
end

local function uuidOf(name)
    if uuids[name] ~= nil then return uuids[name] end
    if not (Ext and Ext.StaticData) then return nil end
    for _, guid in ipairs(Ext.StaticData.GetAll("ActionResource")) do
        local def = Ext.StaticData.Get(guid, "ActionResource")
        if def and def.Name == name then
            uuids[name] = guid
            return guid
        end
    end
    uuids[name] = false
    return nil
end

local function entries(char, name)
    local api = entityApi()
    local entity = api and api.Get(char)
    local resources = entity and entity.ActionResources and entity.ActionResources.Resources
    local uuid = uuidOf(name)
    if not (resources and uuid) then return nil, nil end
    return entity, resources[uuid]
end

function Rs.io.get(char, name)
    local _, list = entries(char, name)
    return (list and list[1]) and list[1].Amount or 0
end

function Rs.io.set(char, name, value)
    local entity, list = entries(char, name)
    if not list then
        if entityApi() then print("[ArcanaDeck] " .. tostring(char) .. " has no " .. tostring(name)) end
        return false
    end
    for _, r in ipairs(list) do r.Amount = math.min(value, r.MaxAmount or value) end
    -- without Replicate the client keeps drawing the old value
    entity:Replicate("ActionResources")
    return true
end

function Rs.Get(char, name) return Rs.io.get(char, name) end
function Rs.Set(char, name, value) return Rs.io.set(char, name, value) end

return Rs
