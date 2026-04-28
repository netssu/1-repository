-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- CONSTANTS
local SKIP_DAY_PRODUCT_ID = 3305696523

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local NewUI = PlayerGui:WaitForChild("NewUI")
local DailyUI = NewUI:WaitForChild("DailyRewardFrame")

local Main = DailyUI:WaitForChild("Main")
local SlotsFrame = Main:WaitForChild("Slots")
local SlotsContents = SlotsFrame:WaitForChild("Contents")
local Slot7 = SlotsFrame:WaitForChild("7")
local SkipDayBtn = DailyUI:WaitForChild("Days"):WaitForChild("SkipADay")

local DailyReward = require(ReplicatedStorage.Modules.DailyReward)
local ClaimReward = ReplicatedStorage.Functions.ClaimReward
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local Upgrades = require(ReplicatedStorage.Upgrades)
local UiHandler = require(ReplicatedStorage.Modules.Client.UIHandler)

local gemSet = false

-- FUNCTIONS
local function updateGemsTextIfDouble()
	if gemSet then return end
	if Player.OwnGamePasses["x2 Gems"].Value then
		for _, v in DailyUI:GetDescendants() do
			if v.Name == "GemsTextLabel" and v:IsA("TextLabel") then
				local baseAmount = tonumber(v.Text:match("%d+"))
				if baseAmount then
					v.Text = "x" .. tostring(baseAmount * 2)
				end
			end
		end
	end
	gemSet = true
end

local function GetDisplayDay(index)
	local nextClaim = Player.DailyRewards.NextClaim.Value
	local div = math.floor(nextClaim / 7)

	local startDay = (div * 7) + 1
	if nextClaim % 7 == 0 then
		startDay = ((div - 1) * 7) + 1
	end

	return startDay + index - 1
end

local function UpdateSlotVisuals(ui, displayDay)
	local nextClaimValue = Player.DailyRewards.NextClaim.Value

	local container = ui:FindFirstChild("Container")
	local overlay = ui:FindFirstChild("Overlay")

	local dayText = container and container:FindFirstChild("Day")
	local timeText = container and container:FindFirstChild("Time")

	local lock = overlay and overlay:FindFirstChild("Lock")
	local check = overlay and overlay:FindFirstChild("Check")

	if dayText and dayText:IsA("TextLabel") then
		dayText.Text = "Day " .. tostring(displayDay)
	end

	if displayDay < nextClaimValue then
		if lock then lock.Visible = false end
		if check then check.Visible = true end
		if timeText then timeText.Visible = false end

	elseif displayDay == nextClaimValue then
		if lock then lock.Visible = false end
		if check then check.Visible = false end
		if timeText then timeText.Visible = true end

	else
		if lock then lock.Visible = true end
		if check then check.Visible = false end
		if timeText then timeText.Visible = true end
	end

	if timeText and timeText.Visible then
		local climableInSeconds = DailyReward.GetTimeUntilClaim(Player, displayDay)

		if climableInSeconds <= 0 then
			timeText.Text = "Redeem"
		else
			local hours = math.floor(climableInSeconds / 3600)
			local minutes = math.floor((climableInSeconds % 3600) / 60)
			local seconds = climableInSeconds % 60

			timeText.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
		end
	end
end

local function SetupButtonClick(ui, index)
	local btn = ui:FindFirstChild("Btn")

	if not btn then return end

	local clicked = false
	btn.Activated:Connect(function()
		if clicked then return end
		clicked = true

		local displayDay = GetDisplayDay(index)

		if Player.DailyRewards.NextClaim.Value ~= displayDay then
			clicked = false
			return
		end

		local climableInSeconds = DailyReward.GetTimeUntilClaim(Player, displayDay)
		if climableInSeconds > 0 then
			clicked = false
			return
		end

		local success, claimable, unit, Rarity = pcall(function()
			return ClaimReward:InvokeServer()
		end)

		if not success or not claimable then
			clicked = false
			return
		end

		local tower = nil
		if typeof(unit) == "string" and unit ~= "" and Rarity then
			local attempts = 0 

			repeat
				tower = nil
				local rarityFolder = ReplicatedStorage.Towers:FindFirstChild(Rarity)

				if rarityFolder then
					for _, v in pairs(rarityFolder:GetChildren()) do
						if v.Name == unit and v:IsA("Model") then
							tower = v
							break
						end
					end
				end

				if not tower then
					attempts += 1
					task.wait(1)
				end
			until tower or attempts >= 10 
		end

		if unit then
			ViewModule.Hatch({
				Upgrades[unit],
				tower,
				nil,
				true
			})
			if _G.CloseAll then _G.CloseAll() end
			UiHandler.EnableAllButtons()
		end

		task.delay(5, function()
			clicked = false
		end)
	end)
end

local function RefreshUI()
	for index = 1, 7 do
		local displayDay = GetDisplayDay(index)
		local rewardDayUI

		if index == 7 then
			rewardDayUI = Slot7
		else
			rewardDayUI = SlotsContents:FindFirstChild(tostring(index))
		end

		if rewardDayUI then
			UpdateSlotVisuals(rewardDayUI, displayDay)
		end
	end

	updateGemsTextIfDouble()
end

-- INIT
Player:WaitForChild("DataLoaded")

for i = 1, 6 do
	local slot = SlotsContents:FindFirstChild(tostring(i))
	if slot then
		SetupButtonClick(slot, i)
	end
end
SetupButtonClick(Slot7, 7)

RefreshUI()

task.spawn(function()
	while task.wait(1) do
		RefreshUI()
	end
end)


SkipDayBtn.Activated:Connect(function()
	MarketplaceService:PromptProductPurchase(Player, SKIP_DAY_PRODUCT_ID)
end)