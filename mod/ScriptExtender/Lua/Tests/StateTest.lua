local T = Req("Tests/T.lua")
local S = Req("Server/Core/State.lua")

local oldStore, oldHook

return {
    name = "State",
    before = function()
        oldStore, oldHook = S.store, S.beforeSave
        S.store, S.beforeSave = S.MemoryStore(), nil
    end,
    after = function()
        S.store, S.beforeSave = oldStore, oldHook
    end,
    cases = {
        ["Get returns a fresh state for unknown characters"] = function()
            local st = S.Get("c1")
            T.eq(#st.hand, 0)
            T.eq(st.combat, nil)
            T.ok(st.applied, "applied")
        end,
        ["Commit stores a copy that later edits do not touch"] = function()
            local st = S.Get("c1")
            st.list.X = 2
            S.Commit("c1", st)
            st.list.X = 3
            T.eq(S.Get("c1").list.X, 2)
        end,
        ["Get fills tables missing from old saves"] = function()
            S.store.save({ c1 = { list = { X = 1 } } })
            local st = S.Get("c1")
            T.eq(st.list.X, 1)
            T.eq(#st.unraveled, 0)
        end,
        ["Commit runs beforeSave first"] = function()
            S.beforeSave = function(_, st) st.applied.A = "boost" end
            S.Commit("c1", S.New())
            T.eq(S.Get("c1").applied.A, "boost")
        end,
        ["Delete removes the character"] = function()
            S.Commit("c1", S.New())
            S.Delete("c1")
            T.eq(S.All().c1, nil)
        end,
    },
}
