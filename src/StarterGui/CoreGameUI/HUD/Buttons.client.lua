local Players = game:GetService("Players")
local Player = Players.LocalPlayer

for i,v in script.Parent.LeftPanel:GetChildren() do
	if v:IsA('GuiBase2d') then
		v = v :: ImageButton
		
		v.Activated:Connect(function()
			if v.Name == 'Summon' then
				local character = Player.Character
				if character then
					character:PivotTo(workspace:WaitForChild('SummonTeleporters').Teleport.CFrame)
					_G.CloseAll()
				end
				return
			elseif v.Name == 'Play' then
				local character = Player.Character
				if character then
					character:PivotTo(workspace.PlayTeleport.Teleporter.CFrame)
					_G.CloseAll()
				end
				return
			end
			
			_G.CloseAll(v.Name)
		end)
	end
end

for i,v in script.Parent.RightPanel:GetChildren() do
	if v:IsA('GuiBase2d') then
		v = v :: ImageButton

		v.Activated:Connect(function()
			_G.CloseAll(v.Name)
		end)
	end
end