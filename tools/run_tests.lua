local root = assert(arg[1], "usage: lua run_tests.lua <ScriptExtender/Lua folder>")
root = root:gsub("[\\/]$", "")

local cache = {}
function Req(path)
    local m = cache[path]
    if m == nil then
        m = dofile(root .. "/" .. path)
        if m == nil then m = true end
        cache[path] = m
    end
    return m
end

Ext = {}
Osi = {}

local ok = Req("Tests/All.lua").Run()
os.exit(ok and 0 or 1)
