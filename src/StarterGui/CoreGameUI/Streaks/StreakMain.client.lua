local AvatarEditorService = game:GetService('AvatarEditorService')
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StreakUp = SoundService.Streaks.StreakUp
local ResetStreakAnimation = ReplicatedStorage.Events.ResetStreakAnimation
local StreakBlur = Lighting.StreakBlur
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)

repeat task.wait() until Player:FindFirstChild('DataLoaded')
repeat task.wait() until _G.LoadingScreenComplete or _G.GameLoaded

local originalFOV = workspace.Camera.FieldOfView
local newFOV = 90

	local function tween(obj, length, details)
		TweenService:Create(obj, TweenInfo.new(length), details):Play()
	end

local Streak = Player.Streak.Value

--[[

OldStreak = 0,
Streak = 0,
StreakIncreasesIn = time() + 86400,
StreakRestoreExpiresIn = time() + 86400 * 3,
PlayStreakAnimation = false

--]]

local offsetVal = 1.194 - 1.149
local fadeOutTime = 0.2
local fadeInTime = 0.3
local intervalDelay = 0.3
local numberSwitchTime = 1

local function fadeIn(obj)
	if obj:FindFirstChild('OriginalPositionX') then
		local newPos = UDim2.fromScale(obj.OriginalPositionX.Value, obj.OriginalPositionY.Value)
		tween(obj, fadeInTime, {Position = newPos, TextTransparency = 0})
	else
		tween(obj, fadeInTime, {TextTransparency = 0})
	end
	
	tween(obj.UIStroke, fadeInTime, {Transparency = 0})
end

local function fadeOut(obj, noPos)
	if not obj:FindFirstChild('OriginalPositionX') and not noPos then
		local val = Instance.new('NumberValue')
		val.Name = 'OriginalPositionX'
		val.Value = obj.Position.X.Scale
		val.Parent = obj
		
		local val = Instance.new('NumberValue')
		val.Name = 'OriginalPositionY'
		val.Value = obj.Position.Y.Scale
		val.Parent = obj
	end
	
	if not noPos then
		local newPos = UDim2.fromScale(obj.Position.X.Scale, obj.Position.Y.Scale - offsetVal)

		tween(obj, fadeOutTime, {Position = newPos, TextTransparency = 1})
	else
		tween(obj, fadeOutTime, {TextTransparency = 1})
	end
	
	tween(obj.UIStroke, fadeOutTime, {Transparency = 1})
end

local function expandOut(obj)
	if not obj:FindFirstChild('OriginalSizeX') then
		local val = Instance.new('NumberValue')
		val.Name = 'OriginalSizeX'
		val.Value = obj.Size.X.Scale
		val.Parent = obj

		local val = Instance.new('NumberValue')
		val.Name = 'OriginalSizeY'
		val.Value = obj.Size.Y.Scale
		val.Parent = obj
	end
	
	if obj:IsA('ImageLabel') then
		tween(obj, fadeOutTime, {Size = UDim2.fromScale(obj.Size.X.Scale/2, obj.Size.Y.Scale/2), ImageTransparency = 1})
	else
		tween(obj, fadeOutTime, {Size = UDim2.fromScale(obj.Size.X.Scale/2, obj.Size.Y.Scale/2)})
	end
end

local function expandIn(obj)
	local newSize = UDim2.fromScale(obj.OriginalSizeX.Value, obj.OriginalSizeY.Value)
	tween(obj, fadeInTime, {Size = newSize, ImageTransparency = 0})
end

script.Parent.FireMain.Visible = false

expandOut(script.Parent.FireMain.FireIcon)
tween(StreakBlur, fadeOutTime, {Size = 0})
tween(workspace.Camera, fadeInTime, {FieldOfView = originalFOV})
for i,v in script.Parent.FireMain.FireIcon:GetDescendants() do
	if v:IsA('TextLabel') then
		fadeOut(v, true)
	end
end

for i,v in script.Parent.FireMain:GetChildren() do
	if v:IsA('TextLabel') then
		fadeOut(v)
	end
end	

task.wait(fadeOutTime)

script.Parent.FireMain.Visible = true

local function playAnimation()
	if not _G.CloseAll then repeat task.wait() until _G.CloseAll end
	_G.CloseAll() -- close all UI
	_G.Occupied = true
	--UIHandler.DisableAllButtons({'Exp_Frame','Units_Bar',"Currency","Level","SummonFrame"})
	UIHandler.DisableAllButtons()
	
	if Streak ~= 0 then
		
		StreakUp:Play()
		
		local FireIcon = script.Parent.FireMain.FireIcon
		
		if Streak == 1 then -- day 1
			FireIcon.Container.CurrentFire.Text = Streak
			expandIn(FireIcon)
			for i,v in script.Parent.FireMain.FireIcon:GetDescendants() do
				if v:IsA('TextLabel') then
					fadeIn(v)
				end
			end
			tween(StreakBlur, fadeInTime, {Size = 24})
			tween(workspace.Camera, fadeInTime, {FieldOfView = newFOV})
			task.wait(.5)
			for i,v in script.Parent.FireMain:GetChildren() do
				if v:IsA('TextLabel') then
					fadeIn(v)
					task.wait(intervalDelay)
				end
			end
		else -- 1 day 😈
			FireIcon.Container.CurrentFire.Text = Streak-1
			FireIcon.Container.NewFire.Text = Streak
			expandIn(FireIcon)
			for i,v in script.Parent.FireMain.FireIcon:GetDescendants() do
				if v:IsA('TextLabel') then
					fadeIn(v)
				end
			end
			tween(StreakBlur, fadeInTime, {Size = 24})
			tween(workspace.Camera, fadeInTime, {FieldOfView = newFOV})
			
			
			task.wait(.5)
			-- tween the numbers

			tween(FireIcon.Container.CurrentFire, numberSwitchTime, {Position = UDim2.fromScale(0.5,2)})
			tween(FireIcon.Container.NewFire, numberSwitchTime, {Position = UDim2.fromScale(0.5,1)})
			
			script.Parent.FireMain.YouStarted.Text = 'Streak Up!'
			for i,v in script.Parent.FireMain:GetChildren() do
				if v:IsA('TextLabel') then
					fadeIn(v)
					task.wait(intervalDelay)
				end
			end
		end
		
		
		task.wait(3)

		expandOut(script.Parent.FireMain.FireIcon)
		tween(StreakBlur, fadeOutTime, {Size = 0})
		tween(workspace.Camera, fadeInTime, {FieldOfView = originalFOV})
		for i,v in script.Parent.FireMain.FireIcon:GetDescendants() do
			if v:IsA('TextLabel') then
				fadeOut(v, true)
			end
		end

		for i,v in script.Parent.FireMain:GetChildren() do
			if v:IsA('TextLabel') then
				fadeOut(v)
			end
		end
		
		task.delay(fadeOutTime, function()
			tween(FireIcon.Container.CurrentFire, numberSwitchTime, {Position = UDim2.fromScale(0.5,1)})
			tween(FireIcon.Container.NewFire, numberSwitchTime, {Position = UDim2.fromScale(0.5,0)})
		end)
	end
	
	ResetStreakAnimation:FireServer()
	_G.Occupied = false
	UIHandler.EnableAllButtons()
	
	AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
end

if Player.PlayStreakAnimation.Value then
	task.wait(5)
	print('Playing streak animation...')
	playAnimation()
end