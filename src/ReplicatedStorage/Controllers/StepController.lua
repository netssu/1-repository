--!strict

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local SoundsData = require(ReplicatedStorage.Modules.Data.SoundsData)

local StepController = {}

type SoundInfo = {
	Id: number,
	BaseVolume: number?,
}

type SoundMap = {
	[string]: SoundInfo,
}

type StepMode = "walk" | "run"

local DEFAULT_RUN_SOUND_NAME: string = "Running"
local DEFAULT_RUN_SOUND_VOLUME: number = 0
local WALK_INTERVAL: number = 0.42
local RUN_INTERVAL: number = 0.29
local STEP_START_FACTOR: number = 0.35
local STEP_MAX_DISTANCE: number = 30
local MIN_MOVE_DIRECTION: number = 0.05
local MIN_PLANAR_SPEED: number = 1.75
local MIN_SPEED_DENOMINATOR: number = 0.1
local MIN_SPEED_FACTOR: number = 0.8
local MAX_SPEED_FACTOR: number = 1.2
local RUN_VOLUME_MULTIPLIER: number = 1.18

local WALK_STATES: {[string]: boolean} = table.freeze({
	walk = true,
	walkball = true,
	walkback = true,
	walkl = true,
	walkr = true,
	front = true,
})

local GRASS_MATERIALS: {[Enum.Material]: boolean} = table.freeze({
	[Enum.Material.Grass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Mud] = true,
})

local GRASS_KEYS: {string} = table.freeze({
	"Grass1",
	"Grass2",
	"Grass3",
})

local HARD_KEYS: {string} = table.freeze({
	"Hard1",
	"Hard2",
	"Hard3",
	"Hard4",
})

local STEP_KEYS: {string} = table.freeze({
	"Grass1",
	"Grass2",
	"Grass3",
	"Hard1",
	"Hard2",
	"Hard3",
	"Hard4",
})

local LocalPlayer: Player = Players.LocalPlayer
local SoundList: SoundMap = SoundsData.List
local UpdateConnection: RBXScriptConnection? = nil
local RootSoundConnection: RBXScriptConnection? = nil
local CharacterAddedConnection: RBXScriptConnection? = nil
local NextStepAt: number = 0
local LastStateName: string = ""
local LastStepKey: string = ""

local function ResetStepCycle(): ()
	NextStepAt = 0
	LastStateName = ""
end

local function GetCharacterParts(): (Model?, Humanoid?, BasePart?)
	local Character: Model? = LocalPlayer.Character
	if not Character then
		return nil, nil, nil
	end

	local Humanoid: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return Character, nil, nil
	end

	local Root: Instance? = Character:FindFirstChild("HumanoidRootPart")
	if not Root or not Root:IsA("BasePart") then
		return Character, Humanoid, nil
	end

	return Character, Humanoid, Root
end

local function GetPlanarSpeed(Root: BasePart): number
	return Vector2.new(Root.AssemblyLinearVelocity.X, Root.AssemblyLinearVelocity.Z).Magnitude
end

local function GetStepMode(StateName: string): StepMode?
	if StateName == "run" then
		return "run"
	end
	if WALK_STATES[StateName] then
		return "walk"
	end
	return nil
end

local function GetSurfaceKeys(Humanoid: Humanoid): {string}
	if GRASS_MATERIALS[Humanoid.FloorMaterial] then
		return GRASS_KEYS
	end
	return HARD_KEYS
end

local function GetSoundVolume(SoundKey: string, StepModeName: StepMode): number
	local Entry: SoundInfo? = SoundList[SoundKey]
	local BaseVolume: number = if Entry and typeof(Entry.BaseVolume) == "number" then Entry.BaseVolume else 0.45
	if StepModeName == "run" then
		return BaseVolume * RUN_VOLUME_MULTIPLIER
	end
	return BaseVolume
end

local function PickSoundKey(Keys: {string}): string?
	local Count: number = #Keys
	if Count <= 0 then
		return nil
	end

	local SelectedKey: string = Keys[math.random(1, Count)]
	if Count > 1 and SelectedKey == LastStepKey then
		for _ = 1, Count do
			local CandidateKey: string = Keys[math.random(1, Count)]
			if CandidateKey ~= LastStepKey then
				SelectedKey = CandidateKey
				break
			end
		end
	end

	return SelectedKey
end

local function CanPlayStep(Humanoid: Humanoid, Root: BasePart, StepModeName: StepMode?): boolean
	if not StepModeName then
		return false
	end
	if Humanoid.Health <= 0 then
		return false
	end
	if Humanoid.PlatformStand then
		return false
	end
	if Humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	if Humanoid.MoveDirection.Magnitude < MIN_MOVE_DIRECTION and GetPlanarSpeed(Root) < MIN_PLANAR_SPEED then
		return false
	end
	return true
end

local function GetStepInterval(Humanoid: Humanoid, Root: BasePart, StepModeName: StepMode): number
	local BaseInterval: number = if StepModeName == "run" then RUN_INTERVAL else WALK_INTERVAL
	local SpeedDenominator: number = math.max(Humanoid.WalkSpeed, MIN_SPEED_DENOMINATOR)
	local SpeedFactor: number = math.clamp(GetPlanarSpeed(Root) / SpeedDenominator, MIN_SPEED_FACTOR, MAX_SPEED_FACTOR)
	return BaseInterval / SpeedFactor
end

local function PlayStep(Humanoid: Humanoid, Root: BasePart, StepModeName: StepMode): ()
	local Keys: {string} = GetSurfaceKeys(Humanoid)
	local SoundKey: string? = PickSoundKey(Keys)
	if not SoundKey then
		return
	end

	LastStepKey = SoundKey
	SoundController:PlayAt(Root, SoundKey, {
		Volume = GetSoundVolume(SoundKey, StepModeName),
		Pitch = true,
		MaxDist = STEP_MAX_DISTANCE,
	})
end

local function MuteRunSoundChild(Child: Instance): ()
	if not Child:IsA("Sound") then
		return
	end
	if Child.Name ~= DEFAULT_RUN_SOUND_NAME then
		return
	end

	Child.Volume = DEFAULT_RUN_SOUND_VOLUME
end

local function BindCharacter(Character: Model): ()
	if RootSoundConnection then
		RootSoundConnection:Disconnect()
		RootSoundConnection = nil
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		local ResolvedRoot: Instance? = Character:WaitForChild("HumanoidRootPart", 5)
		if ResolvedRoot and ResolvedRoot:IsA("BasePart") then
			Root = ResolvedRoot
		end
	end
	if not Root then
		return
	end

	for _, Child in Root:GetChildren() do
		MuteRunSoundChild(Child)
	end

	RootSoundConnection = Root.ChildAdded:Connect(function(Child: Instance): ()
		MuteRunSoundChild(Child)
	end)
end

local function BuildPreloadList(): {any}
	local PreloadList: {any} = {}
	local SeenContent: {[string]: boolean} = {}

	for _, SoundKey in STEP_KEYS do
		local Entry: SoundInfo? = SoundList[SoundKey]
		if not Entry or typeof(Entry.Id) ~= "number" or Entry.Id <= 0 then
			continue
		end

		local AssetId: string = "rbxassetid://" .. tostring(Entry.Id)
		if SeenContent[AssetId] then
			continue
		end

		SeenContent[AssetId] = true
		table.insert(PreloadList, AssetId)
	end

	return PreloadList
end

local function PreloadStepSounds(): ()
	local PreloadList: {any} = BuildPreloadList()
	if #PreloadList <= 0 then
		return
	end

	pcall(function(): ()
		ContentProvider:PreloadAsync(PreloadList)
	end)
end

local function UpdateSteps(): ()
	local _Character: Model?, Humanoid: Humanoid?, Root: BasePart? = GetCharacterParts()
	if not Humanoid or not Root then
		ResetStepCycle()
		return
	end

	local StateName: string = AnimationController.GetCurrentState()
	local StepModeName: StepMode? = GetStepMode(StateName)
	if not CanPlayStep(Humanoid, Root, StepModeName) then
		ResetStepCycle()
		return
	end

	local ResolvedStepMode: StepMode = StepModeName :: StepMode
	local Interval: number = GetStepInterval(Humanoid, Root, ResolvedStepMode)
	local Now: number = os.clock()

	if LastStateName ~= StateName then
		LastStateName = StateName
		NextStepAt = Now + (Interval * STEP_START_FACTOR)
		return
	end

	if NextStepAt <= 0 then
		NextStepAt = Now + (Interval * STEP_START_FACTOR)
		return
	end

	if Now < NextStepAt then
		return
	end

	PlayStep(Humanoid, Root, ResolvedStepMode)
	NextStepAt = Now + Interval
end

function StepController.Init(): ()
	ResetStepCycle()
end

function StepController.Start(): ()
	if CharacterAddedConnection then
		return
	end

	task.spawn(PreloadStepSounds)

	CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(Character: Model): ()
		ResetStepCycle()
		BindCharacter(Character)
	end)

	if LocalPlayer.Character then
		BindCharacter(LocalPlayer.Character)
	end

	if UpdateConnection then
		return
	end

	UpdateConnection = RunService.RenderStepped:Connect(UpdateSteps)
end

return StepController
