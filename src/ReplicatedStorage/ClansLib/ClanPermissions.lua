local module = {}

module.Permissions = {
	Emperor = {
		Demotes = {'Grand Moff', 'Commander', 'Corporal', 'Trooper'},
		Promotes = {'Trooper', 'Corporal', 'Commander', 'Initiate'},
		Color = Color3.fromRGB(255,0,0),
		Index = 1,
		CanInvite = true,
		CanSpendVault = true,
		CanKick = true,
		CanChatInInbox = true,
		ChangeEmblem = true,
		ChangeDescription = true,
	},
	['Grand Moff'] = {
		Demotes = {'Commander', 'Corporal', 'Trooper'},
		Promotes = {'Trooper', 'Corporal', 'Initiate'},
		Color = Color3.fromRGB(255,50,50),
		Index = 2,
		CanInvite = true,
		CanSpendVault = true,
		CanKick = true,
		CanChatInInbox = true,
		ChangeEmblem = true,
		ChangeDescription = true,
	},
	Commander = {
		Demotes = {'Corporal', 'Trooper'},
		Promotes = {'Trooper', 'Initiate'},
		Color = Color3.fromRGB(94, 255, 245),
		Index = 3,
		CanInvite = true,
		CanKick = true,
		CanChatInInbox = true,
		--ChangeEmblem = true,
		--ChangeDescription = true,
	},
	Corporal = {
		Demotes = {},
		Promotes = {},
		Color = Color3.fromRGB(255, 147, 43),
		Index = 4,
	},
	Trooper = {
		Demotes = {},
		Promotes = {},
		Color = Color3.fromRGB(200,200,200),
		Index = 5,
	},
	Initiate = {
		Demotes = {},
		Promotes = {},
		Color = Color3.fromRGB(150,150,150),
		Index = 6,
	}
}

function module.canSpendVault(sourceRank)
	return module.Permissions[sourceRank].CanSpendVault
end

function module.CanChangeDescription(sourceRank)
	return module.Permissions[sourceRank].ChangeDescription
end

function module.CanChangeEmblem(sourceRank)
	return module.Permissions[sourceRank].ChangeEmblem
end

function module.CanKick(kickerRank, targetRank)
	local kicker = module.Permissions[kickerRank]
	local target = module.Permissions[targetRank]
	if not kicker or not target then return end
	if not kicker.CanKick then return end
	if kicker.Index < target.Index then return true end
end

function module.whatModification(sourceRank, targetRank)
	local sourceRankIndex = module.Permissions[sourceRank].Index
	local targetRankIndex = module.Permissions[targetRank].Index
	
	if sourceRankIndex > targetRankIndex then
		return 'Promote'
	else
		return 'Demote'
	end
end

function module.canPromote(sourceRank, currentRank)
	return table.find(module.Permissions[sourceRank].Promotes, currentRank)
end

function module.canPost(sourceRank)
	return module.Permissions[sourceRank].CanChatInInbox
end

function module.canInvite(sourceRank)
	return module.Permissions[sourceRank].CanInvite
end

function module.canDemote(sourceRank, currentRank)
	return table.find(module.Permissions[sourceRank].Demotes, currentRank)
end

function module.GetPromotedTo(rank)
	local current = module.Permissions[rank]
	local currentIndex = current.Index
	
	for i,v in module.Permissions do
		if v.Index == currentIndex-1 then
			return i
		end
	end
end
function module.GetDemotedTo(rank)
	local current = module.Permissions[rank]
	local currentIndex = current.Index

	for i, v in module.Permissions do
		if v.Index == currentIndex + 1 then
			return i
		end
	end
end

return module