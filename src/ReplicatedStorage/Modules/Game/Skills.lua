--!strict

export type SkillSlotIndex = number
export type StyleSlots = {[string]: string}
export type VFXTypeName = "Start" | "Impact"
export type SkillInputMode = "Tap" | "Hold"

export type SkillInputBehavior = {
	Mode: SkillInputMode,
}

export type SkillVFX = {
	Module: string,
	Type: VFXTypeName,
}

export type SkillDefinition = {
	Id: string,
	Name: string,
	Cooldown: number,
	Benefit: string,
	VFXPath: string,
	Module: string,
	VFX: SkillVFX,
	Input: SkillInputBehavior?,
	RequiresBall: boolean?,
	BlocksWhenHoldingBall: boolean?,
}

export type AwakenInfo = {
	Duration: number,
	CutsceneDuration: number,
	VFXController: string?,
}

export type AwakenData = {
	Info: AwakenInfo,
	Skills: {SkillDefinition},
}

export type StyleData = {
	Skills: {SkillDefinition},
	Awaken: AwakenData?,
}

type SkillsModule = {
	ResolveStyleFromSlots: (SelectedSlot: number, Slots: StyleSlots) -> string,
	GetStyleData: (StyleId: string) -> StyleData?,
	GetSkillList: (StyleId: string, IsAwaken: boolean) -> {SkillDefinition}?,
	GetAwakenDuration: (StyleId: string) -> number,
	GetAwakenCutsceneDuration: (StyleId: string) -> number,
	GetAwakenVFXControllerName: (StyleId: string) -> string?,
	GetInputMapping: () -> {[Enum.KeyCode]: SkillSlotIndex},
	GetAwakenKey: () -> Enum.KeyCode,
	GetSkillInputBehavior: (Skill: SkillDefinition?) -> SkillInputBehavior,
	RequiresBall: (Skill: SkillDefinition?) -> boolean,
	BlocksWhenHoldingBall: (Skill: SkillDefinition?) -> boolean,
	GetAllSkillModuleNames: () -> {string},
	GetVFXModuleIndex: (ModuleName: string) -> number?,
	GetVFXModuleName: (ModuleIndex: number) -> string?,
	GetVFXTypeId: (TypeName: VFXTypeName) -> number?,
	GetVFXTypeName: (TypeId: number) -> VFXTypeName?,
	DefaultStyleId: string,
}

local Skills: SkillsModule = {} :: SkillsModule

--// CONSTANTS
local EMPTY_STRING: string = ""
local SLOT_PREFIX: string = "Slot"

local ZERO: number = 0
local ONE: number = 1
local TWO: number = 2
local THREE: number = 3
local FOUR: number = 4

local DEFAULT_STYLE_ID: string = "Default"
local FALLBACK_STYLE_ID: string = "SenaKobayakawa"
local DEFAULT_SELECTED_SLOT: number = ONE
local MIN_STYLE_SLOT: number = ONE
local MAX_STYLE_SLOT: number = FOUR

local INPUT_SLOT_C: number = ONE
local INPUT_SLOT_V: number = TWO
local INPUT_SLOT_B: number = THREE

local AWAKEN_KEY: Enum.KeyCode = Enum.KeyCode.G

local VFX_TYPE_START_ID: number = ONE
local VFX_TYPE_IMPACT_ID: number = TWO

local PHANTOM_DASH_VFX_INDEX: number = ONE
local DEVIL_LASER_VFX_INDEX: number = TWO
local MONTA_FLIP_VFX_INDEX: number = THREE
local RED_DASH_VFX_INDEX: number = FOUR
local SENA_AWAKEN_CUTSCENE_DURATION: number = 330 / 60
local HIRUMA_AWAKEN_CUTSCENE_DURATION: number = 574 / 60
local FAT_GUY_AWAKEN_CUTSCENE_DURATION: number = 300 / 60
local TESTER_AWAKEN_CUTSCENE_DURATION: number = 411 / 60

local INPUT_MAPPING: {[Enum.KeyCode]: SkillSlotIndex} = {
	[Enum.KeyCode.C] = INPUT_SLOT_C,
	[Enum.KeyCode.V] = INPUT_SLOT_V,
	[Enum.KeyCode.B] = INPUT_SLOT_B,
}

local DEFAULT_INPUT_BEHAVIOR: SkillInputBehavior = {
	Mode = "Tap",
}

local VFX_TYPE_IDS: {[VFXTypeName]: number} = {
	Start = VFX_TYPE_START_ID,
	Impact = VFX_TYPE_IMPACT_ID,
}

local VFX_TYPE_NAMES: {[number]: VFXTypeName} = {
	[VFX_TYPE_START_ID] = "Start",
	[VFX_TYPE_IMPACT_ID] = "Impact",
}

local VFX_MODULES: {string} = {
	[PHANTOM_DASH_VFX_INDEX] = "PhantomDash",
	[DEVIL_LASER_VFX_INDEX] = "DevilLaser",
	[MONTA_FLIP_VFX_INDEX] = "MontaFlip",
	[RED_DASH_VFX_INDEX] = "RedDash",
}

local VFX_INDEX_BY_NAME: {[string]: number} = {}
for Index, Name in VFX_MODULES do
	VFX_INDEX_BY_NAME[Name] = Index
end

local STYLE_ALIASES: {[string]: string} = {
	Senna = "SenaKobayakawa",
	YoichiHiruma = "Hiruma",
	Kurita = "FatGuy",
	Kuritas = "FatGuy",
	FatGuy = "FatGuy",
	FatGuys = "FatGuy",
	Tester = "Tester",
}

local STYLE_DATA: {[string]: StyleData} = {
	Default = {
		Skills = {
			{
				Id = "Default_Skill_1",
				Name = "Phantom Dash",
				Cooldown = 1,
				Benefit = "Fast straight-line dash.",
				VFXPath = "PhantomDash",
				Module = "PhantomDash",
				VFX = {
					Module = "PhantomDash",
					Type = "Start",
				},
			},
		},
		Awaken = {
			Info = {
				Duration = 15,
				CutsceneDuration = ZERO,
				VFXController = nil,
			},
			Skills = {
				{
					Id = "Default_Awaken_1",
					Name = "Phantom Dash Awaken",
					Cooldown = 6,
					Benefit = "Enhanced dash during Awaken.",
					VFXPath = "PhantomDash",
					Module = "PhantomDash",
					VFX = {
						Module = "PhantomDash",
						Type = "Start",
					},
				},
			},
		},
	},
	SenaKobayakawa = {
		Skills = {
			{
				Id = "Sena_Skill_1",
				Name = "Phantom Dash",
				Cooldown = 1,
				Benefit = "High-speed dash inspired by Sena.",
				VFXPath = "PhantomDash",
				Module = "PhantomDash",
				VFX = {
					Module = "PhantomDash",
					Type = "Start",
				},
			},
			{
				Id = "Sena_Skill_2",
				Name = "Devil Laser",
				Cooldown = 4,
				Benefit = "Zig-zag dash with laser finish.",
				VFXPath = "DevilLaser",
				Module = "DevilLaser",
				VFX = {
					Module = "DevilLaser",
					Type = "Start",
				},
			},
		},
		Awaken = {
			Info = {
				Duration = 18,
				CutsceneDuration = SENA_AWAKEN_CUTSCENE_DURATION,
				VFXController = "SennaAwaken",
			},
			Skills = {
				{
					Id = "Sena_Awaken_1",
					Name = "Phantom Dash Awaken",
					Cooldown = 5,
					Benefit = "Extreme dash during Awaken.",
					VFXPath = "PhantomDash",
					Module = "PhantomDash",
					VFX = {
						Module = "PhantomDash",
						Type = "Start",
					},
				},
			},
		},
	},
	Hiruma = {
		Skills = {
			[1] = {
				Id = "Hiruma_Skill_1",
				Name = "Shadow",
				Cooldown = 8,
				Benefit = "Rapid phantom dash behind a target ahead.",
				VFXPath = "Shadow",
				Module = "HirumaShadow",
				VFX = {
					Module = "Shadow",
					Type = "Start",
				},
				RequiresBall = false,
			},
			[2] = {
				Id = "Hiruma_Skill_2",
				Name = "Throw Pass",
				Cooldown = 7,
				Benefit = "Fast curved throw toward the mouse impact point.",
				VFXPath = "Throw",
				Module = "HirumaThrow",
				VFX = {
					Module = "Throw",
					Type = "Start",
				},
			},
		},
		Awaken = {
			Info = {
				Duration = 18,
				CutsceneDuration = HIRUMA_AWAKEN_CUTSCENE_DURATION,
				VFXController = "HirumaAwaken",
			},
			Skills = {
				[1] = {
					Id = "Hiruma_Awaken_1",
					Name = "Shadow",
					Cooldown = 6,
					Benefit = "Longer and faster phantom dash during Awaken.",
					VFXPath = "Shadow",
					Module = "HirumaShadow",
					VFX = {
						Module = "Shadow",
						Type = "Start",
					},
					RequiresBall = false,
				},
				[2] = {
					Id = "Hiruma_Awaken_2",
					Name = "Throw Pass",
					Cooldown = 5,
					Benefit = "Long-range accelerated throw during Awaken.",
					VFXPath = "Throw",
					Module = "HirumaThrow",
					VFX = {
						Module = "Throw",
						Type = "Start",
					},
				},
				[3] = {
					Id = "Hiruma_Awaken_3",
					Name = "Perfect Pass",
					Cooldown = 18,
					Benefit = "Triggers a full-team pass cutscene and redirects possession.",
					VFXPath = "PerfectPass",
					Module = "PerfectPass",
					VFX = {
						Module = "PerfectPass",
						Type = "Start",
					},
				},
			},
		},
	},
	FatGuy = {
		Skills = {
			[1] = {
				Id = "FatGuy_Skill_1",
				Name = "Jump Down",
				Cooldown = 9,
				Benefit = "Tap to leap to the airborne ball height and catch it if it is within range.",
				RequiresBall = false,
				VFXPath = "Move1",
				Module = "FatGuyMove1",
				VFX = {
					Module = "Move1",
					Type = "Start",
				},
				Input = {
					Mode = "Tap",
				},
			},
			[2] = {
				Id = "FatGuy_Skill_2",
				Name = "Speed",
				Cooldown = 7,
				Benefit = "Forward speed rush with smoother ground tracking and layered impact effects.",
				VFXPath = "Move2",
				Module = "FatGuyMove2",
				VFX = {
					Module = "Move2",
					Type = "Start",
				},
			},
		},
		Awaken = {
			Info = {
				Duration = 18,
				CutsceneDuration = FAT_GUY_AWAKEN_CUTSCENE_DURATION,
				VFXController = "FatGuyAwaken",
			},
			Skills = {
				[1] = {
					Id = "FatGuy_Awaken_1",
					Name = "Jump Down",
					Cooldown = 9,
					Benefit = "Tap to leap to the airborne ball height with a wider catch zone during Awaken.",
					RequiresBall = false,
					VFXPath = "Move1",
					Module = "FatGuyMove1",
					VFX = {
						Module = "Move1",
						Type = "Start",
					},
					Input = {
						Mode = "Tap",
					},
				},
				[2] = {
					Id = "FatGuy_Awaken_2",
					Name = "Speed",
					Cooldown = 7,
					Benefit = "Longer and faster rush during Awaken.",
					VFXPath = "Move2",
					Module = "FatGuyMove2",
					VFX = {
						Module = "Move2",
						Type = "Start",
					},
				},
			},
		},
	},
	Tester = {
		Skills = {
			[1] = {
				Id = "Tester_Skill_1",
				Name = "Monta Flip",
				Cooldown = 7,
				Benefit = "A legendary forward flip dash with layered impact effects.",
				VFXPath = "Monta Flip",
				Module = "MontaFlip",
				VFX = {
					Module = "MontaFlip",
					Type = "Start",
				},
				RequiresBall = false,
				BlocksWhenHoldingBall = true,
			},
			[2] = {
				Id = "Tester_Skill_2",
				Name = "Red Dash",
				Cooldown = 8,
				Benefit = "A chained legendary dash with repeated burst impacts while carrying the ball.",
				VFXPath = "Red Dash",
				Module = "RedDash",
				VFX = {
					Module = "RedDash",
					Type = "Start",
				},
				RequiresBall = true,
			},
		},
		Awaken = {
			Info = {
				Duration = 18,
				CutsceneDuration = TESTER_AWAKEN_CUTSCENE_DURATION,
				VFXController = "TesterAwaken",
			},
			Skills = {
				[1] = {
					Id = "Tester_Awaken_1",
					Name = "Monta Flip",
					Cooldown = 6,
					Benefit = "A stronger forward flip dash during Awaken.",
					VFXPath = "Monta Flip",
					Module = "MontaFlip",
					VFX = {
						Module = "MontaFlip",
						Type = "Start",
					},
					RequiresBall = false,
					BlocksWhenHoldingBall = true,
				},
				[2] = {
					Id = "Tester_Awaken_2",
					Name = "Red Dash",
					Cooldown = 7,
					Benefit = "A faster chained dash sequence during Awaken.",
					VFXPath = "Red Dash",
					Module = "RedDash",
					VFX = {
						Module = "RedDash",
						Type = "Start",
					},
					RequiresBall = true,
				},
				[3] = {
					Id = "Tester_Awaken_3",
					Name = "Red Feint",
					Cooldown = 7,
					Benefit = "A faster chained dash sequence during Awaken.",
					VFXPath = "Red Feint",
					Module = "RedFeint",
					VFX = {
						Module = "RedFeint",
						Type = "Start",
					},
					RequiresBall = false,
				},
			},
		},
	},
}

local function GetFallbackStyleId(): string
	if STYLE_DATA[FALLBACK_STYLE_ID] then
		return FALLBACK_STYLE_ID
	end
	return DEFAULT_STYLE_ID
end

local function ResolveStyleAlias(StyleId: string): string
	local Alias: string? = STYLE_ALIASES[StyleId]
	if Alias then
		return Alias
	end
	return StyleId
end

local function ResolveKnownStyleOrFallback(StyleId: string): string
	local ResolvedStyleId: string = ResolveStyleAlias(StyleId)
	if STYLE_DATA[ResolvedStyleId] ~= nil then
		return ResolvedStyleId
	end
	return GetFallbackStyleId()
end

local function ClampSelectedSlot(SelectedSlot: number): number
	local SlotIndex: number = math.floor(SelectedSlot)
	if SlotIndex < MIN_STYLE_SLOT then
		return DEFAULT_SELECTED_SLOT
	end
	if SlotIndex > MAX_STYLE_SLOT then
		return DEFAULT_SELECTED_SLOT
	end
	return SlotIndex
end

function Skills.ResolveStyleFromSlots(SelectedSlot: number, Slots: StyleSlots): string
	local SlotIndex: number = ClampSelectedSlot(SelectedSlot)
	local SlotKey: string = SLOT_PREFIX .. tostring(SlotIndex)
	local StyleId: string? = Slots[SlotKey]
	if not StyleId or StyleId == EMPTY_STRING then
		return GetFallbackStyleId()
	end
	StyleId = ResolveStyleAlias(StyleId)
	if STYLE_DATA[StyleId] == nil then
		return GetFallbackStyleId()
	end
	return StyleId
end

function Skills.GetStyleData(StyleId: string): StyleData?
	local ResolvedStyleId: string = ResolveKnownStyleOrFallback(StyleId)
	return STYLE_DATA[ResolvedStyleId]
end

function Skills.GetSkillList(StyleId: string, IsAwaken: boolean): {SkillDefinition}?
	local ResolvedStyleId: string = ResolveKnownStyleOrFallback(StyleId)
	local Style: StyleData? = STYLE_DATA[ResolvedStyleId]
	if not Style then
		return nil
	end
	if IsAwaken then
		local Awaken: AwakenData? = Style.Awaken
		if not Awaken then
			local Fallback: StyleData? = STYLE_DATA[GetFallbackStyleId()]
			local FallbackAwaken: AwakenData? = Fallback and Fallback.Awaken or nil
			return FallbackAwaken and FallbackAwaken.Skills or nil
		end
		return Awaken.Skills
	end
	return Style.Skills
end

function Skills.GetAwakenDuration(StyleId: string): number
	local ResolvedStyleId: string = ResolveKnownStyleOrFallback(StyleId)
	local Style: StyleData? = STYLE_DATA[ResolvedStyleId]
	if not Style or not Style.Awaken then
		return ZERO
	end
	return Style.Awaken.Info.Duration
end

function Skills.GetAwakenCutsceneDuration(StyleId: string): number
	local ResolvedStyleId: string = ResolveKnownStyleOrFallback(StyleId)
	local Style: StyleData? = STYLE_DATA[ResolvedStyleId]
	if not Style or not Style.Awaken then
		return ZERO
	end
	return Style.Awaken.Info.CutsceneDuration
end

function Skills.GetAwakenVFXControllerName(StyleId: string): string?
	local ResolvedStyleId: string = ResolveKnownStyleOrFallback(StyleId)
	local Style: StyleData? = STYLE_DATA[ResolvedStyleId]
	if not Style or not Style.Awaken then
		return nil
	end
	return Style.Awaken.Info.VFXController
end

function Skills.GetInputMapping(): {[Enum.KeyCode]: SkillSlotIndex}
	return INPUT_MAPPING
end

function Skills.GetAwakenKey(): Enum.KeyCode
	return AWAKEN_KEY
end

function Skills.GetSkillInputBehavior(Skill: SkillDefinition?): SkillInputBehavior
	if Skill and Skill.Input then
		return Skill.Input
	end
	return DEFAULT_INPUT_BEHAVIOR
end

function Skills.RequiresBall(Skill: SkillDefinition?): boolean
	return Skill ~= nil and Skill.RequiresBall ~= false
end

function Skills.BlocksWhenHoldingBall(Skill: SkillDefinition?): boolean
	return Skill ~= nil and Skill.BlocksWhenHoldingBall == true
end

function Skills.GetAllSkillModuleNames(): {string}
	local ModuleNames: {string} = {}
	local Seen: {[string]: boolean} = {}

	local function CollectFromList(List: {SkillDefinition}?): ()
		if not List then
			return
		end
		for _, Skill in pairs(List) do
			local ModuleName: string = Skill.Module
			if ModuleName ~= EMPTY_STRING and not Seen[ModuleName] then
				Seen[ModuleName] = true
				table.insert(ModuleNames, ModuleName)
			end
		end
	end

	for _, Style in STYLE_DATA do
		CollectFromList(Style.Skills)
		if Style.Awaken then
			CollectFromList(Style.Awaken.Skills)
		end
	end

	return ModuleNames
end

function Skills.GetVFXModuleIndex(ModuleName: string): number?
	return VFX_INDEX_BY_NAME[ModuleName]
end

function Skills.GetVFXModuleName(ModuleIndex: number): string?
	return VFX_MODULES[ModuleIndex]
end

function Skills.GetVFXTypeId(TypeName: VFXTypeName): number?
	return VFX_TYPE_IDS[TypeName]
end

function Skills.GetVFXTypeName(TypeId: number): VFXTypeName?
	return VFX_TYPE_NAMES[TypeId]
end

Skills.DefaultStyleId = DEFAULT_STYLE_ID

return Skills :: SkillsModule
