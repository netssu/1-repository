local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCache = workspace.ItemCache
local DestroyerRemotes = ReplicatedStorage.Remotes.DestroyerRemotes
local DeathRay = require(script.DeathRay)
local Upgrades = require(ReplicatedStorage.Upgrades)
local TowerFunctions = require(ServerScriptService.Main.TowerFunctions)

local info = workspace.Info


local height = 700
local radius = 1000

local function spawnDestroyer(plr)
	if not plr.Character then return end
	local StarDestroyer = ReplicatedStorage.Assets.Stardestroyer.ImperialStarDestroyer:Clone()
	StarDestroyer:SetAttribute('Active', true)
	
	local playerPos = plr.Character:GetPivot().Position -- workspace.center.Position
	local angle = math.rad(math.random(0, 359))
	local offsetX = math.cos(angle) * radius
	local offsetZ = math.sin(angle) * radius
	local startPos = playerPos + Vector3.new(offsetX, height, offsetZ)
	local endPos = playerPos + Vector3.new(0, height, 0)
	local lookCFrame = CFrame.new(startPos, endPos) -- face toward travel path
	local x, y, z = lookCFrame:ToEulerAnglesXYZ()

	StarDestroyer:PivotTo(lookCFrame)
	StarDestroyer.Parent = ItemCache

	endPos = CFrame.new(endPos)  * CFrame.Angles(x, y, z)
	return StarDestroyer, endPos
end

local readyToDeploy = {}
local configs = {}
local upgradeConfig = nil
local AbilityStatus = ReplicatedStorage.States.AbilityStatus

DestroyerRemotes.CallDestroyer.OnServerEvent:Connect(function(plr, unit)
	if AbilityStatus.Value ~= 'G' or not unit then return end
	local potentialConfig = Upgrades[unit.Name].Upgrades[unit.Config.Upgrades.Value]
	
	warn(unit.Config.Upgrades.Value)
	warn(potentialConfig)
	if not potentialConfig then return end
	local Cooldown = potentialConfig.AbilityCooldown
	if not Cooldown then return end
	upgradeConfig = potentialConfig
	
	--local Cooldown = 1 -- DELETE THIS
	
	task.spawn(function()
		local count = Cooldown
		while count ~= 0 do
			count -= 1
			AbilityStatus.Value = tostring(count)
			if not info:FindFirstChild('GameSpeed') then
				local num = Instance.new('NumberValue')
				num.Name = 'GameSpeed'
				num.Value = 1
				num.Parent = info
			end
			
			task.wait(1/info.GameSpeed.Value)
		end
		
		AbilityStatus.Value = 'G'
	end)
	print('Calling destroyer...(server)')
	
	local AbilityStats = {
		AbilityAttackRate = potentialConfig.AbilityAttackRate,
		AbilityDamage = potentialConfig.AbilityDamage,
		Unit = unit
	}
	
	configs[plr] = AbilityStats
	
	table.insert(readyToDeploy, plr)
	DestroyerRemotes.SpawnDestroyer:FireAllClients(plr)
end)

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local duration = 30

DestroyerRemotes.Ready.OnServerEvent:Connect(function(plr)
	local found = table.find(readyToDeploy, plr)
	
	if found then
		table.remove(readyToDeploy, found)
		local destroyer: Model, endPos = spawnDestroyer(plr)
		
		for i,v in destroyer:GetChildren() do
			if v:IsA('BasePart') then
				v.Transparency = 1
			end
		end
		
		DestroyerRemotes.Ready:FireAllClients(destroyer, endPos)
		
		task.wait(9)
		
		-- lazer
		destroyer:PivotTo(endPos)
		
		local EnemyFolder = workspace:FindFirstChild('Mobs')
		
		if not EnemyFolder then
			EnemyFolder = workspace[plr.Team.Name .. 'Mobs']
		end
		local instanceRay = nil
		
		local s,e = pcall(function()
			DeathRay.setRay(destroyer, plr.Character:GetPivot().Position + Vector3.new(0,-3,0))
		end)
		
		if not s then
			task.spawn(error, e)
		end
		
		instanceRay = DeathRay.getInstanceRay(destroyer)

		task.delay(1, function()
			DestroyerRemotes.Intense:FireAllClients()
		end)

		local active = true
		task.delay(duration, function()
			active = false
		end)
				
		--local AbilityStats = {
		--	AbilityAttackRate = potentialConfig.AbilityAttackRate,
		--	AbilityDamage = potentialConfig.AbilityDamage
		--}
		
		local AbilityStats = configs[plr]
		
		--local Damage = 
		task.spawn(function()
			while active do
				for i,v in EnemyFolder:GetChildren() do	
					if v:IsA('Model') then
						local pos = v:GetPivot().Position
						if getMag(pos, DeathRay.getEnd()) < 10 then
							if v.Humanoid.Health < AbilityStats.AbilityDamage then
								-- add kill
								plr.Kills.Value += 1
								v:Destroy()
							else
								v.Humanoid:TakeDamage(AbilityStats.AbilityDamage)
							end
							
							AbilityStats.Unit.Config.TotalDamage.Value += AbilityStats.AbilityDamage
							plr.Damage.Value += AbilityStats.AbilityDamage
						end
					end
				end
				
				task.wait(AbilityStats.AbilityAttackRate/info.GameSpeed.Value)
			end
		end)

		while active do
			for i,v: Model in EnemyFolder:GetChildren() do
				if not v:IsA('Model') then continue end
				local ttime = 0
				pcall(function()
					ttime = DeathRay.setRay(destroyer, v:GetPivot().Position)
				end)
				task.wait(ttime/info.GameSpeed.Value)
				task.wait(1/info.GameSpeed.Value)
				
				if not active then break end
			end
			task.wait(1/info.GameSpeed.Value)
		end
		
		warn('No longer active! tell clients we are going away')
		-- just destroy for now
		destroyer:SetAttribute('Active', false)
		--workspace.ItemCache.DeathRay:Destroy()
		if instanceRay then
			instanceRay:Destroy()
		end
		
		task.wait(2/info.GameSpeed.Value)
		destroyer:Destroy()
	end
end)