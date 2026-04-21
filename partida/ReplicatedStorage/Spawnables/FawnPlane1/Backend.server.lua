local ServerScriptService = game:GetService("ServerScriptService")
local TowerFunctions = require(ServerScriptService.Main.TowerFunctions)

local LeftMuzzle = script.Parent.LeftGun.MuzzleFlash
local RightMuzzle = script.Parent.RightGun.MuzzleFlash
local Fire = script.Parent.Body.Firing
local firetime = 0.06

local function fireGuns()
	for i = 1, 3 do
		task.wait(firetime/workspace.Info.GameSpeed.Value)
		for i,v in pairs(LeftMuzzle:GetChildren()) do
			if v:IsA('SpotLight') then
				v.Enabled = true
			else
				v:Emit(3)
			end
		end
		
		for i,v in pairs(RightMuzzle:GetChildren()) do
			if v:IsA('SpotLight') then
				v.Enabled = true
			else
				v:Emit(3)
			end
		end
		
		Fire:Play()
		
		task.wait(firetime/workspace.Info.GameSpeed.Value)
		
		
		for i,v in pairs(LeftMuzzle:GetChildren()) do
			if v:IsA('SpotLight') then
				v.Enabled = false
			end
		end

		for i,v in pairs(RightMuzzle:GetChildren()) do
			if v:IsA('SpotLight') then
				v.Enabled = false
			end
		end
	end
end

local Radius = script.Parent.Radius
local Center = script.Parent.HumanoidRootPart
local Range = Radius.Size.Z/2

local Cooldown = script.Parent:GetAttribute('Cooldown')
local Team = script.Parent:GetAttribute('Team')
local OwnedBy = script.Parent.OwnedBy.Value :: Model

OwnedBy:GetPropertyChangedSignal('Parent'):Once(function() -- destroy if tower is gone
	script.Parent:Destroy()
end)

OwnedBy.Config.Upgrades.Changed:Once(function()
	script.Parent:Destroy()
end)

local shouldFire = false

while task.wait(Cooldown/workspace.Info.GameSpeed.Value) do
	-- Handle targeting logic and stuff
	--dealDamage(v)
	--shouldFire = true
	local enemies = TowerFunctions.SpawnerFindTarget(script.Parent)
	
	if #enemies ~= 0 then
		for i,v in enemies do
			TowerFunctions.DamageFunction(OwnedBy, v)
		end
		
		shouldFire = true
	end
	
	if shouldFire then
		task.spawn(fireGuns)
		
		shouldFire = false
	end
	
end