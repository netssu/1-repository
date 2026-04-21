for i,v in game.ReplicatedStorage.Enemies:GetDescendants() do
	if v.Name == 'Tact' then
		local newTact = game.ReplicatedStorage.DomainParent.Tact:Clone()
		newTact.Parent = v.Parent
		v:Destroy()
	end
end