local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)


local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local tweenService = game:GetService("TweenService")

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	tweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end


module["Heavy Machine Gun"] = function(HRP, target)
	local Folder = VFX.Heavy.First
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	--VFX_Helper.SoundPlay(HRP, Folder.Sound)
	local GunShoot = Folder["Heavy Machine gun"]:Clone()
	
	
	GunShoot.CFrame = HRP.CFrame
	GunShoot.Parent = HRP.Parent
	local Attatchments = GunShoot.Attachment
	local tableEmit = {}

	local speed = 5
	local enemyPos = target:GetPivot().Position
	local timeToTravel = getMag(HRP.Position, enemyPos) / speed

	tween(GunShoot, timeToTravel, {Position = enemyPos})
	
	UnitSoundEffectLib.playSound(HRP.Parent, 'LaserGun4')
	task.delay(timeToTravel, function()
		GunShoot:Destroy()
	end)

	for i,v in Attatchments:GetChildren() do
		table.insert(tableEmit, v)
	end

	warn(tableEmit, "Particles for gun")

	for i,v in tableEmit do
		v.Enabled = true
		task.wait(0.2 / speed, function()
			v.Enabled = false
		end)
	end
	HRP.Parent.Attacking.Value = false
end

return module
