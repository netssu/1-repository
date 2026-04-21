local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sinans_modules = ReplicatedStorage:WaitForChild("sinans_modules")
local closeopentweens = require(sinans_modules.closeopentweens)

local CoreGameUI = script.Parent.Parent.Parent.CoreGameUI

closeopentweens.setup(CoreGameUI.Areas.AreasFrame)

--script.Parent.SettingsButton.Activated:Connect(function()
--	if true then return end
--	_G.CloseAll('SettingsFrame')
--end)
