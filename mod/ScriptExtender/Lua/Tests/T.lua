local T = {}

function T.eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label or "eq", tostring(expected), tostring(actual)), 2)
    end
end

function T.ok(value, label)
    if not value then error((label or "ok") .. ": expected truthy", 2) end
end

function T.list(actual, expected, label)
    label = label or "list"
    if #actual ~= #expected then
        error(string.format("%s: expected length %d, got %d", label, #expected, #actual), 2)
    end
    for i = 1, #expected do
        if actual[i] ~= expected[i] then
            error(string.format("%s[%d]: expected %s, got %s", label, i, tostring(expected[i]), tostring(actual[i])), 2)
        end
    end
end

function T.Run(suites)
    local passed, failed = 0, 0
    for _, suite in ipairs(suites) do
        local names = {}
        for name in pairs(suite.cases) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            if suite.before then suite.before() end
            local ok, err = pcall(suite.cases[name])
            if suite.after then suite.after() end
            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                print("[FAIL] " .. suite.name .. " / " .. name .. ": " .. tostring(err))
            end
        end
    end
    print(string.format("[ArcanaDeck tests] %d passed, %d failed", passed, failed))
    return failed == 0
end

return T
