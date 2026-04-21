local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local module = {}

Players.PlayerAdded:Connect(function(plr)
	Instance.new('Folder', ReplicatedStorage.ClanInvites).Name = plr.UserId
end)

Players.PlayerRemoving:Connect(function(plr)
	local foundPlr = ReplicatedStorage.ClanInvites:FindFirstChild(plr.UserId)
	if foundPlr then
		foundPlr:Destroy()
	end
end)

function module.hasInvite(plr: Player, clan)
	return ReplicatedStorage.ClanInvites[plr.UserId]:FindFirstChild(clan)
end

function module.createInvite(plr, clan)
	local foundInvite = ReplicatedStorage.ClanInvites[plr.UserId]:FindFirstChild(clan)
	if not foundInvite then
		local NewInvite = Instance.new('BoolValue')
		NewInvite.Name = clan
		NewInvite.Parent = ReplicatedStorage.ClanInvites[plr.UserId]
		
		return "Success"
	else
		return "Player already has an invite"
	end
end

function module.deleteInvite(UserId: Number, clan:string)
	local foundClan = ReplicatedStorage.ClanInvites[UserId]:FindFirstChild(clan)
	if foundClan then
		foundClan:Destroy()
	end
end

return module