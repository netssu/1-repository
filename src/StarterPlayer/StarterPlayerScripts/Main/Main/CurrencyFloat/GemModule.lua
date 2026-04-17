local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ItemCache = workspace:WaitForChild('ItemCache')
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local CameraShake = require(ReplicatedStorage.AceLib.CameraShake)
local Player = Players.LocalPlayer
local Assets = ReplicatedStorage.Assets

-- Sounds
local SFX = SoundService.SFX
local GemDrop = SFX.GemDrop
local GemReceived = SFX.GemReceived
local GoldDrop = SFX.GoldDrop
local GoldReceived = SFX.GoldReceived

local MinScale = 1.6
local MaxScale = 2.3

local minGems = 12
local maxGems = 18

local minScale = 1.3
local maxScale = 2.6
local minDistance = 6
local maxDistance = 10
local minBounceHeight = 2
local maxBounceHeight = 5
local minSpinSpeed = 2
local maxSpinSpeed = 6
local suckDelay = 1.5 -- Time before gems start getting sucked back
local suckDuration = 0.8 -- How long the suction takes
local function tweenCFrame(model: Model, info: TweenInfo, currentCFrame, targetCFrame)
	local CFrameValue = Instance.new('CFrameValue')
	CFrameValue.Value = currentCFrame
	CFrameValue.Changed:Connect(function()
		model:PivotTo(CFrameValue.Value)
	end)
	TweenService:Create(CFrameValue, info, {Value = targetCFrame}):Play()
	task.wait(info.Time)
	CFrameValue:Destroy()
end

local function tweenSize(model: Model, info: TweenInfo, targetSize:number)
	local NumberValue = Instance.new('NumberValue')
	NumberValue.Value = model:GetScale()
	NumberValue.Changed:Connect(function()
		model:ScaleTo(NumberValue.Value)
	end)
	TweenService:Create(NumberValue, info, {Value = targetSize}):Play()
	task.wait(info.Time)
	NumberValue:Destroy()
end

local module = {}

local function bezierCurve(p0, p1, p2, t)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

function module.castEffect(currency)
	if not Player.Character then return end
	local SourcePosition = Player.Character:GetPivot().Position
	local numGems = math.random(minGems, maxGems)
	CameraShake.shakeCamera(0.5, 0.3)

	if currency == 'Gold' then
		GoldDrop:Play()
	else
		GemDrop:Play()
	end

	for i = 1, numGems do
		local Gem = Assets[currency]:Clone()
		Gem.Parent = ItemCache
		Gem:PivotTo(CFrame.new(SourcePosition + Vector3.new(0, -4, 0)))
		Gem:ScaleTo(math.random(minScale * 100, maxScale * 100) / 100)

		local baseAngle = (i - 1) * (360 / numGems)
		local randomVariation = math.random(-30, 30)
		local angle = math.rad(baseAngle + randomVariation)

		local distance = math.random(minDistance * 100, maxDistance * 100) / 100
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local bounceHeight = math.random(minBounceHeight * 100, maxBounceHeight * 100) / 100
		local startPos = Gem:GetPivot().Position
		local midPos = startPos + offset + Vector3.new(0, bounceHeight, 0)
		local endPos = startPos + offset
		task.spawn(function()
			local positionCFrame = Instance.new('CFrameValue')
			local rotationAngle = Instance.new('NumberValue')
			positionCFrame.Value = CFrame.new(startPos)
			rotationAngle.Value = 0
			local function updateGem()
				local pos = positionCFrame.Value.Position
				local rotation = CFrame.Angles(0, math.rad(rotationAngle.Value), 0)
				Gem:PivotTo(CFrame.new(pos) * rotation)
			end
			positionCFrame.Changed:Connect(updateGem)
			rotationAngle.Changed:Connect(updateGem)
			local upTween = TweenService:Create(positionCFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = CFrame.new(midPos)})
			local downTween = TweenService:Create(positionCFrame, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Value = CFrame.new(endPos)})
			local spinSpeed = math.random(minSpinSpeed, maxSpinSpeed)
			local spinning = true
			upTween:Play()
			task.spawn(function()
				while spinning do
					local spinTween = TweenService:Create(rotationAngle, TweenInfo.new(1 / spinSpeed, Enum.EasingStyle.Linear), {Value = rotationAngle.Value + 360})
					spinTween:Play()
					task.wait(1 / spinSpeed)
				end
			end)
			upTween.Completed:Connect(function()
				downTween:Play()
			end)
			task.wait(0.5)
			task.wait(suckDelay)
			task.spawn(function()
				tweenSize(Gem, TweenInfo.new(suckDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.In), Gem:GetScale() * 0.1)
			end)
			local suckStartTime = tick()
			local suckEndTime = suckStartTime + suckDuration
			local startSuckPos = positionCFrame.Value.Position
			local initialPlayerPos = Player.Character and Player.Character:GetPivot().Position or SourcePosition
			local directionFromPlayer = (startSuckPos - initialPlayerPos).Unit
			local flarePoint = startSuckPos + directionFromPlayer * math.random(8, 15) + Vector3.new(0, math.random(3, 8), 0)

			while tick() < suckEndTime do
				local currentPlayerPos = Player.Character and Player.Character:GetPivot().Position or SourcePosition
				local suckTarget = currentPlayerPos + Vector3.new(0, -1, 0)
				local elapsed = tick() - suckStartTime
				local alpha = math.min(elapsed / suckDuration, 1)
				alpha = 1 - (1 - alpha)^4
				local newPos = bezierCurve(startSuckPos, flarePoint, suckTarget, alpha)
				positionCFrame.Value = CFrame.new(newPos)
				task.wait()
			end

			if currency == 'Gold' then
				GoldReceived:Play()
			else
				GemReceived:Play()
			end

			spinning = false
			positionCFrame:Destroy()
			rotationAngle:Destroy()
			Gem:Destroy()
		end)
		Debris:AddItem(Gem, suckDelay + suckDuration + 2)
	end
end

return module