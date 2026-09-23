local T = Req("Tests/T.lua")
local U = Req("Server/Core/Util.lua")

return {
    name = "Util",
    cases = {
        ["IsUpcast only fires on a trailing _N"] = function()
            T.ok(U.IsUpcast("Target_Arcana_Card_Spell_Distortion_5"), "variant")
            T.ok(not U.IsUpcast("Target_Arcana_Card_Spell_Distortion"), "base card")
            T.ok(not U.IsUpcast("Target_Arcana_Card_Spell_Transfusion_EX"), "_EX is not a level")
        end,
        ["Category reads the Arcana prefix after the spell type"] = function()
            T.eq(U.Category("Target_Arcana_Card_Spell_Distortion"), "Card")
            T.eq(U.Category("Shout_Arcana_Created_Withdraw"), "Created")
            T.eq(U.Category("Shout_Arcana_Util_Faceless"), "Util")
            T.eq(U.Category("Projectile_Arcana_Card_Ability_Fly_Untethered"), "Ability")
        end,
        ["Category ignores clone, helper and vanilla spells"] = function()
            T.eq(U.Category("Target_Deceiver_Clone_MirrorDistortion"), nil)
            T.eq(U.Category("Projectile_Arcana_Distortion_Explosion"), nil)
            T.eq(U.Category("Projectile_MagicMissile"), nil)
            T.eq(U.Category(nil), nil)
        end,
        ["StripUpcast removes a trailing level suffix"] = function()
            T.eq(U.StripUpcast("Target_Arcana_Card_Spell_X_3"), "Target_Arcana_Card_Spell_X")
            T.eq(U.StripUpcast("Target_Arcana_Card_Spell_X"), "Target_Arcana_Card_Spell_X")
        end,
        ["Guid keeps only the trailing uuid"] = function()
            local id = "2c76687d-93a2-477b-8b18-8a14b549304c"
            T.eq(U.Guid("S_Player_Karlach_" .. id), id)
            T.eq(U.Guid(id), id)
        end,
        ["Shuffle with an identity rand keeps the order"] = function()
            T.list(U.Shuffle({ "a", "b", "c" }, function(n) return n end), { "a", "b", "c" })
        end,
        ["Shuffle keeps every element"] = function()
            local t = U.Shuffle({ 1, 2, 3, 4, 5 })
            table.sort(t)
            T.list(t, { 1, 2, 3, 4, 5 })
        end,
        ["DeepCopy does not share nested tables"] = function()
            local a = { x = { y = 1 } }
            local b = U.DeepCopy(a)
            b.x.y = 2
            T.eq(a.x.y, 1)
        end,
        ["SortedKeys and IndexOf"] = function()
            T.list(U.SortedKeys({ b = 1, a = 2 }), { "a", "b" })
            T.eq(U.IndexOf({ "x", "y" }, "y"), 2)
            T.eq(U.IndexOf({ "x" }, "z"), nil)
        end,
    },
}
