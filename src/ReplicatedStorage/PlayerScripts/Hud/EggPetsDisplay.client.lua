------------------// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

------------------// CONSTANTS
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RANGE = 25
local TWEEN_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local FolderEgg = Workspace:WaitForChild("FolderEgg")
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas")

local DataEggs = require(ModulesFolder:WaitForChild("EggData"))
local DataPets = require(ModulesFolder:WaitForChild("PetsData"))
local DataRaritys = require(ModulesFolder:WaitForChild("RaritysData"))

-- ATENÇÃO: Verifique se o caminho do DataUtility abaixo está correto na sua estrutura!
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility")) 

------------------// VARIABLES
local activeGuis = {}

------------------// FUNCTIONS
-- Função flexível para ler o inventário do jogador usando seu DataUtility
local function checkIfPetIsOwned(petName, currentOwnedPets)
	-- Se não passar a tabela atual, busca no cache do DataUtility
	local ownedPets = currentOwnedPets or DataUtility.client.get("OwnedPets")
	if type(ownedPets) ~= "table" then return false end

	-- Varre a tabela para procurar o pet, independente de como ela for salva (Array ou Dicionário)
	for key, value in pairs(ownedPets) do
		if type(value) == "table" and value.Name == petName then
			return true
		elseif type(value) == "string" and value == petName then
			return true
		elseif type(key) == "string" and key == petName and value == true then
			return true
		end
	end

	return false
end

-- Função central para aplicar/remover silhueta (suporta 2D e 3D)
local function UpdateSilhouette(viewportData, isOwned)
	if not viewportData then return end

	if viewportData:IsA("ImageLabel") or viewportData:IsA("ImageButton") then
		viewportData.ImageColor3 = isOwned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)

	elseif viewportData:IsA("ViewportFrame") then
		if isOwned then
			viewportData.ImageColor3 = Color3.fromRGB(255, 255, 255)
			viewportData.Ambient = viewportData:GetAttribute("OrigAmbient") or Color3.fromRGB(200, 200, 200)
			viewportData.LightColor = viewportData:GetAttribute("OrigLightColor") or Color3.fromRGB(255, 255, 255)
		else
			-- Salva iluminação original antes de escurecer
			if not viewportData:GetAttribute("OrigAmbient") then
				viewportData:SetAttribute("OrigAmbient", viewportData.Ambient)
				viewportData:SetAttribute("OrigLightColor", viewportData.LightColor)
			end
			viewportData.ImageColor3 = Color3.fromRGB(0, 0, 0)
			viewportData.Ambient = Color3.fromRGB(0, 0, 0)
			viewportData.LightColor = Color3.fromRGB(0, 0, 0)
		end

		for _, desc in pairs(viewportData:GetDescendants()) do
			if desc:IsA("BasePart") then
				-- Salva cor e material original como atributo
				if not desc:GetAttribute("OrigColor") then
					desc:SetAttribute("OrigColor", desc.Color)
					desc:SetAttribute("OrigMaterial", desc.Material.Name)
				end

				if isOwned then
					desc.Color = desc:GetAttribute("OrigColor")
					desc.Material = Enum.Material[desc:GetAttribute("OrigMaterial")]
				else
					desc.Color = Color3.fromRGB(0, 0, 0)
					desc.Material = Enum.Material.SmoothPlastic
				end
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				if not desc:GetAttribute("OrigTransp") then
					desc:SetAttribute("OrigTransp", desc.Transparency)
				end
				desc.Transparency = isOwned and desc:GetAttribute("OrigTransp") or 1
			end
		end
	end
end

local function WaitForPetsGui(eggModel)
	local timeout = 10
	local timeWaited = 0

	while timeWaited < timeout do
		for _, descendant in ipairs(eggModel:GetDescendants()) do
			if descendant.Name == "PetsGui" and descendant:IsA("BillboardGui") then
				return descendant
			end
		end

		task.wait(0.5)
		timeWaited += 0.5
	end

	return nil
end

local function WaitForEggGui(eggModel)
	local timeout = 10
	local timeWaited = 0

	while timeWaited < timeout do
		for _, descendant in ipairs(eggModel:GetDescendants()) do
			if descendant.Name == "EggGUI" and descendant:IsA("BillboardGui") then
				return descendant
			end
		end

		task.wait(0.5)
		timeWaited += 0.5
	end

	return nil
end

local function FormatNumber(n)
	n = tostring(n)
	return n:reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
end

local function SetScale(frame, scale)
	local uiScale = frame:FindFirstChildWhichIsA("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = frame
	end
	uiScale.Scale = scale
end

local function GetUIScale(frame)
	local uiScale = frame:FindFirstChildWhichIsA("UIScale")
	return uiScale
end

local function AnimateIn(backgroundFrame)
	local uiScale = GetUIScale(backgroundFrame)
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 0
		uiScale.Parent = backgroundFrame
	end

	uiScale.Scale = 0
	backgroundFrame.Visible = true

	TweenService:Create(uiScale, TWEEN_IN, { Scale = 1 }):Play()
end

local function AnimateOut(backgroundFrame, callback)
	local uiScale = GetUIScale(backgroundFrame)
	if not uiScale then
		if callback then callback() end
		return
	end

	local tween = TweenService:Create(uiScale, TWEEN_OUT, { Scale = 0 })
	tween:Play()
	tween.Completed:Connect(function()
		backgroundFrame.Visible = false
		if callback then callback() end
	end)
end

local function SetupEggBillboard(eggModel)
	local eggData = DataEggs[eggModel.Name]
	if not eggData then return end

	local eggGui = WaitForEggGui(eggModel)
	if eggGui then
		local nameLabel = eggGui:FindFirstChild("NameLabel")
		local priceLabel = eggGui:FindFirstChild("PriceLabel")

		if nameLabel then
			nameLabel.Text = eggModel.Name
		end

		if priceLabel then
			local formattedPrice = FormatNumber(eggData.Price)

			if eggData.Currency == "Coins" then
				priceLabel.Text = "$" .. formattedPrice
			elseif eggData.Currency == "RebirthTokens" then
				priceLabel.Text = formattedPrice .. " RB"
			else
				priceLabel.Text = formattedPrice
			end
		end
	end

	local originalPetsGui = WaitForPetsGui(eggModel)
	if not originalPetsGui then return end

	local guiName = "PetsGui_" .. eggModel.Name
	local petsGui = PlayerGui:FindFirstChild(guiName)

	if not petsGui then
		petsGui = originalPetsGui:Clone()
		petsGui.Name = guiName
		petsGui.Adornee = originalPetsGui.Parent
		petsGui.ResetOnSpawn = false
		petsGui.Enabled = true
		petsGui.Parent = PlayerGui

		originalPetsGui.Enabled = false
	else
		petsGui.Enabled = true
	end

	local backgroundFrame = petsGui:WaitForChild("BackgroundFrame", 5)
	if not backgroundFrame then return end

	local petsContainer = backgroundFrame:WaitForChild("PetsContainer", 5)
	if not petsContainer then return end

	local petTemplate = petsContainer:WaitForChild("PetTemplate", 5)
	if not petTemplate then return end

	for _, child in ipairs(petsContainer:GetChildren()) do
		if child:IsA("Frame") and child ~= petTemplate then
			child:Destroy()
		end
	end

	petTemplate.Visible = false

	local totalWeight = 0
	local sortedPets = {}

	for petName, weight in pairs(eggData.Weights) do
		totalWeight += weight
		table.insert(sortedPets, {
			Name = petName,
			Weight = weight
		})
	end

	table.sort(sortedPets, function(a, b)
		return a.Weight > b.Weight
	end)

	for index, petInfo in ipairs(sortedPets) do
		local petName = petInfo.Name
		local weight = petInfo.Weight

		local clone = petTemplate:Clone()
		clone.Name = petName
		clone.Visible = true
		clone.LayoutOrder = index

		local chance = (weight / totalWeight) * 100
		local chanceString = string.format("%.2f", chance):gsub("%.", ",")

		if clone:FindFirstChild("TextPet") then
			clone.TextPet.Text = chanceString .. "%"

			local t = math.clamp(chance / 100, 0, 1)
			local r, g

			if t >= 0.5 then
				local f = (t - 0.5) * 2
				r = math.floor((1 - f) * 255)
				g = 255
			else
				local f = t * 2
				r = 255
				g = math.floor(f * 255)
			end

			clone.TextPet.TextColor3 = Color3.fromRGB(r, g, 0)
		end

		local imagePetContainer = clone:FindFirstChild("ImagePet")
		if imagePetContainer then
			imagePetContainer:ClearAllChildren()

			local viewportData = DataPets.GetPetViewport(petName)
			if viewportData then
				viewportData.Size = UDim2.new(1.3, 0, 1.3, 0)
				viewportData.Position = UDim2.new(0.5, 0, 0.5, 0)
				viewportData.AnchorPoint = Vector2.new(0.5, 0.5)
				viewportData.BackgroundTransparency = 1
				viewportData.Parent = imagePetContainer

				-- Aplica a silhueta ou cor normal no primeiro carregamento
				local isOwned = checkIfPetIsOwned(petName)
				UpdateSilhouette(viewportData, isOwned)
			end
		end

		local petDataInfo = DataPets.GetPetData(petName)

		if petDataInfo then
			local baseRarity = string.gsub(petDataInfo.Raritys, "Golden ", "")

			if baseRarity == "Common" or baseRarity == "Comum" then
				clone.Size = UDim2.new(
					petTemplate.Size.X.Scale * 0.85, 0,
					petTemplate.Size.Y.Scale * 0.85, 0
				)
			end

			if imagePetContainer then
				local background = clone:FindFirstChild("Background")
				if background then
					local rarityConfig = DataRaritys[baseRarity]
					if rarityConfig then
						background.ImageColor3 = rarityConfig.Color
					end
				end
			end
		end

		clone.Parent = petsContainer
	end

	-- EVENTO DE ATUALIZAÇÃO EM TEMPO REAL --
	-- Fica observando o perfil do jogador. Quando 'OwnedPets' atualizar, ele verifica as silhuetas de novo!
	local dataConnection = DataUtility.client.bind("OwnedPets", function(newOwnedPets)
		for _, petInfo in ipairs(sortedPets) do
			local petName = petInfo.Name
			local clone = petsContainer:FindFirstChild(petName)

			if clone then
				local imagePetContainer = clone:FindFirstChild("ImagePet")
				if imagePetContainer then
					local viewportData = imagePetContainer:FindFirstChildWhichIsA("GuiObject")

					-- Checa se ele está na nova tabela e atualiza a cor
					local isOwned = checkIfPetIsOwned(petName, newOwnedPets)
					UpdateSilhouette(viewportData, isOwned)
				end
			end
		end
	end)

	-- Desconecta o evento caso o ovo/painel seja destruído para evitar lag
	eggModel.Destroying:Connect(function()
		if petsGui then petsGui:Destroy() end
		if dataConnection then dataConnection:Disconnect() end
	end)

	SetScale(backgroundFrame, 0)
	backgroundFrame.Visible = false

	activeGuis[petsGui] = {
		backgroundFrame = backgroundFrame,
		adornee = petsGui.Adornee,
		isVisible = false,
	}
end

------------------// INIT
for _, child in ipairs(FolderEgg:GetChildren()) do
	if child:IsA("Model") then
		task.spawn(function()
			SetupEggBillboard(child)
		end)
	end
end

FolderEgg.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.spawn(function()
			SetupEggBillboard(child)
		end)
	end
end)

RunService.Heartbeat:Connect(function()
	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then return end

	local cameraPos = currentCamera.CFrame.Position

	for petsGui, data in pairs(activeGuis) do
		if not petsGui or not petsGui.Parent then
			activeGuis[petsGui] = nil
			continue
		end

		local adornee = data.adornee
		if not adornee or not adornee.Parent then
			activeGuis[petsGui] = nil
			continue
		end

		local adorneePart = adornee:IsA("BasePart") and adornee or adornee:FindFirstChildWhichIsA("BasePart")
		if not adorneePart then continue end

		local dist = (cameraPos - adorneePart.Position).Magnitude
		local shouldShow = dist <= RANGE

		if shouldShow and not data.isVisible then
			data.isVisible = true
			AnimateIn(data.backgroundFrame)
		elseif not shouldShow and data.isVisible then
			data.isVisible = false
			AnimateOut(data.backgroundFrame)
		end
	end
end)