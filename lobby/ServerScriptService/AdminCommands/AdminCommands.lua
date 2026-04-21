local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitModule = require(ReplicatedStorage.Upgrades)
local TraitModule = require(ReplicatedStorage.Modules.Traits)

local AdminCommands = {}

local function getPlayerByName(playerName)
	for _, player in Players:GetPlayers() do
		if player.Name == playerName then
			return player
		end
	end
	warn("Player not found: " .. playerName)
	return nil
end

local function warnMissingValue(playerName, valueName)
	warn(playerName .. " does not have a " .. valueName .. " value.")
end

function AdminCommands.giveCoins(playerName, amount)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local coins = targetPlayer:FindFirstChild("Coins")
		if coins then
			coins.Value = coins.Value + amount
			print(playerName .. " has been given " .. amount .. " coins.")
		else
			warnMissingValue(playerName, "Coins")
		end
	end
end

function AdminCommands.giveGems(playerName, amount)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local gems = targetPlayer:FindFirstChild("Gems")
		if gems then
			gems.Value = gems.Value + amount
			print(playerName .. " has been given " .. amount .. " gems.")
		else
			warnMissingValue(playerName, "Gems")
		end
	end
end

function AdminCommands.giveUnit(playerName, unitName, trait)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local towerStorage = targetPlayer:FindFirstChild("OwnedTowers")
		if towerStorage then
			if not UnitModule[unitName] then
				warn("Unit not found: " .. unitName)
				return
			end
			if not TraitModule.Traits[trait] then
				warn("Invalid trait: " .. trait)
				return
			end

			-- Create the new tower
			local newTower = Instance.new("StringValue")
			newTower.Name = unitName
			newTower.Value = trait
			newTower.Parent = towerStorage

			print(playerName .. " has been given a new unit: " .. unitName .. " with trait: " .. trait)
		else
			warnMissingValue(playerName, "OwnedTowers folder")
		end
	end
end

return AdminCommands