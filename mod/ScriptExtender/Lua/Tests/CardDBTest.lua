local T = Req("Tests/T.lua")
local U = Req("Server/Core/Util.lua")
local D = Req("Server/Cards/CardDB.lua")
local R = Req("Server/Economy/Reactions.lua")

return {
    name = "CardDB",
    cases = {
        ["CostOf le o Level da magia, nao a tabela"] = function()
            local saved = D.io.spellLevel
            D.io.spellLevel = function(id) return id == "NV2" and 2 or nil end
            T.eq(D.CostOf("NV2"), 2, "o Level manda -- era isso que fazia o Olhar Hipnotico dizer 1")
            D.io.spellLevel = function() return nil end
            T.eq(D.CostOf("Projectile_Arcana_Card_Spell_SigilofMalice"), 1, "sem Level, cai na tabela")
            D.io.spellLevel = saved
        end,
        ["CostOf falls back to the default"] = function()
            T.eq(D.CostOf("Unknown_Spell"), 1)
            T.eq(D.CostOf("Shout_Arcana_Card_Spell_DEBUG_Tangler"), 2)
        end,
        ["A card costs its level, with no once-per-rest discount"] = function()
            T.eq(D.CostOf("Projectile_Arcana_Card_Spell_SigilofMalice"), 1)
            T.eq(D.CostOf("Target_Arcana_Card_Spell_EtherealChains"), 2)
            T.eq(D.CostOf("Target_Arcana_Card_Spell_Distortion"), 3)
            T.eq(D.CostOf("Zone_Arcana_Card_Spell_FinalSpark"), 6, "level 6, once per short rest")
            T.eq(D.CostOf("Shout_Arcana_Created_Withdraw"), 1)
            T.eq(D.CostOf("Target_Arcana_Created_MimicDistortion"), 2)
        end,
        ["Container children the deck ignores are skipped"] = function()
            T.eq(D.Skipped("Shout_Arcana_Util_Faceless_Elf_Male"), true)
            T.eq(D.Skipped("Target_Arcana_Util_Faceless_Copy"), true)
            T.eq(D.Skipped("Shout_Arcana_Util_Faceless"), false, "the container itself stays")
            T.eq(D.Skipped("Target_Arcana_Card_Spell_Distortion"), false)
        end,
        ["A cantrip costs 1 Thread: nothing to zero, the status only adds"] = function()
            T.eq(D.CostOf("Target_Arcana_Card_Spell_MaliciousWhispers"), 1)
            T.eq(D.CostOf("Shout_Arcana_Card_Spell_HowlOfTheDead"), 1)
        end,
        ["Every reaction card names a resource and is Unique"] = function()
            local seen = 0
            for _, e in ipairs(R.Each()) do
                seen = seen + 1
                T.ok(type(e.reaction.resource) == "string", e.id .. " has a resource")
                T.eq(U.Category(e.id), "Passive", e.id)
                T.eq(D.Has(e.id, "Unique"), true, e.id .. " is Unique")
            end
            T.eq(seen, 3, "three reactions")
        end,
        ["Has reads keyword flags"] = function()
            T.eq(D.Has("Shout_Arcana_Card_Spell_DEBUG_Fated", "Fated"), true)
            T.eq(D.Has("Shout_Arcana_Card_Spell_DEBUG_Fated", "Unique"), false)
            T.eq(D.Has("Unknown_Spell", "Fated"), false)
        end,
        ["ConjuresOn lists the Distortion tokens"] = function()
            local c = D.ConjuresOn("Target_Arcana_Card_Spell_Distortion")
            T.eq(#c, 2)
            T.eq(c[1].id, "Shout_Arcana_Created_Withdraw")
            T.eq(c[1].lasts, 2)
            T.eq(#D.ConjuresOn("Unknown_Spell"), 0)
        end,
        ["Every conjured card is a Token"] = function()
            for _, card in pairs(D.cards) do
                for _, c in ipairs(card.conjures or {}) do T.eq(U.Category(c.id), "Created", c.id) end
            end
            for _, c in pairs(D.statusConjures) do T.eq(U.Category(c.id), "Created", c.id) end
            -- a container is either a Created card (Mimic) or a deck card whose Choose options
            -- are Created (Hemoplague); the children are always Created
            for container, subs in pairs(D.containers) do
                local cat = U.Category(container)
                T.ok(cat == "Created" or cat == "Card", container .. " category " .. tostring(cat))
                for _, id in ipairs(subs) do
                    T.eq(U.Category(id), "Created", id)
                    T.eq(D.parentOf[id], container, id .. " points back at its container")
                end
            end
        end,
    },
}
