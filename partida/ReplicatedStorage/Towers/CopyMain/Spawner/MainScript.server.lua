-- SERVICES
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)
local upgradesModule = require(game.ReplicatedStorage.Upgrades)

-- VARIABLES
local SpawnerDealDamage = ServerScriptService.Bindables.SpawnerDealDamage
local UnitName = upgradesModule[script.Parent.Name]
local currentWave = workspace.Info.Wave
local targetSpawn = nil :: BasePart
local MapFolder = workspace.Map:GetChildren()[1] :: Folder or workspace
local Start = nil
local End = nil
local currentTeam = script.Parent:GetAttribute('Team')

-- FUNCTIONS
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

	Plane:SetAttribute('GameSpeed', workspace.Info.GameSpeed.Value)

	Plane.Radius.Size = Vector3.new(0.05, config.Range*2, config.Range*2)

	Plane.Parent = workspace.Spawnables

	Plane.HumanoidRootPart:SetNetworkOwner(nil)

	Plane.Movement.Enabled = true
	Plane.Backend.Enabled = true

	if Plane:FindFirstChild('Body') and Plane.Body:FindFirstChild('Engine') then
		Plane.Body.Engine.PlaybackSpeed = workspace.Info.GameSpeed.Value
		Plane.Body.Engine:Play()
	end
end

-- INIT
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

script.Parent.Config.Upgrades.Changed:Connect(function()
	local config = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]
	spawnPlane({
		SpawnedName = config.SpawnedName,
		Range = config.SpawnedRange,
		SpawnBlock = targetSpawn,
		Cooldown = config.SpawnedCooldown,
	})
end)

task.spawn(function()
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
end)