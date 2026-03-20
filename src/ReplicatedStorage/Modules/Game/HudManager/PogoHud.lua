------------------//VARIABLES
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local vendorFrame = playerGui:WaitForChild("GUI"):WaitForChild("VendorFrame")

------------------//FUNCTIONS
local function open_pogos_hud(): ()
	vendorFrame.Visible = true
end

local function close_pogos_hud(): ()
	vendorFrame.Visible = false
end

return {
	open_pogos_hud = open_pogos_hud,
	close_pogos_hud = close_pogos_hud,
}