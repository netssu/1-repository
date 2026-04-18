local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Player = Players.Player
type Humanoid = Humanoid
type BasePart = BasePart

local SHIFTLOCK_BIND_NAME: string = "ShiftLock"
local CAMERA_OFFSET_Y: number = 0.35
local OFFSET_BLEND_SPEED: number = 14
local ROTATION_BLEND_SPEED: number = 18

local CameraController = {}
local HARD_SHIFTLOCK_BLOCKERS: {[string]: boolean} = {
	MatchIntroCutscene = true,
}

local LocalPlayer: Player = Players.LocalPlayer
local Character: Model? = nil
local HumanoidInstance: Humanoid? = nil
local HumanoidRootPart: BasePart? = nil

local ShiftlockBlendAlpha: number = 0
local LastStepClock: number = os.clock()
local RenderBound: boolean = false
local AutoRotateOwner: Humanoid? = nil
local AutoRotatePrevious: boolean? = nil
local ShiftlockBlockers: {[string]: number} = {}
local BindAwakenSignals: ((Target: Instance) -> ())? = nil
local ShiftlockRequested: boolean = false
local AwakenShiftlockBlocked: boolean = false
local AwakenShiftlockRestoreAllowed: boolean = false

_G.CameraShiftlock = false
_G.CameraShiftlockRequested = false
_G.CameraScoredGoal = false
_G.CameraBallController = nil

local function IsSkillShiftlockSyncPaused(): boolean
	if LocalPlayer:GetAttribute("FTSkillLocked") == true then
		return true
	end
	if Character and Character:GetAttribute("FTSkillLocked") == true then
		return true
	end
	return false
end

local function HasShiftlockBlocker(requireHardBlock: boolean): boolean
	for Source, Count in ShiftlockBlockers do
		if Count > 0 and (not requireHardBlock or HARD_SHIFTLOCK_BLOCKERS[Source] == true) then
			return true
		end
	end
	return false
end

local function IsShiftlockPreferenceBlocked(): boolean
	if _G.CameraScoredGoal == true or _G.CameraBallController == true then
		return true
	end
	return HasShiftlockBlocker(true)
end

local function ResolveCharacterParts(): ()
	Character = LocalPlayer.Character
	HumanoidInstance = nil
	HumanoidRootPart = nil
	if not Character then
		return
	end
	HumanoidInstance = Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetMiscCursor(): GuiObject?
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local miscGui = if playerGui then playerGui:FindFirstChild("Misc") else nil
	if not miscGui then
		return nil
	end
	local cursor = miscGui:FindFirstChild("Cursor")
	if cursor and cursor:IsA("GuiObject") then
		return cursor
	end
	return nil
end

local function SetCursorState(nativeVisible: boolean, miscVisible: boolean): ()
	if UserInputService.MouseIconEnabled ~= nativeVisible then
		UserInputService.MouseIconEnabled = nativeVisible
	end
	local cursor = GetMiscCursor()
	if cursor and cursor.Visible ~= miscVisible then
		cursor.Visible = miscVisible
	end
end

local function SetMouseBehavior(behavior: Enum.MouseBehavior): ()
	if UserInputService.MouseBehavior ~= behavior then
		UserInputService.MouseBehavior = behavior
	end
end

local function BlendBySpeed(current: number, target: number, speed: number, dt: number): number
	local safeDt = math.clamp(dt, 0, 0.1)
	local k = 1 - math.exp(-speed * safeDt)
	return current + (target - current) * k
end

local function SetHumanoidOffsetAlpha(alpha: number): ()
	if not HumanoidInstance then
		return
	end
	local target = Vector3.new(0, CAMERA_OFFSET_Y * math.clamp(alpha, 0, 1), 0)
	if (HumanoidInstance.CameraOffset - target).Magnitude > 1e-4 then
		HumanoidInstance.CameraOffset = target
	end
end

local function AcquireAutoRotateLock(): ()
	if not HumanoidInstance then
		return
	end
	if AutoRotateOwner ~= HumanoidInstance then
		AutoRotateOwner = HumanoidInstance
		AutoRotatePrevious = HumanoidInstance.AutoRotate
	end
	if HumanoidInstance.AutoRotate ~= false then
		HumanoidInstance.AutoRotate = false
	end
end

local function ReleaseAutoRotateLock(): ()
	local owner = AutoRotateOwner
	local previous = AutoRotatePrevious
	if owner and owner.Parent and previous ~= nil and owner.AutoRotate ~= previous then
		owner.AutoRotate = previous
	end
	AutoRotateOwner = nil
	AutoRotatePrevious = nil
end

local function IsShiftlockBlocked(): boolean
	return IsShiftlockPreferenceBlocked()
end

local function ForceShiftlockOff(): ()
	ShiftlockBlendAlpha = 0
	_G.CameraShiftlock = false
	SetHumanoidOffsetAlpha(0)
	ReleaseAutoRotateLock()
	SetCursorState(true, false)
	SetMouseBehavior(Enum.MouseBehavior.Default)
end

local function SyncRequestedShiftlockGlobal(): ()
	_G.CameraShiftlockRequested = ShiftlockRequested == true
end

local function HandleAwakenShiftlockBlockState(): ()
	local Blocked: boolean = IsShiftlockPreferenceBlocked()
	if Blocked ~= AwakenShiftlockBlocked then
		AwakenShiftlockBlocked = Blocked
		if Blocked then
			AwakenShiftlockRestoreAllowed = ShiftlockRequested
		else
			AwakenShiftlockRestoreAllowed = false
		end
	end
	if Blocked then
		ForceShiftlockOff()
	end
end

local function UpdateShiftlock(dt: number): ()
	ResolveCharacterParts()
	HandleAwakenShiftlockBlockState()

	local wantsShiftlock = ShiftlockRequested == true
	local blockedByCamera = IsShiftlockBlocked()
	local syncPaused = IsSkillShiftlockSyncPaused() or HasShiftlockBlocker(false)
	local hasRoot = HumanoidRootPart ~= nil and HumanoidRootPart.AssemblyRootPart == HumanoidRootPart
	local shouldControl = wantsShiftlock and not blockedByCamera and hasRoot
	_G.CameraShiftlock = shouldControl

	local targetAlpha = if shouldControl then 1 else 0
	ShiftlockBlendAlpha = BlendBySpeed(ShiftlockBlendAlpha, targetAlpha, OFFSET_BLEND_SPEED, dt)
	if ShiftlockBlendAlpha < 1e-4 and targetAlpha == 0 then
		ShiftlockBlendAlpha = 0
	end
	SetHumanoidOffsetAlpha(ShiftlockBlendAlpha)

	if shouldControl then
		if syncPaused then
			ReleaseAutoRotateLock()
		else
			AcquireAutoRotateLock()
		end
		SetCursorState(false, true)
		SetMouseBehavior(Enum.MouseBehavior.LockCurrentPosition)
		local camera = workspace.CurrentCamera
		if not syncPaused and camera and HumanoidRootPart then
			local _, yaw = camera.CFrame.Rotation:ToEulerAnglesYXZ()
			local yawBlend = BlendBySpeed(0, 1, ROTATION_BLEND_SPEED, dt) * math.clamp(ShiftlockBlendAlpha, 0, 1)
			HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(
				CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, yaw, 0),
				yawBlend
			)
		end
	else
		ReleaseAutoRotateLock()
		if not wantsShiftlock and not blockedByCamera and HumanoidInstance and AutoRotateOwner == nil then
			if HumanoidInstance.AutoRotate ~= true then
				HumanoidInstance.AutoRotate = true
			end
		end
		if wantsShiftlock or ShiftlockBlendAlpha > 0 then
			SetCursorState(true, false)
			SetMouseBehavior(Enum.MouseBehavior.Default)
		end
	end

	if not wantsShiftlock and ShiftlockBlendAlpha <= 0 and AutoRotateOwner == nil and RenderBound then
		RunService:UnbindFromRenderStep(SHIFTLOCK_BIND_NAME)
		RenderBound = false
	end
end

local function EnsureRenderLoop(): ()
	if RenderBound then
		return
	end
	RenderBound = true
	LastStepClock = os.clock()
	RunService:BindToRenderStep(SHIFTLOCK_BIND_NAME, Enum.RenderPriority.Character.Value, function()
		local now = os.clock()
		local dt = now - LastStepClock
		LastStepClock = now
		UpdateShiftlock(dt)
	end)
end

ResolveCharacterParts()
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	HumanoidInstance = newCharacter:WaitForChild("Humanoid", 5) :: Humanoid?
	HumanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	BindAwakenSignals(newCharacter)
	if AutoRotateOwner and AutoRotateOwner ~= HumanoidInstance then
		ReleaseAutoRotateLock()
	end
	SetHumanoidOffsetAlpha(ShiftlockBlendAlpha)
	HandleAwakenShiftlockBlockState()
	if ShiftlockRequested == true then
		EnsureRenderLoop()
	end
end)

LocalPlayer.CharacterRemoving:Connect(function(removingCharacter)
	if Character == removingCharacter then
		ShiftlockBlendAlpha = 0
		ReleaseAutoRotateLock()
		_G.CameraShiftlock = false
		SetCursorState(true, false)
		SetMouseBehavior(Enum.MouseBehavior.Default)
		Character = nil
		HumanoidInstance = nil
		HumanoidRootPart = nil
	end
end)

SetCursorState(true, false)

function CameraController:SetShiftlock(enabled: boolean): ()
	local WantsShiftlock: boolean = enabled == true
	HandleAwakenShiftlockBlockState()
	if WantsShiftlock and IsShiftlockPreferenceBlocked() and not AwakenShiftlockRestoreAllowed then
		UpdateShiftlock(1 / 60)
		return
	end
	ShiftlockRequested = WantsShiftlock
	SyncRequestedShiftlockGlobal()
	EnsureRenderLoop()
	UpdateShiftlock(1 / 60)
end

function CameraController:IsShiftlockRequested(): boolean
	return ShiftlockRequested == true
end

function CameraController:IsShiftlockBlocked(): boolean
	return IsShiftlockPreferenceBlocked()
end

function CameraController:RefreshShiftlockState(): ()
	ResolveCharacterParts()
	if AutoRotateOwner and AutoRotateOwner ~= HumanoidInstance then
		ReleaseAutoRotateLock()
	end
	if HumanoidInstance and not IsShiftlockPreferenceBlocked() and AutoRotateOwner == nil and not IsSkillShiftlockSyncPaused() then
		if HumanoidInstance.AutoRotate ~= true then
			HumanoidInstance.AutoRotate = true
		end
	end
	EnsureRenderLoop()
	UpdateShiftlock(1 / 60)
	if ShiftlockRequested ~= true and not IsShiftlockPreferenceBlocked() and AutoRotateOwner == nil and HumanoidInstance and not IsSkillShiftlockSyncPaused() then
		if HumanoidInstance.AutoRotate ~= true then
			HumanoidInstance.AutoRotate = true
		end
	end
end

function CameraController:SetShiftlockBlocked(source: string, blocked: boolean): ()
	if blocked then
		ShiftlockBlockers[source] = (ShiftlockBlockers[source] or 0) + 1
	else
		local Count: number = ShiftlockBlockers[source] or 0
		if Count <= 1 then
			ShiftlockBlockers[source] = nil
		else
			ShiftlockBlockers[source] = Count - 1
		end
	end
	EnsureRenderLoop()
	UpdateShiftlock(1 / 60)
end

BindAwakenSignals = function(Target: Instance): ()
	Target:GetAttributeChangedSignal("FTSkillLocked"):Connect(function()
		HandleAwakenShiftlockBlockState()
		UpdateShiftlock(1 / 60)
	end)
end

ShiftlockRequested = _G.CameraShiftlockRequested == true or _G.CameraShiftlock == true
SyncRequestedShiftlockGlobal()
BindAwakenSignals(LocalPlayer)
if Character then
	BindAwakenSignals(Character)
end

return CameraController
