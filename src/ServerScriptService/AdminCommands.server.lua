local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminCommands = require(script:WaitForChild("AdminCommands"))

local GROUP_ID = 35339513
local REQUIRED_RANK = 252

local TraitModule = require(ReplicatedStorage.Modules.Traits)
local UnitModule = require(ReplicatedStorage.Upgrades)

local function isValidUnit(unitName)
	return UnitModule[unitName] ~= nil
end

local function isValidTrait(trait)
	return TraitModule.Traits[trait] ~= nil
end

local function splitMessage(message)
	local args = {}
	local inQuotes = false
	local currentArg = ""

	for char in message:gmatch(".") do
		if char == '"' then
			inQuotes = not inQuotes
		elseif char == " " and not inQuotes then
			if currentArg ~= "" then
				table.insert(args, currentArg)
				currentArg = ""
			end
		else
			currentArg = currentArg .. char
		end
	end

	if currentArg ~= "" then
		table.insert(args, currentArg)
	end

	return args
end

local function onPlayerChatted(player, message)
	local rank = player:GetRankInGroup(GROUP_ID)

	if rank >= REQUIRED_RANK then
		local args = splitMessage(message)

		if #args >= 3 then
			local command = args[1]:lower()

			if command == "!givecoins" then
				if #args == 3 then
					local playerName = args[2]
					local amount = tonumber(args[3])

					if amount then
						print("Executing giveCoins with playerName: " .. playerName .. ", amount: " .. amount)
						AdminCommands.giveCoins(playerName, amount)
					else
						warn("Invalid amount: " .. args[3])
					end
				else
					warn("Invalid number of arguments for !givecoins")
				end

			elseif command == "!givegems" then
				if #args == 3 then
					local playerName = args[2]
					local amount = tonumber(args[3])

					if amount then
						print("Executing giveGems with playerName: " .. playerName .. ", amount: " .. amount)
						AdminCommands.giveGems(playerName, amount)
					else
						warn("Invalid amount: " .. args[3])
					end
				else
					warn("Invalid number of arguments for !givegems")
				end

			elseif command == "!giveunits" then
				if #args >= 4 then
					local playerName = args[2]
					local unitName = args[3]
					local trait = table.concat(args, " ", 4)

					if isValidUnit(unitName) and isValidTrait(trait) then
						print("Executing giveUnit with playerName: " .. playerName .. ", unitName: " .. unitName .. ", trait: " .. trait)
						AdminCommands.giveUnit(playerName, unitName, trait)
					else
						warn("Invalid unit or trait: " .. unitName .. ", " .. trait)
					end
				else
					warn("Invalid number of arguments for !giveunits")
				end

			else
				warn("Invalid command: " .. command)
			end

		end
	else
		warn(player.Name .. " does not have the required rank to execute commands.")
	end
end

local function onPlayerAdded(player)
	player.Chatted:Connect(function(message)
		--onPlayerChatted(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end