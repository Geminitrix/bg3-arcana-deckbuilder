local T = Req("Tests/T.lua")

return {
    name = "Smoke",
    cases = {
        ["Req caches modules"] = function()
            T.eq(Req("Tests/T.lua"), T)
        end,
    },
}
