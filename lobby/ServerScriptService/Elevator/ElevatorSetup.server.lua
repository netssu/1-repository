for i,v in pairs(workspace.StoryElevators:GetChildren()) do
	if v:IsA('Model') then
		local skript = script.ElevatorServer:Clone()
		skript.Parent = v
		skript.Enabled = true
	end
end


if script:FindFirstChild('RaidElevatorServer') then
	for i,v in pairs(workspace.NewLobby.RaidElevators:GetChildren()) do
		local skript = script.RaidElevatorServer:Clone()
		skript.Parent = v
		skript.Enabled = true
	end
end

for i,v in workspace.VersusElevators:GetChildren() do
	local skript = script.VersusElevatorServer:Clone()
	skript.Parent = v
	skript.Enabled = true
end