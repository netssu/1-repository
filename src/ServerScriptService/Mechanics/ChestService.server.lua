------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local GOLD_MIN = 50
local GOLD_MAX = 1000
local TOUCH_DISTANCE = 8
local CHEST_NAME = "Chest"
local REWARDS = {
	{type = "Gold",        weight = 40},
	{type = "CoinsPotion", weight = 30},
	{type = "LuckyPotion", weight = 30},
}

------------------//VARIABLES
local playerChestCooldowns = {}
local openEvent = nil
local rewardEvent = nil

------------------//FUNCTIONS
local function generateGoldReward()
	return math.random(GOLD_MIN, GOLD_MAX)
end

local function selectReward()
	local totalWeight = 0
	for _, reward in ipairs(REWARDS) do
		totalWeight += reward.weight
	end
	local randomValue = math.random() * totalWeight
	local cumulativeWeight = 0
	for _, reward in ipairs(REWARDS) do
		cumulativeWeight += reward.weight
		if randomValue <= cumulativeWeight then
			return reward.type
		end
	end
	return "Gold"
end

local function setupChestPrompt(object)
	if object.Name ~= CHEST_NAME or not object:IsA("Model") then return end

	local promptPart = object:FindFirstChild("KeyHole", true)
	if not promptPart then return end
	if promptPart:FindFirstChildOfClass("ProximityPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TOUCH_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		local userId = player.UserId
		local lastOpen = playerChestCooldowns[userId]
		if lastOpen and (os.clock() - lastOpen) < 1 then return end
		playerChestCooldowns[userId] = os.clock()

		object:Destroy()

		local rewardType = selectReward()
		local rewards = {}

		if rewardType == "Gold" then
			local goldAmount = generateGoldReward()
			local ownedUpgrades = DATA_UTILITY.server.get(player, "OwnedRebirthUpgrades") or {}
			if table.find(ownedUpgrades, "ChestFortune") then
				goldAmount = goldAmount * 2
			end
			local currentGold = DATA_UTILITY.server.get(player, "Coins") or 0
			DATA_UTILITY.server.set(player, "Coins", currentGold + goldAmount)
			rewards.gold = goldAmount
			print("[CHEST] " .. player.Name .. " recebeu " .. goldAmount .. " moedas")
		else
			local currentPotions = DATA_UTILITY.server.get(player, "Potions") or {}
			currentPotions[rewardType] = (currentPotions[rewardType] or 0) + 1
			DATA_UTILITY.server.set(player, "Potions", currentPotions)
			rewards.potion = rewardType
			print("[CHEST] " .. player.Name .. " recebeu a poção: " .. rewardType)
		end

		rewardEvent:FireClient(player, rewards)
	end)
end

local function setupRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")

	openEvent = remotesFolder:FindFirstChild("ChestOpenEvent")
	if not openEvent then
		openEvent = Instance.new("RemoteEvent")
		openEvent.Name = "ChestOpenEvent"
		openEvent.Parent = remotesFolder
	end

	rewardEvent = remotesFolder:FindFirstChild("ChestRewardEvent")
	if not rewardEvent then
		rewardEvent = Instance.new("RemoteEvent")
		rewardEvent.Name = "ChestRewardEvent"
		rewardEvent.Parent = remotesFolder
	end

	openEvent.OnServerEvent:Connect(function(player)
		print("[CHEST] OpenEvent recebido de", player.Name)
	end)
end

local function onPlayerRemoving(player)
	playerChestCooldowns[player.UserId] = nil
end

------------------//INIT
DATA_UTILITY.server.ensure_remotes()
setupRemotes()
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, child in pairs(workspace.Chests:GetChildren()) do
	setupChestPrompt(child)
end

workspace.Chests.ChildAdded:Connect(setupChestPrompt)

_G.ChestRewards = {
	GOLD_MIN = GOLD_MIN,
	GOLD_MAX = GOLD_MAX,
}