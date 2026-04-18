--!strict

local SceneBundleAwakenController: any = require(script.Parent.SceneBundleAwakenController)
local SennaAwakenTimeline: any = require(script.Parent.Timelines.SennaAwakenTimeline)

local CUTSCENE_DURATION: number = 330 / 60

local STYLE_ALIASES: {string} = {
	"Senna",
	"Sena",
	"SennaKobayakawa",
	"SenaKobayakawa",
	"Senna Kobayakawa",
	"Sena Kobayakawa",
}

local SCENE_ALIASES: {string} = {
	"Awaken",
	"Awakening",
}

local Controller: any = SceneBundleAwakenController.new({
	StyleAliases = STYLE_ALIASES,
	SceneAliases = SCENE_ALIASES,
	VfxModelAliases = {
		"VfxModel",
		"VFXModel",
	},
	PlayerModelAliases = {
		"Player",
		"Player 1",
	},
	CameraModelAliases = {
		"Cam",
	},
	CameraPartAliases = {
		"CamPart",
		"CameraPart",
	},
	PlayerAnimationAliases = {
		"Animation",
	},
	CameraAnimationAliases = {
		"Cam",
	},
	CleanupOnCameraAnimationEnd = true,
	WorkspaceRootAliases = {
		["Player 1"] = {
			"Player 1",
			"Player",
		},
		["Shozuki Head"] = {
			"Shozuki Head",
			"Suzuki Head",
		},
	},
	AuthoredPlayerPosition = Vector3.new(84.884, 713.719, -16.025),
	AuthoredVfxModelPosition = Vector3.new(84.415, 712.32, -16.019),
	CutsceneDuration = CUTSCENE_DURATION,
	CameraBindName = "SennaAwakenCamera",
	ShiftlockBlockerName = "SennaAwaken",
	Timeline = SennaAwakenTimeline,
})

return Controller
