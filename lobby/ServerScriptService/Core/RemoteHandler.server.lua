local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService('Players')

ReplicatedStorage.Events.Client.Tutorial.OnServerEvent:Connect(function(player)
	local TutorialCompleted = player:WaitForChild("TutorialCompleted")
	local TutorialWin = player:WaitForChild("TutorialWin")
	
	if TutorialWin.Value == true then
		TutorialCompleted.Value = true
	else
		warn("Player probably an exploiter lmao")
	end
end)

local function playerAdded(player: Player)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")
	
	if player.FirstTime.Value == true then
		player:WaitForChild('TutorialModeCompleted').Value = true
	end
end


for _, module in script:GetChildren() do
	local Remote = ReplicatedStorage:FindFirstChild(module.Name, true)
	if Remote then
		local func = require(module)
		if Remote:IsA("RemoteEvent") then
			Remote.OnServerEvent:Connect(func)
			--print("Connected",module)
		elseif Remote:IsA("RemoteFunction") then
			Remote.OnServerInvoke = func
			--print("Connected",module)
		end
	end
end

for _, player in players:GetPlayers() do
	playerAdded(player)
end

players.PlayerAdded:Connect(playerAdded)
