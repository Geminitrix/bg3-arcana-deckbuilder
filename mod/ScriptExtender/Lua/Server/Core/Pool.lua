local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")
local D = Req("Server/Cards/CardDB.lua")

local Po = {}

-- The class's own spells are told apart by prefix; a weapon action is a base-game spell and is
-- told apart by its flag (C.WEAPON_ACTION_FLAG).
function Po.CategoryOf(id)
    local cat = U.Category(id)
    if cat == nil and D.IsWeaponAction(id) then return "WeaponAction" end
    return cat
end

-- None of the base-game spells is an upcast variant of ours, so only the class's own spells go
-- through StripUpcast -- a base-game name that happens to end in _2 stays whole.
local function rootOf(id)
    if U.Category(id) == nil then return id end
    return U.StripUpcast(id)
end

function Po.IsDeckUser(char)
    return Osi.IsPlayer(char) == 1
        and Osi.IsTagged(char, C.TAG_ARCANA) == 1
        and Osi.IsSummon(char) ~= 1
end

function Po.HasSpell(char, id)
    return Osi.HasSpell(char, id) == 1
end

-- Perguntar por HasSpell(raiz) nao serve mais: a base pode ter sido colapsada na variante e o motor
-- responde 0. Este conjunto diz "a carta X existe neste personagem, sob qualquer nivel".
function Po.RootSet(char)
    local out = {}
    for _, id in ipairs(Po.SpellIds(char)) do out[rootOf(id)] = true end
    return out
end

-- Osiris only exposes the character level; in multiclass this is not the Arcana level
function Po.LevelOf(char)
    local level = Osi.GetLevel(char)
    if type(level) == "number" and level > 0 then return level end
    return C.DEFAULT_LEVEL
end

-- Field names unverified; check with _D(Ext.Entity.Get(GetHostCharacter()).SpellBook.Spells[1])
function Po.SpellIds(char)
    local ids, seen = {}, {}
    local entity = Ext.Entity.Get(char)
    local book = entity and entity.SpellBook
    if not book then return ids end
    for _, spell in ipairs(book.Spells) do
        local sid = spell.Id
        local id = sid and ((sid.OriginatorPrototype ~= nil and sid.OriginatorPrototype ~= "") and sid.OriginatorPrototype or sid.Prototype)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function mirroredCopies(char)
    local out = {}
    local ok, rows = pcall(function() return Osi.DB_ARCANA_MirroredSpell:Get(nil, nil) end)
    if not ok or type(rows) ~= "table" then return out end
    for _, row in ipairs(rows) do
        if U.Guid(row[1]) == char then out[row[2]] = true end
    end
    return out
end

function Po.Relevant(char)
    local out = {}
    for _, id in ipairs(Po.SpellIds(char)) do
        local cat = Po.CategoryOf(id)
        local root = rootOf(id)
        if D.vanillaGranted[id] then
            -- Magia do jogo base concedida pela classe: nao e carta, mas em combate so se joga
            -- carta, entao vai trancada como utilitaria.
            out[#out + 1] = { id = id, cat = "Util" }
        elseif (C.DECK_CATEGORIES[cat] or cat == "Created" or cat == "Util") and not D.Skipped(id) then
            -- An upcast variant is a separate spell in the spellbook, so it needs its own lock or
            -- glow boost -- but the decision belongs to the card it came from, not to itself.
            out[#out + 1] = { id = id, cat = cat, root = root ~= id and root or nil }
        end
    end
    return out
end

-- O grimorio nao guarda a carta base: desde que o custo deixou de carregar recurso extra, o motor a
-- colapsa na variante de upcast do nivel que o personagem tem. Uma carta de nivel 1 num personagem
-- com espaco de nivel 3 aparece SO como "..._3". Por isso o baralho e montado pela RAIZ -- pular as
-- variantes, como se fazia antes, escondia justamente toda carta que tem variante, e sobravam os
-- truques. A raiz tambem e a chave do CardDB e o que a mao guarda.
function Po.Cards(char)
    local copies = mirroredCopies(char)
    local out, seen = {}, {}
    for _, id in ipairs(Po.SpellIds(char)) do
        local root = rootOf(id)
        if C.DECK_CATEGORIES[Po.CategoryOf(root)] and not seen[root] and not copies[root]
            and not D.Get(root).conjuredOnly then
            seen[root] = true
            out[#out + 1] = root
        end
    end
    table.sort(out)
    return out
end

return Po
