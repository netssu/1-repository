------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild(
	"DataUtility"))

local BASE_LUCKY = 1

local BOOST_MULTIPLIERS = {
	Coins2x = 2,
	Lucky2x = 2,
}

local BOOST_DURATION = 120

------------------//VARIABLES
local boostTimers = {}
local playerMultiplierFactor = {}
local playerLuckyFactor = {}

------------------//FUNCTIONS
local function updatePlayerMultiplier(player)
	local userId = player.UserId
	local oldFactor = playerMultiplierFactor[userId] or 1

	local coins2xDuration = player:GetAttribute("Coins2xDuration") or 0
	local newFactor = coins2xDuration > 0 and BOOST_MULTIPLIERS.Coins2x or 1

	if newFactor == oldFactor then return end

	local currentTotal = player:GetAttribute("Multiplier") or 1
	local baseWithoutBoost = currentTotal / (oldFactor > 0 and oldFactor or 1)
	local finalMultiplier = baseWithoutBoost * newFactor

	playerMultiplierFactor[userId] = newFactor
	player:SetAttribute("Multiplier", finalMultiplier)
end

local function updatePlayerLucky(player)
	local userId = player.UserId
	local oldFactor = playerLuckyFactor[userId] or 1

	local lucky2xDuration = player:GetAttribute("Lucky2xDuration") or 0
	local newFactor = lucky2xDuration > 0 and BOOST_MULTIPLIERS.Lucky2x or 1

	if newFactor == oldFactor then return end

	local currentTotal = player:GetAttribute("Lucky") or BASE_LUCKY
	local baseWithoutBoost = currentTotal / (oldFactor > 0 and oldFactor or 1)
	local finalLucky = baseWithoutBoost * newFactor

	playerLuckyFactor[userId] = newFactor
	player:SetAttribute("Lucky", finalLucky)
end

local function startBoostTimer(player, boostName)
	local userId = player.UserId

	if not boostTimers[userId] then
		boostTimers[userId] = {}
	end

	if boostTimers[userId][boostName] then
		return
	end

	if boostName == "Coins2x" then
		updatePlayerMultiplier(player)
	elseif boostName == "Lucky2x" then
		updatePlayerLucky(player)
	end

	boostTimers[userId][boostName] = task.spawn(function()
		while true do
			if not player or not player.Parent then break end

			local currentDuration = player:GetAttribute(boostName .. "Duration") or 0
			if currentDuration <= 0 then break end

			task.wait(1)

			local newDuration = (player:GetAttribute(boostName .. "Duration") or 0) - 1
			player:SetAttribute(boostName .. "Duration", math.max(0, newDuration))
		end

		player:SetAttribute(boostName .. "Duration", 0)
		DATA_UTILITY.server.set(player, "Boosts." .. boostName, 0)

		if boostTimers[userId] then
			boostTimers[userId][boostName] = nil
		end

		if boostName == "Coins2x" then
			updatePlayerMultiplier(player)
		elseif boostName == "Lucky2x" then
			updatePlayerLucky(player)
		end
	end)
end

local function activateBoost(player, boostName, duration)
	if not player or not player:IsDescendantOf(Players) then return end
	if BOOST_MULTIPLIERS[boostName] == nil then return end

	duration = duration or BOOST_DURATION

	local currentDuration = player:GetAttribute(boostName .. "Duration") or 0
	local newDuration = currentDuration + duration

	player:SetAttribute(boostName .. "Duration", newDuration)
	DATA_UTILITY.server.set(player, "Boosts." .. boostName, newDuration)

	startBoostTimer(player, boostName)
end

local function deactivateBoost(player, boostName)
	if not player or not player:IsDescendantOf(Players) then return end

	local userId = player.UserId

	player:SetAttribute(boostName .. "Duration", 0)
	DATA_UTILITY.server.set(player, "Boosts." .. boostName, 0)

	if boostTimers[userId] and boostTimers[userId][boostName] then
		task.cancel(boostTimers[userId][boostName])
		boostTimers[userId][boostName] = nil
	end

	if boostName == "Coins2x" then
		updatePlayerMultiplier(player)
	elseif boostName == "Lucky2x" then
		updatePlayerLucky(player)
	end
end

local function initPlayerBoosts(player)
	local coins2xTime = tonumber(DATA_UTILITY.server.get(player, "Boosts.Coins2x")) or 0
	local lucky2xTime = tonumber(DATA_UTILITY.server.get(player, "Boosts.Lucky2x")) or 0

	player:SetAttribute("Coins2xDuration", coins2xTime)
	player:SetAttribute("Lucky2xDuration", lucky2xTime)

	if coins2xTime > 0 then startBoostTimer(player, "Coins2x") end
	if lucky2xTime > 0 then startBoostTimer(player, "Lucky2x") end
end

local function savePlayerBoosts(player)
	local coins2xTime = player:GetAttribute("Coins2xDuration") or 0
	local lucky2xTime = player:GetAttribute("Lucky2xDuration") or 0

	DATA_UTILITY.server.set(player, "Boosts.Coins2x", coins2xTime)
	DATA_UTILITY.server.set(player, "Boosts.Lucky2x", lucky2xTime)
end

------------------//INIT
DATA_UTILITY.server.ensure_remotes()

local boostRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):FindFirstChild("BoostRemote")

boostRemote.OnServerEvent:Connect(function(player, action, boostName, duration)
	if action == "activate" then
		activateBoost(player, boostName, duration)
	elseif action == "deactivate" then
		deactivateBoost(player, boostName)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local userId = player.UserId

	playerMultiplierFactor[userId] = 1
	playerLuckyFactor[userId] = 1

	if not player:GetAttribute("Multiplier") then
		player:SetAttribute("Multiplier", 1)
	end

	if not player:GetAttribute("Lucky") then
		player:SetAttribute("Lucky", BASE_LUCKY)
	end

	task.wait(1)
	initPlayerBoosts(player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerBoosts(player)

	local userId = player.UserId
	if boostTimers[userId] then
		for _, timerThread in pairs(boostTimers[userId]) do
			if timerThread then task.cancel(timerThread) end
		end
		boostTimers[userId] = nil
	end
	playerMultiplierFactor[userId] = nil
	playerLuckyFactor[userId] = nil
end)

_G.BoostManager = {
	activateBoost = activateBoost,
	deactivateBoost = deactivateBoost
}