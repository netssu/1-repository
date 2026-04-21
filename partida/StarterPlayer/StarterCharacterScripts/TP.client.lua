local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Maps = {"Naboo Planet", "Kashyyyk Planet", "Geonosis Planet", "Death Star", "Mustafar", "Destroyed Kamino"}

Player.CharacterAdded:Connect(function(character)
	local selectedMap = nil

	for _, mapName in ipairs(Maps) do
		local map = workspace.Map:FindFirstChild(mapName)
		if map then
			selectedMap = map
			break
		end
	end

	if not selectedMap then return end

	local spawnLocation = selectedMap:FindFirstChildOfClass("SpawnLocation")
	if not spawnLocation then return end

	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	character:PivotTo(spawnLocation.CFrame + CFrame.new(0, 5, 0))
end)
