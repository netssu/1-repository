local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local UIS = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local SoundService = game:GetService('SoundService')
local SoundFX = SoundService:WaitForChild('SoundFX')
local ContentProvider = game:GetService("ContentProvider")

local preloads = {}
for i,v in ReplicatedStorage.CompetitiveData.CompetitiveRankConfigurations:GetChildren() do
	table.insert(preloads, v.Image)
end
task.spawn(function()
	ContentProvider:PreloadAsync(preloads)
end)

local function tween(obj, length, details)
	if obj and length and details then
		TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Exponential), details):Play()
	end
end

local StarterGui = game:GetService('StarterGui')
local ContentProvider = game:GetService('ContentProvider')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Modules = ReplicatedStorage:WaitForChild('Modules')
local CompetitiveData = ReplicatedStorage:WaitForChild('CompetitiveData')
local CompRankConfig = CompetitiveData:WaitForChild('CompetitiveRankConfigurations')


local RomanNumerals = require(ReplicatedStorage.AceLib.RomanNumeralsConverter)
local RankCalculator = require(ReplicatedStorage.CompetitiveData.RankCalculator)


local MainFrame = script.Parent.MainFrame

local YouHaveRankedUp = MainFrame:WaitForChild('YouHaveRankedUp')
local RankImage = MainFrame:WaitForChild('RankImage')
--local RankShadow = MainFrame:WaitForChild('RankShadowImage')

local RankText = MainFrame:WaitForChild('RankText')
local CompetitiveText = MainFrame:WaitForChild('Competitive')

local Shadow = MainFrame:WaitForChild('Shadow')

local ClickToContinue = MainFrame:WaitForChild('ClickToContinue')

local Blackout = script.Parent:WaitForChild('Blackout')

function module.activate(elo)
	-- disable chat & playerlist
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	
	local rank, div = RankCalculator.getRankAndDivision(elo)
	div = RomanNumerals.toRoman(div)
	
	local RankData = CompRankConfig:WaitForChild(rank)
	
	RankImage.Image = RankData.Image
	--RankShadow.Image = RankData.Image
	
	
	tween(Blackout, 1, {BackgroundTransparency = 0})

	task.wait(1)
	MainFrame.Visible = true

	MainFrame.BackgroundColor3 = RankData:WaitForChild('Primary').Value

	task.wait(0.1)
	tween(Blackout, 1, {BackgroundTransparency = 1})
	
	task.wait(1)
	
	SoundFX.RankUp:Play()
	
	tween(YouHaveRankedUp.Frame, 0.4, {Size = UDim2.fromScale(1,1)})
	task.wait(0.5)
	YouHaveRankedUp.Frame.AnchorPoint = Vector2.new(1,0)
	YouHaveRankedUp.Frame.Size = UDim2.fromScale(1,1)
	YouHaveRankedUp.Frame.Position = UDim2.fromScale(1,0)
	YouHaveRankedUp.TextTransparency = 0
	
	tween(YouHaveRankedUp.Frame, 0.4, {Size = UDim2.fromScale(0,1)})
	task.wait(0.45)
	tween(YouHaveRankedUp, 0.4, {Position = UDim2.fromScale(0.5,0.278)})
	task.wait(0.4)
	
	RankImage.ImageTransparency = 1
	local BaseRankX = 0.13*0.8
	local BaseRankY = 0.231*0.8
	
	RankImage.Size = UDim2.fromScale(BaseRankX*2, BaseRankY*2)
	RankImage.Visible = true
	--RankShadow.ImageTransparency = 1
	--RankShadow.Visible = true
	
	
	
	tween(RankImage, 0.5, {ImageTransparency = 0, Size = UDim2.fromScale(BaseRankX,BaseRankY)})
	--tween(RankShadow, 0.5, {ImageTransparency = 0.3})
	
	task.wait(0.1)
	
	-- RankText
	if rank ~= 'Unranked' and rank ~= 'Champion' then
		RankText.Text = rank ..  ' ' .. div
	else
		RankText.Text = rank
	end
	
	RankText.UIGradient.Color = RankData.UIGradient.Color
	tween(RankText.Frame, 0.5, {Size = UDim2.fromScale(1,1)})
	task.delay(0.5, function()
		RankText.Frame.AnchorPoint = Vector2.new(1,0)
		RankText.Frame.Size = UDim2.fromScale(1,1)
		RankText.Frame.Position = UDim2.fromScale(1,0)
		RankText.TextTransparency = 0
		
		tween(RankText.Frame, 0.4, {Size = UDim2.fromScale(0,1)})
	end)
	task.wait(0.15)
	tween(CompetitiveText.Frame, 0.5, {Size = UDim2.fromScale(1,1)})
	
	task.wait(0.5)
	CompetitiveText.Frame.AnchorPoint = Vector2.new(1,0)
	CompetitiveText.Frame.Size = UDim2.fromScale(1,1)
	CompetitiveText.Frame.Position = UDim2.fromScale(1,0)
	CompetitiveText.TextTransparency = 0
	tween(CompetitiveText.Frame, 0.4, {Size = UDim2.fromScale(0,1)})
	
	task.wait(1)
	
	tween(ClickToContinue, 0.4, {TextTransparency = 0})
	
	local bind = Instance.new('BindableEvent')
	local conn = nil
	
	conn = UIS.InputBegan:Connect(function(key, gp)
		if not gp then
			if key.UserInputType == Enum.UserInputType.Touch or key.UserInputType == Enum.UserInputType.MouseButton1 then
				bind:Fire()
				conn:Disconnect()
				conn = nil
			end
		end
	end)
	
	bind.Event:Wait()
	bind:Destroy()
	
	tween(Blackout, 1, {BackgroundTransparency = 0})
	task.wait(1)
	script.Parent.MainFrame.Visible = false
	
	-- reset positions  --- - - - - --- -- -
	ClickToContinue.TextTransparency = 1
	CompetitiveText.TextTransparency = 1
	RankText.TextTransparency = 1
	YouHaveRankedUp.TextTransparency = 1
	YouHaveRankedUp.Position = UDim2.fromScale(0.5,0.5)
	RankImage.Visible = false
	--RankShadow.Visible = false
	
	-- reset frames
	CompetitiveText.Frame.AnchorPoint = Vector2.new(0,0)
	CompetitiveText.Frame.Position = UDim2.fromScale(0,0)
	YouHaveRankedUp.Frame.AnchorPoint = Vector2.new(0,0)
	YouHaveRankedUp.Frame.Position = UDim2.fromScale(0,0)
	ClickToContinue.Frame.AnchorPoint = Vector2.new(0,0)
	ClickToContinue.Frame.Position = UDim2.fromScale(0,0)
	RankText.Frame.AnchorPoint = Vector2.new(0,0)
	RankText.Frame.Position = UDim2.fromScale(0,0)
	
	tween(Blackout, 1, {BackgroundTransparency = 1})
	
end

return module