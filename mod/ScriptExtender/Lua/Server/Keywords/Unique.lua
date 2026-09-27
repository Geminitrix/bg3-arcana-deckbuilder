local C = Req("Server/Core/Const.lua")
local D = Req("Server/Cards/CardDB.lua")
local L = Req("Server/Deck/List.lua")

L.maxRules[#L.maxRules + 1] = function(id)
    if D.Has(id, "Unique") or D.Has(id, "Fated") then return C.UNIQUE_COPIES end
    -- Weapon actions keep the game's own cooldown (once per short rest), so a second copy would
    -- only ever be drawn dead. The player can still take the one copy out.
    if D.IsWeaponAction(id) then return C.UNIQUE_COPIES end
end

return true
