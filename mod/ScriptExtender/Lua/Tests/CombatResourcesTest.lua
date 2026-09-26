local T = Req("Tests/T.lua")
local C = Req("Server/Core/Const.lua")
local S = Req("Server/Core/State.lua")
local F = Req("Server/Core/Flow.lua")
local Th = Req("Server/Economy/Threads.lua")
local CR = Req("Server/Economy/CombatResources.lua")

local CHAR = "char-combatres"
local held, savedIo, savedThreadIo

-- what the character holds, counted per boost string
local function count(boost) return held[boost] or 0 end

return {
    name = "CombatResources",
    before = function()
        savedIo, savedThreadIo = CR.io, Th.io
        held = {}
        CR.io = {
            add = function(_, b) held[b] = (held[b] or 0) + 1 end,
            remove = function(_, b) held[b] = nil end,
        }
        local threads = 0
        Th.io = {
            get = function() return threads end,
            set = function(_, v) threads = v end,
            hasStatus = function() return false end,
        }
    end,
    after = function() CR.io, Th.io = savedIo, savedThreadIo end,
    cases = {
        ["Both resources are named, with the deck's own limits"] = function()
            T.eq(C.COMBAT_RESOURCES[1], "ActionResource(ArcanaThread," .. C.THREAD_CAP .. ",0)")
            T.eq(C.COMBAT_RESOURCES[2], "ActionResource(ArcanaHandCard," .. C.HAND_MAX .. ",0)")
        end,
        ["A fight grants them and its end takes them away"] = function()
            local st = S.New()
            F.BeginCombat(CHAR, st, "c1", 1)
            for _, b in ipairs(C.COMBAT_RESOURCES) do T.eq(count(b), 1, b .. " granted") end
            F.EndCombat(CHAR, st)
            for _, b in ipairs(C.COMBAT_RESOURCES) do T.eq(count(b), 0, b .. " removed") end
        end,
        ["Starting the same fight twice never stacks a second copy"] = function()
            local st = S.New()
            F.BeginCombat(CHAR, st, "c1", 1)
            F.BeginCombat(CHAR, st, "c1", 1)
            for _, b in ipairs(C.COMBAT_RESOURCES) do T.eq(count(b), 1, b) end
        end,
        ["Revoke with nothing granted is harmless"] = function()
            CR.Revoke(CHAR)
            for _, b in ipairs(C.COMBAT_RESOURCES) do T.eq(count(b), 0, b) end
        end,
    },
}
