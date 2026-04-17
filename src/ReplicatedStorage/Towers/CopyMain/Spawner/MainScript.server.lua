local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnerDealDamage = ServerScriptService.Bindables.SpawnerDealDamage
local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)

local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)
local upgradesModule = require(game.ReplicatedStorage.Upgrades)
local UnitName = upgradesModule[script.Parent.Name]
local currentWave = workspace.Info.Wave

local targetSpawn = nil :: BasePart

local MapFolder = workspace.Map:GetChildren()[1] :: Folder or workspace

local Start = nil
local End = nil



local currentTeam = script.Parent:GetAttribute('Team')

if currentTeam then
	-- we are inside a team
	targetSpawn = MapFolder[currentTeam .. 'End']
	Start = MapFolder[currentTeam .. 'Start']
	End = MapFolder[currentTeam .. 'End']
else
	-- just get normal spawn
	Start = MapFolder.Start
	End = MapFolder.End
	targetSpawn = End
end

type config = {
	SpawnedName: string,
	Range: number,
	SpawnBlock: Part,
	Cooldown: number,
}

local function spawnPlane(config:config)
	local Plane = ReplicatedStorage.Spawnables[config.SpawnedName]:Clone() :: Model
	Plane:PivotTo(config.SpawnBlock.CFrame * CFrame.new(0,4,0))	

	local obj = Instance.new('ObjectValue', Plane)
	obj.Name = 'OwnedBy'
	obj.Value = script.Parent
	
	Plane:SetAttribute('Team', currentTeam)
	Plane:SetAttribute('Cooldown', config.Cooldown)
	Plane:SetAttribute('Range', config.Range)

	Plane.Radius.Size = Vector3.new(0.05, config.Range*2, config.Range*2)
	
	Plane.Parent = workspace.Spawnables

	Plane.HumanoidRootPart:SetNetworkOwner(nil)

	Plane.Movement.Enabled = true
	Plane.Backend.Enabled = true
	
	if Plane:FindFirstChild('Body') and Plane.Body:FindFirstChild('Engine') then
		Plane.Body.Engine:Play()
	end
end

script.Parent.Config.Upgrades.Changed:Connect(function()
	local config = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]
	spawnPlane({
		SpawnedName = config.SpawnedName,
		Range = config.SpawnedRange,
		SpawnBlock = targetSpawn,
		Cooldown = config.SpawnedCooldown,
	})
end)

while true do
	local config = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]
	
	spawnPlane({
		SpawnedName = config.SpawnedName,
		Range = config.SpawnedRange,
		SpawnBlock = targetSpawn,
		Cooldown = config.SpawnedCooldown,
	})
	
	ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name,UnitName["Upgrades"][script.Parent.Config.Upgrades.Value].AttackName},script.Parent.HumanoidRootPart)
	ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, "Attack", script.Parent)
	
	task.wait(config.Cooldown/workspace.Info.GameSpeed.Value)
end
