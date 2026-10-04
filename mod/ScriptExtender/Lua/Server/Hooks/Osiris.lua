local U = Req("Server/Core/Util.lua")
local S = Req("Server/Core/State.lua")
local F = Req("Server/Core/Flow.lua")
local Po = Req("Server/Core/Pool.lua")
local Sy = Req("Server/Core/Sync.lua")
local L = Req("Server/Deck/List.lua")
local D = Req("Server/Cards/CardDB.lua")
local CR = Req("Server/Economy/CombatResources.lua")
local G = Req("Server/Deck/Grants.lua")

local H = {}

local function withState(rawChar, fn)
    local char = U.Guid(rawChar)
    if not Po.IsDeckUser(char) then return end
    local st = S.Get(char)
    L.Refresh(st, Po.Cards(char))
    fn(char, st)
    S.Commit(char, st)
end

-- Monta o conjunto uma vez: a carta conjurada pode estar no grimorio so como variante de upcast, e
-- perguntar pelo nome da raiz direto ao motor devolveria 0.
local function hasSpellFor(char)
    local roots = Po.RootSet(char)
    return function(id) return roots[id] == true end
end

local function watchedStatus(status)
    return D.statusConjures[status] ~= nil or D.threadStartStatuses[status] ~= nil
        or D.reactionByUsed[status] ~= nil
end

function H.ResyncAll()
    for char, st in pairs(S.All()) do
        Sy.ClearAll(char, st)
        if st.combat and Osi.IsInCombat(char) ~= 1 then F.EndCombat(char, st) end
        -- Threads and the hand counter belong to a fight. One that ended without its CombatEnded
        -- -- a crash, a reload -- would leave them on the panel for good, so take them away here.
        if not st.combat then CR.Revoke(char) end
        S.Commit(char, st)
    end
end

function H.Register()
    Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(char, combatId)
        withState(char, function(c, st)
            G.Ensure(c)
            F.BeginCombat(c, st, U.Guid(combatId), Po.LevelOf(c))
        end)
    end)

    -- the deck-only spells (Reweave) come from Lua, not from the progression
    Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(char) G.Ensure(U.Guid(char)) end)
    Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(char) G.Ensure(U.Guid(char)) end)
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function() G.EnsureParty() end)

    Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(char)
        withState(char, function(c, st)
            if Osi.IsInCombat(c) ~= 1 then return end
            local level = Po.LevelOf(c)
            if not st.combat then F.BeginCombat(c, st, nil, level) end
            F.StartTurn(c, st, hasSpellFor(c), level)
        end)
    end)

    Ext.Osiris.RegisterListener("TurnEnded", 1, "after", function(char)
        withState(char, function(c, st)
            if st.combat then F.EndTurn(c, st) end
        end)
    end)

    Ext.Osiris.RegisterListener("CastedSpell", 5, "after", function(caster, spell)
        withState(caster, function(c, st) F.Cast(c, st, spell) end)
    end)

    Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status)
        if not watchedStatus(status) then return end
        withState(target, function(c, st) F.StatusApplied(c, st, status) end)
    end)

    -- whole-combat event, so nobody unlocks their pool while the fight goes on
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(combatId)
        local id = U.Guid(combatId)
        for char, st in pairs(S.All()) do
            if st.combat and (st.combat.id == nil or st.combat.id == id) and Osi.IsInCombat(char) ~= 1 then
                F.EndCombat(char, st)
                S.Commit(char, st)
            end
        end
    end)

    Ext.Events.SessionLoaded:Subscribe(function()
        Ext.Timer.WaitFor(1000, function()
            H.ResyncAll()
            G.EnsureParty()
        end)
    end)
    Ext.Events.ResetCompleted:Subscribe(H.ResyncAll)
end

return H
