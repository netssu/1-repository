--!strict

local Debris: Debris = game:GetService("Debris")
local RunService: RunService = game:GetService("RunService")

local GlobalFunctions = {}

local MIN_DIRECTION_MAGNITUDE: number = 0.001
local DEFAULT_DIRECTION: Vector3 = Vector3.new(1, 0, 0)
local SKILL_LOCK_ATTRIBUTE: string = "FTSkillLocked"

function GlobalFunctions.GetHumanoid(Character: Model?): Humanoid?
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

function GlobalFunctions.GetRoot(Character: Model?): BasePart?
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function GlobalFunctions.GetAnimator(Character: Model?): Animator?
	local HumanoidInstance: Humanoid? = GlobalFunctions.GetHumanoid(Character)
	if not HumanoidInstance then
		return nil
	end
	local AnimatorInstance: Animator? = HumanoidInstance:FindFirstChildOfClass("Animator")
	if AnimatorInstance then
		return AnimatorInstance
	end
	local NewAnimator: Animator = Instance.new("Animator")
	NewAnimator.Parent = HumanoidInstance
	return NewAnimator
end

function GlobalFunctions.FlattenDirection(Direction: Vector3): Vector3
	return Vector3.new(Direction.X, 0, Direction.Z)
end

function GlobalFunctions.ResolveDirection(Direction: Vector3, Fallback: Vector3?): Vector3
	local Flat: Vector3 = GlobalFunctions.FlattenDirection(Direction)
	if Flat.Magnitude > MIN_DIRECTION_MAGNITUDE then
		return Flat.Unit
	end
	local FallbackDirection: Vector3 = Fallback or DEFAULT_DIRECTION
	local FallbackFlat: Vector3 = GlobalFunctions.FlattenDirection(FallbackDirection)
	if FallbackFlat.Magnitude > MIN_DIRECTION_MAGNITUDE then
		return FallbackFlat.Unit
	end
	return DEFAULT_DIRECTION
end

function GlobalFunctions.SetSkillLock(Player: Player?, Character: Model?, Enabled: boolean): ()
	if Player then
		Player:SetAttribute(SKILL_LOCK_ATTRIBUTE, Enabled)
	end
	if Character then
		Character:SetAttribute(SKILL_LOCK_ATTRIBUTE, Enabled)
	end
end

function GlobalFunctions.DisconnectAll(Connections: {RBXScriptConnection}): ()
	for _, Connection in Connections do
		if Connection.Connected then
			Connection:Disconnect()
		end
	end
	table.clear(Connections)
end

function GlobalFunctions.SafeDestroy(InstanceItem: Instance?): ()
	if InstanceItem then
		InstanceItem:Destroy()
	end
end

function GlobalFunctions.WeldToRoot(Root: BasePart, Target: Instance, WeldName: string?): ()
	local Name: string = WeldName or "SkillWeld"

	local function PreparePart(Part: BasePart): ()
		Part.Anchored = false
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
		Part.Massless = true
	end

	local function CreateWeld(Part: BasePart): ()
		local Weld: WeldConstraint = Instance.new("WeldConstraint")
		Weld.Name = Name
		Weld.Part0 = Root
		Weld.Part1 = Part
		Weld.Parent = Part
	end

	if Target:IsA("Model") then
		(Target :: Model):PivotTo(Root.CFrame)
	elseif Target:IsA("BasePart") then
		(Target :: BasePart).CFrame = Root.CFrame
	end

	if Target:IsA("BasePart") then
		local Part: BasePart = Target :: BasePart
		PreparePart(Part)
		CreateWeld(Part)
		return
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			local Part: BasePart = Descendant
			PreparePart(Part)
			CreateWeld(Part)
		end
	end
end

function GlobalFunctions.CreateBodyVelocityBurst(Root: BasePart, Speed: number, Duration: number, Name: string?): BodyVelocity
	local BodyVelocity: BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.Name = Name or "SkillBurstVelocity"
	BodyVelocity.MaxForce = Vector3.new(20000, 20000, 20000)
	BodyVelocity.Parent = Root

	local Connection: RBXScriptConnection? = nil
	Connection = RunService.Stepped:Connect(function()
		if not BodyVelocity.Parent then
			if Connection then
				Connection:Disconnect()
				Connection = nil
			end
			return
		end
		BodyVelocity.Velocity = Root.CFrame.LookVector * Speed
	end)

	Debris:AddItem(BodyVelocity, Duration)
	task.delay(Duration + 0.03, function()
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end
	end)

	return BodyVelocity
end

function GlobalFunctions.StartCameraShake(
	Camera: Camera?,
	Intensity: number,
	Duration: number,
	NoiseSpeed: number?
): () -> ()
	if not RunService:IsClient() or not Camera then
		return function() end
	end

	local Active: boolean = true
	local ElapsedTime: number = 0
	local Offset: Vector3 = Vector3.new(0, 0, 0)
	local Speed: number = NoiseSpeed or 8
	local Connection: RBXScriptConnection

	Connection = RunService.RenderStepped:Connect(function(DeltaTime: number)
		if not Active then
			return
		end
		if not Camera.Parent then
			return
		end

		ElapsedTime += DeltaTime
		local TimeValue: number = ElapsedTime * Speed
		local TargetOffset: Vector3 = Vector3.new(
			math.noise(TimeValue + 13, 0, 0),
			math.noise(TimeValue + 41, 0, 0),
			math.noise(TimeValue + 73, 0, 0)
		) * Intensity
		local Smoothed: Vector3 = Offset:Lerp(TargetOffset, 0.25)
		Camera.CFrame = Camera.CFrame * CFrame.new(Smoothed - Offset)
		Offset = Smoothed
	end)

	local function Stop(): ()
		if not Active then
			return
		end
		Active = false
		if Connection.Connected then
			Connection:Disconnect()
		end
		if Camera.Parent then
			Camera.CFrame = Camera.CFrame * CFrame.new(-Offset)
		end
		Offset = Vector3.new(0, 0, 0)
	end

	if Duration > 0 then
		task.delay(Duration, Stop)
	end

	return Stop
end

return GlobalFunctions

