-- made by abdul - unfortunately(edited by ace)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local areateleports = workspace:WaitForChild("areateleports")

script.Parent.Frame.X_Close.Activated:Connect(function()
	_G.CloseAll()
end)

for i, v in script.Parent.Frame.Location.Bg:GetChildren() do
	if v:IsA("ImageButton") then
		v.Contents.Teleport.Activated:Connect(function()
			if character then
				character.HumanoidRootPart.Position = areateleports[v.Name].Position
			end
			_G.CloseAll()
		end)
	end
end