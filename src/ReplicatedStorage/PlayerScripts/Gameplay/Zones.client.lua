------------------//SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

------------------//CONSTANTS
local ZONE_REBIRTH: string = "ZoneRebirth"
local ZONE_POGO: string = "ZonePogo"
local CHECK_HEIGHT: number = 5

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local vendorFrameRebirth: Frame = nil
local vendorFrame: Frame = nil

task.spawn(function()
	local gui = playerGui:WaitForChild("GUI", 10)
	if gui then
		vendorFrame = gui:WaitForChild("VendorFrame", 10)
		vendorFrameRebirth = gui:WaitForChild("VendorFrameRebirth", 10)
	else
		warn("[Zones] GUI não encontrado")
	end
end)

local zonesFolder: Folder = workspace:WaitForChild("Zones")
local cachedZoneParts: {BasePart} = {}
local currentZoneName: string? = nil

------------------//FUNCTIONS
local function updateZoneCache(): ()
	table.clear(cachedZoneParts)
	for _, inst: Instance in ipairs(zonesFolder:GetDescendants()) do
		if inst:IsA("BasePart") and (inst.Name == ZONE_REBIRTH or inst.Name == ZONE_POGO) then
			table.insert(cachedZoneParts, inst)
		end
	end
end

local function isAbovePart(rootPos: Vector3, zonePart: BasePart): boolean
	local localPos = zonePart.CFrame:PointToObjectSpace(rootPos)
	local size = zonePart.Size / 2
	local withinX = math.abs(localPos.X) <= size.X
	local withinZ = math.abs(localPos.Z) <= size.Z
	local aboveY = localPos.Y >= -CHECK_HEIGHT and localPos.Y <= CHECK_HEIGHT + size.Y * 2
	return withinX and withinZ and aboveY
end

local function openZoneUI(zoneName: string): ()
	if zoneName == ZONE_REBIRTH then
		if vendorFrameRebirth then vendorFrameRebirth.Visible = true end
	elseif zoneName == ZONE_POGO then
		if vendorFrame then vendorFrame.Visible = true end
	end
end

local function closeZoneUI(zoneName: string): ()
	if zoneName == ZONE_REBIRTH then
		if vendorFrameRebirth then vendorFrameRebirth.Visible = false end
	elseif zoneName == ZONE_POGO then
		if vendorFrame then vendorFrame.Visible = false end
	end
end

local function checkZones(): ()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local foundZoneName: string? = nil
	for _, zonePart in ipairs(cachedZoneParts) do
		if isAbovePart(rootPart.Position, zonePart) then
			foundZoneName = zonePart.Name
			break
		end
	end

	if foundZoneName ~= currentZoneName then
		if currentZoneName then closeZoneUI(currentZoneName) end
		if foundZoneName then openZoneUI(foundZoneName) end
		currentZoneName = foundZoneName
	end
end

------------------//INIT
updateZoneCache()

zonesFolder.DescendantAdded:Connect(function(inst: Instance)
	if inst:IsA("BasePart") and (inst.Name == ZONE_REBIRTH or inst.Name == ZONE_POGO) then
		table.insert(cachedZoneParts, inst)
	end
end)

RunService.Heartbeat:Connect(checkZones)