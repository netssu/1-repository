local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFX_Loader = require(ReplicatedStorage.VFX_Loader)
local MiscModule = require(ReplicatedStorage.VFXModules.Misc)
local upgradesModule = require(ReplicatedStorage.Upgrades)
local TS = game:GetService("TweenService")
local GameSpeed = workspace.Info.GameSpeed
local player = game.Players.LocalPlayer
repeat task.wait() until player:FindFirstChild('DataLoaded')

local playerSettings = player:WaitForChild("Settings")
local TowerInfo = require(ReplicatedStorage.Modules.Helpers.TowerInfo)

ReplicatedStorage.Events.VFX_Remote.OnClientEvent:Connect(function(Name,...)
	if Name == "DamageIndicator"  then
		if not playerSettings.DamageIndicator.Value then return end
		MiscModule.DamageIndicator(...)
		return
	end

	local UnitModule = Name[1]

	for unitName, Info in upgradesModule do
		if Info.Evolve and Info.Evolve.EvolvedUnit == Name[1] then
			UnitModule = unitName
		end
	end

	if not VFX_Loader[UnitModule] then return end -- Spawner units dont have VFX

	if VFX_Loader[UnitModule][Name[2]] and type(VFX_Loader[UnitModule][Name[2]]) == "function" then --Check if there exiest a name, and check if its a function
		if not playerSettings.VFX.Value then return end
		VFX_Loader[UnitModule][Name[2]](...)	--call the function and send in the argument using the ...
		return
	end

end)


local bestTarget = nil
local bestWaypoint = nil
local bestDistance = nil
local bestHealth = nil
local mode = nil
local map = nil
local range = nil

local info = workspace:WaitForChild('Info')

local function handleFindTarget(newTower, mob: Model)
	local HRP = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or nil
	if HRP then
		local newMobPositionForTower = Vector3.new(HRP.Position.X,newTower.HumanoidRootPart.Position.Y,HRP.Position.Z)

		local distanceToMob = (newMobPositionForTower - newTower.HumanoidRootPart.Position).Magnitude
		local distanceToWaypoint = nil

		if not info.Versus.Value then
			if map:FindFirstChild("Waypoints",true) then
				local newMobPositionForPoint = Vector3.new(HRP.Position.X,map.Waypoints[mob:WaitForChild("MovingTo").Value].Position.Y,HRP.Position.Z)
				distanceToWaypoint = (newMobPositionForPoint - map.Waypoints[mob:WaitForChild("MovingTo").Value].Position).Magnitude
			else
				local newMobPositionForPoint = Vector3.new(HRP.Position.X,map["Waypoints"..mob.PathNumber.Value][mob:WaitForChild("MovingTo").Value].Position,HRP.Position.Z)
				distanceToWaypoint = (newMobPositionForPoint - map["Waypoints"..mob.PathNumber.Value][mob:WaitForChild("MovingTo").Value].Position).Magnitude
			end
		else
			local mobTeam = mob:GetAttribute('Team')
						
			local newMobPositionForPoint = Vector3.new(HRP.Position.X,map[mobTeam .. 'Waypoints'][mob:WaitForChild("MovingTo").Value].Position.Y,HRP.Position.Z)
			distanceToWaypoint = (newMobPositionForPoint - map[mobTeam .. 'Waypoints'][mob:WaitForChild("MovingTo").Value].Position).Magnitude

		end

		if distanceToMob <= range then
			if mode == "Near" then
				range = distanceToMob
				bestTarget = mob
			elseif mode == "First" then
				if not bestWaypoint or mob:WaitForChild("MovingTo").Value >= bestWaypoint then

					--	print(`New Mob: {mob} | MovingTo:{mob.MovingTo.Value} | newDistance: {distanceToWaypoint}`)
					--	print(`OLD MOB: {bestTarget} | BestWaypoint:{bestWaypoint} | oldDistance: {bestDistance}`)

					if bestWaypoint and mob:WaitForChild("MovingTo").Value > bestWaypoint then
						bestWaypoint = mob:WaitForChild("MovingTo").Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					elseif not bestDistance or distanceToWaypoint < bestDistance then
						bestWaypoint = bestWaypoint or mob:WaitForChild("MovingTo").Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end
			elseif mode == "Last" then
				--if not bestWaypoint or mob.MovingTo.Value <= bestWaypoint then
				--	bestWaypoint = mob.MovingTo.Value

				--	if not bestDistance or distanceToWaypoint > bestDistance then
				--		bestDistance = distanceToWaypoint
				--		bestTarget = mob
				--	end
				--end

				if not bestWaypoint or mob:WaitForChild("MovingTo").Value <= bestWaypoint then

					if bestWaypoint and mob:WaitForChild("MovingTo").Value < bestWaypoint then
						bestWaypoint = mob:WaitForChild("MovingTo").Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					elseif not bestDistance or distanceToWaypoint > bestDistance then
						bestWaypoint = bestWaypoint or mob:WaitForChild("MovingTo").Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end

			elseif mode == "Strong" then
				if not bestHealth or mob.Humanoid.Health > bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			elseif mode == "Weak" then
				if not bestHealth or mob.Humanoid.Health < bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			end
		end
	end
end

local info = workspace:WaitForChild('Info')

function FindTarget(newTower:Model)
	if not info.Versus.Value then
		map = workspace.Map:FindFirstChildOfClass("Folder")
	else
		map = workspace -- as it should be >:(
	end
	
	mode = newTower.Config.TargetMode.Value
	range = TowerInfo.GetRange(newTower)

	if not info.Versus.Value then
		for i, mob in workspace.Mobs:GetChildren() do
			handleFindTarget(newTower, mob)
		end
	else
		for i, mob in workspace[newTower:GetAttribute('Team') .. 'Mobs']:GetChildren() do
			handleFindTarget(newTower, mob)
		end
	end

	return bestTarget
end

while task.wait() do
	task.spawn(function()
		for i, v in game.Workspace.Towers:GetChildren() do
			if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Attacking") and v.Attacking.Value == false then
				local target = FindTarget(v)
				if target and target:FindFirstChild('HumanoidRootPart') then
					local targetCFrame = CFrame.lookAt(v.HumanoidRootPart.Position, Vector3.new(target.HumanoidRootPart.Position.X,v.HumanoidRootPart.Position.Y,target.HumanoidRootPart.Position.Z))

					if v:FindFirstChild("HumanoidRootPart") then
						TS:Create(v.HumanoidRootPart,TweenInfo.new(0.2/GameSpeed.Value,Enum.EasingStyle.Sine),{CFrame = targetCFrame}):Play()
						if v.HumanoidRootPart:FindFirstChild("BodyGyro") then
							TS:Create(v.HumanoidRootPart.BodyGyro,TweenInfo.new(0.2/GameSpeed.Value,Enum.EasingStyle.Sine),{CFrame = targetCFrame}):Play()
						end
					end
					if v:FindFirstChild("VFXTowerBasePart") then
						TS:Create(v.VFXTowerBasePart,TweenInfo.new(0.2/GameSpeed.Value,Enum.EasingStyle.Sine),{CFrame = targetCFrame}):Play()
					end
					if game.Workspace.CurrentCamera:FindFirstChild("SplashPart") and v:FindFirstChild("SplashPositionPart") then

						local newCFrame = CFrame.new(target.HumanoidRootPart.Position) * CFrame.new(0,target.HumanoidRootPart.Size.Y*-1.45,0)
						TS:Create(v.SplashPositionPart,TweenInfo.new(0.2/GameSpeed.Value,Enum.EasingStyle.Sine),{Position = newCFrame.Position}):Play()  --target.HumanoidRootPart.CFrame * CFrame.new(0,target.HumanoidRootPart.Size.Y*-1.45,0)
						if game.Workspace.CurrentCamera.SplashPart:FindFirstChild("Arrows") then
							--TS:Create(game.Workspace.CurrentCamera.SplashPart,TweenInfo.new(0.2,Enum.EasingStyle.Sine),{Rotation = Vector3.new(0,0,0)}):Play()
							local part1Position = game.Workspace.CurrentCamera.SplashPart.WeldConstraint.Part1.Position + Vector3.new(0,0.2,0)
							TS:Create(game.Workspace.CurrentCamera.SplashPart.Arrows.Part2,TweenInfo.new(0.2/GameSpeed.Value,Enum.EasingStyle.Sine),{CFrame = CFrame.new(part1Position) * CFrame.Angles(0, 0, math.rad(-90))}):Play()
						end
					end	
				end
			end
		end
	end)
end