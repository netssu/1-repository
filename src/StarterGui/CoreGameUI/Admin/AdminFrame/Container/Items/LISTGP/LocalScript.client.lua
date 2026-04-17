local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

script.Parent.Activated:Connect(function()
	print('---- ITEM LIST ----')
	for i,v in Player.Items:GetChildren() do
		print(v.Name)
	end
	print('---- END ----')
end)