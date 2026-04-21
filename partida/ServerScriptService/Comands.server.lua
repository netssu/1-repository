local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TowerModule = require(script.Parent.Main.Tower)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local UpgradesModule = require(ReplicatedStorage.Upgrades)

print("[GIVE/EQUIP] Script iniciado")

local ADMIN_USERS = {
	["kaosgamesteam1"] = true,
	["ckaosgames2"] = true
}

local MAX_SELECTED_TOWERS = 4

local function dbg(player, msg)
	if player then
	--	print("[GIVE/EQUIP][" .. player.Name .. "] " .. msg)
	else
	--	print("[GIVE/EQUIP] " .. msg)
	end
end

local function trim(value)
	if type(value) ~= "string" then
		return value
	end

	return value:match("^%s*(.-)%s*$")
end

local function getTowerFolderPath(towerModel)
	local towersFolder = ReplicatedStorage:FindFirstChild("Towers")
	if not towersFolder or not towerModel then
		return ""
	end

	local segments = {}
	local current = towerModel.Parent

	while current and current ~= towersFolder do
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end

	return table.concat(segments, "/")
end

local function getTowerCatalog()
	local catalog = {}

	for towerName in pairs(UpgradesModule) do
		local towerModel = GetUnitModel[towerName]
		if towerModel and towerModel:IsA("Model") and towerModel:FindFirstChild("HumanoidRootPart", true) then
			local folderPath = getTowerFolderPath(towerModel)
			table.insert(catalog, {
				name = towerName,
				folderPath = folderPath,
				sortKey = string.lower(folderPath .. "/" .. towerName)
			})
		end
	end

	table.sort(catalog, function(a, b)
		if a.sortKey == b.sortKey then
			return string.lower(a.name) < string.lower(b.name)
		end

		return a.sortKey < b.sortKey
	end)

	return catalog
end

local function findTowerName(inputName)
	local catalog = getTowerCatalog()
	if #catalog == 0 then
		return nil, nil, "Nenhuma tower valida encontrada no catalogo"
	end

	if not inputName or inputName == "" then
		return nil, nil, "Informe o nome ou ID da tower"
	end

	local numericIndex = tonumber(inputName)
	if numericIndex and math.floor(numericIndex) == numericIndex then
		local entry = catalog[numericIndex]
		if entry then
			dbg(nil, string.format("ID %d => %s [%s]", numericIndex, entry.name, entry.folderPath))
			return entry.name, numericIndex
		end

		return nil, nil, "ID invalido. Use um numero entre 1 e " .. tostring(#catalog)
	end

	for index, entry in ipairs(catalog) do
		if entry.name:lower() == inputName:lower() then
			dbg(nil, string.format("MATCH por nome => [%d] %s [%s]", index, entry.name, entry.folderPath))
			return entry.name, index
		end
	end

	return nil, nil, "Tower nao existe"
end

local function dumpTowerCatalog(player)
	local catalog = getTowerCatalog()
	dbg(player, "===== DUMP TOWER IDS =====")

	for index, entry in ipairs(catalog) do
		dbg(player, string.format("[%d] %s | Pasta=%s", index, entry.name, entry.folderPath))
	end

	dbg(player, "===== FIM DUMP TOWER IDS =====")
end

local function dumpOwnedTowers(player)
	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		dbg(player, "OwnedTowers nao encontrado")
		return
	end

	dbg(player, "===== DUMP OWNEDTOWERS =====")
	for i, tower in ipairs(owned:GetChildren()) do
		dbg(
			player,
			string.format(
				"[%d] %s | Equipped=%s | Slot=%s | Level=%s | Trait=%s | Shiny=%s | UniqueID=%s",
				i,
				tower.Name,
				tostring(tower:GetAttribute("Equipped")),
				tostring(tower:GetAttribute("EquippedSlot")),
				tostring(tower:GetAttribute("Level")),
				tostring(tower:GetAttribute("Trait")),
				tostring(tower:GetAttribute("Shiny")),
				tostring(tower:GetAttribute("UniqueID"))
			)
		)
	end
	dbg(player, "===== FIM DUMP =====")
end

local function countEquipped(player)
	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		return 0
	end

	local total = 0
	for _, tower in ipairs(owned:GetChildren()) do
		if tower:GetAttribute("Equipped") == true then
			total += 1
		end
	end
	return total
end

local function getFreeSlot(player)
	local used = {}

	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		return nil
	end

	for _, tower in ipairs(owned:GetChildren()) do
		if tower:GetAttribute("Equipped") == true then
			local slot = tostring(tower:GetAttribute("EquippedSlot") or "")
			if slot ~= "" then
				used[slot] = true
			end
		end
	end

	for i = 1, MAX_SELECTED_TOWERS do
		if not used[tostring(i)] then
			return tostring(i)
		end
	end

	return nil
end

local function findOwnedTowerByName(player, towerName)
	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		return nil
	end

	for _, tower in ipairs(owned:GetChildren()) do
		if tower.Name == towerName then
			return tower
		end
	end

	return nil
end

local function unequipTowerInSameSlot(player, slot, exceptTower)
	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		return
	end

	for _, tower in ipairs(owned:GetChildren()) do
		if tower ~= exceptTower then
			local equipped = tower:GetAttribute("Equipped")
			local equippedSlot = tostring(tower:GetAttribute("EquippedSlot") or "")

			if equipped == true and equippedSlot == tostring(slot) then
				dbg(player, "Desequipando '" .. tower.Name .. "' do slot " .. tostring(slot))
				tower:SetAttribute("Equipped", false)
				tower:SetAttribute("EquippedSlot", "")
			end
		end
	end
end

local function giveAndEquipTower(player, towerName, forcedSlot)
	dbg(player, "giveAndEquipTower iniciado com towerName = " .. tostring(towerName) .. " | forcedSlot = " .. tostring(forcedSlot))

	if not player:FindFirstChild("DataLoaded") then
		dbg(player, "ERRO: DataLoaded ainda nao existe")
		return false, "Data ainda nao carregada"
	end

	if typeof(_G.createTower) ~= "function" then
		dbg(player, "ERRO: _G.createTower nao esta disponivel")
		return false, "_G.createTower nao disponivel"
	end

	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		dbg(player, "ERRO: OwnedTowers nao encontrado")
		return false, "OwnedTowers nao encontrado"
	end

	local realTowerName, towerIndex, resolveError = findTowerName(towerName)
	if not realTowerName then
		dbg(player, "ERRO: " .. tostring(resolveError))
		return false, resolveError or "Tower nao existe"
	end

	dbg(player, "Nome resolvido: " .. realTowerName .. " | ID = " .. tostring(towerIndex))

	local existing = findOwnedTowerByName(player, realTowerName)
	if existing then
		dbg(player, "Player ja possui essa tower. Vai reutilizar a existente.")
	else
		dbg(player, "Player nao possui essa tower. Criando via _G.createTower...")
		existing = _G.createTower(owned, realTowerName, "", {Shiny = false})
		dbg(player, "Tower criada: " .. tostring(existing))
	end

	if not existing then
		dbg(player, "ERRO: falha ao criar/obter tower")
		return false, "Falha ao criar tower"
	end

	local slotToUse = forcedSlot and tostring(forcedSlot) or getFreeSlot(player)
	dbg(player, "Slot escolhido = " .. tostring(slotToUse))

	if not slotToUse or slotToUse == "" then
		dbg(player, "ERRO: nenhum slot livre encontrado")
		return false, "Nenhum slot livre"
	end

	local equippedCount = countEquipped(player)
	dbg(player, "Equipped count atual = " .. tostring(equippedCount))

	unequipTowerInSameSlot(player, slotToUse, existing)

	dbg(player, "Setando Equipped = true")
	existing:SetAttribute("Equipped", true)

	dbg(player, "Setando EquippedSlot = " .. tostring(slotToUse))
	existing:SetAttribute("EquippedSlot", tostring(slotToUse))

	dbg(player, "Estado final da tower:")
	dbg(
		player,
		string.format(
			"%s | Equipped=%s | EquippedSlot=%s | Level=%s | Exp=%s | Trait=%s | Locked=%s | UniqueID=%s | Shiny=%s",
			existing.Name,
			tostring(existing:GetAttribute("Equipped")),
			tostring(existing:GetAttribute("EquippedSlot")),
			tostring(existing:GetAttribute("Level")),
			tostring(existing:GetAttribute("Exp")),
			tostring(existing:GetAttribute("Trait")),
			tostring(existing:GetAttribute("Locked")),
			tostring(existing:GetAttribute("UniqueID")),
			tostring(existing:GetAttribute("Shiny"))
		)
	)

	dumpOwnedTowers(player)

	return true, "Tower dada e equipada no slot " .. tostring(slotToUse)
end

local function getGroundedSpawnCFrame(player, towerName)
	local character = player.Character
	if not character then
		return nil, "Character nao carregado"
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, "HumanoidRootPart nao encontrado"
	end

	local towerModel = GetUnitModel[towerName]
	local towerRoot = towerModel and towerModel:FindFirstChild("HumanoidRootPart", true)
	if not towerRoot then
		return nil, "HumanoidRootPart da tower nao encontrado"
	end

	local raycastFilter = {character}
	local towersFolder = Workspace:FindFirstChild("Towers")
	local redZones = Workspace:FindFirstChild("RedZones")

	if towersFolder then
		table.insert(raycastFilter, towersFolder)
	end

	if redZones then
		table.insert(raycastFilter, redZones)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = raycastFilter

	local rayOrigin = hrp.Position + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -250, 0)
	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if not raycastResult then
		return nil, "Nao encontrei chao abaixo do player"
	end

	local height = towerRoot.Size.Y * 1.5
	local spawnPosition = Vector3.new(hrp.Position.X, raycastResult.Position.Y + height, hrp.Position.Z)
	local forward = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)

	if forward.Magnitude <= 0.001 then
		return CFrame.new(spawnPosition)
	end

	return CFrame.lookAt(spawnPosition, spawnPosition + forward.Unit)
end

local function putTowerHere(player, towerName)
	dbg(player, "putTowerHere iniciado com towerName = " .. tostring(towerName))

	if not player:FindFirstChild("DataLoaded") then
		dbg(player, "ERRO: DataLoaded ainda nao existe")
		return false, "Data ainda nao carregada"
	end

	if typeof(_G.createTower) ~= "function" then
		dbg(player, "ERRO: _G.createTower nao esta disponivel")
		return false, "_G.createTower nao disponivel"
	end

	local owned = player:FindFirstChild("OwnedTowers")
	if not owned then
		dbg(player, "ERRO: OwnedTowers nao encontrado")
		return false, "OwnedTowers nao encontrado"
	end

	local realTowerName, towerIndex, resolveError = findTowerName(towerName)
	if not realTowerName then
		dbg(player, "ERRO: " .. tostring(resolveError))
		return false, resolveError or "Tower nao existe"
	end

	dbg(player, "Tower escolhida para puthere: " .. realTowerName .. " | ID = " .. tostring(towerIndex))

	local existing = findOwnedTowerByName(player, realTowerName)
	if not existing then
		dbg(player, "Player nao possui essa tower. Criando via _G.createTower...")
		existing = _G.createTower(owned, realTowerName, "", {Shiny = false})
	end

	if not existing then
		dbg(player, "ERRO: falha ao criar/obter tower")
		return false, "Falha ao criar tower"
	end

	local spawnCFrame, spawnError = getGroundedSpawnCFrame(player, realTowerName)
	if not spawnCFrame then
		dbg(player, "ERRO: " .. tostring(spawnError))
		return false, spawnError or "Nao foi possivel calcular a posicao da tower"
	end

	local spawnedTower = TowerModule.Spawn(player, existing, spawnCFrame, nil, true, true, true)
	if not spawnedTower then
		dbg(player, "ERRO: falha ao colocar tower no mapa")
		return false, "Nao foi possivel colocar a tower"
	end

	return true, "Tower colocada no chao, na sua posicao"
end

local function endMatch(player, isVictoryArg)
	local isVictory = (tostring(isVictoryArg) == "1")

	local info = Workspace:FindFirstChild("Info")
	if info then
		local victoryVal = info:FindFirstChild("Victory")
		local gameOverVal = info:FindFirstChild("GameOver")

		if victoryVal and gameOverVal then
			victoryVal.Value = isVictory
			gameOverVal.Value = true
			return true, "Partida encerrada. Vitoria: " .. tostring(isVictory)
		else
			return false, "Valores de Victory/GameOver nao encontrados em Workspace.Info"
		end
	else
		return false, "Pasta Info nao encontrada no Workspace"
	end
end

Players.PlayerAdded:Connect(function(player)
	dbg(player, "PlayerAdded")

	player.Chatted:Connect(function(message)
		dbg(player, "Chat recebido: " .. tostring(message))

		if not ADMIN_USERS[player.Name] then
			dbg(player, "Sem permissao")
			return
		end

		local cmd, rest = message:match("^(%S+)%s*(.*)$")
		local arg1 = nil
		local arg2 = ""

		if rest and rest ~= "" then
			arg1, arg2 = rest:match("^([^,]+)%s*,%s*(.*)$")
			if not arg1 then
				arg1 = rest
			end
		end

		arg1 = trim(arg1)
		arg2 = trim(arg2) or ""
		dbg(player, "Parser => cmd=" .. tostring(cmd) .. " arg1=" .. tostring(arg1) .. " arg2=" .. tostring(arg2))

		if not cmd then
			return
		end

		cmd = cmd:lower()

		if cmd == "!giveequip" then
			local success, response = giveAndEquipTower(player, arg1, arg2 ~= "" and arg2 or nil)
			dbg(player, "Resultado => " .. tostring(success) .. " | " .. tostring(response))
		elseif cmd == "!puthere" then
			local success, response = putTowerHere(player, arg1)
			dbg(player, "Resultado => " .. tostring(success) .. " | " .. tostring(response))
		elseif cmd == "!dumptowerids" then
			dumpTowerCatalog(player)
		elseif cmd == "!dumpunits" then
			dumpOwnedTowers(player)
		elseif cmd == "!endmatch" then
			local success, response = endMatch(player, arg1)
			dbg(player, "Resultado => " .. tostring(success) .. " | " .. tostring(response))
		end
	end)
end)