local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GuiController = require(ReplicatedStorage.Controllers.GuiController)

local Trove = require(ReplicatedStorage.Packages.Trove)

local player = Players.LocalPlayer

local module = {}
module.__index = module

module.Tag = script.Name

type self = {
	Trove: Trove.Trove,
}

type GuiPrompt = typeof(setmetatable({} :: self, module))

function module.new(instance: ProximityPrompt): GuiPrompt
	local link = instance:GetAttribute("Link")
	if not link then
		error(`[C]: No link for Proximity Prompt {instance}`)
	end

	local self = setmetatable({} :: self, module)

	local mainTrove = Trove.new()

	mainTrove:Connect(instance.Triggered, function(whoTriggered: Player)
		if whoTriggered ~= player then
			return
		end

		GuiController:Open(link)
	end)

	self.Trove = mainTrove

	return self
end

function module.Destroy(self: GuiPrompt): ()
	self.Trove:Destroy()
end

return module
