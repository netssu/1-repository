local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local Debris: Debris = game:GetService("Debris")

local PROJECTILE_LIFETIME: number = 5
local ABILITY_STUN_DURATION: number = 0.6
local ALLOWED_POSSESSION_RARITIES: {[string]: boolean} = {
	Secret = true,
}

local events: Folder = ReplicatedStorage:WaitForChild("Events")
local possessEvent: RemoteEvent = events:WaitForChild("PossessTower")
local shootEvent: RemoteEvent = events:WaitForChild("PossessShoot")
local playVFXEvent: RemoteEvent = events:WaitForChild("PlayPossessVFX")

local upgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))
local towerFunctionModule = require(ServerScriptService:WaitForChild("Main"):WaitForChild("TowerFunctions"))

local playerPossessions: {[Player]: Model} = {}

local function get_towers_folder(): Folder?
	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder and towersFolder:IsA("Folder") then
		return towersFolder
	end
	return nil
end

local function get_vfx_parent(): Instance
	return workspace:FindFirstChild("VFX") or workspace
end

local function read_numeric_upgrade_value(valueObject: Instance?): number?
	if not valueObject then
		return nil
	end

	if valueObject:IsA("IntValue") or valueObject:IsA("NumberValue") then
		return valueObject.Value
	end

	if valueObject:IsA("StringValue") then
		return tonumber(valueObject.Value)
	end

	return nil
end

local function resolve_tower_upgrade_index(towerModel: Model, towerData: {[string]: any}?): number
	local maxUpgradeIndex = (towerData and towerData.Upgrades and #towerData.Upgrades) or 1
	local config = towerModel:FindFirstChild("Config")

	local rawUpgrade: number? = nil

	if config then
		rawUpgrade = read_numeric_upgrade_value(config:FindFirstChild("Upgrades"))
	end

	if rawUpgrade == nil then
		local attrUpgrades = towerModel:GetAttribute("Upgrades")
		if attrUpgrades ~= nil then
			rawUpgrade = tonumber(attrUpgrades)
		end
	end

	if rawUpgrade == nil and config then
		rawUpgrade = read_numeric_upgrade_value(config:FindFirstChild("Upgrade"))
	end

	if rawUpgrade == nil then
		local attrUpgrade = towerModel:GetAttribute("Upgrade")
		if attrUpgrade ~= nil then
			rawUpgrade = tonumber(attrUpgrade)
		end
	end

	rawUpgrade = math.max(1, math.floor(rawUpgrade or 1))
	local progressionIndex = math.clamp(rawUpgrade, 1, maxUpgradeIndex)

	return progressionIndex
end

local function getTowerStats(towerModel: Model): {[string]: any}
	local towerName = towerModel.Name
	local towerData = upgradesModule[towerName]
	local upgradeIndex = resolve_tower_upgrade_index(towerModel, towerData)

	local stats = {
		Damage = 10,
		Cooldown = 1,
		Range = 15,
		AOESize = 4,
		AttackName = nil,
		AOEType = "Single",
		Rarity = nil,
		BasicAttack = nil,
		Abilities = {},
		MultiDamageDelays = nil
	}

	if not towerData or not towerData.Upgrades or not towerData.Upgrades[1] then
		return stats
	end

	stats.Rarity = towerData.Rarity

	local baseUpgrade = towerData.Upgrades[1]
	stats.BasicAttack = {
		Damage = baseUpgrade.Damage or stats.Damage,
		Cooldown = baseUpgrade.Cooldown or stats.Cooldown,
		Range = baseUpgrade.Range or stats.Range,
		AOESize = baseUpgrade.AOESize or stats.AOESize,
		AttackName = baseUpgrade.AttackName,
		AOEType = baseUpgrade.AOEType or stats.AOEType,
		MultiDamageDelays = baseUpgrade.MultiDamageDelays,
	}

	local attackProgression: {[string]: {[string]: any}} = {}
	for index, upgradeData in ipairs(towerData.Upgrades) do
		if index > upgradeIndex then
			break
		end

		local attackName = upgradeData.AttackName
		if attackName then
			attackProgression[attackName] = {
				Damage = upgradeData.Damage or stats.Damage,
				Cooldown = upgradeData.Cooldown or stats.Cooldown,
				Range = upgradeData.Range or stats.Range,
				AOESize = upgradeData.AOESize or stats.AOESize,
				AttackName = attackName,
				AOEType = upgradeData.AOEType or stats.AOEType,
				MultiDamageDelays = upgradeData.MultiDamageDelays,
			}
		end
	end

	local currentUpgrade = towerData.Upgrades[upgradeIndex]
	if currentUpgrade then
		stats.Damage = currentUpgrade.Damage or stats.Damage
		stats.Cooldown = currentUpgrade.Cooldown or stats.Cooldown
		stats.Range = currentUpgrade.Range or stats.Range
		stats.AOESize = currentUpgrade.AOESize or stats.AOESize
		stats.AttackName = currentUpgrade.AttackName
		stats.AOEType = currentUpgrade.AOEType or stats.AOEType
		stats.MultiDamageDelays = currentUpgrade.MultiDamageDelays
	end

	local basicAttackName = stats.BasicAttack and stats.BasicAttack.AttackName
	if basicAttackName and attackProgression[basicAttackName] then
		stats.BasicAttack = attackProgression[basicAttackName]
	end

	local abilityNames: {string} = {}
	for index, upgradeData in ipairs(towerData.Upgrades) do
		if index > upgradeIndex then
			break
		end

		local attackName = upgradeData.AttackName
		if attackName and attackName ~= basicAttackName and attackProgression[attackName] then
			if not table.find(abilityNames, attackName) then
				table.insert(abilityNames, attackName)
			end
		end
	end

	for i = 1, 2 do
		if abilityNames[i] and attackProgression[abilityNames[i]] then
			stats.Abilities[i] = attackProgression[abilityNames[i]]
		end
	end

	return stats
end

local function build_possession_ui_data(stats: {[string]: any}): {[string]: any}
	local function pack_attack_data(attackData: {[string]: any}?): {[string]: any}?
		if not attackData then
			return nil
		end

		return {
			Name = attackData.AttackName or "Ability",
			Cooldown = attackData.Cooldown or 1,
			AOEType = attackData.AOEType,
			AOESize = attackData.AOESize,
			Range = attackData.Range
		}
	end

	local uiData = {
		Basic = pack_attack_data(stats.BasicAttack),
		Abilities = {
			pack_attack_data(stats.Abilities[1]),
			pack_attack_data(stats.Abilities[2]),
		},
	}

	return uiData
end

local function setCharacterVisibility(char: Model, isVisible: boolean): ()
	for _, obj in ipairs(char:GetDescendants()) do
		if (obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart") or (obj:IsA("Decal") and obj.Name == "face") then
			if not isVisible then
				obj:SetAttribute("OldTrans", obj.Transparency)
				obj.Transparency = 1
			else
				obj.Transparency = obj:GetAttribute("OldTrans") or 0
			end
		end
	end
end

local function restore_bodygyro_state(towerModel: Model): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
	local bodyGyro = humanoidRootPart and humanoidRootPart:FindFirstChildOfClass("BodyGyro")
	if bodyGyro and towerModel:GetAttribute("OriginalBodyGyroMaxTorque") then
		bodyGyro.MaxTorque = towerModel:GetAttribute("OriginalBodyGyroMaxTorque")
	end
end

local function disable_bodygyro_state(towerModel: Model): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
	local bodyGyro = humanoidRootPart and humanoidRootPart:FindFirstChildOfClass("BodyGyro")
	if bodyGyro then
		if towerModel:GetAttribute("OriginalBodyGyroMaxTorque") == nil then
			towerModel:SetAttribute("OriginalBodyGyroMaxTorque", bodyGyro.MaxTorque)
		end
		bodyGyro.MaxTorque = Vector3.zero
	end
end

local function set_tower_baseparts_cframe(towerModel: Model, targetCFrame: CFrame): ()
	for _, partName in ipairs({"TowerBasePart", "VFXTowerBasePart"}) do
		local basePart = towerModel:FindFirstChild(partName)
		if basePart and basePart:IsA("BasePart") then
			basePart.CFrame = targetCFrame
		end
	end
end

local function unpossessTower(player: Player, char: Model?): ()
	local towerModel = playerPossessions[player]
	if towerModel and towerModel.Parent then
		local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			pcall(function()
				humanoidRootPart:SetNetworkOwner(nil)
			end)
			humanoidRootPart.Anchored = true
			humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		end

		towerModel:SetAttribute("Possessed", false)
		restore_bodygyro_state(towerModel)

		local config = towerModel:FindFirstChild("Config")
		if config and config:FindFirstChild("CanAttack") and config.CanAttack:IsA("BoolValue") then
			config.CanAttack.Value = true
		end

		local originalCFrame = towerModel:GetAttribute("OriginalCFrame")
		if originalCFrame and humanoidRootPart then
			task.delay(0.1, function()
				humanoidRootPart.CFrame = originalCFrame
				set_tower_baseparts_cframe(towerModel, originalCFrame)
			end)
		end
	end

	playerPossessions[player] = nil
	player:SetAttribute("PossessingTower", nil)

	if char then
		local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			humanoidRootPart.Anchored = false
		end
		setCharacterVisibility(char, true)

		local originalCharCFrame = char:GetAttribute("OriginalCFrame")
		if originalCharCFrame and humanoidRootPart then
			task.delay(0.1, function()
				humanoidRootPart.CFrame = originalCharCFrame
			end)
		end
	end
end

local function processPossessionRequest(player: Player, towerModel: Instance?): ()
	local char = player.Character
	local characterRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not characterRoot or not characterRoot:IsA("BasePart") then
		return
	end

	if not towerModel or not towerModel:IsA("Model") or not towerModel:IsDescendantOf(get_towers_folder() or workspace) then
		unpossessTower(player, char)
		possessEvent:FireClient(player, nil, false)
		return
	end

	local towerStats = getTowerStats(towerModel)
	local towerRoot = towerModel:FindFirstChild("HumanoidRootPart")
	if not ALLOWED_POSSESSION_RARITIES[towerStats.Rarity] or not towerRoot or not towerRoot:IsA("BasePart") then
		possessEvent:FireClient(player, nil, false)
		return
	end

	if towerModel:GetAttribute("Possessed") and playerPossessions[player] ~= towerModel then
		possessEvent:FireClient(player, nil, false)
		return
	end

	unpossessTower(player, char)

	if not char:GetAttribute("OriginalCFrame") then
		char:SetAttribute("OriginalCFrame", characterRoot.CFrame)
	end
	if not towerModel:GetAttribute("OriginalCFrame") then
		towerModel:SetAttribute("OriginalCFrame", towerRoot.CFrame)
	end

	characterRoot.Anchored = true
	setCharacterVisibility(char, false)

	playerPossessions[player] = towerModel
	player:SetAttribute("PossessingTower", towerModel.Name)
	towerModel:SetAttribute("Possessed", true)

	disable_bodygyro_state(towerModel)
	towerRoot.Anchored = false
	pcall(function()
		towerRoot:SetNetworkOwner(player)
	end)

	local config = towerModel:FindFirstChild("Config")
	if config and config:FindFirstChild("CanAttack") and config.CanAttack:IsA("BoolValue") then
		config.CanAttack.Value = false
	end

	local uiData = build_possession_ui_data(towerStats)

	possessEvent:FireClient(player, towerModel, true, uiData)
end

local function tag_humanoid(humanoid: Humanoid, player: Player)
	local creatorTag = humanoid:FindFirstChild("creator")
	if not creatorTag then
		creatorTag = Instance.new("ObjectValue")
		creatorTag.Name = "creator"
		creatorTag.Parent = humanoid
	end
	creatorTag.Value = player
	Debris:AddItem(creatorTag, 2)
end

local function onPossessShoot(player: Player, targetPosition: Vector3, lookVector: Vector3, abilitySlot: number?): ()
	if typeof(targetPosition) ~= "Vector3" or typeof(lookVector) ~= "Vector3" then
		return
	end

	local towerModel = playerPossessions[player]
	if not towerModel or not towerModel:IsA("Model") or towerModel:GetAttribute("Possessed") ~= true then
		return
	end

	local spawnPart = towerModel:FindFirstChild("HumanoidRootPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	local stunnedUntil = towerModel:GetAttribute("PossessionStunnedUntil")
	if typeof(stunnedUntil) == "number" and os.clock() < stunnedUntil then
		return
	end

	local stats = getTowerStats(towerModel)
	local selectedAttack = stats.BasicAttack

	if abilitySlot and abilitySlot >= 1 and abilitySlot <= 2 then
		selectedAttack = stats.Abilities[abilitySlot]
		if not selectedAttack then
			return
		end
	end

	selectedAttack = selectedAttack or {
		Damage = stats.Damage,
		Cooldown = stats.Cooldown,
		Range = stats.Range,
		AOESize = stats.AOESize,
		AttackName = stats.AttackName,
		AOEType = stats.AOEType,
		MultiDamageDelays = stats.MultiDamageDelays
	}

	local now = os.clock()
	local lastShotAttribute = abilitySlot and string.format("LastShot_Ability%d", abilitySlot) or "LastShot_Basic"
	if now - (towerModel:GetAttribute(lastShotAttribute) or 0) < selectedAttack.Cooldown then
		return
	end

	towerModel:SetAttribute(lastShotAttribute, now)
	if abilitySlot then
		towerModel:SetAttribute("PossessionStunnedUntil", now + ABILITY_STUN_DURATION)
	end

	local maxTargetDistance = selectedAttack.Range or 20
	set_tower_baseparts_cframe(towerModel, spawnPart.CFrame)

	local hitPosition = targetPosition
	local rayResult: RaycastResult? = nil
	local mobsFolder = workspace:FindFirstChild("Mobs")

	if selectedAttack.AOEType == "Splash" then
		local flatTowerPos = Vector3.new(spawnPart.Position.X, targetPosition.Y, spawnPart.Position.Z)
		local dist = (targetPosition - flatTowerPos).Magnitude

		if dist > maxTargetDistance + 5 then
			local dir = (targetPosition - flatTowerPos).Unit
			hitPosition = flatTowerPos + (dir * maxTargetDistance)
		else
			hitPosition = targetPosition
		end
	else
		local isMelee = selectedAttack.Range <= 15
		maxTargetDistance = isMelee and selectedAttack.Range or 2000
		local direction = (targetPosition - spawnPart.Position).Unit
		if direction.Magnitude ~= direction.Magnitude then
			direction = lookVector.Unit
		end

		if mobsFolder then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {mobsFolder}
			raycastParams.FilterType = Enum.RaycastFilterType.Include
			rayResult = workspace:Raycast(spawnPart.Position, direction * maxTargetDistance, raycastParams)
		end

		if rayResult then
			hitPosition = rayResult.Position
		else
			local dist = (targetPosition - spawnPart.Position).Magnitude
			if dist > maxTargetDistance then
				hitPosition = spawnPart.Position + (direction * maxTargetDistance)
			else
				hitPosition = targetPosition
			end
		end
	end

	if selectedAttack.AttackName then
		playVFXEvent:FireAllClients(towerModel, towerModel.Name, selectedAttack.AttackName, hitPosition)
	end

	local mockTarget = Instance.new("Model")
	mockTarget.Name = "ServerMockTarget"

	local mockHRP = Instance.new("Part")
	mockHRP.Name = "HumanoidRootPart"
	mockHRP.CFrame = CFrame.new(hitPosition)
	mockHRP.Anchored = true
	mockHRP.Transparency = 1
	mockHRP.CanCollide = false
	mockHRP.Parent = mockTarget

	mockTarget.PrimaryPart = mockHRP
	Instance.new("Humanoid", mockTarget)

	mockTarget.Parent = get_vfx_parent()
	Debris:AddItem(mockTarget, PROJECTILE_LIFETIME)

	local delayTime = (selectedAttack.MultiDamageDelays and selectedAttack.MultiDamageDelays[1]) or 0

	local gameSpeed = 1
	local infoFolder = workspace:FindFirstChild("Info")
	if infoFolder and infoFolder:FindFirstChild("GameSpeed") and infoFolder.GameSpeed:IsA("NumberValue") then
		gameSpeed = infoFolder.GameSpeed.Value
	end

	task.spawn(function()
		local config = towerModel:FindFirstChild("Config")
		local rangeValue = config and config:FindFirstChild("Range")
		local originalRange = rangeValue and rangeValue:IsA("NumberValue") and rangeValue.Value or selectedAttack.Range

		local aoeTypeValue = config and config:FindFirstChild("AOEType")
		local originalAoeType = aoeTypeValue and aoeTypeValue:IsA("StringValue") and aoeTypeValue.Value or ""

		local aoeSizeValue = config and config:FindFirstChild("AOESize")
		local originalAoeSize = aoeSizeValue and aoeSizeValue:IsA("NumberValue") and aoeSizeValue.Value or 0

		if rangeValue and rangeValue:IsA("NumberValue") then
			rangeValue.Value = 2000
		end

		if aoeTypeValue and aoeTypeValue:IsA("StringValue") then
			aoeTypeValue.Value = selectedAttack.AOEType or "Single"
		end

		if aoeSizeValue and aoeSizeValue:IsA("NumberValue") then
			aoeSizeValue.Value = selectedAttack.AOESize or 0
		end

		pcall(function()
			if selectedAttack.AOEType == "Splash" then
				towerFunctionModule.Splash(towerModel, mockHRP.CFrame, selectedAttack.Damage)
			elseif selectedAttack.AOEType == "Cone" then
				towerFunctionModule.ConeAOE(spawnPart, towerModel, selectedAttack.AOESize, selectedAttack.Damage)
			elseif selectedAttack.AOEType == "AOE" then
				towerFunctionModule.AOE(towerModel, selectedAttack.Damage)
			else
				if rayResult then
					local enemyModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
					if enemyModel then
						local humanoid = enemyModel:FindFirstChild("Humanoid")
						if humanoid and humanoid:IsA("Humanoid") and humanoid.Health > 0 then
							local towerType = config and config:FindFirstChild("Type") and config.Type.Value or "Hybrid"
							local enemyType = enemyModel:FindFirstChild("Type") and enemyModel.Type.Value or ""

							if towerType == "Hybrid" or towerType == enemyType then
								tag_humanoid(humanoid, player)
								if towerFunctionModule.TakeDamage then
									towerFunctionModule.TakeDamage(humanoid, towerModel, selectedAttack.Damage)
								else
									humanoid:TakeDamage(selectedAttack.Damage)
								end
							end
						end
					end
				end
			end
		end)

		task.wait(1.5)

		if rangeValue and rangeValue:IsA("NumberValue") then
			rangeValue.Value = originalRange
		end
		if aoeTypeValue and aoeTypeValue:IsA("StringValue") then
			aoeTypeValue.Value = originalAoeType
		end
		if aoeSizeValue and aoeSizeValue:IsA("NumberValue") then
			aoeSizeValue.Value = originalAoeSize
		end
	end)
end

local function onPlayerRemoving(player: Player): ()
	unpossessTower(player, player.Character)
end

possessEvent.OnServerEvent:Connect(processPossessionRequest)
shootEvent.OnServerEvent:Connect(onPossessShoot)
Players.PlayerRemoving:Connect(onPlayerRemoving)