local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local Teams = game:GetService('Teams')
local TouchPart = script.Parent

TouchPart.Touched:Connect(function(touched)
	if touched.Parent:IsA("Model") and touched.Parent:FindFirstChild("Humanoid") then
		local Player = Players:GetPlayerFromCharacter(touched.Parent)
		if Player then
			if Player.Character:FindFirstChild('TELEPORTINGLEAVEMEALONE') then return end

			local boolValue = Instance.new('BoolValue')
			boolValue.Name = 'TELEPORTINGLEAVEMEALONE'
			boolValue.Parent = Player.Character
			
			if ReplicatedStorage.States.Gamemode.Value == 'Survival' or ReplicatedStorage.States.Gamemode.Value == 'Tutorial' then
				Player.Character:PivotTo(workspace.MainMapTeleport.CFrame)
			else
				if Player.Team == Teams.Red then
					Player.Character:PivotTo(workspace.RedMainMapTeleport.CFrame)
				else
					Player.Character:PivotTo(workspace.BlueMainMapTeleport.CFrame)
				end
			end
			
			task.wait(1)
			
			boolValue:Destroy()
		end
	end
end)