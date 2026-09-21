local U = Req("Server/Core/Util.lua")

local S = { store = nil, beforeSave = nil }

function S.New()
    return { list = {}, deck = {}, hand = {}, frayed = {}, unraveled = {}, applied = {} }
end

function S.MemoryStore()
    local data = {}
    return {
        load = function() return data end,
        save = function(d) data = d end,
    }
end

function S.ModVarsStore()
    Ext.Vars.RegisterModVariable(ModuleUUID, "Decks", {
        Server = true, Client = false, Persistent = true, SyncToClient = false,
    })
    return {
        load = function() return Ext.Vars.GetModVariables(ModuleUUID).Decks or {} end,
        -- ModVars only notices a write when the whole table is reassigned
        save = function(d) Ext.Vars.GetModVariables(ModuleUUID).Decks = d end,
    }
end

function S.Get(char)
    local saved = S.store.load()[char]
    local st = U.DeepCopy(saved) or S.New()
    for key, default in pairs(S.New()) do
        if st[key] == nil then st[key] = default end
    end
    return st
end

function S.Commit(char, st)
    if S.beforeSave then S.beforeSave(char, st) end
    local all = U.DeepCopy(S.store.load())
    all[char] = U.DeepCopy(st)
    S.store.save(all)
end

function S.All()
    return U.DeepCopy(S.store.load())
end

function S.Delete(char)
    local all = U.DeepCopy(S.store.load())
    all[char] = nil
    S.store.save(all)
end

return S
