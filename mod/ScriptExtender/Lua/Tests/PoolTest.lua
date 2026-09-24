local T = Req("Tests/T.lua")
local Po = Req("Server/Core/Pool.lua")

-- O grimorio devolve a carta sob o nivel que o personagem consegue pagar: uma carta de nivel 1 num
-- personagem com espaco de nivel 3 aparece so como "..._3". Tudo aqui existe para garantir que o
-- baralho continue raciocinando pela carta, e nao por cada variante.
local saved

local function spellbook(ids)
    saved = Po.SpellIds
    Po.SpellIds = function() return ids end
end

return {
    name = "Pool",
    after = function() if saved then Po.SpellIds = saved; saved = nil end end,
    cases = {
        ["A carta entra no baralho uma vez, mesmo vindo como variante"] = function()
            spellbook({
                "Target_Arcana_Card_Spell_A_3",
                "Target_Arcana_Card_Spell_A_4",
                "Target_Arcana_Card_Spell_B",
            })
            T.list(Po.Cards("char"), { "Target_Arcana_Card_Spell_A", "Target_Arcana_Card_Spell_B" },
                "uma entrada por carta, nao por variante")
        end,

        ["RootSet reconhece a carta que so existe como variante"] = function()
            spellbook({ "Target_Arcana_Card_Spell_A_3" })
            local roots = Po.RootSet("char")
            T.ok(roots["Target_Arcana_Card_Spell_A"], "a raiz conta como presente")
            T.ok(not roots["Target_Arcana_Card_Spell_A_3"], "a variante nao vira uma carta a parte")
        end,

        ["Variante ganha boost proprio, decidido pela carta"] = function()
            spellbook({ "Target_Arcana_Card_Spell_A_3" })
            local rel = Po.Relevant("char")
            T.eq(#rel, 1)
            T.eq(rel[1].id, "Target_Arcana_Card_Spell_A_3", "o boost nomeia a variante")
            T.eq(rel[1].root, "Target_Arcana_Card_Spell_A", "mas quem decide e a carta")
        end,

        ["Magia vanilla concedida pela classe e tratada como utilitaria"] = function()
            spellbook({ "Target_Light" })
            local rel = Po.Relevant("char")
            T.eq(#rel, 1)
            T.eq(rel[1].cat, "Util", "cai no caminho que tranca em combate")
        end,
    },
}
