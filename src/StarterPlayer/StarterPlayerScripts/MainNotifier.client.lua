local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

repeat task.wait() until Player:FindFirstChild("DataLoaded") and Player.PlayerGui:FindFirstChild("GameGui")

local ObtainedFrame = Player.PlayerGui.CoreGameUI.Notifier.Obtained
local Template = ObtainedFrame.Rewards.Template
local BG = Template.BG
local Amount = Template.Amount
local Close = ObtainedFrame.Close
local Notice = ObtainedFrame.Notice
local Items = Player:FindFirstChild("Items")

local Assets = {"rbxassetid://136316362283198"}
local Currency = {
	["Gems"] = "rbxassetid://131476601794300",
	["Willpower"] = "http://www.roblox.com/asset/?id=125102279720110"
}
local soundID = "1347153667"

local displayQueue = {}  
local isDisplaying = false  
local cancelTween = false
local CurrencyIsTrue = false

function FadeBlackBackGround(bg, fadeIn)
	local goal = {}
	goal.BackgroundTransparency = fadeIn and 0.15 or 1
	local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(bg, tweenInfo, goal)
	tween:Play()
end


function MovingTextUpAndDown(textLabel)
	cancelTween = true
	task.wait()

	cancelTween = false
	coroutine.wrap(function()
		local originalPosition = textLabel.Position
		while textLabel:IsDescendantOf(game) and textLabel.Visible and not cancelTween do
			local up = TweenService:Create(textLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = originalPosition - UDim2.new(0, 0, 0.05, 0)
			})
			up:Play()
			up.Completed:Wait()

			if cancelTween then break end

			local down = TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = originalPosition
			})
			down:Play()
			down.Completed:Wait()
		end
	end)()
end


function DisplayCurrency(currency, CurrencyName, Currencyvalue)
	table.insert(displayQueue, {isCurrency = true, CurrencyName = CurrencyName, value = Currencyvalue})
	if not isDisplaying then
		ProcessQueue()
	end
end

function DisplayItem()
	for i, v in pairs(Items:GetChildren()) do
		local lastValue = v.Value
		v.Changed:Connect(function()
			pcall(function()
				ContentProvider:PreloadAsync(Assets)
			end)

			local diff = v.Value - lastValue
			lastValue = v.Value

			if diff <= 0 then
				return
			end

			table.insert(displayQueue, {
				isCurrency = false,
				CurrencyName = v.Name,
				value = diff
			})

			if not isDisplaying then
				ProcessQueue()
			end
		end)
	end
end


local counter = 0

function ProcessQueue(isDouble)
	if #displayQueue > 0 then
		isDisplaying = true
		local data = table.remove(displayQueue, 1)  

		
		ObtainedFrame.Visible = true
		FadeBlackBackGround(ObtainedFrame, true)
		local sound = Instance.new("Sound")
		sound.SoundId = soundID
		sound:Play()
		
		if counter < 1 then
			MovingTextUpAndDown(Notice)
		end
		
		counter += 1
		
		if data.isCurrency then
			CurrencyIsTrue = true
			local LevelRewards = ObtainedFrame:FindFirstChild("LevelRewards")
			print(LevelRewards)
			if not LevelRewards then
				local LevelRewards = Amount:Clone()
				LevelRewards.Name = "LevelRewards"
				LevelRewards.Text = "Displaying Level Rewards"
				LevelRewards.AnchorPoint = Vector2.new(0.5, 0.5)
				LevelRewards.Position = UDim2.new(0.42, 0, 0.08, 0)
				LevelRewards.TextSize = 36
				LevelRewards.Parent = ObtainedFrame
				LevelRewards.Visible = true

				local LevelRewardsName = Amount:Clone()
				LevelRewardsName.Name = "LevelDisplay"
				LevelRewardsName.Text = "For Reaching Level " .. "" .. Player:FindFirstChild("PlayerLevel").Value
				LevelRewardsName.AnchorPoint = Vector2.new(0.5, 0.5)
				LevelRewardsName.Position = UDim2.new(0.4, 0,0.3, 0)
				LevelRewardsName.TextColor3 = Color3.new(1, 1, 1)
				LevelRewardsName.Parent = ObtainedFrame
				LevelRewardsName.Visible = true

				BG.Image = Currency[data.CurrencyName]
				Amount.Text = "x" .. data.value

			else
				LevelRewards.Visible = true
				BG.Image = Currency[data.CurrencyName]
				Amount.Text = "x" .. data.value
			end
		else
			local viewport = ViewPortModule.CreateViewPort(data.CurrencyName)
			viewport.Parent = BG
			viewport.Size = UDim2.new(1, 0, 1, 0)
			viewport.ZIndex = 999999999
			viewport.AnchorPoint = Vector2.new(0.5, 0.5)
			viewport.Position = UDim2.new(0.5, 0, 0.35, 0)
			Amount.Text = "x" .. data.value
		end


		ObtainedFrame:GetPropertyChangedSignal("Visible"):Wait()


		isDisplaying = false
		ProcessQueue()
	end
end


Close.Activated:Connect(function()
	cancelTween = true
	counter -= 1
	local Viewport = ObtainedFrame.Rewards.Template.BG:FindFirstChildOfClass("ViewportFrame")
	if Viewport then
		Viewport:Destroy()
	end
	
	
	for i, v in ipairs(ObtainedFrame:GetChildren()) do
		if v.Name == "LevelRewards" or v.Name == "LevelDisplay" then
			v:Destroy()
		end
	end
	
	if CurrencyIsTrue then
		BG.Image = "rbxassetid://136316362283198" 
	end
	FadeBlackBackGround(ObtainedFrame, false)
	cancelTween = true
	ObtainedFrame.Visible = false
end)


local level = Player:FindFirstChild("PlayerLevel")
local LevelRewardRemote = ReplicatedStorage.Remotes.LevelRewards.LevelReward

level.Changed:Connect(function()
	local GemsReward, TraitPoints = LevelRewardRemote:InvokeServer()
	print(GemsReward, TraitPoints)

	if GemsReward and TraitPoints == 0 then
		return
	end

	DisplayCurrency(true, "Gems", GemsReward)
	DisplayCurrency(true, "Willpower", TraitPoints)
end)


LevelRewardRemote.OnClientInvoke = function(Gems, Traits)
	
	if Gems and Traits == 0 or Gems == nil or Traits == nil then
		return
	end
	
	
	DisplayCurrency(true, "Gems", Gems)
	DisplayCurrency(true, "Willpower", Traits)
end


DisplayItem()
