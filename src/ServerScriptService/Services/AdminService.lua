local module = {}

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

--//Dependecies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local AdminsData = require(ReplicatedStorage.Modules.Data.Admins)
local CommandsData = require(ReplicatedStorage.Modules.Data.Commands)

--//Instances
--local Commands = script.Commands
local Commands = ServerScriptService.Services.CommandsService.CustomCommands
local AdminGuiButton = ServerStorage.AdminGui
local AdminGuiScreen = ServerStorage.AdminGuiScreen

--//STATE
local _commandsCache = {}

-- PRIVATE
local function setCommandCache()
	for _, commandModule in Commands:GetChildren() do
		if not commandModule:IsA("ModuleScript") or not string.find(commandModule.Name, "Server") then
			continue
		end

		_commandsCache[commandModule.Name] = commandModule
	end
end

local function requireCommand(commandName: string)
	if next(_commandsCache) == nil then
		return nil, "No admin commands are loaded."
	end

	local formattedName = `{commandName}Server`

	local targetModule = _commandsCache[formattedName]
	if not targetModule then
		return nil, (`Command module "{formattedName}" was not found.`)
	end

	local result, requiredModule = pcall(function()
		return require(targetModule)
	end)
	if not result or not requiredModule then
		return nil, tostring(requiredModule)
	end

	return requiredModule, nil
end

local function resolveCommandData(commandName: string)
	local exactCommandData = CommandsData[commandName]
	if exactCommandData then
		return exactCommandData
	end

	for _, commandData in CommandsData do
		if commandData.PrivateName == commandName then
			return commandData
		end
	end

	return nil
end

local function isAdmin(player: Player)
	return AdminsData[player.UserId]
end

-- PUBLIC
function module:Start()
	setCommandCache()
	Packets.Admin.OnServerInvoke = function(player: Player)
		if not isAdmin(player) then
			return
		end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local hudScreen = playerGui:FindFirstChild("HudGui")
		if not hudScreen or not hudScreen:IsA("ScreenGui") then
			return
		end

		local bottomFrame = hudScreen:FindFirstChild("BottomFrame")
		if not bottomFrame then
			return
		end

		local newButton = AdminGuiButton:Clone()
		newButton.Parent = bottomFrame

		local newScreen = AdminGuiScreen:Clone()
		newScreen.Name = "AdminGui"
		newScreen.Parent = playerGui

		return "Loaded"
	end

	Packets.Command.OnServerEvent:Connect(function(player: Player, params)
		if not isAdmin(player) then
			return
		end
		local commandName = params["Command"]
		if not commandName then
			return
		end

		local commandModule, commandLoadError = requireCommand(commandName)
		if not commandModule then
			Packets.Command:FireClient(player, {"Error", commandLoadError or (`Command "{commandName}" is unavailable.`)})
			return
		end

		local commandData = resolveCommandData(commandName)
		if not commandData then
			Packets.Command:FireClient(player, {"Error", (`Command "{commandName}" has no registered metadata.`)})
			return
		end

		local context = {
			Executor = player,
			Error = function(_self, errorMessage: string)
				warn(errorMessage)
				Packets.Command:FireClient(player, {"Error", errorMessage})
			end,

			SendEvent = function(_self, executor: Player, eventType: string, message: string)
				Packets.Command:FireClient(executor, {eventType, message})	
			end
		}

		local args = {
			context
		}
		for _, paramName in commandData.Parameters do
			table.insert(args, params[paramName])
		end

		local success, errorMessage = pcall(function()
			commandModule(table.unpack(args))
		end)
		if not success then
			warn(errorMessage)
			Packets.Command:FireClient(player, {"Error", tostring(errorMessage)})
		end
	end)
end

return module
