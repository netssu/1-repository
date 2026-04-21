------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")
local StarterGui: StarterGui = game:GetService("StarterGui")
local ContentProvider: ContentProvider = game:GetService("ContentProvider")

------------------//CONSTANTS
local FADE_TIME: number = 0.45
local ORIGINAL_TRANSPARENCY_ATTRIBUTE: string = "__CutsceneOriginalTransparency"
local DEBUG_LOOP_CUTSCENE: boolean = false
local DEBUG_LOOP_DELAY: number = 0.25

------------------//VARIABLES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules") :: Folder
local VFXHelper = require(modulesFolder:WaitForChild("VFX_Helper"))
local TowerCutsceneConfig = require(ReplicatedStorage:WaitForChild("TowerCutsceneConfig"))

type BlinkSwapSettings = {
	Enabled: boolean?,
	BaseModelName: string,
	FlashModelName: string,
	Duration: number?,
	Interval: number?,
	FlashDuration: number?,
	FlashYOffset: number?,
}

type TowerSettings = {
	SourcePath: string,
	GuiName: string?,
	FallbackDuration: number?,
	CameraHeightOffset: number?,
	CameraContainerName: string?,
	CameraPartName: string?,
	VfxModelName: string?,
	TrackModelName: string?,
	SoundName: string?,
	IgnoredAnimationContainers: {[string]: boolean}?,
	BlinkSwap: BlinkSwapSettings?,
}

type CutsceneCache = {
	Ready: boolean,
	Clones: {Instance},
	Tracks: {AnimationTrack},
	MaxDuration: number,
	CameraRootPart: BasePart?,
	Sound: Sound?,
}

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local cutsceneEvent: RemoteEvent = ReplicatedStorage
	:WaitForChild("Events")
	:WaitForChild("Client")
	:WaitForChild(TowerCutsceneConfig.RemoteEventName) :: RemoteEvent

local running: boolean = false
local cutsceneCaches: {[string]: CutsceneCache} = {}

------------------//FUNCTIONS
local function tween_black(frame: Frame, transparency: number): ()
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{BackgroundTransparency = transparency}
	)

	tween:Play()
	tween.Completed:Wait()
end

local function apply_visibility_to_object(object: Instance, isVisible: boolean): ()
	if object:IsA("BasePart") then
		object.LocalTransparencyModifier = isVisible and 0 or 1
	elseif object:IsA("Decal") or object:IsA("Texture") then
		local savedTransparency = object:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)

		if savedTransparency == nil then
			object:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, object.Transparency)
			savedTransparency = object.Transparency
		end

		object.Transparency = isVisible and savedTransparency or 1
	end
end

local function set_instance_visibility(target: Instance, isVisible: boolean): ()
	apply_visibility_to_object(target, isVisible)

	for _, descendant in target:GetDescendants() do
		apply_visibility_to_object(descendant, isVisible)
	end
end

local function set_character_visibility(character: Model, isVisible: boolean): ()
	set_instance_visibility(character, isVisible)
end

local function resolve_replicated_path(path: string): Instance?
	local current: Instance = ReplicatedStorage

	for _, segment in string.split(path, "/") do
		if segment == "" then
			continue
		end

		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then
			return nil
		end

		current = nextInstance
	end

	return current
end

local function get_animator_for_instance(instance: Instance): Animator?
	local humanoid = instance:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local animationController = instance:FindFirstChildWhichIsA("AnimationController", true)
	if not animationController and instance:IsA("Model") then
		animationController = Instance.new("AnimationController")
		animationController.Name = "AutoAnimationController"
		animationController.Parent = instance
	end

	if animationController then
		local animator = animationController:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animationController
		end
		return animator
	end

	return nil
end

local function position_clone_at_player(clone: Instance, targetCFrame: CFrame): ()
	if clone:IsA("Model") then
		clone:PivotTo(targetCFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = targetCFrame
	end
end

local function get_instance_pivot(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end

	return nil
end

local function offset_instance(instance: Instance, offset: CFrame): ()
	local currentPivot = get_instance_pivot(instance)
	if not currentPivot then
		return
	end

	position_clone_at_player(instance, currentPivot * offset)
end

local function find_by_name_in_clones(clones: {Instance}, targetName: string): Instance?
	for _, clone in clones do
		if clone.Name == targetName then
			return clone
		end

		local found = clone:FindFirstChild(targetName, true)
		if found then
			return found
		end
	end

	return nil
end

local function get_cutscene_vfx_parts(clones: {Instance}, vfxModelName: string): {[string]: BasePart}
	local vfxPartsByName: {[string]: BasePart} = {}
	local vfxContainer = find_by_name_in_clones(clones, vfxModelName)

	if not vfxContainer then
		return vfxPartsByName
	end

	for _, descendant in vfxContainer:GetDescendants() do
		if descendant:IsA("BasePart") then
			vfxPartsByName[descendant.Name] = descendant
		end
	end

	return vfxPartsByName
end

local function connect_vfx_markers(track: AnimationTrack, vfxPartsByName: {[string]: BasePart}): ()
	for markerName, part in vfxPartsByName do
		warn(markerName)
		track:GetMarkerReachedSignal(markerName):Connect(function()
			warn(markerName,"Reached")
			if not part or part.Parent == nil then
				return
			end

			if not part:IsDescendantOf(game) then
				return
			end

			for _ , v in part.Parent:GetChildren() do
				if v.Name == part.Name then
					VFXHelper.EmitAllParticles(v)
					if v.Name:find("And") then
						for _ , b in script:GetChildren() do
							local c = b:Clone()
							c.Parent = game.Lighting
							game.Debris:AddItem(c,0.1)
						end
					end
				end
			end
		end)
	end
end

local function preload_cutscene(towerName: string): ()
	if cutsceneCaches[towerName] and cutsceneCaches[towerName].Ready then
		return
	end

	local settings: TowerSettings? = TowerCutsceneConfig.Towers[towerName]
	if not settings then
		warn(("Nenhuma cutscene configurada para a torre '%s'"):format(towerName))
		return
	end

	local sourceFolder = resolve_replicated_path(settings.SourcePath)
	if not sourceFolder then
		warn(("Pasta da cutscene não encontrada: %s"):format(settings.SourcePath))
		return
	end

	local cache: CutsceneCache = {
		Ready = false,
		Clones = {},
		Tracks = {},
		MaxDuration = 0,
		CameraRootPart = nil,
		Sound = nil,
	}

	local cameraContainerName = settings.CameraContainerName or "Camera"
	local cameraPartName = settings.CameraPartName or "camera"
	local vfxModelName = settings.VfxModelName or "CutSceneVfx"
	local trackModelName = settings.TrackModelName or "2"
	local ignoredContainers = settings.IgnoredAnimationContainers or {}

	for _, child in sourceFolder:GetChildren() do
		local clone = child:Clone()
		clone.Parent = ReplicatedStorage
		table.insert(cache.Clones, clone)
	end

	local cameraContainer = find_by_name_in_clones(cache.Clones, cameraContainerName)
	if cameraContainer then
		if cameraContainer:IsA("BasePart") and cameraContainer.Name == cameraPartName then
			cache.CameraRootPart = cameraContainer
		else
			local foundCameraPart = cameraContainer:FindFirstChild(cameraPartName, true)
			if foundCameraPart and foundCameraPart:IsA("BasePart") then
				cache.CameraRootPart = foundCameraPart
			end
		end
	end

	local foundSound = find_by_name_in_clones(cache.Clones, settings.SoundName or "Sound")
	if foundSound and foundSound:IsA("Sound") then
		cache.Sound = foundSound
	end

	local vfxPartsByName = get_cutscene_vfx_parts(cache.Clones, vfxModelName)
	local animationsToLoad: {Animation} = {}

	for _, clone in cache.Clones do
		if not ignoredContainers[clone.Name] then
			local animator = get_animator_for_instance(clone)
			if animator then
				for _, animationObject in clone:GetDescendants() do
					if animationObject:IsA("Animation") then
						table.insert(animationsToLoad, animationObject)

						local track = animator:LoadAnimation(animationObject)

						if clone.Name == trackModelName then
							connect_vfx_markers(track, vfxPartsByName)
						end

						table.insert(cache.Tracks, track)
					end
				end
			end
		end
	end

	if #animationsToLoad > 0 then
		ContentProvider:PreloadAsync(animationsToLoad)
	end

	for _, track in cache.Tracks do
		local waited = 0

		while track.Length == 0 and waited < 5 do
			waited += task.wait()
		end

		if track.Length > cache.MaxDuration then
			cache.MaxDuration = track.Length
		end
	end

	cache.Ready = true
	cutsceneCaches[towerName] = cache
end

local function start_blink_swap_effect(cache: CutsceneCache, blinkSwap: BlinkSwapSettings?): (() -> ())?
	if not blinkSwap or not blinkSwap.Enabled then
		return nil
	end

	local baseModel = find_by_name_in_clones(cache.Clones, blinkSwap.BaseModelName)
	local flashModel = find_by_name_in_clones(cache.Clones, blinkSwap.FlashModelName)

	if not baseModel then
		warn(("BlinkSwap: model base '%s' não encontrado."):format(blinkSwap.BaseModelName))
		return nil
	end

	if not flashModel then
		warn(("BlinkSwap: model flash '%s' não encontrado."):format(blinkSwap.FlashModelName))
		return nil
	end

	local duration = blinkSwap.Duration or 5
	local interval = blinkSwap.Interval or 1
	local flashDuration = blinkSwap.FlashDuration or 0.1
	local flashYOffset = blinkSwap.FlashYOffset or -10
	local alive = true

	offset_instance(flashModel, CFrame.new(0, flashYOffset, 0))

	set_instance_visibility(baseModel, true)
	set_instance_visibility(flashModel, false)

	task.spawn(function()
		local flashCount = math.max(1, math.floor(duration / interval))

		for _ = 1, flashCount do
			if not alive then
				break
			end

			task.wait(interval)

			if not alive then
				break
			end

			set_instance_visibility(baseModel, false)
			set_instance_visibility(flashModel, true)

			task.wait(flashDuration)

			if not alive then
				break
			end

			set_instance_visibility(flashModel, false)
			set_instance_visibility(baseModel, true)
		end
	end)

	return function()
		alive = false
		set_instance_visibility(flashModel, false)
		set_instance_visibility(baseModel, true)
	end
end

------------------//MAIN FUNCTIONS
local function run_cutscene(towerName: string): ()
	if running then
		return
	end

	local settings: TowerSettings? = TowerCutsceneConfig.Towers[towerName]
	if not settings then
		return
	end

	if not cutsceneCaches[towerName] or not cutsceneCaches[towerName].Ready then
		preload_cutscene(towerName)
	end

	local cache = cutsceneCaches[towerName]
	if not cache or not cache.Ready then
		return
	end

	running = true

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		running = false
		return
	end

	local originalCharacterCFrame = humanoidRootPart.CFrame
	local cameraHeightOffset = settings.CameraHeightOffset or -1.5
	local fallbackDuration = settings.FallbackDuration or 6
	local guiName = settings.GuiName or ("TowerCutscene_" .. towerName:gsub("%W", ""))

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = guiName
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local blackFrame = Instance.new("Frame")
	blackFrame.Name = "Fade"
	blackFrame.Size = UDim2.fromScale(1, 1)
	blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	blackFrame.BackgroundTransparency = 1
	blackFrame.BorderSizePixel = 0
	blackFrame.Parent = screenGui

	local oldCameraType = camera.CameraType
	local oldCameraSubject = camera.CameraSubject
	local oldCameraCFrame = camera.CFrame
	local cameraConnection: RBXScriptConnection? = nil
	local blinkSwapCleanup: (() -> ())? = nil

	local hiddenGuis: {ScreenGui} = {}
	for _, gui in player.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name ~= guiName and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenGuis, gui)
		end
	end

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)

	tween_black(blackFrame, 0)

	local hiddenTowers: {Instance} = {}
	local hiddenMobs: {Instance} = {}

	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder then
		for _, child in towersFolder:GetChildren() do
			table.insert(hiddenTowers, child)
			child.Parent = ReplicatedStorage
		end
	end

	local mobsFolder = workspace:FindFirstChild("Mobs")
	if mobsFolder then
		for _, child in mobsFolder:GetChildren() do
			table.insert(hiddenMobs, child)
			child.Parent = ReplicatedStorage
		end
	end

	set_character_visibility(character, false)
	humanoidRootPart.Anchored = true
	character:PivotTo(originalCharacterCFrame * CFrame.new(0, -10, 0))

	for _, clone in cache.Clones do
		clone.Parent = workspace
		position_clone_at_player(clone, originalCharacterCFrame)
	end

	blinkSwapCleanup = start_blink_swap_effect(cache, settings.BlinkSwap)

	if cache.CameraRootPart then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cache.CameraRootPart.CFrame * CFrame.new(0, cameraHeightOffset, 0)
	end

	cameraConnection = RunService.RenderStepped:Connect(function()
		if cache.CameraRootPart and cache.CameraRootPart.Parent then
			camera.CFrame = cache.CameraRootPart.CFrame * CFrame.new(0, cameraHeightOffset, 0)
		end
	end)

	if cache.Sound then
		cache.Sound:Stop()
		cache.Sound.TimePosition = 0
		cache.Sound:Play()
	end

	for _, track in cache.Tracks do
		track:Play(0)
		track.TimePosition = 0.05
	end

	task.wait(0.1)

	task.spawn(function()
		tween_black(blackFrame, 1)
	end)

	if cache.MaxDuration > 0 then
		task.wait(cache.MaxDuration - 0.1)
	else
		task.wait(fallbackDuration - 0.1)
	end

	tween_black(blackFrame, 0)

	if blinkSwapCleanup then
		blinkSwapCleanup()
		blinkSwapCleanup = nil
	end

	for _, track in cache.Tracks do
		track:Stop(0)
	end

	if cache.Sound then
		cache.Sound:Stop()
	end

	for _, clone in cache.Clones do
		clone.Parent = ReplicatedStorage
	end

	if towersFolder then
		for _, child in hiddenTowers do
			if child.Parent ~= nil then
				child.Parent = towersFolder
			end
		end
	end

	if mobsFolder then
		for _, child in hiddenMobs do
			if child.Parent ~= nil then
				child.Parent = mobsFolder
			end
		end
	end

	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	camera.CameraType = oldCameraType
	if oldCameraSubject then
		camera.CameraSubject = oldCameraSubject
	end
	camera.CFrame = oldCameraCFrame

	character:PivotTo(originalCharacterCFrame)
	humanoidRootPart.Anchored = false
	set_character_visibility(character, true)

	for _, gui in hiddenGuis do
		if gui.Parent then
			gui.Enabled = true
		end
	end

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)

	tween_black(blackFrame, 1)
	screenGui:Destroy()

	running = false

	if DEBUG_LOOP_CUTSCENE then
		task.delay(DEBUG_LOOP_DELAY, function()
			run_cutscene(towerName)
		end)
	end
end

------------------//INIT
task.spawn(function()
	for towerName in TowerCutsceneConfig.Towers do
		preload_cutscene(towerName)
	end
end)

cutsceneEvent.OnClientEvent:Connect(function(towerName: string)
	run_cutscene(towerName)
end)