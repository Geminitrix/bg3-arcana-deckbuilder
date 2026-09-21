local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")
local D = Req("Server/Cards/CardDB.lua")

local Po = {}

function Po.IsDeckUser(char)
    return Osi.IsPlayer(char) == 1
        and Osi.IsTagged(char, C.TAG_ARCANA) == 1
        and Osi.IsSummon(char) ~= 1
end

function Po.HasSpell(char, id)
    return Osi.HasSpell(char, id) == 1
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
        local cat = U.Category(id)
        if (C.DECK_CATEGORIES[cat] or cat == "Created" or cat == "Util") and not D.Skipped(id) then
            out[#out + 1] = { id = id, cat = cat }
        end
    end
    return out
end

function Po.Cards(char)
    local copies = mirroredCopies(char)
    local out = {}
    for _, id in ipairs(Po.SpellIds(char)) do
        if C.DECK_CATEGORIES[U.Category(id)] and not copies[id] and not D.Get(id).conjuredOnly then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

return Po
