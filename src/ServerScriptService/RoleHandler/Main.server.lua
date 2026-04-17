local MarketPlaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ValidRoles = {
	["Owner"] = {},
	["Content Creator"] = {150000, 150, 6}, -- div all by 3  
    ["Developer"] = {50000, 50, 2},
    ['Community Manager'] = {50000, 50, 2},
	["Developer+"] = {},
	["Manager"] = {},
}

function UpdateRewards(Player)
	local PlayerRoleInGroup = Player:GetRoleInGroup(35339513)
	local Role = ValidRoles[PlayerRoleInGroup] 

    if Role and #Role ~= 0  then
        print('GIVING REWARD')
		local GemsReward = Role[1]
		local TraitReward = Role[2]
		local LuckBoost = Role[3]
		Player:FindFirstChild("Gems").Value += GemsReward
		Player:FindFirstChild("TraitPoint").Value += TraitReward
		--Player:FindFirstChild("LuckBoost").Value += LuckBoost
	end
end


Players.PlayerAdded:Connect(function(Player)
	repeat task.wait() until Player:FindFirstChild("DataLoaded")
	
	if true then return end

	local UpdateVersion = Player:FindFirstChild("UpdateVersion")
	local Description = script.Description.Value

    if UpdateVersion and (UpdateVersion.Value == "" or UpdateVersion.Value ~= Description) then
		UpdateVersion.Value = Description
		UpdateRewards(Player)
	end
end)
