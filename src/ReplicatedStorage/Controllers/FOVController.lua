--!strict

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FOVController = {}

--\\ TYPES \\ --
type FOVOptions = {
	TweenInfo: TweenInfo?,
	Duration: number?,
}

type FOVRequest = {
	Id: string,
	FOV: number,
	Priority: number,
	Sequence: number,
	TweenInfo: TweenInfo?,
	ExpireAt: number?,
}

--\\ CONSTANTS \\ --
local DEFAULT_TWEEN: TweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local FALLBACK_FOV: number = 70
local MIN_DELTA_TO_APPLY: number = 0.01
local DEFAULT_PRIORITY: number = 0

--\\ STATE \\ --
local ActiveRequests: {[string]: FOVRequest} = {}
local BaseFOV: number = FALLBACK_FOV
local ActiveTween: Tween? = nil
local CameraChangedConnection: RBXScriptConnection? = nil
local ExpireConnection: RBXScriptConnection? = nil
local RequestSequence: number = 0

--\\ PRIVATE FUNCTIONS \\ --
local function GetCamera(): Camera?
	return Workspace.CurrentCamera
end

local function CaptureBaseFOV(): ()
	local camera = GetCamera()
	if camera then
		BaseFOV = camera.FieldOfView
	end
end

local function CancelActiveTween(): ()
	if ActiveTween then
		ActiveTween:Cancel()
		ActiveTween = nil
	end
end

local function ApplyFOV(targetFOV: number, tweenInfo: TweenInfo?): ()
	local camera = GetCamera()
	if not camera then return end

	CancelActiveTween()

	local delta = math.abs(camera.FieldOfView - targetFOV)
	local info = tweenInfo or DEFAULT_TWEEN
	if info.Time <= 0 or delta <= MIN_DELTA_TO_APPLY then
		camera.FieldOfView = targetFOV
		return
	end

	local tween = TweenService:Create(camera, info, { FieldOfView = targetFOV })
	ActiveTween = tween

	tween.Completed:Once(function()
		if ActiveTween == tween then
			ActiveTween = nil
		end
	end)

	tween:Play()
end

local function CleanupExpiredRequests(now: number?): boolean
	local current = now or os.clock()
	local removed = false

	for id, request in ActiveRequests do
		if request.ExpireAt and current >= request.ExpireAt then
			ActiveRequests[id] = nil
			removed = true
		end
	end

	return removed
end

local function HasActiveRequests(): boolean
	return next(ActiveRequests) ~= nil
end

local function GetWinningRequest(): FOVRequest?
	local winner: FOVRequest? = nil

	for _, request in ActiveRequests do
		if not winner
			or request.Priority > winner.Priority
			or (request.Priority == winner.Priority and request.FOV > winner.FOV)
			or (request.Priority == winner.Priority and request.FOV == winner.FOV and request.Sequence > winner.Sequence)
		then
			winner = request
		end
	end

	return winner
end

local function Evaluate(): ()
	-- Remove pedidos expirados antes de decidir.
	CleanupExpiredRequests()

	local winner = GetWinningRequest()
	if not winner then
		ApplyFOV(BaseFOV, DEFAULT_TWEEN)
		return
	end

	ApplyFOV(winner.FOV, winner.TweenInfo or DEFAULT_TWEEN)
end

local function DisconnectConnections(): ()
	if CameraChangedConnection then
		CameraChangedConnection:Disconnect()
		CameraChangedConnection = nil
	end
	if ExpireConnection then
		ExpireConnection:Disconnect()
		ExpireConnection = nil
	end
end

--\\ PUBLIC API \\ --
function FOVController.Start(): ()
	CaptureBaseFOV()
	Evaluate()

	DisconnectConnections()

	CameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if not HasActiveRequests() then
			CaptureBaseFOV()
		end
		Evaluate()
	end)

	ExpireConnection = RunService.Heartbeat:Connect(function()
		if CleanupExpiredRequests() then
			Evaluate()
		end
	end)
end

function FOVController.Stop(): ()
	DisconnectConnections()
	CancelActiveTween()
end

function FOVController.SetBaseFOV(fov: number): ()
	BaseFOV = fov
	Evaluate()
end

function FOVController.AddRequest(id: string, fov: number, priority: number?, options: FOVOptions?): ()
	local expireAt = if options and options.Duration then os.clock() + options.Duration else nil
	local tweenInfo = if options then options.TweenInfo else nil
	RequestSequence += 1

	ActiveRequests[id] = {
		Id = id,
		FOV = fov,
		Priority = priority or DEFAULT_PRIORITY,
		Sequence = RequestSequence,
		TweenInfo = tweenInfo,
		ExpireAt = expireAt,
	}

	Evaluate()
end

function FOVController.RemoveRequest(id: string): ()
	if ActiveRequests[id] then
		ActiveRequests[id] = nil
		Evaluate()
	end
end

function FOVController.Clear(): ()
	if next(ActiveRequests) == nil then
		return
	end
	table.clear(ActiveRequests)
	Evaluate()
end

function FOVController.GetActiveRequest(): FOVRequest?
	return GetWinningRequest()
end

function FOVController.GetBaseFOV(): number
	return BaseFOV
end

return FOVController
