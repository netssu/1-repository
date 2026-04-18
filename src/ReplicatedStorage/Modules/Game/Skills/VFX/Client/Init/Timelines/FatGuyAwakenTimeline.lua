--!strict

export type AwakenAction = "Emit" | "Enable" | "Disable" | "SetProperty" | "MarkerCode"

export type AwakenEvent = {
	Frame: number,
	Action: AwakenAction,
	Path: string?,
	Property: string?,
	Value: any?,
	Amount: number?,
	Code: string?,
}

local MAX_FRAME: number = 300
local FPS: number = 60
local CAMERA_RELEASE_FRAME: number = 266
local CAMERA_RELEASE_MARKER: string = "__ReleaseCamera__"

local EVENTS: {AwakenEvent} = {}

local function AddSetProperty(Frame: number, Path: string, Property: string, Value: any): ()
	table.insert(EVENTS, {
		Frame = Frame,
		Action = "SetProperty",
		Path = Path,
		Property = Property,
		Value = Value,
	})
end

local function AddMarker(Frame: number, Path: string, Code: string): ()
	table.insert(EVENTS, {
		Frame = Frame,
		Action = "MarkerCode",
		Path = Path,
		Code = Code,
	})
end

AddSetProperty(0, "Workspace.CurrentCamera", "AttachToPart", nil)

local CameraFovFrames = {
	{0, 47.30735},
	{1, 49.949459},
	{3, 54.21191},
	{4, 60.042156},
	{5, 67.199524},
	{7, 74.934822},
	{8, 81.679474},
	{9, 85.123917},
	{11, 86.071487},
	{12, 86.93898},
	{13, 87.727188},
	{15, 88.437508},
	{16, 89.071968},
	{17, 89.633163},
	{19, 90.124161},
	{20, 90.548531},
	{21, 90.910194},
	{23, 91.213455},
	{24, 91.462921},
	{25, 91.663445},
	{27, 91.820091},
	{28, 91.93808},
	{29, 92.022766},
	{31, 92.079605},
	{32, 92.114105},
	{33, 92.131836},
	{35, 92.138359},
	{36, 92.139282},
	{37, 92.017128},
	{39, 91.673264},
	{40, 91.142891},
	{41, 90.46209},
	{43, 89.666794},
	{44, 88.792061},
	{45, 87.871506},
	{47, 86.936943},
	{48, 86.018173},
	{49, 85.143089},
	{51, 84.337708},
	{52, 83.626579},
	{53, 83.033165},
	{55, 82.580338},
	{56, 82.291046},
	{57, 82.189079},
	{59, 82.19133},
	{60, 82.207031},
	{61, 82.249695},
	{63, 82.332863},
	{64, 82.470299},
	{65, 82.676018},
	{67, 82.964523},
	{68, 83.351006},
	{69, 84.907768},
	{71, 87.875069},
	{72, 90.884171},
	{73, 92.282112},
	{75, 91.655167},
	{76, 90.18663},
	{77, 88.481682},
	{79, 87.092186},
	{80, 86.519844},
	{81, 86.834602},
	{83, 87.73024},
	{84, 89.143608},
	{85, 91.018784},
	{87, 93.3004},
	{88, 95.927818},
	{89, 98.829659},
	{91, 101.919304},
	{92, 105.091415},
	{93, 108.220169},
	{95, 111.159744},
	{96, 113.747429},
	{97, 115.809387},
	{99, 117.168945},
	{100, 117.656906},
	{101, 117.351395},
	{103, 116.476883},
	{104, 115.102638},
	{105, 113.303886},
	{107, 111.158577},
	{108, 108.744804},
	{109, 106.138199},
	{111, 103.409966},
	{112, 100.625244},
	{113, 97.842018},
	{115, 95.110664},
	{116, 92.473869},
	{117, 89.967079},
	{119, 87.619194},
	{120, 85.453575},
	{121, 83.489105},
	{123, 81.741348},
	{124, 80.223717},
	{125, 78.948608},
	{127, 77.928543},
	{128, 77.177322},
	{129, 76.711311},
	{131, 76.550636},
	{132, 77.129982},
	{133, 78.678024},
	{135, 80.923729},
	{136, 83.572525},
	{137, 86.267891},
	{139, 88.574379},
	{140, 89.991844},
	{141, 90.766945},
	{143, 91.49334},
	{144, 92.17131},
	{145, 92.801369},
	{147, 93.384224},
	{148, 93.920807},
	{149, 94.412262},
	{151, 94.859848},
	{152, 95.265076},
	{153, 95.62957},
	{155, 95.95507},
	{156, 96.2435},
	{157, 96.496857},
	{159, 96.717247},
	{160, 96.906868},
	{161, 97.067993},
	{163, 97.20298},
	{164, 97.314201},
	{165, 97.404114},
	{167, 97.475174},
	{168, 97.529907},
	{169, 97.570847},
	{171, 97.60051},
	{172, 97.621483},
	{173, 97.636314},
	{175, 97.647583},
	{176, 97.657845},
	{177, 97.669067},
	{179, 97.680756},
	{180, 97.691803},
	{181, 97.701057},
	{183, 97.707443},
	{184, 97.709808},
	{185, 93.418388},
	{187, 84.292091},
	{188, 75.164963},
	{189, 68.735275},
	{191, 66.318291},
	{275, 66.318291},
}

for _, Entry in CameraFovFrames do
	AddSetProperty(Entry[1], "Workspace.CurrentCamera", "FieldOfView", Entry[2])
end

local OverlayColorFrames = {
	{0, {0, 0, 0}},
	{40, {0, 0, 0}},
	{41, {1, 0.788235, 0.25098}},
	{47, {0, 0, 0}},
	{52, {0, 0, 0}},
	{53, {1, 0.788235, 0.25098}},
	{59, {0, 0, 0}},
	{64, {0, 0, 0}},
	{65, {1, 0.788235, 0.25098}},
	{71, {0, 0, 0}},
	{72, {0, 0, 0}},
	{73, {1, 0.788235, 0.25098}},
	{79, {0, 0, 0}},
	{80, {0, 0, 0}},
	{81, {1, 0.788235, 0.25098}},
	{87, {0, 0, 0}},
}

for _, Entry in OverlayColorFrames do
	AddSetProperty(Entry[1], "StarterGui.VignetteGui.Overlay", "ImageColor3", Entry[2])
end

local MarkerFrames = {
	{9, "local emitter = workspace.Stomp; width=0"},
	{44, "local emitter = workspace.GorillaThud; width=0"},
	{52, "local emitter = workspace.GorillaThud; width=0"},
	{66, "local emitter = workspace.GorillaThud; width=0"},
	{73, "local emitter = workspace.GorillaThud; width=0"},
	{81, "local emitter = workspace.GorillaThud; width=0"},
	{101, "local emitter = workspace.Kanji; width=0"},
	{113, "local emitter = workspace.JumpScreen; width=0"},
	{114, "local emitter = workspace.SpeedLines; width=0"},
	{CAMERA_RELEASE_FRAME, CAMERA_RELEASE_MARKER},
}

for _, Entry in MarkerFrames do
	AddMarker(Entry[1], "Workspace.gorilla", Entry[2])
end

return {
	FPS = FPS,
	MaxFrame = MAX_FRAME,
	Events = EVENTS,
}
