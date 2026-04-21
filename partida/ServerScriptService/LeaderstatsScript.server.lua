local short = require(game.ReplicatedStorage.Modules.NumberShortener)

game.Players.PlayerAdded:Connect(function(player)
	local RawDamage = player:SetAttribute("RawDamage", 0)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")
	local PlayerXP = player:SetAttribute("PlayerXP", player.PlayerExp.Value)
	
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("StringValue")
	money.Name = "Money"
	money.Value = "0"
	money.Parent = leaderstats

	local dmg = Instance.new("StringValue")
	dmg.Name = "Damage"
	dmg.Value = "0"
	dmg.Parent = leaderstats

	local kls = Instance.new("StringValue")
	kls.Name = "Kills"
	kls.Value = "0"
	kls.Parent = leaderstats

	leaderstats.Parent = player

	if player:WaitForChild("Money") then
		money.Value = short.en(player.Money.Value)
		player.Money.Changed:Connect(function()
			money.Value = short.en(player.Money.Value)
		end)
	end
	if player:WaitForChild("Damage") then
		dmg.Value = short.en(player.Damage.Value)
		player.Damage.Changed:Connect(function()
			dmg.Value = short.en(player.Damage.Value)
		end)
	end
	if player:WaitForChild("Kills") then
		kls.Value = short.en(player.Kills.Value)
		player.Kills.Changed:Connect(function()
			kls.Value = short.en(player.Kills.Value)
		end)
	end
end)

