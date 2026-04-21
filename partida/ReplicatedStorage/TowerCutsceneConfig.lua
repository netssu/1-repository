local TowerCutsceneConfig = {
	RemoteEventName = "TowerMaxCutscene",

	Towers = {
		["Dart Wader"] = {
			SourcePath = "Cutscenes/DartWader",
			GuiName = "DartWaderMaxCutsceneGui",
			FallbackDuration = 6,
			CameraHeightOffset = -1.5,
			CameraContainerName = "Camera",
			CameraPartName = "camera",
			VfxModelName = "CutSceneVfx",
			TrackModelName = "2",
			SoundName = "Sound",
			PlacementMode = "Legacy",
			IgnoredAnimationContainers = {
				Sphere = true,
				CutSceneVfx = true,
			},
		},

		["Anekan Skaivoker"] = {
			SourcePath = "Cutscenes/AnekanSkaivoker",
			GuiName = "AnekanSkaivokerMaxCutsceneGui",
			FallbackDuration = 6,
			CameraHeightOffset = -1.5,
			CameraContainerName = "Camera",
			CameraPartName = "CameraPart",
			VfxModelName = "CutSceneVfx",
			TrackModelName = "Keyframes",
			SoundName = "Sound",
			PlacementMode = "ReferenceModel",
			PlacementReferenceName = "CutSceneFella",
			AnchoredContainers = {
				Camera = true,
				CutSceneVfx = true,
			},
			IgnoredAnimationContainers = {
				Sphere = true,
				CutSceneVfx = true,
			},

			-- Efeito especial do Anekan/Dart
			BlinkSwap = {
				Enabled = true,
				BaseModelName = "Anekan",
				FlashModelName = "Dart",
				Duration = 3,        -- primeiros 5 segundos
				Interval = 1,        -- a cada 1 segundo
				FlashDuration = 0.3, -- Dart aparece por 0.1s
				FlashYOffset = 0,  -- Dart fica 10 studs abaixo
			},
		},
	},
}

return TowerCutsceneConfig