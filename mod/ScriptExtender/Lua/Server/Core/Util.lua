local C = Req("Server/Core/Const.lua")

local U = {}

local HEX = "%x"
local GUID_PATTERN = "(" .. HEX:rep(8) .. "%-" .. HEX:rep(4) .. "%-" .. HEX:rep(4) .. "%-"
    .. HEX:rep(4) .. "%-" .. HEX:rep(12) .. ")$"

function U.StartsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

function U.Category(spellId)
    if type(spellId) ~= "string" then return nil end
    for _, cat in ipairs(C.CATEGORY_ORDER) do
        local p = C.PREFIX[cat]
        if U.StartsWith(spellId, p) or spellId:find("_" .. p, 1, true) then return cat end
    end
    return nil
end

function U.StripUpcast(spellId)
    return (spellId:gsub("_%d+$", ""))
end

function U.Guid(s)
    if type(s) ~= "string" then return s end
    return s:match(GUID_PATTERN) or s
end

function U.Shuffle(t, rand)
    rand = rand or math.random
    for i = #t, 2, -1 do
        local j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function U.DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = U.DeepCopy(x) end
    return out
end

function U.IndexOf(list, value)
    for i, x in ipairs(list) do
        if x == value then return i end
    end
    return nil
end

function U.SortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

return U
