local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Raycast = require(script.Parent:WaitForChild("Raycast2"))
local CollisionGroup = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CollisionGroup"))
local TraitModule = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Traits"))
local GetUnitModel = require(game.ReplicatedStorage.Modules.GetUnitModel)
local AuraTraitsFolder = ReplicatedStorage:WaitForChild("AuraTraits")
local UnitsFollowFolder = game.Workspace:WaitForChild("UnitsFollowFolder")
local character = Players.LocalPlayer.Character
local humanoid: Humanoid = character:WaitForChild("Humanoid")


local unitAnimationList = {}

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

function Towers.new(towerValue, player:Player, slot:number,traitName :string,shiny:boolean)
	local name = towerValue.Name
	local newcharacter = player.Character or player.CharacterAdded:Wait()
	local humanoid = newcharacter:WaitForChild("Humanoid")
	local humanoidRootPart = newcharacter:WaitForChild("HumanoidRootPart")
	local tower = if shiny then  GetUnitModel[name] else GetUnitModel[name]
	if tower then
		tower = tower:Clone()
	else
		print('Unable to find ', name)
		
		return
	end
	
	--print(towerValue)
	
	local self = setmetatable({
		Player = player,
		Character = newcharacter,
		Humanoid = humanoid,

		Tower = nil,
		TowerName = name,
		RaycastParem = RaycastParams.new(),
		FilterList = {newcharacter, tower,workspace.Ignore},


		Slot = slot,
		CurrentAnimName = nil,
		CurrentAnimTrack = nil,
		Connections = {}
	},Towers)

	if name == nil then return end	
    tower.HumanoidRootPart.Anchored = true
    
    --for i,v in pairs(tower:GetDescendants()) do
    --    if v:IsA('BasePart') then
    --        v.CanCollide = false
    --        v.CanTouch = false
    --    end
    --end

    
	CollisionGroup:SetModel(tower,"Tower")

	TraitModule.AddVisualAura(tower, traitName)
	towerValue:GetAttributeChangedSignal("Trait"):Connect(function()
		TraitModule.AddVisualAura(tower, towerValue:GetAttribute("Trait"))
	end)

	self.Tower = tower
	tower.Parent = UnitsFollowFolder

	self.RaycastParem.FilterType = Enum.RaycastFilterType.Exclude
	self.RaycastParem.FilterDescendantsInstances = self.FilterList

	tower:PivotTo(character.PrimaryPart.CFrame)
	self:Init()

	return self
end

function Towers:Init()
	self.Connections["HumanoidAnimation"] = self.Humanoid.Running:Connect(function() self:UpdateAnimation() end)
	self.Connections["Movement"] = game["Run Service"].RenderStepped:Connect(function() self:Move() end)
end

function Towers:Destroy()
	for _,connection in self.Connections do
		connection:Disconnect()
	end

	self.Tower:Destroy()
end

function Towers:UpdateAnimation()

	local animRequestName
	local animSpeed = 1
	if self.Humanoid.MoveDirection.Magnitude > 0 then 


		if self.Humanoid.WalkSpeed >16 then
			animSpeed = 1
			animRequestName = "Run"
		else
			animSpeed = 1
			animRequestName = "Walk"
		end
	else
		animRequestName = "Idle"
	end

	if self.CurrentAnimName and self.CurrentAnimName == animRequestName then return end

    local animator = self.Tower.Humanoid:FindFirstChild("Animator") or self.Tower.Humanoid--target:FindFirstChild("Humanoid"):FindFirstChild("Animator") or target:FindFirstChild("Humanoid")
	if not self.Tower then return end -- tower is nil sometiems lol
	--print(self.Tower)
	local animation = self.Tower:FindFirstChild("Animations"):FindFirstChild(animRequestName)  --target:FindFirstChild("Animations"):FindFirstChild(name)

	if self.CurrentAnimTrack then
		self.CurrentAnimTrack:Stop()
		self.CurrentAnimTrack:Destroy()
	end

	self.CurrentAnimTrack = animator:LoadAnimation(animation)
	self.CurrentAnimName = animRequestName
	self.CurrentAnimTrack:Play(nil,nil,animSpeed)
end

function Towers:Move()

	for _,player in game.Players:GetPlayers() do
		local character = player.Character
		if not character then continue end
		if table.find(self.FilterList,character) then continue end

		table.insert(self.FilterList,character)

	end
	self.RaycastParem.FilterDescendantsInstances = self.FilterList
	local offset = offsets[self.Slot]
	
	if not self.Character:FindFirstChild('HumanoidRootPart') then
		return
	end
	
	local origin = self.Character.HumanoidRootPart.CFrame * offset 

	local currentHeightCheck = 0
	local increment = 10
	local maxCheck = 5



	local result 
	for i = 1,maxCheck do
		if result and result.Material ~= Enum.Material.Water then break end
		result = workspace:Raycast(origin.Position + Vector3.new(0,currentHeightCheck,0),Vector3.new(0,-200,0),self.RaycastParem)
		currentHeightCheck += increment
	end


	local newPosition
	if result then
		newPosition = result.Position
	else
		newPosition = origin.Position
	end


	local cframe = self.Tower:GetPivot()
	local inAir =  workspace:Raycast(self.Character.HumanoidRootPart.Position,Vector3.new(0,-4,0),self.RaycastParem) == nil and true or false   --self.Humanoid.FloorMaterial == Enum.Material.Air and true or false
	local cf 
	local x,y,z = self.Character.HumanoidRootPart.CFrame:ToOrientation()
	if inAir then
		newPosition = newPosition * Vector3.new(1,0,1) + Vector3.new(0,character.HumanoidRootPart.CFrame.Position.Y - 2,0)
		cf = CFrame.new(newPosition) * CFrame.Angles(0,y,z) --( self.Character.PrimaryPart.CFrame.Rotation )
	else
		cf = CFrame.new(newPosition + Vector3.new(0,1.2 ,0)) * CFrame.Angles(0,y,z) --* self.Character.PrimaryPart.CFrame.Rotation
	end



	self.Tower:PivotTo(cframe:Lerp(cf,0.25))
end

function Towers:UpdateSlot(newSlot)
	self.Slot = newSlot
	self.Tower.Parent = UnitsFollowFolder
end

return Towers
