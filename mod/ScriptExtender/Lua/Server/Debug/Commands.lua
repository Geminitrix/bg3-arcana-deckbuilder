local C = Req("Server/Core/Const.lua")
local U = Req("Server/Core/Util.lua")
local S = Req("Server/Core/State.lua")
local P = Req("Server/Core/Piles.lua")
local Sy = Req("Server/Core/Sync.lua")
local Po = Req("Server/Core/Pool.lua")
local D = Req("Server/Cards/CardDB.lua")
local L = Req("Server/Deck/List.lua")
local Th = Req("Server/Economy/Threads.lua")
local O = Req("Server/Feedback/Overhead.lua")
-- Required here and not inside the callback: a console command runs outside the mod context, and
-- Ext.Require refuses to work there ("the current mod UUID is not known").
local Tests = Req("Tests/All.lua")

local function host()
    return U.Guid(Osi.GetHostCharacter())
end

local function mutate(fn)
    local char = host()
    local st = S.Get(char)
    fn(char, st)
    S.Commit(char, st)
end

Ext.RegisterConsoleCommand("arcana", function()
    _D(S.Get(host()))
end)

-- Readable version of !arcana: what is in hand right now, with copies, and how big each pile is.
local function tally(list)
    local order, count = {}, {}
    for _, e in ipairs(list or {}) do
        local id = type(e) == "table" and e.id or e
        if count[id] == nil then order[#order + 1] = id; count[id] = 0 end
        count[id] = count[id] + 1
    end
    return order, count
end

Ext.RegisterConsoleCommand("arcanahand", function()
    local char = host()
    local st = S.Get(char)
    if not st.combat then
        print("not in combat -- there is no hand outside combat")
        return
    end
    print(string.format("hand %d/%d   threads %d", #st.hand, C.HAND_MAX, Th.io.get(char)))
    local order, count = tally(st.hand)
    for _, id in ipairs(order) do
        print(string.format("  %dx  %-42s %d thread%s",
            count[id], O.NameOf(id), D.CostOf(id), D.CostOf(id) == 1 and "" or "s"))
    end
    print(string.format("deck %d   frayed %d   unraveled %d",
        #st.deck, #(st.frayed or {}), #(st.unraveled or {})))
end)

-- The remaining deck, grouped, so you can see what is still coming.
Ext.RegisterConsoleCommand("arcanadeck", function()
    local st = S.Get(host())
    if not st.combat then
        print("not in combat; deck list has " .. #(U.SortedKeys(st.list or {})) .. " distinct cards")
        for _, id in ipairs(U.SortedKeys(st.list or {})) do
            print(string.format("  %dx  %s", st.list[id], O.NameOf(id)))
        end
        return
    end
    local order, count = tally(st.deck)
    print(string.format("deck %d cards left", #st.deck))
    for _, id in ipairs(order) do
        print(string.format("  %dx  %s", count[id], O.NameOf(id)))
    end
end)

Ext.RegisterConsoleCommand("arcanatext", function(_, mode)
    if mode == "on" or mode == "off" then O.on = (mode == "on") end
    print("overhead card text: " .. (O.on and "on" or "off"))
end)

Ext.RegisterConsoleCommand("arcanapool", function()
    local char = host()
    local inDeck = {}
    for _, id in ipairs(Po.Cards(char)) do inDeck[id] = true end
    for _, s in ipairs(Po.Relevant(char)) do
        print(string.format("%-6s %s%s", s.cat, s.id, inDeck[s.id] and "  [deck]" or ""))
    end
end)

Ext.RegisterConsoleCommand("arcanadraw", function(_, n)
    mutate(function(char, st)
        print("drew " .. P.Draw(char, st, tonumber(n) or 1))
    end)
end)

Ext.RegisterConsoleCommand("arcanaadd", function(_, id)
    mutate(function(char, st)
        local turn = st.combat and st.combat.turn or 0
        P.AddToHand(char, st, id, { conjured = true, expiresOnTurn = turn })
    end)
end)

Ext.RegisterConsoleCommand("arcanaset", function(_, id, n)
    mutate(function(char, st)
        local ok, result = L.SetCount(st, Po.Cards(char), id, tonumber(n) or 0, Po.LevelOf(char))
        print(ok and ("set to " .. result) or ("refused: " .. result))
    end)
end)

Ext.RegisterConsoleCommand("arcanathreads", function()
    local char = host()
    local st = S.Get(char)
    if not st.combat then
        print("not in combat; current " .. Th.io.get(char))
        return
    end
    local total, base, reserve = Th.Compute(st.combat)
    print(string.format("turn %d  base %d  reserve %d  formula %d  current %d",
        st.combat.turn, base, reserve, total, Th.io.get(char)))
end)

Ext.RegisterConsoleCommand("arcanaboost", function(_, mode, id)
    local char = host()
    if mode == "lock" and id then
        Sy.io.add(char, Sy.LockFor(id))
    elseif mode == "glow" and id then
        Sy.io.add(char, Sy.GlowFor(id))
    elseif mode == "clear" and id then
        Sy.io.remove(char, Sy.LockFor(id))
        Sy.io.remove(char, Sy.GlowFor(id))
    else
        print("usage: !arcanaboost lock|glow|clear <spellId>")
    end
end)

Ext.RegisterConsoleCommand("arcanareset", function()
    local char = host()
    local st = S.Get(char)
    Sy.ClearAll(char, st)
    S.Delete(char)
    print("deck state cleared")
end)

Ext.RegisterConsoleCommand("arcanatest", function()
    Tests.Run()
end)

return true
