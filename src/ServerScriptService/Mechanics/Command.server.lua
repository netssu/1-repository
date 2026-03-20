------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)

------------------//CONFIG
local ADMINS = {
	[12345678] = true, -- COLOQUE SEU ID AQUI goofy gemini
	[game.CreatorId] = true
}

local PREFIX = ":"

------------------//FUNCTIONS
local function get_args(msg)
	local args = string.split(msg, " ")
	local cmd = string.lower(string.sub(table.remove(args, 1), #PREFIX + 1))
	return cmd, args
end

local function teleport_to_world(player, worldId)
	local worldData = WorldConfig.GetWorld(worldId)
	if worldData and player.Character then
		DataUtility.server.set(player, "CurrentWorld", worldId)
		DataUtility.server.set(player, "PogoSettings.gravity_mult", worldData.gravityMult)
		player.Character:PivotTo(worldData.entryCFrame)
	end
end

local COMMANDS = {
	["force"] = function(player, args)
		local amount = tonumber(args[1])
		if amount then
			DataUtility.server.set(player, "PogoSettings.base_jump_power", amount)
			print("Força definida para:", amount)
		end
	end,

	["coins"] = function(player, args)
		local amount = tonumber(args[1])
		if amount then
			DataUtility.server.set(player, "Coins", amount)
			print("Coins definidos para:", amount)
		end
	end,

	["addcoins"] = function(player, args)
		local amount = tonumber(args[1])
		if amount then
			local current = DataUtility.server.get(player, "Coins") or 0
			DataUtility.server.set(player, "Coins", current + amount)
			print("Adicionado coins:", amount)
		end
	end,

	["rebirths"] = function(player, args)
		local amount = tonumber(args[1])
		if amount then
			DataUtility.server.set(player, "Rebirths", amount)
			print("Rebirths definidos para:", amount)
		end
	end,

	["world"] = function(player, args)
		local worldId = tonumber(args[1])
		if worldId then
			teleport_to_world(player, worldId)
			print("Teleportado para mundo:", worldId)
		end
	end,

	["speed"] = function(player, args)
		local amount = tonumber(args[1])
		if amount and player.Character then
			player.Character.Humanoid.WalkSpeed = amount
		end
	end,

	["reset"] = function(player, args)
		DataUtility.server.set(player, "PogoSettings.base_jump_power", 0)
		DataUtility.server.set(player, "Coins", 0)
		DataUtility.server.set(player, "Rebirths", 0)
		teleport_to_world(player, 1)
		print("Conta resetada")
	end
}

------------------//INIT
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		--if not ADMINS[player.UserId] then return end
		if string.sub(msg, 1, #PREFIX) ~= PREFIX then return end

		local cmd, args = get_args(msg)

		if COMMANDS[cmd] then
			COMMANDS[cmd](player, args)
		end
	end)
end)