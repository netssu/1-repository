local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local AudioPlayer = require(ReplicatedStorage.AceLib.AudioPlayer)
local CameraShake = require(ReplicatedStorage.AceLib.CameraShake)
local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local VFXPlayer = require(ReplicatedStorage.AceLib.VFXPlayer)

local StarDestroyerSFX = SoundService.SFX.Stardestroyer
local GroundCrack = ReplicatedStorage.Assets.Stardestroyer["Ground Crack"]
local Explosion = ReplicatedStorage.Assets.Stardestroyer.Explosion

local ItemCache = workspace:WaitForChild('ItemCache')

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Radius variable for cube placement
local CUBE_RADIUS = 5

local function createCube(pos)
	local cube = Instance.new('Part')
	cube.Size = Vector3.new(1,1,1)
	cube.Material = Enum.Material.Neon
	cube.Color = Color3.fromRGB(0,0,255)
	cube.Position = pos
	cube.Anchored = true
	cube.CanCollide = false
	cube.CanQuery = false
	cube.Parent = workspace:WaitForChild('ItemCache')

	task.delay(1, function()
		cube:Destroy()
	end)

end

local function raycastToGround(Player, origin)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character}

	local raycastResult = workspace:Raycast(origin, Vector3.new(0, -100, 0), raycastParams)

	if raycastResult then
		return raycastResult.Position
	else
		return origin - Vector3.new(0, 5, 0) -- fallback position
	end
end

local heightOffset = 50

local function spinMeRightRoundBaby(part)
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not part or not part.Parent then
			connection:Disconnect()
			return
		end
		part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(125) * deltaTime)
	end)
end

local Alarms = {}

local function spawnAlarm(pos)
	local Alarm = ReplicatedStorage.Assets.Stardestroyer.Alarm:Clone()
	local x, y, z = Alarm:GetPivot():ToEulerAnglesXYZ()
	local OriginPos = CFrame.new(pos + Vector3.new(0, heightOffset, 0)) * CFrame.Angles(x, y, z)
	table.insert(Alarms, Alarm)
	Alarm:PivotTo(OriginPos)
	VFXPlayer.cutVFX(Alarm)

	Alarm.Parent = workspace:WaitForChild('ItemCache')
	Alarm.FlyingDown:Play()
	TweenModule.tween(Alarm, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {CFrame = CFrame.new(pos + Vector3.new(0,1,0)) * CFrame.Angles(x, y, z)})
	task.delay(1, function()
		Alarm.Crash:Play()
		VFXPlayer.enableVFX(Alarm)
		task.spawn(spinMeRightRoundBaby, Alarm.Spin)

		local CrackVFX = GroundCrack:Clone()
		CrackVFX.Position = pos
		CrackVFX.Parent = ItemCache

		local ExplosionVFX = Explosion:Clone()
		ExplosionVFX.Position = pos
		ExplosionVFX.Parent = ItemCache
		--VFXPlayer.emitVFX(ExplosionVFX)
		ExplosionVFX:SetAttribute('ClientVFXPlayed', true)

		task.delay(1, function()
			VFXPlayer.cutVFX(CrackVFX)
			ExplosionVFX:SetAttribute('ClientVFXPlayed', false)
			task.wait(.5)
			CrackVFX:Destroy()
			ExplosionVFX:Destroy()
		end)
	end)
end

local DestroyerRemotes = ReplicatedStorage.Remotes.DestroyerRemotes

DestroyerRemotes.SpawnDestroyer.OnClientEvent:Connect(function(Player)
	AudioPlayer.playSound(StarDestroyerSFX.Initiate)
	task.wait(0.3)

	AudioPlayer.playSound(StarDestroyerSFX.Deploying)

	task.wait(1) -- a lil delay for INTENSITY

	CameraShake.shakeCamera(1.7, 0.1)
	-- Get player position
	local playerPos = Player.Character:GetPivot().Position

	-- Calculate 4 corner positions in a square formation
	local corners = {
		Vector3.new(playerPos.X + CUBE_RADIUS, playerPos.Y + 10, playerPos.Z + CUBE_RADIUS), -- Front-right
		Vector3.new(playerPos.X - CUBE_RADIUS, playerPos.Y + 10, playerPos.Z + CUBE_RADIUS), -- Front-left
		Vector3.new(playerPos.X + CUBE_RADIUS, playerPos.Y + 10, playerPos.Z - CUBE_RADIUS), -- Back-right
		Vector3.new(playerPos.X - CUBE_RADIUS, playerPos.Y + 10, playerPos.Z - CUBE_RADIUS)  -- Back-left
	}

	-- Place cubes on the ground at each corner
	for _, corner in ipairs(corners) do
		local groundPos = raycastToGround(Player, corner)
		--createCube(groundPos)
		spawnAlarm(groundPos)
	end
	task.wait(1)
	CameraShake.shakeCamera(0.1, 0.6)
	AudioPlayer.playSound(StarDestroyerSFX.Alarm, 1.5)
	task.wait(0.1)
	AudioPlayer.playSound(StarDestroyerSFX.EarthRumble)
	CameraShake.shakeCamera(true, 0.3)
	task.wait(3)


	if Player == LocalPlayer then
		DestroyerRemotes.Ready:FireServer()
	end
	--spawnDestroyer(playerPos)

	AudioPlayer.playSound(StarDestroyerSFX.WeAreNotResponsible)


	
	task.wait(30)
	CameraShake.fadeOut(5)
end)

DestroyerRemotes.Ready.OnClientEvent:Connect(function(destroyer: Model, pos)
	for i,v in destroyer:GetChildren() do
		if v:IsA('BasePart') then
			TweenModule.tween(v, 1, {Transparency = 0})
		end
	end
	
	destroyer:GetAttributeChangedSignal('Active'):Connect(function()
		for i,v in destroyer:GetChildren() do
			if v:IsA('BasePart') then
				TweenModule.tween(v, 1, {Transparency = 1})
			end
		end
		
		for i,v in Alarms do
			v:Destroy()
		end
		
		AudioPlayer.stopAllSounds()
	end)
	

	
	TweenModule.tween(destroyer,
		TweenInfo.new(8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{CFrame = pos}
	)
end)

DestroyerRemotes.Intense.OnClientEvent:Connect(function()
	CameraShake.shakeCamera(true, 0.4)
end)