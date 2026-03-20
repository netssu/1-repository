------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local ADMIN_ID = 10386863908
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local WORLD_CONFIG = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("WorldConfig"))
local NOTIFICATION_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

local LIGHTING_TRANSITION_TIME = 1

------------------//VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UI = playerGui:WaitForChild("GUI")

local teleportFrame = UI:WaitForChild("TeleportFrame")
local content = teleportFrame:WaitForChild("Content")

local teleportTemplate = content:WaitForChild("TeleportButton")
local unknownTemplate = content:WaitForChild("UnknownHolder")

local teleportRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("TeleportRemote")

local maxUnlockedWorldId = 1
local lastUnlockedWorldId = nil -- Mudamos para nil para saber quando é a primeira leitura

------------------//LIGHTING FUNCTIONS
local function apply_world_lighting(worldId: number): ()
	local worldFolder = workspace:FindFirstChild(tostring(worldId))
	if not worldFolder then
		warn("[Lighting] World folder not found:", worldId)
		return
	end

	local lightingSets = worldFolder:FindFirstChild("Lighting Sets")
	if lightingSets then
		local preset = lightingSets:FindFirstChild("LightingPreset")
		if preset then
			for _, child in ipairs(preset:GetChildren()) do
				local existing = Lighting:FindFirstChild(child.Name)
				if existing then
					existing:Destroy()
				end

				local clone = child:Clone()
				clone.Parent = Lighting
			end
		end
	end

	local stylizedConfig = lightingSets and lightingSets:FindFirstChild("Stylized")
	if not stylizedConfig then
		stylizedConfig = worldFolder:FindFirstChild("Stylized", true)
	end

	if stylizedConfig then
		local attributes = stylizedConfig:GetAttributes()
		local tweenableProps = {}

		for attrName, attrValue in pairs(attributes) do
			local success = pcall(function()
				local currentVal = (Lighting :: any)[attrName]
				if currentVal ~= nil then
					local valType = typeof(attrValue)
					if valType == "number" or valType == "Color3" then
						tweenableProps[attrName] = attrValue
					else
						(Lighting :: any)[attrName] = attrValue
					end
				end
			end)
		end

		if next(tweenableProps) then
			local tweenInfo = TweenInfo.new(LIGHTING_TRANSITION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			local tween = TweenService:Create(Lighting, tweenInfo, tweenableProps)
			tween:Play()
		end
	end
end

------------------//FUNCTIONS
local function refresh_unlock_state(isFirstLoad: boolean): ()
	maxUnlockedWorldId = DATA_UTILITY.client.get("MaxWorldUnlocked") or 1

	-- Se for o primeiro load, apenas salva o valor e não faz mais nada.
	if isFirstLoad or lastUnlockedWorldId == nil then
		lastUnlockedWorldId = maxUnlockedWorldId
		return
	end

	-- Agora sim, se for um update real do banco durante o jogo:
	if maxUnlockedWorldId > lastUnlockedWorldId then
		local wData = WORLD_CONFIG.GetWorld(maxUnlockedWorldId)
		if wData then
			NOTIFICATION_UTILITY:Success("New World Unlocked: " .. tostring(wData.name) .. "!", 5)
		end
		lastUnlockedWorldId = maxUnlockedWorldId
	end
end

local function is_world_unlocked(worldId: number): boolean
	if player.UserId == ADMIN_ID then return true end
	return worldId <= maxUnlockedWorldId
end

local function set_button_data(btn: Frame, worldData: any)
	local planetName = btn:FindFirstChild("PlanetName", true)
	local iconImage = btn:FindFirstChild("Icon", true)

	if planetName and planetName:IsA("TextLabel") then
		planetName.Text = worldData.name
	end

	if iconImage and iconImage:IsA("ImageLabel") then
		iconImage.Image = worldData.imageId or ""
	end
end

local function load_teleport_menu(): ()
	for _, child in pairs(content:GetChildren()) do
		if child:IsA("GuiObject") and child ~= teleportTemplate and child ~= unknownTemplate then
			child:Destroy()
		end
	end

	for _, worldData in ipairs(WORLD_CONFIG.WORLDS) do
		local worldId = worldData.id

		if is_world_unlocked(worldId) then
			local btnClone = teleportTemplate:Clone()
			btnClone.Name = "World_" .. worldId

			set_button_data(btnClone, worldData)

			btnClone.Visible = true
			btnClone.Parent = content

			btnClone.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					teleportRemote:FireServer(worldId)
				end
			end)
		else
			local unkClone = unknownTemplate:Clone()
			unkClone.Name = "Unknown_" .. worldId

			local planetName = unkClone:FindFirstChild("PlanetName", true)
			if planetName and planetName:IsA("TextLabel") then
				planetName.Text = "???"
			end

			unkClone.Visible = true
			unkClone.Parent = content
		end
	end

	teleportTemplate.Visible = false
	unknownTemplate.Visible = false
end

------------------//INIT
DATA_UTILITY.client.ensure_remotes()

-- Primeiro load silencioso (não aciona notificação)
refresh_unlock_state(true)

-- Bind para mudanças no decorrer da partida
DATA_UTILITY.client.bind("MaxWorldUnlocked", function(val)
	refresh_unlock_state(false)
	load_teleport_menu()
end)

DATA_UTILITY.client.bind("CurrentWorld", function(newWorldId)
	task.delay(0.3, function()
		refresh_unlock_state(false)
		load_teleport_menu()

		local worldId = newWorldId or DATA_UTILITY.client.get("CurrentWorld") or 1
		apply_world_lighting(worldId)
	end)
end)

task.spawn(function()
	task.wait(1)
	refresh_unlock_state(true)
	load_teleport_menu()

	local initialWorld = DATA_UTILITY.client.get("CurrentWorld") or 1
	apply_world_lighting(initialWorld)
end)
