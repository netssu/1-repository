local ServerScriptService = game:GetService("ServerScriptService")
local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local ItemCache = workspace.ItemCache
local SoundService = game:GetService("SoundService")
local VFXPlayer = require(ReplicatedStorage.AceLib.VFXPlayer)
local AudioPlayer = require(ReplicatedStorage.AceLib.AudioPlayer)

local StarDestroyerSFX = SoundService.SFX.Stardestroyer

local info = workspace.Info
local ttime = 1	

local function getMidpoint(vec1, vec2)
	return (vec1 + vec2) / 2
end

local rayEnd = nil :: Attachment
local rayConn = nil :: RBXScriptConnection
local InstanceRays = {}

function module.getInstanceRay(star)
	return InstanceRays[star]
end

function module.setRay(StarDestroyer: Model, endPosition)
	local startPosition = StarDestroyer.Starcore.Position
	rayEnd = endPosition

	if rayConn then
		rayConn:Disconnect()
		rayConn = nil
	end

	if not InstanceRays[StarDestroyer] then
		local DeathRay = ReplicatedStorage.Assets.Stardestroyer.DeathRay:Clone()

		InstanceRays[StarDestroyer] = DeathRay
		
		InstanceRays[StarDestroyer] = DeathRay
		StarDestroyer:GetPropertyChangedSignal('Parent'):Connect(function()
			InstanceRays[StarDestroyer] = nil
		end)
				

		VFXPlayer.cutVFX(DeathRay)

		DeathRay.Parent = ItemCache

		VFXPlayer.enableVFX(DeathRay.Release)


		AudioPlayer.playSound(StarDestroyerSFX.RayStart)
		AudioPlayer.playSound(StarDestroyerSFX.RayLoad)
		AudioPlayer.playSound(StarDestroyerSFX.RayLoop)

		DeathRay.CFrame = CFrame.new(getMidpoint(startPosition, endPosition), endPosition) * CFrame.new(0, 0, -DeathRay.Size.Z / 2)
		DeathRay.Size = Vector3.new(10, 10, (startPosition - endPosition).Magnitude) -- Adjust the thickness and length of the beam

		local x, y, z = DeathRay.Release.WorldCFrame:ToEulerAnglesXYZ()
		DeathRay.Release.WorldCFrame = CFrame.new(startPosition) * CFrame.Angles(x, y, z)


		for i,v in DeathRay:GetDescendants() do
			if v:IsA('Attachment') and v.Name == 'B2' then
				local x, y, z = v.WorldCFrame:ToEulerAnglesXYZ()
				v.WorldCFrame = CFrame.new(startPosition) * CFrame.Angles(x, y, z)
			end
		end
		
		local setEnd = false
		
		for i,v in DeathRay:GetDescendants() do
			if v:IsA('Attachment') and v.Name == 'B1' then
				if not setEnd then
					rayConn = v:GetPropertyChangedSignal('WorldCFrame'):Connect(function()
						rayEnd = v.WorldCFrame.Position
					end)
					
					
					setEnd = true
				end
				
				local x, y, z = v.WorldCFrame:ToEulerAnglesXYZ()
				v.WorldCFrame = CFrame.new(startPosition) * CFrame.Angles(x, y, z)

				TweenModule.tween(v, TweenInfo.new(ttime/info.GameSpeed.Value, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {WorldCFrame = CFrame.new(endPosition) * CFrame.Angles(x, y, z)}, true)
			end
		end

		local x, y, z = DeathRay.End.WorldCFrame:ToEulerAnglesXYZ()
		DeathRay.End.WorldCFrame = CFrame.new(startPosition) * CFrame.Angles(x, y, z)
		TweenModule.tween(DeathRay.End, TweenInfo.new(ttime/info.GameSpeed.Value, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {WorldCFrame = CFrame.new(endPosition) * CFrame.Angles(x, y, z)}, true)

		VFXPlayer.enableVFX(DeathRay)

		task.delay(ttime/info.GameSpeed.Value, function()
			AudioPlayer.playSound(StarDestroyerSFX.RayImpact)
		end)
	else
		for i,v in InstanceRays[StarDestroyer]:GetDescendants() do
			if v:IsA('Attachment') and v.Name == 'B1' then
				local x, y, z = v.WorldCFrame:ToEulerAnglesXYZ()
				--v.WorldCFrame = CFrame.new(startPosition) * CFrame.Angles(x, y, z)
				TweenModule.tween(v, TweenInfo.new(ttime/info.GameSpeed.Value, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {WorldCFrame = CFrame.new(endPosition) * CFrame.Angles(x, y, z)}, true)
			end
		end

		local x,y,z = CFrame.lookAt(startPosition, endPosition):ToEulerAnglesXYZ()
		TweenModule.tween(InstanceRays[StarDestroyer].End, TweenInfo.new(ttime/info.GameSpeed.Value, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {WorldCFrame = CFrame.new(endPosition) * CFrame.Angles(x, y, z)}, true) 
	end
	
	return ttime
end

function module.getEnd()
	return rayEnd
end

return module