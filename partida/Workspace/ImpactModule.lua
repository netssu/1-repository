-- Similar to Jujutsu Shenanigans impact frames.

local impactModule = {}

--[[ SERVICES ]]--
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

--[[ VARIABLES ]]--
local Player = Players.LocalPlayer

-- References to UI elements
local Black = script:WaitForChild("Black")
local White = script:WaitForChild("White")

--[[ FUNCTIONS ]]--

-- Function to create impact effect on the map
function impactModule.createImpact(HoldTime)

	-- Clone UI elements
	local BlackClone = Black:Clone()
	local WhiteClone = White:Clone()

	-- Parent the clones appropriately
	BlackClone.Parent = Lighting
	WhiteClone.Parent = Player.Character

	-- Wait for the specified hold time
	task.delay(HoldTime, function()
		BlackClone:Destroy()
		WhiteClone:Destroy()
	end)

	-- Disable outline effect if it exists
	local Outline = Player.Character:FindFirstChild("Highlight")
	if Outline then
		Outline.Enabled = false
	else
		warn("Outline not found in Player.Character")
	end


end

return impactModule
