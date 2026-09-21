local T = Req("Tests/T.lua")
local E = Req("Server/Core/Events.lua")

local run = 0

return {
    name = "Events",
    before = function() run = run + 1 end,
    cases = {
        ["Emit calls handlers in registration order"] = function()
            local name, seen = "Test_Order_" .. run, {}
            E.On(name, function(ctx) seen[#seen + 1] = "a" .. ctx.n end)
            E.On(name, function(ctx) seen[#seen + 1] = "b" .. ctx.n end)
            E.Emit(name, { n = 1 })
            T.list(seen, { "a1", "b1" })
        end,
        ["A failing handler does not stop the next one"] = function()
            local name, reached = "Test_Error_" .. run, false
            E.On(name, function() error("boom") end)
            E.On(name, function() reached = true end)
            E.Emit(name, {})
            T.eq(reached, true)
        end,
        ["Emit without handlers does nothing"] = function()
            E.Emit("Test_Nobody_" .. run, {})
        end,
    },
}
