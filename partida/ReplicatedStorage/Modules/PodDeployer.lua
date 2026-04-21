local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local CameraShake = require(ReplicatedStorage.AceLib.CameraShake)
--local AudioPlayer = require(ReplicatedStorage.AceLib.AudioPlayer)
local VFXPlayer = require(ReplicatedStorage.AceLib.VFXPlayer)

local Assets = ReplicatedStorage.Assets

--local PodSFX = SoundService.SFX.Pod
local ItemCache = workspace:WaitForChild('ItemCache')
local GroundCrack = ReplicatedStorage.Assets.PodVFX["Ground Crack"]
local Explosion = ReplicatedStorage.Assets.PodVFX.Explosion

local module = {}

local RadiusMinimumOffset = 5
local RadiusMaximumOffset = 10

local HeightOffset = 50
local rocketSpeed = 70

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

-- Main Function
function module.deployPod(pos: Vector3, sourcePlayer, damage)
	print('Deploying pod')
	local Pod = Assets.Pod:Clone() :: Model

	local offsetVector = Vector3.new(
		module.randomOffset(RadiusMinimumOffset, RadiusMaximumOffset),
		HeightOffset,
		module.randomOffset(RadiusMinimumOffset, RadiusMaximumOffset)
	)
	Pod:PivotTo(CFrame.new(pos + offsetVector))

	local pivot = Pod:GetPivot()
	local lookCFrame = CFrame.lookAt(pivot.Position, pos)
	Pod:PivotTo(lookCFrame)

	Pod.Parent = ItemCache
	--AudioPlayer.playSound(PodSFX.FlyingDown)
	Pod.Main.FlyingDown:Play()

	local ttime = getMag(lookCFrame.Position, pos) / rocketSpeed
	local offset = Vector3.new(0, -1.3, 0)

	local x, y, z = lookCFrame:ToEulerAnglesXYZ()
	local targetCFrame = CFrame.new(pos) * CFrame.Angles(x, y, z)
	targetCFrame = CFrame.new(pos + offset) * CFrame.Angles(x, y, z)

	TweenModule.tween(Pod, TweenInfo.new(ttime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})

	task.wait(ttime)

	VFXPlayer.cutVFX(Pod)
	--AudioPlayer.playSound(PodSFX.Crash)
	Pod.Main.Crash:Play()
	-- crashes!
	if sourcePlayer and damage then
		local mobFolder = workspace:FindFirstChild('Mobs') or workspace[sourcePlayer.Team.Name .. 'Mobs'] :: Folder
		for i,v: Model in mobFolder:GetChildren() do
			task.spawn(function()
				if v:IsA('Model') then
					local enemyPos = v:GetPivot().Position
					
					if getMag(enemyPos, pos) < 20 then
						v.Humanoid:TakeDamage(math.round(damage))
					end
				end
			end)
		end
	end
	
	
	
	if RunService:IsClient() then
		CameraShake.shakeCamera(0.5, 0.3)
	else
		local ShakeCamera = ReplicatedStorage.Remotes.Client.ShakeCamera

		for i, plr: Player in Players:GetChildren() do
			if plr.Character then
				if getMag(plr.Character:GetPivot().Position, pos) < 50 then
					ShakeCamera:FireClient(plr, 0.5, 0.3)
				end
			end
		end
	end

	local CrackVFX = GroundCrack:Clone()
	CrackVFX.Position = pos + offset
	CrackVFX.Parent = ItemCache
	
	local ExplosionVFX = Explosion:Clone()
	ExplosionVFX.Position = pos + offset
	ExplosionVFX.Parent = ItemCache
	--VFXPlayer.emitVFX(ExplosionVFX)
	ExplosionVFX:SetAttribute('ClientVFXPlayed', true)
	
	Pod.Main.Transparency = 1
	
	task.delay(1, function()	
		--task.delay(1, function()
		VFXPlayer.cutVFX(CrackVFX)
		ExplosionVFX:SetAttribute('ClientVFXPlayed', false)

		task.delay(.5, function()
			CrackVFX:Destroy()
			ExplosionVFX:Destroy()
			Pod:Destroy()
		end)
	end)
end

-- Aux Functions

function module.randomOffset(min, max)
	local value = math.random(min, max)
	if math.random(0, 1) == 0 then
		value = -value
	end
	return value
end


return module