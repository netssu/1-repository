------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ADMIN_ID = 10386863908
local DATA_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local WORLD_CONFIG = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("WorldConfig"))
local NOTIFICATION_UTILITY = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

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
local lastUnlockedWorldId = 1

------------------//FUNCTIONS
local function refresh_unlock_state(): ()
	maxUnlockedWorldId = DATA_UTILITY.client.get("MaxWorldUnlocked") or 1

	if maxUnlockedWorldId > lastUnlockedWorldId then
		local wData = WORLD_CONFIG.GetWorld(maxUnlockedWorldId)
		if wData then
		--	NOTIFICATION_UTILITY:Success("New World Unlocked: " .. tostring(wData.name) .. "!", 5)
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

refresh_unlock_state()

DATA_UTILITY.client.bind("MaxWorldUnlocked", function(val)
	refresh_unlock_state()
	load_teleport_menu()
end)

DATA_UTILITY.client.bind("CurrentWorld", function()
	task.delay(0.3, function()
		refresh_unlock_state()
		load_teleport_menu()
	end)
end)

task.spawn(function()
	task.wait(1)
	refresh_unlock_state()
	load_teleport_menu()
end)
