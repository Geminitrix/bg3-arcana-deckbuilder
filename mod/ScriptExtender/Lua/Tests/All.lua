local T = Req("Tests/T.lua")

local SUITES = {
    "Tests/SmokeTest.lua",
    "Tests/UtilTest.lua",
    "Tests/EventsTest.lua",
    "Tests/StateTest.lua",
    "Tests/CardDBTest.lua",
    "Tests/PoolTest.lua",
    "Tests/ListTest.lua",
    "Tests/PilesTest.lua",
    "Tests/ThreadsTest.lua",
    "Tests/SyncTest.lua",
    "Tests/FlowTest.lua",
    "Tests/KeywordsTest.lua",
    "Tests/ReactionsTest.lua",
    "Tests/OverheadTest.lua",
    "Tests/HandCardsTest.lua",
}

-- Loaded here, at bootstrap, and not inside Run(): Ext.Require only works while the mod context is
-- known, and a console command callback runs outside it ("current mod UUID is not known").
local SUITE_MODULES = {}
for _, path in ipairs(SUITES) do SUITE_MODULES[#SUITE_MODULES + 1] = Req(path) end

local M = {}

function M.Run()
    return T.Run(SUITE_MODULES)
end

return M
