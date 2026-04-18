--!strict

local TesterSkillUtils: any = require(script.Parent.Init.TesterSkillUtils)

local MONTA_FLIP_WORLD_OFFSET: Vector3 = Vector3.new(0.73, 7.274, -22.603)
local MONTA_FLIP_WORLD_ORIENTATION_OFFSET: Vector3 = Vector3.new(0, 90, 0)
local END_FOV_TARGET: number = 30
local END_FOV_IN_TIME: number = 0.16
local END_FOV_HOLD_TIME: number = 1.85

return TesterSkillUtils.Create({
	TypeName = "MontaFlip",
	SkillFolderAliases = { "Monta Flip" },
	AnimationId = "rbxassetid://93944476600675",
	WorldOffset = MONTA_FLIP_WORLD_OFFSET,
	WorldOrientationOffset = MONTA_FLIP_WORLD_ORIENTATION_OFFSET,
	DetachAttachedParticlePartsOnStart = true,
	FovRequestId = "Tester::MontaFlip::EndFov",
	EndFovTarget = END_FOV_TARGET,
	EndFovInTime = END_FOV_IN_TIME,
	EndFovHoldTime = END_FOV_HOLD_TIME,
	Timeline = {
		{
			Frame = 0,
			Kind = "Vignette",
			LocalOnly = true,
		},
		{
			Frame = 14,
			Kind = "Emit",
			Path = { "HumanoidRootPart", "Won" },
			MeshPath = { "JumoMesh" },
		},
		{
			Frame = 14,
			Kind = "Highlight",
			FillTransparency = 0.5,
			OutlineTransparency = 0,
		},
		{
			Frame = 20,
			Kind = "Highlight",
			FillTransparency = 1,
			OutlineTransparency = 1,
		},
		{
			Frame = 29,
			Kind = "Emit",
			Path = { "MontaJump", "One" },
		},
		{
			Frame = 56,
			Kind = "Emit",
			Path = { "HumanoidRootPart", "Ground" },
			MeshPath = { "JumoMesh2" },
		},
		{
			Frame = 70,
			Kind = "Emit",
			Path = { "HumanoidRootPart", "PreImpact" },
		},
	},
})
