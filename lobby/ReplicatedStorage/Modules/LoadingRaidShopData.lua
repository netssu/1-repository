local Loading = {}


local Levels = {
	[1] = "DeathStar" 
}

function Loading.LoadRightPanel(Panel, Contents, Level)	
end


function Loading.LoadCredits(Player, Label, Currency)
	
	if Currency then
		local Curent = Player:FindFirstChild(Currency)
		Label.Text = Curent.Name .. ":" .. " " .. Curent.Value
	end
	
	local RaidFolder = Player:FindFirstChild("RaidData")
	local Credits = RaidFolder.Credits
	Label.Text = "Credits:" .." " .. "x".. " ".. Credits.Value	
end

function Loading.LoadRefresh(Player, Label)
	local Refresh = Player:WaitForChild("RaidsRefresh").Value
	print(Refresh, Label)
	Label.Text = "Refresh:" .." " .. "x".. " ".. Refresh
end

function Loading.ShopLimits(Player, Label)	
end




return Loading
