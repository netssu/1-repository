local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.SetHiddenQuests.OnServerEvent:Connect(function(plr, state)
	plr['QuestsHidden'].Value = state
end)