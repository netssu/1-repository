local DailyReward = require(game.ReplicatedStorage.Modules.DailyReward)
local ClaimReward = game.ReplicatedStorage.Functions.ClaimReward
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DailyRewardFrame = script.Parent.DailyRewardFrame
local Main = DailyRewardFrame.Frame
local RewardsContainer = Main.Rewards_Frame.Bar
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local Upgrades = require(ReplicatedStorage.Upgrades)
local Player = game.Players.LocalPlayer
local UiHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)
Player:WaitForChild("DataLoaded")

local gemSet = false

local function updateGemsTextIfDouble()
	if gemSet then return end
	if Player.OwnGamePasses["x2 Gems"].Value then
		for _, v in script.Parent:GetDescendants() do
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

local function NewButton(ui, displayDay)
	local nextClaimValue = Player.DailyRewards.NextClaim.Value
	local uiDay = displayDay
	local contents = ui.Contents
	
	if contents.Contents:FindFirstChild("Title") and contents.Contents.Title:IsA("TextLabel") then
		contents.Contents.Title.Text = "Day " .. tostring(displayDay)
	end

	if uiDay < nextClaimValue then
		if ui.Name == "7" then
			ui.Contents.Contents.Lock.Visible = false
			ui.Contents.Contents.Check.Visible = true
			ui.Time.Visible = false
		else
			ui.Contents.Overlay.Lock.Visible = false
			ui.Contents.Overlay.Check.Visible = true
			ui.Time.Visible = false		
		end
	
	else
		ui.Time.Visible = true

		local climableInSeconds = DailyReward.GetTimeUntilClaim(Player, uiDay)
		local climableInText

		if climableInSeconds > (3600 * 24) then
			climableInText = tostring(math.floor(climableInSeconds / (3600 * 24))) .. " Days"
		elseif climableInSeconds > 3600 then
			local num = math.floor(climableInSeconds%3600 / 60)
			climableInText = tostring(math.floor(climableInSeconds / 3600)) .. " hours " .. num .. " minutes"
		else
			local num = math.floor(climableInSeconds / 60)
			climableInText = (num == 0) and "Redeem" or (tostring(num) .. " minutes")
		end

		ui.Time.Text = climableInText

		if climableInSeconds <= 0 then
			if ui.Name == "7" then
				ui.Contents.Contents.Lock.Visible = false
			else
				ui.Contents.Overlay.Lock.Visible = false
			end
		end
		ui.Activated:Connect(function()
			local clicked = false
			if clicked then return end
			clicked = true

			if Player.DailyRewards.NextClaim.Value ~= uiDay then
				clicked = false
				return
			end

			local claimable, unit, Rarity = ClaimReward:InvokeServer()

			local tower = nil
			if typeof(unit) == "string" and unit ~= "" then
				repeat
					tower = nil
					for _, v in pairs(ReplicatedStorage.Towers[Rarity]:GetChildren()) do
						warn(v.Name .. "vName" .. unit .. "unit name")
						if v.Name == unit and v:IsA("Model") then
							tower = v
							break
						end
					end
					if not tower then
						task.wait(1)
					end
				until tower
			end

			if unit then
				ViewModule.Hatch({
					Upgrades[unit],
					tower,
					nil,
					true
				})
				--DailyRewardFrame.Visible = false
				_G.CloseAll()
				UiHandler.EnableAllButtons()
			end

			if claimable then
				RefreshUI()
			end
			
			task.wait(5, function()
				clicked = false
			end)
		end)

	end
end


function RefreshUI()
	local nextClaim = Player.DailyRewards.NextClaim.Value
	local div = math.floor(nextClaim / 7)

	local startDay = (div * 7) + 1
	if nextClaim % 7 == 0 then
		startDay = ((div - 1) * 7) + 1
	end

	for index = 1, 7 do
		local rewardDayUI = RewardsContainer:FindFirstChild(index)
		local displayDay = startDay + index - 1

		local overlay = rewardDayUI:FindFirstChild("Contents") and rewardDayUI.Contents:FindFirstChild("Overlay")
		local contents = rewardDayUI:FindFirstChild("Contents") and rewardDayUI.Contents:FindFirstChild("Contents")
		if overlay then
			if overlay:FindFirstChild("Lock") then overlay.Lock.Visible = true end
			if overlay:FindFirstChild("Check") then overlay.Check.Visible = false end
		end
		if contents then
			if contents:FindFirstChild("Lock") then contents.Lock.Visible = true end
			if contents:FindFirstChild("Check") then contents.Check.Visible = false end
		end
		rewardDayUI.Time.Visible = true

		NewButton(rewardDayUI, displayDay)
	end

	updateGemsTextIfDouble()
end

RefreshUI()

task.spawn(function()
	while task.wait(1) do
		RefreshUI()
	end
end)

DailyRewardFrame.Frame.X_Close.Activated:Connect(function()
	_G.CloseAll()
end)


local MPS = game:GetService("MarketplaceService")

DailyRewardFrame.Days.SkipADay.Activated:Connect(function()
	MPS:PromptProductPurchase(Player, 3305696523)
end)