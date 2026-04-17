local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Raycast = require(script.Parent:WaitForChild("Raycast2"))
local CollisionGroup = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CollisionGroup"))
local TraitModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Traits"))
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local AuraTraitsFolder = ReplicatedStorage:WaitForChild("AuraTraits")
local UnitsFollowFolder = workspace:WaitForChild("UnitsFollowFolder")
local character = Players.LocalPlayer.Character
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local Towers = {}
Towers.__index = Towers

local offsets = {
	CFrame.new(3,0,0),
	CFrame.new(-3,0,0),
	CFrame.new(0,0,3),
	CFrame.new(-2,0,3),
	CFrame.new(2,0,-3),
	CFrame.new(-2,0,-3)
}

function Towers.new(towerValue, player:Player, slot:number, traitName:string, shiny:boolean)
	local name = towerValue.Name
	local newcharacter = player.Character or player.CharacterAdded:Wait()
	local humanoid = newcharacter:WaitForChild("Humanoid")
	local humanoidRootPart = newcharacter:WaitForChild("HumanoidRootPart")
	local tower = GetUnitModel[name]
	if tower then
		tower = tower:Clone()
	else
		print('Unable to find ', name)
		return
	end

	local self = setmetatable({
		Player = player,
		Character = newcharacter,
		Humanoid = humanoid,
		Tower = nil,
		TowerName = name,
		RaycastParem = RaycastParams.new(),
		FilterList = {newcharacter, tower, workspace.Ignore},
		Slot = slot,
		CurrentAnimName = nil,
		CurrentAnimTrack = nil,
		Connections = {},
		Animations = {},
		LastUpdate = 0,
		TargetCFrame = nil
	}, Towers)

	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char and not table.find(self.FilterList, char) then
			table.insert(self.FilterList, char)
		end
	end
	self.RaycastParem.FilterType = Enum.RaycastFilterType.Exclude
	self.RaycastParem.FilterDescendantsInstances = self.FilterList

	tower.HumanoidRootPart.Anchored = true
	CollisionGroup:SetModel(tower, "Tower")
	TraitModule.AddVisualAura(tower, traitName)

	towerValue:GetAttributeChangedSignal("Trait"):Connect(function()
		TraitModule.AddVisualAura(tower, towerValue:GetAttribute("Trait"))
	end)

	self.Tower = tower
	tower.Parent = UnitsFollowFolder
	tower:PivotTo(character.PrimaryPart.CFrame)
	self.TargetCFrame = tower:GetPivot()
	self:Init()
	return self
end

function Towers:Init()
	self.Connections["HumanoidAnimation"] = self.Humanoid.Running:Connect(function()
		self:UpdateAnimation()
	end)

	self.Connections["Movement"] = RunService.Heartbeat:Connect(function(dt)
		self.LastUpdate += dt
		if self.LastUpdate >= 0.1 then
			self:Move()
			self.LastUpdate = 0
		end
	end)

	self.Connections["SmoothRender"] = RunService.RenderStepped:Connect(function()
		if self.Tower and self.TargetCFrame then
			local current = self.Tower:GetPivot()
			local smoothed = current:Lerp(self.TargetCFrame, 0.2)
			self.Tower:PivotTo(smoothed)
		end
	end)
end

function Towers:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Tower:Destroy()
end

function Towers:UpdateAnimation()
	local animRequestName
	local animSpeed = 1
	if self.Humanoid.MoveDirection.Magnitude > 0 then
		animRequestName = self.Humanoid.WalkSpeed > 16 and "Run" or "Walk"
	else
		animRequestName = "Idle"
	end

	if self.CurrentAnimName == animRequestName then return end
	if not self.Tower then return end

	local animator = self.Tower.Humanoid:FindFirstChild("Animator") or self.Tower.Humanoid
	if not self.Animations[animRequestName] then
		local anim = self.Tower:FindFirstChild("Animations"):FindFirstChild(animRequestName)
		if anim then
			self.Animations[animRequestName] = animator:LoadAnimation(anim)
		end
	end

	local track = self.Animations[animRequestName]
	if track then
		if self.CurrentAnimTrack and self.CurrentAnimTrack ~= track then
			self.CurrentAnimTrack:Stop()
		end
		self.CurrentAnimTrack = track
		self.CurrentAnimName = animRequestName
		track:Play(nil, nil, animSpeed)
	end
end

function Towers:Move()
	local offset = offsets[self.Slot]
	if not self.Character:FindFirstChild('HumanoidRootPart') then return end

	local origin = self.Character.HumanoidRootPart.CFrame * offset
	local currentHeightCheck, increment, maxCheck = 0, 10, 3
	local result

	for i = 1, maxCheck do
		if result and result.Material ~= Enum.Material.Water then break end
		result = workspace:Raycast(origin.Position + Vector3.new(0, currentHeightCheck, 0), Vector3.new(0, -200, 0), self.RaycastParem)
		currentHeightCheck += increment
	end

	local newPosition = result and result.Position or origin.Position
	local inAir = workspace:Raycast(self.Character.HumanoidRootPart.Position, Vector3.new(0, -4, 0), self.RaycastParem) == nil
	local x, y, z = self.Character.HumanoidRootPart.CFrame:ToOrientation()
	local cf

	if inAir then
		newPosition = newPosition * Vector3.new(1, 0, 1) + Vector3.new(0, self.Character.HumanoidRootPart.CFrame.Position.Y - 2, 0)
		cf = CFrame.new(newPosition) * CFrame.Angles(0, y, z)
	else
		cf = CFrame.new(newPosition + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, y, z)
	end

	self.TargetCFrame = cf
end

function Towers:UpdateSlot(newSlot)
	self.Slot = newSlot
	self.Tower.Parent = UnitsFollowFolder
end

return Towers