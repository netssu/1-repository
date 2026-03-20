------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local BOOST_ICONS = {
	Coins2x = "rbxassetid://81187465021797",
	Lucky2x = "rbxassetid://124014027649385",
}
local BOOST_NAMES = {
	Coins2x = "2xCoinsPotion",
	Lucky2x = "2xLuckyPotion",
}

------------------//VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local UI = PlayerGui:WaitForChild("UI")
local GameHUD = UI:WaitForChild("GameHUD")
local PowerupsFR = GameHUD:WaitForChild("PowerupsFR")
local PowerupBGTemplate = PowerupsFR:WaitForChild("PowerupBG")
local activeBoostUIs = {}
local boostTimers = {}

------------------//FUNCTIONS
local function formatTime(seconds)
	if not seconds then return "0:00" end
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local function createBoostUI(boostName)
	if activeBoostUIs[boostName] then
		return activeBoostUIs[boostName]
	end

	local boostUI = PowerupBGTemplate:Clone()
	boostUI.Name = boostName

	local powerUpTX = boostUI:FindFirstChild("PowerUpsTX")
	if powerUpTX then powerUpTX.Text = BOOST_NAMES[boostName] or boostName end

	local icon = boostUI:FindFirstChild("Icon")
	if icon then icon.Image = BOOST_ICONS[boostName] or "" end

	local timeTX = boostUI:FindFirstChild("TimeTX")
	if timeTX then timeTX.Text = "0:00" end

	boostUI.Visible = true
	boostUI.Parent = PowerupsFR

	return boostUI
end

local function removeBoostUI(boostName)
	if activeBoostUIs[boostName] then
		activeBoostUIs[boostName]:Destroy()
		activeBoostUIs[boostName] = nil
	end
	if boostTimers[boostName] and boostTimers[boostName] <= 0 then
		boostTimers[boostName] = nil
	end
end

local function updateBoostTimer(boostName, timeRemaining)
	if not activeBoostUIs[boostName] then return end
	local timeTX = activeBoostUIs[boostName]:FindFirstChild("TimeTX")
	if timeTX then
		timeTX.Text = formatTime(math.max(0, math.ceil(timeRemaining)))
	end
	if timeRemaining <= 0 then
		removeBoostUI(boostName)
	end
end

local function handleBoostActivation(boostName, duration)
	if duration and duration > 0 then
		if not activeBoostUIs[boostName] then
			activeBoostUIs[boostName] = createBoostUI(boostName)
		end
		boostTimers[boostName] = duration
		updateBoostTimer(boostName, duration)
	else
		removeBoostUI(boostName)
	end
end

------------------//INIT
DATA_UTILITY.client.ensure_remotes()
PowerupBGTemplate.Visible = false

RunService.Heartbeat:Connect(function(dt)
	for boostName, timeRemaining in pairs(boostTimers) do
		if timeRemaining > 0 then
			local newTime = timeRemaining - dt
			boostTimers[boostName] = newTime
			updateBoostTimer(boostName, newTime)
		else
			if activeBoostUIs[boostName] then
				removeBoostUI(boostName)
			end
		end
	end
end)

Player:GetAttributeChangedSignal("Coins2xDuration"):Connect(function()
	local duration = Player:GetAttribute("Coins2xDuration") or 0
	handleBoostActivation("Coins2x", duration)
end)

Player:GetAttributeChangedSignal("Lucky2xDuration"):Connect(function()
	local duration = Player:GetAttribute("Lucky2xDuration") or 0
	handleBoostActivation("Lucky2x", duration)
end)

task.wait(2)
local initialCoins2x = Player:GetAttribute("Coins2xDuration") or 0
local initialLucky2x = Player:GetAttribute("Lucky2xDuration") or 0
if initialCoins2x > 0 then handleBoostActivation("Coins2x", initialCoins2x) end
if initialLucky2x > 0 then handleBoostActivation("Lucky2x", initialLucky2x) end