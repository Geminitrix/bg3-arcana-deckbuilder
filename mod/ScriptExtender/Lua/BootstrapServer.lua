local cache = {}
function Req(path)
    local m = cache[path]
    if m == nil then
        m = Ext.Require(path)
        if m == nil then m = true end
        cache[path] = m
    end
    return m
end

local S = Req("Server/Core/State.lua")
local Sy = Req("Server/Core/Sync.lua")
local Po = Req("Server/Core/Pool.lua")

S.store = S.ModVarsStore()
Sy.io.relevant = Po.Relevant
S.beforeSave = Sy.Apply

for _, kw in ipairs({ "Fated", "Fleeting", "Unique", "Conjured", "Reweave", "Tangle" }) do
    Req("Server/Keywords/" .. kw .. ".lua")
end

Req("Server/Economy/Weaving.lua")
Req("Server/Economy/HandCards.lua")
Req("Server/Economy/Reactions.lua")
Req("Server/Feedback/Overhead.lua")

Req("Server/Hooks/Osiris.lua").Register()
Req("Server/Debug/Commands.lua")

print("[ArcanaDeck] loaded")
