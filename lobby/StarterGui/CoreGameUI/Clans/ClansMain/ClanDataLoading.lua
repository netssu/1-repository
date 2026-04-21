local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

function module.LoadData(clan: string)
	repeat task.wait() until ReplicatedStorage.Clans:FindFirstChild(clan)
	repeat task.wait() until ReplicatedStorage.Clans[clan]:FindFirstChild('Loaded')
	
	for i,v in script:GetChildren() do
		require(v).Init(clan)
	end	
end


return module