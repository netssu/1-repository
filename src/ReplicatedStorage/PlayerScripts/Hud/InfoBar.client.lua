------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local RENDER_STEP_NAME: string = "WorldHeightBar"
local SMOOTH_SPEED: number = 18
local HEIGHT_SENTINEL: number = 90000
local LIMITS_TIMEOUT: number = 15

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)

local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local barGui: ScreenGui = playerGui:WaitForChild("BAR") :: any
local barFrame: Frame = barGui:WaitForChild("Bar") :: any
local barInner: Frame = barFrame:WaitForChild("bar") :: any

local playerMarker: Frame = barInner:WaitForChild("Position") :: any

local backgroundOriginal: ImageLabel = (barInner:FindFirstChild("background") or barInner:FindFirstChild("Background")) :: any
local iconOriginal: ImageLabel = (backgroundOriginal and (backgroundOriginal:FindFirstChild("icon") or backgroundOriginal:FindFirstChild("Icon"))) :: any

local backgroundTemplate: ImageLabel? = nil
if backgroundOriginal and iconOriginal then
	backgroundTemplate = backgroundOriginal:Clone()
	backgroundTemplate.Parent = nil
end

local markersFolder: Folder = barInner:FindFirstChild("LayerMarkers") :: Folder
if not markersFolder then
	markersFolder = Instance.new("Folder")
	markersFolder.Name = "LayerMarkers"
	markersFolder.Parent = barInner
end

local character: Model? = nil
local rootPart: BasePart? = nil

local currentWorldId: number = 1
local worldMinHeight: number = 0
local worldMaxHeight: number = 1000
local smoothPct: number = 0

local markerCache: {[number]: {gui: ImageLabel, pct: number}} = {}

------------------//FUNCTIONS
local function exp_lerp(a: number, b: number, speed: number, dt: number): number
	local alpha = 1 - math.exp(-speed * dt)
	return a + (b - a) * alpha
end

local function bind_character(newCharacter: Model): ()
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
end

local function get_layer_height_y(layerData: any): number?
	if layerData and typeof(layerData.entryCFrame) == "CFrame" then
		return layerData.entryCFrame.Position.Y
	end
	if layerData and typeof(layerData.minHeight) == "number" then
		return layerData.minHeight
	end
	return nil
end

local function wait_for_limit_part(worldId: number, partName: string): BasePart?
	local limitsFolder: Folder? = nil
	local elapsed = 0

	repeat
		elapsed += task.wait(0.1)
		limitsFolder = workspace:FindFirstChild("Limits") :: Folder?
	until limitsFolder or elapsed >= LIMITS_TIMEOUT

	if not limitsFolder then
		return nil
	end

	elapsed = 0
	local part: BasePart? = nil

	repeat
		elapsed += task.wait(0.1)
		local found = limitsFolder:FindFirstChild(partName)
		if found and found:IsA("BasePart") then
			part = found :: BasePart
		end
	until part or elapsed >= LIMITS_TIMEOUT

	return part
end

local function compute_world_bounds(worldId: number): (number, number)
	local startName = "MapStart_" .. tostring(worldId)
	local endName = "MapEnd_" .. tostring(worldId)

	local startPart = wait_for_limit_part(worldId, startName)
	local endPart = wait_for_limit_part(worldId, endName)

	if startPart and endPart then
		local minY = math.min(startPart.Position.Y, endPart.Position.Y)
		local maxY = math.max(startPart.Position.Y, endPart.Position.Y)
		return minY, maxY
	end

	return 0, 1000
end

local function clear_layer_markers(): ()
	for _, child in ipairs(markersFolder:GetChildren()) do
		child:Destroy()
	end
	markerCache = {}
end

local function position_gui_at_pct(gui: GuiObject, pct: number, keepX: UDim): ()
	local trackH = barInner.AbsoluteSize.Y
	local guiH = gui.AbsoluteSize.Y
	if trackH <= 0 or guiH <= 0 then return end

	local ay = gui.AnchorPoint.Y
	local y = (1 - pct) * (trackH - guiH) + (guiH * ay)

	gui.Position = UDim2.new(keepX.Scale, keepX.Offset, 0, y)
end

local function rebuild_layer_icons(worldId: number): ()
	clear_layer_markers()

	local w = WorldConfig.GetWorld(worldId)
	if not w or not w.layers then return end
	if not backgroundOriginal or not backgroundTemplate then return end

	local keepX = backgroundOriginal.Position.X
	local totalLayers = #w.layers

	local heightRange = math.max(1, worldMaxHeight - worldMinHeight)

	for layerIdx, layerData in ipairs(w.layers) do
		local pct = 0
		local y = get_layer_height_y(layerData)

		if layerIdx == totalLayers then
			pct = 1
		elseif y then
			pct = math.clamp((y - worldMinHeight) / heightRange, 0, 1)
		end

		local clone: ImageLabel = backgroundTemplate:Clone()
		clone.Name = "LayerIcon_" .. tostring(layerIdx)
		clone.Parent = markersFolder
		clone.Visible = true

		local icon: ImageLabel? = (clone:FindFirstChild("icon") or clone:FindFirstChild("Icon")) :: ImageLabel?
		if icon then
			icon.Image = layerData.imageId or w.imageId or ""
		end

		markerCache[layerIdx] = { gui = clone, pct = pct }
	end

	task.defer(function()
		for _, info in pairs(markerCache) do
			position_gui_at_pct(info.gui, info.pct, keepX)
		end
	end)
end

local function set_world(worldId: number): ()
	currentWorldId = worldId

	-- Fallback imediato via WorldConfig para não travar a UI
	local w = WorldConfig.GetWorld(worldId)
	if w and w.layers and #w.layers > 0 then
		worldMinHeight = get_layer_height_y(w.layers[1]) or 0
		worldMaxHeight = get_layer_height_y(w.layers[#w.layers]) or 1000
	end

	local rp = rootPart
	if rp then
		local heightRange = math.max(1, worldMaxHeight - worldMinHeight)
		smoothPct = math.clamp((rp.Position.Y - worldMinHeight) / heightRange, 0, 1)
	end

	-- Atualiza a barrinha na hora
	rebuild_layer_icons(worldId)

	-- Busca limites físicos do workspace em segundo plano sem travar
	task.spawn(function()
		local realMin, realMax = compute_world_bounds(worldId)
		worldMinHeight, worldMaxHeight = realMin, realMax
		rebuild_layer_icons(worldId)
	end)
end

local function update_player_marker(pct: number): ()
	local trackH = barInner.AbsoluteSize.Y
	local markerH = playerMarker.AbsoluteSize.Y
	if trackH <= 0 or markerH <= 0 then return end

	local ay = playerMarker.AnchorPoint.Y
	local y = (1 - pct) * (trackH - markerH) + (markerH * ay)

	playerMarker.Position = UDim2.new(playerMarker.Position.X.Scale, playerMarker.Position.X.Offset, 0, y)
end

local function update_loop(dt: number): ()
	local rp = rootPart
	if not rp then return end

	local heightRange = math.max(1, worldMaxHeight - worldMinHeight)
	local pct = math.clamp((rp.Position.Y - worldMinHeight) / heightRange, 0, 1)
	smoothPct = exp_lerp(smoothPct, pct, SMOOTH_SPEED, dt)
	update_player_marker(smoothPct)
end

------------------//INIT
DataUtility.client.ensure_remotes()

character = player.Character or player.CharacterAdded:Wait()
bind_character(character)

player.CharacterAdded:Connect(function(newCharacter: Model)
	bind_character(newCharacter)
	set_world(currentWorldId)
end)

barInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if backgroundOriginal then
		local keepX = backgroundOriginal.Position.X
		for _, info in pairs(markerCache) do
			position_gui_at_pct(info.gui, info.pct, keepX)
		end
	end
	update_player_marker(smoothPct)
end)

DataUtility.client.bind("CurrentWorld", function(val: number)
	if typeof(val) ~= "number" then return end
	if currentWorldId == val then return end
	set_world(val)
end)

currentWorldId = DataUtility.client.get("CurrentWorld") or 1
task.spawn(function()
	set_world(currentWorldId)
end)

RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, update_loop)