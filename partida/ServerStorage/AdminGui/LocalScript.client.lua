for i, v in script.Parent.Frame:GetChildren() do
	if v:IsA("GuiButton") then
		v.MouseButton1Click:Connect(function()
			game.ReplicatedStorage.Events.SpawnMob:FireServer(v.Text)
		end)
	end
end