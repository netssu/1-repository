--!strict

local SceneBundleAwakenController: any = require(script.Parent.SceneBundleAwakenController)
local TesterAwakenTimeline: any = require(script.Parent.Timelines.TesterAwakenTimeline)

local CUTSCENE_DURATION: number = 411 / 60

local Controller: any = SceneBundleAwakenController.new({
	StyleAliases = {
		"Tester",
	},
	SceneAliases = {
		"Awaken",
		"Awakening",
	},
	VfxModelAliases = {
		"VfxModel",
		"VFXModel",
	},
	PlayerModelAliases = {
		"Player",
		"Player 1",
	},
	VictimModelAliases = {
		"Victim",
		"l0feu",
	},
	PlayerAnimationId = "rbxassetid://108384873610738",
	VictimAnimationId = "rbxassetid://117148234614030",
	HideMatchPlayers = true,
	WorkspaceRootAliases = {
		["Player 1"] = {
			"Player 1",
			"Player",
		},
		["l0feu"] = {
			"l0feu",
			"Victim",
		},
	},
	LightingSourceAliases = {
		"csDepthOfField",
		"ColorCorrection",
	},
	AuthoredPlayerPosition = Vector3.new(-170.98, 710.747, 35.345),
	AuthoredVfxModelPosition = Vector3.new(-170.436, 719.35, 29.247),
	FixedVfxHeight = 719.35,
	CutsceneDuration = CUTSCENE_DURATION,
	DisableCamera = true,
	ShiftlockBlockerName = "TesterAwaken",
	Timeline = TesterAwakenTimeline,
})

return Controller
