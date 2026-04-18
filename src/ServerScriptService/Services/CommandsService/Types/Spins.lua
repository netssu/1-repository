return function(registry)

    local spinsNames = {
        "SpinFlow",
        "SpinStyle"
    }
    registry:RegisterType("spins", registry.Cmdr.Util.MakeEnumType("spins", spinsNames))
end
