------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local VEHICLES_FOLDER_NAME: string = "Vehicles"
local RACING_HUD_NAME: string = "RacingHud"
local CANVAS_NAME: string = "Canvas"
local CONTROL_SCHEMA_NAME: string = "ControlSchema"
local PC_PANEL_NAME: string = "PC"
local GAMEPAD_PANEL_NAME: string = "Gamepad"
local BIND_TEMPLATE_NAME: string = "BindTemplate"
local UPDATE_INTERVAL_SECONDS: number = 0.25

local PC_BINDINGS: { { label: string, key: string } } = {
	{ label = "Throttle", key = "W" },
	{ label = "Brake", key = "S" },
	{ label = "Steer Left", key = "A" },
	{ label = "Steer Right", key = "D" },
	{ label = "Camera", key = "C" },
	{ label = "Rear Camera", key = "X" },
	{ label = "Lap Times", key = "TAB / F1" },
	{ label = "Activate Attack Mode", key = "E" },
	{ label = "Return", key = "HOLD SPACE" },
}

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local updateAccumulator: number = 0
local currentVehicle: Model?
local controlSchema: Frame?
local pcPanel: Frame?
local gamepadPanel: Frame?

------------------//FUNCTIONS
local function get_owned_vehicle(): Model?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then
		return nil
	end

	local vehicle = seat:FindFirstAncestorOfClass("Model")
	local fesystem = workspace:FindFirstChild(FESYSTEM_FOLDER_NAME)
	local vehiclesFolder = fesystem and fesystem:FindFirstChild(VEHICLES_FOLDER_NAME)
	if vehicle and vehiclesFolder and vehicle.Parent == vehiclesFolder and vehicle:GetAttribute("OwnerUserId") == localPlayer.UserId then
		return vehicle
	end
	return nil
end

local function find_control_schema(): (Frame?, Frame?, Frame?)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local racingHud = playerGui and playerGui:FindFirstChild(RACING_HUD_NAME)
	local canvas = racingHud and racingHud:FindFirstChild(CANVAS_NAME)
	local schema = canvas and canvas:FindFirstChild(CONTROL_SCHEMA_NAME)
	local pc = schema and schema:FindFirstChild(PC_PANEL_NAME)
	local gamepad = schema and schema:FindFirstChild(GAMEPAD_PANEL_NAME)

	if not schema or not schema:IsA("Frame") then
		return nil, nil, nil
	end

	return schema, if pc and pc:IsA("Frame") then pc else nil, if gamepad and gamepad:IsA("Frame") then gamepad else nil
end

local function get_bind_rows(panel: Frame): { Frame }
	local rows: { Frame } = {}
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") and child.Name == BIND_TEMPLATE_NAME then
			table.insert(rows, child)
		end
	end

	table.sort(rows, function(left: Frame, right: Frame): boolean
		return left.LayoutOrder < right.LayoutOrder
	end)
	return rows
end

local function update_pc_bindings(panel: Frame): ()
	local rows = get_bind_rows(panel)
	for index, binding in PC_BINDINGS do
		local row = rows[index]
		local label = row and row:FindFirstChild("Bind")
		if label and label:IsA("TextLabel") then
			label.RichText = true
			label.Text = ("%s <font color=\"#3b82f6\">[%s]</font>"):format(binding.label, binding.key)
		end
		if row then
			row.LayoutOrder = index
		end
	end
end

local function update_panel_mode(): ()
	if not controlSchema or not pcPanel or not gamepadPanel then
		return
	end

	local useGamepad = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
	controlSchema.Visible = currentVehicle ~= nil
	pcPanel.Visible = currentVehicle ~= nil and not useGamepad
	gamepadPanel.Visible = currentVehicle ~= nil and useGamepad
end

local function show_controls(vehicle: Model): ()
	if currentVehicle == vehicle and controlSchema then
		update_panel_mode()
		return
	end

	currentVehicle = vehicle
	controlSchema, pcPanel, gamepadPanel = find_control_schema()
	if pcPanel then
		update_pc_bindings(pcPanel)
	end
	update_panel_mode()
end

local function hide_controls(): ()
	currentVehicle = nil
	if controlSchema then
		controlSchema.Visible = false
	end
	if pcPanel then
		pcPanel.Visible = false
	end
	if gamepadPanel then
		gamepadPanel.Visible = false
	end
end

local function update_controls(deltaTime: number): ()
	updateAccumulator += deltaTime
	if updateAccumulator < UPDATE_INTERVAL_SECONDS then
		return
	end
	updateAccumulator = 0

	local vehicle = get_owned_vehicle()
	if vehicle then
		show_controls(vehicle)
	else
		hide_controls()
	end
end

------------------//INIT
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(update_panel_mode)
RunService.Heartbeat:Connect(update_controls)
