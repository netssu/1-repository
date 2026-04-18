--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FTRefereeService = {}

local refereeInstance: Model? = nil
local ballCarrier: Player? = nil
local refereeConnection: RBXScriptConnection? = nil
local MIN_MOVE_DISTANCE = 0.1
local UPDATE_INTERVAL = 0.05
local SIDE_SIGN = 1
local ARBITO_LINE_TARGET_Y = 710.333
local lastUpdateTime = 0
local TARGET_Y = 713.825
local trackedBall: BasePart? = nil

local function GetArbitoLine(): BasePart?
	local Game = Workspace:FindFirstChild("Game")
	if not Game then return nil end
	local ArbitoLine = Game:FindFirstChild("ArbitoLine")
	if not ArbitoLine or not ArbitoLine:IsA("BasePart") then return nil end

	if ArbitoLine:GetAttribute("HeightAdjusted") ~= true then
		local CurrentPosition: Vector3 = ArbitoLine.Position
		local TargetPosition: Vector3 = Vector3.new(CurrentPosition.X, ARBITO_LINE_TARGET_Y, CurrentPosition.Z)
		ArbitoLine.CFrame = CFrame.new(TargetPosition) * (ArbitoLine.CFrame - CurrentPosition)
		ArbitoLine:SetAttribute("HeightAdjusted", true)
	end

	return ArbitoLine
end

local function InitializeReferee(): ()
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return end
	local Gameplay = Assets:FindFirstChild("Gameplay")
	if not Gameplay then return end
	local Modelo = Gameplay:FindFirstChild("Modelo")
	if not Modelo then return end
	local RefereeModel = Modelo:FindFirstChild("Juiz")
	if not RefereeModel then return end

	refereeInstance = RefereeModel:Clone()
	refereeInstance.Name = "Referee"
	refereeInstance.Parent = Workspace:FindFirstChild("Game") or Workspace
	
	for _, part in ipairs(refereeInstance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end

	local root = refereeInstance:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CanCollide = true
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	local hum = refereeInstance:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = 25
	end
end

local function ResolveBall(): BasePart?
	if trackedBall and trackedBall.Parent then
		return trackedBall
	end

	local Game = Workspace:FindFirstChild("Game")
	if Game then
		local football = Game:FindFirstChild("Football")
		if football then
			if football:IsA("Model") then
				local part = football.PrimaryPart or football:FindFirstChildWhichIsA("BasePart")
				if part then
					trackedBall = part
					return part
				end
			elseif football:IsA("BasePart") then
				trackedBall = football
				return football
			end
		end
	end

	local footballDescendant = Workspace:FindFirstChild("Football", true)
	if footballDescendant then
		if footballDescendant:IsA("Model") then
			local part = footballDescendant.PrimaryPart or footballDescendant:FindFirstChildWhichIsA("BasePart")
			if part then
				trackedBall = part
				return part
			end
		elseif footballDescendant:IsA("BasePart") then
			trackedBall = footballDescendant
			return footballDescendant
		end
	end

	return nil
end

local function GetTargetPosition(): Vector3?
	local target = ResolveBall()
	if not target and ballCarrier then
		local character = ballCarrier.Character
		if character then
			target = character:FindFirstChild("HumanoidRootPart")
		end
	end
	
	if target then
		return target.Position
	end
	
	return nil
end

local function ComputeRefereeTargetPosition(targetPos: Vector3): Vector3?
	local ArbitoLine = GetArbitoLine()
	if not ArbitoLine then return nil end

	local ArbitoLineCFrame = ArbitoLine.CFrame
	local ArbitoLinePosition = ArbitoLineCFrame.Position

	local mainAxisIsX = ArbitoLine.Size.X >= ArbitoLine.Size.Z
	local axisVector = if mainAxisIsX then ArbitoLineCFrame.RightVector else ArbitoLineCFrame.LookVector
	local perpendicular = if mainAxisIsX then ArbitoLineCFrame.LookVector else ArbitoLineCFrame.RightVector
	local axisLength = if mainAxisIsX then ArbitoLine.Size.X else ArbitoLine.Size.Z

	local halfThickness = if mainAxisIsX then ArbitoLine.Size.Z * 0.5 else ArbitoLine.Size.X * 0.5
	local sideVector = perpendicular.Unit * (SIDE_SIGN * (halfThickness + 2))

	local alongDistance = (targetPos - ArbitoLinePosition):Dot(axisVector)
	local clampedAlong = math.clamp(alongDistance, -axisLength * 0.5, axisLength * 0.5)

	local targetPosition = ArbitoLinePosition + axisVector * clampedAlong + sideVector
	return Vector3.new(targetPosition.X, TARGET_Y, targetPosition.Z)
end


local function UpdateRefereePosition(): ()
	if not refereeInstance then return end

	local targetPos = GetTargetPosition()
	if not targetPos then return end
	local targetPosition = ComputeRefereeTargetPosition(targetPos)
	if not targetPosition then return end

	local RefereeHumanoidRootPart = refereeInstance:FindFirstChild("HumanoidRootPart") :: BasePart?
	local RefereeHumanoid = refereeInstance:FindFirstChildOfClass("Humanoid")

	if RefereeHumanoidRootPart and RefereeHumanoid then
		local now = os.clock()
		if now - lastUpdateTime < UPDATE_INTERVAL then return end
		lastUpdateTime = now

		local dist = (Vector2.new(RefereeHumanoidRootPart.Position.X, RefereeHumanoidRootPart.Position.Z) - Vector2.new(targetPosition.X, targetPosition.Z)).Magnitude
		if dist > MIN_MOVE_DISTANCE then
			RefereeHumanoid:MoveTo(targetPosition)
		end
	end
end

local function SetBallCarrier(Player: Player?): ()
	ballCarrier = Player
	lastUpdateTime = 0
end

local function PlayRequestBall(): ()
	if not refereeInstance then return end
	local targetPos = GetTargetPosition()
	if targetPos then
		local refereeTarget = ComputeRefereeTargetPosition(targetPos)
		if refereeTarget then
			refereeInstance:PivotTo(CFrame.new(refereeTarget))
			local root = refereeInstance:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
	refereeInstance:SetAttribute("RequestBall", true)
	task.delay(0.1, function()
		if refereeInstance then
			refereeInstance:SetAttribute("RequestBall", false)
		end
	end)
end

local function TeleportToPosition(targetPos: Vector3): ()
	if not refereeInstance then return end
	local refereeTarget = ComputeRefereeTargetPosition(targetPos)
	if not refereeTarget then
		return
	end
	refereeInstance:PivotTo(CFrame.new(refereeTarget))
	local root = refereeInstance:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function FTRefereeService.Init(_self: typeof(FTRefereeService)): ()
	InitializeReferee()
	if not refereeConnection then
		refereeConnection = RunService.Heartbeat:Connect(UpdateRefereePosition)
	end
end

function FTRefereeService.Start(_self: typeof(FTRefereeService)): ()
end

function FTRefereeService.SetBallCarrier(_self: typeof(FTRefereeService), Player: Player?): ()
	SetBallCarrier(Player)
end

function FTRefereeService.PlayRequestBall(_self: typeof(FTRefereeService)): ()
	PlayRequestBall()
end

function FTRefereeService.TeleportToPosition(_self: typeof(FTRefereeService), targetPos: Vector3): ()
	TeleportToPosition(targetPos)
end

return FTRefereeService
