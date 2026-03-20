------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------//CONSTANTS
local RINGS_FOLDER = workspace:WaitForChild("Rings")
local REQUIRED_FALL_VELOCITY_Y = -1
local LABEL_SIZE = UDim2.new(4, 0, 1.5, 0)
local LABEL_TEXT_SIZE = 28

------------------//VARIABLES
local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local ringEvent = remotesFolder:WaitForChild("RingEvent")
local localCollected = {}

------------------//FUNCTIONS

local function get_ring_percentage(ring: Instance): number
	local value = tonumber(ring.Name)
	if value then
		return value * 10
	end
	return 0
end

local function setup_hitbox(ring: BasePart): ()
	local hitbox = ring:FindFirstChild("HitBox") or ring:FindFirstChild("hitbox")
	if not hitbox or not hitbox:IsA("BasePart") then
		return
	end

	hitbox.CFrame = ring.CFrame
	hitbox.Transparency = 0
	hitbox.Anchored = false
	hitbox.CanCollide = false

	local existing = hitbox:FindFirstChildOfClass("WeldConstraint")
	if not existing then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = ring
		weld.Parent = hitbox
	end
end

local function create_ring_label(ring: BasePart): ()
	local percentage = get_ring_percentage(ring)
	if percentage <= 0 then
		return
	end

	if ring:FindFirstChild("RingLabel") then
		return
	end

	local hitbox = ring:FindFirstChild("HitBox") or ring:FindFirstChild("hitbox") or ring
	if not hitbox:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RingLabel"
	billboard.Size = LABEL_SIZE
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Adornee = hitbox
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Parent = ring

	local label = Instance.new("TextLabel")
	label.Name = "PercentText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = ring.Color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextSize = LABEL_TEXT_SIZE
	label.TextScaled = false
	label.Text = "+" .. tostring(percentage) .. "%"
	label.Parent = billboard
end

local function setup_all_labels(): ()
	for _, ring in RINGS_FOLDER:GetChildren() do
		if ring:IsA("BasePart") then
			setup_hitbox(ring)
			create_ring_label(ring)
		end
	end
end

local function can_collect(): boolean
	local pogoState = localPlayer:GetAttribute("PogoState")
	if pogoState == "Idle" or pogoState == "Stunned" then
		return false
	end
	local character = localPlayer.Character
	if not character then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end
	if rootPart.AssemblyLinearVelocity.Y >= REQUIRED_FALL_VELOCITY_Y then
		--return false
	end
	return true
end

local function is_inside_box(playerPos: Vector3, boxPart: BasePart): boolean
	local relative = boxPart.CFrame:PointToObjectSpace(playerPos)
	local halfSize = boxPart.Size * 0.5
	return math.abs(relative.X) <= halfSize.X
		and math.abs(relative.Y) <= halfSize.Y
		and math.abs(relative.Z) <= halfSize.Z
end

local function check_rings()
	local character = localPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if not can_collect() then return end
	local playerPos = rootPart.Position
	for _, ring in RINGS_FOLDER:GetChildren() do
		if localCollected[ring] then continue end
		if not ring:IsA("BasePart") then continue end
		local hitbox = ring:FindFirstChild("HitBox") or ring:FindFirstChild("hitbox") or ring
		if not hitbox:IsA("BasePart") then continue end
		if is_inside_box(playerPos, hitbox) then
			localCollected[ring] = true
			ringEvent:FireServer("RequestCollect", ring)
		end
	end
end

------------------//INIT
setup_all_labels()

RINGS_FOLDER.ChildAdded:Connect(function(child: Instance)
	task.defer(function()
		if child:IsA("BasePart") then
			setup_hitbox(child)
			create_ring_label(child)
		end
	end)
end)

RunService.Heartbeat:Connect(check_rings)

ringEvent.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any, arg3: any)
	if action == "Restore" then
		table.clear(localCollected)
	elseif action == "Collect" then
		if localPlayer:GetAttribute("Tutorial") == true then
			local currentRings = localPlayer:GetAttribute("RingsCollected") or 0
			localPlayer:SetAttribute("RingsCollected", currentRings + 1)
		end
	end
end)
