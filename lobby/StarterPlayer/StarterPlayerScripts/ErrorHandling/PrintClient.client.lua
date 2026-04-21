local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrintClient = ReplicatedStorage.Events.PrintClient

PrintClient.OnClientEvent:Connect(function(msg)
	print(msg)
end)