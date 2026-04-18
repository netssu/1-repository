--!strict

local RunService: RunService = game:GetService("RunService")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local FTBallService: any = require(ServerScriptService.Services.BallService)
local ForwardDashSkill: any = require(script.Parent.Utils.ForwardDashSkill)

local DASH_SPEED: number = 150
local FAILSAFE_TIME: number = 2.4
local END_SLOW_DURATION: number = 0.05
local POST_END_MOVEMENT_LOCK_DURATION: number = 0.03
local APPLY_DASH_VELOCITY: boolean = true
local HOMING_BALL_RANGE: number = 48
local PRIORITY_CATCH_RADIUS: number = 16
local PRIORITY_CATCH_WEIGHT: number = 100
local MIN_DIRECTION_MAGNITUDE: number = 0.01
local DASH_RESPONSIVENESS: number = 320
local DASH_RIGIDITY_ENABLED: boolean = false
local END_MAX_FORCE: number = 650000
local END_RESPONSIVENESS: number = 220
local END_RIGIDITY_ENABLED: boolean = false
local DASH_DIRECTION_LERP_ALPHA: number = 0.3

local function FlattenDirection(Direction: Vector3): Vector3
	return Vector3.new(Direction.X, 0, Direction.Z)
end

local function ResolveTargetBall(_Character: Model, Root: BasePart): BasePart?
	local BallState = FTBallService:GetBallState()
	if not BallState or BallState:GetPossession() ~= nil then
		return nil
	end
	if FTBallService:GetExternalHolder() ~= nil then
		return nil
	end

	local Ball: BasePart? = FTBallService:GetBallInstance()
	if not Ball or Ball.Parent == nil then
		return nil
	end

	local ToBall: Vector3 = FlattenDirection(Ball.Position - Root.Position)
	if ToBall.Magnitude < MIN_DIRECTION_MAGNITUDE or ToBall.Magnitude > HOMING_BALL_RANGE then
		return nil
	end

	local Forward: Vector3 = FlattenDirection(Root.CFrame.LookVector)
	if Forward.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return nil
	end
	if Forward.Unit:Dot(ToBall.Unit) <= 0 then
		return nil
	end

	return Ball
end

local function ArmCatchPriority(Player: Player): ()
	FTBallService:SetCatchPriority(Player, PRIORITY_CATCH_RADIUS, FAILSAFE_TIME, PRIORITY_CATCH_WEIGHT)
	FTBallService:TryCatchByPlayer(Player, PRIORITY_CATCH_RADIUS, true)
end

return ForwardDashSkill.Create({
	TypeName = "MontaFlip",
	DashSpeed = DASH_SPEED,
	FailsafeTime = FAILSAFE_TIME,
	EndSlowDuration = END_SLOW_DURATION,
	PostEndMovementLockDuration = POST_END_MOVEMENT_LOCK_DURATION,
	ApplyDashVelocity = APPLY_DASH_VELOCITY,
	DashResponsiveness = DASH_RESPONSIVENESS,
	DashRigidityEnabled = DASH_RIGIDITY_ENABLED,
	EndMaxForce = END_MAX_FORCE,
	EndResponsiveness = END_RESPONSIVENESS,
	EndRigidityEnabled = END_RIGIDITY_ENABLED,
	DashDirectionLerpAlpha = DASH_DIRECTION_LERP_ALPHA,
	AlignPositionName = "MontaFlipAlignPosition",
	AlignAttachmentName = "MontaFlipAlignAttachment",
	OrientationAttachmentName = "MontaFlipOrientationAttachment",
	OrientationConstraintName = "MontaFlipOrientationConstraint",
	ResolveStartDirection = function(_Player: Player, Character: Model, Root: BasePart, _State: any, DefaultDirection: Vector3): Vector3?
		local Ball: BasePart? = ResolveTargetBall(Character, Root)
		if not Ball then
			return DefaultDirection
		end

		return FlattenDirection(Ball.Position - Root.Position)
	end,
	ResolveDashDirection = function(_Player: Player, Character: Model, Root: BasePart, _State: any, CurrentDirection: Vector3): Vector3?
		local Ball: BasePart? = ResolveTargetBall(Character, Root)
		if not Ball then
			return CurrentDirection
		end

		return FlattenDirection(Ball.Position - Root.Position)
	end,
	OnSkillActivated = function(Player: Player, _Character: Model, _Root: BasePart, _State: any, _Token: number): ()
		ArmCatchPriority(Player)
	end,
	OnDashStarted = function(Player: Player, _Character: Model, _Root: BasePart, State: any, Token: number): ()
		ArmCatchPriority(Player)
		task.spawn(function()
			while State.Active and State.Token == Token do
				FTBallService:TryCatchByPlayer(Player, PRIORITY_CATCH_RADIUS, true)
				RunService.Heartbeat:Wait()
			end
		end)
	end,
	OnDashCleared = function(Player: Player, _Character: Model?, _Root: BasePart?, _State: any, _Token: number): ()
		FTBallService:ClearCatchPriority(Player)
	end,
})
