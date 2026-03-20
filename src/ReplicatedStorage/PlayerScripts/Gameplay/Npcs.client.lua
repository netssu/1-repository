------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local NPCS_FOLDER_NAME: string = "Npcs"
local MAX_LOOK_DISTANCE: number = 20
local MAX_LOOK_ANGLE: number = 70
local HEAD_SMOOTH_SPEED: number = 0.1

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local npcsFolder: Instance = workspace:WaitForChild(NPCS_FOLDER_NAME)

local promptConnections: {[ProximityPrompt]: RBXScriptConnection} = {}
local cleanupConnections: {[ProximityPrompt]: RBXScriptConnection} = {}

local activeNpcs: {[Model]: any} = {}

local openedGui: ScreenGui?
local openedFrame: Frame?

local HudManager: {} = require(ReplicatedStorage.Modules.Game.HudManager)

------------------//PROMPT ACTIONS
local PROMPT_ACTIONS: {[string]: () -> ()} = {
	["Shop"] = function(): ()
		HudManager.call("open_pogos_hud")
	end,
	
	["RebirthShop"] = function(): () 
		player.PlayerGui.UI.RebirthShop.Visible = true
		
	end,
}

------------------//FUNCTIONS
local function get_first_frame(screenGui: ScreenGui): Frame?
	local children = screenGui:GetChildren()
	for _, child: Instance in children do
		if child:IsA("Frame") then return child end
	end
	for _, inst: Instance in screenGui:GetDescendants() do
		if inst:IsA("Frame") then return inst end
	end
	return nil
end

local function resolve_screen_gui_for_prompt(prompt: ProximityPrompt): ScreenGui?
	local byPromptName = playerGui:FindFirstChild(prompt.Name)
	if byPromptName and byPromptName:IsA("ScreenGui") then return byPromptName end

	local parent = prompt.Parent
	if parent then
		local byParentName = playerGui:FindFirstChild(parent.Name)
		if byParentName and byParentName:IsA("ScreenGui") then return byParentName end
	end
	return nil
end

local function close_current_hud(): ()
	if openedFrame then
		openedFrame.Visible = false
		openedFrame = nil
	end
	if openedGui then
		openedGui.Enabled = false
		openedGui = nil
	end
end

local function open_hud(screenGui: ScreenGui, frame: Frame?): ()
	openedGui = screenGui
	openedFrame = frame
	screenGui.Enabled = true
	if frame then frame.Visible = true end
end

local function toggle_prompt_gui(prompt: ProximityPrompt): ()
	local action = PROMPT_ACTIONS[prompt.Name]
	if action then
		action()
		return
	end

	local screenGui = resolve_screen_gui_for_prompt(prompt)
	if not screenGui then
		warn(("ScreenGui não encontrado para prompt: %s"):format(prompt.Name))
		return
	end

	if openedGui == screenGui then
		close_current_hud()
		return
	end

	if openedGui then close_current_hud() end

	local frame = get_first_frame(screenGui)
	if not frame then
		warn(("Nenhum Frame encontrado dentro de: %s"):format(screenGui.Name))
	end
	open_hud(screenGui, frame)
end

local function unbind_prompt(prompt: ProximityPrompt): ()
	local conn = promptConnections[prompt]
	if conn then conn:Disconnect(); promptConnections[prompt] = nil end
	local cleanup = cleanupConnections[prompt]
	if cleanup then cleanup:Disconnect(); cleanupConnections[prompt] = nil end
end

local function bind_prompt(prompt: ProximityPrompt): ()
	if promptConnections[prompt] then return end

	promptConnections[prompt] = prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer ~= player then return end
		toggle_prompt_gui(prompt)
	end)

	cleanupConnections[prompt] = prompt.Destroying:Connect(function()
		unbind_prompt(prompt)
	end)
end

local function setup_npc(npcModel: Model)
	if activeNpcs[npcModel] then return end

	local humanoid = npcModel:WaitForChild("Humanoid", 5) :: Humanoid
	local rootPart = npcModel:WaitForChild("HumanoidRootPart", 5) :: BasePart
	if not humanoid or not rootPart then return end

	local animation = npcModel:FindFirstChildWhichIsA("Animation")
	if animation then
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play()
	end

	local neck = nil
	local head = npcModel:FindFirstChild("Head")

	if head then neck = head:FindFirstChild("Neck") end
	if not neck then
		local upperTorso = npcModel:FindFirstChild("UpperTorso")
		if upperTorso then neck = upperTorso:FindFirstChild("Neck") end
	end
	if not neck then
		local torso = npcModel:FindFirstChild("Torso")
		if torso then neck = torso:FindFirstChild("Neck") end
	end

	if neck and neck:IsA("Motor6D") then
		activeNpcs[npcModel] = {
			Root = rootPart,
			Neck = neck,
			Head = head,
			OriginalC0 = neck.C0
		}
	end
end

------------------//UPDATE LOOP
RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local playerHead = char:FindFirstChild("Head")
	if not playerHead then return end

	for model, data in pairs(activeNpcs) do
		if not model.Parent then
			activeNpcs[model] = nil
			continue
		end

		local root = data.Root
		local neck = data.Neck
		local originalC0 = data.OriginalC0

		local dist = (playerHead.Position - root.Position).Magnitude

		if dist <= MAX_LOOK_DISTANCE then
			local lookVector = root.CFrame:PointToObjectSpace(playerHead.Position)

			local yaw = math.atan2(lookVector.X, -lookVector.Z)
			local pitch = math.asin(lookVector.Y / lookVector.Magnitude)

			local maxAngleRad = math.rad(MAX_LOOK_ANGLE)
			yaw = math.clamp(yaw, -maxAngleRad, maxAngleRad)
			pitch = math.clamp(pitch, -maxAngleRad, maxAngleRad)

			local rotation = CFrame.Angles(0, -yaw, 0) * CFrame.Angles(pitch, 0, 0)
			local targetCFrame = CFrame.new(originalC0.Position) * rotation * (originalC0 - originalC0.Position)

			neck.C0 = neck.C0:Lerp(targetCFrame, HEAD_SMOOTH_SPEED)
		else
			neck.C0 = neck.C0:Lerp(originalC0, HEAD_SMOOTH_SPEED)
		end
	end
end)

------------------//MAIN FUNCTIONS
local function scan_and_bind_prompts(): ()
	local descendants = npcsFolder:GetDescendants()
	for _, inst: Instance in descendants do
		if inst:IsA("ProximityPrompt") then
			bind_prompt(inst)
		end
	end

	for _, child in npcsFolder:GetChildren() do
		if child:IsA("Model") then
			task.spawn(function() setup_npc(child) end)
		end
	end
end

local function on_descendant_added(inst: Instance): ()
	if inst:IsA("ProximityPrompt") then
		bind_prompt(inst)
	end
end

local function on_child_added(child: Instance)
	if child:IsA("Model") then
		task.spawn(function() setup_npc(child) end)
	end
end

------------------//INIT
scan_and_bind_prompts()
npcsFolder.DescendantAdded:Connect(on_descendant_added)
npcsFolder.ChildAdded:Connect(on_child_added)
