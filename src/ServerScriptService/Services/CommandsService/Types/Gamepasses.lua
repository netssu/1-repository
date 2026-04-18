return function(registry)
	local statsNames = {
		"GamePassVip",
		"SkipSpin",
		"ToxicEmotes",
		"AnimeEmotes",
	}
    
	registry:RegisterType("gamepasses", registry.Cmdr.Util.MakeEnumType("gamepasses", statsNames))
end
