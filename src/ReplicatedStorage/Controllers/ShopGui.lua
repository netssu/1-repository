--!strict
------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local LocalPlayer = Players.LocalPlayer :: Instance

local GuiController = require(ReplicatedStorage.Controllers.GuiController) :: any

------------------//VARIABLES
local SettingsGui = {}

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local MainGui = PlayerGui:WaitForChild("Main")

local SettingsFrame = MainGui:WaitForChild("ShopFrame")

local HeaderTabs = SettingsFrame:WaitForChild("Header"):WaitForChild("Tabs"):WaitForChild("Contents")

------------------//FUNCTIONS
local function SetupHeaderTabs()
	local children = HeaderTabs:GetChildren()

	for i, tabFrame in ipairs(children) do

		if not tabFrame:IsA("Frame") then
			continue
		end

		local targetGuiName = tabFrame.Name

		local btn = tabFrame:FindFirstChild("Btn") :: GuiButton?
		if not btn then
			continue
		end

		btn.MouseButton1Click:Connect(function()
			if not GuiController then
				return
			end

			GuiController:Open(targetGuiName)
		end)
	end
end

------------------//INIT
function SettingsGui.Init(): ()
end

function SettingsGui.Start(): ()
	SetupHeaderTabs()
end

return SettingsGui