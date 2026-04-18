--!strict

local SceneBundleAwakenController: any = require(script.Parent.SceneBundleAwakenController)
local FatGuyAwakenTimeline: any = require(script.Parent.Timelines.FatGuyAwakenTimeline)

local CUTSCENE_DURATION: number = 300 / 60

local Controller: any = SceneBundleAwakenController.new({
	StyleAliases = {
		"Kurita",
		"Kuritas",
		"FatGuys",
		"FatGuy",
	},
	SceneAliases = {
		"Awaken",
		"Awakening",
	},
	GuiContainerAliases = {
		"Gui",
		"GUI",
	},
	VfxModelAliases = {
		"VFXModel",
	},
	PlayerModelAliases = {
		"Player",
	},
	CameraModelAliases = {
		"Cam",
	},
	CameraPartAliases = {
		"CamPart",
	},
	PlayerAnimationId = "rbxassetid://130692247634665",
	CameraAnimationId = "rbxassetid://133861434396390",
	AuthoredPlayerPosition = Vector3.new(23.637, 713.708, 42.19),
	AuthoredVfxModelPosition = Vector3.new(23.275, 712.087, 42.216),
	CutsceneDuration = CUTSCENE_DURATION,
	CameraBindName = "FatGuyAwakenCamera",
	ShiftlockBlockerName = "FatGuyAwaken",
	Timeline = FatGuyAwakenTimeline,
})

return Controller
