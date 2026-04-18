local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Trove = require(ReplicatedStorage.Packages.Trove)

local profileBillboardTemplate = ReplicatedStorage.Assets.ProfileBillboard

local module = {}
module.__index = module

module.Tag = script.Name

Players.PlayerAdded:Connect(function(player)
	if player.Character then
		CollectionService:AddTag(player.Character, module.Tag)
	end

	player.CharacterAdded:Connect(function(character)
		CollectionService:AddTag(character, module.Tag)
	end)
end)

type self = {
	Trove: Trove.Trove,
}

type ProfileBillboard = typeof(setmetatable({} :: self, module))

function module.new(instance: Model): ProfileBillboard
	local player = Players:GetPlayerFromCharacter(instance)
	if not player then
		error(`[S]: Player not found for character: {instance}.`)
	end

	local self = setmetatable({} :: self, module)

	local mainTrove = Trove.new()

	local humanoid = instance:WaitForChild("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local playerWins = PlayerDataService:GetValue(player, "Trophies") :: number

	local newProfileBillboard = mainTrove:Add(profileBillboardTemplate:Clone())
	newProfileBillboard.PlayerName.Text = player.DisplayName
	newProfileBillboard.Wins.Amount.Text = playerWins

	newProfileBillboard.Parent = instance:WaitForChild("HumanoidRootPart")

	mainTrove:Add(
		PlayerDataService:GetValueChangedSignal(player, "Trophies"):Connect(function(newValue: number)
			newProfileBillboard.Wins.Amount.Text = " "..newValue
		end),
		"Disconnect"
	)

	self.Trove = mainTrove

	return self
end

function module.Destroy(self: ProfileBillboard): ()
	self.Trove:Destroy()
end

return module
