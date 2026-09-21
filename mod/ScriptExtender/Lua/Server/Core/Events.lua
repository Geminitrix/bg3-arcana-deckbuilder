local E = { handlers = {} }

function E.On(name, fn)
    local list = E.handlers[name]
    if not list then
        list = {}
        E.handlers[name] = list
    end
    list[#list + 1] = fn
end

function E.Emit(name, ctx)
    for _, fn in ipairs(E.handlers[name] or {}) do
        local ok, err = pcall(fn, ctx)
        if not ok then print("[ArcanaDeck] handler error in " .. name .. ": " .. tostring(err)) end
    end
end

return E
