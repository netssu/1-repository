local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerInfo = require(ReplicatedStorage.Modules.Helpers.TowerInfo)
local Auras = require(ReplicatedStorage.Modules.Auras)
local upgradesModule = require(ReplicatedStorage.Upgrades)

return function(humanoid:Humanoid,tower:Model,damage)	
	local damage = math.round(damage or TowerInfo.GetDamage(tower)) -- fixed rounding: ace
	local upgradeStats = upgradesModule[tower.Name]["Upgrades"][tower.Config.Upgrades.Value]

	local enemy = humanoid.Parent
	if not enemy then
		return
	end

	if upgradeStats and upgradeStats.EnemyDebuffs then
		local debuffs = upgradeStats.EnemyDebuffs
		local slowData = debuffs.Slowness
		if slowData and not enemy:GetAttribute("Slowness") then
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local originalSpeed = enemy:GetAttribute("OriginalSpeed") or humanoid.WalkSpeed
				enemy:SetAttribute("OriginalSpeed", originalSpeed)

				Auras.AddAura(enemy, "Slowness", slowData.Duration)
				enemy:SetAttribute("Slowness", true)

				local factor = slowData.SlowFactor or 0.8
				humanoid.WalkSpeed = originalSpeed * factor

				task.delay(slowData.Duration, function()
					if humanoid and humanoid.Parent then
						humanoid.WalkSpeed = originalSpeed
						enemy:SetAttribute("Slowness", false)
					end
				end)
			end
		end
	end

	local bossDamage = math.round(damage or TowerInfo.GetDamage(tower, enemy))
	if enemy ~= nil then
		local enemyRoot = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart")
		if enemyRoot ~= nil then
			local healthBeforeDamageDealt = humanoid.Health
			local enemyType = enemy:FindFirstChild("Type")
			local towerType = tower.Config:FindFirstChild("Type")
			if enemyType and towerType and (enemyType.Value == towerType.Value or towerType.Value == "Hybrid") then
				if tower.Config:FindFirstChild("FreezeDuration") then
					local FreezeDamage = 0
					if tower.Config:FindFirstChild("FreezeDamage") then
						FreezeDamage = tower.Config.FreezeDamage.Value
					end
					local FreezePriority = 1
					if tower.Config:FindFirstChild("FreezePriority") then
						FreezePriority = tower.Config.FreezePriority.Value
					end
					local NoIce = false
					if tower.Config:FindFirstChild("NoIce") then
						NoIce = tower.Config.NoIce.Value
					end
					local freezeEvent = enemy:FindFirstChild("Freeze")
					if freezeEvent then
						freezeEvent:Fire(tower.Config.FreezeDuration.Value,FreezeDamage,FreezePriority,NoIce)
					end
				elseif tower.Config:FindFirstChild("BurningDuration") then
					local BurningDamage = 0
					if tower.Config:FindFirstChild("BurningDamage") then
						BurningDamage = tower.Config.BurningDamage.Value
					end
					local BurningPriority = 1
					if tower.Config:FindFirstChild("BurningPriority") then
						BurningPriority = tower.Config.BurningPriority.Value
					end
					local burnEvent = enemy:FindFirstChild("Burn")
					if burnEvent then
						burnEvent:Fire(tower.Config.BurningDuration.Value,BurningDamage,BurningPriority)
					end
				elseif tower.Config:FindFirstChild("PoisonDuration") then
					local PoisonDamage = 0
					if tower.Config:FindFirstChild("PoisonDamage") then
						PoisonDamage = tower.Config.PoisonDamage.Value
					end
					local PoisonPriority = 1
					if tower.Config:FindFirstChild("PoisonPriority") then
						PoisonPriority = tower.Config.PoisonPriority.Value
					end
					local poisonEvent = enemy:FindFirstChild("Poison")
					if poisonEvent then
						poisonEvent:Fire(tower.Config.PoisonDuration.Value,PoisonDamage,PoisonPriority)
					end
				elseif tower.Config:FindFirstChild("BleedDuration") then
					local BleedPercent = 0
					if tower.Config:FindFirstChild("BleedPercent") then
						BleedPercent = tower.Config.BleedPercent.Value
					end
					local BleedPriority = 1
					if tower.Config:FindFirstChild("BleedPriority") then
						BleedPriority = tower.Config.BleedPriority.Value
					end
					local bleedEvent = enemy:FindFirstChild("Bleed")
					if bleedEvent then
						bleedEvent:Fire(tower.Config.BleedDuration.Value,BleedPercent,BleedPriority)
					end
				elseif tower.Config:FindFirstChild("CursedPercent") then
					local curseEvent = enemy:FindFirstChild("Curse")
					if curseEvent then
						curseEvent:Fire(tower.Config.CursedPercent.Value)
					end
				end
			end
			if enemy:FindFirstChild("IsBoss") then
				if tower then
					tower.Config.TotalDamage.Value += bossDamage
				end
				humanoid:TakeDamage(bossDamage)
			else
				if tower then
					tower.Config.TotalDamage.Value += damage
				end

				humanoid:TakeDamage(damage)
			end

			if tower.Config:FindFirstChild("Owner") and damage > 0 then
				--print(tower.Config)
				local player = game.Players:FindFirstChild(tower.Config.Owner.Value) or game.Players:FindFirstChildOfClass("Player")
				if player and player:IsA("Player") then
					if enemy:FindFirstChild("IsBoss") then
						ReplicatedStorage.Events.VFX_Remote:FireClient(player,"DamageIndicator",bossDamage,enemyRoot)
					else
						ReplicatedStorage.Events.VFX_Remote:FireClient(player,"DamageIndicator",damage,enemyRoot)
					end
				end


				if player then
					local RawDamage = player:GetAttribute("RawDamage") or 0
					if enemy:FindFirstChild("IsBoss") then
						player.Damage.Value += bossDamage
						player:SetAttribute("RawDamage", RawDamage + bossDamage)
					else
						player.Damage.Value += damage
						player:SetAttribute("RawDamage", RawDamage + damage)
					end
				end

				if player then

					if healthBeforeDamageDealt > 0 and humanoid.Health <= 0 then

						local playerTower;
						for _, towerObject in player.OwnedTowers:GetChildren() do
							if towerObject.Name == tower.Name and towerObject:GetAttribute("Equipped") then
								playerTower = towerObject
								break
							end
						end




						if playerTower then
							local Kills = player:WaitForChild("Kills")
							Kills.Value = Kills.Value + 1

							player.Stats.Kills.Value += 1
							player:FindFirstChild("MedalKills").Value += 1
							--warn(player:FindFirstChild("MedalKills").Value)


							if workspace.Info.SpecialEvent.Value then
								player.Stats.YounglingsEnded.Value += 1
							end
						end
					end
				end
			end
		end
	end
end
