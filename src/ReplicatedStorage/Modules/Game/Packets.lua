--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Packages.Packet)

local EMPTY_RESPONSE = table.freeze({})

local Packets = {
	PlaySound = Packet("PlaySound", Packet.NumberF64, Packet.Boolean8),
	PlaySoundAt = Packet("PlaySoundAt", Packet.NumberF64, Packet.Instance),
	Summon = Packet("Summon", Packet.String):Response(Packet.String),

	Admin = Packet("Admin", Packet.String):Response(Packet.Any),
	Command = Packet("Command", Packet.Any),

	BuySpin = Packet("BuySpin", Packet.String):Response(Packet.String),
	RequestSpin = Packet("RequestSpin", Packet.String, Packet.Any):Response(Packet.Any),
	RequestSkipSpin = Packet("RequestSkipSpin", Packet.String):Response(Packet.Any, Packet.Any),
	SpinResult = Packet("SpinResult", Packet.String, Packet.String, Packet.Any),

	RequestEquip = Packet("RequestEquip", Packet.String),
	RequestEquipCosmetic = Packet("RequestEquipCosmetic", Packet.String),
	RequestEquipEmote = Packet("RequestEquipEmote", Packet.String),

	RequestEquipCard = Packet("RequestEquipCard", Packet.String),
	BallThrow = Packet("BallThrow", Packet.Vector3F32, Packet.NumberF64, Packet.NumberF32, Packet.NumberF64, Packet.NumberU16, Packet.Vector3F32),
	BallCatch = Packet("BallCatch"),
	BallKick = Packet("BallKick", Packet.Vector3F32, Packet.NumberF64, Packet.NumberF32),
	BallFumble = Packet("BallFumble"),

	ExtraPointKickRequest = Packet("ExtraPointKickRequest", Packet.Vector3F32, Packet.NumberF64, Packet.NumberF32, Packet.NumberF64, Packet.NumberU16, Packet.Vector3F32),
	ExtraPointKickCinematic = Packet("ExtraPointKickCinematic", Packet.NumberF64, Packet.NumberF32),
	ExtraPointResult = Packet("ExtraPointResult", Packet.Boolean8),
	ExtraPointPreCam = Packet("ExtraPointPreCam", Packet.NumberF64, Packet.NumberF32, Packet.String),
	ExtraPointKickerCam = Packet("ExtraPointKickerCam", Packet.NumberF64, Packet.NumberF32),
	ExtraPointStart = Packet("ExtraPointStart", Packet.NumberU8, Packet.NumberF32),
	ExtraPointEnd = Packet("ExtraPointEnd"),

	ScoreNotify = Packet("ScoreNotify", Packet.String, Packet.String, Packet.NumberF32),
	TouchdownShowcase = Packet("TouchdownShowcase", Packet.NumberF64, Packet.String, Packet.NumberF64, Packet.NumberF64, Packet.NumberF64, Packet.NumberF32),
	TeleportFade = Packet("TeleportFade", Packet.NumberF32),
	MatchIntroCutscene = Packet("MatchIntroCutscene", Packet.Any),
	MatchIntroFinished = Packet("MatchIntroFinished", Packet.NumberF64),
	SpinActivate = Packet("SpinActivate"),
	RunningStateUpdate = Packet("RunningStateUpdate", Packet.Boolean8),
	TackleAttempt = Packet("TackleAttempt", Packet.CFrameF32U16, Packet.Vector3F32),
	TackleStun = Packet("TackleStun", Packet.NumberF32),
	TackleImpact = Packet("TackleImpact", Packet.NumberF64, Packet.NumberF32),
	RagdollState = Packet("RagdollState", Packet.Boolean8, Packet.NumberF32),
	PositionSelect = Packet("PositionSelect", Packet.String, Packet.NumberU8),
	PositionSelectResult = Packet("PositionSelectResult", Packet.Boolean8, Packet.NumberU8, Packet.String),
	BallStateUpdate = Packet("BallStateUpdate"),
	ThrowPassCatch = Packet("ThrowPassCatch", Packet.String),
	DebugResetRequest = Packet("DebugResetRequest"),
	DebugResetReport = Packet("DebugResetReport", Packet.Any),
	PlayerStaminaUpdate = Packet("PlayerStaminaUpdate", Packet.NumberF64),
	LeaveMatch = Packet("LeaveMatch"),
	PurchaseCompleted = Packet("PurchaseCompleted", Packet.String, Packet.String),
	RequestRedeemCode = Packet("RequestRedeemCode", Packet.String):Response(Packet.String),
	UpdateSetting = Packet("UpdateSetting", Packet.String, Packet.Any),
	ChangeSetting = Packet("ChangeSetting", Packet.String, Packet.String),
	SkillRequest = Packet("SkillRequest", Packet.NumberU8, Packet.Vector3F32),
	SkillHoldRequest = Packet("SkillHoldRequest", Packet.NumberU8, Packet.NumberU8, Packet.NumberF32, Packet.Vector3F32),
	HirumaThrowAim = Packet("HirumaThrowAim", Packet.Vector3F32),
	SkillCooldown = Packet("SkillCooldown", Packet.NumberU8, Packet.NumberF32),
	SkillVFX = Packet("SkillVFX", Packet.NumberU8, Packet.NumberU8, Packet.Vector3F32),
	Replicator = Packet("Replicator", Packet.Any),
	SkillPhase = Packet("SkillPhase", Packet.String, Packet.NumberU16, Packet.String),
	SkillMarker = Packet("SkillMarker", Packet.String, Packet.NumberU16, Packet.String),
	SkillDirection = Packet("SkillDirection", Packet.String, Packet.NumberU16, Packet.Vector3F32),
	AwakenRequest = Packet("AwakenRequest"),
	FlowActivateRequest = Packet("FlowActivateRequest"),
	AwakenStatus = Packet("AwakenStatus", Packet.String, Packet.NumberF32),
	AwakenCutscene = Packet("AwakenCutscene", Packet.String, Packet.NumberF64, Packet.NumberF32),
	AwakenCutsceneEnded = Packet("AwakenCutsceneEnded", Packet.CFrameF32U16),
	PerfectPassCutscene = Packet(
		"PerfectPassCutscene",
		Packet.NumberF64,
		Packet.Vector3F32,
		Packet.Vector3F32,
		Packet.NumberF32,
		Packet.NumberF64,
		Packet.NumberF64,
		Packet.NumberF64,
		Packet.NumberF64
	),
	PerfectPassCutsceneEnded = Packet("PerfectPassCutsceneEnded", Packet.NumberF64, Packet.Any),

	Slots = Packet("Slots", Packet.String, Packet.Any):Response(Packet.Any)
}

Packets.Admin.ResponseTimeout = 20
Packets.Admin.ResponseTimeoutValue = "TimedOut"
Packets.Slots.ResponseTimeout = 20
Packets.Slots.ResponseTimeoutValue = EMPTY_RESPONSE

return Packets
