local Players = game:GetService('Players')

if game.PlaceId == 117137931466956 and not game:GetService('RunService'):IsStudio() then
	Players.PlayerAdded:Connect(function(plr)
		local rank = plr:GetRankInGroup(35339513)
		if rank == 0 or rank == 1 or not rank then -- failed for whatever reason
			plr:Kick('oops, go away')
		end
	end)
end