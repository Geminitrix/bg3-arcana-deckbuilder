-- Floating text over the character when a card moves. The deck is invisible otherwise: the player
-- sees icons light up and Threads go down, but never which card arrived or left.
-- Osi.DebugText is the engine's overhead text; the mod's own Osiris goals already use it.
local E = Req("Server/Core/Events.lua")

local O = { on = true, io = {} }

function O.io.text(char, line)
    -- absent in the offline test runner
    if Osi and Osi.DebugText then Osi.DebugText(char, line) end
end

-- The spell's real, localised name -- the id is not something to show a player.
local names = {}

local function fromId(id)
    -- last resort: Projectile_Arcana_Card_Spell_SigilofMalice -> "SigilofMalice"
    return (id:gsub("^.-_Arcana_[A-Za-z]-_?[A-Za-z]-_", ""):gsub("^.*_", ""))
end

function O.NameOf(id)
    local cached = names[id]
    if cached then return cached end
    local name
    if Ext and Ext.Stats and Ext.Loca then
        local ok, stat = pcall(Ext.Stats.Get, id)
        local handle = ok and stat and stat.DisplayName
        if type(handle) == "string" and handle ~= "" then
            handle = handle:match("^([^;]+)") or handle
            local ok2, text = pcall(Ext.Loca.GetTranslatedString, handle)
            if ok2 and type(text) == "string" and text ~= "" then name = text end
        end
    end
    name = name or fromId(id)
    names[id] = name
    return name
end

function O.Say(char, verb, id)
    if not O.on or not char or not id then return false end
    O.io.text(char, verb .. ": " .. O.NameOf(id))
    return true
end

E.On("CardDrawn", function(ctx)
    O.Say(ctx.char, "Drawn", ctx.entry and ctx.entry.id)
end)

E.On("CardPlayed", function(ctx)
    O.Say(ctx.char, "Played", ctx.entry and ctx.entry.id)
end)

-- Being exiled for going over the hand limit is a real cost and the only silent one.
E.On("CardUnraveled", function(ctx)
    O.Say(ctx.char, "Unravelled", ctx.id)
end)

return O
