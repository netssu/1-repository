export type FTGameConfig = {
	MatchEnabled: boolean,
	QuarterDuration: number,
	PlayClockDuration: number,
	DownsToGain: number,
	MaxDowns: number,
	TouchdownPoints: number,
	FieldGoalPoints: number,
	ExtraPointKick: number,
	ExtraPointRun: number,
	TwoMinuteWarning: number,
	TimeoutsPerHalf: number,
	Gravity: number,
	BallRadius: number,
	CatchRadius: number,
	IntermissionDuration: number,
}

export type FTGameState = {
	GameTime: number,
	Down: number,
	Distance: number,
	LineOfScrimmage: number,
	PossessingTeam: number,
	Team1Score: number,
	Team2Score: number,
	Team1Timeouts: number,
	Team2Timeouts: number,
	IntermissionActive: boolean,
	IntermissionTime: number,
}

export type FTPlayerPosition = {
	Name: string,
	DisplayName: string,
	Team: number?,
	Player: Player?,
}

export type FTStyleAbility = {
	Name: string,
	Type: "Style",
	Cooldown: number,
	StaminaCost: number,
	Description: string,
}

export type FTFlowAbility = {
	Name: string,
	Type: "Flow",
	Condition: string,
	Description: string,
}

export type FTAbility = FTStyleAbility | FTFlowAbility

local GAME_CONFIG: FTGameConfig = {
	MatchEnabled = true,
	QuarterDuration = 300,
	PlayClockDuration = 20,
	DownsToGain = 10,
	MaxDowns = 4,
	TouchdownPoints = 6,
	FieldGoalPoints = 3,
	ExtraPointKick = 1,
	ExtraPointRun = 2,
	TwoMinuteWarning = 120,
	TimeoutsPerHalf = 3,
	Gravity = 196.2,
	BallRadius = 1.5,
	CatchRadius = 10,
	IntermissionDuration = 3,
}

local BALL_SPIN_TYPES = {
	function(): CFrame
		return CFrame.Angles((-math.pi/2), tick() % math.pi * 22, 0)
	end,
	function(): CFrame
		return CFrame.Angles(tick() % math.pi * 12, 0, 0)
	end,
	function(): CFrame
		return CFrame.Angles(tick() % math.pi * -12, tick() % math.pi * 6, tick() % math.pi * 6)
	end,
}

local PLAYER_POSITIONS: {FTPlayerPosition} = {
	{ Name = "Center", DisplayName = "Center" },
	{ Name = "Left Line Backer", DisplayName = "Left Line Backer" },
	{ Name = "Left Wide Receiver", DisplayName = "Left Wide Receiver" },
	{ Name = "Quarter Back", DisplayName = "Quarter Back" },
	{ Name = "Right Line Backer", DisplayName = "Right Line Backer" },
	{ Name = "Right Wide Receiver", DisplayName = "Right Wide Receiver" },
	{ Name = "Run Back", DisplayName = "Run Back" },
}

local STYLE_ABILITIES: {[string]: FTStyleAbility} = {}

local FLOW_ABILITIES: {[string]: FTFlowAbility} = {}

local STAMINA_CONFIG = {
	MaxStamina = 100,
	StaminaRegenRate = 10,
	StaminaDrainRate = 25,
	SpinStaminaCost = 0,
}

local SPIN_CONFIG = {
	SpinKeyCode = Enum.KeyCode.R,
	SpinDuration = 0.5,
	SpinCooldown = 2.5,
	SpinSpeedMultiplier = 1.5,
	SpinAnimationNames = { "SpinJuke", "SpinJuke M" },
}

local THROW_CONFIG = {
	MinAimDistance = 6,
	MaxAimDistance = 200,
	MinThrowPower = 20,
	MaxThrowPower = 100,
	ChargeDuration = 1.1,
	MaxThrowDistance = 500,
	TimeDivisor = 60,
	MinFlightTime = 0.9,
	MaxFlightTime = 3.4,
	SpawnVelocityLeadTime = 0.05,
	MaxClientReleaseLead = 0.85,
	MaxClientReleaseBacktrack = 0.4,
	PredictionBlendTime = 0.12,
	PredictionLagCompWindow = 0.2,
	PredictionExpiryBuffer = 0.4,
}

local TACKLE_CONFIG = {
	TackleKeyCode = Enum.KeyCode.F,
	Cooldown = 2.5,
	HitboxSize = Vector3.new(6, 5, 8),
	HitboxForwardOffset = 3,
	VelocityProjection = 0.05,
	StunDuration = 2,
	NotifyDelay = 0.15,
	MinStaminaToRun = 5,
}

local FIELD_DIMENSIONS = {
	FieldLength = 100,
	EndZoneLength = 10,
	FieldWidth = 53.33,
}

return {
	GAME_CONFIG = GAME_CONFIG,
	BALL_SPIN_TYPES = BALL_SPIN_TYPES,
	PLAYER_POSITIONS = PLAYER_POSITIONS,
	STYLE_ABILITIES = STYLE_ABILITIES,
	FLOW_ABILITIES = FLOW_ABILITIES,
	STAMINA_CONFIG = STAMINA_CONFIG,
	SPIN_CONFIG = SPIN_CONFIG,
	THROW_CONFIG = THROW_CONFIG,
	TACKLE_CONFIG = TACKLE_CONFIG,
	FIELD_DIMENSIONS = FIELD_DIMENSIONS,
}
