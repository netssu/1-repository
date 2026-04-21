game.Players.PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	
	if player.Name == "Wh1teosnako" then
		print("WAIIIIT")
		
		_G.createTower(player.OwnedTowers, "Greedy")
		_G.createTower(player.OwnedTowers, "Chompy")
		_G.createTower(player.OwnedTowers, "Grand Moth Tarin")
		_G.createTower(player.OwnedTowers, "Bo Kotan")
		_G.createTower(player.OwnedTowers, "Bob")
		_G.createTower(player.OwnedTowers, "Princess")
		_G.createTower(player.OwnedTowers, "Hans")
	end
	
end)