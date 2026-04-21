local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local VFX = rs.VFX
local GameSpeed = workspace.Info.GameSpeed
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TS:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end


module["Saber Dash"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX["Seventh Sister"].First
	local characterModel = HRP.Parent
	local Range = characterModel.Config:WaitForChild("Range").Value
	local enemyPos = target:GetPivot().Position

	local originalCFrame = characterModel:GetPivot()

	task.wait(0.78 / speed)
	if not HRP or not HRP.Parent then return end

	characterModel.Attacking.Value = true

	
	local SaberDash = Folder["Saber Dash"]:Clone()
	SaberDash.Parent = workspace.VFX
	SaberDash.CFrame = HRP.CFrame

	local distance = (HRP.Position - enemyPos).Magnitude
	local timeToTravel = distance / speed

	TS:Create(SaberDash, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {Position = enemyPos}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
	

	task.delay(timeToTravel, function()
		if SaberDash and SaberDash.Parent then
			SaberDash:Destroy()
		end
	end)

	for _, v in pairs(SaberDash:GetChildren()) do
		if v:IsA("ParticleEmitter") or v:IsA("Beam") then
			v.Enabled = true
		elseif v:IsA("Attachment") then
			for _, child in pairs(v:GetChildren()) do
				if child:IsA("ParticleEmitter") or child:IsA("Beam") then
					child.Enabled = true
				end
			end
		end
	end


	local targetCFrame = HRP.CFrame * CFrame.new(0, 0, -Range)
	TS:Create(HRP, TweenInfo.new(0.15/speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end
	characterModel:PivotTo(originalCFrame)

	characterModel.Attacking.Value = false
end



return module
