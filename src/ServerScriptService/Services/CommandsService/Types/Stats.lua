return function(registry)
	local statsNames = {
		"Yen",
		"Level",
		"Rating",
		"MVP",
		"Touchdowns",
		"Passing",
		"Tackles",
		"Wins",
		"Timer",
		"Intercepts",
		"Assists",
		"Possession",

		"SpinStyle",
		"StyleLuckySpins",
        
        "SpinFlow",
		"FlowLuckySpins",

	}
	registry:RegisterType("stats", registry.Cmdr.Util.MakeEnumType("stats", statsNames))

	registry:RegisterType("anyValue", {
        Transform = function(rawText: string)
            local asNumber = tonumber(rawText)
            if asNumber then return asNumber end

            if rawText == "true" then return true end
            if rawText == "false" then return false end

            return rawText
        end,

        Validate = function(value)
            local typeOfValue = typeof(value)
            if typeOfValue == "number" or typeOfValue == "boolean" or typeOfValue == "string" then
                return true
            end
            return false, "Value must be a number, boolean, or string"
        end,

        Parse = function(value)
            return value
        end,
    })
end   

