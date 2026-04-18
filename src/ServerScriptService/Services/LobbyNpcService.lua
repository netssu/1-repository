--!strict

local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local RigUtil: any = require(ServerScriptService.Services.Utils.RigUtil)

local LobbyNpcService = {}

function LobbyNpcService.Init(_self: typeof(LobbyNpcService)): ()
	return
end

function LobbyNpcService.Start(_self: typeof(LobbyNpcService)): ()
	RigUtil.Start()
end

return LobbyNpcService
