local Players: Players = game:GetService("Players")
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local hudAnim = require(modules:WaitForChild("Interface"):WaitForChild("HudAnim"))
local packages: Folder = ReplicatedFirst:WaitForChild("Packages")
local expressivePrompts = require(packages:WaitForChild("Main"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

------------------//FUNCTIONS
local function setup_interface(instance: Instance): ()
	if instance:IsA("ScreenGui") then
		hudAnim.apply_defaults_to_buttons(instance)
		hudAnim.bind_all(instance)
	end
end

------------------//MAIN FUNCTIONS

------------------//INIT
for _, gui in playerGui:GetChildren() do
	setup_interface(gui)
end

playerGui.DescendantAdded:Connect(setup_interface)

expressivePrompts.Config.BackgroundTransparency.Value = 0.3
expressivePrompts.Config.BackgroundColor.Value = Color3.fromRGB(15, 15, 25)
expressivePrompts.Config.TextColor.Value = Color3.fromRGB(255, 255, 255)
expressivePrompts.Config.SubTextColor.Value = Color3.fromRGB(150, 150, 170)
expressivePrompts.Config.CornerRadius.Value = 24
expressivePrompts.Config.MainSizeSpringSpeed.Value = 35
expressivePrompts.Config.MainSizeSpringDampening.Value = 0.35
expressivePrompts.Config.MainRotationSpringSpeed.Value = 45
expressivePrompts.Config.MainRotationSpringDampening.Value = 0.25
expressivePrompts.Config.MainRotationStrength.Value = 15
expressivePrompts.Config.AspectRatioSpringSpeed.Value = 30
expressivePrompts.Config.AspectRatioSpringDampening.Value = 0.4
expressivePrompts.Config.ProgressBarYScale.Value = 0.15
expressivePrompts.Config.ProgressBarColor.Value = Color3.fromRGB(255, 255, 255)
expressivePrompts.Config.ProgressBarTransparency.Value = 0.15
expressivePrompts.Config.GuiOffsetSpringSpeed.Value = 25
expressivePrompts.Config.GuiOffsetSpringDampening.Value = 0.4
expressivePrompts.Init()
