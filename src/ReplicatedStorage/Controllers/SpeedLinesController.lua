--!strict

local RUN_SERVICE: RunService = game:GetService("RunService")
local REPLICATED_STORAGE: ReplicatedStorage = game:GetService("ReplicatedStorage")
local WORKSPACE: Workspace = game:GetService("Workspace")

local SPEED_REF: number = 20
local RATE_REF: number = 800
local FORCE_RATE_MIN: number = RATE_REF
local ASPECT_THRESHOLD: number = 1.5
local OFFSET_WIDE: number = 7
local OFFSET_TALL: number = 10

local INPUT_DEADZONE: number = 0.05
local STOP_DEADZONE: number = 0.8
local FORCE_ENABLED_DEFAULT: boolean = false
local DEFAULT_KEY: string = "Default"
local SPEED_LINES_MODEL_NAME: string = "SpeedLines"
local SPEED_LINES_OWNER_ATTRIBUTE: string = "SpeedLinesOwner"
local SPEED_LINES_OWNER_VALUE: string = "SpeedLinesController"

type Config = {
	SpeedRef: number?,
	RateRef: number?,
	AspectThreshold: number?,
	OffsetWide: number?,
	OffsetTall: number?,
	InputDeadzone: number?,
	StopDeadzone: number?,
	ForceEnabled: boolean?,
}

local SpeedLinesController = {}

local _Conn: RBXScriptConnection? = nil
local _Model: Model? = nil
local _ModelOwned: boolean = false
local _Emitters: {ParticleEmitter} = {}
local _Humanoid: Humanoid? = nil

local _SpeedRef: number = SPEED_REF
local _RateRef: number = RATE_REF
local _AspectThreshold: number = ASPECT_THRESHOLD
local _OffsetWide: number = OFFSET_WIDE
local _OffsetTall: number = OFFSET_TALL
local _InputDeadzone: number = INPUT_DEADZONE
local _StopDeadzone: number = STOP_DEADZONE
local _ForceEnabled: boolean = FORCE_ENABLED_DEFAULT
local _ActiveKeys: {[string]: boolean} = {}
local _ForceByKey: {[string]: boolean} = {}

local function _UpdateForceEnabled(): ()
	local Force: boolean = false
	for _, Enabled in _ForceByKey do
		if Enabled then
			Force = true
			break
		end
	end
	_ForceEnabled = Force
end

local function _GetTemplate(): Model
	local Assets: Folder = REPLICATED_STORAGE:WaitForChild("Assets") :: Folder
	local Gameplay: Folder = Assets:WaitForChild("Gameplay") :: Folder
	local Modelo: Folder = Gameplay:WaitForChild("Modelo") :: Folder
	return Modelo:WaitForChild(SPEED_LINES_MODEL_NAME) :: Model
end

local function _CollectEmitters(Root: Instance): {ParticleEmitter}
	local List: {ParticleEmitter} = {}
	for _, d: Instance in ipairs(Root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			table.insert(List, d)
		end
	end
	return List
end

local function _SetEnabled(Enabled: boolean)
	for _, em: ParticleEmitter in ipairs(_Emitters) do
		em.Enabled = Enabled
		if not Enabled then
			em.Rate = 0
		end
	end
end

local function _SetRate(Rate: number)
	for _, em: ParticleEmitter in ipairs(_Emitters) do
		em.Rate = Rate
	end
end

local function _GetHorizontalSpeed(H: Humanoid): number
	local v: Vector3 = H:GetMoveVelocity()
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function _IsOnGround(H: Humanoid): boolean
	if H.FloorMaterial == Enum.Material.Air then
		return false
	end
	local st: Enum.HumanoidStateType = H:GetState()
	if st == Enum.HumanoidStateType.Jumping
		or st == Enum.HumanoidStateType.Freefall
		or st == Enum.HumanoidStateType.FallingDown then
		return false
	end
	return true
end

function SpeedLinesController.ShouldShow(H: Humanoid): boolean
	local movingInput: boolean = (H.MoveDirection.Magnitude > _InputDeadzone)
	local speed: number = _GetHorizontalSpeed(H)
	local onGround: boolean = _IsOnGround(H)
	return onGround and movingInput and (speed > _StopDeadzone)
end

local function _EnsureModel()
	if _Model ~= nil then
		return
	end

	local Cam: Camera? = WORKSPACE.CurrentCamera
	if Cam then
		local Existing: Model? = Cam:FindFirstChild(SPEED_LINES_MODEL_NAME) :: Model?
		if Existing and Existing:IsA("Model") then
			_Model = Existing
			_ModelOwned = Existing:GetAttribute(SPEED_LINES_OWNER_ATTRIBUTE) == SPEED_LINES_OWNER_VALUE
			_Emitters = _CollectEmitters(Existing)
			if _ModelOwned then
				_SetEnabled(false)
			end
			return
		end
	end

	local Template: Model = _GetTemplate()
	local Clone: Model = Template:Clone()
	Clone.Name = SPEED_LINES_MODEL_NAME
	Clone:SetAttribute(SPEED_LINES_OWNER_ATTRIBUTE, SPEED_LINES_OWNER_VALUE)

	Clone.Parent = Cam or WORKSPACE
	_Model = Clone
	_ModelOwned = true
	_Emitters = _CollectEmitters(Clone)
	_SetEnabled(false)
end

local function _DestroyModel()
	if _Model ~= nil then
		if _ModelOwned then
			pcall(function()
				_Model:Destroy()
			end)
		end
	end
	_Model = nil
	_ModelOwned = false
	table.clear(_Emitters)
end

function SpeedLinesController.Acquire(Key: string, H: Humanoid, Cfg: Config?): ()
	if _ActiveKeys[Key] ~= true then
		_ActiveKeys[Key] = true
	end

	_Humanoid = H

	if Cfg then
		if Cfg.SpeedRef ~= nil then
			_SpeedRef = Cfg.SpeedRef
		end
		if Cfg.RateRef ~= nil then
			_RateRef = Cfg.RateRef
		end
		if Cfg.AspectThreshold ~= nil then
			_AspectThreshold = Cfg.AspectThreshold
		end
		if Cfg.OffsetWide ~= nil then
			_OffsetWide = Cfg.OffsetWide
		end
		if Cfg.OffsetTall ~= nil then
			_OffsetTall = Cfg.OffsetTall
		end
		if Cfg.InputDeadzone ~= nil then
			_InputDeadzone = Cfg.InputDeadzone
		end
		if Cfg.StopDeadzone ~= nil then
			_StopDeadzone = Cfg.StopDeadzone
		end
		_ForceByKey[Key] = Cfg.ForceEnabled == true
	else
		if _ForceByKey[Key] == nil then
			_ForceByKey[Key] = FORCE_ENABLED_DEFAULT
		end
	end

	_UpdateForceEnabled()
	_EnsureModel()

	if _Conn ~= nil then
		return
	end

	_Conn = RUN_SERVICE.RenderStepped:Connect(function()
		local Humanoid: Humanoid? = _Humanoid
		local Model: Model? = _Model
		local Cam: Camera? = WORKSPACE.CurrentCamera

		if Humanoid == nil or Model == nil or Cam == nil then
			_SetEnabled(false)
			return
		end

		if Model.Parent ~= Cam then
			Model.Parent = Cam
		end

		local view: Vector2 = Cam.ViewportSize
		local aspect: number = 1
		if view.Y > 0 then
			aspect = view.X / view.Y
		end

		local offset: number = (aspect > _AspectThreshold) and _OffsetWide or _OffsetTall
		local dist: number = offset / (Cam.FieldOfView / 70)

		Model:PivotTo(Cam.CFrame + (Cam.CFrame.LookVector * dist))

		local movingInput: boolean = (Humanoid.MoveDirection.Magnitude > _InputDeadzone)
		local speed: number = _GetHorizontalSpeed(Humanoid)
		local onGround: boolean = _IsOnGround(Humanoid)

		local show: boolean = _ForceEnabled or (onGround and movingInput and (speed > _StopDeadzone))
		if not show then
			_SetEnabled(false)
			return
		end

		_SetEnabled(true)
		local Rate: number = (speed / _SpeedRef) * _RateRef
		if _ForceEnabled and Rate < FORCE_RATE_MIN then
			Rate = FORCE_RATE_MIN
		end
		_SetRate(Rate)
	end)
end

function SpeedLinesController.Release(Key: string): ()
	if _ActiveKeys[Key] ~= true then
		return
	end
	_ActiveKeys[Key] = nil
	_ForceByKey[Key] = nil
	_UpdateForceEnabled()
	if next(_ActiveKeys) ~= nil then
		return
	end
	if _Conn ~= nil then
		_Conn:Disconnect()
		_Conn = nil
	end
	_SetEnabled(false)
	_DestroyModel()
	_Humanoid = nil
end

function SpeedLinesController.Play(H: Humanoid, Cfg: Config?): ()
	SpeedLinesController.Acquire(DEFAULT_KEY, H, Cfg)
end

function SpeedLinesController.Stop(): ()
	SpeedLinesController.Release(DEFAULT_KEY)
end

return SpeedLinesController
