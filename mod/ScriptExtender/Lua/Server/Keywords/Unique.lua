local C = Req("Server/Core/Const.lua")
local D = Req("Server/Cards/CardDB.lua")
local L = Req("Server/Deck/List.lua")

L.maxRules[#L.maxRules + 1] = function(id)
    if D.Has(id, "Unique") or D.Has(id, "Fated") then return C.UNIQUE_COPIES end
end

return true
