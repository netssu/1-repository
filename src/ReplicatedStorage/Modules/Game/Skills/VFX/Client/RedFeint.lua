--!strict

local TesterSkillUtils: any = require(script.Parent.Init.TesterSkillUtils)

local ANIMATION_ID: string = "rbxassetid://134400225225538"
local UNUSED_END_FOV_TARGET: number = 70
local UNUSED_END_FOV_TIME: number = 0.1
local UNUSED_END_FOV_HOLD: number = 0.1

local function CreateHighlightEvent(Frame: number, FillTransparency: number, OutlineTransparency: number): {[string]: any}
	return {
		Frame = Frame,
		Kind = "Highlight",
		FillTransparency = FillTransparency,
		OutlineTransparency = OutlineTransparency,
	}
end

local function CreateEmitEvent(Path: {string}): {[string]: any}
	return {
		Frame = 0,
		Kind = "Emit",
		Path = Path,
	}
end

local function CreateVignetteEvent(): {[string]: any}
	return {
		Frame = 0,
		Kind = "Vignette",
		LocalOnly = true,
	}
end

return TesterSkillUtils.Create({
	TypeName = "RedDash",
	SkillFolderAliases = { "Red Dash" },
	AnimationId = ANIMATION_ID,
	WorldOffset = Vector3.zero,
	WorldOrientationOffset = Vector3.zero,
	PlayAnimationOnClient = false,
	SendStartPhase = false,
	AttachWorldCloneToRoot = false,
	AnchorDetachedWorldClone = true,
	WorldTemplateAliases = { "QuickPorts" },
	FovRequestId = "Tester::RedDash::UnusedEndFov",
	EndFovTarget = UNUSED_END_FOV_TARGET,
	EndFovInTime = UNUSED_END_FOV_TIME,
	EndFovHoldTime = UNUSED_END_FOV_HOLD,
	Timeline = {
		{
			Frame = 0,
			Kind = "Vignette",
			LocalOnly = true,
		},
		CreateHighlightEvent(34, 1, 1),
		CreateHighlightEvent(39, 0.5, 0.35),
		CreateHighlightEvent(47, 1, 1),
		CreateHighlightEvent(51, 0.5, 0.35),
		CreateHighlightEvent(60, 1, 1),
		CreateHighlightEvent(71, 1, 1),
		CreateHighlightEvent(75, 0.5, 0.35),
		CreateHighlightEvent(81, 1, 1),
		CreateHighlightEvent(84, 1, 1),
		CreateHighlightEvent(88, 0.5, 0.35),
		CreateHighlightEvent(97, 1, 1),
	},
	MarkerEvents = {
		Start1 = {
			CreateEmitEvent({ "Torso", "Body" }),
			CreateEmitEvent({ "One" }),
		},
		Start2 = {
			CreateEmitEvent({ "Torso", "Body" }),
			CreateEmitEvent({ "Two" }),
		},
		Start3 = {
			CreateEmitEvent({ "Torso", "Body" }),
			CreateEmitEvent({ "Three" }),
		},
		Tp1 = {
			CreateVignetteEvent(),
			CreateEmitEvent({ "HumanoidRootPart", "One" }),
		},
		Tp2 = {
			CreateVignetteEvent(),
			CreateEmitEvent({ "HumanoidRootPart", "One" }),
		},
		Tp3 = {
			CreateVignetteEvent(),
			CreateEmitEvent({ "HumanoidRootPart", "One" }),
		},
		Star = {
			CreateEmitEvent({ "Right Arm", "Star" }),
		},
	},
})
