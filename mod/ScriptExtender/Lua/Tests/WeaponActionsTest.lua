local T = Req("Tests/T.lua")
local C = Req("Server/Core/Const.lua")
local D = Req("Server/Cards/CardDB.lua")
local Po = Req("Server/Core/Pool.lua")
local L = Req("Server/Deck/List.lua")
local P = Req("Server/Core/Piles.lua")
local S = Req("Server/Core/State.lua")
Req("Server/Keywords/Unique.lua")

-- Weapon actions are base-game spells with no prefix of ours; the only thing that marks them is the
-- IsDefaultWeaponAction spell flag. These cases pin down that the deck reads exactly that.
local SLASH = "Target_Slash_New"
local SHOT = "Projectile_PiercingShot"
local HASTE = "Target_MAG_Haste"          -- an item spell: no flag, not a weapon action
local CARD = "Target_Arcana_Card_Spell_A"

local savedIo, savedIds
local FLAGS = {
    [SLASH] = { "IsMelee", "IsHarmful", "IsDefaultWeaponAction" },
    [SHOT] = "IsHarmful;IsDefaultWeaponAction",   -- the string form is read too
    [HASTE] = { "IsSpell" },
    ["Target_Oddly_Named_2"] = { "IsDefaultWeaponAction" },
}

local function spellbook(ids) Po.SpellIds = function() return ids end end

return {
    name = "WeaponActions",
    before = function()
        savedIo, savedIds = D.io, Po.SpellIds
        D.io = {
            spellLevel = function() return nil end,
            spellFlags = function(id) return FLAGS[id] end,
        }
        D.ForgetWeaponActions()
        P.rand = function(n) return n end
    end,
    after = function()
        D.io, Po.SpellIds = savedIo, savedIds
        D.ForgetWeaponActions()
        P.rand = math.random
    end,
    cases = {
        ["The flag, and only the flag, makes a weapon action"] = function()
            T.ok(D.IsWeaponAction(SLASH), "flag in a list")
            T.ok(D.IsWeaponAction(SHOT), "flag in a string")
            T.ok(not D.IsWeaponAction(HASTE), "an item spell is not one")
            T.ok(not D.IsWeaponAction("Target_Unknown"), "no stats, no card")
        end,
        ["Weapon actions join the pool beside the class's cards"] = function()
            spellbook({ CARD, SLASH, HASTE, "Target_MainHandAttack" })
            T.list(Po.Cards("char"), { CARD, SLASH }, "the basic attack and item spells stay out")
        end,
        ["A weapon action gets its own lock or glow boost"] = function()
            spellbook({ SLASH })
            local rel = Po.Relevant("char")
            T.eq(#rel, 1)
            T.eq(rel[1].cat, "WeaponAction")
            T.eq(rel[1].root, nil, "it is its own card")
        end,
        ["A base-game name ending in a number is not taken for an upcast"] = function()
            spellbook({ "Target_Oddly_Named_2" })
            T.list(Po.Cards("char"), { "Target_Oddly_Named_2" })
        end,
        ["Unique: one copy by default, and it can be taken out"] = function()
            T.eq(L.MaxCopies(SLASH), C.UNIQUE_COPIES)
            local st = S.New()
            L.Refresh(st, { CARD, SLASH })
            T.eq(st.list[SLASH], 1, "enters with one copy")
            st.list[CARD] = 20                      -- keep the minimum deck out of the way
            local ok = L.SetCount(st, { CARD, SLASH }, SLASH, 0, 1)
            T.ok(ok, "the player may leave it out")
            T.eq(st.list[SLASH], 0)
        end,
        ["Costs no Threads"] = function()
            T.eq(D.CostOf(SLASH), 0)
        end,
        ["Played, a weapon action goes to the exile, not the discard"] = function()
            local st = S.New()
            st.hand = { { id = SLASH }, { id = CARD } }
            P.Play("char", st, SLASH)
            T.list(st.unraveled, { SLASH }, "its cooldown would make it a dead draw")
            T.eq(#st.frayed, 0)
            P.Play("char", st, CARD)
            T.list(st.frayed, { CARD }, "an ordinary card still goes to the discard")
        end,
        ["A weapon action that names its own pile goes there"] = function()
            D.cards[SLASH] = { destination = D.PILE_FRAYED }
            T.eq(D.PlayedTo(SLASH, false), D.PILE_FRAYED, "the card beats the weapon-action rule")
            D.cards[SLASH] = nil
            T.eq(D.PlayedTo(SLASH, false), D.PILE_UNRAVEL)
        end,
        ["A card whose weapon is not equipped stays listed but out of the fight"] = function()
            local st = S.New()
            L.Refresh(st, { CARD, SLASH })
            L.Refresh(st, { CARD })                  -- the weapon was unequipped
            T.eq(st.list[SLASH], 1, "its count is kept for when the weapon comes back")
            P.BuildDeck(st)
            for _, id in ipairs(st.deck) do T.ok(id ~= SLASH, "not shuffled in") end
            L.Refresh(st, { CARD, SLASH })
            P.BuildDeck(st)
            local found = false
            for _, id in ipairs(st.deck) do if id == SLASH then found = true end end
            T.ok(found, "back in the deck once the weapon is")
        end,
    },
}
