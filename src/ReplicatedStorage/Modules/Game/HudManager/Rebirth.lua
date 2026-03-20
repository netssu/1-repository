------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REBIRTH_SCALE = 0.5

------------------//VARIABLES
local RebirthController = {}
local localPlayer = Players.LocalPlayer

local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RebirthConfig"))
local MathUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("MathUtility"))
local NotificationUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

local rebirthEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("RebirthAction")

local currentRebirths = 0
local currentCoins = 0
local hasNotifiedAvailability = false

------------------//FUNCTIONS
local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local mainGui = playerGui:FindFirstChild("GUI")
	if not mainGui then return nil end

	local rebirthFrame = mainGui:FindFirstChild("RebirthFrame")
	if not rebirthFrame then return nil end

	local levelDisplay = rebirthFrame:FindFirstChild("LevelDisplay")
	local levelText = levelDisplay and levelDisplay:FindFirstChild("LevelText")

	local priceDisplay = rebirthFrame:FindFirstChild("PriceDisplay")
	local priceText = priceDisplay and priceDisplay:FindFirstChild("PriceText")

	local rebirthButton = rebirthFrame:FindFirstChild("RebirthButton")
	local rewardHolder = rebirthFrame:FindFirstChild("RewardHolder")

	return {
		Main = rebirthFrame,
		LevelText = levelText,
		PriceText = priceText,
		RebirthBtn = rebirthButton,
		RewardHolder = rewardHolder
	}
end

local function check_availability_and_notify()
	local coinsReq = RebirthConfig.GetRequirement(currentRebirths)
	local canRebirth = currentCoins >= coinsReq

	if canRebirth then
		if not hasNotifiedAvailability then
			NotificationUtility:Info("Rebirth Available", 5)
			hasNotifiedAvailability = true
		end
	else
		hasNotifiedAvailability = false
	end

	return canRebirth
end

local function update_rewards_display(ui)
	if not ui.RewardHolder then return end

	local REWARDS_DATA = {
		["RareHolder"] = {
			Icon = "rbxassetid://70682584492943", 
			Text = "+1 Rebirth Token" 
		},
		["EpicHolder"] = {
			Icon = "rbxassetid://113221502801232", 
			Text = "+x0.5 Power Multiplier" 
		},
		["LegendaryHolder"] = {
			Icon = "rbxassetid://77228037161086", 
			Text = "Reset Progress" 
		}
	}

	for holderName, data in pairs(REWARDS_DATA) do
		local holderFrame = ui.RewardHolder:FindFirstChild(holderName)

		if holderFrame then
			local iconImage = holderFrame:FindFirstChild("IconImage")
			local amountText = holderFrame:FindFirstChild("AmountText")

			if iconImage and iconImage:IsA("ImageLabel") then
				iconImage.Image = data.Icon
				iconImage.ImageTransparency = 0
			end

			if amountText and amountText:IsA("TextLabel") then
				amountText.Text = data.Text
			end
		end
	end
end

local function update_full_ui()
	local ui = get_ui_references()
	if not ui then return end

	if ui.LevelText then
		ui.LevelText.Text = tostring(currentRebirths + 1)
	end

	local coinsReq = RebirthConfig.GetRequirement(currentRebirths)
	if ui.PriceText then
		ui.PriceText.Text = MathUtility.format_number(coinsReq)
	end

	if ui.RebirthBtn then
		local canRebirth = check_availability_and_notify()

		if canRebirth then
			ui.RebirthBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
			ui.RebirthBtn.Active = true
		else
			ui.RebirthBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			ui.RebirthBtn.Active = false
		end
	end

	update_rewards_display(ui)
end

local function setup_interactions(ui)
	if ui.RebirthBtn then
		ui.RebirthBtn.Activated:Connect(function()
			local coinsReq = RebirthConfig.GetRequirement(currentRebirths)
			if currentCoins >= coinsReq then
				rebirthEvent:FireServer()
			end
		end)
	end
end

------------------//INIT
DataUtility.client.ensure_remotes()

DataUtility.client.bind("Rebirths", function(val)
	currentRebirths = val or 0
	update_full_ui()
end)

DataUtility.client.bind("Coins", function(val)
	currentCoins = val or 0
	update_full_ui()
end)

rebirthEvent.OnClientEvent:Connect(function(status)
	if status == "Success" then
		local currentMult = 1 + (currentRebirths * REBIRTH_SCALE)
		local msg = string.format("You gained +1 Rebirth Token\nMultiplier: x%.1f", currentMult)

		NotificationUtility:Success(msg, 5)
		hasNotifiedAvailability = false
	end
end)

currentRebirths = DataUtility.client.get("Rebirths") or 0
currentCoins = DataUtility.client.get("Coins") or 0

task.spawn(function()
	task.wait(1)
	local ui = get_ui_references()
	if ui then
		setup_interactions(ui)
		update_full_ui()
	end
end)

return RebirthController
